<script setup lang="ts">
import { ref, computed } from 'vue'
import { useAccount, useConnect, useDisconnect, useReadContract } from '@wagmi/vue'
import { injected } from '@wagmi/vue/connectors'
import { formatEther } from 'viem'
import { TOKEN_ADDRESS, VepoTokenABI } from './abi'

import CreateBounty from './components/CreateBounty.vue'
import BountyFeed from './components/BountyFeed.vue'
import StakingDashboard from './components/StakingDashboard.vue'
import TestnetSandbox from './components/TestnetSandbox.vue'
import NetworkStatsBar from './components/NetworkStatsBar.vue'
import ToastNotification from './components/ToastNotification.vue'

const { address, isConnected } = useAccount()
const { connect } = useConnect()
const { disconnect } = useDisconnect()

const activeTab = ref<'marketplace' | 'staking' | 'sandbox'>('marketplace')

const handleConnect = () => {
  connect({ connector: injected() })
}

const { data: userVepoBalance } = useReadContract({
  address: TOKEN_ADDRESS,
  abi: VepoTokenABI,
  functionName: 'balanceOf',
  args: address.value ? [address.value] : undefined,
  query: { refetchInterval: 5000 }
})

const formattedUserBalance = computed(() => {
  if (!userVepoBalance.value) return '0'
  const val = Number(formatEther(userVepoBalance.value as bigint))
  return val.toLocaleString(undefined, { maximumFractionDigits: 1 })
})
</script>

<template>
  <ToastNotification />

  <!-- Navigation Header -->
  <header class="nav-header">
    <div class="nav-logo">
      <div class="nav-logo-icon">V</div>
      <div>
        <div style="display: flex; align-items: center; gap: 0.5rem;">
          <span class="nav-logo-text">VEPO</span>
          <span class="nav-logo-badge">Arbitrum L3</span>
        </div>
        <div style="font-size: 0.72rem; color: var(--text-dim); letter-spacing: 0.02em;">
          Hyper-Deflationary Freelance Economy
        </div>
      </div>
    </div>

    <!-- Navigation Tabs (When Connected) -->
    <nav v-if="isConnected" class="nav-tab-container">
      <button
        :class="['tab-btn', { active: activeTab === 'marketplace' }]"
        @click="activeTab = 'marketplace'"
      >
        <span class="tab-indicator" v-if="activeTab === 'marketplace'"></span>
        Marketplace
      </button>
      <button
        :class="['tab-btn', { active: activeTab === 'staking' }]"
        @click="activeTab = 'staking'"
      >
        <span class="tab-indicator" v-if="activeTab === 'staking'"></span>
        Staking & Treasury
      </button>
      <button
        :class="['tab-btn', { active: activeTab === 'sandbox' }]"
        @click="activeTab = 'sandbox'"
      >
        <span class="tab-indicator" v-if="activeTab === 'sandbox'"></span>
        Developer Sandbox
      </button>
    </nav>

    <!-- Wallet Actions -->
    <div class="nav-actions">
      <button v-if="!isConnected" class="btn-primary" @click="handleConnect">
        Connect Wallet
      </button>
      <div v-else style="display: flex; gap: 0.75rem; align-items: center;">
        <div class="wallet-pill">
          <span class="wallet-dot"></span>
          <span>{{ formattedUserBalance }} $VEPO</span>
          <span style="color: var(--text-dim);">|</span>
          <code>{{ address?.slice(0, 6) }}...{{ address?.slice(-4) }}</code>
        </div>
        <button
          class="btn-outline"
          @click="disconnect()"
          style="padding: 0.45rem 0.85rem; font-size: 0.8rem;"
        >
          Disconnect
        </button>
      </div>
    </div>
  </header>

  <!-- Network Live Metrics -->
  <NetworkStatsBar />

  <!-- Main Content -->
  <main>
    <div v-if="isConnected">
      <!-- Tab 1: Marketplace Feed & Create -->
      <div v-show="activeTab === 'marketplace'" class="layout-grid">
        <div>
          <CreateBounty />
        </div>
        <div>
          <BountyFeed />
        </div>
      </div>

      <!-- Tab 2: Staking & Treasury Dashboard -->
      <div v-show="activeTab === 'staking'">
        <StakingDashboard />
      </div>

      <!-- Tab 3: Testnet Sandbox -->
      <div v-show="activeTab === 'sandbox'">
        <TestnetSandbox />
      </div>
    </div>

    <!-- Logged Out Welcome Screen -->
    <div v-else class="glass-panel" style="text-align: center; margin-top: 3rem; padding: 3.5rem 2rem;">
      <div class="hero-emblem-wrap">
        <div class="hero-emblem">VEPO</div>
      </div>
      <h2 style="font-size: 2rem; margin-bottom: 0.75rem; letter-spacing: -0.02em;">Welcome to Vepo Network</h2>
      <p style="color: var(--text-muted); max-width: 620px; margin: 0 auto 2rem; line-height: 1.6; font-size: 1.05rem;">
        The premier decentralized micro-bounty protocol on Arbitrum L3. Zero commission fees for freelancers, USDC-escrowed protection, sequencer profit buybacks, and an 80/20 deflationary burn engine.
      </p>

      <div style="display: flex; justify-content: center; gap: 1rem; margin-bottom: 2.5rem; flex-wrap: wrap;">
        <div class="feature-tag">
          <span class="feature-tag-dot"></span>
          7-Day Ghosting Protection
        </div>
        <div class="feature-tag">
          <span class="feature-tag-dot"></span>
          80/20 Fee Burn Engine
        </div>
        <div class="feature-tag">
          <span class="feature-tag-dot"></span>
          70% Sequencer Yield
        </div>
        <div class="feature-tag">
          <span class="feature-tag-dot"></span>
          Zero Commission Payouts
        </div>
      </div>

      <button class="btn-primary" style="font-size: 1.05rem; padding: 0.9rem 2.2rem;" @click="handleConnect">
        Connect Web3 Wallet to Launch
      </button>
    </div>
  </main>
</template>

<style scoped>
.nav-tab-container {
  display: flex;
  gap: 0.35rem;
  background: rgba(0, 0, 0, 0.35);
  padding: 4px;
  border-radius: 12px;
  border: 1px solid var(--glass-border);
}

.tab-btn {
  background: transparent;
  border: none;
  color: var(--text-muted);
  padding: 0.5rem 1.1rem;
  border-radius: 8px;
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.tab-btn:hover {
  color: var(--text-light);
}

.tab-btn.active {
  background: var(--glass-bg);
  color: var(--primary);
  border: 1px solid var(--glass-border);
}

.tab-indicator {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--primary);
}

.hero-emblem-wrap {
  display: flex;
  justify-content: center;
  margin-bottom: 1.5rem;
}

.hero-emblem {
  width: 72px;
  height: 72px;
  border-radius: 20px;
  background: linear-gradient(135deg, rgba(74, 222, 128, 0.15) 0%, rgba(99, 102, 241, 0.15) 100%);
  border: 1px solid rgba(74, 222, 128, 0.3);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.25rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  color: var(--primary);
  box-shadow: 0 0 30px rgba(74, 222, 128, 0.15);
}

.feature-tag {
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--glass-border);
  padding: 0.5rem 1rem;
  border-radius: 20px;
  font-size: 0.85rem;
  font-weight: 500;
  color: var(--text-light);
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.feature-tag-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--primary);
}
</style>
