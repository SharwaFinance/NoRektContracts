import { keccak256, toUtf8Bytes } from "ethers"
import { HardhatRuntimeEnvironment } from "hardhat/types"


async function deployment(hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get, execute } = deployments
  const { deployer } = await getNamedAccounts()

  const MarginTrading = await get("MarginTrading")
  const OneClickProxy = await get("OneClickProxy")
  const OneClickLiquidation = await get("OneClickLiquidation")
  const MarginAccount = await get("MarginAccount")
  const OneClickLiquidityPool = await get("OneClickLiquidityPool")
  const LiquidityPool_USDC = await get("USDC_LiquidityPool")
  const LiquidityPool_WETH = await get("WETH_LiquidityPool")

  const controller = await deploy("OneClickShutdownController", {
    from: deployer,
    log: true,
    args: [
      MarginTrading.address,
      LiquidityPool_USDC.address,
      LiquidityPool_WETH.address,
      OneClickProxy.address,
      OneClickLiquidation.address,
      MarginAccount.address,
      OneClickLiquidityPool.address,
    ]
  })

  const MANAGER_ROLE = keccak256(toUtf8Bytes("MANAGER_ROLE"));

  await execute(
    "MarginTrading",
    { from: deployer, log: true },
    "grantRole",
    MANAGER_ROLE,
    controller.address
  )
  await execute(
    "USDC_LiquidityPool",
    { from: deployer, log: true },
    "grantRole",
    MANAGER_ROLE,
    controller.address
  )
  await execute(
    "WETH_LiquidityPool",
    { from: deployer, log: true },
    "grantRole",
    MANAGER_ROLE,
    controller.address
  )
}

deployment.tags = ["one_click_shutdown_controller"]

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
  "swap_output_module"
]

export default deployment
