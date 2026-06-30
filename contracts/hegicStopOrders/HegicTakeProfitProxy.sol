/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Sharwa.Finance
 * Copyright (C) 2026 Sharwa.Finance
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

pragma solidity 0.8.20;

import {IHegicTakeProfit} from "../interfaces/hegicStopOrders/IHegicTakeProfit.sol";
import {HegicModule} from "../modularSwapRouter/hegic/HegicModule.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract HegicTakeProfitProxy is AccessControl {
    IHegicTakeProfit public hegicTakeProfit;
    HegicModule public hegicModule;

    bytes32 public constant MANAGERE_ROLE = keccak256("MANAGERE_ROLE");

    constructor(IHegicTakeProfit _hegicTakeProfit, HegicModule _hegicModule) {
        hegicTakeProfit = _hegicTakeProfit;
        hegicModule = _hegicModule;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGERE_ROLE, msg.sender);
    }

    function setHegicTakeProfit(
        IHegicTakeProfit newhegicTakeProfit
    ) external onlyRole(MANAGERE_ROLE) {
        hegicTakeProfit = newhegicTakeProfit;
    }

    function setHegicModule(
        HegicModule newHegicModule
    ) external onlyRole(MANAGERE_ROLE) {
        hegicModule = newHegicModule;
    }

    function checkTakeProfits(
        uint[] memory arrTokenId
    ) external view returns (bool[] memory) {
        uint len = arrTokenId.length;
        bool[] memory results = new bool[](len);
        for (uint i = 0; i < len; i++) {
            results[i] = hegicTakeProfit.checkTakeProfit(arrTokenId[i]);
        }
        return results;
    }

    function checkPositionsValidity(
        uint[] memory arrTokenId
    ) external returns (bool[] memory) {
        uint len = arrTokenId.length;
        bool[] memory results = new bool[](len);
        for (uint i = 0; i < len; i++) {
            results[i] = hegicModule.checkValidityERC721(arrTokenId[i]);
        }
        return results;
    }
}
