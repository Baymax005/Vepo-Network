<script setup lang="ts">
import { ref } from 'vue'
import { useReadContract, useWriteContract, useAccount, useConfig } from '@wagmi/vue'
import { readContract, waitForTransactionReceipt } from '@wagmi/core'
import { STAKING_ADDRESS, TOKEN_ADDRESS, VepoStakingABI, VepoTokenABI } from '../abi'
import { formatEther, parseEther } from 'viem'
import { useToast } from '../useToast'

const config = useConfig()
const { address } = useAccount()
const { addToast } = useToast()
const { writeContractAsync } = useWriteContract()

const stakeAmount = ref('')
const withdrawAmount = ref('')
const isStaking = ref(false)
const isWithdrawing = ref(false)
const isClaiming = ref(false)

// Read staking data
const { data: totalStaked, refetch: refetchTotalStaked } = useReadContract({
  address: STAKING_ADDRESS,
  abi: VepoStakingABI,
  functionName: 'totalStaked',
  query: { refetchInterval: 5000 }
})

const { data: userStaked, refetch: refetchUserStaked } = useReadContract({
  address: STAKING_ADDRESS,
  abi: VepoStakingABI,
  functionName: 'stakedBalance',
  args: address.value ? [address.value] : undefined,
  query: { refetchInterval: 5000 }
})

const { data: vepoBalance, refetch: refetchVepoBalance } = useReadContract({
  address: TOKEN_ADDRESS,
  abi: VepoTokenABI,
  functionName: 'balanceOf',
  args: address.value ? [address.value] : undefined,
  query: { refetchInterval: 5000 }
})

const setMaxStake = () => {
  if (vepoBalance.value) {
    stakeAmount.value = formatEther(vepoBalance.value as bigint)
  }
}

const setMaxWithdraw = () => {
  if (userStaked.value) {
    withdrawAmount.value = formatEther(userStaked.value as bigint)
  }
}

const stakeTokens = async () => {
  if (!stakeAmount.value || Number(stakeAmount.value) <= 0) {
    addToast('Please enter an amount to stake.', 'error')
    return
  }
  if (!address.value) {
    addToast('Wallet not connected.', 'error')
    return
  }
  
  isStaking.value = true
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
      addToast('Approving $VEPO for staking vault...', 'info')
      const approveHash = await writeContractAsync({
        address: TOKEN_ADDRESS,
        abi: VepoTokenABI,
        functionName: 'approve',
        args: [STAKING_ADDRESS, amount],
      })
      await waitForTransactionReceipt(config, { hash: approveHash })
      addToast('$VEPO approved for staking!', 'success')
    }

    addToast('Depositing into Staking Treasury...', 'info')
    const stakeHash = await writeContractAsync({
      address: STAKING_ADDRESS,
      abi: VepoStakingABI,
      functionName: 'stake',
      args: [amount],
    })
    await waitForTransactionReceipt(config, { hash: stakeHash })
    
    addToast(`Successfully staked ${stakeAmount.value} $VEPO`, 'success')
    stakeAmount.value = ''
    refetchTotalStaked()
    refetchUserStaked()
    refetchVepoBalance()
  } catch (e: any) {
    console.error('Stake error:', e)
    addToast('Staking failed: ' + (e.shortMessage || e.message), 'error')
  } finally {
    isStaking.value = false
  }
}

const withdrawTokens = async () => {
  if (!withdrawAmount.value || Number(withdrawAmount.value) <= 0) {
    addToast('Please enter an amount to withdraw.', 'error')
    return
  }
  
  isWithdrawing.value = true
  try {
    addToast('Withdrawing $VEPO from staking vault...', 'info')
    const hash = await writeContractAsync({
      address: STAKING_ADDRESS,
      abi: VepoStakingABI,
      functionName: 'withdraw',
      args: [parseEther(withdrawAmount.value.toString())],
    })
    await waitForTransactionReceipt(config, { hash })
    addToast(`Successfully unstaked ${withdrawAmount.value} $VEPO`, 'success')
    withdrawAmount.value = ''
    refetchTotalStaked()
    refetchUserStaked()
    refetchVepoBalance()
  } catch (e: any) {
    console.error('Withdraw error:', e)
    addToast('Withdraw failed: ' + (e.shortMessage || e.message), 'error')
  } finally {
    isWithdrawing.value = false
  }
}

const claimYield = async () => {
  isClaiming.value = true
  addToast('Harvesting staking yields...', 'info')
  try {
    const hash = await writeContractAsync({
      address: STAKING_ADDRESS,
      abi: VepoStakingABI,
      functionName: 'claimYield',
    })
    await waitForTransactionReceipt(config, { hash })
    addToast('Staking yields harvested successfully', 'success')
    refetchUserStaked()
    refetchVepoBalance()
  } catch (e: any) {
    console.error('Harvest error:', e)
    addToast('Harvest failed: ' + (e.shortMessage || e.message), 'error')
  } finally {
    isClaiming.value = false
  }
}
</script>

