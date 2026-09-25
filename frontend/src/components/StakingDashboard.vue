<script setup lang="ts">
import { ref } from 'vue'
import { useReadContract, useWriteContract, useAccount, useConfig } from '@wagmi/vue'
import { readContract } from '@wagmi/core'
import { STAKING_ADDRESS, TOKEN_ADDRESS, VepoStakingABI, VepoTokenABI } from '../abi'
import { formatEther, parseEther } from 'viem'

const config = useConfig()
const { address } = useAccount()
const stakeAmount = ref('')
const withdrawAmount = ref('')

// Read staking data
const { data: totalStaked } = useReadContract({
  address: STAKING_ADDRESS,
  abi: VepoStakingABI,
  functionName: 'totalStaked'
})

const { data: userStaked } = useReadContract({
  address: STAKING_ADDRESS,
  abi: VepoStakingABI,
  functionName: 'stakedBalance',
  args: address.value ? [address.value] : undefined
})

const { data: vepoBalance } = useReadContract({
  address: TOKEN_ADDRESS,
  abi: VepoTokenABI,
  functionName: 'balanceOf',
  args: address.value ? [address.value] : undefined
})

const { writeContractAsync } = useWriteContract()

import { waitForTransactionReceipt } from '@wagmi/core'

const stakeTokens = async () => {
  if (!stakeAmount.value || !address.value) return
  
  try {
    const amount = parseEther(stakeAmount.value.toString())
    
    // Check allowance
    const allowance = await readContract(config, {
      address: TOKEN_ADDRESS,
      abi: VepoTokenABI,
      functionName: 'allowance',
      args: [address.value, STAKING_ADDRESS],
    }) as bigint
    
    if (allowance < amount) {
      const approveHash = await writeContractAsync({
        address: TOKEN_ADDRESS,
        abi: VepoTokenABI,
        functionName: 'approve',
        args: [STAKING_ADDRESS, amount],
      })
      await waitForTransactionReceipt(config, { hash: approveHash })
    }

    const stakeHash = await writeContractAsync({
      address: STAKING_ADDRESS,
      abi: VepoStakingABI,
      functionName: 'stake',
      args: [amount],
    })
    await waitForTransactionReceipt(config, { hash: stakeHash })
    
    stakeAmount.value = ''
  } catch (e: any) {
    alert("Staking failed: " + (e.shortMessage || e.message))
  }
}

const withdrawTokens = async () => {
  if (!withdrawAmount.value) return
  try {
    await writeContractAsync({
      address: STAKING_ADDRESS,
      abi: VepoStakingABI,
      functionName: 'withdraw',
      args: [parseEther(withdrawAmount.value.toString())],
    })
    withdrawAmount.value = ''
  } catch (e: any) {
    alert("Withdraw failed: " + (e.shortMessage || e.message))
  }
}

const claimYield = async () => {
  try {
    await writeContractAsync({
      address: STAKING_ADDRESS,
      abi: VepoStakingABI,
      functionName: 'claimYield',
    })
  } catch (e: any) {
    alert("Claim failed: " + (e.shortMessage || e.message))
  }
}
</script>

<template>
  <div class="glass-panel" style="margin-bottom: 2rem;">
    <h2>$VEPO Staking (Treasury Engine)</h2>
    <p style="color: var(--text-muted); margin-bottom: 1rem;">
      Lock your $VEPO to earn 70% of the Arbitrum Sequencer profits (USDC swapped to VEPO).
      The remaining 30% is permanently burned!
    </p>

    <div style="display: flex; gap: 2rem; margin-bottom: 1.5rem; flex-wrap: wrap;">
      <div style="background: rgba(0,0,0,0.2); padding: 15px; border-radius: 8px; flex: 1; min-width: 200px;">
        <h4 style="margin: 0; color: var(--text-muted)">Global TVL</h4>
        <p style="font-size: 1.5rem; font-weight: bold; margin: 5px 0;">
          {{ totalStaked ? formatEther(totalStaked as bigint) : '0' }} VEPO
        </p>
      </div>
      <div style="background: rgba(0,0,0,0.2); padding: 15px; border-radius: 8px; flex: 1; min-width: 200px;">
        <h4 style="margin: 0; color: var(--text-muted)">Your Staked Balance</h4>
        <p style="font-size: 1.5rem; font-weight: bold; margin: 5px 0; color: var(--primary);">
          {{ userStaked ? formatEther(userStaked as bigint) : '0' }} VEPO
        </p>
      </div>
    </div>

    <div v-if="address" style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
      <!-- Stake Form -->
      <div style="background: rgba(255,255,255,0.05); padding: 1rem; border-radius: 8px;">
        <h4 style="margin-top: 0;">Stake $VEPO</h4>
        <div class="form-group" style="margin-bottom: 10px;">
          <input type="number" class="input-field" v-model="stakeAmount" placeholder="Amount to Stake" />
        </div>
        <p style="font-size: 0.8rem; color: var(--text-muted); margin-top: -5px; margin-bottom: 10px;">
          Wallet Balance: {{ vepoBalance ? formatEther(vepoBalance as bigint) : '0' }} VEPO
        </p>
        <button class="btn-primary" style="width: 100%" @click="stakeTokens">Deposit & Stake</button>
      </div>

      <!-- Withdraw Form -->
      <div style="background: rgba(255,255,255,0.05); padding: 1rem; border-radius: 8px;">
        <h4 style="margin-top: 0;">Unstake</h4>
        <div class="form-group" style="margin-bottom: 10px;">
          <input type="number" class="input-field" v-model="withdrawAmount" placeholder="Amount to Unstake" />
        </div>
        <button class="btn-primary" style="width: 100%; background: #ef4444" @click="withdrawTokens">Withdraw</button>
      </div>
    </div>

    <div v-if="address" style="margin-top: 1.5rem;">
      <button 
        class="btn-primary" 
        style="width: 100%; background: #10b981; font-size: 1.1rem;" 
        @click="claimYield"
        :disabled="!userStaked || (userStaked as bigint) === 0n"
        :style="{ opacity: (!userStaked || (userStaked as bigint) === 0n) ? 0.5 : 1, cursor: (!userStaked || (userStaked as bigint) === 0n) ? 'not-allowed' : 'pointer' }"
      >
        Claim Staking Yields (Harvest)
      </button>
    </div>
  </div>
</template>
