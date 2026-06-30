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
import {IHegicStrategy} from "../../interfaces/modularSwapRouter/hegic/IHegicStrategy.sol";
import {IPositionsManager} from "../../interfaces/oneClick/IPositionsManager.sol";
import {IMarginAccountManager} from "../../interfaces/IMarginAccountManager.sol";
import {IProxySeller} from "../../interfaces/oneClick/IProxySeller.sol";
import {IPositionManagerERC20} from "../../interfaces/modularSwapRouter/IPositionManagerERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IWETH9} from "../../interfaces/oneClick/IWETH9.sol";
import {HegicModule} from "../../modularSwapRouter/hegic/HegicModule.sol";
import {IWrapper} from "../../interfaces/modularSwapRouter/hegic/IWrapper.sol";

contract OneClickOptions is AccessControl {
    IMarginAccountManager public marginAccountManager;
    IOneClickProxy public oneClickProxy;
    IMarginAccount public marginAccount;
    IPositionsManager public hegicPositionManager;
    IProxySeller public proxySeller;
    HegicModule public hegicModule;
    IWrapper public wrapper;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address public referrer;
    address public hegicTokenIn;
    address public weth;
    address public usdc;

    struct SwapData {
        address tokenIn;
        uint amountIn;
        uint amountOutMinimum;
    }

    mapping(address => mapping(address => address))
        public uniswapExchangeModules;

    constructor(
        IMarginAccountManager _marginAccountManager,
        IOneClickProxy _oneClickProxy,
        IPositionsManager _hegicPositionManager,
        IProxySeller _proxySeller,
        IMarginAccount _marginAccount,
        HegicModule _hegicModule,
        address _hegicTokenIn,
        address _referrer,
        address _weth,
        address _usdc,
        IWrapper _wrapper
    ) {
        marginAccountManager = _marginAccountManager;
        oneClickProxy = _oneClickProxy;
        hegicPositionManager = _hegicPositionManager;
        proxySeller = _proxySeller;
        marginAccount = _marginAccount;
        hegicTokenIn = _hegicTokenIn;
        hegicModule = _hegicModule;
        referrer = _referrer;
        weth = _weth;
        usdc = _usdc;
        wrapper = _wrapper;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
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

    function setUniswapExchangeModules(
        address tokenIn,
        address tokenOut,
        address module
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uniswapExchangeModules[tokenIn][tokenOut] = module;
    }

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

    // ONLY MANAGER_ROLE FUNCTIONS

    function withdrawERC721(
        uint marginAccountID,
        uint tokenID
    ) external onlyRole(MANAGER_ROLE) {
        if (!hegicModule.checkValidityERC721(tokenID)) {
            oneClickProxy.withdrawERC721(
                marginAccountID,
                address(hegicPositionManager),
                tokenID
            );
            hegicPositionManager.transferFrom(
                address(this),
                msg.sender,
                tokenID
            );
        }
    }

    // ONLY marginAccountID APPROVE OR OWNER FUNCTIONS

    function borrowDoubleWithdrawBuyProvideERC721(
        uint marginAccountID,
        address tokenBorrow,
        address tokenForOption,
        IHegicStrategy strategy,
        uint amountBorrow,
        uint amountBuy,
        uint amountWithdraw,
        uint maxTotalCost,
        uint period,
        bytes[] memory additional
    ) external onlyApprovedOrOwner(marginAccountID) {
        _withdraw(marginAccountID, tokenBorrow, amountBorrow);
        withdrawBuyProvideERC721(
            marginAccountID,
            tokenForOption,
            strategy,
            amountBuy,
            amountWithdraw,
            maxTotalCost,
            period,
            additional
        );
    }

    function borrowWithdrawTransferBuyProvideERC721(
        uint marginAccountID,
        address tokenBorrow,
        IHegicStrategy strategy,
        uint amountBorrow,
        address tokenTransfer,
        uint amountBuy,
        uint maxTotalCost,
        uint period,
        bytes[] memory additional
    ) external onlyApprovedOrOwner(marginAccountID) {
        _withdraw(marginAccountID, tokenBorrow, amountBorrow);
        transferBuyProvideERC721(
            marginAccountID,
            tokenTransfer,
            strategy,
            amountBuy,
            maxTotalCost,
            period,
            additional
        );
    }

    function withdrawBuyProvideERC721(
        uint marginAccountID,
        address tokenOut,
        IHegicStrategy strategy,
        uint amount,
        uint amountWithdraw,
        uint maxTotalCost,
        uint period,
        bytes[] memory additional
    ) public onlyApprovedOrOwner(marginAccountID) {
        (, uint128 positivepnl) = strategy.calculateNegativepnlAndPositivepnl(
            amount,
            period,
            additional
        );
        uint premium = uint256(positivepnl);
        require(premium <= maxTotalCost, "maximum total value exceeded");
        uint amountOut;
        if (tokenOut == usdc) {
            amountOut = premium;
        } else {
            amountOut = IPositionManagerERC20(
                uniswapExchangeModules[usdc][tokenOut]
            ).getOutputPositionValue(premium);
        }

        if (amountWithdraw == 0) {
            amountWithdraw = amountOut;
        }
        require(amountWithdraw >= amountOut, "Insufficient amount to withdraw");
        oneClickProxy.withdrawERC20(marginAccountID, tokenOut, amountWithdraw);
        if (tokenOut != usdc) {
            IPositionManagerERC20(uniswapExchangeModules[usdc][tokenOut])
                .swapOutput(premium);
        }

        wrapper.wrap(premium);
        uint id = hegicPositionManager.nextTokenId();

        proxySeller.buyWithReferal(
            strategy,
            amount,
            period,
            additional,
            referrer
        );

        oneClickProxy.provideERC721(
            marginAccountID,
            address(hegicPositionManager),
            id,
            1
        );
    }

    function transferBuyProvideERC721(
        uint marginAccountID,
        address tokenOut,
        IHegicStrategy strategy,
        uint amount,
        uint maxTotalCost,
        uint period,
        bytes[] memory additional
    ) public payable onlyApprovedOrOwner(marginAccountID) {
        (, uint128 positivepnl) = strategy.calculateNegativepnlAndPositivepnl(
            amount,
            period,
            additional
        );
        uint premium = uint256(positivepnl);
        require(premium <= maxTotalCost, "maximum total value exceeded");
        if (tokenOut == hegicTokenIn) {
            IERC20(tokenOut).transferFrom(msg.sender, address(this), premium);
        } else {
            uint amountOut;
            if (tokenOut == usdc) {
                amountOut = premium;
            } else {
                amountOut = IPositionManagerERC20(
                    uniswapExchangeModules[usdc][tokenOut]
                ).getOutputPositionValue(premium);
            }

            if (msg.value != 0 && tokenOut == address(weth)) {
                IWETH9(weth).deposit{value: msg.value}();
                if (msg.value > amountOut) {
                    IERC20(tokenOut).transfer(
                        msg.sender,
                        msg.value - amountOut
                    );
                }
            } else {
                IERC20(tokenOut).transferFrom(
                    msg.sender,
                    address(this),
                    amountOut
                );
            }
            if (tokenOut != usdc) {
                IPositionManagerERC20(uniswapExchangeModules[usdc][tokenOut])
                    .swapOutput(premium);
            }
            wrapper.wrap(premium);
        }
        uint id = hegicPositionManager.nextTokenId();

        proxySeller.buyWithReferal(
            strategy,
            amount,
            period,
            additional,
            referrer
        );

        oneClickProxy.provideERC721(
            marginAccountID,
            address(hegicPositionManager),
            id,
            1
        );
    }

    function exercisesSwapRepay(
        uint marginAccountID,
        uint[] memory hegopIDs,
        address repayToken,
        uint amountOutMinimum
    ) public onlyApprovedOrOwner(marginAccountID) {
        uint swapBalanceBefore = marginAccount.getErc20ByContract(
            marginAccountID,
            usdc
        );
        _exercises(marginAccountID, hegopIDs);
        uint swapBalanceAfter = marginAccount.getErc20ByContract(
            marginAccountID,
            usdc
        );
        uint swapAmount = swapBalanceAfter - swapBalanceBefore;
        if (repayToken != usdc) {
            uint repayBalanceBefore = marginAccount.getErc20ByContract(
                marginAccountID,
                repayToken
            );
            oneClickProxy.swap(
                marginAccountID,
                usdc,
                repayToken,
                swapAmount,
                amountOutMinimum
            );
            uint repayBalanceAfter = marginAccount.getErc20ByContract(
                marginAccountID,
                repayToken
            );
            uint repayAmount = repayBalanceAfter - repayBalanceBefore;
            oneClickProxy.repay(marginAccountID, repayToken, repayAmount);
        } else {
            oneClickProxy.repay(marginAccountID, repayToken, swapAmount);
        }
    }

    function exercisesSwapRepayAndWithdraw(
        uint marginAccountID,
        uint[] memory hegopIDs,
        address repayToken,
        uint amountOutMinimum,
        bool useAllForWithdraw,
        uint withdrawAmount,
        bool isETH
    ) external onlyApprovedOrOwner(marginAccountID) {
        exercisesSwapRepay(
            marginAccountID,
            hegopIDs,
            repayToken,
            amountOutMinimum
        );
        uint balanceTokenOut = marginAccount.getErc20ByContract(
            marginAccountID,
            repayToken
        );
        uint amount;
        if (useAllForWithdraw) {
            amount = balanceTokenOut;
        } else {
            amount = withdrawAmount;
        }
        if (repayToken == weth && isETH) {
            _withdrawETH(marginAccountID, amount, msg.sender);
        } else {
            oneClickProxy.withdrawERC20(marginAccountID, repayToken, amount);
            IERC20(repayToken).transfer(msg.sender, amount);
        }
    }

    // PRIVATE FUNCTIONS //

    function _withdraw(
        uint marginAccountID,
        address tokenBorrow,
        uint amountBorrow
    ) private {
        oneClickProxy.borrow(marginAccountID, tokenBorrow, amountBorrow);
        oneClickProxy.withdrawERC20(marginAccountID, tokenBorrow, amountBorrow);
        IERC20(tokenBorrow).transfer(msg.sender, amountBorrow);
    }

    function _exercises(uint marginAccountID, uint[] memory hegopIDs) private {
        for (uint i = 0; i < hegopIDs.length; i++) {
            uint hegopID = hegopIDs[i];
            oneClickProxy.exercise(
                marginAccountID,
                address(hegicPositionManager),
                hegopID
            );
        }
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
