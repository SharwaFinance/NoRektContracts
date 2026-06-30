import { keccak256, MaxUint256, toUtf8Bytes } from "ethers"
import { HardhatRuntimeEnvironment } from "hardhat/types"

async function deployment(hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get, execute } = deployments
  const { deployer } = await getNamedAccounts()

  const MarginTrading = await get("MarginTrading")
  const HegicPositionsManager = await get("HegicPositionsManager")
  const MarginAccount = await get("MarginAccount")
  const WETH = await get("WETH")
  const USDC = await get("USDC")
  const ONE_CLICK_PROXY_ROLE = keccak256(toUtf8Bytes("ONE_CLICK_PROXY_ROLE"));

  const optionDataStorage = await deploy("OptionDataStorage", {
    from: deployer,
    log: true,
  })

  const OneClickProxy = await deploy("OneClickProxy", {
    from: deployer,
    log: true,
    args: [
      MarginTrading.address
    ],
  })

  await execute("OneClickProxy", { log: true, from: deployer }, "setOptionDataStorage", optionDataStorage.address)
  await execute("OneClickProxy", { log: true, from: deployer }, "approveERC721ForAll", HegicPositionsManager.address, MarginAccount.address, true)
  await execute("OneClickProxy", { log: true, from: deployer }, "approveERC20", WETH.address, MarginAccount.address, MaxUint256)
  await execute("OneClickProxy", { log: true, from: deployer }, "approveERC20", USDC.address, MarginAccount.address, MaxUint256)
  await execute("MarginTrading", { log: true, from: deployer }, "grantRole", ONE_CLICK_PROXY_ROLE, OneClickProxy.address)
  await execute("OptionDataStorage", { log: true, from: deployer }, "grantRole", ONE_CLICK_PROXY_ROLE, OneClickProxy.address)

}

deployment.tags = ["one_click_proxy"]
deployment.dependencies = ["margin_trading", "margin_account"]

export default deployment
