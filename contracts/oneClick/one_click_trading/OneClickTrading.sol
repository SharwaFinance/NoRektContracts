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

import {IOneClickProxy} from "../../interfaces/oneClick/IOneClickProxy.sol";
import {IMarginAccount} from "../../interfaces/IMarginAccount.sol";
import {IMarginAccountManager} from "../../interfaces/IMarginAccountManager.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH9} from "../../interfaces/oneClick/IWETH9.sol";

contract OneClickTrading is AccessControl {
    IMarginAccountManager public marginAccountManager;
    IOneClickProxy public oneClickProxy;
    IMarginAccount public marginAccount;

    address public weth;
    address public usdc;

    constructor(
        IMarginAccountManager _marginAccountManager,
        IOneClickProxy _oneClickProxy,
        IMarginAccount _marginAccount,
        address _weth,
        address _usdc
    ) {
        marginAccountManager = _marginAccountManager;
        oneClickProxy = _oneClickProxy;
        marginAccount = _marginAccount;
        weth = _weth;
        usdc = _usdc;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyApprovedOrOwner(uint marginAccountID) {
        require(
            marginAccountManager.isApprovedOrOwner(msg.sender, marginAccountID),
            "You are not the owner of the token"
        );
        _;
    }

    receive() external payable {}

    // ONLY DEFAULT_ADMIN_ROLE FUNCTIONS

    function approveERC20(
        address token,
        address to,
        uint amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token).approve(to, amount);
    }

    // ONLY marginAccountID APPROVE OR OWNER FUNCTIONS

    function provideETH(
        uint marginAccountID
    ) external payable onlyApprovedOrOwner(marginAccountID) {
        IWETH9(weth).deposit{value: msg.value}();
        oneClickProxy.provideERC20(marginAccountID, weth, msg.value);
    }

    function withdrawETH(
        uint marginAccountID,
        uint amount
    ) external payable onlyApprovedOrOwner(marginAccountID) {
        _withdrawETH(marginAccountID, amount, msg.sender);
    }

    function borrowWithdraw(
        uint marginAccountID,
        address token,
        uint amount,
        bool isETH
    ) external onlyApprovedOrOwner(marginAccountID) {
        oneClickProxy.borrow(marginAccountID, token, amount);
        if (token == weth && isETH) {
            _withdrawETH(marginAccountID, amount, msg.sender);
        } else {
            oneClickProxy.withdrawERC20(marginAccountID, token, amount);
            IERC20(token).transfer(msg.sender, amount);
        }
    }

    function provideERC20Repay(
        uint marginAccountID,
        address token,
        uint amount
    ) external payable onlyApprovedOrOwner(marginAccountID) {
        if (msg.value != 0 && token == address(weth)) {
            IWETH9(weth).deposit{value: msg.value}();
        } else {
            IERC20(token).transferFrom(msg.sender, address(this), amount);
        }
        oneClickProxy.provideERC20(marginAccountID, token, amount);
        oneClickProxy.repay(marginAccountID, token, amount);
    }

    function provideERC20RepayWithdraw(
        uint marginAccountID,
        address provideToken,
        address repayToken,
        address withdrawToken,
        uint amount
    ) external payable onlyApprovedOrOwner(marginAccountID) {
        if (msg.value != 0 && provideToken == address(weth)) {
            IWETH9(weth).deposit{value: msg.value}();
        } else {
            IERC20(provideToken).transferFrom(
                msg.sender,
                address(this),
                amount
            );
        }
        oneClickProxy.provideERC20(marginAccountID, provideToken, amount);
        oneClickProxy.repay(marginAccountID, repayToken, amount);
        uint withdrawAmount = marginAccount.getErc20ByContract(
            marginAccountID,
            withdrawToken
        );
        if (withdrawToken == weth) {
            _withdrawETH(marginAccountID, withdrawAmount, msg.sender);
        } else {
            oneClickProxy.withdrawERC20(
                marginAccountID,
                withdrawToken,
                withdrawAmount
            );
            IERC20(withdrawToken).transfer(msg.sender, withdrawAmount);
        }
    }

    // PRIVATE FUNCTIONS //

    function _withdrawETH(
        uint marginAccountID,
        uint amount,
        address msgSender
    ) private {
        oneClickProxy.withdrawERC20(marginAccountID, weth, amount);
        IWETH9(weth).withdraw(amount);
        (bool success, ) = payable(msgSender).call{value: amount}("");
        require(success, "ETH transfer failed");
    }
}
