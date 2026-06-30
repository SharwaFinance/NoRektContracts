import {
    MaxUint256,
    parseUnits,
    solidityPacked
} from "ethers";

import {
    PreparationResult,
} from "./prepareContracts";

import { time } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

export function sqrt(value: bigint): bigint {
    if (value < 0n) throw new Error("sqrt of negative number");
    if (value < 2n) return value;
    let x0 = value / 2n;
    let x1 = (x0 + value / x0) / 2n;
    while (x1 < x0) {
        x0 = x1;
        x1 = (x0 + value / x0) / 2n;
    }
    return x0;
}

export function priceToSqrtPriceX96BigInt(price: bigint): bigint {
    // Q96 = 2^96
    const Q96 = 1n << 96n;

    const sqrtPriceScaled = sqrt(price);

    return (sqrtPriceScaled * Q96) / (10n ** 9n);
}

export function sqrtPriceX96ToPrice(sqrtPriceX96: bigint): bigint {
    const Q96 = 2n ** 96n;      // 2^96
    const numerator = sqrtPriceX96 ** 2n;
    const denominator = Q96 * Q96; // 2^192
    return numerator / denominator;
}

export async function setPriceInWETHUSDCPool(c: PreparationResult, usdcAmount: bigint) {
    const poolAddress = await c.WETH_USDC_Pool.getAddress();
    const usdcBalance = await c.USDC.balanceOf(poolAddress);
    const wethBalance = await c.WETH.balanceOf(poolAddress);
    const total = usdcBalance * wethBalance
    const newWETHBalance = sqrt(BigInt(total) * (10n ** 18n) / usdcAmount)

    if (newWETHBalance > wethBalance) {
        const amount = (newWETHBalance - wethBalance)
        const swapParams = {
            path: solidityPacked(
                ["address", "uint24", "address"],
                [await c.WETH.getAddress(), 500, await c.USDC.getAddress()]
            ),
            recipient: await c.deployer.getAddress(),
            deadline: (await time.latest()) + 300,
            amountIn: amount,
            amountOutMinimum: 0
        };
        await c.WETH.approve(await c.SwapRouter.getAddress(), amount)
        await c.WETH.mint(amount)
        await c.SwapRouter.exactInput(swapParams);
    } else {
        const amount = wethBalance - newWETHBalance
        const swapParams = {
            path: solidityPacked(
                ["address", "uint24", "address"],
                [await c.WETH.getAddress(), 500, await c.USDC.getAddress()]
            ),
            recipient: await c.deployer.getAddress(),
            deadline: (await time.latest()) + 300,
            amountOut: amount,
            amountInMaximum: MaxUint256
        };
        const mint_amount = await c.Quoter.quoteExactOutput.staticCall(swapParams.path, swapParams.amountOut)
        await c.USDC.approve(await c.SwapRouter.getAddress(), mint_amount)
        await c.USDC.mint(mint_amount)

        await c.SwapRouter.exactOutput(swapParams);
    }
}

export async function getWethUsdcPoolPrice(c: PreparationResult) {
    const poolAddress = await c.WETH_USDC_Pool.getAddress();
    const usdcBalance = await c.USDC.balanceOf(poolAddress);
    const wethBalance = await c.WETH.balanceOf(poolAddress);
    return BigInt(usdcBalance) * (10n ** 18n) / BigInt(wethBalance)
}

export async function setPriceInUSDCeUSDCPool(c: PreparationResult, usdcAmount: bigint) {
    const poolAddress = await c.Factory.getPool(await c.USDCe.getAddress(), await c.USDC.getAddress(), 500);
    
    const usdcBalance = await c.USDC.balanceOf(poolAddress);
    const usdceBalance = await c.USDCe.balanceOf(poolAddress);
    const total = usdcBalance * usdceBalance;
    const newUSDCeBalance = sqrt(BigInt(total) * (10n ** 6n) / usdcAmount); // Both have 6 decimals

    if (newUSDCeBalance > usdceBalance) {
        const amount = newUSDCeBalance - usdceBalance;
        const swapParams = {
            path: solidityPacked(
                ["address", "uint24", "address"],
                [await c.USDCe.getAddress(), 500, await c.USDC.getAddress()]
            ),
            recipient: await c.deployer.getAddress(),
            deadline: (await time.latest()) + 300,
            amountIn: amount,
            amountOutMinimum: 0
        };
        await c.USDCe.approve(await c.SwapRouter.getAddress(), amount);
        await c.USDCe.mint(amount);
        await c.SwapRouter.exactInput(swapParams);
    } else {
        const amount = usdceBalance - newUSDCeBalance;
        const swapParams = {
            path: solidityPacked(
                ["address", "uint24", "address"],
                [await c.USDCe.getAddress(), 500, await c.USDC.getAddress()]
            ),
            recipient: await c.deployer.getAddress(),
            deadline: (await time.latest()) + 300,
            amountOut: amount,
            amountInMaximum: MaxUint256
        };
        const mint_amount = await c.Quoter.quoteExactOutput.staticCall(swapParams.path, swapParams.amountOut);
        await c.USDC.approve(await c.SwapRouter.getAddress(), mint_amount);
        await c.USDC.mint(mint_amount);

        await c.SwapRouter.exactOutput(swapParams);
    }
}

