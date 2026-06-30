pragma solidity ^0.8.0;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IMarginTrading} from "../interfaces/IMarginTrading.sol";
import {IOneClickProxy} from "../interfaces/oneClick/IOneClickProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILiquidationEventsStorage} from "../interfaces/oneClick/ILiquidationEventsStorage.sol";

contract OneClickLiquidation is AccessControl {
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    IMarginTrading public immutable marginTrading;
    IOneClickProxy public immutable oneClickProxy;
    ILiquidationEventsStorage public liquidationEventsStorage;

    constructor(
        address _marginTrading,
        address _oneClickProxy,
        address _liquidationEventsStorage
    ) {
        marginTrading = IMarginTrading(_marginTrading);
        oneClickProxy = IOneClickProxy(_oneClickProxy);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LIQUIDATOR_ROLE, msg.sender);
        liquidationEventsStorage = ILiquidationEventsStorage(
            _liquidationEventsStorage
        );
    }

    function liquidate(
        uint256 marginAccountID,
        uint minTotalMarginAccountValue
    ) external onlyRole(LIQUIDATOR_ROLE) {
        address baseToken = marginTrading.BASE_TOKEN();
        uint balanceBefore = IERC20(baseToken).balanceOf(address(this));
        marginTrading.liquidate(marginAccountID, minTotalMarginAccountValue);
        uint balanceAfter = IERC20(baseToken).balanceOf(address(this));
        uint liquidatorCommission = balanceAfter - balanceBefore;
        IERC20(baseToken).transfer(msg.sender, liquidatorCommission);
        liquidationEventsStorage.emitLiquidate(marginAccountID);
    }

    function abs(int256 x) internal pure returns (int256) {
        return x >= 0 ? int256(x) : int256(-x);
    }
}
