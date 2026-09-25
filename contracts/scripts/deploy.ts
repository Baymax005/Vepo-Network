import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("═══════════════════════════════════════════════════");
  console.log("  Vepo Network — Full Protocol Deployment (V4.0)  ");
  console.log("═══════════════════════════════════════════════════");
  console.log("Deployer:", deployer.address);
  console.log("");

  // ─── 1. Deploy VepoToken ────────────────────────
  console.log("[1/7] Deploying VepoToken (100M Genesis Supply)...");
  const VepoToken = await ethers.getContractFactory("VepoToken");
  const vepoToken = await VepoToken.deploy();
  await vepoToken.waitForDeployment();
  const tokenAddress = await vepoToken.getAddress();
  console.log("  ✅ VepoToken:", tokenAddress);

  // ─── 2. Deploy VepoFaucet ──────────────────────
  console.log("[2/7] Deploying VepoFaucet (Rate-Limited Reserve)...");
  const VepoFaucet = await ethers.getContractFactory("VepoFaucet");
  const vepoFaucet = await VepoFaucet.deploy(tokenAddress);
  await vepoFaucet.waitForDeployment();
  const faucetAddress = await vepoFaucet.getAddress();
  console.log("  ✅ VepoFaucet:", faucetAddress);

  // Fund Faucet with 1,000,000 VEPO from Genesis supply
  console.log("  💰 Funding VepoFaucet with 1,000,000 $VEPO...");
  const fundTx = await vepoToken.transfer(faucetAddress, ethers.parseUnits("1000000", 18));
  await fundTx.wait();
  console.log("  ✅ VepoFaucet funded.");

  // ─── 3. Deploy VepoBounty ──────────────────────
  console.log("[3/7] Deploying VepoBounty (Escrow & Arbitration Engine)...");
  const VepoBounty = await ethers.getContractFactory("VepoBounty");
  const vepoBounty = await VepoBounty.deploy(tokenAddress);
  await vepoBounty.waitForDeployment();
  const bountyAddress = await vepoBounty.getAddress();
  console.log("  ✅ VepoBounty:", bountyAddress);

  // ─── 4. Deploy Mocks (Local Testing Only) ──────
  console.log("[4/7] Deploying Mock Environment...");
  const MockUSDC = await ethers.getContractFactory("MockUSDC");
  const mockUSDC = await MockUSDC.deploy();
  await mockUSDC.waitForDeployment();
  const usdcAddress = await mockUSDC.getAddress();
  console.log("  ✅ MockUSDC:", usdcAddress);

  const MockRouter = await ethers.getContractFactory("MockUniswapV2Router");
  const mockRouter = await MockRouter.deploy(usdcAddress, tokenAddress);
  await mockRouter.waitForDeployment();
  const routerAddress = await mockRouter.getAddress();
  console.log("  ✅ MockUniswapV2Router:", routerAddress);

  // Fund the mock router with VEPO so it can perform swaps
  console.log("  💰 Funding Mock Router with 5,000,000 $VEPO for swaps...");
  const fundRouterTx = await vepoToken.transfer(routerAddress, ethers.parseUnits("5000000", 18));
  await fundRouterTx.wait();
  console.log("  ✅ Mock Router funded.");

  // ─── 5. Deploy VepoStaking (Treasury Engine) ───
  console.log("[5/7] Deploying VepoStaking (Treasury & Buyback Engine)...");
  const VepoStaking = await ethers.getContractFactory("VepoStaking");
  const vepoStaking = await VepoStaking.deploy(tokenAddress, usdcAddress, routerAddress);
  await vepoStaking.waitForDeployment();
  const stakingAddress = await vepoStaking.getAddress();
  console.log("  ✅ VepoStaking:", stakingAddress);

  // Wire VepoStaking into VepoBounty (for supply floor fee redirection)
  console.log("  🔗 Linking VepoStaking to VepoBounty (supply floor fee redirection)...");
  const linkTx = await vepoBounty.setStakingContract(stakingAddress);
  await linkTx.wait();
  console.log("  ✅ VepoBounty now redirects fees to VepoStaking at supply floor.");

  // ─── 6. Deploy VepoReputation ──────────────────
  console.log("[6/7] Deploying VepoReputation (On-Chain Scoring)...");
  const VepoReputation = await ethers.getContractFactory("VepoReputation");
  const vepoReputation = await VepoReputation.deploy(bountyAddress);
  await vepoReputation.waitForDeployment();
  const reputationAddress = await vepoReputation.getAddress();
  console.log("  ✅ VepoReputation:", reputationAddress);

  // ─── 7. Deploy VepoGovernance ──────────────────
  console.log("[7/7] Deploying VepoGovernance (DAO Voting)...");
  const VepoGovernance = await ethers.getContractFactory("VepoGovernance");
  const vepoGovernance = await VepoGovernance.deploy(tokenAddress);
  await vepoGovernance.waitForDeployment();
  const governanceAddress = await vepoGovernance.getAddress();
  console.log("  ✅ VepoGovernance:", governanceAddress);

  // ─── Update Frontend ABIs ──────────────────────
  console.log("\n[ABI] Writing deployed addresses to frontend/src/abi.ts...");
  const fs = require("fs");
  const path = require("path");
  const abiPath = path.join(__dirname, "../../frontend/src/abi.ts");
  let abiFile = fs.readFileSync(abiPath, 'utf8');
  abiFile = abiFile.replace(/export const BOUNTY_ADDRESS = ".*";/, `export const BOUNTY_ADDRESS = "${bountyAddress}";`);
  abiFile = abiFile.replace(/export const TOKEN_ADDRESS = ".*";/, `export const TOKEN_ADDRESS = "${tokenAddress}";`);
  abiFile = abiFile.replace(/export const FAUCET_ADDRESS = ".*";/, `export const FAUCET_ADDRESS = "${faucetAddress}";`);
  abiFile = abiFile.replace(/export const STAKING_ADDRESS = ".*";/, `export const STAKING_ADDRESS = "${stakingAddress}";`);
  
  // Add new contract addresses if not present
  if (!abiFile.includes("REPUTATION_ADDRESS")) {
    abiFile += `\nexport const REPUTATION_ADDRESS = "${reputationAddress}";\n`;
  } else {
    abiFile = abiFile.replace(/export const REPUTATION_ADDRESS = ".*";/, `export const REPUTATION_ADDRESS = "${reputationAddress}";`);
  }
  if (!abiFile.includes("GOVERNANCE_ADDRESS")) {
    abiFile += `export const GOVERNANCE_ADDRESS = "${governanceAddress}";\n`;
  } else {
    abiFile = abiFile.replace(/export const GOVERNANCE_ADDRESS = ".*";/, `export const GOVERNANCE_ADDRESS = "${governanceAddress}";`);
  }
  
  fs.writeFileSync(abiPath, abiFile);
  console.log("  ✅ Updated frontend/src/abi.ts with all contract addresses!");

  // ─── Summary ───────────────────────────────────
  console.log("\n═══════════════════════════════════════════════════");
  console.log("  Deployment Summary — Vepo Network V4.0");
  console.log("═══════════════════════════════════════════════════");
  console.log(`  VepoToken:       ${tokenAddress}`);
  console.log(`  VepoFaucet:      ${faucetAddress}`);
  console.log(`  VepoBounty:      ${bountyAddress}`);
  console.log(`  VepoStaking:     ${stakingAddress}`);
  console.log(`  VepoReputation:  ${reputationAddress}`);
  console.log(`  VepoGovernance:  ${governanceAddress}`);
  console.log(`  MockUSDC:        ${usdcAddress}`);
  console.log(`  MockRouter:      ${routerAddress}`);
  console.log("═══════════════════════════════════════════════════");
  console.log("  Genesis Supply Allocation:");
  console.log("    Faucet:  1,000,000 $VEPO");
  console.log("    Router:  5,000,000 $VEPO (mock liquidity)");
  console.log("    Deployer: 94,000,000 $VEPO (remaining)");
  console.log("═══════════════════════════════════════════════════\n");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
