import "@keep-network/hardhat-local-networks-config";
import '@nomicfoundation/hardhat-toolbox';
import "@nomicfoundation/hardhat-verify";
import 'hardhat-contract-sizer';
import 'hardhat-deploy';
import 'hardhat-deploy-ethers';
import { HardhatUserConfig } from "hardhat/config";
// import "hardhat-tracer";
import dotenv from "dotenv";

if (process.env.TRACER === "1") {
  require("hardhat-tracer");
}

dotenv.config({ debug: false })

const config: HardhatUserConfig = {
  localNetworksConfig: "~/.hardhat/networks.json",
  solidity: {
    version: "0.8.20",
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  gasReporter: {
    enabled: false,
    currency: 'USD',
    L2: "arbitrum",
    coinmarketcap: process.env.COINMARKET_CAP_API,
    L2Etherscan: process.env.ARBITRUM_API_KEY
  },
  etherscan: {
    apiKey: process.env.ARBITRUM_API_KEY,
    customChains: [
      {
        network: "arbitrum_sharwaFinance",
        chainId: 42161,
        urls: {
          apiURL: "https://api.arbiscan.io/api",
          browserURL: "https://arbiscan.io"
        }
      },
    ]
  },
  sourcify: {
    enabled: true
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false
    }
  },
  typechain: {
    externalArtifacts: [
      "node_modules/@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Factory.sol/IUniswapV3Factory.json",
      "node_modules/@uniswap/v3-periphery/artifacts/contracts/NonfungiblePositionManager.sol/NonfungiblePositionManager.json"
    ],
  }
};

export default config;
