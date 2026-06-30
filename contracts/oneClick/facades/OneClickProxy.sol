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

import {IMarginTrading} from "../../interfaces/IMarginTrading.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IOptionDataStorage} from "../../interfaces/oneClick/IOptionDataStorage.sol";

contract OneClickProxy is AccessControl {
    IMarginTrading public marginTrading;
    IOptionDataStorage public optionDataStorage;
    bytes32 public constant FACADE_ROLE = keccak256("FACADE_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant NO_YELLOW_ROLE = keccak256("NO_YELLOW_ROLE");

    uint public yellowCoeff = 1.20 * 1e5;

    constructor(IMarginTrading _marginTrading) {
        marginTrading = _marginTrading;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
    }

    modifier ensureYellowCoeffForDebt(uint marginAccountID) {
        _;
        require(
            marginTrading.getMarginAccountRatioForDebt(marginAccountID) >=
                yellowCoeff,
            "Operation rejected due to insufficient yellow coefficient"
        );
    }

    // ONLY MANAGER_ROLE FUNCTIONS

    function setYellowCoeff(
        uint newYellowCoeff
    ) external onlyRole(MANAGER_ROLE) {
        yellowCoeff = newYellowCoeff;
    }

    // ONLY DEFAULT_ADMIN_ROLE FUNCTIONS

    function approveERC20(
        address token,
        address to,
        uint amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token).approve(to, amount);
    }

    function approveERC721ForAll(
        address token,
        address to,
        bool value
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC721(token).setApprovalForAll(to, value);
    }

    function setMarginTrading(
        IMarginTrading newMarginTrading
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        marginTrading = newMarginTrading;
    }

    function setOptionDataStorage(
        IOptionDataStorage newOptionDataStorage
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        optionDataStorage = newOptionDataStorage;
    }

    // VIEW FUNCTIONS

    function getOptionOwner(
        uint marginAccountID,
        address token
    ) external view returns (uint) {
        return optionDataStorage.getOptionOwner(marginAccountID, token);
    }

    // ONLY FACADE_ROLE FUNCTIONS

    function provideERC20(
        uint marginAccountID,
        address token,
        uint amount
    ) external onlyRole(FACADE_ROLE) {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        marginTrading.provideERC20(marginAccountID, token, amount);
    }

    function provideERC721(
        uint marginAccountID,
        address token,
        uint collateralTokenID,
        uint optionType
    ) external onlyRole(FACADE_ROLE) {
        IERC721(token).transferFrom(
            msg.sender,
            address(this),
            collateralTokenID
        );
        marginTrading.provideERC721(marginAccountID, token, collateralTokenID);
        optionDataStorage.setOptionOwner(
            marginAccountID,
            token,
            collateralTokenID
        );
        optionDataStorage.setERC721Type(token, collateralTokenID, optionType);
        optionDataStorage.addActiveOption(token, collateralTokenID);
    }

    function withdrawERC20(
        uint marginAccountID,
        address token,
        uint amount
    ) external ensureYellowCoeffForDebt(marginAccountID) onlyRole(FACADE_ROLE) {
        marginTrading.withdrawERC20(marginAccountID, token, amount);
        IERC20(token).transfer(msg.sender, amount);
    }

    function withdrawERC721(
        uint marginAccountID,
        address token,
        uint value
    ) external ensureYellowCoeffForDebt(marginAccountID) onlyRole(FACADE_ROLE) {
        marginTrading.withdrawERC721(marginAccountID, token, value);
        IERC721(token).transferFrom(address(this), msg.sender, value);
        optionDataStorage.setOptionOwner(0, token, value);
        optionDataStorage.removeActiveOption(token, value);
    }

    function withdrawERC20NoYellow(
        uint marginAccountID,
        address token,
        uint amount
    ) external onlyRole(NO_YELLOW_ROLE) {
        marginTrading.withdrawERC20(marginAccountID, token, amount);
        IERC20(token).transfer(msg.sender, amount);
    }

    function withdrawERC721NoYellow(
        uint marginAccountID,
        address token,
        uint value
    ) external onlyRole(NO_YELLOW_ROLE) {
        marginTrading.withdrawERC721(marginAccountID, token, value);
        IERC721(token).transferFrom(address(this), msg.sender, value);
        optionDataStorage.setOptionOwner(0, token, value);
        optionDataStorage.removeActiveOption(token, value);
    }

    function borrow(
        uint marginAccountID,
        address token,
        uint amount
    ) external ensureYellowCoeffForDebt(marginAccountID) onlyRole(FACADE_ROLE) {
        marginTrading.borrow(marginAccountID, token, amount);
    }

    function borrowNoYellow(
        uint marginAccountID,
        address token,
        uint amount
    ) external onlyRole(NO_YELLOW_ROLE) {
        marginTrading.borrow(marginAccountID, token, amount);
    }

    function repay(
        uint marginAccountID,
        address token,
        uint amount
    ) external onlyRole(FACADE_ROLE) {
        marginTrading.repay(marginAccountID, token, amount);
    }

    function swap(
        uint marginAccountID,
        address tokenIn,
        address tokenOut,
        uint amountIn,
        uint amountOutMinimum
    ) external onlyRole(FACADE_ROLE) {
        marginTrading.swap(
            marginAccountID,
            tokenIn,
            tokenOut,
            amountIn,
            amountOutMinimum
        );
    }

    function exercise(
        uint marginAccountID,
        address token,
        uint collateralTokenID
    ) external onlyRole(FACADE_ROLE) {
        marginTrading.exercise(marginAccountID, token, collateralTokenID);
        optionDataStorage.removeActiveOption(token, collateralTokenID);
    }

    // EXTERNAL FUNCTIONS //

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
}
