export const VepoTokenABI = [
  "function approve(address spender, uint256 value) returns (bool)",
  "function faucet(address to, uint256 amount) external",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function balanceOf(address account) view returns (uint256)",
] as const;

export const VepoBountyABI = [
  "function postBounty() payable",
  "function boostBounty(uint256 bountyId)",
  "function bountyCounter() view returns (uint256)",
  "function bounties(uint256) view returns (uint256 bountyId, address client, address freelancer, uint256 amount, bool isCompleted, bool isBoosted)",
] as const;

export const BOUNTY_ADDRESS = "0x0000000000000000000000000000000000000000"; // Replace after deployment
export const TOKEN_ADDRESS = "0x0000000000000000000000000000000000000000"; // Replace after deployment
