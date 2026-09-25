<script setup lang="ts">
import { ref } from 'vue'
import { useWriteContract, useWaitForTransactionReceipt, useAccount, useConfig } from '@wagmi/vue'
import { readContract } from '@wagmi/core'
import { parseEther } from 'viem'
import { BOUNTY_ADDRESS, TOKEN_ADDRESS, FAUCET_ADDRESS, VepoBountyABI, VepoTokenABI, VepoFaucetABI } from '../abi'

const amount = ref('')
const boost = ref(false)
const { address } = useAccount()

const config = useConfig()
const { writeContractAsync, data: hash } = useWriteContract()
const { isLoading, isSuccess } = useWaitForTransactionReceipt({ hash })

import { waitForTransactionReceipt } from '@wagmi/core'

const submitBounty = async () => {
  if (!amount.value) return
  
  try {
    if (!address.value) throw new Error("Wallet not connected");

    // Calculate required VEPO allowance (5 for listing, 100 for boost if selected)
    const requiredAllowance = boost.value ? parseEther('105') : parseEther('5');

    // 1. Check existing allowance first
    const currentAllowance = await readContract(config, {
      address: TOKEN_ADDRESS,
      abi: VepoTokenABI,
      functionName: 'allowance',
      args: [address.value, BOUNTY_ADDRESS],
    }) as bigint;

    // 2. Approve if needed
    if (currentAllowance < requiredAllowance) {
      const approveHash = await writeContractAsync({
        address: TOKEN_ADDRESS,
        abi: VepoTokenABI,
        functionName: 'approve',
        args: [BOUNTY_ADDRESS, requiredAllowance],
      })
      await waitForTransactionReceipt(config, { hash: approveHash })
    }

    // 3. Post the bounty (burns 5 VEPO listing fee)
    const postHash = await writeContractAsync({
      address: BOUNTY_ADDRESS,
      abi: VepoBountyABI,
      functionName: 'postBounty',
      value: parseEther(amount.value.toString()),
    })
    await waitForTransactionReceipt(config, { hash: postHash })

    if (boost.value) {
      // Get the ID of the bounty we just posted
      const currentCounter = await readContract(config, {
        address: BOUNTY_ADDRESS,
        abi: VepoBountyABI,
        functionName: 'bountyCounter',
      })

      // 4. Boost the bounty (burns 100 VEPO fee)
      const boostHash = await writeContractAsync({
        address: BOUNTY_ADDRESS,
        abi: VepoBountyABI,
        functionName: 'boostBounty',
        args: [currentCounter],
      })
      await waitForTransactionReceipt(config, { hash: boostHash })
    }
    
    amount.value = ''
    boost.value = false
  } catch (err: any) {
    console.error("Transaction failed:", err)
    alert("Transaction failed: " + (err.shortMessage || err.message))
  }
}

const claimFaucet = async () => {
  try {
    await writeContractAsync({
      address: FAUCET_ADDRESS,
      abi: VepoFaucetABI,
      functionName: 'requestTokens',
    })
    alert("Successfully claimed 1000 $VEPO from the Reserve Faucet!")
  } catch (err: any) {
    console.error("Faucet failed:", err)
    alert("Faucet failed: " + (err.shortMessage || err.message))
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

    <div style="margin-top: 2rem; padding-top: 1rem; border-top: 1px solid rgba(255,255,255,0.1)">
      <p style="font-size: 0.85rem; color: var(--text-muted); margin-bottom: 0.5rem">Need $VEPO to test boosting?</p>
      <button class="btn-primary" style="background: transparent; border: 1px solid var(--primary); color: var(--primary); padding: 0.5rem;" @click="claimFaucet">
        Claim Test $VEPO
      </button>
    </div>
  </div>
</template>
