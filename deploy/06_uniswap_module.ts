import { keccak256, MaxUint256, toUtf8Bytes, ZeroAddress } from "ethers"
import { HardhatRuntimeEnvironment } from "hardhat/types"

async function deployment(hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get, execute } = deployments
  const { deployer } = await getNamedAccounts()

  const MarginAccount = await get("MarginAccount")
  const ModularSwapRouter = await get("ModularSwapRouter")
  const SwapRouter = await get("SwapRouter")
  const Quoter = await get("Quoter")
  const WETH = await get("WETH")
  const USDC = await get("USDC")
  const AggregatorV3_WETH_USDC = await get("AggregatorV3_WETH_USDC")
  const SequencerUptimeFeed = await get("SequencerUptimeFeed")

  const MODULAR_SWAP_ROUTER_ROLE = keccak256(toUtf8Bytes("MODULAR_SWAP_ROUTER_ROLE"));
  const MANAGER_ROLE = keccak256(toUtf8Bytes("MANAGER_ROLE"));

  let contractsMap = new Map<string, string>([
    ["WETH", WETH.address],
    ["USDC", USDC.address]
  ]);

  const arrayParams = [
    { "tokenIn": "WETH", "poolFee": 500, "tokenOut": "USDC", "aggregatorV3": AggregatorV3_WETH_USDC.address },
    { "tokenIn": "USDC", "poolFee": 500, "tokenOut": "WETH", "aggregatorV3": AggregatorV3_WETH_USDC.address },
  ]

  async function deployUniswapModule(tokenIn: string, poolFee: number, tokenOut: string, aggregatorV3: string) {
    const contractName = `${tokenIn}_${tokenOut}_UniswapModule`

    let contract = "UniswapModuleWithoutChainlink"
    let args = [
      MarginAccount.address,
      contractsMap.get(tokenIn),
      poolFee,
      contractsMap.get(tokenOut),
      SwapRouter.address,
      Quoter.address
    ]

    if (aggregatorV3 != ZeroAddress) {
      if (tokenIn == "USDC") {
        contract = "UniswapModuleWithChainlinkInvertedFeed"
      } else {
        contract = "UniswapModuleWithChainlink"
      }
      args = [
        MarginAccount.address,
        contractsMap.get(tokenIn),
        poolFee,
        contractsMap.get(tokenOut),
        aggregatorV3,
        SequencerUptimeFeed.address,
        SwapRouter.address,
        Quoter.address
      ]
    }

    const module = await deploy(contractName, {
      contract: contract,
      from: deployer,
      log: true,
      args: args,
    })

    await execute(
      contractName,
      { log: true, from: deployer },
      "grantRole",
      MODULAR_SWAP_ROUTER_ROLE,
      ModularSwapRouter.address
    )

    await execute(
      contractName,
      { log: true, from: deployer },
      "grantRole",
      MANAGER_ROLE,
      deployer
    )

    await execute(
      contractName,
      { log: true, from: deployer },
      "allApprove"
    )

    await execute(
      "ModularSwapRouter",
      { log: true, from: deployer },
      "setTokenInToTokenOutToExchange",
      contractsMap.get(tokenIn),
      contractsMap.get(tokenOut),
      module.address
    )

    await execute(
      "MarginAccount",
      { log: true, from: deployer },
      "approveERC20",
      contractsMap.get(tokenIn),
      module.address,
      MaxUint256
    )

    await execute(
      "MarginAccount",
      { log: true, from: deployer },
      "approveERC20",
      contractsMap.get(tokenOut),
      module.address,
      MaxUint256
    )

  }

  for (let item in arrayParams) {
    await deployUniswapModule(arrayParams[item].tokenIn, arrayParams[item].poolFee, arrayParams[item].tokenOut, arrayParams[item].aggregatorV3)
  }

}

deployment.tags = ["uniswap_module"]
deployment.dependencies = ["margin_account", "modular_swap_router"]

export default deployment
