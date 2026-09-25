# Vepo Network

> **Empowering Decentralization in Finance: Vision 2035**

Vepo Network is a **hyper-deflationary L3 App-Chain** powering a decentralized micro-bounty and freelance economy. Built on Arbitrum Orbit with AnyTrust data availability, it combines trustless escrow, on-chain reputation, and DAO governance with a novel Quadruple Burn tokenomics engine that creates constant deflationary pressure on the $VEPO token.

---

## 🌟 Key Features

| Feature | Description |
|---|---|
| **Trustless Escrow** | Client funds locked in smart contract until work is verified |
| **Quadruple Burn** | Every marketplace action permanently destroys $VEPO |
| **Sequencer Buyback** | L3 gas profits buy & burn $VEPO, with 70% going to stakers |
| **On-Chain Reputation** | Freelancer scores (0–100) stored on-chain, fully portable |
| **DAO Governance** | $VEPO holders vote on protocol parameters |
| **Ghosting Protection** | 7-day time-lock lets freelancers claim if clients disappear |
| **Emergency Controls** | Pausable circuit-breaker for protocol-wide halts |

---

## 📚 Documentation

| Document | Description |
|---|---|
| [WHITEPAPER.md](./docs/WHITEPAPER.md) | Protocol overview, problem statement, and competitive analysis |
| [TOKENOMICS.md](./docs/TOKENOMICS.md) | Supply mechanics, allocation, burns, staking APY model |
| [ARCHITECTURE.md](./docs/ARCHITECTURE.md) | System design, contract interactions, and security model |
| [ROADMAP.md](./docs/ROADMAP.md) | 5-phase delivery plan with milestones |
| [SECURITY.md](./docs/SECURITY.md) | Threat model, audit status, and known limitations |
| [CHANGELOG.md](./docs/CHANGELOG.md) | Version history and release notes |

---

## 🏗️ Smart Contract Suite

| Contract | Purpose | Lines |
|---|---|---|
| `VepoToken.sol` | Fixed-supply ERC-20 (100M, no minting) | ~30 |
| `VepoBounty.sol` | Escrow, marketplace, Quadruple Burn, dispute arbitration | ~300 |
| `VepoStaking.sol` | Treasury buyback engine, 70/30 staker/burn split | ~280 |
| `VepoReputation.sol` | On-chain reputation scoring (0–100) | ~170 |
| `VepoGovernance.sol` | DAO proposal creation, voting, quorum | ~250 |
| `VepoFaucet.sol` | Rate-limited testnet token distribution | ~80 |

All contracts use **OpenZeppelin v5.x** (ERC20Burnable, Ownable, ReentrancyGuard, Pausable) and are compiled with **Solidity ^0.8.20**.

---

## ⚙️ Tech Stack

| Layer | Technology |
|---|---|
| **L3 Infrastructure** | Arbitrum Orbit App-Chain (AnyTrust DA) |
| **Smart Contracts** | Solidity ^0.8.20, Hardhat, OpenZeppelin 5.x |
| **Frontend** | Vue 3, Vite, TypeScript |
| **Web3** | Wagmi, Viem |
| **Styling** | Custom CSS with Glassmorphism |

---

## 🚀 Local Development Guide

### Prerequisites
- Node.js 18+ and npm

### 1. Smart Contract Setup

```bash
cd contracts
npm install
```

**Start the Local Hardhat Node** (keep this terminal open):
```bash
npx hardhat node
```

**Compile & Deploy** (in a second terminal):
```bash
cd contracts
npx hardhat compile
npx hardhat run scripts/deploy.ts --network localhost
```

> The deploy script automatically funds the Faucet and Mock Router, deploys all 6 production contracts, and writes addresses to the frontend `abi.ts`.

**Run Tests:**
```bash
npx hardhat test test/VepoBounty.test.ts
```

**Update ABIs** (after modifying contracts):
```bash
npx hardhat run scripts/updateABI.ts
```

### 2. Frontend Setup

```bash
cd frontend
npm install
```

Create a `.env` file:
```env
VITE_VEPO_RPC_URL=http://127.0.0.1:8545
VITE_CHAIN_ID=2739
```

**Start Dev Server:**
```bash
npm run dev
```

Navigate to `http://localhost:5173`.

### 3. Using the Reserve Faucet

Because Vepo Network uses an absolute genesis supply with zero minting:

1. Connect MetaMask to Localhost 8545 (Chain ID: 2739).
2. Click **"Claim Test $VEPO"** on the frontend to receive 1,000 $VEPO.
3. Import the VepoToken address (printed during deployment) into MetaMask to view your balance.

---

## 📄 License

[MIT License](./LICENSE) — Copyright © 2026 Vepo Network
