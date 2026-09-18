# Vepo Network: Gasless Micro-Bounty Platform

## Project Vision & Overview
Vepo Network is an **Arbitrum Orbit Layer 3 (L3) App-Chain** designed specifically to power a zero-friction, decentralized micro-bounty economy. By utilizing a custom **USDC native gas token** and **AnyTrust Data Availability (DA)**, Vepo eliminates the traditional friction of volatile gas fees (like ETH) while providing lightning-fast, ultra-cheap transactions. It acts as a borderless, global protocol for the freelance economy.

## Core Tech Stack
- **Smart Contracts:** Solidity, Hardhat, OpenZeppelin
- **Frontend Framework:** Vue 3, Vite
- **Web3 Integration:** Wagmi, Viem (TypeScript)

## Dual-Token Architecture
Vepo operates on a dual-token model to provide a seamless user experience:
1. **USDC (Native Gas & Escrow):** At the protocol level, Vepo is configured to use USDC as its native gas token. This means standard `msg.value` and `payable` transfers inherently represent USDC, avoiding the need for complex stablecoin approvals for basic bounties.
2. **$VEPO (Platform Utility Token):** An ERC-20 token used natively within the ecosystem. Clients can spend 100 $VEPO to "Boost" their bounties, increasing their visibility on the platform.

## Smart Contract Overview
The platform is powered by two highly optimized and secure smart contracts:

- **`VepoBounty.sol` (The Escrow Engine):** A decentralized escrow contract managing the entire lifecycle of a gig. It utilizes a strict State Machine (`Open`, `Locked`, `Completed`, `Cancelled`) to prevent race conditions. 
  - **Security:** Fully protected against re-entrancy attacks by inheriting OpenZeppelin's `ReentrancyGuard` and strictly enforcing the **Checks-Effects-Interactions** pattern (e.g., zeroing out `bounty.amount` before executing `.call` transfers to freelancers).
  
- **`VepoToken.sol` (Utility Token):** A standard ERC-20 implementation with a fixed supply of 100,000,000 $VEPO minted at genesis. It includes a rate-limited faucet (max 1,000 VEPO per 24 hours per address) for local testnet development.

## Local Setup & Installation

To run the Vepo development environment locally on your machine, follow these steps:

1. **Clone the repository:**
   ```bash
   git clone git@github.com:Baymax005/Vepo-Network.git
   cd Vepo-Network
   ```

2. **Install Smart Contract Dependencies:**
   ```bash
   cd contracts
   npm install
   ```

3. **Install Frontend Dependencies:**
   ```bash
   cd ../frontend
   npm install
   ```

4. **Start the Development Environment:**
   You can easily spin up the Hardhat local node, deploy the contracts, and start the Vue frontend by running the automated batch script from the project root:
   ```bash
   cd ..
   ./start_dev.bat
   ```
   *(The frontend will be available at `http://localhost:5173`)*

## Environment Variables
Create a `.env` file in the root of your `frontend` directory using the `.env.example` template:

```env
# frontend/.env
VITE_VEPO_RPC_URL=http://127.0.0.1:8545
VITE_CHAIN_ID=2739
# Add any future wallet connect project IDs or third-party keys here
```

## Authorship & Genesis
Vepo Network is a borderless, global protocol designed to empower the freelance economy by removing intermediaries and gas volatility. 

This architecture was incubated as part of the **"Empowering Decentralization in Finance: Vision 2035"** initiative. 
- **Core Architect:** Muhammad Ali
