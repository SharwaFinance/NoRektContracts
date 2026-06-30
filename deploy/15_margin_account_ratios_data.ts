import {HardhatRuntimeEnvironment} from "hardhat/types"

async function deployment(hre: HardhatRuntimeEnvironment): Promise<void> {
  const {deployments, getNamedAccounts} = hre
  const { deploy, get, execute } = deployments
  const {deployer} = await getNamedAccounts()

  const MarginTrading = await get("MarginTrading")

  await deploy("MarginAccountsRatiosData", {
      from: deployer,
      log: true,
      args: [
        MarginTrading.address
      ],
    })
}

deployment.tags = ["margin_accounts_ratios_data"]

export default deployment
