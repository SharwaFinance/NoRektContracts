import { MaxInt256, parseUnits, ZeroAddress } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import {
    abi as FACTORY_ABI,
    bytecode as FACTORY_BYTECODE,
} from "@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json";

import {
    abi as UNISWAP_V3_POOL_ABI
} from "@uniswap/v3-core/artifacts/contracts/UniswapV3Pool.sol/UniswapV3Pool.json";

import {
    abi as SWAP_ROUTER_ABI,
    bytecode as SWAP_ROUTER_BYTECODE,
} from "@uniswap/v3-periphery/artifacts/contracts/SwapRouter.sol/SwapRouter.json";

import {
    abi as QUOTER_ABI,
    bytecode as QUOTER_BYTECODE,
} from "@uniswap/v3-periphery/artifacts/contracts/lens/Quoter.sol/Quoter.json";

import {
    abi as NONFUNGIBLE_POSITION_MANAGER_ABI,
    bytecode as NONFUNGIBLE_POSITION_MANAGER_BYTECODE,
} from "@uniswap/v3-periphery/artifacts/contracts/NonfungiblePositionManager.sol/NonfungiblePositionManager.json";

import { priceToSqrtPriceX96BigInt } from "../utils/uniswap";

async function deployment(hre: HardhatRuntimeEnvironment): Promise<void> {
    const { deployments, getNamedAccounts, network } = hre
    const { deploy, save, getArtifact, execute } = deployments
    const { deployer } = await getNamedAccounts()

    if (network.name == "hardhat") {
        const USDC = await deploy("USDC", {
            contract: "MockERC20",
            from: deployer,
            log: true,
            args: ["USDC (Mock)", "USDC", 6],
        })
        const USDCe = await deploy("USDCe", {
            contract: "MockERC20",
            from: deployer,
            log: true,
            args: ["USDCe (Mock)", "USDCe", 6],
        })
        const WETH = await deploy("WETH", {
            contract: "WETHMock",
            from: deployer,
            log: true,
            args: [],
        })
        const WBTC = await deploy("WBTC", {
            contract: "MockERC20",
            from: deployer,
            log: true,
            args: ["WBTC (Mock)", "WBTC", 8],
        })

        await execute("USDC", { log: true, from: deployer }, "mint", parseUnits("10", 6))
        await execute("WETH", { log: true, from: deployer }, "mint", parseUnits("0.01", 18))
        await execute("WBTC", { log: true, from: deployer }, "mint", parseUnits("0.001", 8))

        const AggregatorV3_WETH_USDC = await deploy("AggregatorV3_WETH_USDC", { contract: "MockAggregatorV3", from: deployer, log: true, args: [8, parseUnits("4000", 8)] })
        const AggregatorV3_WBTC_USDC = await deploy("AggregatorV3_WBTC_USDC", { contract: "MockAggregatorV3", from: deployer, log: true, args: [8, parseUnits("60000", 8)] })

        await deploy("SequencerUptimeFeed", { contract: "MockAggregatorV3", from: deployer, log: true, args: [0, 0] })

        const MockHegicStrategy = await deploy("MockHegicStrategy", {
            contract: "MockHegicStrategy",
            from: deployer,
            log: true,
            args: [
                AggregatorV3_WETH_USDC.address
            ],
        })

        const OperationalTreasury = await deploy("OperationalTreasury", {
            contract: "MockOperationalTreasury",
            from: deployer,
            log: true,
            args: [
                MockHegicStrategy.address,
                USDCe.address
            ],
        })

        const HegicPositionsManager = await deploy("HegicPositionsManager", {
            contract: "MockPositionsManager",
            from: deployer,
            log: true,
            args: [],
        })

        await deploy("DirectExchanger", {
            from: deployer,
            log: true,
            args: [
                USDC.address,
                USDCe.address
            ],
        })

        await deploy("IProxySeller", {
            contract: "IProxySellerMock",
            from: deployer,
            log: true,
            args: [
                USDCe.address,
                OperationalTreasury.address,
                HegicPositionsManager.address
            ],
        })

        const factory = await deploy("UniswapV3Factory", {
            from: deployer,
            log: true,
            contract: {
                abi: FACTORY_ABI,
                bytecode: FACTORY_BYTECODE,
            },
        });

        const nonfungible_position_manager = await deploy("NonfungiblePositionManager", {
            from: deployer,
            log: true,
            contract: {
                abi: NONFUNGIBLE_POSITION_MANAGER_ABI,
                bytecode: NONFUNGIBLE_POSITION_MANAGER_BYTECODE,
            },
            args: [factory.address, WETH.address, ZeroAddress],
        });

        await deploy("Quoter", {
            from: deployer,
            log: true,
            contract: {
                abi: QUOTER_ABI,
                bytecode: QUOTER_BYTECODE,
            },
            args: [factory.address, WETH.address],
        });

        await deploy("SwapRouter", {
            from: deployer,
            log: true,
            contract: {
                abi: SWAP_ROUTER_ABI,
                bytecode: SWAP_ROUTER_BYTECODE,
            },
            args: [factory.address, WETH.address],
        });

        await execute("UniswapV3Factory", { log: true, from: deployer }, "createPool", WETH.address, USDC.address, 500)
        await execute("UniswapV3Factory", { log: true, from: deployer }, "createPool", WBTC.address, USDC.address, 500)
        await execute("UniswapV3Factory", { log: true, from: deployer }, "createPool", WBTC.address, WETH.address, 500)
        await execute("UniswapV3Factory", { log: true, from: deployer }, "createPool", USDC.address, USDCe.address, 500)
        await execute("UniswapV3Factory", { log: true, from: deployer }, "createPool", WETH.address, USDCe.address, 500)

        const factory_contract = await hre.ethers.getContractAt(FACTORY_ABI, factory.address)
        const nonfungible_position_manager_contract = await hre.ethers.getContractAt(NONFUNGIBLE_POSITION_MANAGER_ABI, nonfungible_position_manager.address)
        const SCALE = 10n ** 18n;

        // WETH USDC pool
        const usdcAmount0 = parseUnits("1000000", 6) * 1000000n
        const wethAmount = parseUnits("250", 18) * 1000000n

        await execute("USDC", { log: true, from: deployer }, "mint", usdcAmount0)
        await execute("WETH", { log: true, from: deployer }, "mint", wethAmount)

        const isUsdcToken0 = USDC.address.toLowerCase() < WETH.address.toLowerCase()

        const weth_usdc_params = {
            token0: isUsdcToken0 ? USDC.address : WETH.address,
            token1: isUsdcToken0 ? WETH.address : USDC.address,
            fee: 500,
            tickLower: -887220,
            tickUpper: 887220,
            amount0Desired: isUsdcToken0 ? usdcAmount0 : wethAmount,
            amount1Desired: isUsdcToken0 ? wethAmount : usdcAmount0,
            amount0Min: 0,
            amount1Min: 0,
            recipient: deployer,
            // deadline: Math.floor(Date.now() / 1000) + 60 * 10,
            deadline: MaxInt256,
        };

        const weth_usdc_pool = await hre.ethers.getContractAt(UNISWAP_V3_POOL_ABI, await factory_contract.getPool(WETH.address, USDC.address, 500))
        const weth_usdc_price = priceToSqrtPriceX96BigInt(parseUnits("1", 18) * SCALE / parseUnits("4000", 6))
        await weth_usdc_pool.initialize(weth_usdc_price)

        await execute("WETH", { log: true, from: deployer }, "approve", await nonfungible_position_manager_contract.getAddress(), wethAmount)
        await execute("USDC", { log: true, from: deployer }, "approve", await nonfungible_position_manager_contract.getAddress(), usdcAmount0)
        await nonfungible_position_manager_contract.mint(weth_usdc_params)

        // WBTC USDC pool
        // Mint enough tokens for WBTC/USDC pool

        const isUsdcToken1 = USDC.address.toLowerCase() < WBTC.address.toLowerCase()
        const usdcAmount1 = parseUnits("1000000", 6) * 1000000n
        const wbtcAmount = parseUnits("16.6", 8) * 1000000n

        await execute("WBTC", { log: true, from: deployer }, "mint", wbtcAmount)
        await execute("USDC", { log: true, from: deployer }, "mint", usdcAmount1)

        const wbtc_usdc_params = {
            token0: isUsdcToken1 ? USDC.address : WBTC.address,
            token1: isUsdcToken1 ? WBTC.address : USDC.address,
            fee: 500,
            tickLower: -887220,
            tickUpper: 887220,
            amount0Desired: isUsdcToken1 ? usdcAmount1 : wbtcAmount,
            amount1Desired: isUsdcToken1 ? wbtcAmount : usdcAmount1,
            amount0Min: 0,
            amount1Min: 0,
            recipient: deployer,
            deadline: MaxInt256,
            // deadline: Math.floor(Date.now() / 1000) + 60 * 10,
        };

        const wbtc_usdc_pool = await hre.ethers.getContractAt(
            UNISWAP_V3_POOL_ABI,
            await factory_contract.getPool(WBTC.address, USDC.address, 500)
        )
        const wbtc_usdc_price = priceToSqrtPriceX96BigInt(parseUnits("1", 8) * SCALE / parseUnits("60000", 6))
        await wbtc_usdc_pool.initialize(wbtc_usdc_price)

        await execute("WBTC", { log: true, from: deployer }, "approve", await nonfungible_position_manager_contract.getAddress(), wbtcAmount)
        await execute("USDC", { log: true, from: deployer }, "approve", await nonfungible_position_manager_contract.getAddress(), usdcAmount1)
        await nonfungible_position_manager_contract.mint(wbtc_usdc_params)

        // WBTC WETH pool
        // Mint required tokens for WBTC/WETH pool

        const isWethToken1 = WETH.address.toLowerCase() < WBTC.address.toLowerCase()
        const wethAmount2 = parseUnits("250", 18) * 1000000n
        const wbtcAmount2 = parseUnits("16.6", 8) * 1000000n

        await execute("WBTC", { log: true, from: deployer }, "mint", wbtcAmount2)
        await execute("WETH", { log: true, from: deployer }, "mint", wethAmount2)

        const wbtc_weth_params = {
            token0: isWethToken1 ? WETH.address : WBTC.address,
            token1: isWethToken1 ? WBTC.address : WETH.address,
            fee: 500,
            tickLower: -887220,
            tickUpper: 887220,
            amount0Desired: isWethToken1 ? wethAmount2 : wbtcAmount2,
            amount1Desired: isWethToken1 ? wbtcAmount2 : wethAmount2,
            amount0Min: 0,
            amount1Min: 0,
            recipient: deployer,
            deadline: MaxInt256,
            // deadline: Math.floor(Date.now() / 1000) + 60 * 10,
        };

        const wbtc_weth_pool = await hre.ethers.getContractAt(
            UNISWAP_V3_POOL_ABI,
            await factory_contract.getPool(WBTC.address, WETH.address, 500)
        );
        const wbtc_weth_price = priceToSqrtPriceX96BigInt(parseUnits("0.0666", 8) * SCALE / parseUnits("1", 18))
        await wbtc_weth_pool.initialize(wbtc_weth_price);

        await execute("WBTC", { log: true, from: deployer }, "approve", await nonfungible_position_manager_contract.getAddress(), wbtcAmount2)
        await execute("WETH", { log: true, from: deployer }, "approve", await nonfungible_position_manager_contract.getAddress(), wethAmount2)
        await nonfungible_position_manager_contract.mint(wbtc_weth_params)


        // USDCe USDC pool
        const isUsdcToken2 = USDC.address.toLowerCase() < USDCe.address.toLowerCase()
        const usdcAmount2 = parseUnits("1000000", 6) * 1000000n
        const usdceAmount = parseUnits("1000000", 6) * 1000000n

        await execute("USDCe", { log: true, from: deployer }, "mint", usdceAmount)
        await execute("USDC", { log: true, from: deployer }, "mint", usdcAmount2)

        const usdce_usdc_params = {
            token0: isUsdcToken2 ? USDC.address : USDCe.address,
            token1: isUsdcToken2 ? USDCe.address : USDC.address,
            fee: 500,
            tickLower: -887220,
            tickUpper: 887220,
            amount0Desired: isUsdcToken2 ? usdcAmount2 : usdceAmount,
            amount1Desired: isUsdcToken2 ? usdceAmount : usdcAmount2,
            amount0Min: 0,
            amount1Min: 0,
            recipient: deployer,
            deadline: MaxInt256,
            // deadline: Math.floor(Date.now() / 1000) + 60 * 10,
        };

        const usdce_usdc_pool = await hre.ethers.getContractAt(
            UNISWAP_V3_POOL_ABI,
            await factory_contract.getPool(USDC.address, USDCe.address, 500)
        )

        const usdce_usdc_price = priceToSqrtPriceX96BigInt(parseUnits("1", 6) * SCALE / parseUnits("1", 6))
        await usdce_usdc_pool.initialize(usdce_usdc_price)

        await execute("USDCe", { log: true, from: deployer }, "approve", await nonfungible_position_manager_contract.getAddress(), usdceAmount)
        await execute("USDC", { log: true, from: deployer }, "approve", await nonfungible_position_manager_contract.getAddress(), usdcAmount2)
        await nonfungible_position_manager_contract.mint(usdce_usdc_params)

        const isWethToken3 = WETH.address.toLowerCase() < USDCe.address.toLowerCase()
        const wethAmount3 = parseUnits("2500", 18) * 1000000n
        const usdceAmount3 = parseUnits("10000000", 6) * 1000000n

        await execute("WETH", { log: true, from: deployer }, "mint", wethAmount3)
        await execute("USDCe", { log: true, from: deployer }, "mint", usdceAmount3)

        const weth_usdce_params = {
            token0: isWethToken3 ? WETH.address : USDCe.address,
            token1: isWethToken3 ? USDCe.address : WETH.address,
            fee: 500,
            tickLower: -887220,
            tickUpper: 887220,
            amount0Desired: isWethToken3 ? wethAmount3 : usdceAmount3,
            amount1Desired: isWethToken3 ? usdceAmount3 : wethAmount3,
            amount0Min: 0,
            amount1Min: 0,
            recipient: deployer,
            deadline: MaxInt256,
        };

        const weth_usdce_pool = await hre.ethers.getContractAt(
            UNISWAP_V3_POOL_ABI,
            await factory_contract.getPool(WETH.address, USDCe.address, 500)
        )
        const weth_usdce_price = priceToSqrtPriceX96BigInt(parseUnits("1", 18) * SCALE / parseUnits("4000", 6))
        await weth_usdce_pool.initialize(weth_usdce_price)

        await execute("WETH", { log: true, from: deployer }, "approve", await nonfungible_position_manager_contract.getAddress(), wethAmount3)
        await execute("USDCe", { log: true, from: deployer }, "approve", await nonfungible_position_manager_contract.getAddress(), usdceAmount3)
        await nonfungible_position_manager_contract.mint(weth_usdce_params)


    } else {
        save("USDCe", {
            address: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
            abi: await getArtifact("@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20").then((x) => x.abi),
        })

        save("USDC", {
            address: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831",
            abi: await getArtifact("@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20").then((x) => x.abi),
        })

        save("WETH", {
            address: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
            abi: await getArtifact("@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20").then((x) => x.abi),
        })

        save("WBTC", {
            address: "0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f",
            abi: await getArtifact("@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20").then((x) => x.abi),
        })

        save("Quoter", {
            address: "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6",
            abi: await getArtifact("contracts/interfaces/modularSwapRouter/uniswap/IQuoter.sol:IQuoter").then((x) => x.abi),
        })

        save("SwapRouter", {
            address: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
            abi: await getArtifact("@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol:ISwapRouter").then((x) => x.abi),
        })

        save("OperationalTreasury", {
            address: "0xec096ea6eB9aa5ea689b0CF00882366E92377371",
            abi: await getArtifact("contracts/interfaces/modularSwapRouter/hegic/IOperationalTreasury.sol:IOperationalTreasury").then((x) => x.abi),
        })

        save("HegicPositionsManager", {
            address: "0x5Fe380D68fEe022d8acd42dc4D36FbfB249a76d5",
            abi: await getArtifact("contracts/interfaces/modularSwapRouter/hegic/IPositionsManager.sol:IPositionsManager").then((x) => x.abi),
        })

        save("AggregatorV3_WETH_USDC", {
            address: "0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612",
            abi: await getArtifact("@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol:AggregatorV3Interface").then((x) => x.abi),
        })

        save("AggregatorV3_WBTC_USDC", {
            address: "0x6ce185860a4963106506C203335A2910413708e9",
            abi: await getArtifact("@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol:AggregatorV3Interface").then((x) => x.abi),
        })

        save("SequencerUptimeFeed", {
            address: "0xFdB631F5EE196F0ed6FAa767959853A9F217697D",
            abi: await getArtifact("@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol:AggregatorV2V3Interface").then((x) => x.abi),
        })

        save("IProxySeller", {
            address: "0x7740FC99bcaE3763a5641e450357a94936eaF380",
            abi: await getArtifact("contracts/interfaces/oneClick/IProxySeller.sol:IProxySeller").then((x) => x.abi),
        })

        save("DirectExchanger", {
            address: "0xD3ECA2F3cEEE8f68075b2cA613FbA7D75Fb95e8f",
            abi: await getArtifact("contracts/interfaces/modularSwapRouter/hegic/IWrapper.sol:IWrapper").then((x) => x.abi),
        })
    }
}

deployment.tags = ["preparation"]
export default deployment
