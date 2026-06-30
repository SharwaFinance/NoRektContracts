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

import {IPositionManagerERC20} from "../../interfaces/modularSwapRouter/IPositionManagerERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EphemeralSwapOutputUSDC is IPositionManagerERC20 {
    address public tokenInContract;
    uint24 public poolFee;
    address public tokenOutContract;

    constructor(
        address _tokenInContract,
        uint24 _poolFee,
        address _tokenOutContract
    ) {
        tokenInContract = _tokenInContract;
        poolFee = _poolFee;
        tokenOutContract = _tokenOutContract;
    }

    // VIEW FUNCTIONS //

    function getPositionValue(
        uint256 amountIn
    ) public returns (uint amountOut) {
        amountOut = amountIn;
    }

    function getInputPositionValue(
        uint256 amountIn
    ) external returns (uint amountOut) {}

    function getOutputPositionValue(
        uint256 amountOut
    ) external returns (uint amountIn) {}

    // ONLY MODULAR_SWAP_ROUTER_ROLE FUNCTION //

    function liquidate(uint256 amountIn) external returns (uint amountOut) {}

    function swapInput(
        uint amountIn,
        uint amountOutMinimum
    ) external returns (uint amountOut) {}

    function swapOutput(uint amountOut) external returns (uint amountIn) {}
}
