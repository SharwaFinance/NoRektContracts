// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

interface IOneClickLiquidityPoolRouter {
    function oneClickLiquidityPool() external view returns (address);

    function setOneClickLiquidityPool(address _oneClickLiquidityPool) external;

    function provideETH() external payable;

    function withdrawETH(uint amount) external;

    function provide(address token, uint amount) external;

    function withdraw(address token, uint poolTokenAmount) external;
}
