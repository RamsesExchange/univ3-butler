import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import { resolve } from "path";
import { config as dotenvConfig } from "dotenv";
dotenvConfig({ path: resolve(__dirname, "./.env") });

const config: HardhatUserConfig = {
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      initialBaseFeePerGas: 0,
      chainId: 42161,
      blockGasLimit: 1000000000,

      forking: {
        url: `https://arbitrum-one.public.blastapi.io`,
        blockNumber: 127502248,
      },
    },
    local: {
      initialBaseFeePerGas: 0,
      url: "http://127.0.0.1:8546",
      timeout: 36000,
      allowUnlimitedContractSize: true,
    },
    arbitrum: {
      url: "https://arbitrum-one.public.blastapi.io",
      accounts: [process.env.PRIVATE_KEY!],
    },
  },
  solidity: {
    version: "0.8.21",
    settings: {
      viaIR: true,
      evmVersion: "paris",
      optimizer: {
        enabled: true,
        runs: 10000,
      },
    },
  },
};

export default config;
