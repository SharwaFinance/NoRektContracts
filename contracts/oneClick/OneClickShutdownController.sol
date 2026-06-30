// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ILiquidityPool} from "../interfaces/ILiquidityPool.sol";
import {IMarginTrading} from "../interfaces/IMarginTrading.sol";

contract OneClickShutdownController is AccessControl {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    IMarginTrading public marginTrading;
    ILiquidityPool public liquidityPool_USDC;
    ILiquidityPool public liquidityPool_WETH;
    address public oneClickProxy;
    address public oneClickLiquidation;
    address public marginAccount;
    address public oneClickLiquidityPool;

    constructor(
        address _marginTrading,
        address _liquidityPoolUSDC,
        address _liquidityPoolWETH,
        address _oneClickProxy,
        address _oneClickLiquidation,
        address _marginAccount,
        address _oneClickLiquidityPool
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
        marginTrading = IMarginTrading(_marginTrading);
        liquidityPool_USDC = ILiquidityPool(_liquidityPoolUSDC);
        liquidityPool_WETH = ILiquidityPool(_liquidityPoolWETH);
        oneClickProxy = _oneClickProxy;
        oneClickLiquidation = _oneClickLiquidation;
        marginAccount = _marginAccount;
        oneClickLiquidityPool = _oneClickLiquidityPool;
    }

    event ProtocolPaused(address indexed manager);
    event BorrowingPaused(address indexed manager);
    event LiquidityPoolsDisabled(address indexed manager);
    event LiquidityPoolUSDCDisabled(address indexed manager);
    event LiquidityPoolWETHDisabled(address indexed manager);

    function pauseProtocol() external onlyRole(MANAGER_ROLE) {
        marginTrading.revokeOneClickProxyRole(oneClickProxy);
        marginTrading.revokeLiquidatorRole(oneClickLiquidation);
        liquidityPool_USDC.revokeProtocolRouterRole(marginAccount);
        liquidityPool_WETH.revokeProtocolRouterRole(marginAccount);
        liquidityPool_USDC.revokeProtocolRouterRole(oneClickLiquidityPool);
        liquidityPool_WETH.revokeProtocolRouterRole(oneClickLiquidityPool);
        emit ProtocolPaused(msg.sender);
    }

    function pauseBorrowing() external onlyRole(MANAGER_ROLE) {
        liquidityPool_USDC.setMaximumBorrowMultiplier(0);
        liquidityPool_WETH.setMaximumBorrowMultiplier(0);
        emit BorrowingPaused(msg.sender);
    }

    function disableLiquidityPools() external onlyRole(MANAGER_ROLE) {
        liquidityPool_USDC.revokeProtocolRouterRole(marginAccount);
        liquidityPool_WETH.revokeProtocolRouterRole(marginAccount);
        emit LiquidityPoolsDisabled(msg.sender);
    }

    function disableLiquidityPoolUSDC() external onlyRole(MANAGER_ROLE) {
        liquidityPool_USDC.revokeProtocolRouterRole(marginAccount);
        emit LiquidityPoolUSDCDisabled(msg.sender);
    }

    function disableLiquidityPoolWETH() external onlyRole(MANAGER_ROLE) {
        liquidityPool_WETH.revokeProtocolRouterRole(marginAccount);
        emit LiquidityPoolWETHDisabled(msg.sender);
    }
}
