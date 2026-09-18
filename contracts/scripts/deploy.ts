import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy VepoToken
  const VepoToken = await ethers.getContractFactory("VepoToken");
  const vepoToken = await VepoToken.deploy();
  await vepoToken.waitForDeployment();
  const tokenAddress = await vepoToken.getAddress();
  console.log("VepoToken deployed to:", tokenAddress);

  // Use deployer as treasury for this MVP
  const treasuryAddress = deployer.address;

  // Deploy VepoBounty
  const VepoBounty = await ethers.getContractFactory("VepoBounty");
  const vepoBounty = await VepoBounty.deploy(tokenAddress, treasuryAddress);
  await vepoBounty.waitForDeployment();
  const bountyAddress = await vepoBounty.getAddress();
  console.log("VepoBounty deployed to:", bountyAddress);

  const fs = require("fs");
  const path = require("path");
  const abiPath = path.join(__dirname, "../../frontend/src/abi.ts");
  let abiFile = fs.readFileSync(abiPath, 'utf8');
  abiFile = abiFile.replace(/export const BOUNTY_ADDRESS = ".*";/, `export const BOUNTY_ADDRESS = "${bountyAddress}";`);
  abiFile = abiFile.replace(/export const TOKEN_ADDRESS = ".*";/, `export const TOKEN_ADDRESS = "${tokenAddress}";`);
  fs.writeFileSync(abiPath, abiFile);
  console.log("Updated frontend/src/abi.ts with new addresses!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
