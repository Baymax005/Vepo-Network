# Vepo Network

<div align="center">

**Empowering Decentralization in Finance: Vision 2035**

*A Hyper-Deflationary L3 App-Chain for the Global Freelance Economy & Cross-Border Payments*

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Solidity](https://img.shields.io/badge/Solidity-%5E0.8.20-363636?logo=solidity)](https://soliditylang.org/)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-v5.x-4E5EE4?logo=openzeppelin)](https://openzeppelin.com/)
[![Hardhat](https://img.shields.io/badge/Hardhat-2.x-FFF100?logo=data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAiIGhlaWdodD0iMjAiIHZpZXdCb3g9IjAgMCAyMCAyMCI+PHJlY3Qgd2lkdGg9IjIwIiBoZWlnaHQ9IjIwIiBmaWxsPSIjRkZGMTAwIi8+PC9zdmc+)](https://hardhat.org/)
[![Vue.js](https://img.shields.io/badge/Vue.js-3.x-4FC08D?logo=vue.js)](https://vuejs.org/)
[![Arbitrum](https://img.shields.io/badge/Arbitrum-L3%20Orbit-28A0F0?logo=arbitrum)](https://arbitrum.io/)

</div>

---

## 🌐 What is Vepo Network?

Vepo Network is a **decentralized micro-bounty marketplace and cross-border payment rail** deployed as a dedicated Arbitrum L3 App-Chain. It enables trustless freelance hiring with instant USDC payments, on-chain reputation, and DAO governance — all powered by a novel deflationary token economy.

### The Problem
- Centralized platforms (Upwork, Fiverr) charge **20–30% fees** and hold payments for weeks.
- Cross-border freelancers lose **6–10%** of earnings to remittance fees and FX spreads.
- Freelancer reputations are **locked to platforms** — you can't take your ratings with you.

### Our Solution
- **Near-zero fees:** Only small $VEPO burns (~$0.10) instead of percentage-based platform cuts.
- **Instant USDC payments:** Freelancers receive stablecoins in < 2 seconds via L3 escrow.
- **Portable reputation:** On-chain scores (0–100) owned by the freelancer, not the platform.
- **Dedicated infrastructure:** Own L3 chain = own sequencer revenue = staker yields.

---

## 🌟 Key Features

| Feature | Description |
|---|---|
| **Trustless Escrow** | Client USDC locked in smart contract until work is verified |
| **Quadruple Burn** | Every marketplace action permanently destroys $VEPO — listing, applying, boosting, cancelling |
| **Sequencer Buyback** | L3 gas profits buy & burn $VEPO, with 70% going to stakers |
| **Cross-Border Remittance** | USDC payments settle globally in < 2s with sub-cent fees |
| **On-Chain Reputation** | Freelancer scores (0–100) stored on-chain, fully portable |
| **DAO Governance** | $VEPO holders vote on protocol parameters (fees, burn rate, supply floor) |
| **Ghosting Protection** | 7-day time-lock lets freelancers claim if clients disappear |
| **Supply Floor Safety** | 10M $VEPO floor — once reached, fees redirect to stakers instead of burning |
| **Emergency Controls** | Pausable circuit-breaker for protocol-wide halts |

---

## 📚 Documentation

| Document | Description |
|---|---|
| [Whitepaper](./docs/WHITEPAPER.md) | Protocol overview, problem statement, remittance use case, and competitive analysis |
| [Tokenomics](./docs/TOKENOMICS.md) | Supply mechanics, allocation, Quadruple Burn, staking APY, supply floor math |
| [Architecture](./docs/ARCHITECTURE.md) | System design, L3 justification, contract interactions, security model |
| [Roadmap](./docs/ROADMAP.md) | 5-phase delivery plan — testnet first, mainnet 2028 |
| [Security](./docs/SECURITY.md) | Threat model, audit status, and known limitations |
| [Changelog](./docs/CHANGELOG.md) | Version history and release notes |
| [Contributing](./CONTRIBUTING.md) | How to contribute to the project |

---

## 🏗️ Smart Contract Suite

All contracts are compiled with **Solidity ^0.8.20** and use battle-tested **OpenZeppelin v5.x** libraries.

| Contract | Purpose | Security |
|---|---|---|
| [`VepoToken.sol`](./contracts/contracts/VepoToken.sol) | Fixed-supply ERC-20 (100M, zero minting) | ERC20Burnable, Ownable |
| [`VepoBounty.sol`](./contracts/contracts/VepoBounty.sol) | Escrow, marketplace, Quadruple Burn, dispute arbitration | ReentrancyGuard, Pausable, Ownable |
| [`VepoStaking.sol`](./contracts/contracts/VepoStaking.sol) | Treasury buyback engine, 70/30 staker/burn split | ReentrancyGuard, Pausable, Ownable |
| [`VepoReputation.sol`](./contracts/contracts/VepoReputation.sol) | On-chain reputation scoring (0–100) | Ownable, authorized callers |
| [`VepoGovernance.sol`](./contracts/contracts/VepoGovernance.sol) | DAO proposal creation, weighted voting, quorum | Ownable |
| [`VepoFaucet.sol`](./contracts/contracts/VepoFaucet.sol) | Rate-limited testnet token distribution | Ownable |

### Contract Interaction Overview

```
Client ──→ VepoBounty (USDC Escrow + $VEPO Fee Burn) ──→ Freelancer (USDC Payment)
                │                                              │
                ├── VepoReputation (Score Update)              │
                └── VepoToken (Fee Burn / Redirect)            │
                                                               │
L3 Sequencer ──→ VepoStaking (USDC→VEPO Swap) ──→ 70% Stakers │ 30% Burn
                                                               │
$VEPO Holders ──→ VepoGovernance (Propose & Vote) ─────────────┘
```

---

## ⚙️ Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| **L1** | Ethereum Mainnet | Final settlement & security |
| **L2** | Arbitrum One | Rollup bridge |
| **L3** | Arbitrum Orbit (AnyTrust DA) | Dedicated app-chain, USDC gas token |
| **Contracts** | Solidity ^0.8.20, Hardhat, OpenZeppelin 5.x | Core protocol logic |
| **Frontend** | Vue 3, Vite, TypeScript | Web3 dApp interface |
| **Web3** | Wagmi, Viem | Wallet connection, contract reads/writes |
| **Styling** | Custom CSS with Glassmorphism | Dark-mode premium UI |

---

## 🚀 Getting Started

### Prerequisites
- **Node.js** 18+ and **npm**
- **Git**

### 1. Clone & Install

```bash
git clone https://github.com/Baymax005/Vepo-Network.git
cd Vepo-Network
```

### 2. Smart Contract Setup

```bash
cd contracts
npm install
```

**Start the local Hardhat node** (keep this terminal open):
```bash
npx hardhat node
```

**Compile & Deploy** (in a second terminal):
```bash
cd contracts
npx hardhat compile
npx hardhat run scripts/deploy.ts --network localhost
```

> The deploy script automatically funds the Faucet and Mock Router, deploys all 6 production contracts + 2 test mocks, links VepoStaking into VepoBounty for supply floor enforcement, and writes all addresses to the frontend `abi.ts`.

**Run Tests:**
```bash
npx hardhat test
```

### 3. Frontend Setup

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

### 4. Using the Reserve Faucet

Because Vepo Network uses an absolute genesis supply with **zero minting**:

1. Connect MetaMask to Localhost 8545 (Chain ID: 2739).
2. Click **"Claim Test $VEPO"** on the frontend to receive 1,000 $VEPO.
3. Import the VepoToken address (printed during deployment) into MetaMask to view your balance.

---

## 🗺️ Roadmap

| Phase | Timeline | Status | Key Deliverables |
|---|---|---|---|
| **Foundation** | Q3 2026 | ✅ Complete | Core contracts, testnet, Vue frontend |
| **Ecosystem** | Q4 2026 | 🔄 In Progress | Reputation, governance, block explorer, testing |
| **Public Testnet** | 2027 | 📋 Planned | Security audit, bug bounties, public testnet scaling |
| **Mainnet** | 2028 | 📋 Planned | Mainnet launch (grant-funded), DEX listing, mobile app |
| **Decentralization** | 2029+ | 📋 Planned | Full DAO control, cross-chain bridges |

See the full [Roadmap](./docs/ROADMAP.md) for details.

---

## 🤝 Contributing

We welcome contributions! Please read our [Contributing Guide](./CONTRIBUTING.md) for guidelines on how to get involved.

---

## 📄 License

[MIT License](./LICENSE) — Copyright © 2026 Vepo Network

---

<div align="center">

**Built with ❤️ for the decentralized future of work**

[Whitepaper](./docs/WHITEPAPER.md) · [Tokenomics](./docs/TOKENOMICS.md) · [Architecture](./docs/ARCHITECTURE.md) · [Roadmap](./docs/ROADMAP.md)

</div>
