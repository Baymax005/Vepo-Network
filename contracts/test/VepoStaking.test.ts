import { expect } from "chai";
import { ethers } from "hardhat";

describe("VepoStaking (Treasury Engine)", function () {
    let vepoToken: any;
    let mockUsdc: any;
    let mockRouter: any;
    let vepoStaking: any;
    let owner: any;
    let staker1: any;
    let staker2: any;

    const INITIAL_VEPO = ethers.parseEther("10000");
    const STAKE_AMOUNT = ethers.parseEther("1000");

    beforeEach(async function () {
        [owner, staker1, staker2] = await ethers.getSigners();

        // Deploy VepoToken
        const VepoToken = await ethers.getContractFactory("VepoToken");
        vepoToken = await VepoToken.deploy();

        // Deploy MockUSDC
        const MockUSDC = await ethers.getContractFactory("MockUSDC");
        mockUsdc = await MockUSDC.deploy();

        // Deploy MockRouter
        const MockRouter = await ethers.getContractFactory("MockUniswapV2Router");
        mockRouter = await MockRouter.deploy(await mockUsdc.getAddress(), await vepoToken.getAddress());

        // Deploy VepoStaking
        const VepoStaking = await ethers.getContractFactory("VepoStaking");
        vepoStaking = await VepoStaking.deploy(
            await vepoToken.getAddress(),
            await mockUsdc.getAddress(),
            await mockRouter.getAddress()
        );

        // Fund stakers with VEPO
        await vepoToken.transfer(staker1.address, INITIAL_VEPO);
        await vepoToken.transfer(staker2.address, INITIAL_VEPO);

        // Fund mock router with VEPO for swap simulation
        await vepoToken.transfer(await mockRouter.getAddress(), ethers.parseEther("5000000"));

        // Approve staking contract
        await vepoToken.connect(staker1).approve(await vepoStaking.getAddress(), ethers.MaxUint256);
        await vepoToken.connect(staker2).approve(await vepoStaking.getAddress(), ethers.MaxUint256);
    });

    // ─── Staking Basics ───

    it("should allow a user to stake $VEPO", async function () {
        await vepoStaking.connect(staker1).stake(STAKE_AMOUNT);

        expect(await vepoStaking.stakedBalance(staker1.address)).to.equal(STAKE_AMOUNT);
        expect(await vepoStaking.totalStaked()).to.equal(STAKE_AMOUNT);
    });

    it("should reject staking 0 tokens", async function () {
        await expect(vepoStaking.connect(staker1).stake(0)).to.be.revertedWith("Cannot stake 0");
    });

    it("should allow a user to withdraw staked $VEPO", async function () {
        await vepoStaking.connect(staker1).stake(STAKE_AMOUNT);

        const balanceBefore = await vepoToken.balanceOf(staker1.address);
        await vepoStaking.connect(staker1).withdraw(STAKE_AMOUNT);

        expect(await vepoStaking.stakedBalance(staker1.address)).to.equal(0);
        expect(await vepoStaking.totalStaked()).to.equal(0);
        expect(await vepoToken.balanceOf(staker1.address)).to.equal(balanceBefore + STAKE_AMOUNT);
    });

    it("should reject withdrawing more than staked", async function () {
        await vepoStaking.connect(staker1).stake(STAKE_AMOUNT);
        await expect(
            vepoStaking.connect(staker1).withdraw(STAKE_AMOUNT + 1n)
        ).to.be.revertedWith("Insufficient staked balance");
    });

    it("should reject withdrawing 0 tokens", async function () {
        await expect(vepoStaking.connect(staker1).withdraw(0)).to.be.revertedWith("Cannot withdraw 0");
    });

    // ─── Multiple Stakers ───

    it("should track multiple stakers independently", async function () {
        await vepoStaking.connect(staker1).stake(STAKE_AMOUNT);
        await vepoStaking.connect(staker2).stake(STAKE_AMOUNT * 2n);

        expect(await vepoStaking.stakedBalance(staker1.address)).to.equal(STAKE_AMOUNT);
        expect(await vepoStaking.stakedBalance(staker2.address)).to.equal(STAKE_AMOUNT * 2n);
        expect(await vepoStaking.totalStaked()).to.equal(STAKE_AMOUNT * 3n);
    });

    // ─── Sequencer Profit Processing ───

    it("should process sequencer profits and distribute rewards", async function () {
        // Staker1 stakes
        await vepoStaking.connect(staker1).stake(STAKE_AMOUNT);

        // Send USDC to staking contract (simulates sequencer profit accumulation)
        const usdcAmount = ethers.parseEther("100");
        await mockUsdc.transfer(await vepoStaking.getAddress(), usdcAmount);

        // Process profits
        await vepoStaking.processSequencerProfits();

        // accVepoPerShare should have increased
        expect(await vepoStaking.accVepoPerShare()).to.be.gt(0);
    });

    it("should reject processing with no USDC balance", async function () {
        await expect(vepoStaking.processSequencerProfits()).to.be.revertedWith("No USDC to process");
    });

    it("should enforce cooldown between processing calls", async function () {
        await vepoStaking.connect(staker1).stake(STAKE_AMOUNT);

        const usdcAmount = ethers.parseEther("100");
        await mockUsdc.transfer(await vepoStaking.getAddress(), usdcAmount);
        await vepoStaking.processSequencerProfits();

        // Send more USDC and try to process again immediately
        await mockUsdc.transfer(await vepoStaking.getAddress(), usdcAmount);
        await expect(vepoStaking.processSequencerProfits()).to.be.revertedWith("Cooldown active");
    });

    it("should only allow owner to process profits", async function () {
        const usdcAmount = ethers.parseEther("100");
        await mockUsdc.transfer(await vepoStaking.getAddress(), usdcAmount);

        await expect(
            vepoStaking.connect(staker1).processSequencerProfits()
        ).to.be.revertedWithCustomError(vepoStaking, "OwnableUnauthorizedAccount");
    });

    // ─── Reward Claiming ───

    it("should allow staker to claim yield after profit processing", async function () {
        await vepoStaking.connect(staker1).stake(STAKE_AMOUNT);

        // Send and process USDC profits
        await mockUsdc.transfer(await vepoStaking.getAddress(), ethers.parseEther("100"));
        await vepoStaking.processSequencerProfits();

        const balanceBefore = await vepoToken.balanceOf(staker1.address);
        await vepoStaking.connect(staker1).claimYield();
        const balanceAfter = await vepoToken.balanceOf(staker1.address);

        expect(balanceAfter).to.be.gt(balanceBefore);
    });

    it("should distribute rewards proportionally to stake", async function () {
        // Staker1 stakes 1000, staker2 stakes 2000
        await vepoStaking.connect(staker1).stake(STAKE_AMOUNT);
        await vepoStaking.connect(staker2).stake(STAKE_AMOUNT * 2n);

        // Process profits
        await mockUsdc.transfer(await vepoStaking.getAddress(), ethers.parseEther("100"));
        await vepoStaking.processSequencerProfits();

        // Claim for both
        const balance1Before: bigint = await vepoToken.balanceOf(staker1.address);
        await vepoStaking.connect(staker1).claimYield();
        const reward1: bigint = (await vepoToken.balanceOf(staker1.address)) - balance1Before;

        const balance2Before: bigint = await vepoToken.balanceOf(staker2.address);
        await vepoStaking.connect(staker2).claimYield();
        const reward2: bigint = (await vepoToken.balanceOf(staker2.address)) - balance2Before;

        // Staker2 staked 2x more, so should get ~2x reward
        // Allow 1 wei tolerance for rounding
        expect(reward2).to.be.closeTo(reward1 * 2n, ethers.parseEther("0.001"));
    });

    // ─── Governance Setters ───

    it("should allow owner to update burn BPS", async function () {
        await vepoStaking.updateBurnBps(5000); // 50%
        expect(await vepoStaking.burnBps()).to.equal(5000);
    });

    it("should reject burn BPS over 10000", async function () {
        await expect(vepoStaking.updateBurnBps(10001)).to.be.revertedWith("Invalid BPS");
    });

    it("should allow owner to update supply floor", async function () {
        const newFloor = ethers.parseEther("5000000");
        await vepoStaking.updateSupplyFloor(newFloor);
        expect(await vepoStaking.supplyFloor()).to.equal(newFloor);
    });

    it("should allow owner to update process interval", async function () {
        await vepoStaking.updateProcessInterval(7200); // 2 hours
        expect(await vepoStaking.processInterval()).to.equal(7200);
    });

    // ─── Pausable ───

    it("should prevent staking when paused", async function () {
        await vepoStaking.pause();
        await expect(
            vepoStaking.connect(staker1).stake(STAKE_AMOUNT)
        ).to.be.revertedWithCustomError(vepoStaking, "EnforcedPause");
    });

    it("should allow staking after unpause", async function () {
        await vepoStaking.pause();
        await vepoStaking.unpause();
        await vepoStaking.connect(staker1).stake(STAKE_AMOUNT);
        expect(await vepoStaking.stakedBalance(staker1.address)).to.equal(STAKE_AMOUNT);
    });
});
