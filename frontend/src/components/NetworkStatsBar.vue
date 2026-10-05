<script setup lang="ts">
import { computed } from 'vue'
import { useReadContract } from '@wagmi/vue'
import { formatEther, parseEther } from 'viem'
import { TOKEN_ADDRESS, STAKING_ADDRESS, BOUNTY_ADDRESS, VepoTokenABI, VepoStakingABI, VepoBountyABI } from '../abi'

// 1. Total Supply
const { data: totalSupply } = useReadContract({
  address: TOKEN_ADDRESS,
  abi: VepoTokenABI,
  functionName: 'totalSupply',
  query: { refetchInterval: 5000 }
})

// 2. Total Staked
const { data: totalStaked } = useReadContract({
  address: STAKING_ADDRESS,
  abi: VepoStakingABI,
  functionName: 'totalStaked',
  query: { refetchInterval: 5000 }
})

// 3. Bounty Counter
const { data: bountyCount } = useReadContract({
  address: BOUNTY_ADDRESS,
  abi: VepoBountyABI,
  functionName: 'bountyCounter',
  query: { refetchInterval: 5000 }
})

// 4. Supply Floor
const { data: supplyFloor } = useReadContract({
  address: BOUNTY_ADDRESS,
  abi: VepoBountyABI,
  functionName: 'supplyFloor',
  query: { refetchInterval: 10000 }
})

const GENESIS_SUPPLY = parseEther('100000000') // 100M VEPO

const formattedSupply = computed(() => {
  if (!totalSupply.value) return '100.00M'
  const val = Number(formatEther(totalSupply.value as bigint))
  if (val >= 1_000_000) return (val / 1_000_000).toFixed(2) + 'M'
  if (val >= 1_000) return (val / 1_000).toFixed(1) + 'k'
  return val.toFixed(0)
})

const burnedAmount = computed(() => {
  if (!totalSupply.value) return '0'
  const supply = totalSupply.value as bigint
  if (supply >= GENESIS_SUPPLY) return '0'
  const burned = GENESIS_SUPPLY - supply
  const val = Number(formatEther(burned))
  if (val >= 1_000_000) return (val / 1_000_000).toFixed(2) + 'M'
  if (val >= 1_000) return (val / 1_000).toFixed(1) + 'k'
  return val.toLocaleString(undefined, { maximumFractionDigits: 1 })
})

const formattedStaked = computed(() => {
  if (!totalStaked.value) return '0'
  const val = Number(formatEther(totalStaked.value as bigint))
  if (val >= 1_000_000) return (val / 1_000_000).toFixed(2) + 'M'
  if (val >= 1_000) return (val / 1_000).toFixed(1) + 'k'
  return val.toLocaleString(undefined, { maximumFractionDigits: 1 })
})

const totalBounties = computed(() => {
  return bountyCount.value ? bountyCount.value.toString() : '0'
})

const formattedFloor = computed(() => {
  if (!supplyFloor.value) return '10M Floor'
  const val = Number(formatEther(supplyFloor.value as bigint))
  return `${(val / 1_000_000).toFixed(0)}M Floor`
})
</script>

<template>
  <div class="stats-bar">
    <div class="stat-card">
      <div class="stat-label">Circulating $VEPO</div>
      <div class="stat-value green">{{ formattedSupply }}</div>
    </div>

    <div class="stat-card" :title="`Guaranteed hard stop at ${formattedFloor}`">
      <div class="stat-label">Deflationary Burned</div>
      <div class="stat-value red">{{ burnedAmount }}</div>
    </div>

    <div class="stat-card">
      <div class="stat-label">Total Staked (TVL)</div>
      <div class="stat-value purple">{{ formattedStaked }}</div>
    </div>

    <div class="stat-card">
      <div class="stat-label">Total Bounties Listed</div>
      <div class="stat-value blue">{{ totalBounties }}</div>
    </div>
  </div>
</template>
