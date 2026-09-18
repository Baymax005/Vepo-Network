<script setup lang="ts">
import { ref, watchEffect } from 'vue'
import { useReadContract, useWriteContract, useAccount, useConfig } from '@wagmi/vue'
import { readContract } from '@wagmi/core'
import { BOUNTY_ADDRESS, VepoBountyABI } from '../abi'
import { formatEther } from 'viem'

const config = useConfig()
const { address } = useAccount()
const sortedBounties = ref<any[]>([])

const { data: bountyCount } = useReadContract({
  address: BOUNTY_ADDRESS,
  abi: VepoBountyABI,
  functionName: 'bountyCounter',
})

const { writeContractAsync } = useWriteContract()

const fetchBounties = async () => {
  const count = Number(bountyCount.value || 0)
  if (count === 0) {
    sortedBounties.value = []
    return
  }

  const bounties = []
  for (let i = 1; i <= count; i++) {
    try {
      const data: any = await readContract(config, {
        address: BOUNTY_ADDRESS,
        abi: VepoBountyABI,
        functionName: 'bounties',
        args: [BigInt(i)],
      })
      bounties.push({
        id: data[0],
        client: data[1],
        freelancer: data[2],
        amount: data[3],
        state: data[4], // 0: Open, 1: Locked, 2: Completed, 3: Cancelled
        isBoosted: data[5],
        workLink: data[6],
      })
    } catch (e) {
      console.error("Failed to fetch bounty", i, e)
    }
  }

  // Sort boosted to the top, then by ID descending
  sortedBounties.value = bounties.sort((a, b) => {
    if (a.isBoosted && !b.isBoosted) return -1
    if (!a.isBoosted && b.isBoosted) return 1
    return Number(b.id) - Number(a.id)
  })
}

watchEffect(() => {
  fetchBounties()
})

const handleAction = async (actionName: string, id: bigint, extraArg?: string) => {
  try {
    const args = extraArg ? [id, extraArg] : [id]
    await writeContractAsync({
      address: BOUNTY_ADDRESS,
      abi: VepoBountyABI,
      functionName: actionName as any,
      args,
    })
    // In a real app we wait for tx receipt, for MVP we just delay and refresh
    setTimeout(fetchBounties, 2000)
  } catch (err: any) {
    console.error("Action failed:", err)
    alert("Action failed: " + (err.shortMessage || err.message))
  }
}

const submitWork = (id: bigint) => {
  const link = prompt("Enter the link to your completed work (e.g. GitHub repo, Google Doc):")
  if (link) handleAction('submitWork', id, link)
}

const getStateLabel = (state: number) => {
  switch (state) {
    case 0: return { text: 'Open', color: 'var(--primary)' }
    case 1: return { text: 'In Review (Locked)', color: '#eab308' }
    case 2: return { text: 'Completed', color: '#10b981' }
    case 3: return { text: 'Cancelled', color: '#ef4444' }
    default: return { text: 'Unknown', color: '#888' }
  }
}
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
      <div style="display: flex; justify-content: space-between; align-items: start;">
        <h3>Bounty #{{ bounty.id.toString() }}</h3>
        <span 
          :style="{ color: getStateLabel(bounty.state).color, fontWeight: 'bold' }"
        >
          {{ getStateLabel(bounty.state).text }}
        </span>
      </div>
      
      <p style="margin-bottom: 0.5rem"><strong>Amount:</strong> {{ formatEther(bounty.amount) }} USDC</p>
      <p style="margin-bottom: 0.5rem"><strong>Client:</strong> {{ bounty.client.slice(0,6) }}...{{ bounty.client.slice(-4) }}</p>
      
      <div v-if="bounty.workLink" style="margin-bottom: 0.5rem; padding: 10px; background: rgba(255,255,255,0.05); border-radius: 8px;">
        <strong>Work Link:</strong> <a :href="bounty.workLink" target="_blank" style="color: var(--primary);">{{ bounty.workLink }}</a><br/>
        <small style="color: var(--text-muted)">Submitted by: {{ bounty.freelancer.slice(0,6) }}...{{ bounty.freelancer.slice(-4) }}</small>
      </div>

      <!-- Action Buttons -->
      <div style="margin-top: 1rem; display: flex; gap: 10px;" v-if="address">
        
        <!-- Freelancer Actions -->
        <button 
          v-if="bounty.state === 0 && bounty.client !== address" 
          class="btn-primary" 
          @click="submitWork(bounty.id)"
        >
          Submit Work
        </button>

        <!-- Client Actions -->
        <template v-if="bounty.client === address">
          <button 
            v-if="bounty.state === 0" 
            class="btn-primary" 
            style="background: #ef4444"
            @click="handleAction('cancelBounty', bounty.id)"
          >
            Cancel Bounty
          </button>
          
          <button 
            v-if="bounty.state === 1" 
            class="btn-primary" 
            style="background: #10b981"
            @click="handleAction('releaseFunds', bounty.id)"
          >
            Release Funds
          </button>

          <button 
            v-if="bounty.state === 1" 
            class="btn-primary" 
            style="background: #ef4444"
            @click="handleAction('rejectWork', bounty.id)"
          >
            Reject Work
          </button>
        </template>
        
      </div>
    </div>
  </div>
</template>

<style scoped>
a:hover {
  text-decoration: underline;
}
</style>
