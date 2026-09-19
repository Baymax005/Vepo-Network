# Vepo Network
> Empowering Decentralization in Finance: Vision 2035

Vepo Network is a decentralized micro-bounty and freelance economy deployed as an Arbitrum L3 App-Chain. It operates on a robust, highly deflationary dual-token architecture utilizing native USDC for protocol gas/escrow and the $VEPO ERC-20 token for utility, ecosystem boosting, and decentralized governance.

## Project Documentation
Please refer to the following comprehensive guides to understand the core Vepo Network systems:
* [TOKENOMICS.md](./docs/TOKENOMICS.md) - Explains the True Burn mechanics, the 100M absolute Genesis Supply, the Treasury Buyback loop, and the 5M Supply Floor.
* [ARCHITECTURE.md](./docs/ARCHITECTURE.md) - Technical system design and smart contract data flow diagram.

---

## Tech Stack
* **Smart Contracts**: Solidity ^0.8.20, Hardhat, OpenZeppelin (ERC20Burnable, Ownable, ReentrancyGuard)
* **Frontend UI**: Vue 3, Vite, TailwindCSS
* **Web3 Integration**: Wagmi, Viem
* **Blockchain Infrastructure**: Arbitrum Orbit L3 App-Chain with AnyTrust DA

---

## Local Development Guide

Follow these steps to spin up the entire Vepo Network (V3 Tokenomics Engine) locally using the Hardhat network.

### 1. Prerequisites
Ensure you have `node` and `npm` installed.

### 2. Smart Contract Setup & Deployment
Open a terminal and navigate to the `contracts/` directory to compile and deploy the Vepo Network stack (Tokens, Mocks, Faucets, Staking, and Bounties).

```bash
cd contracts
npm install
```

**Start the Local Hardhat Node:**
In this terminal, spin up the local blockchain. Keep this terminal window open.
```bash
npx hardhat node
```

**Compile and Deploy:**
Open a **second terminal window**, navigate back to `contracts/`, and run the automated deployment script.
```bash
cd contracts
npx hardhat compile
npx hardhat run scripts/deploy.ts --network localhost
```
*Note: This script automatically handles funding the `VepoFaucet` and the `MockUniswapV2Router`, and dynamically writes the deployed contract addresses into the Vue frontend `abi.ts` file!*

### 3. Frontend Setup
Open a **third terminal window** and navigate to the `frontend/` directory.

```bash
cd frontend
npm install
```

Create a `.env` file in the `frontend` folder:
```env
VITE_VEPO_RPC_URL=http://127.0.0.1:8545
VITE_CHAIN_ID=2739
```
*(Note: Ensure your Hardhat node or actual network is running on the official Vepo Testnet ID 2739).*

**Start the Web Server (Development):**
```bash
npm run dev
```
Navigate to `http://localhost:5173` in your browser.

**Build for Production:**
```bash
npm run build
```
Navigate to `http://localhost:5173` in your browser.

### 4. Using the Reserve Faucet
Because Vepo Network relies on an absolute Genesis Supply with zero infinite minting, developers must use the pre-funded **Reserve Faucet** to obtain testnet $VEPO.
1. Connect your MetaMask wallet (configured for your Localhost 8545 network).
2. Use the "Claim Test $VEPO" functionality on the frontend UI to interact with the `VepoFaucet.sol` contract and request your 1,000 $VEPO drip.
3. Import the `VepoToken` address printed during the Hardhat deployment into MetaMask to view your balance.