<template>
  <div class="glass-panel" style="margin-bottom: 2rem;">
    <div class="section-header">
      <h2 style="margin: 0;">
        $VEPO Staking & Treasury Engine
      </h2>
      <span class="nav-logo-badge">Dual-Action Yield</span>
    </div>

    <p style="color: var(--text-muted); font-size: 0.88rem; line-height: 1.5; margin-bottom: 1.25rem;">
      Lock your $VEPO to earn <strong>70% of Arbitrum Sequencer profits</strong> (USDC swapped to VEPO) plus 
      <strong>20% of all marketplace fees</strong> from the 80/20 Dual-Action Fee Engine. 
      The remaining 80% of fees and 30% of sequencer buybacks are permanently destroyed!
    </p>

    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 1.5rem;">
      <div style="background: rgba(0,0,0,0.3); padding: 1.2rem; border-radius: 12px; border: 1px solid var(--glass-border);">
        <div class="stat-label">Global Staking TVL</div>
        <div style="font-size: 1.4rem; font-weight: 700; color: var(--text-light); margin-top: 0.25rem;">
          {{ totalStaked ? Number(formatEther(totalStaked as bigint)).toLocaleString(undefined, { maximumFractionDigits: 1 }) : '0' }} <span style="font-size: 0.9rem; color: var(--text-dim);">$VEPO</span>
        </div>
      </div>
      <div style="background: rgba(0,0,0,0.3); padding: 1.2rem; border-radius: 12px; border: 1px solid var(--glass-border);">
        <div class="stat-label">Your Active Stake</div>
        <div style="font-size: 1.4rem; font-weight: 700; color: var(--primary); margin-top: 0.25rem;">
          {{ userStaked ? Number(formatEther(userStaked as bigint)).toLocaleString(undefined, { maximumFractionDigits: 2 }) : '0' }} <span style="font-size: 0.9rem; color: var(--text-dim);">$VEPO</span>
        </div>
      </div>
    </div>

    <div v-if="address" style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
      <!-- Stake Form -->
      <div style="background: rgba(255,255,255,0.03); padding: 1.25rem; border-radius: 12px; border: 1px solid var(--glass-border);">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem;">
          <h4 style="margin: 0; font-size: 0.95rem;">Stake $VEPO</h4>
          <button @click="setMaxStake" style="background: none; border: none; color: var(--primary); font-size: 0.75rem; cursor: pointer; text-decoration: underline;">
            Max
          </button>
        </div>
        <input
          type="number"
          class="input-field"
          v-model="stakeAmount"
          placeholder="Amount to Stake"
          :disabled="isStaking"
        />
        <div style="font-size: 0.78rem; color: var(--text-dim); margin-top: -0.5rem; margin-bottom: 0.85rem;">
          Wallet: {{ vepoBalance ? Number(formatEther(vepoBalance as bigint)).toLocaleString(undefined, { maximumFractionDigits: 2 }) : '0' }} $VEPO
        </div>
        <button
          class="btn-primary"
          style="width: 100%;"
          @click="stakeTokens"
          :disabled="isStaking || !stakeAmount"
        >
          {{ isStaking ? 'Processing...' : 'Deposit & Stake' }}
        </button>
      </div>

      <!-- Withdraw Form -->
      <div style="background: rgba(255,255,255,0.03); padding: 1.25rem; border-radius: 12px; border: 1px solid var(--glass-border);">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem;">
          <h4 style="margin: 0; font-size: 0.95rem;">Unstake $VEPO</h4>
          <button @click="setMaxWithdraw" style="background: none; border: none; color: var(--danger); font-size: 0.75rem; cursor: pointer; text-decoration: underline;">
            Max
          </button>
        </div>
        <input
          type="number"
          class="input-field"
          v-model="withdrawAmount"
          placeholder="Amount to Unstake"
          :disabled="isWithdrawing"
        />
        <div style="font-size: 0.78rem; color: var(--text-dim); margin-top: -0.5rem; margin-bottom: 0.85rem;">
          Staked: {{ userStaked ? Number(formatEther(userStaked as bigint)).toLocaleString(undefined, { maximumFractionDigits: 2 }) : '0' }} $VEPO
        </div>
        <button
          class="btn-primary"
          style="width: 100%; background: #ef4444;"
          @click="withdrawTokens"
          :disabled="isWithdrawing || !withdrawAmount || !userStaked || (userStaked as bigint) === 0n"
        >
          {{ isWithdrawing ? 'Withdrawing...' : 'Withdraw Stake' }}
        </button>
      </div>
    </div>

    <div v-if="address" style="margin-top: 1.5rem;">
      <button 
        class="btn-primary" 
        style="width: 100%; background: linear-gradient(135deg, #10b981 0%, #059669 100%); font-size: 1rem; padding: 0.85rem;" 
        @click="claimYield"
        :disabled="isClaiming || !userStaked || (userStaked as bigint) === 0n"
        :style="{ opacity: (!userStaked || (userStaked as bigint) === 0n) ? 0.5 : 1, cursor: (!userStaked || (userStaked as bigint) === 0n) ? 'not-allowed' : 'pointer' }"
      >
        {{ isClaiming ? 'Harvesting...' : 'Harvest Staking Yields' }}
      </button>
    </div>
  </div>
</template>
