/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Sharwa.Finance
 * Copyright (C) 2026 Sharwa.Finance
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

pragma solidity 0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IOperationalTreasury, IHegicStrategy} from "../interfaces/modularSwapRouter/hegic/IOperationalTreasury.sol";
import {IHegicTakeProfit} from "../interfaces/hegicStopOrders/IHegicTakeProfit.sol";
import {IPositionsManager} from "../interfaces/modularSwapRouter/hegic/IPositionsManager.sol";
import {IOneClickProxy} from "../interfaces/oneClick/IOneClickProxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IMarginAccountManager} from "../interfaces/IMarginAccountManager.sol";
import {ILendingMarginAccountManager} from "../interfaces/ILendingMarginAccountManager.sol";
import {IOneClickNoRekt} from "../interfaces/oneClick/IOneClickNoRekt.sol";

/**
 * @title TakeProfit
 * @author 0nika0
 * @dev A contract that enables users to set and execute take-profit orders on ERC721 tokens.
 */
contract HegicTakeProfit is IHegicTakeProfit, Ownable {
    IPositionsManager public positionManager;
    IOperationalTreasury public operationalTreasury;
    IMarginAccountManager public immutable marginAccountManager;
    ILendingMarginAccountManager public lendingMarginAccountManager;
    IOneClickProxy public oneClickProxy;
    IOneClickNoRekt public oneClickNoRekt;

    address public usdc;

    uint256 public globalTimeToExecution = 30 minutes;

    mapping(uint256 => IHegicTakeProfit.TakeInfo) public tokenIdToTakeInfo;

    constructor(
        address _positionManager,
        address _operationalTreasury,
        address _oneClickProxy,
        address _marginAccountManager,
        address _lendingMarginAccountManager,
        address _oneClickNoRekt,
        address _usdc
    ) {
        positionManager = IPositionsManager(_positionManager);
        operationalTreasury = IOperationalTreasury(_operationalTreasury);
        oneClickProxy = IOneClickProxy(_oneClickProxy);
        marginAccountManager = IMarginAccountManager(_marginAccountManager);
        lendingMarginAccountManager = ILendingMarginAccountManager(
            _lendingMarginAccountManager
        );
        oneClickNoRekt = IOneClickNoRekt(_oneClickNoRekt);
        usdc = _usdc;
    }

    /**
     * @dev Modifier to check if the caller is approved or the owner of the margin account.
     * @param marginAccountID The ID of the margin account.
     */
    modifier onlyApprovedOrOwner(uint marginAccountID) {
        require(
            marginAccountManager.isApprovedOrOwner(msg.sender, marginAccountID),
            "You are not the owner of the token"
        );
        _;
    }

    // OWNER FUNCTIONS //

    function setGlobalTimeToExecution(
        uint256 newGlobalTimeToExecution
    ) external override onlyOwner {
        globalTimeToExecution = newGlobalTimeToExecution;
    }

    // VIEW FUNCTIONS //

    function getPayOffAmount(
        uint256 tokenId
    ) public view override returns (uint256) {
        (, IHegicStrategy strategy, , , ) = operationalTreasury.lockedLiquidity(
            tokenId
        );
        return strategy.payOffAmount(tokenId);
    }

    function getCurrentPrice(
        uint256 tokenId
    ) public view override returns (uint256) {
        (, IHegicStrategy strategy, , , ) = operationalTreasury.lockedLiquidity(
            tokenId
        );
        (, int256 latestPrice, , , ) = AggregatorV3Interface(
            strategy.priceProvider()
        ).latestRoundData();
        require(latestPrice > 0, "invalid price");
        return uint256(latestPrice);
    }

    function getExpirationTime(
        uint256 tokenId
    ) public view override returns (uint256) {
        (, , , , uint32 expiration) = operationalTreasury.lockedLiquidity(
            tokenId
        );
        return uint256(expiration);
    }

    function isOptionActive(
        uint256 tokenId
    ) public view override returns (bool) {
        (
            IOperationalTreasury.LockedLiquidityState state,
            ,
            ,
            ,

        ) = operationalTreasury.lockedLiquidity(tokenId);
        return state == IOperationalTreasury.LockedLiquidityState.Locked;
    }

    function checkTakeProfit(
        uint256 tokenId
    ) public view override returns (bool takeProfitTriggered) {
        IHegicTakeProfit.TakeInfo memory takenInfo = tokenIdToTakeInfo[tokenId];

        if (
            !(getMarginAccountID(tokenId) != 0 &&
                getPayOffAmount(tokenId) > 0 &&
                isOptionActive(tokenId))
        ) {
            return false;
        }

        if (
            block.timestamp > getExpirationTime(tokenId) - globalTimeToExecution
        ) {
            return true;
        }

        uint256 currentPrice = getCurrentPrice(tokenId);

        return
            (takenInfo.upperStopPrice != 0 &&
                currentPrice >= takenInfo.upperStopPrice) ||
            (takenInfo.lowerStopPrice != 0 &&
                currentPrice <= takenInfo.lowerStopPrice);
    }

    function getMarginAccountID(
        uint256 tokenId
    ) public view returns (uint256 marginAccountID) {
        marginAccountID = oneClickProxy.getOptionOwner(
            tokenId,
            address(positionManager)
        );
    }

    function isTokenOwner(
        uint256 marginAccountID,
        uint256 tokenId
    ) public view returns (bool) {
        uint256 marginAccountIDOwner = getMarginAccountID(tokenId);
        if (marginAccountIDOwner == 0) {
            return false;
        }
        return marginAccountIDOwner == marginAccountID;
    }

    // EXTERANAL FUNCTIONS //

    function setTakeProfit(
        uint256 marginAccountID,
        uint256 tokenId,
        TakeInfo calldata takeProfitParams
    ) external onlyApprovedOrOwner(marginAccountID) {
        require(
            isTokenOwner(marginAccountID, tokenId),
            "Caller must be the owner of the token"
        );

        require(
            block.timestamp < getExpirationTime(tokenId),
            "Option expiration date has passed"
        );

        tokenIdToTakeInfo[tokenId] = IHegicTakeProfit.TakeInfo(
            takeProfitParams.upperStopPrice,
            takeProfitParams.lowerStopPrice
        );

        emit TakeProfitSet(
            tokenId,
            msg.sender,
            takeProfitParams.upperStopPrice,
            takeProfitParams.lowerStopPrice
        );
    }

    function deleteTakeProfit(
        uint256 marginAccountID,
        uint256 tokenId
    ) external onlyApprovedOrOwner(marginAccountID) {
        IHegicTakeProfit.TakeInfo memory takenInfo = tokenIdToTakeInfo[tokenId];

        require(
            isTokenOwner(marginAccountID, tokenId),
            "Caller must be the owner of the token"
        );

        require(
            (takenInfo.upperStopPrice == 0 && takenInfo.lowerStopPrice == 0) ==
                false,
            "No token set for take profit"
        );

        delete tokenIdToTakeInfo[tokenId];

        emit TakeProfitDeleted(tokenId);
    }

    function executeTakeProfit(uint256 tokenId) external {
        require(checkTakeProfit(tokenId), "Take profit conditions not met");

        delete tokenIdToTakeInfo[tokenId];

        uint256 marginAccountID = oneClickProxy.getOptionOwner(
            tokenId,
            address(positionManager)
        );
        if (
            lendingMarginAccountManager.isLendingMarginAccount(marginAccountID)
        ) {
            uint[] memory tokenIDArr = new uint[](1);
            tokenIDArr[0] = tokenId;
            oneClickNoRekt.contractMultiExerciseRepayWithdraw(
                marginAccountID,
                tokenIDArr,
                usdc,
                0
            );
        } else {
            oneClickProxy.exercise(
                marginAccountID,
                address(positionManager),
                tokenId
            );
        }

        emit TakeProfitExecuted(tokenId, marginAccountID);
    }
}
