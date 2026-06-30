import { keccak256, MaxUint256, toUtf8Bytes } from "ethers"
import { HardhatRuntimeEnvironment } from "hardhat/types"

async function deployment(hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get, execute } = deployments
  const { deployer } = await getNamedAccounts()

  const WETH_LiquidityPool = await get("WETH_LiquidityPool")
  const USDC_LiquidityPool = await get("USDC_LiquidityPool")
  const WETH = await get("WETH")
  const USDC = await get("USDC")
  const PROTOCOL_ROUTER_ROLE = keccak256(toUtf8Bytes("PROTOCOL_ROUTER_ROLE"));

  const OneClickLiquidityPool = await deploy("OneClickLiquidityPool", {
    from: deployer,
    log: true,
    args: [
      WETH.address
    ],
  })

  const ROUTER_ROLE = keccak256(toUtf8Bytes("ROUTER_ROLE"));

  const OneClickLiquidityPoolRouter = await deploy("OneClickLiquidityPoolRouter", {
    from: deployer,
    log: true,
    args: [
      OneClickLiquidityPool.address
    ],
  })

  await execute(
    "OneClickLiquidityPool",
    { log: true, from: deployer },
    "grantRole",
    ROUTER_ROLE,
    OneClickLiquidityPoolRouter.address
  )

  await execute(
    "OneClickLiquidityPool",
    { log: true, from: deployer },
    "approveERC20",
    WETH.address,
    WETH_LiquidityPool.address,
    MaxUint256
  )

  await execute(
    "OneClickLiquidityPool",
    { log: true, from: deployer },
    "approveERC20",
    USDC.address,
    USDC_LiquidityPool.address,
    MaxUint256
  )

  await execute(
    "OneClickLiquidityPool",
    { log: true, from: deployer },
    "setLiquidityPool",
    WETH.address,
    WETH_LiquidityPool.address
  )

  await execute(
    "OneClickLiquidityPool",
    { log: true, from: deployer },
    "setLiquidityPool",
    USDC.address,
    USDC_LiquidityPool.address
  )

  await execute(
    "WETH_LiquidityPool",
    { log: true, from: deployer },
    "grantRole",
    PROTOCOL_ROUTER_ROLE,
    OneClickLiquidityPool.address
  );

  await execute(
    "USDC_LiquidityPool",
    { log: true, from: deployer },
    "grantRole",
    PROTOCOL_ROUTER_ROLE,
    OneClickLiquidityPool.address
  );
}

deployment.tags = ["one_click_liquidity_pool"]
deployment.dependencies = ["preparation", "margin_account", "liquidity_pool", "modular_swap_router", "uniswap_module", "hegic_module", "margin_trading", "margin_account_manager"]

export default deployment
