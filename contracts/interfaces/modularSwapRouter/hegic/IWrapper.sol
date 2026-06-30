// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IWrapper {
    /**
     * @notice Wraps USDC into USDCe.
     * @dev Transfers `amount` of USDC from the caller to the contract, then transfers the same amount of USDCe from the contract to the caller.
     * Can only be called by addresses with the ACCEPTED_USER_ROLE.
     * @param amount The amount of USDC to wrap into USDCe.
     */
    function wrap(uint256 amount) external;

    /**
     * @notice Unwraps USDCe into USDC.
     * @dev Transfers `amount` of USDCe from the caller to the contract, then transfers the same amount of USDC from the contract to the caller.
     * Can only be called by addresses with the ACCEPTED_USER_ROLE.
     * @param amount The amount of USDCe to unwrap into USDC.
     */
    function unwrap(uint256 amount) external;
}
