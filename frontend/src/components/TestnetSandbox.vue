<script setup lang="ts">
import { ref } from 'vue'
import { useWriteContract, useConfig } from '@wagmi/vue'
import { waitForTransactionReceipt } from '@wagmi/core'
import { parseEther } from 'viem'
import { BOUNTY_ADDRESS, VepoBountyABI } from '../abi'
import { useToast } from '../useToast'

const config = useConfig()
const { writeContractAsync } = useWriteContract()
const { addToast } = useToast()

// Dispute Form
const disputeBountyId = ref('')
const favorFreelancer = ref(true)
const isResolvingDispute = ref(false)

// Fee Controls
const newListingFee = ref('')
const newApplicationFee = ref('')
const newBoostFee = ref('')
const newDeletionFee = ref('')
const newStakerBps = ref('')
const isUpdatingFees = ref(false)
const isUpdatingSplit = ref(false)

const isTimeTraveling = ref(false)
const isPausing = ref(false)
const isUnpausing = ref(false)

const fastForwardTime = async () => {
  isTimeTraveling.value = true
  addToast('Simulating 7-day blockchain time travel...', 'info')
  try {
    const sevenDays = 7 * 24 * 60 * 60
    
    // Send evm_increaseTime to Hardhat
    await fetch('http://127.0.0.1:8545', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jsonrpc: '2.0', method: 'evm_increaseTime', params: [sevenDays], id: 1 })
    })

    // Send evm_mine to Hardhat
    await fetch('http://127.0.0.1:8545', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jsonrpc: '2.0', method: 'evm_mine', id: 2 })
    })

    addToast('Blockchain fast-forwarded 7 days. Ghosting protection timelock elapsed.', 'success')
  } catch (err: any) {
    addToast('Time travel failed. Is the local Hardhat node running? ' + err.message, 'error')
  } finally {
    isTimeTraveling.value = false
  }
}

const resolveDispute = async () => {
  if (!disputeBountyId.value) {
    addToast('Please enter a Bounty ID.', 'error')
    return
  }
  isResolvingDispute.value = true
  try {
    const hash = await writeContractAsync({
      address: BOUNTY_ADDRESS,
      abi: VepoBountyABI,
      functionName: 'resolveDispute',
      args: [BigInt(disputeBountyId.value), favorFreelancer.value],
    })
    addToast('Resolving dispute on-chain...', 'info')
    await waitForTransactionReceipt(config, { hash })
    addToast(`Dispute #${disputeBountyId.value} successfully resolved`, 'success')
    disputeBountyId.value = ''
  } catch (err: any) {
    addToast('Reverted! Access Denied: ' + (err.shortMessage || err.message), 'error')
  } finally {
    isResolvingDispute.value = false
  }
}

const updateFees = async () => {
  isUpdatingFees.value = true
  try {
    const hash = await writeContractAsync({
      address: BOUNTY_ADDRESS,
      abi: VepoBountyABI,
      functionName: 'setFees',
      args: [
        newListingFee.value ? parseEther(newListingFee.value) : parseEther('5'),
        newApplicationFee.value ? parseEther(newApplicationFee.value) : parseEther('5'),
        newBoostFee.value ? parseEther(newBoostFee.value) : parseEther('100'),
        newDeletionFee.value ? parseEther(newDeletionFee.value) : parseEther('5')
      ],
    })
    addToast('Updating marketplace fees...', 'info')
    await waitForTransactionReceipt(config, { hash })
    addToast('Marketplace fees updated successfully', 'success')
    newListingFee.value = ''
    newApplicationFee.value = ''
    newBoostFee.value = ''
    newDeletionFee.value = ''
  } catch (err: any) {
    addToast('Reverted! Access Denied: ' + (err.shortMessage || err.message), 'error')
  } finally {
    isUpdatingFees.value = false
  }
}

