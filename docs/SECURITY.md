# Vepo Network — Security Model

> Threat model, security mechanisms, and audit status for the Vepo L3 protocol.

---

## 1. Security Principles

Vepo Network follows a defense-in-depth security model:

1. **Minimize Attack Surface:** Each contract has a focused responsibility with minimal external dependencies.
2. **Fail-Safe Defaults:** All admin functions are `onlyOwner`; unknown callers are rejected by default.
3. **Use Battle-Tested Libraries:** All access control, reentrancy protection, and token logic uses audited OpenZeppelin v5.x contracts.
4. **Emergency Escape Hatches:** Both VepoBounty and VepoStaking implement `Pausable` for protocol-wide halts.
5. **Immutable Core:** No proxy pattern in V1 — contracts cannot be upgraded silently.

---

## 2. Threat Model

### 2.1 Smart Contract Risks

| Threat | Severity | Mitigation |
|---|---|---|
| **Reentrancy on fund transfers** | Critical | `ReentrancyGuard` on all functions with `.call{value}()`. State updated before transfers (CEI pattern). |
| **Integer overflow/underflow** | High | Solidity 0.8.20 has built-in overflow checks. Additional safe-subtraction in `_settlePendingReward()`. |
| **Unauthorized fee manipulation** | High | All fee setters are `onlyOwner`. Future: transfer to DAO governance. |
| **Supply over-burn past floor** | Medium | Clamping math in `processSequencerProfits()` guarantees `totalSupply >= supplyFloor`. |
| **MEV / sandwich attacks on buyback** | Medium | `processSequencerProfits()` is `onlyOwner` — not callable by arbitrary MEV bots. Process cooldown prevents griefing. |
| **Staking reward rounding errors** | Low | Safe subtraction pattern prevents underflow from accumulated rounding dust. |
| **Flash loan governance attacks** | Medium | Governance uses current balances (V1). Future: snapshot-based voting to prevent flash loan manipulation. |

### 2.2 Operational Risks

| Threat | Severity | Mitigation |
|---|---|---|
| **Owner key compromise** | Critical | Use multisig (Gnosis Safe) for all owner operations. Transition to DAO governance. |
| **Sequencer downtime** | Medium | L3 sequencer is managed infrastructure. If sequencer goes down, funds remain safe in contracts. |
| **DEX liquidity drain** | Medium | Buyback uses real DEX; liquidity risks are inherent. Process cooldown limits exposure per call. |
| **Frontend compromise** | Medium | Frontend is read-only display + wallet signature requests. All logic is on-chain. |

### 2.3 Economic Risks

| Threat | Severity | Mitigation |
|---|---|---|
| **Death spiral (excessive burns)** | Low | Supply floor (10M $VEPO) prevents total depletion. Hyper-yield zone incentivizes holding. |
| **Whale manipulation** | Medium | Governance threshold (10K VEPO) and quorum (100K VEPO) prevent low-effort attacks. |
| **Fee parameter abuse** | Medium | Fee changes are `onlyOwner` / governance-voted. No single user can change fees. |

---

## 3. Security Mechanisms Implemented

### 3.1 ReentrancyGuard

Applied to all functions that transfer native currency or tokens:
- `VepoBounty`: `cancelBounty()`, `releaseFunds()`, `claimAbandonedFunds()`, `resolveDispute()`
- `VepoStaking`: `stake()`, `withdraw()`, `claimYield()`

### 3.2 Pausable (Emergency Circuit Breaker)

Both `VepoBounty` and `VepoStaking` inherit OpenZeppelin's `Pausable`:
- `pause()` — Halts all user-facing operations immediately.
- `unpause()` — Resumes operations after the emergency is resolved.
- Only callable by the protocol owner.
- Existing fund positions (staked tokens, escrowed bounties) remain safe during a pause.

### 3.3 Checks-Effects-Interactions (CEI) Pattern

All fund transfer functions follow the CEI pattern:
```solidity
// 1. Check: Validate all conditions
require(bounty.client == msg.sender, "Only client can cancel");

// 2. Effect: Update state BEFORE transferring funds
bounty.state = BountyState.Cancelled;
bounty.amount = 0;

// 3. Interaction: Transfer funds last
(bool success, ) = msg.sender.call{value: amountToRefund}("");
require(success, "Refund failed");
```

### 3.4 Supply Floor Clamping

```solidity
if (theoreticalBurn > amountAboveFloor) {
    burnAmount = amountAboveFloor;  // Clamp to floor
} else {
    burnAmount = theoreticalBurn;
}
// Excess redirects to staker rewards — no tokens are lost
```

### 3.5 Process Cooldown

`processSequencerProfits()` enforces a minimum interval between calls:
```solidity
require(block.timestamp >= lastProcessedAt + processInterval, "Cooldown active");
```

---

## 4. Audit Status

| Item | Status | Notes |
|---|---|---|
| **Internal Review** | ✅ Complete | All contracts reviewed for common vulnerability patterns |
| **Automated Analysis** | 🔲 Planned | Slither, Mythril, and Echidna fuzzing |
| **Professional Audit** | 🔲 Planned (Q1 2027) | Target: OpenZeppelin, Trail of Bits, or Certora |
| **Bug Bounty** | 🔲 Planned (Q1 2027) | Target: Immunefi with tiered rewards |
| **Formal Verification** | 🔲 Future | Critical math (floor clamping, reward distribution) |

---

## 5. Known Limitations

These are documented design trade-offs, not vulnerabilities:

1. **Centralized Admin (V1):** The protocol owner has significant power (fee changes, dispute resolution, pause). This is intentional during bootstrapping and will transition to DAO governance.

2. **Flash Loan Voting Risk:** VepoGovernance uses current token balances for vote weight. A future upgrade will implement snapshot-based voting to prevent flash loan manipulation.

3. **No Proxy Upgradeability:** Contracts are immutable. If a critical bug is found, migration to new contracts would be required. This trade-off was chosen for simplicity and auditability.

4. **Single-Point Arbitration:** Dispute resolution relies on a single Admin Arbiter. The roadmap includes transitioning to a decentralized jury system.

5. **`amountOutMin = 0` in Buyback:** The DEX swap accepts any output amount. This is mitigated by the `onlyOwner` restriction (preventing sandwich attacks from MEV bots) but is a known limitation.

---

## 6. Responsible Disclosure

If you discover a security vulnerability, please report it responsibly:

- **Email:** [security@vepo.network] (coming soon)
- **GitHub:** Open a private security advisory on the repository
- **Do NOT** disclose vulnerabilities publicly before they are patched

We commit to:
- Acknowledging reports within 48 hours.
- Providing updates on remediation within 7 days.
- Crediting responsible disclosers (with permission).
