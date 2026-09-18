<script setup lang="ts">
import { ref } from 'vue'
import { useWriteContract, useWaitForTransactionReceipt, useAccount, useConfig } from '@wagmi/vue'
import { readContract } from '@wagmi/core'
import { parseEther } from 'viem'
import { BOUNTY_ADDRESS, TOKEN_ADDRESS, VepoBountyABI, VepoTokenABI } from '../abi'

const amount = ref('')
const boost = ref(false)
const { address } = useAccount()

const config = useConfig()
const { writeContractAsync, data: hash } = useWriteContract()
const { isLoading, isSuccess } = useWaitForTransactionReceipt({ hash })

const submitBounty = async () => {
  if (!amount.value) return
  
  try {
    // 1. Post the bounty first
    const tx = await writeContractAsync({
      address: BOUNTY_ADDRESS,
      abi: VepoBountyABI,
      functionName: 'postBounty',
      value: parseEther(amount.value.toString()),
    })

    if (boost.value) {
      // Wait for local network to mine
      await new Promise(resolve => setTimeout(resolve, 1000))

      // Get the ID of the bounty we just posted
      const currentCounter = await readContract(config, {
        address: BOUNTY_ADDRESS,
        abi: VepoBountyABI,
        functionName: 'bountyCounter',
      })

      // 2. Approve the Vepo token transfer
      await writeContractAsync({
        address: TOKEN_ADDRESS,
        abi: VepoTokenABI,
        functionName: 'approve',
        args: [BOUNTY_ADDRESS, parseEther('100')],
      })
      await new Promise(resolve => setTimeout(resolve, 1000))

      // 3. Boost the bounty
      await writeContractAsync({
        address: BOUNTY_ADDRESS,
        abi: VepoBountyABI,
        functionName: 'boostBounty',
        args: [currentCounter],
      })
    }
    
    amount.value = ''
    boost.value = false
  } catch (err: any) {
    console.error("Transaction failed:", err)
    alert("Transaction failed: " + (err.shortMessage || err.message))
  }
}
</script>

<template>
  <div class="glass-panel">
    <h2>Post a Gig</h2>
    <div class="form-group">
      <label>Bounty Amount (USDC)</label>
      <input type="number" class="input-field" v-model="amount" placeholder="e.g. 50" />
    </div>

    <label class="toggle-switch">
      <input type="checkbox" v-model="boost" style="display:none;" />
      <span class="toggle-slider"></span>
      Pay 100 $VEPO to Boost
    </label>

    <button class="btn-primary" @click="submitBounty" :disabled="isLoading">
      {{ isLoading ? 'Processing...' : 'Post Bounty' }}
    </button>
    <div v-if="isSuccess" style="color: var(--primary); margin-top: 10px;">
      Successfully posted!
    </div>
  </div>
</template>
