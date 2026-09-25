# Contributing to Vepo Network

Thank you for your interest in contributing to Vepo Network! This guide will help you get started.

## 🚀 How to Contribute

### 1. Fork & Clone

```bash
git clone https://github.com/<your-username>/Vepo-Network.git
cd Vepo-Network
```

### 2. Create a Branch

```bash
git checkout -b feature/your-feature-name
```

Use descriptive branch names:
- `feature/add-skill-badges` — new features
- `fix/staking-reward-underflow` — bug fixes
- `docs/update-tokenomics` — documentation changes

### 3. Make Your Changes

- **Smart Contracts:** Edit files in `contracts/contracts/`. Run `npx hardhat compile` to verify.
- **Frontend:** Edit files in `frontend/src/`. Run `npm run dev` to preview.
- **Documentation:** Edit files in `docs/`.

### 4. Test Your Changes

```bash
cd contracts
npx hardhat test
```

All existing tests must pass before submitting a PR.

### 5. Submit a Pull Request

Push your branch and open a PR against `main`. Include:
- A clear description of what your changes do.
- Which issue (if any) your PR addresses.
- Screenshots for UI changes.

---

## 📝 Code Standards

### Solidity
- Use **Solidity ^0.8.20** and **OpenZeppelin v5.x**.
- Add **NatSpec** comments (`@notice`, `@dev`, `@param`, `@return`) to all public/external functions.
- Follow the **Checks-Effects-Interactions (CEI)** pattern for all fund transfers.
- Use `nonReentrant` on any function that transfers ETH or tokens.
- Emit events for all state-changing operations.

### Frontend (Vue 3 + TypeScript)
- Use the Composition API (`<script setup>`).
- Type all props and emits.
- Keep components focused and reusable.

### Documentation
- Use clear, concise language.
- Include tables and diagrams where they improve readability.
- Keep the changelog updated for all significant changes.

---

## 🐛 Reporting Issues

Found a bug? Please open an issue with:
1. **Steps to reproduce** the problem.
2. **Expected behavior** vs. **actual behavior**.
3. **Environment** (Node.js version, OS, browser).

### Security Vulnerabilities

**Do NOT open a public issue for security vulnerabilities.** Please see our [Security Policy](./docs/SECURITY.md) for responsible disclosure instructions.

---

## 💡 Feature Requests

We welcome ideas! Open an issue with the `enhancement` label and describe:
- What problem does this feature solve?
- How would it work from a user's perspective?
- Any technical considerations?

---

## 📜 License

By contributing, you agree that your contributions will be licensed under the [MIT License](./LICENSE).
