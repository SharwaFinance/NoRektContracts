// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {ILiquidityPool} from "../../interfaces/ILiquidityPool.sol";

interface IOneClickLiquidityPool {
    function ROUTER_ROLE() external view returns (bytes32);

    function weth() external view returns (address);

    function tokenToPool(address token) external view returns (ILiquidityPool);

    function setLiquidityPool(address token, ILiquidityPool pool) external;

    function approveERC20(address token, address to, uint amount) external;

    function provideETHToPool(address recipient) external payable;

    function withdrawETHFromPool(
        address from,
        address recipient,
        uint amount
    ) external payable;

    function provide(
        address payer,
        address token,
        uint amount,
        address recipient
    ) external;

    function withdraw(
        address from,
        address token,
        uint poolTokenAmount,
        address recipient
    ) external;

    event ProvideETH(
        address indexed liquidityProvider,
        uint amountDepositPoolTokens
    );
    event WithdrawETH(
        address indexed liquidityProvider,
        uint amountWithdrawPoolTokens
    );
    event ProvideToken(
        address indexed payer,
        address indexed token,
        uint amountDeposited,
        address indexed recipient
    );
    event WithdrawToken(
        address indexed from,
        address indexed token,
        uint amountWithdrawn,
        address indexed recipient
    );
}
