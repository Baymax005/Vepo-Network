<script setup lang="ts">
import { ref, computed, watchEffect, onUnmounted } from 'vue'
import { useReadContract, useWriteContract, useAccount, useConfig } from '@wagmi/vue'
import { readContract, waitForTransactionReceipt } from '@wagmi/core'
import { GOVERNANCE_ADDRESS, TOKEN_ADDRESS, VepoGovernanceABI, VepoTokenABI } from '../abi'
import { formatEther } from 'viem'
import { useToast } from '../useToast'

interface ProposalItem {
  id: bigint
  proposer: string
  title: string
  description: string
  votesFor: bigint
  votesAgainst: bigint
  startTime: bigint
  endTime: bigint
  state: number // 0: Active, 1: Passed, 2: Rejected, 3: Executed, 4: Cancelled
  userHasVoted?: boolean
  userVoteWeight?: bigint
}

const config = useConfig()
const { address } = useAccount()
const { addToast } = useToast()
const { writeContractAsync } = useWriteContract()

// Form state
const title = ref('')
const description = ref('')
const isCreating = ref(false)
const actionLoading = ref<Record<string, boolean>>({})

// Proposals list
const proposalsList = ref<ProposalItem[]>([])
const isLoadingList = ref(false)

// Read governance parameters
const { data: proposalCount, refetch: refetchCount } = useReadContract({
  address: GOVERNANCE_ADDRESS,
  abi: VepoGovernanceABI,
  functionName: 'proposalCount',
  query: { refetchInterval: 5000 }
})

const { data: proposalThreshold } = useReadContract({
  address: GOVERNANCE_ADDRESS,
  abi: VepoGovernanceABI,
  functionName: 'proposalThreshold',
  query: { refetchInterval: 10000 }
})

const { data: quorum } = useReadContract({
  address: GOVERNANCE_ADDRESS,
  abi: VepoGovernanceABI,
  functionName: 'quorum',
  query: { refetchInterval: 10000 }
})

const { data: userVepoBalance } = useReadContract({
  address: TOKEN_ADDRESS,
  abi: VepoTokenABI,
  functionName: 'balanceOf',
  args: address.value ? [address.value] : undefined,
  query: { refetchInterval: 5000 }
})

// Computed stats
const formattedThreshold = computed(() => {
  if (!proposalThreshold.value) return '10,000'
  return Number(formatEther(proposalThreshold.value as bigint)).toLocaleString()
})

const formattedQuorum = computed(() => {
  if (!quorum.value) return '100,000'
  return Number(formatEther(quorum.value as bigint)).toLocaleString()
})

const activeProposalsCount = computed(() => {
  return proposalsList.value.filter(p => p.state === 0).length
})

const canCreateProposal = computed(() => {
  if (!userVepoBalance.value || !proposalThreshold.value) return false
  return (userVepoBalance.value as bigint) >= (proposalThreshold.value as bigint)
})

// Fetch proposals
const fetchProposals = async () => {
  const count = Number(proposalCount.value || 0)
  if (count === 0) {
    proposalsList.value = []
    return
  }

  isLoadingList.value = true
  const list: ProposalItem[] = []

  for (let i = count; i >= 1; i--) {
    try {
      const data: any = await readContract(config, {
        address: GOVERNANCE_ADDRESS,
        abi: VepoGovernanceABI,
        functionName: 'getProposal',
        args: [BigInt(i)],
      })

      let userVoted = false
      let userWeight = 0n
      if (address.value) {
        userVoted = (await readContract(config, {
          address: GOVERNANCE_ADDRESS,
          abi: VepoGovernanceABI,
          functionName: 'hasVoted',
          args: [BigInt(i), address.value],
        })) as boolean

        if (userVoted) {
          userWeight = (await readContract(config, {
            address: GOVERNANCE_ADDRESS,
            abi: VepoGovernanceABI,
            functionName: 'voteWeight',
            args: [BigInt(i), address.value],
          })) as bigint
        }
      }

      list.push({
        id: data.id ?? data[0],
        proposer: data.proposer ?? data[1],
        title: data.title ?? data[2],
        description: data.description ?? data[3],
        votesFor: data.votesFor ?? data[4],
        votesAgainst: data.votesAgainst ?? data[5],
        startTime: data.startTime ?? data[6],
        endTime: data.endTime ?? data[7],
        state: Number(data.state ?? data[8]),
        userHasVoted: userVoted,
        userVoteWeight: userWeight,
      })
    } catch (e) {
      console.error(`Failed to fetch proposal ${i}:`, e)
    }
  }

  proposalsList.value = list
  isLoadingList.value = false
}

