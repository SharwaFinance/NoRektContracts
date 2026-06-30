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

import {IMarginAccountManager} from "./interfaces/IMarginAccountManager.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract LendingMarginAccountManager is AccessControl {
    IMarginAccountManager public marginAccountManager;
    mapping (uint => bool) public isLendingMarginAccount;
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    constructor(
        IMarginAccountManager _marginAccountManager
    ) {
        marginAccountManager = _marginAccountManager;      
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
    }

    function setLendingMarginAccount(uint id, bool state) external onlyRole(MANAGER_ROLE) {
        isLendingMarginAccount[id] = state;
    }

    function createLendingMarginAccount() external {
        uint id = marginAccountManager.createMarginAccount();
        isLendingMarginAccount[id] = true;
        marginAccountManager.transferFrom(address(this), msg.sender, id);
        emit CreateLendingMarginAccount(id);
    }

    function onERC721Received(
        address, 
        address, 
        uint256, 
        bytes calldata
    ) external returns(bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    } 

    event CreateLendingMarginAccount(uint tokenID);
}