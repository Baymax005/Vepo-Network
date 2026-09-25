# Vepo Network Changelog

## [V4.0: The Governance Expansion] - 2026-09-25
### Added
- **`VepoReputation.sol`**: Deployed an on-chain reputation scoring system.
  - Tracks freelancer `jobsCompleted`, `jobsFailed`, and `totalEarned`.
  - Computes a 0–100 reputation score via `getReputationScore()`.
  - Only authorized contracts (VepoBounty) or the owner can update scores.
  - Maintains a registry of all freelancers who have interacted with the protocol.
- **`VepoGovernance.sol`**: Deployed a DAO voting module for progressive decentralization.
  - $VEPO holders above the proposal threshold (10,000 $VEPO) can create governance proposals.
  - Weighted voting based on $VEPO balance at time of vote.
  - Quorum enforcement (100,000 $VEPO minimum total votes).
  - Full proposal lifecycle: Active → Passed/Rejected → Executed/Cancelled.
- **Emergency Circuit Breaker**: Added OpenZeppelin `Pausable` to both `VepoBounty` and `VepoStaking`.
  - `pause()` and `unpause()` functions with `onlyOwner` restriction.
  - `whenNotPaused` guard on all user-facing marketplace and staking functions.
- **Batch Fee Setter**: Added `setFees()` function to `VepoBounty` for updating all four Quadruple Burn fees in one transaction.
  - Emits `FeesUpdated` event for off-chain indexing.
- **Process Cooldown**: Added `processInterval` to `VepoStaking` to prevent griefing on the buyback engine.
- **Safe Reward Math**: Added rounding-safe subtraction in `_settlePendingReward()` to prevent arithmetic edge cases.

### Changed
- **`VepoStaking.sol`**: `processSequencerProfits()` is now `onlyOwner` to prevent MEV sandwich attacks.
  - Added `SupplyFloorUpdated` and `ProcessIntervalUpdated` events.
- **`VepoFaucet.sol`**: Added `setLockTime()` for configurable cooldown periods.
  - Added `LockTimeUpdated` event.
- **Deployment Script**: Updated `deploy.ts` to deploy VepoReputation and VepoGovernance alongside core contracts.
  - Professional formatted output with deployment summary table.
  - Exports `REPUTATION_ADDRESS` and `GOVERNANCE_ADDRESS` to frontend `abi.ts`.
- **TestnetSandbox.vue**: Fixed broken `setFees()` call (previously referenced a non-existent function).
  - Added Emergency Pause/Unpause controls in the sandbox UI.

### Documentation
- **Rewrote** `TOKENOMICS.md` with allocation table, vesting schedule, burn projections, and staking APY model.
- **Rewrote** `ARCHITECTURE.md` with L3 justification, AnyTrust DA explanation, state machine diagrams, contract interaction matrix, and security architecture.
- **Created** `WHITEPAPER.md` — comprehensive protocol overview with problem statement, competitive analysis, and use cases.
- **Created** `ROADMAP.md` — 5-phase delivery plan from foundation through full decentralization.
- **Created** `SECURITY.md` — threat model, security mechanisms, audit status, and responsible disclosure policy.
- **Updated** `README.md` with professional project overview and documentation links.

### Security
- Full NatSpec documentation added to all 6 production smart contracts.
- All event parameters marked `indexed` where appropriate for efficient log filtering.
- Comprehensive `@dev` annotations documenting security assumptions and invariants.

## [V3: The Deflationary Ecosystem] - 2026-09-18
### Added
- **`VepoStaking.sol`**: Deployed the treasury and staking engine.
  - Implemented the 70/30 DEX Buyback mechanism to route sequencer USDC profits into $VEPO.
  - Implemented the **10 Million Supply Floor**. Burn calculations use clamping math to prevent the token supply from ever dropping below 10M.
- **`VepoFaucet.sol`**: Deployed a standalone, rate-limited reserve faucet.
  - Prefunded with exactly 1,000,000 $VEPO from the Genesis block to guarantee a hard cap on total supply.
- **Mock Environment**: Added `MockUSDC` and `MockUniswapV2Router` to the local Hardhat environment for testing the sequencer buyback logic.
- **Smart Frontend Logic**: Upgraded `CreateBounty.vue` on the frontend. The UI now intelligently reads the user's current ERC-20 allowance and skips the MetaMask `approve` pop-up if the user has already granted sufficient allowance for the gig boost.
- **Testing**: Added `scripts/testStaking.ts` to simulate sequencer profits and mathematically prove the DEX buyback and burn logic on localhost.

### Changed
- **`VepoToken.sol`**: Inherited OpenZeppelin's `ERC20Burnable` to expose `burn()` and `burnFrom()`. Removed the old infinite-mint faucet logic.
- **`VepoBounty.sol`**: Upgraded the `boostBounty()` function to execute a "True Burn". Instead of transferring gig fees to a treasury address, the 100 $VEPO fee is permanently burned via `vepo.burnFrom()`, reducing the absolute total supply of the network.
- **Deployment Script**: Upgraded `deploy.ts` to deploy the Mocks, Faucet, and Staking contracts, automatically fund the Faucet/Router, and export all new contract addresses to the frontend `abi.ts`.

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
