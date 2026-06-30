import { HardhatRuntimeEnvironment } from "hardhat/types"

async function deployment(hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get, execute } = deployments
  const { deployer } = await getNamedAccounts()

  const MarginAccountManager = await get("MarginAccountManager")

  await deploy("LendingMarginAccountManager", {
    from: deployer,
    log: true,
    args: [
      MarginAccountManager.address
    ],
  })
}

deployment.tags = ["lending_margin_account_manager"]
deployment.dependencies = ["margin_account_manager"]

export default deployment
