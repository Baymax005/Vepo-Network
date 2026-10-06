<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useReadContract, useAccount, useConfig } from '@wagmi/vue'
import { readContract } from '@wagmi/core'
import { REPUTATION_ADDRESS, VepoReputationABI } from '../abi'
import { formatEther } from 'viem'
import { useToast } from '../useToast'

interface ProfileData {
  jobsCompleted: bigint
  jobsFailed: bigint
  totalEarned: bigint
  firstActivityAt: bigint
  lastActivityAt: bigint
}

const config = useConfig()
const { address } = useAccount()
const { addToast } = useToast()

const searchAddress = ref('')
const isLoading = ref(false)
const hasSearched = ref(false)
const isFound = ref(false)
const searchedProfile = ref<ProfileData | null>(null)
const searchedScore = ref<number>(0)
const currentSearchedAddress = ref('')

// Read total freelancer count
const { data: totalFreelancers } = useReadContract({
  address: REPUTATION_ADDRESS,
  abi: VepoReputationABI,
  functionName: 'getFreelancerCount',
  query: { refetchInterval: 10000 }
})

// Lookup function
const lookupProfile = async (targetAddress?: string) => {
  const target = (targetAddress || searchAddress.value).trim()
  if (!target) {
    addToast('Please enter a valid wallet address.', 'error')
    return
  }

  if (!target.startsWith('0x') || target.length !== 42) {
    addToast('Invalid Ethereum address format (must be 42 characters starting with 0x).', 'error')
    return
  }

  isLoading.value = true
  hasSearched.value = true
  currentSearchedAddress.value = target

  try {
    const registered = (await readContract(config, {
      address: REPUTATION_ADDRESS,
      abi: VepoReputationABI,
      functionName: 'isRegistered',
      args: [target as `0x${string}`],
    })) as boolean

    if (!registered) {
      isFound.value = false
      searchedProfile.value = null
      searchedScore.value = 0
      addToast('No on-chain reputation record found for this address.', 'info')
      return
    }

    const [profileRaw, repScoreRaw] = await Promise.all([
      readContract(config, {
        address: REPUTATION_ADDRESS,
        abi: VepoReputationABI,
        functionName: 'getProfile',
        args: [target as `0x${string}`],
      }) as Promise<any>,
      readContract(config, {
        address: REPUTATION_ADDRESS,
        abi: VepoReputationABI,
        functionName: 'getReputationScore',
        args: [target as `0x${string}`],
      }) as Promise<bigint>,
    ])

    searchedProfile.value = {
      jobsCompleted: profileRaw.jobsCompleted ?? profileRaw[0],
      jobsFailed: profileRaw.jobsFailed ?? profileRaw[1],
      totalEarned: profileRaw.totalEarned ?? profileRaw[2],
      firstActivityAt: profileRaw.firstActivityAt ?? profileRaw[3],
      lastActivityAt: profileRaw.lastActivityAt ?? profileRaw[4],
    }
    searchedScore.value = Number(repScoreRaw)
    isFound.value = true
    addToast('Reputation profile loaded.', 'success')
  } catch (err: any) {
    console.error('Error fetching reputation:', err)
    addToast(err.shortMessage || 'Failed to query reputation profile.', 'error')
    isFound.value = false
    searchedProfile.value = null
  } finally {
    isLoading.value = false
  }
}

const viewMyProfile = () => {
  if (!address.value) {
    addToast('Please connect your wallet first.', 'error')
    return
  }
  searchAddress.value = address.value
  lookupProfile(address.value)
}

// Helpers
const formatDate = (timestamp: bigint) => {
  if (!timestamp || timestamp === 0n) return 'N/A'
  return new Date(Number(timestamp) * 1000).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  })
}

const formatTokens = (wei: bigint) => {
  if (!wei) return '0'
  const val = Number(formatEther(wei))
  return val.toLocaleString(undefined, { maximumFractionDigits: 2 })
}

