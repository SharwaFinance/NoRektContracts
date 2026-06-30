import {HardhatRuntimeEnvironment} from "hardhat/types"
import {solidityPacked, keccak256, toUtf8Bytes, MaxUint256, ZeroAddress} from "ethers"

async function deployment(hre: HardhatRuntimeEnvironment): Promise<void> {
  const {deployments, getNamedAccounts} = hre
  const { deploy, get, execute } = deployments
  const {deployer} = await getNamedAccounts()

  const MarginAccount = await get("MarginAccount")
  const HegicPositionsManager = await get("HegicPositionsManager")
  const ModularSwapRouter = await get("ModularSwapRouter")
  const OperationalTreasury = await get("OperationalTreasury")
  const USDCe = await get("USDCe")
  const USDC = await get("USDC")
  const DirectExchanger = await get("DirectExchanger")
  
  const MODULAR_SWAP_ROUTER_ROLE = keccak256(toUtf8Bytes("MODULAR_SWAP_ROUTER_ROLE"));

  const HegicModule = await deploy("HegicModule", {
    from: deployer,
    log: true,
    args: [
      USDCe.address,
      HegicPositionsManager.address,
      OperationalTreasury.address,
      DirectExchanger.address,
      MarginAccount.address,
      USDC.address
    ],
  })

  await execute(
    "HegicModule",
    {log: true, from: deployer},
    "allApprove"
  )

  await execute(
    "ModularSwapRouter",
    {log: true, from: deployer},
    "setTokenInToTokenOutToExchange",
    HegicPositionsManager.address,
    USDC.address,
    HegicModule.address
  )

  await execute(
    "HegicModule",
    {log: true, from: deployer},
    "grantRole",
    MODULAR_SWAP_ROUTER_ROLE,
    ModularSwapRouter.address
  )

  await execute(
    "MarginAccount",
    {log: true, from: deployer},
    "approveERC721ForAll",
    HegicPositionsManager.address, 
    HegicModule.address,
    true
  )

  const arrSrtrategies = [
    "0xaA0DfBFb8dA7f45BB41c0fB68B71FAEB959B22aa",
    "0x2739A4C003080A5B3Ade22b92c3321EDa2Da3A9e",
    "0xf711D0BC60F37cA28845BA623ccd9C635E5073A1",
    "0x015FAA9aF7599e6cea597EBC7e7e04A149a3E992",
    "0x6B7e5906F53d8bB365f4A6fA776Fd0f0caf57881",
    "0x3e2a0fE32Cc000d87D9e5D6ed8b3D64e9c74C752",
    "0x33a4B4403B8C6349371CbDf539138D78ec0Aab66",
    "0x3031EA515c2274024D93A8D3BfA91ce920E1192E"
  ]

  for (const strategy of arrSrtrategies) {
    await execute(
      "ModularSwapRouter",
      {log: true, from: deployer},
      "setAvailebleStrategy",
      strategy,
      true
    )
  }
  
}

deployment.tags = ["hegic_module"]
deployment.dependencies = ["preparation", "margin_account", "liquidity_pool", "modular_swap_router", "uniswap_module"]

export default deployment
