// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

interface IFlashLoan {
    function flashLoan(
        address[] calldata tokens,
        address to,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}