const getScoreColorClass = (score: number) => {
  if (score >= 80) return 'green'
  if (score >= 50) return 'yellow'
  return 'red'
}

const getScoreTier = (score: number, totalJobs: number) => {
  if (totalJobs === 0) return { label: 'Unranked', color: 'dim' }
  if (score >= 95 && totalJobs >= 5) return { label: 'Elite Freelancer', color: 'green' }
  if (score >= 80) return { label: 'Highly Trusted', color: 'green' }
  if (score >= 60) return { label: 'Established', color: 'blue' }
  if (score >= 40) return { label: 'Caution Advised', color: 'yellow' }
  return { label: 'High Dispute Risk', color: 'red' }
}

onMounted(() => {
  if (address.value) {
    searchAddress.value = address.value
    lookupProfile(address.value)
  }
})
</script>

<template>
  <div class="rep-container">
    <!-- Top Stats Row -->
    <div class="stats-bar">
      <div class="stat-card">
        <div class="stat-label">Registered Freelancers</div>
        <div class="stat-value purple">{{ Number(totalFreelancers || 0) }}</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Scoring Engine</div>
        <div class="stat-value green">On-Chain</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Escrow Arbiter</div>
        <div class="stat-value blue">Decentralized</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Dispute Penalty</div>
        <div class="stat-value red">Permanent</div>
      </div>
    </div>

    <!-- Lookup Panel -->
    <div class="glass-panel">
      <div class="section-header">
        <h2 class="section-title">
          <span class="indicator-dot green"></span>
          Freelancer Reputation Search
        </h2>
      </div>
      <p class="panel-subtitle">
        Verify freelancer completion rates, dispute history, and total volume before hiring or funding bounties.
      </p>

      <div class="search-row">
        <div class="search-input-wrap">
          <input
            v-model="searchAddress"
            type="text"
            class="input-field search-input"
            placeholder="Search by 0x wallet address..."
            :disabled="isLoading"
            @keyup.enter="lookupProfile()"
          />
        </div>
        <div class="search-btn-group">
          <button
            class="btn-primary"
            :disabled="isLoading || !searchAddress.trim()"
            @click="lookupProfile()"
          >
            {{ isLoading ? 'Searching...' : 'Search Record' }}
          </button>
          <button
            class="btn-outline"
            :disabled="isLoading || !address"
            @click="viewMyProfile"
          >
            My Profile
          </button>
        </div>
      </div>
    </div>

    <!-- Results Display -->
    <div v-if="hasSearched">
      <!-- Profile Found -->
      <div v-if="isFound && searchedProfile" class="glass-panel profile-card">
        <div class="profile-header">
          <div>
            <div class="profile-tag">
              <span class="status-dot green"></span>
              <span>VERIFIED ON-CHAIN RECORD</span>
            </div>
            <h3 class="profile-address">
              {{ currentSearchedAddress }}
            </h3>
          </div>
          <div class="tier-pill" :class="getScoreTier(searchedScore, Number(searchedProfile.jobsCompleted + searchedProfile.jobsFailed)).color">
            <span class="status-dot" :class="getScoreTier(searchedScore, Number(searchedProfile.jobsCompleted + searchedProfile.jobsFailed)).color"></span>
            <span>{{ getScoreTier(searchedScore, Number(searchedProfile.jobsCompleted + searchedProfile.jobsFailed)).label }}</span>
          </div>
        </div>

        <!-- Big Score Metric -->
        <div class="score-showcase">
          <div class="score-number-wrap">
            <div class="score-number" :class="getScoreColorClass(searchedScore)">
              {{ searchedScore }}
            </div>
            <div class="score-max">/ 100</div>
          </div>
          <div class="score-details">
            <div class="score-title">Reputation Trust Score</div>
            <div class="score-desc">
              Computed strictly from verified deliverables: (Completed * 100) / (Completed + Disputed). Cannot be manipulated or forged by third parties.
            </div>
            <!-- Score Meter Bar -->
            <div class="score-meter-track">
              <div
                class="score-meter-fill"
                :class="getScoreColorClass(searchedScore)"
                :style="{ width: searchedScore + '%' }"
              ></div>
            </div>
          </div>
        </div>

        <!-- Detailed Metrics Grid -->
        <div class="metrics-grid">
          <div class="metric-box">
            <div class="metric-label">Jobs Completed</div>
            <div class="metric-value green">{{ searchedProfile.jobsCompleted.toString() }}</div>
            <div class="metric-sub">Successful deliveries</div>
          </div>
          <div class="metric-box">
            <div class="metric-label">Disputed / Failed</div>
            <div class="metric-value red">{{ searchedProfile.jobsFailed.toString() }}</div>
            <div class="metric-sub">Lost arbitrations</div>
          </div>
          <div class="metric-box">
            <div class="metric-label">Total Earned</div>
            <div class="metric-value purple">{{ formatTokens(searchedProfile.totalEarned) }}</div>
            <div class="metric-sub">USDC / Native volume</div>
          </div>
          <div class="metric-box">
            <div class="metric-label">First Active</div>
            <div class="metric-value text-dim">{{ formatDate(searchedProfile.firstActivityAt) }}</div>
            <div class="metric-sub">Registration date</div>
          </div>
          <div class="metric-box">
            <div class="metric-label">Last Active</div>
            <div class="metric-value text-dim">{{ formatDate(searchedProfile.lastActivityAt) }}</div>
            <div class="metric-sub">Most recent milestone</div>
          </div>
        </div>
      </div>

      <!-- Profile Not Found -->
      <div v-else class="glass-panel not-found-card">
        <div class="not-found-icon">0x</div>
        <div class="not-found-title">No Reputation Record Found</div>
        <p class="not-found-desc">
          Address <code>{{ currentSearchedAddress }}</code> has not completed or failed any escrow bounties on the Vepo Network yet.
        </p>
        <div class="not-found-hint">
          Reputation scores are automatically generated once a freelancer delivers work or enters arbitration.
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.rep-container {
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

.panel-subtitle {
  color: var(--text-muted);
  font-size: 0.85rem;
  line-height: 1.5;
  margin-top: -0.5rem;
  margin-bottom: 1.25rem;
}

.search-row {
  display: flex;
  gap: 1rem;
  align-items: flex-start;
}

.search-input-wrap {
  flex: 1;
}

.search-input {
  margin-bottom: 0;
  font-family: monospace;
  font-size: 0.85rem;
}

.search-btn-group {
  display: flex;
  gap: 0.5rem;
}

/* Profile Card */
.profile-card {
  padding: 2rem;
}

.profile-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 2rem;
  gap: 1rem;
  flex-wrap: wrap;
}

