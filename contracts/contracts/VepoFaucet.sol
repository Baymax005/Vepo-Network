// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VepoFaucet is Ownable {
    IERC20 public immutable vepoToken;
    
    uint256 public dripAmount = 1000 * 10**18;
    uint256 public lockTime = 24 hours;
    
    mapping(address => uint256) public nextAccessTime;
    
    event FaucetDripped(address indexed to, uint256 amount);
    event DripAmountUpdated(uint256 newAmount);

    constructor(address _vepoToken) Ownable(msg.sender) {
        vepoToken = IERC20(_vepoToken);
    }
    
    function requestTokens() external {
        require(block.timestamp >= nextAccessTime[msg.sender], "Faucet cooldown active");
        require(vepoToken.balanceOf(address(this)) >= dripAmount, "Faucet empty, please wait for refill");
        
        nextAccessTime[msg.sender] = block.timestamp + lockTime;
        require(vepoToken.transfer(msg.sender, dripAmount), "Transfer failed");
        
        emit FaucetDripped(msg.sender, dripAmount);
    }
    
    function setDripAmount(uint256 _amount) external onlyOwner {
        dripAmount = _amount;
        emit DripAmountUpdated(_amount);
    }
    
    function withdrawTokens(uint256 _amount) external onlyOwner {
        require(vepoToken.transfer(msg.sender, _amount), "Transfer failed");
    }
}
