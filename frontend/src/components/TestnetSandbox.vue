<script setup lang="ts">
import { ref } from 'vue'
import { useWriteContract, useConfig } from '@wagmi/vue'
import { waitForTransactionReceipt } from '@wagmi/core'
import { parseEther } from 'viem'
import { BOUNTY_ADDRESS, VepoBountyABI } from '../abi'

const config = useConfig()
const { writeContractAsync } = useWriteContract()

// Dispute Form
const disputeBountyId = ref('')
const favorFreelancer = ref(true)

// Fee Controls
const newListingFee = ref('')
const newApplicationFee = ref('')
const newBoostFee = ref('')
const newDeletionFee = ref('')

const isTimeTraveling = ref(false)

const fastForwardTime = async () => {
  isTimeTraveling.value = true
  try {
    // 7 days in seconds
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

    alert("Blockchain successfully fast-forwarded by 7 Days! Ghosting protection conditions are now met.")
  } catch (err: any) {
    alert("Time travel failed. Is the local Hardhat node running?\n\n" + err.message)
  } finally {
    isTimeTraveling.value = false
  }
}

const resolveDispute = async () => {
  if (!disputeBountyId.value) return
  try {
    const hash = await writeContractAsync({
      address: BOUNTY_ADDRESS,
      abi: VepoBountyABI,
      functionName: 'resolveDispute',
      args: [BigInt(disputeBountyId.value), favorFreelancer.value],
    })
    await waitForTransactionReceipt(config, { hash })
    alert("Dispute Resolved successfully!")
    disputeBountyId.value = ''
  } catch (err: any) {
    alert("Reverted! Access Denied: " + (err.shortMessage || err.message))
  }
}

const updateFees = async () => {
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
    await waitForTransactionReceipt(config, { hash })
    alert("Fees Updated successfully!")
    newListingFee.value = ''
    newApplicationFee.value = ''
    newBoostFee.value = ''
    newDeletionFee.value = ''
  } catch (err: any) {
    alert("Reverted! Access Denied: " + (err.shortMessage || err.message))
  }
}

const pauseProtocol = async () => {
  try {
    const hash = await writeContractAsync({
      address: BOUNTY_ADDRESS,
      abi: VepoBountyABI,
      functionName: 'pause',
    })
    await waitForTransactionReceipt(config, { hash })
    alert("Protocol PAUSED! No new marketplace actions are allowed.")
  } catch (err: any) {
    alert("Reverted! Access Denied: " + (err.shortMessage || err.message))
  }
}

const unpauseProtocol = async () => {
  try {
    const hash = await writeContractAsync({
      address: BOUNTY_ADDRESS,
      abi: VepoBountyABI,
      functionName: 'unpause',
    })
    await waitForTransactionReceipt(config, { hash })
    alert("Protocol UNPAUSED! Operations resumed.")
  } catch (err: any) {
    alert("Reverted! Access Denied: " + (err.shortMessage || err.message))
  }
}
</script>

<template>
  <div class="glass-panel sandbox-panel" style="margin-bottom: 2rem; border: 2px solid var(--primary);">
    <h2>Testnet Sandbox (Governance & Testing)</h2>
    
    <div style="background: rgba(255, 60, 0, 0.1); border-left: 4px solid var(--primary); padding: 1rem; margin-bottom: 1.5rem;">
      <strong>Welcome to the Vepo Network Testnet.</strong> Use these developer tools to simulate governance fee adjustments, fast-forward the blockchain for time-locks, and test dispute resolutions. 
      <br/><br/>
      <em>Note: Unless you are connected with the deployer wallet, the smart contract will automatically reject these transactions, perfectly demonstrating our strict <code>onlyOwner</code> access control security.</em>
    </div>

    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem;">
      <!-- Time Travel -->
      <div style="background: rgba(255,255,255,0.05); padding: 1.5rem; border-radius: 8px;">
        <h3>Time-Lock Testing</h3>
        <p style="font-size: 0.85rem; color: var(--text-muted); margin-bottom: 1rem;">
          Simulate the passage of 7 days on the local blockchain to test the Ghosting Protection (Force Claim/Force Refund) features.
        </p>
        <button class="btn-primary" style="width: 100%; background: #6366f1" @click="fastForwardTime" :disabled="isTimeTraveling">
          {{ isTimeTraveling ? 'Traveling...' : 'Fast-Forward 7 Days ⏭️' }}
        </button>
      </div>

      <!-- Dispute Resolution -->
      <div style="background: rgba(255,255,255,0.05); padding: 1.5rem; border-radius: 8px;">
        <h3>Dispute Resolution (Admin Arbiter)</h3>
        <div class="form-group" style="margin-bottom: 0.5rem;">
          <input type="number" class="input-field" v-model="disputeBountyId" placeholder="Bounty ID" />
        </div>
        <div style="margin-bottom: 1rem; display: flex; gap: 1rem; align-items: center;">
          <label style="cursor: pointer;">
            <input type="radio" :value="true" v-model="favorFreelancer" /> Award Freelancer
          </label>
          <label style="cursor: pointer;">
            <input type="radio" :value="false" v-model="favorFreelancer" /> Refund Client
          </label>
        </div>
        <button class="btn-primary" style="width: 100%; background: #eab308; color: black;" @click="resolveDispute">
          Resolve Dispute
        </button>
      </div>
      
      <!-- Economic Controls -->
      <div style="background: rgba(255,255,255,0.05); padding: 1.5rem; border-radius: 8px; grid-column: span 2;">
        <h3>Economic Controls (The Quadruple Burn)</h3>
        <p style="font-size: 0.85rem; color: var(--text-muted); margin-bottom: 1rem;">
          Adjust the deflationary fee structure (Values in $VEPO).
        </p>
        <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin-bottom: 1rem;">
          <input type="number" class="input-field" v-model="newListingFee" placeholder="Listing (e.g. 5)" />
          <input type="number" class="input-field" v-model="newApplicationFee" placeholder="Application (e.g. 5)" />
          <input type="number" class="input-field" v-model="newBoostFee" placeholder="Boost (e.g. 100)" />
          <input type="number" class="input-field" v-model="newDeletionFee" placeholder="Deletion (e.g. 5)" />
        </div>
        <button class="btn-primary" style="width: 100%;" @click="updateFees">
          Update Network Fees
        </button>
      </div>

      <!-- Emergency Controls -->
      <div style="background: rgba(255,255,255,0.05); padding: 1.5rem; border-radius: 8px; grid-column: span 2;">
        <h3>🚨 Emergency Circuit Breaker</h3>
        <p style="font-size: 0.85rem; color: var(--text-muted); margin-bottom: 1rem;">
          Pause or unpause all marketplace and staking operations. Use in case of a discovered vulnerability or emergency.
        </p>
        <div style="display: flex; gap: 1rem;">
          <button class="btn-primary" style="flex: 1; background: #ef4444;" @click="pauseProtocol">
            🛑 Pause Protocol
          </button>
          <button class="btn-primary" style="flex: 1; background: #10b981;" @click="unpauseProtocol">
            ▶️ Unpause Protocol
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.sandbox-panel {
  box-shadow: 0 0 20px rgba(255, 60, 0, 0.2);
}
</style>
