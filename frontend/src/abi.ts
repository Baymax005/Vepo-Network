import { parseAbi } from 'viem';

export const VepoTokenABI = parseAbi([
  "function approve(address spender, uint256 value) returns (bool)",
  "function faucet(address to) external",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function balanceOf(address account) view returns (uint256)",
]);

export const VepoBountyABI = parseAbi([
  "function postBounty() payable",
  "function boostBounty(uint256 bountyId)",
  "function submitWork(uint256 bountyId, string workLink)",
  "function rejectWork(uint256 bountyId)",
  "function cancelBounty(uint256 bountyId)",
  "function releaseFunds(uint256 bountyId)",
  "function bountyCounter() view returns (uint256)",
  "function bounties(uint256) view returns (uint256 bountyId, address client, address freelancer, uint256 amount, uint8 state, bool isBoosted, string workLink)",
]);

export const BOUNTY_ADDRESS = "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9";
export const TOKEN_ADDRESS = "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9";
