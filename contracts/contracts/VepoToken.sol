// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VepoToken
 * @author Vepo Network
 * @notice The native utility and governance token of the Vepo Network L3 App-Chain.
 * @dev Strictly deflationary ERC-20 with an absolute genesis supply of 100,000,000 $VEPO.
 *
 * Key design constraints:
 * - Zero minting capability after genesis — no `mint()` function exists.
 * - Inherits `ERC20Burnable` to expose `burn()` and `burnFrom()` for the
 *   Quadruple Burn fee engine ({VepoBounty}) and the Sequencer Buyback loop ({VepoStaking}).
 * - Total supply can only decrease, never increase, making $VEPO a hard-capped deflationary asset.
 */
contract VepoToken is ERC20, ERC20Burnable, Ownable {
    /**
     * @notice Deploys the VepoToken and mints the entire genesis supply to the deployer.
     * @dev After construction, no further minting is possible. The deployer is responsible
     * for distributing tokens to the Faucet, Router, and other protocol contracts.
     */
    constructor() ERC20("Vepo", "VEPO") Ownable(msg.sender) {
        // Mint exactly 100,000,000 tokens — the absolute, immutable genesis supply.
        _mint(msg.sender, 100_000_000 * 10 ** decimals());
    }
}