let refreshInterval: any
watchEffect(() => {
  fetchProposals()
  if (!refreshInterval) {
    refreshInterval = setInterval(fetchProposals, 10000)
  }
})

onUnmounted(() => {
  if (refreshInterval) clearInterval(refreshInterval)
})

// Handlers
const handleCreateProposal = async () => {
  if (!title.value.trim() || !description.value.trim()) {
    addToast('Please provide both a title and description.', 'error')
    return
  }

  if (!canCreateProposal.value) {
    addToast(`Insufficient $VEPO. You need at least ${formattedThreshold.value} $VEPO to propose.`, 'error')
    return
  }

  isCreating.value = true
  try {
    const hash = await writeContractAsync({
      address: GOVERNANCE_ADDRESS,
      abi: VepoGovernanceABI,
      functionName: 'createProposal',
      args: [title.value.trim(), description.value.trim()],
    })

    addToast('Proposal submitted. Awaiting confirmation...', 'info')
    await waitForTransactionReceipt(config, { hash })
    addToast('Proposal created successfully.', 'success')

    title.value = ''
    description.value = ''
    refetchCount()
    await fetchProposals()
  } catch (err: any) {
    addToast(err.shortMessage || 'Failed to create proposal.', 'error')
  } finally {
    isCreating.value = false
  }
}

const handleVote = async (proposalId: bigint, support: boolean) => {
  const key = `vote-${proposalId}-${support}`
  actionLoading.value[key] = true

  try {
    const hash = await writeContractAsync({
      address: GOVERNANCE_ADDRESS,
      abi: VepoGovernanceABI,
      functionName: 'castVote',
      args: [proposalId, support],
    })

    addToast(`Casting vote ${support ? 'FOR' : 'AGAINST'}...`, 'info')
    await waitForTransactionReceipt(config, { hash })
    addToast(`Vote recorded successfully.`, 'success')
    await fetchProposals()
  } catch (err: any) {
    addToast(err.shortMessage || 'Failed to cast vote.', 'error')
  } finally {
    actionLoading.value[key] = false
  }
}

const handleFinalize = async (proposalId: bigint) => {
  const key = `finalize-${proposalId}`
  actionLoading.value[key] = true

  try {
    const hash = await writeContractAsync({
      address: GOVERNANCE_ADDRESS,
      abi: VepoGovernanceABI,
      functionName: 'finalizeProposal',
      args: [proposalId],
    })

    addToast('Finalizing proposal...', 'info')
    await waitForTransactionReceipt(config, { hash })
    addToast('Proposal finalized successfully.', 'success')
    await fetchProposals()
  } catch (err: any) {
    addToast(err.shortMessage || 'Failed to finalize proposal.', 'error')
  } finally {
    actionLoading.value[key] = false
  }
}

// Helpers
const getStateInfo = (state: number) => {
  switch (state) {
    case 0:
      return { label: 'Active', color: 'green', class: 'badge-active' }
    case 1:
      return { label: 'Passed', color: 'blue', class: 'badge-passed' }
    case 2:
      return { label: 'Rejected', color: 'red', class: 'badge-rejected' }
    case 3:
      return { label: 'Executed', color: 'purple', class: 'badge-executed' }
    case 4:
      return { label: 'Cancelled', color: 'dim', class: 'badge-cancelled' }
    default:
      return { label: 'Unknown', color: 'dim', class: 'badge-unknown' }
  }
}

const formatTokens = (wei: bigint) => {
  const val = Number(formatEther(wei))
  if (val >= 1_000_000) return (val / 1_000_000).toFixed(2) + 'M'
  if (val >= 1_000) return (val / 1_000).toFixed(1) + 'k'
  return val.toLocaleString(undefined, { maximumFractionDigits: 1 })
}

const formatRemainingTime = (endTime: bigint) => {
  const now = Math.floor(Date.now() / 1000)
  const remaining = Number(endTime) - now
  if (remaining <= 0) return 'Voting closed'
  const days = Math.floor(remaining / 86400)
  const hours = Math.floor((remaining % 86400) / 3600)
  if (days > 0) return `${days}d ${hours}h remaining`
  const minutes = Math.floor((remaining % 3600) / 60)
  return `${hours}h ${minutes}m remaining`
}

