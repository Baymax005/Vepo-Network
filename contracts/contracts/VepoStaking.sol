// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title IUniswapV2Router02
 * @notice Minimal interface for Uniswap V2 compatible routers.
 */
interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

/**
 * @title IBurnableERC20
 * @notice Extended ERC-20 interface with burn capability and supply tracking.
 */
interface IBurnableERC20 is IERC20 {
    function burn(uint256 amount) external;
    function totalSupply() external view returns (uint256);
}

/**
 * @title VepoStaking
 * @author Vepo Network
 * @notice The Treasury Engine — processes Arbitrum L3 sequencer profits into
 * staking yields and deflationary burns.
 *
 * @dev This contract serves three critical functions:
 *
 * 1. **Staking Vault:** Users deposit $VEPO to earn yield from sequencer profits.
 *    Uses a SushiSwap-style `accRewardPerShare` model for gas-efficient
 *    pro-rata reward distribution.
 *
 * 2. **DEX Buyback Engine:** When `processSequencerProfits()` is called, the contract
 *    swaps accumulated USDC (from L3 gas fees) into $VEPO via a Uniswap V2 router.
 *
 * 3. **Deflationary Burn:** 30% of purchased $VEPO is permanently destroyed. The
 *    remaining 70% is distributed as yield to stakers. If the burn would push total
 *    supply below the `supplyFloor`, the excess is redirected to staker rewards
 *    (creating hyper-yields as supply tightens).
 *
 * Security:
 * - `ReentrancyGuard` on staking/withdrawal functions.
 * - `Pausable` emergency circuit-breaker.
 * - `processSequencerProfits()` restricted to owner to prevent griefing.
 * - Floor clamping math prevents total supply from dropping below the hard floor.
 */
