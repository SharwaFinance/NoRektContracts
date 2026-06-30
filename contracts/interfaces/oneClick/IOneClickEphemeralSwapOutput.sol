pragma solidity 0.8.20;

interface IOneClickEphemeralSwapOutput {
    function swapOutput(
        uint marginAccountID,
        address tokenIn,
        address tokenOut,
        uint amountOut,
        uint amountInMaximum
    ) external returns (uint amountIn);

    function getAmountIn(
        address tokenIn,
        address tokenOut,
        uint amountOut
    ) external returns (uint amountIn);
}