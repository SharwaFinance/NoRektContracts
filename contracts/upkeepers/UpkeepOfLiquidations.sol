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

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IMarginTrading} from "../interfaces/IMarginTrading.sol";
import {IOneClickLiquidation} from "../interfaces/oneClick/IOneClickLiquidation.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UpkeepOfLiquidations is AutomationCompatibleInterface, Ownable {
    uint private constant COEFFICIENT_DECIMALS = 1e5;

    IMarginTrading public marginTrading;
    IOneClickLiquidation public oneClickLiquidation;
    uint public maxDeviationPercent = 30 * 1e5;

    constructor(
        IMarginTrading _marginTrading,
        IOneClickLiquidation _oneClickLiquidation
    ) {
        marginTrading = _marginTrading;
        oneClickLiquidation = _oneClickLiquidation;
    }

    // OWNER FUNCTIONS //

    function transferErc20(
        address token,
        address to,
        uint amount
    ) external onlyOwner {
        ERC20(token).transfer(to, amount);
    }

    function setMarginTrading(
        IMarginTrading newMarginTrading
    ) external onlyOwner {
        marginTrading = newMarginTrading;
    }

    function setMaxDeviationPercent(
        uint newMaxDeviationPercent
    ) external onlyOwner {
        maxDeviationPercent = newMaxDeviationPercent;
    }

    // EXTERNAL FUNCTIONS //

    function checkUpkeep(
        bytes calldata checkData
    ) external override returns (bool upkeepNeeded, bytes memory performData) {
        (uint256 lowerBound, uint256 upperBound) = abi.decode(
            checkData,
            (uint256, uint256)
        );

        for (uint256 i = lowerBound; i <= upperBound; i++) {
            if (
                marginTrading.getMarginAccountRatio(i) <=
                marginTrading.redCoeff()
            ) {
                upkeepNeeded = true;
                performData = abi.encode(i);
                break;
            }
        }
        return (upkeepNeeded, performData);
    }

    function performUpkeep(bytes calldata performData) external override {
        uint256 optionID = abi.decode(performData, (uint256));

        uint marginAccountValueChainlink = marginTrading
            .calculateMarginAccountValue(optionID);

        uint marginAccountValueUniswap = marginTrading
            .calculateMarginAccountValueUSDC(optionID);

        uint minTotalMarginAccountValue = (marginAccountValueChainlink *
            (COEFFICIENT_DECIMALS * 100 - maxDeviationPercent)) /
            (COEFFICIENT_DECIMALS * 100);

        require(
            marginAccountValueUniswap >= minTotalMarginAccountValue,
            "Uniswap value is too low compared to Chainlink value"
        );

        oneClickLiquidation.liquidate(optionID, minTotalMarginAccountValue);
    }
}