const isVotingEnded = (endTime: bigint) => {
  const now = Math.floor(Date.now() / 1000)
  return Number(endTime) <= now
}

const getVotePercentages = (forVotes: bigint, againstVotes: bigint) => {
  const total = forVotes + againstVotes
  if (total === 0n) return { forPct: 50, againstPct: 50, totalVotes: 0n }
  const forPct = Number((forVotes * 100n) / total)
  const againstPct = 100 - forPct
  return { forPct, againstPct, totalVotes: total }
}
</script>

<template>
  <div class="gov-container">
    <!-- Top Governance Metrics -->
    <div class="stats-bar">
      <div class="stat-card">
        <div class="stat-label">Total Proposals</div>
        <div class="stat-value blue">{{ Number(proposalCount || 0) }}</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Active Proposals</div>
        <div class="stat-value green">{{ activeProposalsCount }}</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Proposal Threshold</div>
        <div class="stat-value purple">{{ formattedThreshold }} VEPO</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Quorum Required</div>
        <div class="stat-value">{{ formattedQuorum }} VEPO</div>
      </div>
    </div>

    <div class="layout-grid">
      <!-- Create Proposal Panel -->
      <div>
        <div class="glass-panel">
          <div class="section-header">
            <h2 class="section-title">
              <span class="indicator-dot green"></span>
              Create Proposal
            </h2>
          </div>
          <p class="panel-subtitle">
            Submit parameter adjustments, fee updates, or protocol improvement proposals to the Vepo DAO.
          </p>

          <div class="threshold-notice" :class="{ 'notice-valid': canCreateProposal, 'notice-invalid': !canCreateProposal }">
            <div class="notice-indicator">
              <span class="status-dot" :class="canCreateProposal ? 'green' : 'red'"></span>
              <span>
                {{ canCreateProposal ? 'Eligible to propose' : 'Threshold not met' }}
              </span>
            </div>
            <div class="notice-detail">
              Requires {{ formattedThreshold }} $VEPO balance
            </div>
          </div>

          <div style="margin-top: 1.25rem;">
            <label class="form-label">Proposal Title</label>
            <input
              v-model="title"
              type="text"
              class="input-field"
              placeholder="e.g. VIP-1: Reduce Freelancer Application Fee"
              :disabled="isCreating"
            />
          </div>

          <div>
            <label class="form-label">Detailed Description</label>
            <textarea
              v-model="description"
              class="input-field"
              rows="5"
              placeholder="Outline proposal rationale, target parameters, and expected protocol impact..."
              :disabled="isCreating"
            ></textarea>
          </div>

          <button
            class="btn-primary"
            style="width: 100%; margin-top: 0.5rem;"
            :disabled="isCreating || !canCreateProposal || !title.trim() || !description.trim()"
            @click="handleCreateProposal"
          >
            {{ isCreating ? 'Submitting Proposal...' : 'Submit Proposal' }}
          </button>
        </div>
      </div>

      <!-- Proposals Feed -->
      <div>
        <div class="glass-panel">
          <div class="section-header">
            <h2 class="section-title">
              <span class="indicator-dot purple"></span>
              On-Chain Proposals
            </h2>
            <button class="btn-outline" style="padding: 0.4rem 0.8rem; font-size: 0.75rem;" @click="fetchProposals">
              Refresh Feed
            </button>
          </div>

          <div v-if="proposalsList.length === 0" class="empty-state">
            <div class="empty-icon-box">VIP</div>
            <div class="empty-title">No Proposals Found</div>
            <div class="empty-desc">
              No governance proposals have been registered on-chain yet. Propose the first protocol parameter change.
            </div>
          </div>

          <div v-else class="proposals-stack">
            <div
              v-for="p in proposalsList"
              :key="p.id.toString()"
              class="proposal-item"
            >
              <div class="proposal-header">
                <div class="proposal-title-wrap">
                  <span class="proposal-id">#{{ p.id.toString() }}</span>
                  <span class="proposal-title">{{ p.title }}</span>
                </div>
                <div class="status-pill" :class="getStateInfo(p.state).class">
                  <span class="status-dot" :class="getStateInfo(p.state).color"></span>
                  <span>{{ getStateInfo(p.state).label }}</span>
                </div>
              </div>

              <div class="proposal-meta">
                <span>Proposer: <code>{{ p.proposer.slice(0, 6) }}...{{ p.proposer.slice(-4) }}</code></span>
                <span>•</span>
                <span>{{ formatRemainingTime(p.endTime) }}</span>
              </div>

              <p class="proposal-desc">{{ p.description }}</p>

              <!-- Voting Bar -->
              <div class="vote-bar-container">
                <div class="vote-bar-labels">
                  <span class="vote-label-for">
                    FOR: {{ formatTokens(p.votesFor) }} ({{ getVotePercentages(p.votesFor, p.votesAgainst).forPct }}%)
                  </span>
                  <span class="vote-label-against">
                    AGAINST: {{ formatTokens(p.votesAgainst) }} ({{ getVotePercentages(p.votesFor, p.votesAgainst).againstPct }}%)
                  </span>
                </div>
                <div class="vote-bar-track">
                  <div
                    class="vote-bar-fill for"
                    :style="{ width: getVotePercentages(p.votesFor, p.votesAgainst).forPct + '%' }"
                  ></div>
                  <div
                    class="vote-bar-fill against"
                    :style="{ width: getVotePercentages(p.votesFor, p.votesAgainst).againstPct + '%' }"
                  ></div>
                </div>
              </div>

              <!-- Proposal Action Buttons -->
              <div class="proposal-actions">
                <template v-if="p.state === 0 && !isVotingEnded(p.endTime)">
                  <div v-if="p.userHasVoted" class="voted-indicator">
                    <span class="status-dot green"></span>
                    <span>Vote Recorded (Weight: {{ formatTokens(p.userVoteWeight || 0n) }} $VEPO)</span>
                  </div>
                  <div v-else class="vote-btn-group">
                    <button
                      class="btn-primary vote-btn for"
                      :disabled="actionLoading[`vote-${p.id}-true`]"
                      @click="handleVote(p.id, true)"
                    >
                      <span class="status-dot green"></span>
                      Vote For
                    </button>
                    <button
                      class="btn-outline vote-btn against"
                      :disabled="actionLoading[`vote-${p.id}-false`]"
                      @click="handleVote(p.id, false)"
                    >
                      <span class="status-dot red"></span>
                      Vote Against
                    </button>
                  </div>
                </template>

                <template v-else-if="p.state === 0 && isVotingEnded(p.endTime)">
                  <button
                    class="btn-primary"
                    style="font-size: 0.8rem; padding: 0.5rem 1rem;"
                    :disabled="actionLoading[`finalize-${p.id}`]"
                    @click="handleFinalize(p.id)"
                  >
                    {{ actionLoading[`finalize-${p.id}`] ? 'Finalizing...' : 'Finalize Proposal' }}
                  </button>
                </template>

                <div v-else class="concluded-notice">
                  Voting Concluded • {{ getStateInfo(p.state).label }}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.gov-container {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.indicator-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  display: inline-block;
}

