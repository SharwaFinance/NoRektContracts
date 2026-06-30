pragma solidity ^0.8.0;

import {IMarginTrading} from "../IMarginTrading.sol";
import {IOneClickProxy} from "./IOneClickProxy.sol";

interface IOneClickLiquidation {
    function liquidate(
        uint256 marginAccountID,
        uint minTotalMarginAccountValue
    ) external;
}
