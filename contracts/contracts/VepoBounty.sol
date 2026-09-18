// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract VepoBounty is ReentrancyGuard {
    IERC20 public vepoToken;
    address public treasury;

    struct Bounty {
        uint256 bountyId;
        address client;
        address freelancer;
        uint256 amount;
        bool isCompleted;
        bool isBoosted;
    }

    uint256 public bountyCounter;
    mapping(uint256 => Bounty) public bounties;

    uint256 public constant BOOST_COST = 100 * 10 ** 18; // 100 $VEPO assuming 18 decimals

    event BountyPosted(uint256 indexed bountyId, address indexed client, uint256 amount);
    event BountyBoosted(uint256 indexed bountyId, address indexed client);
    event WorkSubmitted(uint256 indexed bountyId, string workLink);
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
            isCompleted: false,
            isBoosted: false
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
        require(!bounty.isCompleted, "Bounty already completed");
        
        bounty.freelancer = msg.sender;
        emit WorkSubmitted(bountyId, workLink);
    }

    function releaseFunds(uint256 bountyId) external nonReentrant {
        Bounty storage bounty = bounties[bountyId];
        require(bounty.client == msg.sender, "Only client can release funds");
        require(!bounty.isCompleted, "Bounty already completed");
        require(bounty.freelancer != address(0), "No freelancer submitted work");

        bounty.isCompleted = true;
        
        uint256 amountToRelease = bounty.amount;
        
        // Use .call{value: amountToRelease}("") instead of .transfer() to support ERC-4337 smart wallets
        (bool success, ) = bounty.freelancer.call{value: amountToRelease}("");
        require(success, "Transfer failed");

        emit FundsReleased(bountyId, bounty.freelancer, amountToRelease);
    }
}
