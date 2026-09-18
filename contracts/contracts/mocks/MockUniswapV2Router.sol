// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// A very simplified mock router just for testing the buyback
contract MockUniswapV2Router {
    IERC20 public usdc;
    IERC20 public vepo;
    
    // We'll set a fixed exchange rate for the mock: 1 USDC = 10 VEPO
    uint256 public exchangeRate = 10;
    
    constructor(address _usdc, address _vepo) {
        usdc = IERC20(_usdc);
        vepo = IERC20(_vepo);
    }
    
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        require(path[0] == address(usdc) && path[path.length - 1] == address(vepo), "Invalid mock path");
        
        // Take USDC from sender
        require(usdc.transferFrom(msg.sender, address(this), amountIn), "USDC transfer failed");
        
        // Calculate VEPO output
        uint256 amountOut = amountIn * exchangeRate;
        require(amountOut >= amountOutMin, "Insufficient output amount");
        
        // Give VEPO to receiver (the mock router must be pre-funded with VEPO for this to work)
        require(vepo.transfer(to, amountOut), "VEPO transfer failed");
        
        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
        return amounts;
    }
}
