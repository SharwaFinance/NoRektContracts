import { keccak256, toUtf8Bytes } from "ethers"
import { HardhatRuntimeEnvironment } from "hardhat/types"

async function deployment(hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get, execute } = deployments
  const { deployer } = await getNamedAccounts()

  const MarginTrading = await get("MarginTrading")
  const OneClickLiquidation = await get("OneClickLiquidation")

  const LIQUIDATOR_ROLE = keccak256(toUtf8Bytes("LIQUIDATOR_ROLE"));

  const UpkeepOfLiquidations = await deploy("UpkeepOfLiquidations", {
    from: deployer,
    log: true,
    args: [
      MarginTrading.address,
      OneClickLiquidation.address
    ],
  })

  await execute(
    "OneClickLiquidation",
    { log: true, from: deployer },
    "grantRole",
    LIQUIDATOR_ROLE,
    UpkeepOfLiquidations.address
  )
}

deployment.tags = ["upkeep_liquidations"]
deployment.dependencies = ["margin_trading", "one_click"]

export default deployment
