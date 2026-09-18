// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface IBurnableERC20 is IERC20 {
    function burn(uint256 amount) external;
    function totalSupply() external view returns (uint256);
}

contract VepoStaking is ReentrancyGuard, Ownable {
    IBurnableERC20 public immutable vepo;
    IERC20 public immutable usdc;
    IUniswapV2Router02 public immutable router;

    uint256 public burnBps = 3000; // 30% default burn
    uint256 public constant SUPPLY_FLOOR = 5000000 * 10**18; // 5 Million VEPO Floor

    // Staking logic variables
    uint256 public totalStaked;
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public rewardDebt;

    uint256 public accVepoPerShare; 
    uint256 public constant ACC_PRECISION = 1e12;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event SequencerProfitsProcessed(uint256 usdcSpent, uint256 vepoBought, uint256 vepoBurned, uint256 vepoStaked);
    event BurnBpsUpdated(uint256 newBps);

    constructor(address _vepo, address _usdc, address _router) Ownable(msg.sender) {
        vepo = IBurnableERC20(_vepo);
        usdc = IERC20(_usdc);
        router = IUniswapV2Router02(_router);
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0");
        
        // Settle pending rewards before changing balance
        _settlePendingReward(msg.sender);

        require(vepo.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        totalStaked += amount;
        stakedBalance[msg.sender] += amount;
        
        // Reset reward debt
        rewardDebt[msg.sender] = (stakedBalance[msg.sender] * accVepoPerShare) / ACC_PRECISION;
        
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot withdraw 0");
        require(stakedBalance[msg.sender] >= amount, "Insufficient staked balance");

        // Settle pending rewards before changing balance
        _settlePendingReward(msg.sender);

        totalStaked -= amount;
        stakedBalance[msg.sender] -= amount;

        // Reset reward debt
        rewardDebt[msg.sender] = (stakedBalance[msg.sender] * accVepoPerShare) / ACC_PRECISION;
        
        require(vepo.transfer(msg.sender, amount), "Transfer failed");
        
        emit Withdrawn(msg.sender, amount);
    }

    function claimYield() external nonReentrant {
        _settlePendingReward(msg.sender);
    }

    function _settlePendingReward(address user) internal {
        if (stakedBalance[user] > 0) {
            uint256 pending = ((stakedBalance[user] * accVepoPerShare) / ACC_PRECISION) - rewardDebt[user];
            if (pending > 0) {
                // We don't reset reward debt here if we are just claiming without changing stake,
                // because we need to update it below anyway to match the current accVepoPerShare.
                rewardDebt[user] = (stakedBalance[user] * accVepoPerShare) / ACC_PRECISION;
                require(vepo.transfer(user, pending), "Reward transfer failed");
                emit RewardClaimed(user, pending);
            }
        }
    }

    function processSequencerProfits() external {
        uint256 usdcBalance = usdc.balanceOf(address(this));
        require(usdcBalance > 0, "No USDC to process");

        // Approve router
        require(usdc.approve(address(router), usdcBalance), "Approve failed");

        // Path for swap
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(vepo);

        // Record balance before swap to calculate exact amount received
        uint256 vepoBefore = vepo.balanceOf(address(this));

        router.swapExactTokensForTokens(
            usdcBalance,
            0, // accept any amount for now
            path,
            address(this),
            block.timestamp + 300
        );

        uint256 vepoReceived = vepo.balanceOf(address(this)) - vepoBefore;
        
        // Supply Floor Deflationary Logic
        uint256 currentSupply = vepo.totalSupply();
        uint256 burnAmount = 0;

        if (currentSupply > SUPPLY_FLOOR) {
            // Calculate theoretical burn based on bps
            uint256 theoreticalBurn = (vepoReceived * burnBps) / 10000;
            
            // Clamping Logic: Ensure we don't burn past the floor
            uint256 amountAboveFloor = currentSupply - SUPPLY_FLOOR;
            if (theoreticalBurn > amountAboveFloor) {
                burnAmount = amountAboveFloor;
            } else {
                burnAmount = theoreticalBurn;
            }
        }

        uint256 stakingReward = vepoReceived - burnAmount;

        if (burnAmount > 0) {
            vepo.burn(burnAmount);
        }

        if (stakingReward > 0 && totalStaked > 0) {
            accVepoPerShare += (stakingReward * ACC_PRECISION) / totalStaked;
        } else if (totalStaked == 0) {
            // If nobody is staking, we shouldn't lock rewards. 
            // We could burn them or leave them for future stakers. We'll leave them in the contract.
        }

        emit SequencerProfitsProcessed(usdcBalance, vepoReceived, burnAmount, stakingReward);
    }

    function updateBurnBps(uint256 _newBps) external onlyOwner {
        require(_newBps <= 10000, "Invalid BPS");
        burnBps = _newBps;
        emit BurnBpsUpdated(_newBps);
    }
}
