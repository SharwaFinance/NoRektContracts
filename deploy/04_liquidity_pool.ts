import { keccak256, MaxUint256, parseUnits, toUtf8Bytes } from "ethers";
import { ethers } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";

async function deployment(hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts, network } = hre
  const { deploy, get, execute } = deployments
  const { deployer } = await getNamedAccounts()
  const signers = await ethers.getSigners()

  let insurancePool: string
  if (network.name == "hardhat") {
    insurancePool = await signers[5].getAddress()
  } else {
    insurancePool = "0xEE1c5a8c397F4D6BBC33BAd080e77D531C6d8Ce5"
  }

  const WETH = await get("WETH")
  const USDC = await get("USDC")
  const MarginAccount = await get("MarginAccount")
  const MANAGER_ROLE = keccak256(toUtf8Bytes("MANAGER_ROLE"));

  const WETH_LiquidityPool = await deploy("WETH_LiquidityPool", {
    contract: "LiquidityPool",
    from: deployer,
    log: true,
    args: [
      insurancePool,
      MarginAccount.address,
      USDC.address,
      WETH.address,
      'SF-LP-WETH',
      'SF-LP-WETH',
      parseUnits("37", 18)
    ],
  })

  await execute(
    "WETH_LiquidityPool",
    { log: true, from: deployer },
    "grantRole",
    MANAGER_ROLE,
    deployer
  )

  await execute(
    "WETH_LiquidityPool",
    { log: true, from: deployer },
    "setInterestRate",
    0.047 * 1e4
  )

  const USDC_LiquidityPool = await deploy("USDC_LiquidityPool", {
    contract: "LiquidityPool",
    from: deployer,
    log: true,
    args: [
      insurancePool,
      MarginAccount.address,
      USDC.address,
      USDC.address,
      'SF-LP-USDC',
      'SF-LP-USDC',
      parseUnits("100000", 6)
    ],
  })

  await execute(
    "USDC_LiquidityPool",
    { log: true, from: deployer },
    "grantRole",
    MANAGER_ROLE,
    deployer
  )

  await execute(
    "USDC_LiquidityPool",
    { log: true, from: deployer },
    "setInterestRate",
    0.11 * 1e4
  )

  await execute(
    "MarginAccount",
    { log: true, from: deployer },
    "setAvailableTokenToLiquidityPool",
    [WETH.address, USDC.address]
  )

  await execute(
    "MarginAccount",
    { log: true, from: deployer },
    "setTokenToLiquidityPool",
    WETH.address,
    WETH_LiquidityPool.address
  )

  await execute(
    "MarginAccount",
    { log: true, from: deployer },
    "approveERC20",
    WETH.address,
    WETH_LiquidityPool.address,
    MaxUint256
  )

  await execute(
    "MarginAccount",
    { log: true, from: deployer },
    "setTokenToLiquidityPool",
    USDC.address,
    USDC_LiquidityPool.address
  )

  await execute(
    "MarginAccount",
    { log: true, from: deployer },
    "approveERC20",
    USDC.address,
    USDC_LiquidityPool.address,
    MaxUint256
  )

}

deployment.tags = ["liquidity_pool"]
deployment.dependencies = ["preparation", "margin_account"]

export default deployment
