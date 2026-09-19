import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Vepo Network - Deploying contracts with the account:", deployer.address);

  // 1. Deploy VepoToken
  const VepoToken = await ethers.getContractFactory("VepoToken");
  const vepoToken = await VepoToken.deploy();
  await vepoToken.waitForDeployment();
  const tokenAddress = await vepoToken.getAddress();
  console.log("VepoToken deployed to:", tokenAddress);

  // 2. Deploy VepoFaucet and Fund It
  const VepoFaucet = await ethers.getContractFactory("VepoFaucet");
  const vepoFaucet = await VepoFaucet.deploy(tokenAddress);
  await vepoFaucet.waitForDeployment();
  const faucetAddress = await vepoFaucet.getAddress();
  console.log("VepoFaucet deployed to:", faucetAddress);

  // Fund Faucet with 1,000,000 VEPO from Genesis supply
  console.log("Funding VepoFaucet with 1,000,000 $VEPO...");
  const fundTx = await vepoToken.transfer(faucetAddress, ethers.parseUnits("1000000", 18));
  await fundTx.wait();
  console.log("VepoFaucet successfully funded.");

  // 3. Deploy VepoBounty
  const VepoBounty = await ethers.getContractFactory("VepoBounty");
  // Bounty constructor now only takes the token address
  const vepoBounty = await VepoBounty.deploy(tokenAddress);
  await vepoBounty.waitForDeployment();
  const bountyAddress = await vepoBounty.getAddress();
  console.log("VepoBounty deployed to:", bountyAddress);

  // 4. Deploy Mocks for Local Testing
  const MockUSDC = await ethers.getContractFactory("MockUSDC");
  const mockUSDC = await MockUSDC.deploy();
  await mockUSDC.waitForDeployment();
  const usdcAddress = await mockUSDC.getAddress();
  console.log("MockUSDC deployed to:", usdcAddress);

  const MockRouter = await ethers.getContractFactory("MockUniswapV2Router");
  const mockRouter = await MockRouter.deploy(usdcAddress, tokenAddress);
  await mockRouter.waitForDeployment();
  const routerAddress = await mockRouter.getAddress();
  console.log("MockUniswapV2Router deployed to:", routerAddress);

  // We need to fund the mock router with VEPO so it can perform swaps!
  console.log("Funding Mock Router with VEPO for swaps...");
  const fundRouterTx = await vepoToken.transfer(routerAddress, ethers.parseUnits("5000000", 18));
  await fundRouterTx.wait();
  console.log("Mock Router funded.");

  // 5. Deploy VepoStaking (Treasury Engine)
  const VepoStaking = await ethers.getContractFactory("VepoStaking");
  const vepoStaking = await VepoStaking.deploy(tokenAddress, usdcAddress, routerAddress);
  await vepoStaking.waitForDeployment();
  const stakingAddress = await vepoStaking.getAddress();
  console.log("VepoStaking deployed to:", stakingAddress);

  // Update frontend ABIs
  const fs = require("fs");
  const path = require("path");
  const abiPath = path.join(__dirname, "../../frontend/src/abi.ts");
  let abiFile = fs.readFileSync(abiPath, 'utf8');
  abiFile = abiFile.replace(/export const BOUNTY_ADDRESS = ".*";/, `export const BOUNTY_ADDRESS = "${bountyAddress}";`);
  abiFile = abiFile.replace(/export const TOKEN_ADDRESS = ".*";/, `export const TOKEN_ADDRESS = "${tokenAddress}";`);
  abiFile = abiFile.replace(/export const FAUCET_ADDRESS = ".*";/, `export const FAUCET_ADDRESS = "${faucetAddress}";`);
  abiFile = abiFile.replace(/export const STAKING_ADDRESS = ".*";/, `export const STAKING_ADDRESS = "${stakingAddress}";`);
  fs.writeFileSync(abiPath, abiFile);
  console.log("Updated frontend/src/abi.ts with new core addresses!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