const updateStakerFeeBps = async () => {
  if (!newStakerBps.value) {
    addToast('Please enter staker fee BPS (e.g. 2000 for 20%).', 'error')
    return
  }
  isUpdatingSplit.value = true
  try {
    const hash = await writeContractAsync({
      address: BOUNTY_ADDRESS,
      abi: VepoBountyABI,
      functionName: 'setStakerFeeBps',
      args: [BigInt(newStakerBps.value)],
    })
    addToast('Updating staker fee split...', 'info')
    await waitForTransactionReceipt(config, { hash })
    addToast(`Staker fee split updated to ${newStakerBps.value} BPS (${Number(newStakerBps.value)/100}%)`, 'success')
    newStakerBps.value = ''
  } catch (err: any) {
    addToast('Reverted! Access Denied: ' + (err.shortMessage || err.message), 'error')
  } finally {
    isUpdatingSplit.value = false
  }
}

const pauseProtocol = async () => {
  isPausing.value = true
  try {
    const hash = await writeContractAsync({
      address: BOUNTY_ADDRESS,
      abi: VepoBountyABI,
      functionName: 'pause',
    })
    addToast('Triggering protocol pause...', 'info')
    await waitForTransactionReceipt(config, { hash })
    addToast('Protocol PAUSED: Marketplace transactions halted.', 'success')
  } catch (err: any) {
    addToast('Reverted! Access Denied: ' + (err.shortMessage || err.message), 'error')
  } finally {
    isPausing.value = false
  }
}

const unpauseProtocol = async () => {
  isUnpausing.value = true
  try {
    const hash = await writeContractAsync({
      address: BOUNTY_ADDRESS,
      abi: VepoBountyABI,
      functionName: 'unpause',
    })
    addToast('Triggering protocol unpause...', 'info')
    await waitForTransactionReceipt(config, { hash })
    addToast('Protocol UNPAUSED: Marketplace operations resumed.', 'success')
  } catch (err: any) {
    addToast('Reverted! Access Denied: ' + (err.shortMessage || err.message), 'error')
  } finally {
    isUnpausing.value = false
  }
}
</script>

