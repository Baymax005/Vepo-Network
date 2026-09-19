import { parseAbi } from 'viem';

export const VepoTokenABI = parseAbi([
  "function approve(address spender, uint256 value) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function balanceOf(address account) view returns (uint256)",
]);

export const VepoFaucetABI = parseAbi([
  "function requestTokens() external",
]);

export const VepoBountyABI = parseAbi([
  "function postBounty() payable",
  "function boostBounty(uint256 bountyId)",
  "function submitWork(uint256 bountyId, string workLink)",
  "function rejectWork(uint256 bountyId)",
  "function cancelBounty(uint256 bountyId)",
  "function releaseFunds(uint256 bountyId)",
  "function bountyCounter() view returns (uint256)",
  "function bounties(uint256) view returns (uint256 bountyId, address client, address freelancer, uint256 amount, uint256 originalAmount, uint8 state, bool isBoosted, string workLink)",
]);

export const BOUNTY_ADDRESS = "0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE";
export const TOKEN_ADDRESS = "0x9A676e781A523b5d0C0e43731313A708CB607508";
export const FAUCET_ADDRESS = "0x0B306BF915C4d645ff596e518fAf3F9669b97016";
export const STAKING_ADDRESS = "0x59b670e9fA9D0A427751Af201D676719a970857b";
