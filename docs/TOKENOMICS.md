# Vepo Network Tokenomics (V4.0)

> **Vepo Network** — The Hyper-Deflationary L3 Freelance Economy

The $VEPO token is the native utility and governance token of the Vepo Network L3 App-Chain. It powers the gig marketplace, drives constant deflation through the Quadruple Burn engine, and rewards long-term stakers with sequencer-derived yields.

---

## 1. Supply Architecture

| Metric | Value |
|---|---|
| **Token Name** | Vepo ($VEPO) |
| **Token Standard** | ERC-20 (OpenZeppelin ERC20Burnable) |
| **Genesis Supply** | 100,000,000 $VEPO |
| **Minting Capability** | **None** — zero `mint()` function exists |
| **Supply Direction** | Strictly deflationary (can only decrease) |
| **Supply Floor** | 10,000,000 $VEPO (hard-coded minimum) |

### Genesis Allocation

| Allocation | Amount | % | Purpose |
|---|---|---|---|
| Protocol Treasury | 50,000,000 | 50% | Ecosystem grants, partnerships, marketing |
| Staking Rewards Reserve | 20,000,000 | 20% | Long-term yield distribution via VepoStaking |
| Team & Advisors | 15,000,000 | 15% | 12-month cliff, 36-month linear vesting |
| Community & Airdrops | 10,000,000 | 10% | Early adopter rewards, testnet participants |
| DEX Liquidity | 5,000,000 | 5% | Initial Uniswap / DEX pair liquidity |

### Vesting Schedule (Team & Advisors)

```
Month 0–12:   Fully locked (cliff period)
Month 13–48:  Linear unlock (~416,667 $VEPO/month)
```

All team tokens are subject to the same burn mechanics as any other $VEPO — there is no burn exemption.

---

## 2. Deflationary Mechanisms

### 2.1 The Quadruple Burn (Marketplace Fees)

Every marketplace interaction permanently destroys $VEPO through the `burnFrom()` mechanism, directly reducing `totalSupply()`:

| Action | Fee | Trigger | Burn Method |
|---|---|---|---|
| **Post a Bounty** | 5 $VEPO | Client lists a new gig | `burnFrom()` |
| **Apply for a Gig** | 5 $VEPO | Freelancer submits application | `burnFrom()` |
| **Boost a Bounty** | 100 $VEPO | Client promotes gig to top of feed | `burnFrom()` |
| **Cancel a Bounty** | 5 $VEPO | Client cancels before work starts | `burnFrom()` |

> **All fees are governance-adjustable** via `setFees()` or individual setters. The protocol owner (and eventually the VepoGovernance DAO) can tune these based on market conditions.

### 2.2 The Sequencer Buyback & Burn (Treasury Engine)

Vepo Network, as an Arbitrum L3 App-Chain, generates gas fee revenue from its dedicated sequencer. These profits flow into the `VepoStaking` Treasury Engine:

```
Arbitrum L3 Sequencer
    │
    ▼
USDC Gas Profits → VepoStaking Contract
    │
    ├──── Swap USDC → $VEPO via DEX Router
    │
    ├──── 70% → Distributed as staking yield to $VEPO stakers
    │
    └──── 30% → Permanently burned (supply reduction)
```

### 2.3 Supply Floor Clamping Math

The 30% burn is regulated by the **10M Supply Floor**. As `totalSupply()` approaches 10,000,000 $VEPO:

```solidity
// Pseudocode from VepoStaking.sol
if (currentSupply > supplyFloor) {
    theoreticalBurn = vepoReceived * 30%;
    amountAboveFloor = currentSupply - supplyFloor;
    actualBurn = min(theoreticalBurn, amountAboveFloor);
}
// Excess tokens redirect to staking yields (hyper-yield zone)
stakingReward = vepoReceived - actualBurn;
```

**Effect:** As supply tightens toward the floor, stakers receive progressively larger yields, creating a natural incentive to hold and stake rather than sell.

