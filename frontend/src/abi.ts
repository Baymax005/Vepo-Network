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
  "function bounties(uint256) view returns (uint256 bountyId, address client, address freelancer, uint256 amount, uint256 originalAmount, uint8 state, bool isBoosted, string workLink)",
]);

export const BOUNTY_ADDRESS = "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6";
export const TOKEN_ADDRESS = "0xa513E6E4b8f2a923D98304ec87F64353C4D5C853";