.indicator-dot.green { background: var(--primary); }
.indicator-dot.purple { background: var(--accent); }

.panel-subtitle {
  color: var(--text-muted);
  font-size: 0.85rem;
  line-height: 1.5;
  margin-top: -0.5rem;
  margin-bottom: 1.25rem;
}

.threshold-notice {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem 1rem;
  border-radius: 10px;
  font-size: 0.8rem;
  border: 1px solid var(--glass-border);
}

.notice-valid {
  background: rgba(16, 185, 129, 0.08);
  border-color: rgba(16, 185, 129, 0.25);
  color: #6ee7b7;
}

.notice-invalid {
  background: rgba(239, 68, 68, 0.08);
  border-color: rgba(239, 68, 68, 0.25);
  color: #fca5a5;
}

.notice-indicator {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-weight: 600;
}

.notice-detail {
  font-size: 0.75rem;
  color: var(--text-dim);
}

.form-label {
  display: block;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--text-muted);
  margin-bottom: 0.35rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.proposals-stack {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
  margin-top: 1rem;
}

.proposal-item {
  background: rgba(0, 0, 0, 0.25);
  border: 1px solid var(--glass-border);
  border-radius: 12px;
  padding: 1.25rem;
  transition: border-color 0.2s ease;
}

.proposal-item:hover {
  border-color: rgba(255, 255, 255, 0.15);
}

.proposal-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 1rem;
  margin-bottom: 0.5rem;
}

.proposal-title-wrap {
  display: flex;
  align-items: center;
  gap: 0.6rem;
}

.proposal-id {
  font-size: 0.75rem;
  font-weight: 700;
  color: var(--primary);
  background: rgba(var(--primary-rgb), 0.1);
  padding: 2px 6px;
  border-radius: 6px;
}

