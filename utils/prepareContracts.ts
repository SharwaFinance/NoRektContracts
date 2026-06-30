import {Contract, Signer, keccak256, parseUnits, toUtf8Bytes } from "ethers";
import { deployments, ethers } from "hardhat";
import {
    DirectExchanger,
    HegicModule,
    HegicTakeProfit,
    IQuoter,
    ISwapRouter,
    IUniswapV3Factory,
    LendingMarginAccountManager,
    LiquidityPool,
    MarginAccount,
    MarginAccountManager,
    MarginTrading,
    MarginTradingRouter,
    MockAggregatorV3,
    MockERC20,
    MockHegicStrategy,
    MockOperationalTreasury,
    MockPositionsManager,
    ModularSwapRouter,
    NonfungiblePositionManager,
    OneClickLiquidation,
    OneClickLiquidityPool,
    OneClickLiquidityPoolRouter,
    OneClickNoRekt,
    OneClickOptions,
    OneClickProxy,
    OneClickTrading,
    UniswapModuleWithChainlink,
} from "../typechain-types";

import {
    abi as UNISWAP_V3_POOL_ABI
} from "@uniswap/v3-core/artifacts/contracts/UniswapV3Pool.sol/UniswapV3Pool.json";



export interface PreparationResult {
    WETH_LiquidityPool: LiquidityPool;
    USDC_LiquidityPool: LiquidityPool;
    MarginTrading: MarginTrading;
    MarginAccount: MarginAccount;
    MockOperationalTreasury: MockOperationalTreasury;
    MockHegicStrategy: MockHegicStrategy;
    HegicPositionsManager: MockPositionsManager;
    LendingMarginAccountManager: LendingMarginAccountManager;
    MarginAccountManager: MarginAccountManager;
    SwapRouter: ISwapRouter;
    ModularSwapRouter: ModularSwapRouter;
    UniswapModule_WETH_USDC: UniswapModuleWithChainlink;
    Quoter: IQuoter;
    AggregatorV3_WETH_USDC: MockAggregatorV3;
    USDC: MockERC20;
    USDCe: MockERC20;
    WETH: MockERC20;
    signers: Signer[];
    deployer: Signer;
    insurance: Signer;
    OneClickLiquidityPool: OneClickLiquidityPool;
    OneClickLiquidityPoolRouter: OneClickLiquidityPoolRouter;
    OneClickOptions: OneClickOptions;
    OneClickNoRekt: OneClickNoRekt,
    OneClickProxy: OneClickProxy;
    OneClickTrading: OneClickTrading;
    OneClickLiquidation: OneClickLiquidation;
    MarginTradingRouter: MarginTradingRouter;
    HegicTakeProfit: HegicTakeProfit;
    Factory: IUniswapV3Factory;
    WETH_USDC_Pool: Contract;
    nonfungiblePositionManager: NonfungiblePositionManager;
}

