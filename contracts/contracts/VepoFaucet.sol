// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VepoFaucet
 * @author Vepo Network
 * @notice A rate-limited testnet reserve faucet for distributing $VEPO to new users.
 *
 * @dev Key design decisions:
 * - Pre-funded from the genesis supply (no minting) — preserves the hard cap.
 * - 24-hour cooldown per address to prevent draining.
 * - Configurable drip amount for testnet tuning.
 * - Owner can withdraw remaining tokens if the faucet needs to be migrated.
 */
contract VepoFaucet is Ownable {
    /// @notice The $VEPO token distributed by this faucet.
    IERC20 public immutable vepoToken;
    
    /// @notice Amount of $VEPO dispensed per claim (default: 1,000 $VEPO).
    uint256 public dripAmount = 1000 * 10**18;

    /// @notice Cooldown period between claims per address (default: 24 hours).
    uint256 public lockTime = 24 hours;
    
    /// @notice Tracks the earliest time each address can next claim.
    mapping(address => uint256) public nextAccessTime;
    
    /// @notice Emitted when tokens are dispensed from the faucet.
    event FaucetDripped(address indexed to, uint256 amount);

    /// @notice Emitted when the drip amount is updated.
    event DripAmountUpdated(uint256 newAmount);

    /// @notice Emitted when the cooldown period is updated.
    event LockTimeUpdated(uint256 newLockTime);

    /**
     * @notice Initializes the faucet.
     * @param _vepoToken Address of the VepoToken contract.
     */
    constructor(address _vepoToken) Ownable(msg.sender) {
        vepoToken = IERC20(_vepoToken);
    }
    
    /**
     * @notice Claims $VEPO from the faucet.
     * @dev Each address can claim once per `lockTime` period.
     *
     * Requirements:
     * - Caller's cooldown must have expired.
     * - Faucet must have sufficient $VEPO balance.
     */
    function requestTokens() external {
        require(block.timestamp >= nextAccessTime[msg.sender], "Faucet cooldown active");
        require(vepoToken.balanceOf(address(this)) >= dripAmount, "Faucet empty, please wait for refill");
        
        nextAccessTime[msg.sender] = block.timestamp + lockTime;
        require(vepoToken.transfer(msg.sender, dripAmount), "Transfer failed");
        
        emit FaucetDripped(msg.sender, dripAmount);
    }
    
    /**
     * @notice Updates the amount dispensed per claim.
     * @param _amount New drip amount in wei.
     */
    function setDripAmount(uint256 _amount) external onlyOwner {
        dripAmount = _amount;
        emit DripAmountUpdated(_amount);
    }

    /**
     * @notice Updates the cooldown period between claims.
     * @param _lockTime New cooldown in seconds.
     */
    function setLockTime(uint256 _lockTime) external onlyOwner {
        lockTime = _lockTime;
        emit LockTimeUpdated(_lockTime);
    }
    
    /**
     * @notice Withdraws $VEPO from the faucet (for migration or emergency).
     * @param _amount Amount to withdraw in wei.
     */
    function withdrawTokens(uint256 _amount) external onlyOwner {
        require(vepoToken.transfer(msg.sender, _amount), "Transfer failed");
    }
}
