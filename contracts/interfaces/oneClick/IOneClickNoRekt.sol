// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

interface IOneClickNoRekt {
    function multiSwapOutputRepayWithdraw(
        uint marginAccountID,
        address tokenOut,
        SwapOutputData[] memory swapsData,
        uint repayAmount,
        address withdrawToken,
        bool doWithdraw
    ) external;

    function multiExerciseRepayWithdraw(
        uint marginAccountID,
        uint[] memory tokenIDArr,
        address repayWithdrawToken,
        uint repayAmount,
        bool doWithdraw
    ) external;

    function contractMultiExerciseRepayWithdraw(
        uint marginAccountID,
        uint[] memory tokenIDArr,
        address repayWithdrawToken,
        uint repayAmount
    ) external;

    struct SwapOutputData {
        address tokenIn;
        uint amountOut;
        uint amountInMaximum;
    }
}
