<script setup lang="ts">
import { useAccount, useConnect, useDisconnect } from '@wagmi/vue'
import { injected } from '@wagmi/vue/connectors'
import CreateBounty from './components/CreateBounty.vue'
import BountyFeed from './components/BountyFeed.vue'
import StakingDashboard from './components/StakingDashboard.vue'
import TestnetSandbox from './components/TestnetSandbox.vue'

const { address, isConnected } = useAccount()
const { connect } = useConnect()
const { disconnect } = useDisconnect()

const handleConnect = () => {
  connect({ connector: injected() })
}
</script>

<template>
  <header style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 3rem;">
    <h1>Vepo <span>Micro-Bounty Board</span></h1>
    <div>
      <button v-if="!isConnected" class="btn-primary" @click="handleConnect">Connect Wallet</button>
      <div v-else style="display: flex; gap: 1rem; align-items: center;">
        <span>{{ address?.slice(0, 6) }}...{{ address?.slice(-4) }}</span>
        <button class="btn-primary" @click="disconnect()" style="background: var(--glass-bg); color: var(--text-light); border: 1px solid var(--glass-border);">Disconnect</button>
      </div>
    </div>
  </header>

  <main>
    <div v-if="isConnected">
      <TestnetSandbox />
      <div class="layout-grid">
        <div>
          <CreateBounty />
        </div>
        <div>
          <StakingDashboard />
          <BountyFeed />
        </div>
      </div>
    </div>
    <div v-else class="glass-panel" style="text-align: center; margin-top: 4rem;">
      <h2>Welcome to Vepo</h2>
      <p style="color: var(--text-muted); margin-bottom: 2rem;">Please connect your wallet to view and post bounties.</p>
      <button class="btn-primary" @click="handleConnect">Connect Wallet</button>
    </div>
  </main>
</template>

<style scoped>
h1 {
  font-size: 2.5rem;
  margin: 0;
  background: -webkit-linear-gradient(45deg, var(--text-light), var(--primary));
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
h1 span {
  font-size: 1.5rem;
  font-weight: 400;
  color: var(--text-muted);
  -webkit-text-fill-color: var(--text-muted);
}
</style>
