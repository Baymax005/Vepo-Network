import { expect } from "chai";
import { ethers, network } from "hardhat";

describe("VepoGovernance (DAO Voting)", function () {
    let vepoToken: any;
    let vepoGovernance: any;
    let owner: any;
    let proposer: any;
    let voter1: any;
    let voter2: any;
    let poorUser: any;

    const PROPOSER_BALANCE = ethers.parseEther("50000");  // Above 10k threshold
    const VOTER_BALANCE = ethers.parseEther("60000");
    const SMALL_BALANCE = ethers.parseEther("100");

    beforeEach(async function () {
        [owner, proposer, voter1, voter2, poorUser] = await ethers.getSigners();

        const VepoToken = await ethers.getContractFactory("VepoToken");
        vepoToken = await VepoToken.deploy();

        const VepoGovernance = await ethers.getContractFactory("VepoGovernance");
        vepoGovernance = await VepoGovernance.deploy(await vepoToken.getAddress());

        // Fund accounts
        await vepoToken.transfer(proposer.address, PROPOSER_BALANCE);
        await vepoToken.transfer(voter1.address, VOTER_BALANCE);
        await vepoToken.transfer(voter2.address, VOTER_BALANCE);
        await vepoToken.transfer(poorUser.address, SMALL_BALANCE);
    });

    // ─── Proposal Creation ───

    it("should allow creating a proposal with sufficient $VEPO", async function () {
        await vepoGovernance.connect(proposer).createProposal(
            "Reduce Listing Fee",
            "Reduce the listing fee from 5 to 3 VEPO to attract more clients"
        );

        expect(await vepoGovernance.proposalCount()).to.equal(1);

        const proposal = await vepoGovernance.getProposal(1);
        expect(proposal.title).to.equal("Reduce Listing Fee");
        expect(proposal.proposer).to.equal(proposer.address);
        expect(proposal.state).to.equal(0); // Active
    });

    it("should reject proposal creation below threshold", async function () {
        await expect(
            vepoGovernance.connect(poorUser).createProposal("Test", "Test description")
        ).to.be.revertedWith("Below proposal threshold");
    });

    it("should auto-increment proposal IDs", async function () {
        await vepoGovernance.connect(proposer).createProposal("Proposal 1", "Description 1");
        await vepoGovernance.connect(proposer).createProposal("Proposal 2", "Description 2");

        expect(await vepoGovernance.proposalCount()).to.equal(2);

        const p1 = await vepoGovernance.getProposal(1);
        const p2 = await vepoGovernance.getProposal(2);
        expect(p1.title).to.equal("Proposal 1");
        expect(p2.title).to.equal("Proposal 2");
    });

    // ─── Voting ───

    it("should allow a token holder to vote For", async function () {
        await vepoGovernance.connect(proposer).createProposal("Test", "Description");

        await vepoGovernance.connect(voter1).castVote(1, true);

        const proposal = await vepoGovernance.getProposal(1);
        expect(proposal.votesFor).to.equal(VOTER_BALANCE);
        expect(proposal.votesAgainst).to.equal(0);
    });

    it("should allow a token holder to vote Against", async function () {
        await vepoGovernance.connect(proposer).createProposal("Test", "Description");

        await vepoGovernance.connect(voter1).castVote(1, false);

        const proposal = await vepoGovernance.getProposal(1);
        expect(proposal.votesFor).to.equal(0);
        expect(proposal.votesAgainst).to.equal(VOTER_BALANCE);
    });

    it("should prevent double-voting", async function () {
        await vepoGovernance.connect(proposer).createProposal("Test", "Description");
        await vepoGovernance.connect(voter1).castVote(1, true);

        await expect(
            vepoGovernance.connect(voter1).castVote(1, true)
        ).to.be.revertedWith("Already voted");
    });

    it("should reject voting with zero balance", async function () {
        await vepoGovernance.connect(proposer).createProposal("Test", "Description");

        // Transfer all tokens away from poorUser
        await vepoToken.connect(poorUser).transfer(owner.address, SMALL_BALANCE);

        await expect(
            vepoGovernance.connect(poorUser).castVote(1, true)
        ).to.be.revertedWith("No voting power");
    });

    it("should reject voting after the voting period ends", async function () {
        await vepoGovernance.connect(proposer).createProposal("Test", "Description");

        // Fast-forward past the voting period (3 days + 1 second)
        await network.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
        await network.provider.send("evm_mine");

        await expect(
            vepoGovernance.connect(voter1).castVote(1, true)
        ).to.be.revertedWith("Voting period ended");
    });

    // ─── Finalization ───

    it("should pass a proposal that meets quorum and has majority For votes", async function () {
        await vepoGovernance.connect(proposer).createProposal("Test", "Description");

        // voter1 (60k) + voter2 (60k) = 120k > quorum (100k)
        await vepoGovernance.connect(voter1).castVote(1, true);
        await vepoGovernance.connect(voter2).castVote(1, true);

        // Fast-forward past voting period
        await network.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
        await network.provider.send("evm_mine");

        await vepoGovernance.finalizeProposal(1);

        const proposal = await vepoGovernance.getProposal(1);
        expect(proposal.state).to.equal(1); // Passed
    });

    it("should reject a proposal that doesn't meet quorum", async function () {
        await vepoGovernance.connect(proposer).createProposal("Test", "Description");

        // Only voter1 (60k) votes — below quorum (100k)
        await vepoGovernance.connect(voter1).castVote(1, true);

        await network.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
        await network.provider.send("evm_mine");

        await vepoGovernance.finalizeProposal(1);

        const proposal = await vepoGovernance.getProposal(1);
        expect(proposal.state).to.equal(2); // Rejected
    });

    it("should reject a proposal where Against votes win", async function () {
        await vepoGovernance.connect(proposer).createProposal("Test", "Description");

        await vepoGovernance.connect(voter1).castVote(1, false);
        await vepoGovernance.connect(voter2).castVote(1, false);

        await network.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
        await network.provider.send("evm_mine");

        await vepoGovernance.finalizeProposal(1);

        const proposal = await vepoGovernance.getProposal(1);
        expect(proposal.state).to.equal(2); // Rejected
    });

    it("should reject finalization while voting is still open", async function () {
        await vepoGovernance.connect(proposer).createProposal("Test", "Description");

        await expect(
            vepoGovernance.finalizeProposal(1)
        ).to.be.revertedWith("Voting still open");
    });

    // ─── Execution ───

    it("should allow owner to execute a passed proposal", async function () {
        await vepoGovernance.connect(proposer).createProposal("Test", "Description");
        await vepoGovernance.connect(voter1).castVote(1, true);
        await vepoGovernance.connect(voter2).castVote(1, true);

        await network.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
        await network.provider.send("evm_mine");

        await vepoGovernance.finalizeProposal(1);
        await vepoGovernance.executeProposal(1);

        const proposal = await vepoGovernance.getProposal(1);
        expect(proposal.state).to.equal(3); // Executed
    });

    it("should reject execution of a non-passed proposal", async function () {
        await vepoGovernance.connect(proposer).createProposal("Test", "Description");

        await expect(
            vepoGovernance.executeProposal(1)
        ).to.be.revertedWith("Proposal not passed");
    });

    it("should reject execution by non-owner", async function () {
        await vepoGovernance.connect(proposer).createProposal("Test", "Description");
        await vepoGovernance.connect(voter1).castVote(1, true);
        await vepoGovernance.connect(voter2).castVote(1, true);

        await network.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
        await network.provider.send("evm_mine");

        await vepoGovernance.finalizeProposal(1);

        await expect(
            vepoGovernance.connect(proposer).executeProposal(1)
        ).to.be.revertedWithCustomError(vepoGovernance, "OwnableUnauthorizedAccount");
    });

    // ─── Cancellation ───

    it("should allow proposer to cancel their own proposal", async function () {
        await vepoGovernance.connect(proposer).createProposal("Test", "Description");
        await vepoGovernance.connect(proposer).cancelProposal(1);

        const proposal = await vepoGovernance.getProposal(1);
        expect(proposal.state).to.equal(4); // Cancelled
    });

    it("should allow owner to cancel any proposal", async function () {
        await vepoGovernance.connect(proposer).createProposal("Test", "Description");
        await vepoGovernance.connect(owner).cancelProposal(1);

        const proposal = await vepoGovernance.getProposal(1);
        expect(proposal.state).to.equal(4); // Cancelled
    });

    it("should reject cancellation by unauthorized user", async function () {
        await vepoGovernance.connect(proposer).createProposal("Test", "Description");

        await expect(
            vepoGovernance.connect(voter1).cancelProposal(1)
        ).to.be.revertedWith("Only proposer or owner");
    });

    // ─── Governance Parameter Updates ───

    it("should allow owner to update governance parameters", async function () {
        await vepoGovernance.updateGovernanceParams(
            ethers.parseEther("5000"),   // threshold
            ethers.parseEther("50000"),  // quorum
            7200                         // 2 hours
        );

        expect(await vepoGovernance.proposalThreshold()).to.equal(ethers.parseEther("5000"));
        expect(await vepoGovernance.quorum()).to.equal(ethers.parseEther("50000"));
        expect(await vepoGovernance.votingPeriod()).to.equal(7200);
    });

    it("should reject voting period less than 1 hour", async function () {
        await expect(
            vepoGovernance.updateGovernanceParams(
                ethers.parseEther("10000"),
                ethers.parseEther("100000"),
                60  // 1 minute — too short
            )
        ).to.be.revertedWith("Voting period too short");
    });

    it("should reject non-owner from updating governance params", async function () {
        await expect(
            vepoGovernance.connect(voter1).updateGovernanceParams(0, 0, 3600)
        ).to.be.revertedWithCustomError(vepoGovernance, "OwnableUnauthorizedAccount");
    });
});
