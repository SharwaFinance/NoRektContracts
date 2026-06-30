pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IOneClickLiquidityPool} from "../../interfaces/oneClick/IOneClickLiquidityPool.sol";

contract OneClickLiquidityPoolRouter is AccessControl {
    IOneClickLiquidityPool public oneClickLiquidityPool;

    constructor(address _oneClickLiquidityPool) {
        oneClickLiquidityPool = IOneClickLiquidityPool(_oneClickLiquidityPool);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    receive() external payable {}

    function setLiquidityPool(
        address _oneClickLiquidityPool
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        oneClickLiquidityPool = IOneClickLiquidityPool(_oneClickLiquidityPool);
    }

    function provideETH() external payable {
        oneClickLiquidityPool.provideETHToPool{value: msg.value}(msg.sender);
    }

    function withdrawETH(uint amount) external {
        oneClickLiquidityPool.withdrawETHFromPool(
            msg.sender,
            msg.sender,
            amount
        );
    }

    function provide(address token, uint amount) external {
        oneClickLiquidityPool.provide(msg.sender, token, amount, msg.sender);
    }

    function withdraw(address token, uint poolTokenAmount) external {
        oneClickLiquidityPool.withdraw(
            msg.sender,
            token,
            poolTokenAmount,
            msg.sender
        );
    }
}
