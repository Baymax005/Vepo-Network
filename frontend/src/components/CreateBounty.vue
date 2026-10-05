<script setup lang="ts">
import { ref } from 'vue'
import { useWriteContract, useAccount, useConfig } from '@wagmi/vue'
import { readContract, waitForTransactionReceipt } from '@wagmi/core'
import { parseEther } from 'viem'
import { BOUNTY_ADDRESS, TOKEN_ADDRESS, FAUCET_ADDRESS, VepoBountyABI, VepoTokenABI, VepoFaucetABI } from '../abi'
import { useToast } from '../useToast'

const amount = ref('')
const boost = ref(false)
const isSubmitting = ref(false)
const statusText = ref('')
const isClaimingFaucet = ref(false)

const { address } = useAccount()
const config = useConfig()
const { writeContractAsync } = useWriteContract()
const { addToast } = useToast()

const submitBounty = async () => {
  if (!amount.value || Number(amount.value) <= 0) {
    addToast('Please enter a valid bounty amount.', 'error')
    return
  }
  
  if (!address.value) {
    addToast('Wallet not connected. Please connect wallet first.', 'error')
    return
  }

  isSubmitting.value = true
  statusText.value = 'Checking $VEPO fee allowance...'
  
  try {
    // Listing fee is 5 VEPO; boost fee is 100 VEPO if selected
    const requiredAllowance = boost.value ? parseEther('105') : parseEther('5')

    // 1. Check existing allowance
    const currentAllowance = await readContract(config, {
      address: TOKEN_ADDRESS,
      abi: VepoTokenABI,
      functionName: 'allowance',
      args: [address.value, BOUNTY_ADDRESS],
    }) as bigint

    // 2. Approve if needed
    if (currentAllowance < requiredAllowance) {
      statusText.value = 'Approving $VEPO fee transfer...'
      addToast('Approving $VEPO platform fee...', 'info')
      const approveHash = await writeContractAsync({
        address: TOKEN_ADDRESS,
        abi: VepoTokenABI,
        functionName: 'approve',
        args: [BOUNTY_ADDRESS, requiredAllowance],
      })
      await waitForTransactionReceipt(config, { hash: approveHash })
      addToast('$VEPO fee approved!', 'success')
    }

    // 3. Post the bounty (burns/splits listing fee)
    statusText.value = 'Posting bounty to L3...'
    addToast('Broadcasting bounty transaction...', 'info')
    const postHash = await writeContractAsync({
      address: BOUNTY_ADDRESS,
      abi: VepoBountyABI,
      functionName: 'postBounty',
      value: parseEther(amount.value.toString()),
    })
    await waitForTransactionReceipt(config, { hash: postHash })

    // 4. Boost if toggled
    if (boost.value) {
      statusText.value = 'Boosting gig to top of feed...'
      addToast('Applying 100 $VEPO boost...', 'info')
      const currentCounter = await readContract(config, {
        address: BOUNTY_ADDRESS,
        abi: VepoBountyABI,
        functionName: 'bountyCounter',
      }) as bigint

      const boostHash = await writeContractAsync({
        address: BOUNTY_ADDRESS,
        abi: VepoBountyABI,
        functionName: 'boostBounty',
        args: [currentCounter],
      })
      await waitForTransactionReceipt(config, { hash: boostHash })
      addToast('Bounty successfully posted and boosted', 'success')
    } else {
      addToast('Bounty successfully posted to feed', 'success')
    }

    amount.value = ''
    boost.value = false
  } catch (err: any) {
    console.error('Post bounty error:', err)
    addToast('Transaction failed: ' + (err.shortMessage || err.message), 'error')
  } finally {
    isSubmitting.value = false
    statusText.value = ''
  }
}

const claimFaucet = async () => {
  if (isClaimingFaucet.value) return
  isClaimingFaucet.value = true
  addToast('Requesting 1,000 $VEPO from Faucet...', 'info')
  try {
    const hash = await writeContractAsync({
      address: FAUCET_ADDRESS,
      abi: VepoFaucetABI,
      functionName: 'requestTokens',
    })
    await waitForTransactionReceipt(config, { hash })
    addToast('Claimed 1,000 $VEPO from Reserve Faucet', 'success')
  } catch (err: any) {
    console.error('Faucet error:', err)
    addToast('Faucet failed: ' + (err.shortMessage || err.message), 'error')
  } finally {
    isClaimingFaucet.value = false
  }
}
</script>

<template>
  <div class="glass-panel">
    <div class="section-header">
      <h2 style="margin: 0;">
        Post a New Gig
      </h2>
    </div>

    <div class="form-group" style="margin-bottom: 1.25rem;">
      <label style="display: block; font-size: 0.85rem; font-weight: 600; color: var(--text-muted); margin-bottom: 0.5rem;">
        Bounty Escrow Amount (Native Gas / USDC)
      </label>
      <input
        type="number"
        class="input-field"
        v-model="amount"
        placeholder="e.g. 50"
        :disabled="isSubmitting"
      />
    </div>

    <label class="toggle-switch" style="display: flex; align-items: center; gap: 0.75rem; margin-bottom: 1.25rem; cursor: pointer;">
      <input type="checkbox" v-model="boost" style="display: none;" :disabled="isSubmitting" />
      <span class="toggle-slider"></span>
      <span style="font-size: 0.9rem; font-weight: 500;">
        Priority Boost (100 $VEPO)
      </span>
    </label>

    <div style="font-size: 0.75rem; color: var(--text-dim); margin-bottom: 1rem; line-height: 1.4;">
      Platform listing fee: <strong>5 $VEPO</strong> (80% permanently burned, 20% distributed to $VEPO stakers).
    </div>

    <button
      class="btn-primary"
      style="width: 100%; display: flex; justify-content: center; align-items: center; gap: 0.5rem;"
      @click="submitBounty"
      :disabled="isSubmitting || !amount"
    >
      <span v-if="isSubmitting" class="wallet-dot" style="background: #000;"></span>
      <span>{{ isSubmitting ? statusText || 'Processing...' : 'Post Bounty to Feed' }}</span>
    </button>

    <div style="margin-top: 1.75rem; padding-top: 1.25rem; border-top: 1px solid var(--glass-border);">
      <div style="display: flex; justify-content: space-between; align-items: center;">
        <div>
          <div style="font-size: 0.85rem; font-weight: 600;">Need Test $VEPO?</div>
          <div style="font-size: 0.75rem; color: var(--text-dim);">Get 1,000 $VEPO for testing fees & staking</div>
        </div>
        <button
          class="btn-outline"
          @click="claimFaucet"
          :disabled="isClaimingFaucet"
        >
          {{ isClaimingFaucet ? 'Claiming...' : 'Claim Faucet' }}
        </button>
      </div>
    </div>
  </div>
</template>