.profile-tag {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.7rem;
  font-weight: 700;
  color: var(--primary);
  letter-spacing: 0.08em;
  margin-bottom: 0.4rem;
}

.profile-address {
  font-family: monospace;
  font-size: 1.15rem;
  font-weight: 600;
  color: var(--text-light);
  margin: 0;
  word-break: break-all;
}

.tier-pill {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 4px 12px;
  border-radius: 20px;
  font-size: 0.75rem;
  font-weight: 600;
  border: 1px solid transparent;
}

.tier-pill.green {
  background: rgba(16, 185, 129, 0.12);
  border-color: rgba(16, 185, 129, 0.3);
  color: #6ee7b7;
}

.tier-pill.blue {
  background: rgba(59, 130, 246, 0.12);
  border-color: rgba(59, 130, 246, 0.3);
  color: #93c5fd;
}

.tier-pill.yellow {
  background: rgba(234, 179, 8, 0.12);
  border-color: rgba(234, 179, 8, 0.3);
  color: #fde047;
}

.tier-pill.red {
  background: rgba(239, 68, 68, 0.12);
  border-color: rgba(239, 68, 68, 0.3);
  color: #fca5a5;
}

.tier-pill.dim {
  background: rgba(100, 116, 139, 0.12);
  border-color: rgba(100, 116, 139, 0.3);
  color: #cbd5e1;
}

