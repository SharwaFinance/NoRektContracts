import { keccak256, toUtf8Bytes } from "ethers"
import { HardhatRuntimeEnvironment } from "hardhat/types"

async function deployment(hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get, execute } = deployments
  const { deployer } = await getNamedAccounts()

  const HegicPositionsManager = await get("HegicPositionsManager")
  const OperationalTreasury = await get("OperationalTreasury")
  const OneClickProxy = await get("OneClickProxy")
  const MarginAccountManager = await get("MarginAccountManager")
  const LendingMarginAccountManager = await get("LendingMarginAccountManager")
  const OneClickNoRekt = await get("OneClickNoRekt")
  const HegicModule = await get("HegicModule")
  const USDC = await get("USDC")

  const FACADE_ROLE = keccak256(toUtf8Bytes("FACADE_ROLE"));
  const EXECUTOR_ROLE = keccak256(toUtf8Bytes("EXECUTOR_ROLE"));

  const HegicTakeProfit = await deploy("HegicTakeProfit", {
    from: deployer,
    log: true,
    args: [
      HegicPositionsManager.address,
      OperationalTreasury.address,
      OneClickProxy.address,
      MarginAccountManager.address,
      LendingMarginAccountManager.address,
      OneClickNoRekt.address,
      USDC.address
    ],
  })

  await execute("OneClickNoRekt", { log: true, from: deployer }, "grantRole", EXECUTOR_ROLE, HegicTakeProfit.address)

  await deploy("HegicTakeProfitProxy", {
    from: deployer,
    log: true,
    args: [
      HegicTakeProfit.address,
      HegicModule.address
    ]
  })

  await execute(
    "MarginAccount",
    { log: true, from: deployer },
    "approveERC721ForAll",
    HegicPositionsManager.address,
    HegicTakeProfit.address,
    true
  )

  await execute(
    "OneClickProxy",
    { log: true, from: deployer },
    "grantRole",
    FACADE_ROLE,
    HegicTakeProfit.address
  )

}

deployment.tags = ["hegic_take_profit"]
deployment.dependencies = ["preparation", "margin_account_manager", "lending_margin_account_manager", "liquidity_pool", "modular_swap_router", "uniswap_module", "one_click_proxy", "one_click_ephemeral_tokens", "one_click_options"]

export default deployment
