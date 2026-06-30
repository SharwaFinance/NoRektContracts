pragma solidity 0.8.20;

/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SharwaFinance
 * Copyright (C) 2026 SharwaFinance
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

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IOneClickNoRekt} from "../../interfaces/oneClick/IOneClickNoRekt.sol";
import {IMarginAccount} from "../../interfaces/IMarginAccount.sol";
import {IMarginAccountManager} from "../../interfaces/IMarginAccountManager.sol";
import {OneClickEphemeralSwapOutput} from "../swap_output/OneClickEphemeralSwapOutput.sol";
import {ILiquidityPool} from "../../interfaces/ILiquidityPool.sol";
import {IOneClickProxy} from "../../interfaces/oneClick/IOneClickProxy.sol";
import {IWETH9} from "../../interfaces/oneClick/IWETH9.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OneClickNoRekt is AccessControl, IOneClickNoRekt {
    IOneClickProxy public oneClickProxy;
    IMarginAccount public marginAccount;
    IMarginAccountManager public immutable marginAccountManager;
    OneClickEphemeralSwapOutput public oneClickEphemeralSwapOutput;

    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    address public weth;
    address public hegicPositionManager;

    constructor(
        IOneClickProxy _oneClickProxy,
        IMarginAccount _marginAccount,
        IMarginAccountManager _marginAccountManager,
        OneClickEphemeralSwapOutput _oneClickEphemeralSwapOutput,
        address _hegicPositionManager,
        address _weth
    ) {
        oneClickProxy = _oneClickProxy;
        marginAccount = _marginAccount;
        marginAccountManager = _marginAccountManager;
        oneClickEphemeralSwapOutput = _oneClickEphemeralSwapOutput;
        weth = _weth;
        hegicPositionManager = _hegicPositionManager;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Modifier to check if the caller is approved or the owner of the margin account.
     * @param marginAccountID The ID of the margin account.
     */
    modifier onlyApprovedOrOwner(uint marginAccountID) {
        require(
            marginAccountManager.isApprovedOrOwner(msg.sender, marginAccountID),
            "You are not the owner of the token"
        );
        _;
    }

    receive() external payable {}

    function multiSwapOutputRepayWithdraw(
        uint marginAccountID,
        address tokenOut,
        SwapOutputData[] memory swapsData,
        uint repayAmount,
        address withdrawToken,
        bool doWithdraw
    ) external onlyApprovedOrOwner(marginAccountID) {
        for (uint i = 0; i < swapsData.length; i++) {
            SwapOutputData memory swap = swapsData[i];
            if (swap.amountOut != 0) {
                oneClickEphemeralSwapOutput.swapOutput(
                    marginAccountID,
                    tokenOut,
                    swap.tokenIn,
                    swap.amountOut,
                    swap.amountInMaximum
                );
            }
        }

        _repayWithdraw(
            marginAccountID,
            tokenOut,
            withdrawToken,
            repayAmount,
            doWithdraw
        );
    }

    function multiExerciseRepayWithdraw(
        uint marginAccountID,
        uint[] memory tokenIDArr,
        address repayWithdrawToken,
        uint repayAmount,
        bool doWithdraw
    ) external onlyApprovedOrOwner(marginAccountID) {
        _multiExerciseRepayWithdraw(
            marginAccountID,
            tokenIDArr,
            repayWithdrawToken,
            repayAmount,
            doWithdraw
        );
    }

    function contractMultiExerciseRepayWithdraw(
        uint marginAccountID,
        uint[] memory tokenIDArr,
        address repayWithdrawToken,
        uint repayAmount
    ) external onlyRole(EXECUTOR_ROLE) {
        _multiExerciseRepayWithdraw(
            marginAccountID,
            tokenIDArr,
            repayWithdrawToken,
            repayAmount,
            true
        );
    }

    function _multiExerciseRepayWithdraw(
        uint marginAccountID,
        uint[] memory tokenIDArr,
        address repayWithdrawToken,
        uint repayAmount,
        bool doWithdraw
    ) private {
        for (uint i = 0; i < tokenIDArr.length; i++) {
            oneClickProxy.exercise(
                marginAccountID,
                hegicPositionManager,
                tokenIDArr[i]
            );
        }

        _repayWithdraw(
            marginAccountID,
            repayWithdrawToken,
            repayWithdrawToken,
            repayAmount,
            doWithdraw
        );
    }

    function _repayWithdraw(
        uint marginAccountID,
        address repayToken,
        address withdrawToken,
        uint repayAmount,
        bool doWithdraw
    ) private {
        ILiquidityPool liuidityPool = ILiquidityPool(
            marginAccount.tokenToLiquidityPool(repayToken)
        );
        uint debt = liuidityPool.getDebtWithAccruedInterest(marginAccountID);

        if (repayAmount == 0) {
            repayAmount = debt;
        }

        if (debt != 0) {
            oneClickProxy.repay(marginAccountID, repayToken, repayAmount);
        }

        uint balance = marginAccount.getErc20ByContract(
            marginAccountID,
            withdrawToken
        );

        if (doWithdraw) {
            address owner = marginAccountManager.ownerOf(marginAccountID);

            if (withdrawToken == weth) {
                _withdrawETH(marginAccountID, balance, owner);
            } else {
                oneClickProxy.withdrawERC20(
                    marginAccountID,
                    withdrawToken,
                    balance
                );
                IERC20(withdrawToken).transfer(owner, balance);
            }
        }
    }

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