export async function prepareContracts(): Promise<PreparationResult> {
    let WETH_LiquidityPool: LiquidityPool
    let USDC_LiquidityPool: LiquidityPool
    let MarginTrading: MarginTrading
    let MarginAccount: MarginAccount
    let MockOperationalTreasury: MockOperationalTreasury
    let MockHegicStrategy: MockHegicStrategy
    let HegicPositionsManager: MockPositionsManager
    let LendingMarginAccountManager: LendingMarginAccountManager
    let MarginAccountManager: MarginAccountManager
    let SwapRouter: ISwapRouter
    let ModularSwapRouter: ModularSwapRouter
    let UniswapModule_WETH_USDC: UniswapModuleWithChainlink
    let Quoter: IQuoter
    let AggregatorV3_WETH_USDC: MockAggregatorV3;
    let USDC: MockERC20
    let USDCe: MockERC20
    let WETH: MockERC20
    let signers: Signer[]
    let deployer: Signer
    let insurance: Signer
    let OneClickLiquidityPool: OneClickLiquidityPool
    let OneClickLiquidityPoolRouter: OneClickLiquidityPoolRouter
    let OneClickOptions: OneClickOptions
    let OneClickNoRekt: OneClickNoRekt
    let OneClickProxy: OneClickProxy
    let OneClickTrading: OneClickTrading
    let OneClickLiquidation: OneClickLiquidation
    let MarginTradingRouter: MarginTradingRouter
    let HegicTakeProfit: HegicTakeProfit
    let Factory: IUniswapV3Factory
    let WETH_USDC_Pool: Contract
    let nonfungiblePositionManager: NonfungiblePositionManager
    let DirectExchanger: DirectExchanger
    let HegicModule: HegicModule

    await deployments.fixture(["swap_output_module"])
    MarginTrading = await ethers.getContract("MarginTrading")
    MarginAccount = await ethers.getContract("MarginAccount")
    LendingMarginAccountManager = await ethers.getContract("LendingMarginAccountManager")
    MarginAccountManager = await ethers.getContract("MarginAccountManager")
    ModularSwapRouter = await ethers.getContract("ModularSwapRouter")
    UniswapModule_WETH_USDC = await ethers.getContract("WETH_USDC_UniswapModule")
    Quoter = await ethers.getContract("Quoter")
    AggregatorV3_WETH_USDC = await ethers.getContract("AggregatorV3_WETH_USDC")
    OneClickLiquidityPool = await ethers.getContract("OneClickLiquidityPool")
    OneClickLiquidityPoolRouter = await ethers.getContract("OneClickLiquidityPoolRouter")
    OneClickOptions = await ethers.getContract("OneClickOptions")
    OneClickProxy = await ethers.getContract("OneClickProxy")
    OneClickNoRekt = await ethers.getContract("OneClickNoRekt")
    OneClickTrading = await ethers.getContract("OneClickTrading")
    USDC = await ethers.getContract("USDC")
    USDCe = await ethers.getContract("USDCe")
    WETH = await ethers.getContract("WETH")
    signers = await ethers.getSigners()
    deployer = signers[0]
    insurance = signers[5]
    OneClickLiquidation = await ethers.getContract("OneClickLiquidation")
    MarginTradingRouter = await ethers.getContract("MarginTradingRouter")
    HegicTakeProfit = await ethers.getContract("HegicTakeProfit")
    DirectExchanger = await ethers.getContract("DirectExchanger")
    HegicModule = await ethers.getContract("HegicModule")

    await MarginTrading.setRedCoeff(parseUnits("1.05", 5));
    await OneClickProxy.setYellowCoeff(parseUnits("1.10", 5));

    await MarginAccount.setLiquidatorFee(0.05 * 1e5)

    const WETH9 = await ethers.getContractAt("IWETH9", await WETH.getAddress())

    await WETH9.deposit({ value: parseUnits("20", 18) })

    // mint tokens //
    let WETHmintAmount = parseUnits("100", await WETH.decimals())
    await WETH.connect(deployer).mint(WETHmintAmount)
    await WETH.connect(deployer).approve(await MarginAccount.getAddress(), WETHmintAmount)

    let USDCmintAmount = parseUnits("100000", await USDC.decimals())
    await USDC.connect(deployer).mint(USDCmintAmount)
    await USDC.connect(deployer).approve(await MarginAccount.getAddress(), USDCmintAmount)

    // prepare insurancePool // 

    WETHmintAmount = WETHmintAmount * BigInt(10)
    USDCmintAmount = USDCmintAmount * BigInt(10)

    await WETH.connect(insurance).mint(WETHmintAmount)
    await WETH.connect(insurance).approve(await MarginAccount.getAddress(), WETHmintAmount)

    await USDC.connect(insurance).mint(USDCmintAmount)
    await USDC.connect(insurance).approve(await MarginAccount.getAddress(), USDCmintAmount)

    // prepare SwapRouter // 

    SwapRouter = await ethers.getContract("SwapRouter")
    // await WETH.connect(deployer).mintTo(await SwapRouterMock.getAddress(), WETHmintAmount * BigInt(100000000000000000000))
    // await WBTC.connect(deployer).mintTo(await SwapRouterMock.getAddress(), WBTCmintAmount * BigInt(100000000000000000000))
    // await USDC.connect(deployer).mintTo(await SwapRouterMock.getAddress(), USDCmintAmount * BigInt(100000000000000000000))
    // await USDCe.connect(deployer).mintTo(await SwapRouterMock.getAddress(), USDCmintAmount * BigInt(100000000000000000000))

    // prepare pools //

    WETH_LiquidityPool = await ethers.getContract("WETH_LiquidityPool")
    USDC_LiquidityPool = await ethers.getContract("USDC_LiquidityPool")

    await WETH_LiquidityPool.setMaximumPoolCapacity(WETHmintAmount * BigInt(1000000))
    await USDC_LiquidityPool.setMaximumPoolCapacity(USDCmintAmount * BigInt(1000000))

    await WETH.connect(deployer).mint(WETHmintAmount)
    await USDC.connect(deployer).mint(USDCmintAmount)

    await WETH.connect(deployer).approve(await WETH_LiquidityPool.getAddress(), WETHmintAmount)
    await USDC.connect(deployer).approve(await USDC_LiquidityPool.getAddress(), USDCmintAmount)

    await WETH_LiquidityPool.connect(deployer).provide(WETHmintAmount)
    await USDC_LiquidityPool.connect(deployer).provide(USDCmintAmount)

    // prepare hegic //

    MockHegicStrategy = await ethers.getContract("MockHegicStrategy")
    MockOperationalTreasury = await ethers.getContract("OperationalTreasury")
    HegicPositionsManager = await ethers.getContract("HegicPositionsManager")

    await ModularSwapRouter.setAvailebleStrategy(MockHegicStrategy, true)

    await USDCe.connect(deployer).mintTo(await MockOperationalTreasury.getAddress(), WETHmintAmount * BigInt(10))

    const optionProfit = parseUnits("100", await USDCe.decimals())
    const oneWeek = 60 * 60 * 24 * 7
    const optionId = 0

    await HegicPositionsManager.connect(deployer).mint(await deployer.getAddress())
    await MockHegicStrategy.setPayOffAmount(optionId, optionProfit)
    await MockOperationalTreasury.setLockedLiquidity(optionId, oneWeek, 1)

    // prepare exchanger

    let USDCAmount = parseUnits("100000", await USDC.decimals())
    await USDC.connect(deployer).mintTo(await DirectExchanger.getAddress(), USDCAmount)

    let USDCeAmount = parseUnits("100000", await USDC.decimals())
    await USDCe.connect(deployer).mintTo(await DirectExchanger.getAddress(), USDCeAmount)

    const ACCEPTED_USER_ROLE = keccak256(toUtf8Bytes("ACCEPTED_USER_ROLE"));
    await DirectExchanger.connect(deployer).grantRole(ACCEPTED_USER_ROLE, await HegicModule.getAddress())
    await DirectExchanger.connect(deployer).grantRole(ACCEPTED_USER_ROLE, await OneClickOptions.getAddress())
    await OneClickOptions.connect(deployer).approveERC20(await USDC.getAddress(), await DirectExchanger.getAddress(), ethers.MaxUint256)


    // user approve
    await HegicPositionsManager.connect(deployer).approve(await MarginAccount.getAddress(), optionId)

    Factory = await ethers.getContract("UniswapV3Factory")
    WETH_USDC_Pool = await ethers.getContractAt(UNISWAP_V3_POOL_ABI, await Factory.getPool(await WETH.getAddress(), await USDC.getAddress(), 500))
    nonfungiblePositionManager = await ethers.getContract("NonfungiblePositionManager")

    return {
        WETH_LiquidityPool: WETH_LiquidityPool,
        USDC_LiquidityPool: USDC_LiquidityPool,
        MarginTrading: MarginTrading,
        MarginAccount: MarginAccount,
        MockOperationalTreasury: MockOperationalTreasury,
        MockHegicStrategy: MockHegicStrategy,
        HegicPositionsManager: HegicPositionsManager,
        LendingMarginAccountManager: LendingMarginAccountManager,
        MarginAccountManager: MarginAccountManager,
        SwapRouter: SwapRouter,
        ModularSwapRouter: ModularSwapRouter,
        UniswapModule_WETH_USDC: UniswapModule_WETH_USDC,
        Quoter: Quoter,
        AggregatorV3_WETH_USDC: AggregatorV3_WETH_USDC,
        USDC: USDC,
        USDCe: USDCe,
        WETH: WETH,
        signers: signers,
        deployer: deployer,
        insurance: insurance,
        OneClickLiquidityPool: OneClickLiquidityPool,
        OneClickLiquidityPoolRouter: OneClickLiquidityPoolRouter,
        OneClickOptions: OneClickOptions,
        OneClickProxy: OneClickProxy,
        OneClickTrading: OneClickTrading,
        OneClickNoRekt: OneClickNoRekt,
        OneClickLiquidation: OneClickLiquidation,
        MarginTradingRouter: MarginTradingRouter,
        HegicTakeProfit: HegicTakeProfit,
        Factory: Factory,
        WETH_USDC_Pool: WETH_USDC_Pool,
        nonfungiblePositionManager: nonfungiblePositionManager
    };
}