// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title IBurnableERC20
 * @notice Extended ERC-20 interface that includes burn methods and supply tracking
 * required by the Quadruple Burn fee engine and supply floor enforcement.
 */
interface IBurnableERC20 is IERC20 {
    function burnFrom(address account, uint256 amount) external;
    function totalSupply() external view returns (uint256);
}

/**
 * @title VepoBounty
 * @author Vepo Network
 * @notice The decentralized escrow, arbitration, and micro-bounty marketplace engine
 * for the Vepo Network L3 App-Chain.
 *
 * @dev Core protocol contract that:
 * - Holds client funds (native gas token / USDC) in escrow until work is delivered.
 * - Implements a Quadruple Burn fee structure (Listing, Application, Boost, Delete)
 *   that permanently destroys $VEPO on every marketplace interaction.
 * - Provides a two-step hiring flow: Apply → Select → Submit → Release.
 * - Includes an Admin Arbiter dispute resolution system for contested deliverables.
 * - Enforces a 7-day time-lock ghosting protection so freelancers can claim
 *   abandoned funds if the client disappears.
 *
 * Supply Floor Awareness:
 * - When `totalSupply()` is above the `supplyFloor`, fees are burned normally.
 * - When `totalSupply()` is at or below the `supplyFloor`, fees are redirected
 *   to the VepoStaking contract as staker rewards instead of being burned.
 *   This ensures the protocol continues to collect fees even at the floor.
 *
 * Security:
 * - `ReentrancyGuard` on all fund-transfer functions.
 * - `Pausable` emergency circuit-breaker for protocol-wide halts.
 * - `Ownable` for admin-only governance actions (fee adjustment, dispute resolution).
 */
