import { MaxUint256 } from "ethers"
import { HardhatRuntimeEnvironment } from "hardhat/types"

async function deployment(hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get, execute } = deployments
  const { deployer } = await getNamedAccounts()
  const MarginAccount = await get("MarginAccount")
  const USDC = await get("USDC")
  const WETH = await get("WETH")

  const WETHeph = await deploy("WETHeph", {
    contract: "EphemeralERC20Type1",
    from: deployer,
    log: true,
    args: [
      "WETHeph",
      "WETHeph",
      18
    ],
  })

  const USDCeph = await deploy("USDCeph", {
    contract: "EphemeralERC20Type1",
    from: deployer,
    log: true,
    args: [
      "USDCeph",
      "USDCeph",
      6
    ],
  })

  await execute("OneClickProxy", { log: true, from: deployer }, "approveERC20", WETHeph.address, MarginAccount.address, MaxUint256)
  await execute("OneClickProxy", { log: true, from: deployer }, "approveERC20", USDCeph.address, MarginAccount.address, MaxUint256)

  await execute(
    "MarginAccount",
    { log: true, from: deployer },
    "setAvailableErc20",
    [USDC.address, WETH.address, WETHeph.address, USDCeph.address], //_availableErc20
  )
}

deployment.tags = ["one_click_ephemeral_tokens"]
deployment.dependencies = ["one_click_proxy", "margin_account", "margin_trading"]

export default deployment
