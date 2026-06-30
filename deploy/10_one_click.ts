import { keccak256, MaxUint256, toUtf8Bytes } from "ethers"
import { HardhatRuntimeEnvironment } from "hardhat/types"

async function deployment(hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get, execute } = deployments
  const { deployer } = await getNamedAccounts()

  const MarginAccountManager = await get("MarginAccountManager")
  const MarginAccount = await get("MarginAccount")
  const MarginTrading = await get("MarginTrading")
  const SwapRouter = await get("SwapRouter")
  const Quoter = await get("Quoter")
  const WETH = await get("WETH")
  const USDC = await get("USDC")
  const USDCe = await get("USDCe")
  const WETHeph = await get("WETHeph")
  const USDCeph = await get("USDCeph")
  const FACADE_ROLE = keccak256(toUtf8Bytes("FACADE_ROLE"));
  const NO_YELLOW_ROLE = keccak256(toUtf8Bytes("NO_YELLOW_ROLE"));
  const ONE_CLICK_CONTRACT_ROLE = keccak256(toUtf8Bytes("ONE_CLICK_CONTRACT_ROLE"));
  const LIQUIDATOR_ROLE = keccak256(toUtf8Bytes("LIQUIDATOR_ROLE"));
  const ONE_CLICK_LIQUIDATION_ROLE = keccak256(toUtf8Bytes("ONE_CLICK_LIQUIDATION_ROLE"));
  const TRADE_ROUTER_ROLE = keccak256(toUtf8Bytes("TRADE_ROUTER_ROLE"));
  const OneClickProxy = await get("OneClickProxy")
  const HegicPositionsManager = await get("HegicPositionsManager")
  const MarginTradingRouter = await deploy("MarginTradingRouter", {
    from: deployer,
    log: true,
    args: [
      MarginAccountManager.address,
      MarginTrading.address
    ],
  })

  await execute("MarginTradingRouter", { log: true, from: deployer }, "setProvideWithdrawRestricted", USDCe.address, true)
  await execute("OneClickProxy", { log: true, from: deployer }, "grantRole", FACADE_ROLE, MarginTradingRouter.address)
  await execute("MarginTradingRouter", { log: true, from: deployer }, "setOneClickProxy", OneClickProxy.address)
  await execute("MarginTradingRouter", { log: true, from: deployer }, "approveERC20", WETH.address, OneClickProxy.address, MaxUint256)
  await execute("MarginTradingRouter", { log: true, from: deployer }, "approveERC20", USDC.address, OneClickProxy.address, MaxUint256)
  await execute("MarginTradingRouter", { log: true, from: deployer }, "approveERC20", WETHeph.address, OneClickProxy.address, MaxUint256)
  await execute("MarginTradingRouter", { log: true, from: deployer }, "approveERC20", USDCeph.address, OneClickProxy.address, MaxUint256)
  await execute("MarginTradingRouter", { log: true, from: deployer }, "approveERC20", WETH.address, MarginTradingRouter.address, MaxUint256)
  await execute("MarginTradingRouter", { log: true, from: deployer }, "approveERC721ForAll", HegicPositionsManager.address, OneClickProxy.address, true)

  const LiquidationEventsStorage = await deploy("LiquidationEventsStorage", {
    from: deployer,
    log: true,
  })

  const OneClickLiquidation = await deploy("OneClickLiquidation", {
    from: deployer,
    log: true,
    args: [
      MarginTrading.address,
      OneClickProxy.address,
      LiquidationEventsStorage.address
    ],
  })

  await execute("MarginTrading", { log: true, from: deployer }, "grantRole", LIQUIDATOR_ROLE, OneClickLiquidation.address)
  await execute("OneClickProxy", { log: true, from: deployer }, "grantRole", FACADE_ROLE, OneClickLiquidation.address)
  await execute("LiquidationEventsStorage", { log: true, from: deployer }, "grantRole", ONE_CLICK_LIQUIDATION_ROLE, OneClickLiquidation.address)

  const OneClickEphemeralSwapOutput = await deploy("OneClickEphemeralSwapOutput", {
    from: deployer,
    log: true,
    args: [
      MarginAccountManager.address,
      OneClickProxy.address,
      SwapRouter.address,
      Quoter.address
    ],
  })

  await execute("OneClickEphemeralSwapOutput", { log: true, from: deployer }, "setOriginalTokenToEphemeralToken", WETH.address, WETHeph.address)
  await execute("OneClickEphemeralSwapOutput", { log: true, from: deployer }, "setOriginalTokenToEphemeralToken", USDC.address, USDCeph.address)
  await execute("OneClickEphemeralSwapOutput", { log: true, from: deployer }, "approveERC20", WETH.address, OneClickProxy.address, MaxUint256)
  await execute("OneClickEphemeralSwapOutput", { log: true, from: deployer }, "approveERC20", USDC.address, OneClickProxy.address, MaxUint256)
  await execute("OneClickEphemeralSwapOutput", { log: true, from: deployer }, "approveERC20", WETHeph.address, OneClickProxy.address, MaxUint256)
  await execute("OneClickEphemeralSwapOutput", { log: true, from: deployer }, "approveERC20", USDCeph.address, OneClickProxy.address, MaxUint256)
  await execute("OneClickEphemeralSwapOutput", { log: true, from: deployer }, "approveERC20", WETH.address, SwapRouter.address, MaxUint256)
  await execute("OneClickEphemeralSwapOutput", { log: true, from: deployer }, "approveERC20", USDC.address, SwapRouter.address, MaxUint256)
  await execute("OneClickProxy", { log: true, from: deployer }, "grantRole", FACADE_ROLE, OneClickEphemeralSwapOutput.address)
  await execute("OneClickProxy", { log: true, from: deployer }, "grantRole", NO_YELLOW_ROLE, OneClickEphemeralSwapOutput.address)
  await execute("WETHeph", { log: true, from: deployer }, "grantRole", FACADE_ROLE, OneClickEphemeralSwapOutput.address)
  await execute("USDCeph", { log: true, from: deployer }, "grantRole", FACADE_ROLE, OneClickEphemeralSwapOutput.address)
  await execute(
    "MarginAccount",
    { log: true, from: deployer },
    "setIsAvailableErc20",
    USDCeph.address,   //token
    true            //value
  )

  await execute(
    "MarginAccount",
    { log: true, from: deployer },
    "setIsAvailableErc20",
    WETHeph.address,   //token
    true            //value
  )

  const OneClickTrading = await deploy("OneClickTrading", {
    from: deployer,
    log: true,
    args: [
      MarginAccountManager.address,
      OneClickProxy.address,
      MarginAccount.address,
      WETH.address,
      USDC.address
    ],
  })

  await execute("OneClickTrading", { log: true, from: deployer }, "approveERC20", WETH.address, OneClickProxy.address, MaxUint256)
  await execute("OneClickTrading", { log: true, from: deployer }, "approveERC20", USDC.address, OneClickProxy.address, MaxUint256)
  await execute("OneClickProxy", { log: true, from: deployer }, "grantRole", FACADE_ROLE, OneClickTrading.address)
}

deployment.tags = ["one_click"]
deployment.dependencies = ["one_click_proxy", "one_click_ephemeral_tokens"]

export default deployment