export async function getUSDCeUsdcPoolPrice(c: PreparationResult) {
    const poolAddress = await c.Factory.getPool(await c.USDCe.getAddress(), await c.USDC.getAddress(), 500);
    const usdcBalance = await c.USDC.balanceOf(poolAddress);
    const usdceBalance = await c.USDCe.balanceOf(poolAddress);
    return BigInt(usdcBalance) * (10n ** 6n) / BigInt(usdceBalance); // USDC per USDCe (both have 6 decimals)
}

export async function setPriceInWETHUSDCePool(c: PreparationResult, usdceAmount: bigint) {
    const wethAddress = await c.WETH.getAddress();
    const usdceAddress = await c.USDCe.getAddress();
    
    const token0 = wethAddress.toLowerCase() < usdceAddress.toLowerCase() ? wethAddress : usdceAddress;
    const token1 = wethAddress.toLowerCase() < usdceAddress.toLowerCase() ? usdceAddress : wethAddress;
    
    const poolAddress = await c.Factory.getPool(token0, token1, 500);
    
    if (poolAddress === "0x0000000000000000000000000000000000000000") {
        throw new Error("WETH_USDCe pool does not exist. Please create it first.");
    }
    
    const usdceBalance = await c.USDCe.balanceOf(poolAddress);
    const wethBalance = await c.WETH.balanceOf(poolAddress);
    const total = usdceBalance * wethBalance
    const newWETHBalance = sqrt(BigInt(total) * (10n ** 18n) / usdceAmount)

    if (newWETHBalance > wethBalance) {
        const amount = (newWETHBalance - wethBalance)
        const swapParams = {
            path: solidityPacked(
                ["address", "uint24", "address"],
                [wethAddress, 500, usdceAddress]
            ),
            recipient: await c.deployer.getAddress(),
            deadline: (await time.latest()) + 300,
            amountIn: amount,
            amountOutMinimum: 0
        };
        await c.WETH.approve(await c.SwapRouter.getAddress(), amount)
        await c.WETH.mint(amount)
        await c.SwapRouter.exactInput(swapParams);
    } else {
        const amount = wethBalance - newWETHBalance
        const swapParams = {
            path: solidityPacked(
                ["address", "uint24", "address"],
                [wethAddress, 500, usdceAddress]
            ),
            recipient: await c.deployer.getAddress(),
            deadline: (await time.latest()) + 300,
            amountOut: amount,
            amountInMaximum: MaxUint256
        };
        const mint_amount = await c.Quoter.quoteExactOutput.staticCall(swapParams.path, swapParams.amountOut)
        await c.USDCe.approve(await c.SwapRouter.getAddress(), mint_amount)
        await c.USDCe.mint(mint_amount)

        await c.SwapRouter.exactOutput(swapParams);
    }
}

export async function getWethUsdcePoolPrice(c: PreparationResult) {
    const wethAddress = await c.WETH.getAddress();
    const usdceAddress = await c.USDCe.getAddress();
    
    const token0 = wethAddress.toLowerCase() < usdceAddress.toLowerCase() ? wethAddress : usdceAddress;
    const token1 = wethAddress.toLowerCase() < usdceAddress.toLowerCase() ? usdceAddress : wethAddress;
    
    const poolAddress = await c.Factory.getPool(token0, token1, 500);
    const usdceBalance = await c.USDCe.balanceOf(poolAddress);
    const wethBalance = await c.WETH.balanceOf(poolAddress);
    return BigInt(usdceBalance) * (10n ** 18n) / BigInt(wethBalance)
}


