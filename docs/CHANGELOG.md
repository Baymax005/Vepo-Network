# Vepo Network Changelog

## [V3: The Deflationary Ecosystem] - 2026-09-18
### Added
- **`VepoStaking.sol`**: Deployed a new treasury and staking engine.
  - Implemented the 70/30 DEX Buyback mechanism to route sequencer USDC profits into $VEPO.
  - Implemented the **5 Million Supply Floor**. Burn calculations now use clamping math to prevent the token supply from ever dropping below 5M.
- **`VepoFaucet.sol`**: Deployed a new standalone, rate-limited reserve faucet.
  - Prefunded with exactly 1,000,000 $VEPO from the Genesis block to guarantee a hard cap on total supply.
- **Mock Environment**: Added `MockUSDC` and `MockUniswapV2Router` to the local Hardhat environment for testing the sequencer buyback logic.
- **Smart Frontend Logic**: Upgraded `CreateBounty.vue` on the frontend. The UI now intelligently reads the user's current ERC-20 allowance and skips the MetaMask `approve` pop-up if the user has already granted sufficient allowance for the gig boost.
- **Testing**: Added `scripts/testStaking.ts` to simulate sequencer profits and mathematically prove the DEX buyback and burn logic on localhost.

### Changed
- **`VepoToken.sol`**: Inherited OpenZeppelin's `ERC20Burnable` to expose `burn()` and `burnFrom()`. Removed the old infinite-mint faucet logic.
- **`VepoBounty.sol`**: Upgraded the `boostBounty()` function to execute a "True Burn". Instead of transferring gig fees to a treasury address, the 100 $VEPO fee is permanently burned via `vepo.burnFrom()`, reducing the absolute total supply of the network.
- **Deployment Script**: Upgraded `deploy.ts` to deploy the Mocks, Faucet, and Staking contracts, automatically fund the Faucet/Router, and export all new contract addresses to the frontend `abi.ts`.

### Documentation
- Created `docs/TOKENOMICS.md` to outline the V3 dual-token economy, absolute genesis supply, and deflationary burn mechanisms.
- Created `docs/ARCHITECTURE.md` to map the smart contract ecosystem and data flow.
- Updated `README.md` with complete developer instructions for the new environment.

## [V2: The Boost Economy] - Previous Iteration
### Added
- **Gig Boosting**: Introduced the `boostBounty()` mechanic to `VepoBounty.sol`, requiring clients to pay a 100 $VEPO fee to boost their gig visibility.
- **Infinite Mint Faucet**: Added a basic `faucet()` function directly into `VepoToken.sol` to allow testnet users to mint $VEPO freely for testing the boost mechanic (deprecated in V3).
- **Frontend Integration**: Updated `CreateBounty.vue` to include a toggle switch for boosting gigs and a button to claim tokens from the faucet. Added wagmi hooks for blockchain writes.

## [V1: The Micro-Bounty Protocol] - Initial Release
### Added
- **`VepoToken.sol`**: Deployed the core ERC-20 token with a standard 100,000,000 genesis supply.
- **`VepoBounty.sol`**: Built the foundational decentralized escrow contract for the gig economy. 
  - Functions: `postBounty`, `submitWork`, `releaseFunds`, `cancelBounty`, `rejectWork`.
- **Frontend Foundation**: Scaffolded a Vue.js + Vite Web3 frontend using Wagmi/Viem. Implemented wallet connection, balance fetching, and basic bounty listing UI.
