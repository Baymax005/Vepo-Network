<script setup lang="ts">
import { ref, watchEffect, onUnmounted } from 'vue'
import { useReadContract, useWriteContract, useAccount, useConfig } from '@wagmi/vue'
import { readContract } from '@wagmi/core'
import { BOUNTY_ADDRESS, TOKEN_ADDRESS, VepoBountyABI, VepoTokenABI } from '../abi'
import { formatEther, parseEther } from 'viem'

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
      
      let applicants: any[] = []
      if (data[5] === 0) { // If Open, fetch applicants
        applicants = (await readContract(config, {
          address: BOUNTY_ADDRESS,
          abi: VepoBountyABI,
          functionName: 'getApplicants',
          args: [BigInt(i)],
        })) as any as any[]
      }

      bounties.push({
        id: data[0],
        client: data[1],
        freelancer: data[2],
        amount: data[3],
        originalAmount: data[4],
        state: data[5], // 0: Open, 1: Locked, 2: Completed, 3: Cancelled, 4: Disputed
        isBoosted: data[6],
        workLink: data[7],
        workSubmittedAt: Number(data[8]),
        applicants
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

let interval: any;
watchEffect(() => {
  fetchBounties()
  if (!interval) {
    interval = setInterval(fetchBounties, 15000); // Auto-refresh every 15s
  }
})
onUnmounted(() => { clearInterval(interval) })

import { waitForTransactionReceipt } from '@wagmi/core'

const approveTokensIfNeeded = async (amount: bigint) => {
  if (!address.value) throw new Error("Wallet not connected");
  
  const currentAllowance = await readContract(config, {
    address: TOKEN_ADDRESS,
    abi: VepoTokenABI,
    functionName: 'allowance',
    args: [address.value, BOUNTY_ADDRESS],
  }) as bigint;

  if (currentAllowance < amount) {
    const hash = await writeContractAsync({
      address: TOKEN_ADDRESS,
      abi: VepoTokenABI,
      functionName: 'approve',
      args: [BOUNTY_ADDRESS, amount],
    })
    await waitForTransactionReceipt(config, { hash })
  }
}

const handleAction = async (actionName: string, id: bigint, extraArg?: string) => {
  try {
    const args = extraArg ? [id, extraArg] : [id]
    const hash = await writeContractAsync({
      address: BOUNTY_ADDRESS,
      abi: VepoBountyABI,
      functionName: actionName as any,
      args: args as any,
    })
    await waitForTransactionReceipt(config, { hash })
    fetchBounties()
  } catch (err: any) {
    console.error("Action failed:", err)
    alert("Action failed: " + (err.shortMessage || err.message))
  }
}

const applyForGig = async (id: bigint) => {
  const link = prompt("Enter the link to your portfolio or resume:")
  if (!link) return
  try {
    await approveTokensIfNeeded(parseEther('5'))
    await handleAction('applyForGig', id, link)
  } catch (err: any) {
    alert("Application failed: " + (err.shortMessage || err.message))
  }
}

const submitWork = (id: bigint) => {
  const link = prompt("Enter the link to your completed work (e.g. GitHub repo, Google Doc):")
  if (link) handleAction('submitWork', id, link)
}

const cancelBounty = async (id: bigint) => {
  if (confirm("Cancelling an open gig burns a 5 $VEPO fee to prevent spam. Continue?")) {
    try {
      await approveTokensIfNeeded(parseEther('5'))
      await handleAction('cancelBounty', id)
    } catch (err: any) {
      alert("Cancellation failed: " + (err.shortMessage || err.message))
    }
  }
}

const getStateLabel = (state: number) => {
  switch (state) {
    case 0: return { text: 'Open', color: 'var(--primary)' }
    case 1: return { text: 'In Progress / Locked', color: '#eab308' }
    case 2: return { text: 'Completed', color: '#10b981' }
    case 3: return { text: 'Cancelled', color: '#ef4444' }
    case 4: return { text: 'Disputed (Admin Review)', color: '#f97316' }
    default: return { text: 'Unknown', color: '#888' }
  }
}

const canForceClaim = (workSubmittedAt: number) => {
  if (workSubmittedAt === 0) return false;
  const sevenDaysInSeconds = 7 * 24 * 60 * 60;
  const now = Math.floor(Date.now() / 1000);
  return now >= (workSubmittedAt + sevenDaysInSeconds);
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
      
      <p style="margin-bottom: 0.5rem"><strong>Amount:</strong> {{ formatEther(bounty.originalAmount) }} USDC</p>
      <p style="margin-bottom: 0.5rem"><strong>Client:</strong> {{ bounty.client.slice(0,6) }}...{{ bounty.client.slice(-4) }}</p>
      
      <div v-if="bounty.state === 0 && bounty.applicants.length > 0" style="margin: 1rem 0; padding: 10px; background: rgba(0,0,0,0.2); border-radius: 8px;">
        <strong>Applicants:</strong>
        <ul style="margin-top: 0.5rem; padding-left: 1.5rem;">
          <li v-for="(app, index) in bounty.applicants" :key="index" style="margin-bottom: 0.5rem;">
            Freelancer: {{ app.freelancer.slice(0,6) }}...{{ app.freelancer.slice(-4) }}
            (<a :href="app.portfolioLink" target="_blank" style="color: var(--primary);">Portfolio</a>)
            <button 
              v-if="bounty.client === address"
              class="btn-primary" 
              style="padding: 0.2rem 0.5rem; font-size: 0.8rem; margin-left: 10px;"
              @click="handleAction('selectFreelancer', bounty.id, app.freelancer)"
            >
              Assign to this Freelancer
            </button>
          </li>
        </ul>
      </div>

      <div v-if="bounty.workLink" style="margin-bottom: 0.5rem; padding: 10px; background: rgba(255,255,255,0.05); border-radius: 8px;">
        <strong>Work Link:</strong> <a :href="bounty.workLink" target="_blank" style="color: var(--primary);">{{ bounty.workLink }}</a><br/>
        <small style="color: var(--text-muted)">Submitted by: {{ bounty.freelancer.slice(0,6) }}...{{ bounty.freelancer.slice(-4) }}</small>
        <br/>
        <small v-if="bounty.state === 1" style="color: #eab308">
          Time-Lock Expires in: 7 Days (Ghosting Protection)
        </small>
      </div>

      <!-- Action Buttons -->
      <div style="margin-top: 1rem; display: flex; gap: 10px; flex-wrap: wrap;" v-if="address">
        
        <!-- Freelancer Actions -->
        <template v-if="bounty.client !== address">
          <button 
            v-if="bounty.state === 0" 
            class="btn-primary" 
            @click="applyForGig(bounty.id)"
          >
            Apply for Gig (5 $VEPO)
          </button>
          
          <button 
            v-if="bounty.state === 1 && bounty.freelancer === address && bounty.workSubmittedAt === 0" 
            class="btn-primary" 
            @click="submitWork(bounty.id)"
          >
            Submit Work Link
          </button>
          
          <button 
            v-if="bounty.state === 1 && bounty.freelancer === address && canForceClaim(bounty.workSubmittedAt)" 
            class="btn-primary" 
            style="background: #10b981"
            @click="handleAction('claimAbandonedFunds', bounty.id)"
          >
            Force Claim (Time-Lock Expired)
          </button>
        </template>

        <!-- Client Actions -->
        <template v-if="bounty.client === address">
          <button 
            v-if="bounty.state === 0" 
            class="btn-primary" 
            style="background: #ef4444"
            @click="cancelBounty(bounty.id)"
          >
            Cancel Bounty (5 $VEPO)
          </button>
          
          <button 
            v-if="bounty.state === 1 && bounty.workSubmittedAt > 0" 
            class="btn-primary" 
            style="background: #10b981"
            @click="handleAction('releaseFunds', bounty.id)"
          >
            Release Funds
          </button>

          <button 
            v-if="bounty.state === 1 && bounty.workSubmittedAt > 0" 
            class="btn-primary" 
            style="background: #f97316"
            @click="handleAction('rejectWork', bounty.id)"
          >
            Reject Work (Dispute)
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
