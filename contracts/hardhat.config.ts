import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    hardhat: {
      chainId: 2739 // Vepo testnet chainId to simulate locally
    },
    vepo: {
      url: "http://127.0.0.1:8545", // Replace with actual RPC URL
      chainId: 2739
    }
  }
};

export default config;