<template>
  <div class="glass-panel sandbox-panel" style="margin-bottom: 2rem;">
    <div class="section-header">
      <h2 style="margin: 0;">
        Testnet Sandbox (Governance & Diagnostics)
      </h2>
      <span class="nav-logo-badge" style="background: rgba(234, 179, 8, 0.15); color: #eab308; border-color: rgba(234, 179, 8, 0.3);">
        Dev / Admin Mode
      </span>
    </div>
    
    <div style="background: rgba(99, 102, 241, 0.08); border-left: 4px solid var(--accent); padding: 1rem; border-radius: 8px; margin-bottom: 1.5rem; font-size: 0.88rem; line-height: 1.5;">
      <strong>Arbitrum L3 Testing Suite:</strong> Simulate governance fee adjustments, fast-forward time to test 7-day ghosting protections, and exercise protocol pause circuits.
      <div style="font-size: 0.8rem; color: var(--text-dim); margin-top: 0.35rem;">
        * Note: Administrative setters require the deployer/owner wallet, demonstrating strict on-chain <code>onlyOwner</code> access controls.
      </div>
    </div>

    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1.25rem;">
      <!-- Time Travel -->
      <div style="background: rgba(0,0,0,0.3); padding: 1.25rem; border-radius: 12px; border: 1px solid var(--glass-border);">
        <h3 style="margin-top: 0; font-size: 1rem;">
          Ghosting Timelock Fast-Forward
        </h3>
        <p style="font-size: 0.82rem; color: var(--text-muted); margin-bottom: 1rem; line-height: 1.4;">
          Advances EVM block timestamp by 7 days to simulate client abandonment and enable <code>claimAbandonedFunds</code>.
        </p>
        <button class="btn-primary" style="width: 100%; background: linear-gradient(135deg, #6366f1 0%, #4f46e5 100%);" @click="fastForwardTime" :disabled="isTimeTraveling">
          {{ isTimeTraveling ? 'Fast-Forwarding...' : 'Fast-Forward 7 Days' }}
        </button>
      </div>

      <!-- Dispute Resolution -->
      <div style="background: rgba(0,0,0,0.3); padding: 1.25rem; border-radius: 12px; border: 1px solid var(--glass-border);">
        <h3 style="margin-top: 0; font-size: 1rem;">
          Dispute Arbiter (Admin Review)
        </h3>
        <div class="form-group" style="margin-bottom: 0.5rem;">
          <input type="number" class="input-field" v-model="disputeBountyId" placeholder="Disputed Bounty ID" :disabled="isResolvingDispute" />
        </div>
        <div style="margin-bottom: 0.75rem; display: flex; gap: 1rem; font-size: 0.85rem;">
          <label style="cursor: pointer; display: flex; align-items: center; gap: 0.3rem;">
            <input type="radio" :value="true" v-model="favorFreelancer" /> Award Freelancer
          </label>
          <label style="cursor: pointer; display: flex; align-items: center; gap: 0.3rem;">
            <input type="radio" :value="false" v-model="favorFreelancer" /> Refund Client
          </label>
        </div>
        <button class="btn-primary" style="width: 100%; background: #eab308; color: black;" @click="resolveDispute" :disabled="isResolvingDispute || !disputeBountyId">
          {{ isResolvingDispute ? 'Resolving...' : 'Resolve Dispute' }}
        </button>
      </div>
      
      <!-- Economic Controls -->
      <div style="background: rgba(0,0,0,0.3); padding: 1.25rem; border-radius: 12px; border: 1px solid var(--glass-border); grid-column: span 2;">
        <h3 style="margin-top: 0; font-size: 1rem;">
          Quadruple Burn Fee Configuration
        </h3>
        <p style="font-size: 0.82rem; color: var(--text-muted); margin-bottom: 1rem;">
          Tune platform anti-spam fees (in $VEPO). Each action burns 80% and sends 20% to stakers.
        </p>
        <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 0.75rem; margin-bottom: 0.75rem;">
          <input type="number" class="input-field" v-model="newListingFee" placeholder="Listing (5 $VEPO)" />
          <input type="number" class="input-field" v-model="newApplicationFee" placeholder="Application (5 $VEPO)" />
          <input type="number" class="input-field" v-model="newBoostFee" placeholder="Boost (100 $VEPO)" />
          <input type="number" class="input-field" v-model="newDeletionFee" placeholder="Cancel (5 $VEPO)" />
        </div>
        <div style="display: flex; gap: 1rem; align-items: center; margin-bottom: 1rem;">
          <input type="number" class="input-field" style="margin-bottom: 0; max-width: 280px;" v-model="newStakerBps" placeholder="Staker Fee BPS (e.g. 2000 = 20%)" />
          <button class="btn-outline" @click="updateStakerFeeBps" :disabled="isUpdatingSplit || !newStakerBps">
            {{ isUpdatingSplit ? 'Updating...' : 'Set Staker Split BPS' }}
          </button>
        </div>
        <button class="btn-primary" style="width: 100%;" @click="updateFees" :disabled="isUpdatingFees">
          {{ isUpdatingFees ? 'Updating Fees...' : 'Batch Update Marketplace Fees' }}
        </button>
      </div>

      <!-- Emergency Controls -->
      <div style="background: rgba(0,0,0,0.3); padding: 1.25rem; border-radius: 12px; border: 1px solid var(--glass-border); grid-column: span 2;">
        <h3 style="margin-top: 0; font-size: 1rem; color: #ef4444;">
          Emergency Circuit Breaker (Pausable)
        </h3>
        <p style="font-size: 0.82rem; color: var(--text-muted); margin-bottom: 1rem;">
          Freezes or resumes marketplace contract state transitions in case of critical network maintenance.
        </p>
        <div style="display: flex; gap: 1rem;">
          <button class="btn-primary" style="flex: 1; background: #ef4444;" @click="pauseProtocol" :disabled="isPausing">
            {{ isPausing ? 'Pausing...' : 'Pause Protocol' }}
          </button>
          <button class="btn-primary" style="flex: 1; background: #10b981;" @click="unpauseProtocol" :disabled="isUnpausing">
            {{ isUnpausing ? 'Unpausing...' : 'Unpause Protocol' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