.status-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
}

.status-dot.green { background: var(--primary); }
.status-dot.blue { background: var(--info); }
.status-dot.yellow { background: var(--warning); }
.status-dot.red { background: var(--danger); }
.status-dot.dim { background: var(--text-dim); }

/* Score Showcase */
.score-showcase {
  display: flex;
  align-items: center;
  gap: 2rem;
  background: rgba(0, 0, 0, 0.3);
  padding: 1.5rem 2rem;
  border-radius: 14px;
  border: 1px solid var(--glass-border);
  margin-bottom: 2rem;
}

.score-number-wrap {
  display: flex;
  align-items: baseline;
  gap: 0.25rem;
}

.score-number {
  font-size: 3.5rem;
  font-weight: 800;
  line-height: 1;
}

.score-number.green { color: var(--primary); }
.score-number.yellow { color: var(--warning); }
.score-number.red { color: var(--danger); }

.score-max {
  font-size: 1.25rem;
  color: var(--text-dim);
  font-weight: 600;
}

.score-details {
  flex: 1;
}

.score-title {
  font-size: 1.05rem;
  font-weight: 700;
  color: var(--text-light);
  margin-bottom: 0.25rem;
}

.score-desc {
  font-size: 0.8rem;
  color: var(--text-dim);
  line-height: 1.4;
  margin-bottom: 0.85rem;
}

.score-meter-track {
  height: 10px;
  background: rgba(255, 255, 255, 0.08);
  border-radius: 5px;
  overflow: hidden;
}

.score-meter-fill {
  height: 100%;
  border-radius: 5px;
  transition: width 0.6s ease;
}

.score-meter-fill.green { background: var(--primary); }
.score-meter-fill.yellow { background: var(--warning); }
.score-meter-fill.red { background: var(--danger); }

/* Metrics Grid */
.metrics-grid {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 1rem;
}

@media (max-width: 900px) {
  .metrics-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

.metric-box {
  background: rgba(0, 0, 0, 0.25);
  border: 1px solid var(--glass-border);
  border-radius: 10px;
  padding: 1rem;
  text-align: center;
}

.metric-label {
  font-size: 0.72rem;
  color: var(--text-dim);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  font-weight: 600;
  margin-bottom: 0.35rem;
}

.metric-value {
  font-size: 1.25rem;
  font-weight: 700;
  margin-bottom: 0.25rem;
}

.metric-value.green { color: var(--primary); }
.metric-value.red { color: var(--danger); }
.metric-value.purple { color: var(--accent); }
.metric-value.text-dim { color: var(--text-light); font-size: 0.95rem; }

.metric-sub {
  font-size: 0.7rem;
  color: var(--text-dim);
}

/* Not Found State */
.not-found-card {
  text-align: center;
  padding: 3rem 1.5rem;
}

.not-found-icon {
  width: 50px;
  height: 50px;
  border-radius: 14px;
  background: rgba(239, 68, 68, 0.1);
  border: 1px solid rgba(239, 68, 68, 0.25);
  display: flex;
  align-items: center;
  justify-content: center;
  font-family: monospace;
  font-weight: 800;
  font-size: 1rem;
  color: var(--danger);
  margin: 0 auto 1rem;
}

.not-found-title {
  font-size: 1.15rem;
  font-weight: 700;
  color: var(--text-light);
  margin-bottom: 0.5rem;
}

.not-found-desc {
  font-size: 0.85rem;
  color: var(--text-muted);
  max-width: 440px;
  margin: 0 auto 0.75rem;
  line-height: 1.5;
}

.not-found-hint {
  font-size: 0.75rem;
  color: var(--text-dim);
}
</style>