---

## 3. Burn Projections

Based on conservative marketplace activity estimates:

| Scenario | Daily Bounties | Daily Burns (Marketplace) | Monthly Supply Reduction |
|---|---|---|---|
| **Low Activity** | 50 bounties/day | ~750 $VEPO/day | ~22,500 $VEPO/month |
| **Medium Activity** | 500 bounties/day | ~7,500 $VEPO/day | ~225,000 $VEPO/month |
| **High Activity** | 5,000 bounties/day | ~75,000 $VEPO/day | ~2,250,000 $VEPO/month |

*Assumptions: Average 15 $VEPO burned per bounty (listing + 1 application + 0.5 boosts avg). Excludes sequencer buyback burns.*

**Projected Time to Floor (10M $VEPO):**

| Scenario | Estimated Time |
|---|---|
| Low Activity | ~333 years |
| Medium Activity | ~33 years |
| High Activity | ~3.3 years |

> [!NOTE]
> These projections exclude the 30% sequencer buyback burn, which accelerates deflation proportionally to network usage (more users → more gas → more burns).

---

## 4. Staking Economics

### 4.1 How Staking Works

1. Users deposit $VEPO into `VepoStaking.sol`.
2. When `processSequencerProfits()` is called, the contract swaps USDC → $VEPO.
3. 70% of purchased $VEPO is distributed pro-rata to all stakers.
4. Users call `claimYield()` to harvest accumulated rewards.

### 4.2 APY Model

Staking APY is dynamic and depends on:
- **Total Sequencer Revenue:** More L3 activity → more USDC → higher yields.
- **Total Staked $VEPO:** Fewer stakers → each staker gets a larger share.
- **Token Price:** DEX buyback converts USDC at market rates.

```
Estimated APY = (Annual Sequencer Revenue × 70% × VEPO/USDC Rate) / Total Staked VEPO
```

---

## 5. Dual-Token Model

| Token | Type | Purpose |
|---|---|---|
| **$VEPO** | ERC-20 (Deflationary) | Governance, staking, marketplace fees, reputation boosting |
| **Native Gas Token (USDC)** | L3 Gas Token | Transaction fees, bounty escrow payments, sequencer revenue |

This dual-token model ensures:
- **$VEPO** captures value through scarcity (burns) and utility (staking, fees).
- **USDC** provides price-stable payments for freelancers, eliminating volatility risk on earned income.
- **Remittance-ready:** Because payments are in USDC on a sub-cent L3, Vepo doubles as a cross-border remittance rail — freelancers in emerging markets receive instant stablecoin payments without FX fees or banking delays.

### Supply Floor Fee Redirection

When `totalSupply()` reaches the 10M floor, marketplace $VEPO fees can no longer be burned without violating the floor. Instead, the VepoBounty contract automatically **redirects fees to the VepoStaking contract**, where they are distributed as additional staker yields. This ensures:
- The protocol never stops collecting revenue.
- Stakers receive **hyper-yields** as the supply approaches the floor.
- The 10M floor is mathematically guaranteed.

---

## 6. Governance Integration

With the introduction of `VepoGovernance.sol`, $VEPO holders can vote on:

| Parameter | Current Default | Governance-Adjustable |
|---|---|---|
| Listing Fee | 5 $VEPO | ✅ |
| Application Fee | 5 $VEPO | ✅ |
| Boost Fee | 100 $VEPO | ✅ |
| Delete Fee | 5 $VEPO | ✅ |
| Burn BPS | 3000 (30%) | ✅ |
| Supply Floor | 10,000,000 $VEPO | ✅ |
| Proposal Threshold | 10,000 $VEPO | ✅ |
| Quorum | 100,000 $VEPO | ✅ |

This creates a path toward **progressive decentralization** — the protocol starts with admin control for rapid iteration, then gradually transfers parameter authority to the DAO.
