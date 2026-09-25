// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title VepoGovernance
 * @author Vepo Network
 * @notice On-chain governance module for decentralized protocol parameter voting.
 *
 * @dev Enables $VEPO stakers to propose and vote on protocol changes, replacing
 * centralized admin control with community-driven governance.
 *
 * Proposal lifecycle:
 * 1. **Creation:** Any $VEPO holder above `proposalThreshold` can create a proposal.
 * 2. **Voting:** Stakers vote For/Against during the `votingPeriod` window.
 *    Vote weight equals the voter's $VEPO balance at time of voting.
 * 3. **Execution:** If the proposal reaches quorum and passes, the owner (or a
 *    future Timelock) executes the approved change.
 *
 * Supported proposal types:
 * - Fee adjustments (listing, application, boost, delete fees)
 * - Burn BPS changes
 * - Supply floor changes
 * - General protocol upgrades (text-only proposals)
 *
 * Future extensions:
 * - On-chain execution via Timelock controller
 * - Snapshot-based voting (prevents vote-buying via flash loans)
 * - Delegation (vote on behalf of another staker)
 */
contract VepoGovernance is Ownable {

    /// @notice The $VEPO token used for governance voting weight.
    IERC20 public immutable vepoToken;

    /// @notice Minimum $VEPO balance required to create a proposal.
    uint256 public proposalThreshold = 10_000 * 10**18; // 10,000 VEPO

    /// @notice Minimum total votes required for a proposal to be valid.
    uint256 public quorum = 100_000 * 10**18; // 100,000 VEPO

    /// @notice Duration of the voting window in seconds (default: 3 days).
    uint256 public votingPeriod = 3 days;

    /// @notice Auto-incrementing proposal ID counter.
    uint256 public proposalCount;

    /// @notice The lifecycle states of a governance proposal.
    enum ProposalState { Active, Passed, Rejected, Executed, Cancelled }

    /// @notice On-chain representation of a governance proposal.
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        ProposalState state;
    }

    /// @notice Mapping of proposal ID to its on-chain data.
    mapping(uint256 => Proposal) public proposals;

    /// @notice Tracks whether an address has voted on a specific proposal.
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    /// @notice Tracks the vote weight each address cast on a specific proposal.
    mapping(uint256 => mapping(address => uint256)) public voteWeight;

    // ──────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────

    /// @notice Emitted when a new proposal is created.
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        uint256 startTime,
        uint256 endTime
    );

    /// @notice Emitted when a vote is cast on a proposal.
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 weight
    );

    /// @notice Emitted when a proposal is finalized (passed or rejected).
    event ProposalFinalized(uint256 indexed proposalId, ProposalState state);

    /// @notice Emitted when a proposal is executed by the admin.
    event ProposalExecuted(uint256 indexed proposalId);

    /// @notice Emitted when governance parameters are updated.
    event GovernanceParamsUpdated(uint256 proposalThreshold, uint256 quorum, uint256 votingPeriod);

    // ──────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────

    /**
     * @notice Initializes the governance module.
     * @param _vepoToken Address of the VepoToken contract.
     */
    constructor(address _vepoToken) Ownable(msg.sender) {
        vepoToken = IERC20(_vepoToken);
    }

    // ──────────────────────────────────────────────
    // Proposal Creation
    // ──────────────────────────────────────────────

    /**
     * @notice Creates a new governance proposal.
     * @param title Short title of the proposal.
     * @param description Detailed description of what the proposal changes and why.
     * @return proposalId The ID of the newly created proposal.
     *
     * Requirements:
     * - Caller must hold at least `proposalThreshold` $VEPO.
     */
    function createProposal(
        string memory title,
        string memory description
    ) external returns (uint256 proposalId) {
        require(
            vepoToken.balanceOf(msg.sender) >= proposalThreshold,
            "Below proposal threshold"
        );

        proposalCount++;
        proposalId = proposalCount;

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            title: title,
            description: description,
            votesFor: 0,
            votesAgainst: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + votingPeriod,
            state: ProposalState.Active
        });

        emit ProposalCreated(proposalId, msg.sender, title, block.timestamp, block.timestamp + votingPeriod);
    }

    // ──────────────────────────────────────────────
    // Voting
    // ──────────────────────────────────────────────

    /**
     * @notice Casts a vote on an active proposal.
     * @param proposalId The ID of the proposal to vote on.
     * @param support True to vote For, false to vote Against.
     *
     * Requirements:
     * - Proposal must be in `Active` state and within the voting window.
     * - Caller must not have already voted on this proposal.
     * - Caller must hold $VEPO (vote weight = current balance).
     */
    function castVote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        
        require(proposal.state == ProposalState.Active, "Proposal not active");
        require(block.timestamp <= proposal.endTime, "Voting period ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 weight = vepoToken.balanceOf(msg.sender);
        require(weight > 0, "No voting power");

        hasVoted[proposalId][msg.sender] = true;
        voteWeight[proposalId][msg.sender] = weight;

        if (support) {
            proposal.votesFor += weight;
        } else {
            proposal.votesAgainst += weight;
        }

        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    // ──────────────────────────────────────────────
    // Finalization & Execution
    // ──────────────────────────────────────────────

    /**
     * @notice Finalizes a proposal after the voting period ends.
     * @dev A proposal passes if `votesFor > votesAgainst` AND total votes >= quorum.
     * @param proposalId The ID of the proposal to finalize.
     */
    function finalizeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        
        require(proposal.state == ProposalState.Active, "Not active");
        require(block.timestamp > proposal.endTime, "Voting still open");

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;

        if (totalVotes >= quorum && proposal.votesFor > proposal.votesAgainst) {
            proposal.state = ProposalState.Passed;
        } else {
            proposal.state = ProposalState.Rejected;
        }

        emit ProposalFinalized(proposalId, proposal.state);
    }

    /**
     * @notice Marks a passed proposal as executed.
     * @dev In the current implementation, the owner executes the approved changes manually.
     * Future versions will use a Timelock for trustless on-chain execution.
     * @param proposalId The ID of the passed proposal.
     */
    function executeProposal(uint256 proposalId) external onlyOwner {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.Passed, "Proposal not passed");

        proposal.state = ProposalState.Executed;
        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice Cancels an active proposal. Only callable by the proposer or owner.
     * @param proposalId The ID of the proposal to cancel.
     */
    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.Active, "Not active");
        require(
            msg.sender == proposal.proposer || msg.sender == owner(),
            "Only proposer or owner"
        );

        proposal.state = ProposalState.Cancelled;
        emit ProposalFinalized(proposalId, ProposalState.Cancelled);
    }

    // ──────────────────────────────────────────────
    // View Functions
    // ──────────────────────────────────────────────

    /**
     * @notice Returns the full details of a proposal.
     * @param proposalId The proposal ID.
     * @return The proposal struct.
     */
    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        return proposals[proposalId];
    }

    // ──────────────────────────────────────────────
    // Governance Parameter Setters
    // ──────────────────────────────────────────────

    /**
     * @notice Updates governance configuration parameters.
     * @param _threshold New proposal creation threshold in wei.
     * @param _quorum New quorum requirement in wei.
     * @param _period New voting period in seconds.
     */
    function updateGovernanceParams(
        uint256 _threshold,
        uint256 _quorum,
        uint256 _period
    ) external onlyOwner {
        require(_period >= 1 hours, "Voting period too short");
        proposalThreshold = _threshold;
        quorum = _quorum;
        votingPeriod = _period;
        emit GovernanceParamsUpdated(_threshold, _quorum, _period);
    }
}
