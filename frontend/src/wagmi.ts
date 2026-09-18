import { http, createConfig } from '@wagmi/vue'
import { defineChain } from 'viem'

export const vepoTestnet = defineChain({
  id: 2739,
  name: 'Vepo Testnet',
  network: 'vepo-testnet',
  nativeCurrency: {
    decimals: 18,
    name: 'USDC',
    symbol: 'USDC',
  },
  rpcUrls: {
    default: {
      http: ['http://127.0.0.1:8545'], // Assuming local or replace with actual
    },
    public: {
      http: ['http://127.0.0.1:8545'],
    },
  },
})

export const config = createConfig({
  chains: [vepoTestnet],
  transports: {
    [vepoTestnet.id]: http(),
  },
})
