// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract VepoBounty is ReentrancyGuard {
    IERC20 public vepoToken;
    address public treasury;

    enum BountyState { Open, Locked, Completed, Cancelled }

    struct Bounty {
        uint256 bountyId;
        address client;
        address freelancer;
        uint256 amount;
        BountyState state;
        bool isBoosted;
        string workLink;
    }

    uint256 public bountyCounter;
    mapping(uint256 => Bounty) public bounties;

    // Assumes VEPO and native L3 gas (USDC) are 18 decimals
    uint256 public constant BOOST_COST = 100 * 10 ** 18; 

    event BountyPosted(uint256 indexed bountyId, address indexed client, uint256 amount);
    event BountyBoosted(uint256 indexed bountyId, address indexed client);
    event WorkSubmitted(uint256 indexed bountyId, address indexed freelancer, string workLink);
    event WorkRejected(uint256 indexed bountyId);
    event BountyCancelled(uint256 indexed bountyId);
    event FundsReleased(uint256 indexed bountyId, address indexed freelancer, uint256 amount);

    constructor(address _vepoToken, address _treasury) {
        vepoToken = IERC20(_vepoToken);
        treasury = _treasury;
    }

    function postBounty() external payable {
        require(msg.value > 0, "Bounty amount must be greater than 0");

        bountyCounter++;
        bounties[bountyCounter] = Bounty({
            bountyId: bountyCounter,
            client: msg.sender,
            freelancer: address(0),
            amount: msg.value,
            state: BountyState.Open,
            isBoosted: false,
            workLink: ""
        });

        emit BountyPosted(bountyCounter, msg.sender, msg.value);
    }

    function boostBounty(uint256 bountyId) external {
        Bounty storage bounty = bounties[bountyId];
        require(bounty.client == msg.sender, "Only client can boost");
        require(!bounty.isBoosted, "Already boosted");

        require(vepoToken.transferFrom(msg.sender, treasury, BOOST_COST), "Transfer failed");

        bounty.isBoosted = true;
        emit BountyBoosted(bountyId, msg.sender);
    }

    function submitWork(uint256 bountyId, string memory workLink) external {
        Bounty storage bounty = bounties[bountyId];
        require(bounty.client != address(0), "Bounty does not exist");
        require(bounty.state == BountyState.Open, "Bounty is not open");
        
        bounty.freelancer = msg.sender;
        bounty.workLink = workLink;
        bounty.state = BountyState.Locked;
        
        emit WorkSubmitted(bountyId, msg.sender, workLink);
    }

    function rejectWork(uint256 bountyId) external {
        Bounty storage bounty = bounties[bountyId];
        require(bounty.client == msg.sender, "Only client can reject work");
        require(bounty.state == BountyState.Locked, "No work to reject");

        bounty.freelancer = address(0);
        bounty.workLink = "";
        bounty.state = BountyState.Open;

        emit WorkRejected(bountyId);
    }

    function cancelBounty(uint256 bountyId) external nonReentrant {
        Bounty storage bounty = bounties[bountyId];
        require(bounty.client == msg.sender, "Only client can cancel");
        require(bounty.state == BountyState.Open, "Cannot cancel, work submitted or completed");

        bounty.state = BountyState.Cancelled;
        uint256 amountToRefund = bounty.amount;
        bounty.amount = 0; // Prevent re-entrancy / double refund

        (bool success, ) = msg.sender.call{value: amountToRefund}("");
        require(success, "Refund failed");

        emit BountyCancelled(bountyId);
    }

    function releaseFunds(uint256 bountyId) external nonReentrant {
        Bounty storage bounty = bounties[bountyId];
        require(bounty.client == msg.sender, "Only client can release funds");
        require(bounty.state == BountyState.Locked, "Work not submitted or already completed");
        require(bounty.freelancer != address(0), "No freelancer assigned");

        bounty.state = BountyState.Completed;
        
        uint256 amountToRelease = bounty.amount;
        bounty.amount = 0; // Prevent re-entrancy
        
        // Use .call{value: amountToRelease}("") instead of .transfer() to support ERC-4337 smart wallets
        (bool success, ) = bounty.freelancer.call{value: amountToRelease}("");
        require(success, "Transfer failed");

        emit FundsReleased(bountyId, bounty.freelancer, amountToRelease);
    }
}
