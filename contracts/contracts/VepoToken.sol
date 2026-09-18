// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VepoToken is ERC20, Ownable {
    constructor() ERC20("Vepo", "VEPO") Ownable(msg.sender) {
        // Mint 100,000,000 tokens to deployer
        _mint(msg.sender, 100000000 * 10 ** decimals());
    }

    // Faucet for testing the boost feature
    function faucet(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
