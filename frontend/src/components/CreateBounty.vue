<script setup lang="ts">
import { ref } from 'vue'
import { useWriteContract, useWaitForTransactionReceipt, useAccount } from '@wagmi/vue'
import { parseEther } from 'viem'
import { BOUNTY_ADDRESS, TOKEN_ADDRESS, VepoBountyABI, VepoTokenABI } from '../abi'

const amount = ref('')
const boost = ref(false)
const { address } = useAccount()

const { writeContract, data: hash } = useWriteContract()
const { isLoading, isSuccess } = useWaitForTransactionReceipt({ hash })

const submitBounty = async () => {
  if (!amount.value) return
  
  if (boost.value) {
    // Note: In a robust app, we'd wait for approval to mine, then call post, then boost.
    // For MVP, we trigger approval if needed.
    writeContract({
      address: TOKEN_ADDRESS,
      abi: VepoTokenABI,
      functionName: 'approve',
      args: [BOUNTY_ADDRESS, parseEther('100')],
    })
  }

  writeContract({
    address: BOUNTY_ADDRESS,
    abi: VepoBountyABI,
    functionName: 'postBounty',
    value: parseEther(amount.value.toString()),
  })
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
