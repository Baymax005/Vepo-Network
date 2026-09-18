// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VepoToken is ERC20, Ownable {
    constructor() ERC20("Vepo", "VEPO") Ownable(msg.sender) {
        // Mint 100,000,000 tokens to deployer
        _mint(msg.sender, 100000000 * 10 ** decimals());
    }

    mapping(address => uint256) public lastFaucetTime;
    uint256 public constant FAUCET_COOLDOWN = 1 days;
    uint256 public constant FAUCET_AMOUNT = 1000 * 10 ** 18;

    // Faucet for testing the boost feature (rate limited)
    function faucet(address to) external {
        require(block.timestamp >= lastFaucetTime[to] + FAUCET_COOLDOWN, "Faucet cooldown active");
        lastFaucetTime[to] = block.timestamp;
        _mint(to, FAUCET_AMOUNT);
    }
}
