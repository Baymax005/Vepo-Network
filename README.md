# Vepo Gasless Micro-Bounty Board MVP

Vepo is a gasless micro-bounty board built on an Arbitrum Orbit Layer 3 App-Chain. The network uses USDC as the native gas token.

## Dual-Token Model
- **Gas Token:** USDC is configured as the native gas token at the protocol level. All transactions use USDC for gas natively.
- **Utility Token:** `$VEPO` (an ERC-20 token) is used within the platform to access premium features such as boosting bounties.

## Architecture
- **Phase 1: Smart Contracts** - Hardhat project containing `VepoToken.sol` and `VepoBounty.sol`.
- **Phase 2: Frontend** - Vue 3 + Wagmi UI for posting and browsing bounties with a glassmorphism design.

## License
Currently MIT License. Note: Before mainnet launch, this will transition to the Business Source License (BUSL).
