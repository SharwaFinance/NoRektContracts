pragma solidity 0.8.20;

import {IMarginTrading} from "../interfaces/IMarginTrading.sol";
import {IMarginAccountsRatiosData} from "../interfaces/utils/IMarginAccountsRatiosData.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract MarginAccountsRatiosData is IMarginAccountsRatiosData, AccessControl {
    IMarginTrading public marginTrading;

    constructor(address _marginTrading) {
        marginTrading = IMarginTrading(_marginTrading);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setMarginTrading(
        address _marginTrading
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        marginTrading = IMarginTrading(_marginTrading);
    }

    function checkGetMarginAccountRatio(
        uint[] memory arrMarginAccountID
    ) external returns (uint[] memory arrMarginAccountRatio) {
        arrMarginAccountRatio = new uint[](arrMarginAccountID.length);
        for (uint i = 0; i < arrMarginAccountID.length; i++) {
            arrMarginAccountRatio[i] = marginTrading.getMarginAccountRatio(
                arrMarginAccountID[i]
            );
        }
    }
}