.proposal-title {
  font-size: 1.05rem;
  font-weight: 700;
  color: var(--text-light);
}

.proposal-meta {
  font-size: 0.75rem;
  color: var(--text-dim);
  display: flex;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
}

.proposal-desc {
  font-size: 0.85rem;
  color: var(--text-muted);
  line-height: 1.5;
  margin-bottom: 1rem;
  white-space: pre-wrap;
}

/* Status Pill */
.status-pill {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 3px 10px;
  border-radius: 20px;
  font-size: 0.72rem;
  font-weight: 600;
  border: 1px solid transparent;
}

.status-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
}

.status-dot.green { background: var(--primary); }
.status-dot.blue { background: var(--info); }
.status-dot.red { background: var(--danger); }
.status-dot.purple { background: var(--accent); }
.status-dot.dim { background: var(--text-dim); }

.badge-active {
  background: rgba(16, 185, 129, 0.12);
  border-color: rgba(16, 185, 129, 0.3);
  color: #6ee7b7;
}

.badge-passed {
  background: rgba(59, 130, 246, 0.12);
  border-color: rgba(59, 130, 246, 0.3);
  color: #93c5fd;
}

.badge-rejected {
  background: rgba(239, 68, 68, 0.12);
  border-color: rgba(239, 68, 68, 0.3);
  color: #fca5a5;
}

.badge-executed {
  background: rgba(99, 102, 241, 0.12);
  border-color: rgba(99, 102, 241, 0.3);
  color: #c7d2fe;
}

.badge-cancelled {
  background: rgba(100, 116, 139, 0.12);
  border-color: rgba(100, 116, 139, 0.3);
  color: #cbd5e1;
}

/* Vote Bar */
.vote-bar-container {
  background: rgba(0, 0, 0, 0.3);
  padding: 0.75rem 1rem;
  border-radius: 8px;
  border: 1px solid var(--glass-border);
  margin-bottom: 1rem;
}

.vote-bar-labels {
  display: flex;
  justify-content: space-between;
  font-size: 0.75rem;
  font-weight: 600;
  margin-bottom: 0.4rem;
}

.vote-label-for { color: var(--primary); }
.vote-label-against { color: var(--danger); }

.vote-bar-track {
  height: 8px;
  border-radius: 4px;
  overflow: hidden;
  background: rgba(255, 255, 255, 0.05);
  display: flex;
}

.vote-bar-fill.for {
  background: var(--primary);
  transition: width 0.3s ease;
}

.vote-bar-fill.against {
  background: var(--danger);
  transition: width 0.3s ease;
}

/* Actions */
.proposal-actions {
  display: flex;
  justify-content: flex-end;
  align-items: center;
}

.vote-btn-group {
  display: flex;
  gap: 0.75rem;
}

.vote-btn {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.45rem 0.9rem;
  font-size: 0.8rem;
}

.vote-btn.for {
  background: rgba(16, 185, 129, 0.15);
  border: 1px solid rgba(16, 185, 129, 0.3);
  color: #6ee7b7;
}

.vote-btn.for:hover {
  background: rgba(16, 185, 129, 0.25);
}

.vote-btn.against {
  border-color: rgba(239, 68, 68, 0.3);
  color: #fca5a5;
}

.vote-btn.against:hover {
  border-color: var(--danger);
  background: rgba(239, 68, 68, 0.1);
  color: #fca5a5;
}

.voted-indicator {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.78rem;
  color: var(--primary);
  font-weight: 500;
  background: rgba(var(--primary-rgb), 0.08);
  padding: 0.4rem 0.8rem;
  border-radius: 8px;
  border: 1px solid rgba(var(--primary-rgb), 0.2);
}

.concluded-notice {
  font-size: 0.75rem;
  color: var(--text-dim);
  font-weight: 500;
}

.empty-state {
  text-align: center;
  padding: 3rem 1.5rem;
}

.empty-icon-box {
  width: 50px;
  height: 50px;
  border-radius: 14px;
  background: rgba(99, 102, 241, 0.1);
  border: 1px solid rgba(99, 102, 241, 0.25);
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 0.9rem;
  color: var(--accent);
  margin: 0 auto 1rem;
}

.empty-title {
  font-size: 1.1rem;
  font-weight: 700;
  color: var(--text-light);
  margin-bottom: 0.35rem;
}

.empty-desc {
  font-size: 0.85rem;
  color: var(--text-dim);
  max-width: 380px;
  margin: 0 auto;
  line-height: 1.5;
}
</style>
