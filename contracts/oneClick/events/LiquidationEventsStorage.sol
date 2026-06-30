pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ILiquidationEventsStorage} from "../../interfaces/oneClick/ILiquidationEventsStorage.sol";

contract LiquidationEventsStorage is AccessControl, ILiquidationEventsStorage {

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    bytes32 public constant ONE_CLICK_LIQUIDATION_ROLE = keccak256("ONE_CLICK_LIQUIDATION_ROLE");

    event Liquidate(uint marginAccountID);

    function emitLiquidate(uint marginAccountID) external onlyRole(ONE_CLICK_LIQUIDATION_ROLE) {
        emit Liquidate(marginAccountID);
    }
}