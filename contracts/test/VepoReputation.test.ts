import { expect } from "chai";
import { ethers } from "hardhat";

describe("VepoReputation (On-Chain Scoring)", function () {
    let vepoReputation: any;
    let owner: any;
    let bountyContract: any;
    let freelancer1: any;
    let freelancer2: any;
    let unauthorized: any;

    beforeEach(async function () {
        [owner, bountyContract, freelancer1, freelancer2, unauthorized] = await ethers.getSigners();

        const VepoReputation = await ethers.getContractFactory("VepoReputation");
        vepoReputation = await VepoReputation.deploy(bountyContract.address);
    });

    // ─── Authorization ───

    it("should allow the bounty contract to record completions", async function () {
        await vepoReputation.connect(bountyContract).recordCompletion(
            freelancer1.address,
            ethers.parseEther("50")
        );

        const profile = await vepoReputation.getProfile(freelancer1.address);
        expect(profile.jobsCompleted).to.equal(1);
        expect(profile.totalEarned).to.equal(ethers.parseEther("50"));
    });

    it("should allow the owner to record completions", async function () {
        await vepoReputation.connect(owner).recordCompletion(
            freelancer1.address,
            ethers.parseEther("100")
        );

        const profile = await vepoReputation.getProfile(freelancer1.address);
        expect(profile.jobsCompleted).to.equal(1);
    });

    it("should reject unauthorized callers from recording completions", async function () {
        await expect(
            vepoReputation.connect(unauthorized).recordCompletion(freelancer1.address, 100)
        ).to.be.revertedWith("VepoReputation: unauthorized caller");
    });

    it("should reject unauthorized callers from recording failures", async function () {
        await expect(
            vepoReputation.connect(unauthorized).recordFailure(freelancer1.address)
        ).to.be.revertedWith("VepoReputation: unauthorized caller");
    });

    // ─── Score Computation ───

    it("should return 0 for a freelancer with no history", async function () {
        expect(await vepoReputation.getReputationScore(freelancer1.address)).to.equal(0);
    });

    it("should return 100 for a perfect freelancer", async function () {
        await vepoReputation.connect(bountyContract).recordCompletion(freelancer1.address, ethers.parseEther("50"));
        await vepoReputation.connect(bountyContract).recordCompletion(freelancer1.address, ethers.parseEther("100"));
        await vepoReputation.connect(bountyContract).recordCompletion(freelancer1.address, ethers.parseEther("75"));

        expect(await vepoReputation.getReputationScore(freelancer1.address)).to.equal(100);
    });

    it("should return 0 for a freelancer who fails every job", async function () {
        await vepoReputation.connect(bountyContract).recordFailure(freelancer1.address);
        await vepoReputation.connect(bountyContract).recordFailure(freelancer1.address);

        expect(await vepoReputation.getReputationScore(freelancer1.address)).to.equal(0);
    });

    it("should compute correct score with mixed results", async function () {
        // 3 completed, 1 failed → score = (3 * 100) / 4 = 75
        await vepoReputation.connect(bountyContract).recordCompletion(freelancer1.address, ethers.parseEther("50"));
        await vepoReputation.connect(bountyContract).recordCompletion(freelancer1.address, ethers.parseEther("50"));
        await vepoReputation.connect(bountyContract).recordCompletion(freelancer1.address, ethers.parseEther("50"));
        await vepoReputation.connect(bountyContract).recordFailure(freelancer1.address);

        expect(await vepoReputation.getReputationScore(freelancer1.address)).to.equal(75);
    });

    it("should compute correct score at 50/50", async function () {
        // 1 completed, 1 failed → score = 50
        await vepoReputation.connect(bountyContract).recordCompletion(freelancer1.address, ethers.parseEther("50"));
        await vepoReputation.connect(bountyContract).recordFailure(freelancer1.address);

        expect(await vepoReputation.getReputationScore(freelancer1.address)).to.equal(50);
    });

    // ─── Registration & Directory ───

    it("should auto-register a freelancer on first interaction", async function () {
        expect(await vepoReputation.isRegistered(freelancer1.address)).to.equal(false);

        await vepoReputation.connect(bountyContract).recordCompletion(freelancer1.address, ethers.parseEther("50"));

        expect(await vepoReputation.isRegistered(freelancer1.address)).to.equal(true);
        expect(await vepoReputation.getFreelancerCount()).to.equal(1);
    });

    it("should not duplicate registration on subsequent interactions", async function () {
        await vepoReputation.connect(bountyContract).recordCompletion(freelancer1.address, ethers.parseEther("50"));
        await vepoReputation.connect(bountyContract).recordCompletion(freelancer1.address, ethers.parseEther("100"));
        await vepoReputation.connect(bountyContract).recordFailure(freelancer1.address);

        expect(await vepoReputation.getFreelancerCount()).to.equal(1);
    });

    it("should track multiple freelancers independently", async function () {
        await vepoReputation.connect(bountyContract).recordCompletion(freelancer1.address, ethers.parseEther("50"));
        await vepoReputation.connect(bountyContract).recordCompletion(freelancer2.address, ethers.parseEther("100"));
        await vepoReputation.connect(bountyContract).recordFailure(freelancer2.address);

        expect(await vepoReputation.getFreelancerCount()).to.equal(2);
        expect(await vepoReputation.getReputationScore(freelancer1.address)).to.equal(100);
        expect(await vepoReputation.getReputationScore(freelancer2.address)).to.equal(50);
    });

    // ─── Total Earned Tracking ───

    it("should accurately track total earned across multiple jobs", async function () {
        await vepoReputation.connect(bountyContract).recordCompletion(freelancer1.address, ethers.parseEther("50"));
        await vepoReputation.connect(bountyContract).recordCompletion(freelancer1.address, ethers.parseEther("100"));
        await vepoReputation.connect(bountyContract).recordCompletion(freelancer1.address, ethers.parseEther("25"));

        const profile = await vepoReputation.getProfile(freelancer1.address);
        expect(profile.totalEarned).to.equal(ethers.parseEther("175"));
    });

    // ─── Timestamp Tracking ───

    it("should record firstActivityAt and lastActivityAt", async function () {
        await vepoReputation.connect(bountyContract).recordCompletion(freelancer1.address, ethers.parseEther("50"));
        const profile1 = await vepoReputation.getProfile(freelancer1.address);
        const firstActivity = profile1.firstActivityAt;

        expect(firstActivity).to.be.gt(0);
        expect(profile1.lastActivityAt).to.be.gt(0);

        // Second activity — firstActivityAt should NOT change
        await vepoReputation.connect(bountyContract).recordCompletion(freelancer1.address, ethers.parseEther("50"));
        const profile2 = await vepoReputation.getProfile(freelancer1.address);
        expect(profile2.firstActivityAt).to.equal(firstActivity);
        expect(profile2.lastActivityAt).to.be.gte(profile1.lastActivityAt);
    });

    // ─── Admin Functions ───

    it("should allow owner to update the bounty contract address", async function () {
        await vepoReputation.setBountyContract(unauthorized.address);
        expect(await vepoReputation.bountyContract()).to.equal(unauthorized.address);
    });

    it("should reject setting bounty contract to zero address", async function () {
        await expect(
            vepoReputation.setBountyContract(ethers.ZeroAddress)
        ).to.be.revertedWith("Invalid address");
    });

    it("should reject non-owner from updating bounty contract", async function () {
        await expect(
            vepoReputation.connect(unauthorized).setBountyContract(unauthorized.address)
        ).to.be.revertedWithCustomError(vepoReputation, "OwnableUnauthorizedAccount");
    });
});
