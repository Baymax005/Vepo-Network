<script setup lang="ts">
import { ref, watchEffect, onUnmounted } from 'vue'
import { useReadContract, useWriteContract, useAccount, useConfig } from '@wagmi/vue'
import { readContract, waitForTransactionReceipt } from '@wagmi/core'
import { BOUNTY_ADDRESS, TOKEN_ADDRESS, VepoBountyABI, VepoTokenABI } from '../abi'
import { formatEther, parseEther } from 'viem'
import { useToast } from '../useToast'

const config = useConfig()
const { address } = useAccount()
const { addToast } = useToast()
const sortedBounties = ref<any[]>([])
const actionLoading = ref<Record<string, boolean>>({})

const { data: bountyCount } = useReadContract({
  address: BOUNTY_ADDRESS,
  abi: VepoBountyABI,
  functionName: 'bountyCounter',
  query: { refetchInterval: 5000 }
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

let interval: any
watchEffect(() => {
  fetchBounties()
  if (!interval) {
    interval = setInterval(fetchBounties, 10000) // Auto-refresh every 10s
  }
})
onUnmounted(() => { clearInterval(interval) })

const approveTokensIfNeeded = async (amount: bigint) => {
  if (!address.value) throw new Error("Wallet not connected")
  
  const currentAllowance = await readContract(config, {
    address: TOKEN_ADDRESS,
    abi: VepoTokenABI,
    functionName: 'allowance',
    args: [address.value, BOUNTY_ADDRESS],
  }) as bigint

  if (currentAllowance < amount) {
    addToast('Approving $VEPO fee...', 'info')
    const hash = await writeContractAsync({
      address: TOKEN_ADDRESS,
      abi: VepoTokenABI,
      functionName: 'approve',
      args: [BOUNTY_ADDRESS, amount],
    })
    await waitForTransactionReceipt(config, { hash })
    addToast('$VEPO fee approved!', 'success')
  }
}

const handleAction = async (actionName: string, id: bigint, extraArg?: string) => {
  const key = `${actionName}-${id.toString()}`
  actionLoading.value[key] = true
  try {
    const args = extraArg ? [id, extraArg] : [id]
    const hash = await writeContractAsync({
      address: BOUNTY_ADDRESS,
      abi: VepoBountyABI,
      functionName: actionName as any,
      args: args as any,
    })
    addToast(`Transaction broadcast for ${actionName}...`, 'info')
    await waitForTransactionReceipt(config, { hash })
    addToast(`Action "${actionName}" confirmed on-chain!`, 'success')
    fetchBounties()
  } catch (err: any) {
    console.error("Action failed:", err)
    addToast("Action failed: " + (err.shortMessage || err.message), 'error')
  } finally {
    actionLoading.value[key] = false
  }
}

const applyForGig = async (id: bigint) => {
  const link = prompt("Enter the link to your portfolio or resume:")
  if (!link) return
  const key = `apply-${id.toString()}`
  actionLoading.value[key] = true
  try {
    await approveTokensIfNeeded(parseEther('5'))
    await handleAction('applyForGig', id, link)
  } catch (err: any) {
    addToast("Application failed: " + (err.shortMessage || err.message), 'error')
  } finally {
    actionLoading.value[key] = false
  }
}

const submitWork = (id: bigint) => {
  const link = prompt("Enter the link to your completed work (e.g. GitHub repo, Google Doc):")
  if (link) handleAction('submitWork', id, link)
}

const cancelBounty = async (id: bigint) => {
  if (confirm("Cancelling an open gig burns a 5 $VEPO fee to prevent spam. Continue?")) {
    const key = `cancel-${id.toString()}`
    actionLoading.value[key] = true
    try {
      await approveTokensIfNeeded(parseEther('5'))
      await handleAction('cancelBounty', id)
    } catch (err: any) {
      addToast("Cancellation failed: " + (err.shortMessage || err.message), 'error')
    } finally {
      actionLoading.value[key] = false
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
  if (workSubmittedAt === 0) return false
  const sevenDaysInSeconds = 7 * 24 * 60 * 60
  const now = Math.floor(Date.now() / 1000)
  return now >= (workSubmittedAt + sevenDaysInSeconds)
}
</script>

<template>
  <div class="bounty-feed">
    <div class="section-header">
      <h2 style="margin: 0;">Marketplace Bounty Feed</h2>
      <button class="btn-outline" @click="fetchBounties" style="padding: 0.35rem 0.75rem; font-size: 0.8rem;">
        Refresh Feed
      </button>
    </div>

    <div v-if="sortedBounties.length === 0" class="glass-panel" style="text-align: center; color: var(--text-muted); padding: 2.5rem 1rem;">
      <p style="margin: 0; font-size: 1.05rem;">No bounties found on the feed yet.</p>
      <small style="color: var(--text-dim); display: block; margin-top: 0.5rem;">Post the first gig using the form on the left!</small>
    </div>
    
    <div 
      v-for="bounty in sortedBounties" 
      :key="bounty.id.toString()" 
      class="glass-panel" 
      :class="{ 'boosted': bounty.isBoosted }"
      style="margin-bottom: 1.5rem;"
    >
      <div style="display: flex; justify-content: space-between; align-items: start; margin-bottom: 0.75rem;">
        <h3 style="margin: 0; font-size: 1.15rem;">Bounty #{{ bounty.id.toString() }}</h3>
        <span 
          :style="{ color: getStateLabel(bounty.state).color, fontWeight: '700', fontSize: '0.85rem' }"
        >
          {{ getStateLabel(bounty.state).text }}
        </span>
      </div>
      
      <div style="display: flex; gap: 1.5rem; flex-wrap: wrap; margin-bottom: 0.85rem; font-size: 0.9rem;">
        <div>
          <span style="color: var(--text-dim);">Escrow: </span>
          <strong style="color: var(--primary);">{{ formatEther(bounty.originalAmount) }} USDC</strong>
        </div>
        <div>
          <span style="color: var(--text-dim);">Client: </span>
          <code>{{ bounty.client.slice(0,6) }}...{{ bounty.client.slice(-4) }}</code>
        </div>
        <div v-if="bounty.freelancer && bounty.freelancer !== '0x0000000000000000000000000000000000000000'">
          <span style="color: var(--text-dim);">Freelancer: </span>
          <code>{{ bounty.freelancer.slice(0,6) }}...{{ bounty.freelancer.slice(-4) }}</code>
        </div>
      </div>
      
      <div v-if="bounty.state === 0 && bounty.applicants.length > 0" style="margin: 1rem 0; padding: 12px; background: rgba(0,0,0,0.3); border-radius: 10px; border: 1px solid var(--glass-border);">
        <strong style="font-size: 0.85rem; color: var(--text-muted);">Applicants ({{ bounty.applicants.length }}):</strong>
        <ul style="margin: 0.5rem 0 0 0; padding-left: 1.25rem;">
          <li v-for="(app, index) in bounty.applicants" :key="index" style="margin-bottom: 0.4rem; font-size: 0.85rem;">
            <code>{{ app.freelancer.slice(0,6) }}...{{ app.freelancer.slice(-4) }}</code>
            — <a :href="app.portfolioLink" target="_blank" style="color: var(--primary);">Portfolio</a>
            <button 
              v-if="bounty.client === address"
              class="btn-primary" 
              style="padding: 0.25rem 0.6rem; font-size: 0.75rem; margin-left: 10px;"
              @click="handleAction('selectFreelancer', bounty.id, app.freelancer)"
              :disabled="actionLoading[`selectFreelancer-${bounty.id.toString()}`]"
            >
              {{ actionLoading[`selectFreelancer-${bounty.id.toString()}`] ? 'Assigning...' : 'Assign Freelancer' }}
            </button>
          </li>
        </ul>
      </div>

      <div v-if="bounty.workLink" style="margin-bottom: 0.85rem; padding: 12px; background: rgba(255,255,255,0.03); border-radius: 10px; border: 1px solid var(--glass-border);">
        <div><strong>Submitted Work:</strong> <a :href="bounty.workLink" target="_blank" style="color: var(--primary);">{{ bounty.workLink }}</a></div>
        <div style="font-size: 0.8rem; color: var(--text-dim); margin-top: 0.35rem;">
          Freelancer: <code>{{ bounty.freelancer.slice(0,6) }}...{{ bounty.freelancer.slice(-4) }}</code>
        </div>
        <div v-if="bounty.state === 1" style="font-size: 0.8rem; color: #eab308; margin-top: 0.35rem;">
          7-Day Ghosting Protection: {{ canForceClaim(bounty.workSubmittedAt) ? 'Ready to claim abandoned funds' : 'Timelock active (use Sandbox to fast-forward)' }}
        </div>
      </div>

      <!-- Action Buttons -->
      <div style="margin-top: 1rem; display: flex; gap: 10px; flex-wrap: wrap;" v-if="address">
        
        <!-- Freelancer Actions -->
        <template v-if="bounty.client !== address">
          <button 
            v-if="bounty.state === 0" 
            class="btn-primary" 
            @click="applyForGig(bounty.id)"
            :disabled="actionLoading[`apply-${bounty.id.toString()}`]"
          >
            {{ actionLoading[`apply-${bounty.id.toString()}`] ? 'Applying...' : 'Apply for Gig (5 $VEPO)' }}
          </button>
          
          <button 
            v-if="bounty.state === 1 && bounty.freelancer === address && bounty.workSubmittedAt === 0" 
            class="btn-primary" 
            @click="submitWork(bounty.id)"
            :disabled="actionLoading[`submitWork-${bounty.id.toString()}`]"
          >
            {{ actionLoading[`submitWork-${bounty.id.toString()}`] ? 'Submitting...' : 'Submit Work Link' }}
          </button>
          
          <button 
            v-if="bounty.state === 1 && bounty.freelancer === address && bounty.workSubmittedAt > 0" 
            class="btn-primary" 
            :style="{ background: canForceClaim(bounty.workSubmittedAt) ? '#10b981' : '#475569' }"
            @click="handleAction('claimAbandonedFunds', bounty.id)"
            :disabled="actionLoading[`claimAbandonedFunds-${bounty.id.toString()}`]"
            :title="canForceClaim(bounty.workSubmittedAt) ? '7-day lock expired - claim funds' : 'Requires 7-day timelock or fast-forward in sandbox'"
          >
            {{ actionLoading[`claimAbandonedFunds-${bounty.id.toString()}`] ? 'Claiming...' : (canForceClaim(bounty.workSubmittedAt) ? 'Claim Abandoned Funds' : 'Claim Abandoned Funds (7d Timelock)') }}
          </button>
        </template>

        <!-- Client Actions -->
        <template v-if="bounty.client === address">
          <button 
            v-if="bounty.state === 0" 
            class="btn-primary" 
            style="background: #ef4444"
            @click="cancelBounty(bounty.id)"
            :disabled="actionLoading[`cancel-${bounty.id.toString()}`]"
          >
            {{ actionLoading[`cancel-${bounty.id.toString()}`] ? 'Cancelling...' : 'Cancel Bounty (5 $VEPO)' }}
          </button>
          
          <button 
            v-if="bounty.state === 1 && bounty.workSubmittedAt > 0" 
            class="btn-primary" 
            style="background: #10b981"
            @click="handleAction('releaseFunds', bounty.id)"
            :disabled="actionLoading[`releaseFunds-${bounty.id.toString()}`]"
          >
            {{ actionLoading[`releaseFunds-${bounty.id.toString()}`] ? 'Releasing...' : 'Release Escrow Funds' }}
          </button>

          <button 
            v-if="bounty.state === 1 && bounty.workSubmittedAt > 0" 
            class="btn-primary" 
            style="background: #f97316"
            @click="handleAction('rejectWork', bounty.id)"
            :disabled="actionLoading[`rejectWork-${bounty.id.toString()}`]"
          >
            {{ actionLoading[`rejectWork-${bounty.id.toString()}`] ? 'Disputing...' : 'Reject Work (Escalate to Dispute)' }}
          </button>
        </template>
        
      </div>
    </div>
  </div>
</template>

<style scoped>
a {
  text-decoration: none;
}
a:hover {
  text-decoration: underline;
}
</style>
