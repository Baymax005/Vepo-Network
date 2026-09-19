# Vepo Network System Architecture

This document provides a technical overview of the Vepo Network smart contract architecture (V3) and data flow.

## Core Smart Contracts

### 1. `VepoToken.sol`
The foundational ERC-20 utility token of the network.
- **Inheritance:** `ERC20`, `ERC20Burnable`, `Ownable`
- **Key Features:**
  - Absolute Genesis Supply of 100,000,000 tokens minted to the deployer.
  - Zero `mint()` capability. 
  - Exposes `burn()` and `burnFrom()` to allow other authorized contracts or users to permanently destroy tokens, securely and transparently updating the `totalSupply()`.

### 2. `VepoFaucet.sol`
The Reserve Faucet, replacing the highly-insecure infinite mint model.
- **Key Features:**
  - Prefunded with a locked reserve of 1,000,000 $VEPO from the Genesis block.
  - Exposes `requestTokens()` with a rigid cooldown timer (`lockTime = 24 hours`).
  - Transfers existing testnet tokens to developers and users for testing the boost mechanics.

### 3. `VepoBounty.sol`
The decentralized Escrow and Freelance gig engine.
- **State Machine:** Bounties progress through strict state enums (`Open`, `Locked`, `Completed`, `Cancelled`).
- **Escrow:** Holds native USDC (or native L3 gas) until the client approves the submitted work. Follows the Checks-Effects-Interactions pattern for maximum re-entrancy protection.
- **Boosting (`boostBounty`)**: Clients can pay a `boostFee` (adjustable by admin). The contract securely invokes `vepo.burnFrom(msg.sender, boostFee)` to permanently destroy the gig fee.

### 4. `VepoStaking.sol`
The Treasury, Yield, and Deflationary Buyback engine.
- **State Variables:** Tracks `totalStaked`, user `stakedBalance`, and accrued `rewardDebt`.
- **The Value Capture Loop (`processSequencerProfits`):**
  1. The contract accumulates USDC representing the L3 network's gas fees.
  2. The function triggers an approval and calls the Uniswap V2 Router (`MockUniswapV2Router` in development).
  3. The DEX swaps the USDC for $VEPO and returns it to the Staking contract.
  4. The contract checks the $VEPO `totalSupply()`.
  5. It computes the theoretical burn (default 30%) and clamps it against the `SUPPLY_FLOOR` (5,000,000 tokens).
  6. It calls `vepo.burn()` on the calculated burn amount.
  7. The remainder is injected into the global `accVepoPerShare` debt pool, where active stakers can passively harvest it via `claimYield()`.

## Data Flow Diagram
```mermaid
graph TD
    Client[Client] -->|Posts Bounty with USDC| VepoBounty
    Freelancer[Freelancer] -->|Submits Work| VepoBounty
    VepoBounty -->|Releases USDC| Freelancer
    
    Client -->|Pays VEPO Boost Fee| VepoBounty
    VepoBounty -->|burnFrom()| VepoToken
    
    Sequencer[Arbitrum L3 Sequencer] -->|Routes USDC Gas Profits| VepoStaking
    VepoStaking -->|USDC| DEX[UniswapV2 Router]
    DEX -->|VEPO| VepoStaking
    
    VepoStaking -->|burn() 30%| VepoToken
    VepoStaking -->|70% Yield| Stakers[VEPO Stakers]
```
