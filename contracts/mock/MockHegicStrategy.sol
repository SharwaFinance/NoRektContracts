// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IHegicStrategy} from "../interfaces/modularSwapRouter/hegic/IHegicStrategy.sol";

contract MockHegicStrategy is IHegicStrategy {
    address public priceProvider;

    mapping(uint256 => uint256) private payOffAmounts;
    uint256 public premiumAmount;

    constructor(address _priceProvider) {
        priceProvider = _priceProvider;
    }

    function setPayOffAmount(uint256 optionID, uint256 amount) external {
        payOffAmounts[optionID] = amount;
    }

    function setPremium(uint256 amount) external {
        premiumAmount = amount;
    }

    function payOffAmount(
        uint256 optionID
    ) external view override returns (uint256) {
        return payOffAmounts[optionID];
    }

    function calculateNegativepnlAndPositivepnl(
        uint256 amount,
        uint256 period,
        bytes[] calldata
    ) external view returns (uint128 negativepnl, uint128 positivepnl) {
        positivepnl = uint128(premiumAmount);
    }
}
