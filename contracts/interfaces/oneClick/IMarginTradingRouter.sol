// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IOneClickProxy} from "./IOneClickProxy.sol";
import {IMarginAccountManager} from "../IMarginAccountManager.sol";
import {IMarginTrading} from "../IMarginTrading.sol";

interface IMarginTradingRouter {
    function oneClickProxy() external view returns (IOneClickProxy);

    function marginAccountManager()
        external
        view
        returns (IMarginAccountManager);

    function marginTrading() external view returns (IMarginTrading);

    function yellowCoeff() external view returns (uint);

    function provideWithdrawRestricted(
        address token
    ) external view returns (bool);

    function approveERC20(address token, address to, uint amount) external;

    function approveERC721ForAll(
        address token,
        address to,
        bool value
    ) external;

    function setOneClickProxy(IOneClickProxy newOneClickProxy) external;

    function setYellowCoeff(uint newYellowCoeff) external;

    function setProvideWithdrawRestricted(address token, bool value) external;

    function provideERC20(
        uint marginAccountID,
        address token,
        uint amount
    ) external;

    function provideERC721(
        uint marginAccountID,
        address token,
        uint collateralTokenID
    ) external;

    function withdrawERC20(
        uint marginAccountID,
        address token,
        uint amount
    ) external;

    function withdrawERC721(
        uint marginAccountID,
        address token,
        uint value
    ) external;

    function borrow(uint marginAccountID, address token, uint amount) external;

    function repay(uint marginAccountID, address token, uint amount) external;

    function swap(
        uint marginAccountID,
        address tokenIn,
        address tokenOut,
        uint amountIn,
        uint amountOutMinimum
    ) external;

    function exercise(
        uint marginAccountID,
        address token,
        uint collateralTokenID
    ) external;
}