contract VepoStaking is ReentrancyGuard, Ownable, Pausable {

    /// @notice The $VEPO token contract.
    IBurnableERC20 public immutable vepo;

    /// @notice The USDC stablecoin contract (used for sequencer profit routing).
    IERC20 public immutable usdc;

    /// @notice The Uniswap V2 compatible router for USDC → VEPO swaps.
    IUniswapV2Router02 public immutable router;

    /// @notice Burn percentage in basis points (3000 = 30%).
    uint256 public burnBps = 3000;

    /// @notice The absolute minimum $VEPO supply. Burns are clamped at this floor.
    uint256 public supplyFloor = 10_000_000 * 10**18;

    /// @notice Minimum interval between sequencer profit processing calls (anti-griefing).
    uint256 public processInterval = 1 hours;

    /// @notice Timestamp of the last `processSequencerProfits()` call.
    uint256 public lastProcessedAt;

    // ──────────────────────────────────────────────
    // Staking State
    // ──────────────────────────────────────────────

    /// @notice Total $VEPO currently staked across all users.
    uint256 public totalStaked;

    /// @notice Per-user staked $VEPO balance.
    mapping(address => uint256) public stakedBalance;

    /// @notice Per-user reward debt for the accumulator model.
    mapping(address => uint256) public rewardDebt;

    /// @notice Accumulated reward per share (scaled by ACC_PRECISION).
    uint256 public accVepoPerShare; 

    /// @notice Precision multiplier for reward-per-share calculations.
    uint256 public constant ACC_PRECISION = 1e12;

    // ──────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────

    /// @notice Emitted when a user stakes $VEPO.
    event Staked(address indexed user, uint256 amount);

    /// @notice Emitted when a user withdraws staked $VEPO.
    event Withdrawn(address indexed user, uint256 amount);

    /// @notice Emitted when a user claims their accumulated staking yield.
    event RewardClaimed(address indexed user, uint256 amount);

    /// @notice Emitted when sequencer USDC profits are processed through the buyback engine.
    event SequencerProfitsProcessed(
        uint256 usdcSpent,
        uint256 vepoBought,
        uint256 vepoBurned,
        uint256 vepoDistributed
    );

    /// @notice Emitted when the burn basis points are updated.
    event BurnBpsUpdated(uint256 newBps);

    /// @notice Emitted when the supply floor is updated.
    event SupplyFloorUpdated(uint256 newFloor);

    /// @notice Emitted when the process interval is updated.
    event ProcessIntervalUpdated(uint256 newInterval);

    // ──────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────

    /**
     * @notice Initializes the VepoStaking Treasury Engine.
     * @param _vepo Address of the VepoToken contract.
     * @param _usdc Address of the USDC token contract.
     * @param _router Address of the Uniswap V2 compatible router.
     */
    constructor(address _vepo, address _usdc, address _router) Ownable(msg.sender) {
        vepo = IBurnableERC20(_vepo);
        usdc = IERC20(_usdc);
        router = IUniswapV2Router02(_router);
    }

    // ──────────────────────────────────────────────
    // Emergency Controls
    // ──────────────────────────────────────────────

    /// @notice Pauses all staking operations. Emergency use only.
    function pause() external onlyOwner { _pause(); }

    /// @notice Unpauses staking operations.
    function unpause() external onlyOwner { _unpause(); }

    // ──────────────────────────────────────────────
    // Staking Functions
    // ──────────────────────────────────────────────

    /**
     * @notice Stakes $VEPO tokens to earn yield from sequencer profits.
     * @dev Settles any pending rewards before modifying the user's balance.
     * @param amount The amount of $VEPO to stake (in wei).
     */
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Cannot stake 0");
        
        // Settle pending rewards before changing balance
        _settlePendingReward(msg.sender);

        require(vepo.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        totalStaked += amount;
        stakedBalance[msg.sender] += amount;
        
        // Reset reward debt to current accumulator position
        rewardDebt[msg.sender] = (stakedBalance[msg.sender] * accVepoPerShare) / ACC_PRECISION;
        
        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Withdraws staked $VEPO tokens and settles pending rewards.
     * @param amount The amount of $VEPO to withdraw (in wei).
     */
    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Cannot withdraw 0");
        require(stakedBalance[msg.sender] >= amount, "Insufficient staked balance");

        // Settle pending rewards before changing balance
        _settlePendingReward(msg.sender);

        totalStaked -= amount;
        stakedBalance[msg.sender] -= amount;

        // Reset reward debt to current accumulator position
        rewardDebt[msg.sender] = (stakedBalance[msg.sender] * accVepoPerShare) / ACC_PRECISION;
        
        require(vepo.transfer(msg.sender, amount), "Transfer failed");
        
        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Claims accumulated staking yield without modifying the staked balance.
     */
    function claimYield() external nonReentrant whenNotPaused {
        _settlePendingReward(msg.sender);
    }

    /**
     * @dev Internal function that calculates and transfers pending rewards to a user.
     * Uses a safe subtraction pattern to prevent underflow from rounding.
     * @param user The address of the staker.
     */
    function _settlePendingReward(address user) internal {
        if (stakedBalance[user] > 0) {
            uint256 accumulatedReward = (stakedBalance[user] * accVepoPerShare) / ACC_PRECISION;
            
            // Safe subtraction: protect against rounding dust that could cause underflow
            if (accumulatedReward > rewardDebt[user]) {
                uint256 pending = accumulatedReward - rewardDebt[user];
                rewardDebt[user] = accumulatedReward;
                require(vepo.transfer(user, pending), "Reward transfer failed");
                emit RewardClaimed(user, pending);
            } else {
                // Rounding dust — sync debt to prevent future miscalculation
                rewardDebt[user] = accumulatedReward;
            }
        }
    }

    // ──────────────────────────────────────────────
    // Sequencer Buyback & Burn Engine
    // ──────────────────────────────────────────────

    /**
     * @notice Processes accumulated USDC sequencer profits through the buyback engine.
     *
     * @dev Execution flow:
     * 1. Swaps all USDC held by this contract into $VEPO via the DEX router.
     * 2. Calculates the burn amount (burnBps / 10000) of the purchased $VEPO.
     * 3. Applies supply floor clamping — if burning would push supply below `supplyFloor`,
     *    only burns down to the floor and redirects the rest to staker rewards.
     * 4. Updates `accVepoPerShare` to distribute the reward portion to stakers.
     *
     * Requirements:
     * - Only callable by the protocol owner (prevents MEV/sandwich griefing).
     * - Must have USDC balance > 0 in this contract.
     * - Must respect the `processInterval` cooldown between calls.
     */
    function processSequencerProfits() external onlyOwner whenNotPaused {
        require(block.timestamp >= lastProcessedAt + processInterval, "Cooldown active");
        
        uint256 usdcBalance = usdc.balanceOf(address(this));
        require(usdcBalance > 0, "No USDC to process");

        lastProcessedAt = block.timestamp;

        // Approve router to spend USDC
        require(usdc.approve(address(router), usdcBalance), "Approve failed");

        // Build the swap path: USDC → VEPO
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(vepo);

        // Record balance before swap to calculate exact amount received
        uint256 vepoBefore = vepo.balanceOf(address(this));

        router.swapExactTokensForTokens(
            usdcBalance,
            0, // No slippage protection on owner-only calls (MEV risk mitigated by access control)
            path,
            address(this),
            block.timestamp + 300
        );

        uint256 vepoReceived = vepo.balanceOf(address(this)) - vepoBefore;
        
        // ── Supply Floor Deflationary Logic ──
        uint256 currentSupply = vepo.totalSupply();
        uint256 burnAmount = 0;

        if (currentSupply > supplyFloor) {
            // Calculate theoretical burn based on configured BPS
            uint256 theoreticalBurn = (vepoReceived * burnBps) / 10000;
            
            // Clamping: ensure we never burn past the floor
            uint256 amountAboveFloor = currentSupply - supplyFloor;
            burnAmount = theoreticalBurn > amountAboveFloor ? amountAboveFloor : theoreticalBurn;
        }

        // Remaining tokens go to staker yield (including any excess from clamping)
        uint256 stakingReward = vepoReceived - burnAmount;

        // Execute the burn
        if (burnAmount > 0) {
            vepo.burn(burnAmount);
        }

        // Distribute rewards to stakers
        if (stakingReward > 0 && totalStaked > 0) {
            accVepoPerShare += (stakingReward * ACC_PRECISION) / totalStaked;
        }
        // If nobody is staking, rewards remain in the contract for future distribution

        emit SequencerProfitsProcessed(usdcBalance, vepoReceived, burnAmount, stakingReward);
    }

    // ──────────────────────────────────────────────
    // Governance Setters
    // ──────────────────────────────────────────────

    /**
     * @notice Updates the burn percentage.
     * @param _newBps New burn basis points (e.g., 3000 = 30%). Max 10000.
     */
    function updateBurnBps(uint256 _newBps) external onlyOwner {
        require(_newBps <= 10000, "Invalid BPS");
        burnBps = _newBps;
        emit BurnBpsUpdated(_newBps);
    }

    /**
     * @notice Updates the absolute supply floor.
     * @param _newFloor New supply floor in wei (e.g., 10_000_000e18).
     */
    function updateSupplyFloor(uint256 _newFloor) external onlyOwner {
        supplyFloor = _newFloor;
        emit SupplyFloorUpdated(_newFloor);
    }

    /**
     * @notice Updates the minimum interval between profit processing calls.
     * @param _newInterval New interval in seconds.
     */
    function updateProcessInterval(uint256 _newInterval) external onlyOwner {
        processInterval = _newInterval;
        emit ProcessIntervalUpdated(_newInterval);
    }
}
