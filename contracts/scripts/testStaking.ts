import { ethers } from "hardhat";

async function main() {
  const [admin, staker] = await ethers.getSigners();
  console.log("--- Testing VepoStaking DEX Buyback & Burn Logic ---");

  // Load contract addresses from the previously deployed environment
  // We can fetch the deployed addresses from the frontend ABI file or hardcode if known,
  // but it's cleaner to just get them by deploying a fresh instance or relying on the local state if we know the addresses.
  // Since we already deployed, let's grab the addresses from abi.ts
  const fs = require("fs");
  const path = require("path");
  const abiPath = path.join(__dirname, "../../frontend/src/abi.ts");
  const abiFile = fs.readFileSync(abiPath, 'utf8');
  
  const extractAddress = (regex: RegExp) => {
      const match = abiFile.match(regex);
      return match ? match[1] : null;
  }

  const tokenAddress = extractAddress(/export const TOKEN_ADDRESS = "(.*)";/);
  const stakingAddress = extractAddress(/export const STAKING_ADDRESS = "(.*)";/);
  // Hardcoded from our deploy script for the mock USDC (it deploys right after Bounty)
  const usdcAddress = "0x68B1D87F95878fE05B998F19b66F4baba5De1aed"; 

  if (!tokenAddress || !stakingAddress) {
      console.log("Could not find contract addresses. Make sure deploy.ts was run!");
      return;
  }

  const VepoToken = await ethers.getContractAt("VepoToken", tokenAddress);
  const VepoStaking = await ethers.getContractAt("VepoStaking", stakingAddress);
  const MockUSDC = await ethers.getContractAt("MockUSDC", usdcAddress);

  // 1. Initial State
  let initialSupply = await VepoToken.totalSupply();
  console.log(`\n[State 1] Initial $VEPO Total Supply: ${ethers.formatUnits(initialSupply, 18)}`);

  // 2. Simulate Sequencer Profits
  console.log("\n[Simulating Sequencer] Minting 5,000 Mock USDC to VepoStaking contract...");
  await MockUSDC.mint(stakingAddress, ethers.parseUnits("5000", 18));
  
  const usdcBalance = await MockUSDC.balanceOf(stakingAddress);
  console.log(`VepoStaking USDC Balance: ${ethers.formatUnits(usdcBalance, 18)} USDC`);

  // 3. Execute the Buyback & Burn Engine
  console.log("\n[Executing processSequencerProfits] Calling DEX router & burning...");
  const tx = await VepoStaking.processSequencerProfits();
  const receipt = await tx.wait();

  // Find the custom event in the logs
  const event = receipt?.logs.find(
      (log) => log.fragment && log.fragment.name === 'SequencerProfitsProcessed'
  );
  
  if (event) {
      const usdcSpent = ethers.formatUnits(event.args[0], 18);
      const vepoBought = ethers.formatUnits(event.args[1], 18);
      const vepoBurned = ethers.formatUnits(event.args[2], 18);
      const vepoStaked = ethers.formatUnits(event.args[3], 18);
      console.log(`--> Spent ${usdcSpent} USDC to buy ${vepoBought} $VEPO from DEX.`);
      console.log(`--> 30% Burn: ${vepoBurned} $VEPO permanently destroyed!`);
      console.log(`--> 70% Yield: ${vepoStaked} $VEPO sent to Staking pool!`);
  }

  // 4. Final State
  let finalSupply = await VepoToken.totalSupply();
  console.log(`\n[State 2] Final $VEPO Total Supply: ${ethers.formatUnits(finalSupply, 18)}`);
  
  const difference = initialSupply - finalSupply;
  console.log(`Total supply successfully reduced by: ${ethers.formatUnits(difference, 18)} $VEPO!`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
