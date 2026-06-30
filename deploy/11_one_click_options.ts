import { keccak256, MaxUint256, toUtf8Bytes } from "ethers"
import { HardhatRuntimeEnvironment } from "hardhat/types"

async function deployment(hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get, execute } = deployments
  const { deployer } = await getNamedAccounts()

  const MarginAccountManager = await get("MarginAccountManager")
  const HegicPositionsManager = await get("HegicPositionsManager")
  const IProxySeller = await get("IProxySeller")
  const MarginAccount = await get("MarginAccount")
  const SwapRouter = await get("SwapRouter")
  const Quoter = await get("Quoter")
  const HegicModule = await get("HegicModule")
  const USDCe = await get("USDCe")
  const WETH = await get("WETH")
  const USDC = await get("USDC")
  const WBTC = await get("WBTC")
  const MODULAR_SWAP_ROUTER_ROLE = keccak256(toUtf8Bytes("MODULAR_SWAP_ROUTER_ROLE"));
  const OneClickProxy = await get("OneClickProxy")
  const OneClickEphemeralSwapOutput = await get("OneClickEphemeralSwapOutput")
  const DirectExchanger = await get("DirectExchanger")

  const FACADE_ROLE = keccak256(toUtf8Bytes("FACADE_ROLE"));
  const MANAGER_ROLE = keccak256(toUtf8Bytes("MANAGER_ROLE"));

  const referrer = "0x868872CFe737185B89F4fB07A051F4bDAB9Eb5C7"

  const OneClickNoRekt = await deploy("OneClickNoRekt", {
    from: deployer,
    log: true,
    args: [
      OneClickProxy.address,
      MarginAccount.address,
      MarginAccountManager.address,
      OneClickEphemeralSwapOutput.address,
      HegicPositionsManager.address,
      WETH.address
    ],
  })

  await execute("OneClickProxy", { log: true, from: deployer }, "grantRole", FACADE_ROLE, OneClickNoRekt.address)
  await execute("OneClickEphemeralSwapOutput", { log: true, from: deployer }, "grantRole", FACADE_ROLE, OneClickNoRekt.address)

  const OneClickOptions = await deploy("OneClickOptions", {
    from: deployer,
    log: true,
    args: [
      MarginAccountManager.address,
      OneClickProxy.address,
      HegicPositionsManager.address,
      IProxySeller.address,
      MarginAccount.address,
      HegicModule.address,
      USDCe.address,
      referrer,
      WETH.address,
      USDC.address,
      DirectExchanger.address
    ],
  })

  await execute("OneClickOptions", { log: true, from: deployer }, "approveERC721ForAll", HegicPositionsManager.address, OneClickProxy.address, true)
  await execute("OneClickOptions", { log: true, from: deployer }, "approveERC20", USDC.address, DirectExchanger.address, MaxUint256)
  await execute("OneClickOptions", { log: true, from: deployer }, "approveERC20", USDCe.address, IProxySeller.address, MaxUint256)
  await execute("OneClickProxy", { log: true, from: deployer }, "grantRole", FACADE_ROLE, OneClickOptions.address)

  let contractsMap = new Map<string, string>([
    ["WETH", WETH.address],
    ["WBTC", WBTC.address],
    ["USDC", USDC.address],
  ]);

  const arrayParams = [
    { "tokenIn": "USDC", "poolFee": 500, "tokenOut": "WETH" },
    { "tokenIn": "USDC", "poolFee": 500, "tokenOut": "WBTC" },
    { "tokenIn": "USDC", "poolFee": 500, "tokenOut": "USDC" },
  ]

  async function deployUniswapModule(tokenIn: string, poolFee: number, tokenOut: string) {
    const contractName = `${tokenIn}_${tokenOut}_UniswapModuleWithOneClick`

    let args = [
      OneClickOptions.address,
      contractsMap.get(tokenIn),
      poolFee,
      contractsMap.get(tokenOut),
      SwapRouter.address,
      Quoter.address
    ]

    const module = await deploy(contractName, {
      contract: "UniswapModuleWithOneClick",
      from: deployer,
      log: true,
      args: args,
    })

    await execute(
      contractName,
      { log: true, from: deployer },
      "grantRole",
      MODULAR_SWAP_ROUTER_ROLE,
      OneClickOptions.address
    )

    await execute(
      contractName,
      { log: true, from: deployer },
      "grantRole",
      MANAGER_ROLE,
      deployer
    )

    await execute(
      "OneClickOptions",
      { log: true, from: deployer },
      "setUniswapExchangeModules",
      contractsMap.get(tokenIn),
      contractsMap.get(tokenOut),
      module.address
    )

    await execute(
      "OneClickOptions",
      { log: true, from: deployer },
      "approveERC20",
      contractsMap.get(tokenOut),
      module.address,
      MaxUint256
    )

    await execute(
      "OneClickOptions",
      { log: true, from: deployer },
      "approveERC20",
      contractsMap.get(tokenIn),
      IProxySeller.address,
      MaxUint256
    )

    await execute(
      contractName,
      { log: true, from: deployer },
      "allApprove"
    )

  }

  for (let item in arrayParams) {
    await deployUniswapModule(arrayParams[item].tokenIn, arrayParams[item].poolFee, arrayParams[item].tokenOut)
  }
}

deployment.tags = ["one_click_options"]
deployment.dependencies = ["one_click_ephemeral_tokens", "one_click_proxy"]

export default deployment
