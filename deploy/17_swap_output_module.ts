import { ZeroAddress } from "ethers"
import { HardhatRuntimeEnvironment } from "hardhat/types"

async function deployment(hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get, execute } = deployments
  const { deployer } = await getNamedAccounts()

  const WETHeph = await get("WETHeph")
  const USDCeph = await get("USDCeph")
  const WETH = await get("WETH")
  const USDC = await get("USDC")
  const AggregatorV3_WETH_USDC = await get("AggregatorV3_WETH_USDC")
  const SequencerUptimeFeed = await get("SequencerUptimeFeed")

  let contractsMap = new Map<string, string>([
    ["WETH", WETH.address],
    ["USDC", USDC.address]
  ]);

  let originalTokenToEphemeralToken = new Map<string, string>([
    ["WETH", WETHeph.address],
    ["USDC", USDCeph.address],
  ]);


  const arrayParams = [
    { "tokenIn": "WETH", "poolFee": 500, "tokenOut": "USDC", "aggregatorV3": AggregatorV3_WETH_USDC.address },
    { "tokenIn": "USDC", "poolFee": 500, "tokenOut": "USDC", "aggregatorV3": ZeroAddress },
  ]

  async function deployUniswapModule(tokenIn: string, poolFee: number, tokenOut: string, aggregatorV3: string) {
    const contractName = `${tokenIn}_${tokenOut}_EphemeralSwapOutput`

    let contract = "EphemeralSwapOutput"
    let args = [
      contractsMap.get(tokenIn),
      poolFee,
      contractsMap.get(tokenOut),
      aggregatorV3,
      SequencerUptimeFeed.address,
    ]

    if (aggregatorV3 == ZeroAddress) {
      contract = "EphemeralSwapOutputUSDC"
      args = [
        contractsMap.get(tokenIn),
        poolFee,
        contractsMap.get(tokenOut),
      ]
    }

    const module = await deploy(contractName, {
      contract: contract,
      from: deployer,
      log: true,
      args: args,
    })

    await execute(
      "ModularSwapRouter",
      { log: true, from: deployer },
      "setTokenInToTokenOutToExchange",
      originalTokenToEphemeralToken.get(tokenIn),
      contractsMap.get(tokenOut),
      module.address
    )
  }

  for (let item in arrayParams) {
    await deployUniswapModule(arrayParams[item].tokenIn, arrayParams[item].poolFee, arrayParams[item].tokenOut, arrayParams[item].aggregatorV3)
  }

  await execute(
    "MarginAccount",
    { log: true, from: deployer },
    "setAvailableErc20",
    [USDC.address, WETH.address, WETHeph.address, USDCeph.address], //_availableErc20
  )

}

deployment.tags = ["swap_output_module"]

deployment.dependencies = [
  "one_click",
  "preparation",
  "margin_account",
  "liquidity_pool",
  "modular_swap_router",
  "uniswap_module",
  "hegic_module",
  "margin_trading",
  "margin_account_manager",
  "one_click_liquidity_pool",
  "one_click_ephemeral_tokens",
  "one_click_proxy",
  "one_click_options",
  "hegic_take_profit",
]

export default deployment
