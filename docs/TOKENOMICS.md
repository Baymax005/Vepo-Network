# Vepo Network Tokenomics

Vepo Network operates on a highly deflationary, dual-token architecture designed to power a decentralized micro-bounty economy. The network utilizes USDC for stable protocol gas and escrow, and the native **$VEPO** token as a utility and governance asset.

## 1. The Genesis Supply (Absolute Cap)
At block zero, exactly **100,000,000 $VEPO** tokens are minted to the deployer. 
The core smart contracts strictly forbid any future minting. The total supply is a mathematical hard-cap of 100 Million tokens, meaning the ecosystem can only shrink over time, never inflate.

To bootstrap the network safely, 1,000,000 $VEPO from the genesis supply is immediately locked into the **Reserve Faucet** for early adopters and testnet onboarding.

## 2. Utility & True Burning (Bounty Boosting)
The primary utility of the $VEPO token is increasing the visibility of bounties on the network. 

When a client creates a bounty and wishes to attract top-tier freelancers quickly, they can pay a **Boost Fee** (e.g., 100 $VEPO). Instead of this fee going to a developer wallet or a treasury, the `VepoBounty` contract permanently executes a **True Burn** (`ERC20Burnable.burnFrom()`). 

This permanently removes the tokens from circulation, actively decreasing the `totalSupply()` of the network with every boosted gig.

## 3. The Treasury Buyback Mechanism
Because Vepo Network is deployed as an Arbitrum L3 App-Chain, the network sequencer captures a tiny fraction of USDC from every transaction's gas fee. These sequencer profits are periodically routed to the `VepoStaking` treasury contract.

The `VepoStaking` contract executes an automated buyback-and-reward loop:
1. **DEX Buyback**: The contract routes 100% of its accumulated USDC through a Decentralized Exchange (DEX) to market-buy $VEPO.
2. **The 70/30 Split**: The purchased $VEPO is instantly split. 
   - **70%** is deposited into a global yield pool, distributed proportionally to users who are actively staking their $VEPO.
   - **30%** is permanently burned, applying continuous deflationary pressure regardless of gig-boosting volume.

## 4. The 5 Million Supply Floor
To prevent the tokenomics engine from completely burning itself into oblivion over decades, the network implements a **Supply Floor**.

During the DEX Buyback phase, the `VepoStaking` contract actively monitors the `totalSupply()`. If the absolute total supply reaches or falls below **5,000,000 $VEPO**, the 30% burn protocol is temporarily bypassed. Instead, 100% of the market-bought tokens are routed directly to the staking reward pool. 

If a burn calculation would pull the supply below the 5M threshold, the system utilizes "clamping math" to burn exactly enough tokens to hit the floor, and rewards the rest. This ensures a perpetual, stable baseline of tokens while vastly amplifying yields for stakers when maximum deflation is achieved.
