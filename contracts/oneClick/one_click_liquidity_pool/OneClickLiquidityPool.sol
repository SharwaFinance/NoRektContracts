pragma solidity 0.8.20;

/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SharwaFinance
 * Copyright (C) 2025 SharwaFinance
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 **/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH9} from "../../interfaces/oneClick/IWETH9.sol";
import {ILiquidityPool} from "../../interfaces/ILiquidityPool.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IOneClickLiquidityPool} from "../../interfaces/oneClick/IOneClickLiquidityPool.sol";

contract OneClickLiquidityPool is AccessControl, IOneClickLiquidityPool {
    bytes32 public constant ROUTER_ROLE = keccak256("ROUTER_ROLE");

    mapping(address => ILiquidityPool) public tokenToPool;
    address public weth;

    constructor(address _weth) {
        weth = _weth;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ROUTER_ROLE, msg.sender);
    }

    receive() external payable {}

    function setLiquidityPool(
        address token,
        ILiquidityPool pool
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0), "Token address cannot be zero");
        require(address(pool) != address(0), "Pool address cannot be zero");
        tokenToPool[token] = pool;
    }

    function approveERC20(
        address token,
        address to,
        uint amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token).approve(to, amount);
    }

    function provideETHToPool(
        address recipient
    ) external payable onlyRole(ROUTER_ROLE) {
        require(address(tokenToPool[weth]) != address(0), "No pool for WETH");
        IWETH9(weth).deposit{value: msg.value}();
        ILiquidityPool pool = tokenToPool[weth];
        pool.provide(msg.value);
        pool.transfer(recipient, pool.balanceOf(address(this)));
        emit ProvideETH(recipient, msg.value);
    }

    function withdrawETHFromPool(
        address from,
        address recipient,
        uint amount
    ) external payable onlyRole(ROUTER_ROLE) {
        require(address(tokenToPool[weth]) != address(0), "No pool for WETH");
        ILiquidityPool pool = tokenToPool[weth];
        pool.transferFrom(from, address(this), amount);
        pool.withdraw(amount);
        uint weth_amount = IERC20(weth).balanceOf(address(this));
        IWETH9(weth).withdraw(weth_amount);
        (bool success, ) = payable(recipient).call{value: weth_amount}("");
        require(success, "ETH transfer failed");
        emit WithdrawETH(recipient, weth_amount);
    }

    function provide(
        address payer,
        address token,
        uint amount,
        address recipient
    ) external onlyRole(ROUTER_ROLE) {
        ILiquidityPool pool = tokenToPool[token];
        require(address(pool) != address(0), "Pool not registered for token");
        IERC20(token).transferFrom(payer, address(this), amount);
        IERC20(token).approve(address(pool), amount);
        pool.provide(amount);
        pool.transfer(recipient, pool.balanceOf(address(this)));
        emit ProvideToken(payer, token, amount, recipient);
    }

    function withdraw(
        address from,
        address token,
        uint poolTokenAmount,
        address recipient
    ) external onlyRole(ROUTER_ROLE) {
        ILiquidityPool pool = tokenToPool[token];
        require(address(pool) != address(0), "Pool not registered for token");
        pool.transferFrom(from, address(this), poolTokenAmount);
        pool.withdraw(poolTokenAmount);
        uint tokenAmount = IERC20(token).balanceOf(address(this));
        require(tokenAmount > 0, "No tokens received from pool");
        IERC20(token).transfer(recipient, tokenAmount);
        emit WithdrawToken(from, token, tokenAmount, recipient);
    }
}
