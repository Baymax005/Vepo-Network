<script setup lang="ts">
import { useReadContract, useReadContracts } from '@wagmi/vue'
import { BOUNTY_ADDRESS, VepoBountyABI } from '../abi'
import { formatEther } from 'viem'
import { computed } from 'vue'

const { data: bountyCount } = useReadContract({
  address: BOUNTY_ADDRESS,
  abi: VepoBountyABI,
  functionName: 'bountyCounter',
})

const bountyQueries = computed(() => {
  const count = Number(bountyCount.value || 0)
  return Array.from({ length: count }, (_, i) => ({
    address: BOUNTY_ADDRESS,
    abi: VepoBountyABI,
    functionName: 'bounties',
    args: [BigInt(i + 1)],
  }))
})

const { data: bountiesData } = useReadContracts({
  contracts: bountyQueries,
})

const sortedBounties = computed(() => {
  if (!bountiesData.value) return []
  
  const formatted = bountiesData.value
    .filter(res => res.status === 'success')
    .map(res => {
      const data = res.result as any
      return {
        id: data[0],
        client: data[1],
        freelancer: data[2],
        amount: data[3],
        isCompleted: data[4],
        isBoosted: data[5],
      }
    })

  // Sort boosted to the top, then by ID descending
  return formatted.sort((a, b) => {
    if (a.isBoosted && !b.isBoosted) return -1
    if (!a.isBoosted && b.isBoosted) return 1
    return Number(b.id) - Number(a.id)
  })
})
</script>

<template>
  <div class="bounty-feed">
    <h2>Bounty Feed</h2>
    <div v-if="sortedBounties.length === 0" style="color: var(--text-muted)">
      No bounties posted yet.
    </div>
    <div 
      v-for="bounty in sortedBounties" 
      :key="bounty.id.toString()" 
      class="glass-panel" 
      :class="{ 'boosted': bounty.isBoosted }"
      style="margin-bottom: 1.5rem;"
    >
      <h3>Bounty #{{ bounty.id.toString() }}</h3>
      <p style="margin-bottom: 0.5rem"><strong>Amount:</strong> {{ formatEther(bounty.amount) }} USDC</p>
      <p style="margin-bottom: 0.5rem"><strong>Client:</strong> {{ bounty.client.slice(0,6) }}...{{ bounty.client.slice(-4) }}</p>
      <span v-if="bounty.isCompleted" style="color: #ef4444;">Completed</span>
      <span v-else style="color: var(--primary);">Open</span>
    </div>
  </div>
</template>
