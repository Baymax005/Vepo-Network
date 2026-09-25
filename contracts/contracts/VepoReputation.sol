// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VepoReputation
 * @author Vepo Network
 * @notice On-chain reputation scoring system for the Vepo freelance economy.
 *
 * @dev Tracks freelancer performance metrics to enable trust-minimized hiring:
 *
 * - **Jobs Completed:** Total bounties successfully delivered.
 * - **Jobs Failed:** Total disputes lost by the freelancer.
 * - **Reputation Score:** Computed as `(completed * 100) / (completed + failed)`.
 *   A score of 100 means perfect delivery; 0 means all work was disputed.
 *
 * Only the authorized VepoBounty contract (or protocol admin) can update scores,
 * preventing self-reported or inflated reputation.
 *
 * Future extensions:
 * - Category-specific reputation (design, dev, writing).
 * - Decay over time (inactive freelancers lose reputation gradually).
 * - Integration with VepoSkillBadges for verified credentials.
 */
contract VepoReputation is Ownable {

    /// @notice Address of the VepoBounty contract authorized to update reputation.
    address public bountyContract;

    /// @notice On-chain reputation profile for a freelancer.
    struct ReputationProfile {
        uint256 jobsCompleted;
        uint256 jobsFailed;
        uint256 totalEarned;
        uint256 firstActivityAt;
        uint256 lastActivityAt;
    }

    /// @notice Mapping of freelancer address to their reputation profile.
    mapping(address => ReputationProfile) public profiles;

    /// @notice List of all freelancers who have a reputation profile.
    address[] public registeredFreelancers;

    /// @notice Tracks whether a freelancer has been registered (prevents duplicate entries).
    mapping(address => bool) public isRegistered;

    // ──────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────

    /// @notice Emitted when a freelancer's job completion count is incremented.
    event JobCompleted(address indexed freelancer, uint256 totalCompleted, uint256 earned);

    /// @notice Emitted when a freelancer's job failure count is incremented.
    event JobFailed(address indexed freelancer, uint256 totalFailed);

    /// @notice Emitted when the authorized bounty contract address is updated.
    event BountyContractUpdated(address indexed newBountyContract);

    // ──────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────

    /**
     * @notice Initializes the reputation system.
     * @param _bountyContract Address of the VepoBounty contract authorized to record outcomes.
     */
    constructor(address _bountyContract) Ownable(msg.sender) {
        bountyContract = _bountyContract;
    }

    // ──────────────────────────────────────────────
    // Access Control
    // ──────────────────────────────────────────────

    /// @dev Restricts calls to the authorized bounty contract or the protocol owner.
    modifier onlyAuthorized() {
        require(
            msg.sender == bountyContract || msg.sender == owner(),
            "VepoReputation: unauthorized caller"
        );
        _;
    }

    /**
     * @notice Updates the authorized bounty contract address.
     * @param _newBountyContract New VepoBounty contract address.
     */
    function setBountyContract(address _newBountyContract) external onlyOwner {
        require(_newBountyContract != address(0), "Invalid address");
        bountyContract = _newBountyContract;
        emit BountyContractUpdated(_newBountyContract);
    }

    // ──────────────────────────────────────────────
    // Reputation Recording
    // ──────────────────────────────────────────────

    /**
     * @notice Records a successful job completion for a freelancer.
     * @param freelancer The freelancer's address.
     * @param earned The amount earned from this job (in wei).
     */
    function recordCompletion(address freelancer, uint256 earned) external onlyAuthorized {
        _ensureRegistered(freelancer);

        ReputationProfile storage profile = profiles[freelancer];
        profile.jobsCompleted += 1;
        profile.totalEarned += earned;
        profile.lastActivityAt = block.timestamp;

        emit JobCompleted(freelancer, profile.jobsCompleted, earned);
    }

    /**
     * @notice Records a failed job (dispute lost) for a freelancer.
     * @param freelancer The freelancer's address.
     */
    function recordFailure(address freelancer) external onlyAuthorized {
        _ensureRegistered(freelancer);

        ReputationProfile storage profile = profiles[freelancer];
        profile.jobsFailed += 1;
        profile.lastActivityAt = block.timestamp;

        emit JobFailed(freelancer, profile.jobsFailed);
    }

    // ──────────────────────────────────────────────
    // View Functions
    // ──────────────────────────────────────────────

    /**
     * @notice Computes the reputation score for a freelancer (0–100).
     * @param freelancer The freelancer's address.
     * @return score The reputation score. Returns 0 if the freelancer has no history.
     */
    function getReputationScore(address freelancer) external view returns (uint256 score) {
        ReputationProfile storage profile = profiles[freelancer];
        uint256 totalJobs = profile.jobsCompleted + profile.jobsFailed;
        if (totalJobs == 0) return 0;
        return (profile.jobsCompleted * 100) / totalJobs;
    }

    /**
     * @notice Returns the full reputation profile for a freelancer.
     * @param freelancer The freelancer's address.
     * @return The reputation profile struct.
     */
    function getProfile(address freelancer) external view returns (ReputationProfile memory) {
        return profiles[freelancer];
    }

    /**
     * @notice Returns the total number of registered freelancers.
     * @return The count of unique freelancers with reputation history.
     */
    function getFreelancerCount() external view returns (uint256) {
        return registeredFreelancers.length;
    }

    // ──────────────────────────────────────────────
    // Internal Helpers
    // ──────────────────────────────────────────────

    /**
     * @dev Ensures a freelancer is registered in the directory on their first interaction.
     * @param freelancer The freelancer's address.
     */
    function _ensureRegistered(address freelancer) internal {
        if (!isRegistered[freelancer]) {
            isRegistered[freelancer] = true;
            registeredFreelancers.push(freelancer);
            profiles[freelancer].firstActivityAt = block.timestamp;
        }
    }
}
