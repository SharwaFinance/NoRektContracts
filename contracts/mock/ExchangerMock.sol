// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DirectExchanger is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant ACCEPTED_USER_ROLE =
        keccak256("ACCEPTED_USER_ROLE");

    IERC20 public immutable USDC;
    IERC20 public immutable USDCe;

    constructor(IERC20 _USDC, IERC20 _USDCe) {
        USDC = _USDC;
        USDCe = _USDCe;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function wrap(uint256 amount) external onlyRole(ACCEPTED_USER_ROLE) {
        USDC.safeTransferFrom(msg.sender, address(this), amount);
        USDCe.safeTransfer(msg.sender, amount);
    }

    function unwrap(uint256 amount) external onlyRole(ACCEPTED_USER_ROLE) {
        USDCe.safeTransferFrom(msg.sender, address(this), amount);
        USDC.safeTransfer(msg.sender, amount);
    }

    function withdraw(
        IERC20 token,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        token.transfer(msg.sender, amount);
    }
}
