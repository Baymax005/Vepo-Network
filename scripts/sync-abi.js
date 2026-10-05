const fs = require('fs');
const path = require('path');

const contractsDir = path.join(__dirname, '..', 'contracts', 'artifacts', 'contracts');

const token = require(path.join(contractsDir, 'VepoToken.sol', 'VepoToken.json')).abi;
const bounty = require(path.join(contractsDir, 'VepoBounty.sol', 'VepoBounty.json')).abi;
const staking = require(path.join(contractsDir, 'VepoStaking.sol', 'VepoStaking.json')).abi;
const faucet = require(path.join(contractsDir, 'VepoFaucet.sol', 'VepoFaucet.json')).abi;
const rep = require(path.join(contractsDir, 'VepoReputation.sol', 'VepoReputation.json')).abi;
const gov = require(path.join(contractsDir, 'VepoGovernance.sol', 'VepoGovernance.json')).abi;

const content = `
export const VepoTokenABI = ${JSON.stringify(token, null, 2)} as const;

export const VepoBountyABI = ${JSON.stringify(bounty, null, 2)} as const;

export const VepoStakingABI = ${JSON.stringify(staking, null, 2)} as const;

export const VepoFaucetABI = ${JSON.stringify(faucet, null, 2)} as const;

export const VepoReputationABI = ${JSON.stringify(rep, null, 2)} as const;

export const VepoGovernanceABI = ${JSON.stringify(gov, null, 2)} as const;

export const BOUNTY_ADDRESS = "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9";
export const TOKEN_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
export const FAUCET_ADDRESS = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
export const STAKING_ADDRESS = "0xa513E6E4b8f2a923D98304ec87F64353C4D5C853";

export const REPUTATION_ADDRESS = "0x8A791620dd6260079BF849Dc5567aDC3F2FdC318";
export const GOVERNANCE_ADDRESS = "0x610178dA211FEF7D417bC0e6FeD39F05609AD788";
`;

fs.writeFileSync(path.join(__dirname, '..', 'frontend', 'src', 'abi.ts'), content.trim() + '\n');
console.log('Successfully generated frontend/src/abi.ts');