contract VepoBounty is ReentrancyGuard, Ownable, Pausable {
    /// @notice The $VEPO token contract used for deflationary fee burns.
    IBurnableERC20 public vepoToken;

    /// @notice The VepoStaking contract that receives fees when supply is at the floor.
    address public stakingContract;

    /// @notice The supply floor — when totalSupply <= this value, fees redirect to stakers.
    uint256 public supplyFloor = 10_000_000 * 10 ** 18;

    // ──────────────────────────────────────────────
    // Anti-Spam Deflationary Fees (The Quadruple Burn)
    // ──────────────────────────────────────────────

    /// @notice Fee burned when a client posts a new bounty.
    uint256 public listingFee = 5 * 10 ** 18;

    /// @notice Fee burned when a client boosts a bounty to the top of the feed.
    uint256 public boostFee = 100 * 10 ** 18;

    /// @notice Fee burned when a freelancer applies for an open gig.
    uint256 public applicationFee = 5 * 10 ** 18;

    /// @notice Fee burned when a client cancels a bounty before work starts.
    uint256 public deleteFee = 5 * 10 ** 18;

    // ──────────────────────────────────────────────
    // Bounty State Machine
    // ──────────────────────────────────────────────

    /// @notice The lifecycle states of a bounty.
    enum BountyState { Open, Locked, Completed, Cancelled, Disputed }

    /// @notice On-chain representation of a micro-bounty.
    struct Bounty {
        uint256 bountyId;
        address client;
        address freelancer;
        uint256 amount;
        uint256 originalAmount;
        BountyState state;
        bool isBoosted;
        string workLink;
        uint256 workSubmittedAt;
    }

    /// @notice A freelancer's application to a bounty.
    struct Applicant {
        address freelancer;
        string portfolioLink;
    }

    /// @notice Auto-incrementing counter for unique bounty IDs.
    uint256 public bountyCounter;

    /// @notice Mapping of bounty ID to its on-chain data.
    mapping(uint256 => Bounty) public bounties;

    /// @notice Mapping of bounty ID to its list of applicants.
    mapping(uint256 => Applicant[]) public bountyApplicants;

    // ──────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────

    /// @notice Emitted when a new bounty is posted.
    event BountyPosted(uint256 indexed bountyId, address indexed client, uint256 amount);

    /// @notice Emitted when a bounty is boosted to the top of the feed.
    event BountyBoosted(uint256 indexed bountyId, address indexed client);

    /// @notice Emitted when a freelancer applies for a gig.
    event FreelancerApplied(uint256 indexed bountyId, address indexed freelancer, string portfolioLink);

    /// @notice Emitted when a client selects a freelancer for a gig.
    event FreelancerSelected(uint256 indexed bountyId, address indexed freelancer);

    /// @notice Emitted when the assigned freelancer submits their work.
    event WorkSubmitted(uint256 indexed bountyId, address indexed freelancer, string workLink);

    /// @notice Emitted when a client rejects submitted work and triggers a dispute.
    event WorkRejectedAndDisputed(uint256 indexed bountyId);

    /// @notice Emitted when a bounty is cancelled by the client.
    event BountyCancelled(uint256 indexed bountyId);

    /// @notice Emitted when escrow funds are released to the freelancer.
    event FundsReleased(uint256 indexed bountyId, address indexed freelancer, uint256 amount);

    /// @notice Emitted when a freelancer claims funds after the 7-day ghosting time-lock expires.
    event AbandonedFundsClaimed(uint256 indexed bountyId, address indexed freelancer, uint256 amount);

    /// @notice Emitted when an admin resolves a dispute.
    event DisputeResolved(uint256 indexed bountyId, address indexed winner, uint256 amount);

    /// @notice Emitted when the protocol fee structure is updated.
    event FeesUpdated(uint256 listingFee, uint256 applicationFee, uint256 boostFee, uint256 deleteFee);

    /// @notice Emitted when a fee is burned (supply above floor).
    event FeeBurned(address indexed payer, uint256 amount);

    /// @notice Emitted when a fee is redirected to stakers (supply at floor).
    event FeeRedirectedToStakers(address indexed payer, uint256 amount);

    /// @notice Emitted when the staking contract address is updated.
    event StakingContractUpdated(address indexed newStakingContract);

    /// @notice Emitted when the supply floor is updated.
    event SupplyFloorUpdated(uint256 newFloor);

    // ──────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────

    /**
     * @notice Initializes the VepoBounty contract.
     * @param _vepoToken Address of the deployed VepoToken contract.
     */
    constructor(address _vepoToken) Ownable(msg.sender) {
        vepoToken = IBurnableERC20(_vepoToken);
    }

    // ──────────────────────────────────────────────
    // Fee Setters (Governance)
    // ──────────────────────────────────────────────

    /// @notice Updates the listing fee. Only callable by the protocol owner.
    function setListingFee(uint256 _newFee) external onlyOwner { listingFee = _newFee; }

    /// @notice Updates the boost fee. Only callable by the protocol owner.
    function setBoostFee(uint256 _newFee) external onlyOwner { boostFee = _newFee; }

    /// @notice Updates the application fee. Only callable by the protocol owner.
    function setApplicationFee(uint256 _newFee) external onlyOwner { applicationFee = _newFee; }

    /// @notice Updates the delete/cancellation fee. Only callable by the protocol owner.
    function setDeleteFee(uint256 _newFee) external onlyOwner { deleteFee = _newFee; }

    /**
     * @notice Batch-updates all four Quadruple Burn fees in a single transaction.
     * @dev Designed for the governance dashboard. All values are in wei (18 decimals).
     * @param _listingFee    New listing fee (e.g., 5e18 = 5 $VEPO).
     * @param _applicationFee New application fee.
     * @param _boostFee      New boost fee.
     * @param _deleteFee     New delete/cancellation fee.
     */
    function setFees(
        uint256 _listingFee,
        uint256 _applicationFee,
        uint256 _boostFee,
        uint256 _deleteFee
    ) external onlyOwner {
        listingFee = _listingFee;
        applicationFee = _applicationFee;
        boostFee = _boostFee;
        deleteFee = _deleteFee;
        emit FeesUpdated(_listingFee, _applicationFee, _boostFee, _deleteFee);
    }

    /**
     * @notice Sets the VepoStaking contract address for fee redirection at the supply floor.
     * @param _stakingContract Address of the VepoStaking contract.
     */
    function setStakingContract(address _stakingContract) external onlyOwner {
        require(_stakingContract != address(0), "Invalid staking address");
        stakingContract = _stakingContract;
        emit StakingContractUpdated(_stakingContract);
    }

    /**
     * @notice Updates the supply floor threshold for fee redirection.
     * @param _newFloor New supply floor in wei.
     */
    function setSupplyFloor(uint256 _newFloor) external onlyOwner {
        supplyFloor = _newFloor;
        emit SupplyFloorUpdated(_newFloor);
    }

    // ──────────────────────────────────────────────
    // Emergency Controls
    // ──────────────────────────────────────────────

    /// @notice Pauses all marketplace operations. Emergency use only.
    function pause() external onlyOwner { _pause(); }

    /// @notice Unpauses the marketplace.
    function unpause() external onlyOwner { _unpause(); }

    // ──────────────────────────────────────────────
    // Internal Fee Processing (Supply Floor Aware)
    // ──────────────────────────────────────────────

    /**
     * @dev Processes a platform fee from a user. If the total supply is above the
     * supply floor, the fee is burned. If the supply is at or below the floor,
     * the fee is transferred to the VepoStaking contract for staker distribution.
     *
     * This ensures the protocol continues to collect fees and incentivize stakers
     * even after the token reaches its minimum supply.
     *
     * @param payer The address paying the fee (must have approved this contract).
     * @param amount The fee amount in $VEPO (wei).
     */
    function _processFee(address payer, uint256 amount) internal {
        uint256 currentSupply = vepoToken.totalSupply();

        if (currentSupply > supplyFloor) {
            // Supply is above floor — burn the fee (deflationary)
            vepoToken.burnFrom(payer, amount);
            emit FeeBurned(payer, amount);
        } else if (stakingContract != address(0)) {
            // Supply is at floor — redirect fee to stakers (value accrual)
            require(vepoToken.transferFrom(payer, stakingContract, amount), "Fee redirect failed");
            emit FeeRedirectedToStakers(payer, amount);
        } else {
            // Fallback: if staking contract not set, still burn
            // (this prevents a DoS where fees can't be collected)
            vepoToken.burnFrom(payer, amount);
            emit FeeBurned(payer, amount);
        }
    }

    // ──────────────────────────────────────────────
    // Core Marketplace Functions
    // ──────────────────────────────────────────────

    /**
     * @notice Posts a new bounty with native gas token (USDC) as escrow payment.
     * @dev The caller pays the listing fee in $VEPO. Freelancers receive USDC —
     * they are never required to hold or purchase $VEPO.
     *
     * Requirements:
     * - `msg.value` must be greater than 0 (USDC escrow amount).
     * - Caller must have approved at least `listingFee` $VEPO for this contract.
     */
    function postBounty() external payable whenNotPaused {
        require(msg.value > 0, "Bounty amount must be greater than 0");

        // Process Listing Fee (burn or redirect to stakers based on supply)
        _processFee(msg.sender, listingFee);

        bountyCounter++;
        bounties[bountyCounter] = Bounty({
            bountyId: bountyCounter,
            client: msg.sender,
            freelancer: address(0),
            amount: msg.value,
            originalAmount: msg.value,
            state: BountyState.Open,
            isBoosted: false,
            workLink: "",
            workSubmittedAt: 0
        });

        emit BountyPosted(bountyCounter, msg.sender, msg.value);
    }

    /**
     * @notice Boosts a bounty to the top of the feed by paying the boost fee.
     * @param bountyId The ID of the bounty to boost.
     *
     * Requirements:
     * - Caller must be the bounty's client.
     * - Bounty must be in `Open` state and not already boosted.
     * - Caller must have approved at least `boostFee` $VEPO for this contract.
     */
    function boostBounty(uint256 bountyId) external whenNotPaused {
        Bounty storage bounty = bounties[bountyId];
        require(bounty.client == msg.sender, "Only client can boost");
        require(!bounty.isBoosted, "Already boosted");
        require(bounty.state == BountyState.Open, "Can only boost open bounties");

        // Process Boost Fee
        _processFee(msg.sender, boostFee);

        bounty.isBoosted = true;
        emit BountyBoosted(bountyId, msg.sender);
    }

    /**
     * @notice Applies for an open gig by submitting a portfolio link.
     * @param bountyId The ID of the bounty to apply for.
     * @param portfolioLink A URL to the freelancer's portfolio or resume.
     *
     * Requirements:
     * - Bounty must exist and be in `Open` state.
     * - Caller cannot be the bounty's client.
     * - Caller must have approved at least `applicationFee` $VEPO for this contract.
     */
    function applyForGig(uint256 bountyId, string memory portfolioLink) external whenNotPaused {
        Bounty storage bounty = bounties[bountyId];
        require(bounty.client != address(0), "Bounty does not exist");
        require(bounty.state == BountyState.Open, "Bounty is not open");
        require(msg.sender != bounty.client, "Client cannot apply to own gig");

        // Process Application Fee
        _processFee(msg.sender, applicationFee);

        bountyApplicants[bountyId].push(Applicant({
            freelancer: msg.sender,
            portfolioLink: portfolioLink
        }));

        emit FreelancerApplied(bountyId, msg.sender, portfolioLink);
    }

    /**
     * @notice Returns the list of applicants for a bounty.
     * @param bountyId The bounty ID to query.
     * @return An array of `Applicant` structs.
     */
    function getApplicants(uint256 bountyId) external view returns (Applicant[] memory) {
        return bountyApplicants[bountyId];
    }

    /**
     * @notice Selects a freelancer for a bounty, locking the gig.
     * @param bountyId The ID of the bounty.
     * @param freelancer The address of the selected freelancer.
     *
     * Requirements:
     * - Caller must be the bounty's client.
     * - Bounty must be in `Open` state.
     * - Freelancer address must not be the zero address.
     */
    function selectFreelancer(uint256 bountyId, address freelancer) external whenNotPaused {
        Bounty storage bounty = bounties[bountyId];
        require(bounty.client == msg.sender, "Only client can select freelancer");
        require(bounty.state == BountyState.Open, "Bounty is not open");
        require(freelancer != address(0), "Invalid freelancer address");

        bounty.freelancer = freelancer;
        bounty.state = BountyState.Locked;

        emit FreelancerSelected(bountyId, freelancer);
    }

    /**
     * @notice Submits a link to completed work for review by the client.
     * @param bountyId The ID of the bounty.
     * @param workLink A URL pointing to the deliverable (GitHub repo, document, etc.).
     *
     * Requirements:
     * - Bounty must be in `Locked` state.
     * - Caller must be the assigned freelancer.
     */
    function submitWork(uint256 bountyId, string memory workLink) external whenNotPaused {
        Bounty storage bounty = bounties[bountyId];
        require(bounty.state == BountyState.Locked, "Bounty is not locked");
        require(bounty.freelancer == msg.sender, "Only assigned freelancer can submit work");
        
        bounty.workLink = workLink;
        bounty.workSubmittedAt = block.timestamp;
        
        emit WorkSubmitted(bountyId, msg.sender, workLink);
    }

    /**
     * @notice Rejects submitted work and transitions the bounty to `Disputed`.
     * @dev Funds remain frozen in escrow until the Admin Arbiter resolves the dispute.
     * @param bountyId The ID of the bounty.
     *
     * Requirements:
     * - Caller must be the bounty's client.
     * - Bounty must be in `Locked` state with work submitted.
     */
    function rejectWork(uint256 bountyId) external whenNotPaused {
        Bounty storage bounty = bounties[bountyId];
        require(bounty.client == msg.sender, "Only client can reject work");
        require(bounty.state == BountyState.Locked, "No work to reject");
        require(bounty.workSubmittedAt != 0, "Work not submitted yet");

        bounty.state = BountyState.Disputed;

        emit WorkRejectedAndDisputed(bountyId);
    }

    /**
     * @notice Cancels an open bounty and refunds the escrowed funds to the client.
     * @dev Burns the delete fee as a spam-prevention measure. Only works on `Open` bounties.
     * @param bountyId The ID of the bounty to cancel.
     */
    function cancelBounty(uint256 bountyId) external nonReentrant whenNotPaused {
        Bounty storage bounty = bounties[bountyId];
        require(bounty.client == msg.sender, "Only client can cancel");
        require(bounty.state == BountyState.Open, "Cannot cancel, work submitted or locked");

        // Process Delete Fee
        _processFee(msg.sender, deleteFee);

        bounty.state = BountyState.Cancelled;
        uint256 amountToRefund = bounty.amount;
        bounty.amount = 0;

        (bool success, ) = msg.sender.call{value: amountToRefund}("");
        require(success, "Refund failed");

        emit BountyCancelled(bountyId);
    }

    /**
     * @notice Releases escrowed funds (USDC) to the freelancer upon satisfactory delivery.
     * @dev Freelancers receive the native gas token (USDC) — never $VEPO.
     * @param bountyId The ID of the bounty.
     *
     * Requirements:
     * - Caller must be the bounty's client.
     * - Bounty must be in `Locked` state with work submitted.
     */
    function releaseFunds(uint256 bountyId) external nonReentrant whenNotPaused {
        Bounty storage bounty = bounties[bountyId];
        require(bounty.client == msg.sender, "Only client can release funds");
        require(bounty.state == BountyState.Locked, "State must be Locked");
        require(bounty.workSubmittedAt != 0, "Work not submitted yet");

        bounty.state = BountyState.Completed;
        
        uint256 amountToRelease = bounty.amount;
        bounty.amount = 0;
        
        (bool success, ) = bounty.freelancer.call{value: amountToRelease}("");
        require(success, "Transfer failed");

        emit FundsReleased(bountyId, bounty.freelancer, amountToRelease);
    }

    // ──────────────────────────────────────────────
    // Dispute & Arbitration System
    // ──────────────────────────────────────────────

    /**
     * @notice Allows a freelancer to claim payment if the client ghosts for 7+ days.
     * @dev This is the ghosting protection mechanism. After the 7-day time-lock expires,
     * the freelancer can bypass the client and withdraw their earned USDC payment directly.
     * @param bountyId The ID of the bounty.
     *
     * Requirements:
     * - Bounty must be in `Locked` state with work submitted.
     * - Caller must be the assigned freelancer.
     * - At least 7 days must have passed since work submission.
     */
    function claimAbandonedFunds(uint256 bountyId) external nonReentrant {
        Bounty storage bounty = bounties[bountyId];
        require(bounty.state == BountyState.Locked, "State must be Locked");
        require(bounty.freelancer == msg.sender, "Only assigned freelancer can claim");
        require(bounty.workSubmittedAt != 0, "Work not submitted yet");
        require(block.timestamp >= bounty.workSubmittedAt + 7 days, "7-day time-lock has not expired");

        bounty.state = BountyState.Completed;

        uint256 amountToRelease = bounty.amount;
        bounty.amount = 0;

        (bool success, ) = bounty.freelancer.call{value: amountToRelease}("");
        require(success, "Transfer failed");

        emit AbandonedFundsClaimed(bountyId, msg.sender, amountToRelease);
    }

    /**
     * @notice Resolves a disputed bounty by awarding funds to either the freelancer or client.
     * @dev Only callable by the protocol owner acting as Admin Arbiter.
     * @param bountyId The ID of the disputed bounty.
     * @param favorFreelancer If true, USDC funds go to the freelancer; otherwise, refunded to client.
     */
    function resolveDispute(uint256 bountyId, bool favorFreelancer) external onlyOwner nonReentrant {
        Bounty storage bounty = bounties[bountyId];
        require(bounty.state == BountyState.Disputed, "Bounty is not disputed");

        bounty.state = favorFreelancer ? BountyState.Completed : BountyState.Cancelled;
        
        uint256 amountToRelease = bounty.amount;
        bounty.amount = 0;

        address winner = favorFreelancer ? bounty.freelancer : bounty.client;
        
        (bool success, ) = winner.call{value: amountToRelease}("");
        require(success, "Transfer failed");

        emit DisputeResolved(bountyId, winner, amountToRelease);
    }
}
