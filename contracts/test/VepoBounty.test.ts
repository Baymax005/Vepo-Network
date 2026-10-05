import { expect } from "chai";
import { ethers, network } from "hardhat";

describe("VepoBounty V3.1", function () {
    let vepoToken: any;
    let vepoBounty: any;
    let owner: any;
    let client: any;
    let freelancer: any;

    const listingFee = ethers.parseEther("5");
    const boostFee = ethers.parseEther("100");
    const applicationFee = ethers.parseEther("5");
    const deleteFee = ethers.parseEther("5");
    const bountyAmount = ethers.parseEther("50");

    beforeEach(async function () {
        [owner, client, freelancer] = await ethers.getSigners();

        const VepoToken = await ethers.getContractFactory("VepoToken");
        vepoToken = await VepoToken.deploy();

        const VepoBounty = await ethers.getContractFactory("VepoBounty");
        vepoBounty = await VepoBounty.deploy(await vepoToken.getAddress());

        // Fund client and freelancer with VEPO for fees
        await vepoToken.transfer(client.address, ethers.parseEther("1000"));
        await vepoToken.transfer(freelancer.address, ethers.parseEther("1000"));

        // Approve Bounty contract to spend tokens
        await vepoToken.connect(client).approve(await vepoBounty.getAddress(), ethers.parseEther("1000"));
        await vepoToken.connect(freelancer).approve(await vepoBounty.getAddress(), ethers.parseEther("1000"));
    });

    it("should correctly burn $VEPO on Listing, Application, Boost, and Delete fees", async function () {
        const initialClientBalance = await vepoToken.balanceOf(client.address);
        const initialFreelancerBalance = await vepoToken.balanceOf(freelancer.address);
        const initialTotalSupply = await vepoToken.totalSupply();

        // 1. Listing Fee Burn
        await vepoBounty.connect(client).postBounty({ value: bountyAmount });
        expect(await vepoToken.balanceOf(client.address)).to.equal(initialClientBalance - listingFee);
        expect(await vepoToken.totalSupply()).to.equal(initialTotalSupply - listingFee);

        // 2. Application Fee Burn
        await vepoBounty.connect(freelancer).applyForGig(1, "https://portfolio.com");
        expect(await vepoToken.balanceOf(freelancer.address)).to.equal(initialFreelancerBalance - applicationFee);
        expect(await vepoToken.totalSupply()).to.equal(initialTotalSupply - listingFee - applicationFee);

        // 3. Boost Fee Burn
        await vepoBounty.connect(client).boostBounty(1);
        expect(await vepoToken.balanceOf(client.address)).to.equal(initialClientBalance - listingFee - boostFee);
        expect(await vepoToken.totalSupply()).to.equal(initialTotalSupply - listingFee - applicationFee - boostFee);

        // 4. Delete Fee Burn
        await vepoBounty.connect(client).cancelBounty(1);
        expect(await vepoToken.balanceOf(client.address)).to.equal(initialClientBalance - listingFee - boostFee - deleteFee);
        expect(await vepoToken.totalSupply()).to.equal(initialTotalSupply - listingFee - applicationFee - boostFee - deleteFee);
    });

    it("should prevent the client from unilaterally draining funds in a dispute", async function () {
        await vepoBounty.connect(client).postBounty({ value: bountyAmount });
        await vepoBounty.connect(client).selectFreelancer(1, freelancer.address);
        await vepoBounty.connect(freelancer).submitWork(1, "https://github.com/work");

        // Client rejects work, triggering a Dispute
        await vepoBounty.connect(client).rejectWork(1);

        const bounty = await vepoBounty.bounties(1);
        expect(bounty.state).to.equal(4); // 4 = Disputed

        // Client cannot cancel to get refund because state is not Open
        await expect(vepoBounty.connect(client).cancelBounty(1)).to.be.revertedWith("Cannot cancel, work submitted or locked");

        // Only Admin can resolve
        await expect(vepoBounty.connect(client).resolveDispute(1, true)).to.be.revertedWithCustomError(vepoBounty, "OwnableUnauthorizedAccount");

        const initialFreelancerEth = await ethers.provider.getBalance(freelancer.address);
        
        // Admin resolves in favor of freelancer
        await vepoBounty.connect(owner).resolveDispute(1, true);

        const finalFreelancerEth = await ethers.provider.getBalance(freelancer.address);
        expect(finalFreelancerEth - initialFreelancerEth).to.equal(bountyAmount);
    });

    it("should allow the freelancer to claim abandoned funds after 7 days if client ghosts", async function () {
        await vepoBounty.connect(client).postBounty({ value: bountyAmount });
        await vepoBounty.connect(client).selectFreelancer(1, freelancer.address);
        await vepoBounty.connect(freelancer).submitWork(1, "https://github.com/work");

        // Attempting to claim immediately should fail
        await expect(vepoBounty.connect(freelancer).claimAbandonedFunds(1)).to.be.revertedWith("7-day time-lock has not expired");

        // Time travel 7 days and 1 second
        await network.provider.send("evm_increaseTime", [7 * 24 * 60 * 60 + 1]);
        await network.provider.send("evm_mine");

        const initialFreelancerEth: bigint = await ethers.provider.getBalance(freelancer.address);

        // Claim should now succeed
        const tx = await vepoBounty.connect(freelancer).claimAbandonedFunds(1);
        const receipt = await tx.wait();
        
        const gasUsed: bigint = (receipt && receipt.gasPrice) ? BigInt(receipt.gasUsed) * BigInt(receipt.gasPrice) : 0n;

        const finalFreelancerEth: bigint = await ethers.provider.getBalance(freelancer.address);
        expect(finalFreelancerEth - initialFreelancerEth + gasUsed).to.equal(bountyAmount);

        const bounty = await vepoBounty.bounties(1);
        expect(bounty.state).to.equal(2); // 2 = Completed
    });

    describe("80/20 Dual-Action Fee Engine & Staker Distribution", function () {
        let mockStaking: any;

        beforeEach(async function () {
            [, , , mockStaking] = await ethers.getSigners();
            await vepoBounty.setStakingContract(mockStaking.address);
        });

        it("should split platform fees 80% burn and 20% to stakers when supply is above floor", async function () {
            const initialClientBalance = await vepoToken.balanceOf(client.address);
            const initialStakingBalance = await vepoToken.balanceOf(mockStaking.address);
            const initialSupply = await vepoToken.totalSupply();

            // Post bounty: 5 VEPO listing fee
            // 80% of 5 = 4 VEPO burned
            // 20% of 5 = 1 VEPO to mockStaking
            const tx = await vepoBounty.connect(client).postBounty({ value: bountyAmount });

            await expect(tx)
                .to.emit(vepoBounty, "FeeSplit")
                .withArgs(client.address, ethers.parseEther("4"), ethers.parseEther("1"));

            expect(await vepoToken.balanceOf(client.address)).to.equal(initialClientBalance - listingFee);
            expect(await vepoToken.balanceOf(mockStaking.address)).to.equal(initialStakingBalance + ethers.parseEther("1"));
            expect(await vepoToken.totalSupply()).to.equal(initialSupply - ethers.parseEther("4"));
        });

        it("should allow owner to update stakerFeeBps within limit (<= 5000)", async function () {
            await expect(vepoBounty.setStakerFeeBps(3000))
                .to.emit(vepoBounty, "StakerFeeBpsUpdated")
                .withArgs(3000);
            expect(await vepoBounty.stakerFeeBps()).to.equal(3000);

            // Rejects > 5000 (50%)
            await expect(vepoBounty.setStakerFeeBps(5001)).to.be.revertedWith("Staker fee cannot exceed 50%");
        });

        it("should reject non-owner from updating stakerFeeBps", async function () {
            await expect(
                vepoBounty.connect(client).setStakerFeeBps(3000)
            ).to.be.revertedWithCustomError(vepoBounty, "OwnableUnauthorizedAccount");
        });

        it("should redirect 100% of fees to stakers when supply is at or below floor", async function () {
            // Set supplyFloor higher than current totalSupply
            const currentSupply = await vepoToken.totalSupply();
            await vepoBounty.setSupplyFloor(currentSupply + ethers.parseEther("1000"));

            const initialClientBalance = await vepoToken.balanceOf(client.address);
            const initialStakingBalance = await vepoToken.balanceOf(mockStaking.address);

            // Post bounty: 5 VEPO listing fee
            // When supply <= floor, 100% of 5 VEPO redirects to stakers, zero burned
            const tx = await vepoBounty.connect(client).postBounty({ value: bountyAmount });

            await expect(tx)
                .to.emit(vepoBounty, "FeeRedirectedToStakers")
                .withArgs(client.address, listingFee);

            expect(await vepoToken.balanceOf(client.address)).to.equal(initialClientBalance - listingFee);
            expect(await vepoToken.balanceOf(mockStaking.address)).to.equal(initialStakingBalance + listingFee);
            // Supply should be unchanged since nothing was burned
            expect(await vepoToken.totalSupply()).to.equal(currentSupply);
        });

        it("should allow owner to update supply floor", async function () {
            const newFloor = ethers.parseEther("15000000");
            await expect(vepoBounty.setSupplyFloor(newFloor))
                .to.emit(vepoBounty, "SupplyFloorUpdated")
                .withArgs(newFloor);
            expect(await vepoBounty.supplyFloor()).to.equal(newFloor);
        });
    });
});
