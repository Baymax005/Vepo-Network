const fs = require('fs');
const path = require('path');

const vepoTokenPath = path.join(__dirname, '../artifacts/contracts/VepoToken.sol/VepoToken.json');
const vepoBountyPath = path.join(__dirname, '../artifacts/contracts/VepoBounty.sol/VepoBounty.json');
const vepoStakingPath = path.join(__dirname, '../artifacts/contracts/VepoStaking.sol/VepoStaking.json');
const vepoFaucetPath = path.join(__dirname, '../artifacts/contracts/VepoFaucet.sol/VepoFaucet.json');
const abiTsPath = path.join(__dirname, '../../frontend/src/abi.ts');

const vepoTokenAbi = JSON.parse(fs.readFileSync(vepoTokenPath, 'utf8')).abi;
const vepoBountyAbi = JSON.parse(fs.readFileSync(vepoBountyPath, 'utf8')).abi;
const vepoStakingAbi = JSON.parse(fs.readFileSync(vepoStakingPath, 'utf8')).abi;
const vepoFaucetAbi = JSON.parse(fs.readFileSync(vepoFaucetPath, 'utf8')).abi;

let abiTs = fs.readFileSync(abiTsPath, 'utf8');

// Extract addresses from existing abi.ts
const bountyAddressMatch = abiTs.match(/export const BOUNTY_ADDRESS = "(.*?)";/);
const tokenAddressMatch = abiTs.match(/export const TOKEN_ADDRESS = "(.*?)";/);
const faucetAddressMatch = abiTs.match(/export const FAUCET_ADDRESS = "(.*?)";/);
const stakingAddressMatch = abiTs.match(/export const STAKING_ADDRESS = "(.*?)";/);

const newAbiTs = `
export const VepoTokenABI = ${JSON.stringify(vepoTokenAbi, null, 2)} as const;
export const VepoBountyABI = ${JSON.stringify(vepoBountyAbi, null, 2)} as const;
export const VepoStakingABI = ${JSON.stringify(vepoStakingAbi, null, 2)} as const;
export const VepoFaucetABI = ${JSON.stringify(vepoFaucetAbi, null, 2)} as const;

export const BOUNTY_ADDRESS = "${bountyAddressMatch[1]}";
export const TOKEN_ADDRESS = "${tokenAddressMatch[1]}";
export const FAUCET_ADDRESS = "${faucetAddressMatch[1]}";
export const STAKING_ADDRESS = "${stakingAddressMatch ? stakingAddressMatch[1] : ""}";
`;

fs.writeFileSync(abiTsPath, newAbiTs);
console.log("Successfully rebuilt abi.ts");
