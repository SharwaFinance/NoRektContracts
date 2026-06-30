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

import {UniswapModuleBase, ISwapRouter, IQuoter, ERC20} from "./UniswapModuleBase.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";

/**
 * @title UniswapModuleWithChainlink
 * @dev A module for managing token swaps and liquidity positions using Uniswap.
 * @notice This contract provides functions to facilitate token swaps and manage liquidity on Uniswap.
 * It uses AccessControl for role-based access management and integrates with Uniswap's swap router and quoter.
 * @author 0nika0
 */
contract UniswapModuleWithChainlink is UniswapModuleBase {
    uint256 private constant GRACE_PERIOD_TIME = 3600;
    uint private constant COEFFICIENT_DECIMALS = 1e5;

    address public dataFeed;
    address public sequencerUptimeFeed;

    uint public priceUpdateThreshold = 3600;

    uint256 public slippagePercent = 0.3 * 1e5;

    error SequencerDown();
    error GracePeriodNotOver();
    error PriceDataIsStale();

    event SlippagePercentUpdated(uint256 newSlippagePercent);

    constructor(
        address _marginAccount,
        address _tokenInContract,
        uint24 _poolFee,
        address _tokenOutContract,
        address _dataFeed,
        address _sequencerUptimeFeed,
        ISwapRouter _swapRouter,
        IQuoter _quoter
    )
        UniswapModuleBase(
            _marginAccount,
            _tokenInContract,
            _poolFee,
            _tokenOutContract,
            _swapRouter,
            _quoter
        )
    {
        dataFeed = _dataFeed;
        sequencerUptimeFeed = _sequencerUptimeFeed;
    }

    // ONLY MANAGER_ROLE FUNTIONS //

    function setPriceUpdateThreshold(
        uint newPriceUpdateThreshold
    ) external onlyRole(MANAGER_ROLE) {
        priceUpdateThreshold = newPriceUpdateThreshold;
    }

    /**
     * @notice Sets the slippagePercent parameter.
     * @param newSlippagePercent New slippage percent (in bps).
     */
    function setSlippagePercent(
        uint256 newSlippagePercent
    ) external onlyRole(MANAGER_ROLE) {
        require(
            newSlippagePercent <= COEFFICIENT_DECIMALS,
            "slippage too high"
        );
        slippagePercent = newSlippagePercent;
        emit SlippagePercentUpdated(newSlippagePercent);
    }

    // VIEW FUNCTIONS //

    function getPositionValue(
        uint256 amountIn
    ) external override returns (uint amountOut) {
        require(dataFeed != address(0), "invalid module");
        uint latestPrice = getChainlinkDataFeedLatestAnswer();
        uint tokenInDecimals = ERC20(tokenInContract).decimals();
        uint tokenOutDecimals = ERC20(tokenOutContract).decimals();
        uint chainlinkDecimals = AggregatorV3Interface(dataFeed).decimals();
        require(chainlinkDecimals > tokenOutDecimals, "invalid tokenOut");
        uint diffDecimals = chainlinkDecimals - tokenOutDecimals;

        return
            (amountIn * latestPrice) /
            (10 ** tokenInDecimals) /
            (10 ** diffDecimals);
    }

    function getChainlinkDataFeedLatestAnswer() public view returns (uint) {
        (
            ,
            /*uint80 roundID*/ int256 answer,
            uint256 startedAt /*uint256 updatedAt*/ /*uint80 answeredInRound*/,
            ,

        ) = AggregatorV2V3Interface(sequencerUptimeFeed).latestRoundData();

        bool isSequencerUp = answer == 0;
        if (!isSequencerUp) {
            revert SequencerDown();
        }

        uint256 timeSinceUp = block.timestamp - startedAt;
        if (timeSinceUp <= GRACE_PERIOD_TIME) {
            revert GracePeriodNotOver();
        }

        (
            ,
            /*uint80 roundID*/ int data,
            ,
            /*uint startedAt*/ uint updatedAt /*uint80 answeredInRound*/,

        ) = AggregatorV3Interface(dataFeed).latestRoundData();

        require(data > 0, "invalid price");

        if (updatedAt < block.timestamp - priceUpdateThreshold) {
            revert PriceDataIsStale();
        }

        return uint256(data);
    }

    /**
     * @notice Prepares the parameters for an exact input swap.
     * Uses Chainlink price feed to estimate the expected amountOut and applies slippage.
     * @param amount The amount of input tokens.
     * @return params The prepared ExactInputParams struct.
     */
    function prepareInputParams(
        uint256 amount
    )
        internal
        view
        override
        returns (ISwapRouter.ExactInputParams memory params)
    {
        uint256 expectedAmountOut = _getPositionValueView(amount);
        uint256 slippage = (expectedAmountOut * slippagePercent) /
            COEFFICIENT_DECIMALS;
        uint256 amountOutMinimum = expectedAmountOut > slippage
            ? expectedAmountOut - slippage
            : 0;
        params = ISwapRouter.ExactInputParams({
            path: path,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amount,
            amountOutMinimum: amountOutMinimum
        });
    }

    /**
     * @notice Prepares the parameters for an exact output swap.
     * Uses Chainlink price feed to estimate the expected amountIn and applies slippage.
     * @param amount The amount of output tokens.
     * @return params The prepared ExactOutputParams struct.
     */
    function prepareOutputParams(
        uint256 amount
    )
        internal
        view
        override
        returns (ISwapRouter.ExactOutputParams memory params)
    {
        uint256 expectedAmountIn = _getInputPositionValueView(amount);
        uint256 slippage = (expectedAmountIn * slippagePercent) /
            COEFFICIENT_DECIMALS;
        uint256 amountInMaximum = expectedAmountIn + slippage;
        params = ISwapRouter.ExactOutputParams({
            path: path,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: amount,
            amountInMaximum: amountInMaximum
        });
    }

    /**
     * @dev Internal view version of getPositionValue (for slippage math)
     */
    function _getPositionValueView(
        uint256 amountIn
    ) internal view returns (uint amountOut) {
        require(dataFeed != address(0), "invalid module");
        uint latestPrice = getChainlinkDataFeedLatestAnswer();
        uint tokenInDecimals = ERC20(tokenInContract).decimals();
        uint tokenOutDecimals = ERC20(tokenOutContract).decimals();
        uint chainlinkDecimals = AggregatorV3Interface(dataFeed).decimals();
        require(chainlinkDecimals > tokenOutDecimals, "invalid tokenOut");
        uint diffDecimals = chainlinkDecimals - tokenOutDecimals;

        return
            (amountIn * latestPrice) /
            (10 ** tokenInDecimals) /
            (10 ** diffDecimals);
    }

    /**
     * @dev Internal view that estimates needed input for a fixed output (output * price reverse)
     */
    function _getInputPositionValueView(
        uint256 amountOut
    ) internal view returns (uint amountIn) {
        require(dataFeed != address(0), "invalid module");
        uint latestPrice = getChainlinkDataFeedLatestAnswer();
        uint tokenInDecimals = ERC20(tokenInContract).decimals();
        uint tokenOutDecimals = ERC20(tokenOutContract).decimals();
        uint chainlinkDecimals = AggregatorV3Interface(dataFeed).decimals();
        require(chainlinkDecimals > tokenOutDecimals, "invalid tokenOut");
        uint diffDecimals = chainlinkDecimals - tokenOutDecimals;

        return
            (amountOut * (10 ** tokenInDecimals) * (10 ** diffDecimals)) /
            latestPrice;
    }
}
