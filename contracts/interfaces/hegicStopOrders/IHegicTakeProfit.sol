/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Sharwa.Finance
 * Copyright (C) 2023 Sharwa.Finance
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

interface IHegicTakeProfit {
    // STRUCTS //

    /**
     * @dev Struct representing take profit information for a financial instrument.
     * @notice A `TakeInfo` with zero values indicates an inactive state.
     */
    struct TakeInfo {
        uint256 upperStopPrice; // The upper price threshold at which the take profit order triggers.
        uint256 lowerStopPrice; // The lower price threshold at which the take profit order triggers.
    }

    // OWNER FUNCTIONS //

    /**
     * @dev Updates the global time to execution for all take profit orders.
     * @param newGlobalTimeToExecution The new global time duration, in seconds, before take profit orders are executed.
     * Requirements:
     * - Only the contract owner can set the new global time to execution.
     */
    function setGlobalTimeToExecution(
        uint256 newGlobalTimeToExecution
    ) external;

    // VIEW FUNCTIONS //

    /**
     * @dev Retrieves the payoff amount for a specific token ID.
     *
     * @param tokenId The unique identifier of the token for which the payoff amount is requested.
     *
     * @return The calculated payoff amount for the specified token.
     */
    function getPayOffAmount(uint256 tokenId) external view returns (uint256);

    /**
     * @dev Retrieves the current price for a specific token ID.
     *
     * @param tokenId The unique identifier of the token for which the current price is requested.
     *
     * @return The current price for the specified token in the form of a uint256.
     *
     * Requirements:
     * - The price retrieved must not be zero, indicating a valid price.
     */
    function getCurrentPrice(uint256 tokenId) external view returns (uint256);

    /**
     * @dev Retrieves the expiration time for a specific token ID.
     *
     * @param tokenId The unique identifier of the token for which the expiration time is requested.
     *
     * @return The expiration time for the specified token in the form of a uint256.
     */
    function getExpirationTime(uint256 tokenId) external view returns (uint256);

    /**
     * @dev Checks whether a specific option with the given tokenId is currently active.
     *
     * An active option means that it is in the 'Locked' state within the operational treasury.
     *
     * @param tokenId The unique identifier of the option token being checked.
     *
     * @return A boolean value indicating whether the option is currently active (true) or not (false).
     */
    function isOptionActive(uint256 tokenId) external view returns (bool);

    /**
     * @dev Checks if the take profit conditions for a specific token have been triggered.
     *
     * @param tokenId The unique identifier of the token for which take profit is being checked.
     *
     * @return takeProfitTriggered Boolean indicating whether the take profit conditions have been triggered or not.
     */
    function checkTakeProfit(
        uint256 tokenId
    ) external view returns (bool takeProfitTriggered);

    // EXTERNAL FUNCTIONS //

    /**
     * @dev Sets the take profit conditions for a specific token.
     *
     * @param tokenId The unique identifier of the token for which take profit is being set.
     * @param takeProfitParams A `TakeInfo` struct containing the upper and lower stop prices.
     *
     * Requirements:
     * - The caller must be the owner of the token.
     * - The token's expiration date must not have passed.
     */
    function setTakeProfit(
        uint256 marginAccountID,
        uint256 tokenId,
        TakeInfo calldata takeProfitParams
    ) external;

    /**
     * @dev Deletes the take profit configuration for a specific token.
     *
     * This function allows the owner of a specified token to delete the associated take profit configuration.
     *
     * @param tokenId The unique identifier of the token for which the take profit is being deleted.
     *
     * Requirements:
     * - The caller must be the owner of the token.
     * - A valid take profit configuration must exist for the token.
     */
    function deleteTakeProfit(
        uint256 marginAccountID,
        uint256 tokenId
    ) external;

    /**
     * @dev Executes the take profit for a specific token.
     *
     * This function allows a user to execute the take profit conditions for a specified token.
     * If the take profit conditions are met, the associated action, such as transferring the token and
     * potentially paying off the profit, is executed.
     *
     * @param tokenId The unique identifier of the token for which the take profit is being executed.
     *
     * Requirements:
     * - The take profit conditions must be met for the specified token.
     */
    function executeTakeProfit(uint256 tokenId) external;

    // EVENTS //

    /**
     * @dev An event emitted when a take profit configuration is set for a tokenized option.
     *
     * This event is triggered when a user successfully sets a take profit configuration for a specific tokenized option.
     * It includes details such as the token's unique identifier, upper and lower stop price conditions,
     * which define the range for triggering the take profit, and indicate when the take profit conditions are met.
     *
     * @param tokenId The unique identifier of the token for which the take profit is being set.
     * @param user The address of the user setting the take profit configuration.
     * @param upperStopPrice The upper stop price condition for take profit (greater than or equal to).
     * @param lowerStopPrice The lower stop price condition for take profit (less than or equal to).
     */
    event TakeProfitSet(
        uint256 indexed tokenId,
        address indexed user,
        uint256 upperStopPrice,
        uint256 lowerStopPrice
    );

    /**
     * @dev An event emitted when a take profit configuration is deleted for a tokenized option.
     *
     * This event is triggered when a user successfully deletes the take profit configuration for a specific tokenized option.
     * It includes the unique identifier of the token for which the take profit configuration is deleted.
     *
     * @param tokenId The unique identifier of the token for which the take profit configuration is deleted.
     */
    event TakeProfitDeleted(uint256 indexed tokenId);

    /**
     * @dev An event emitted when a take profit is executed for a tokenized option.
     *
     * This event is triggered when a take profit is successfully executed for a specific tokenized option.
     * It includes the unique identifier of the token for which the take profit is executed.
     *
     * @param tokenId The unique identifier of the token for which the take profit is executed.
     * @param marginAccountID The margin account ID of the user setting the take profit configuration.
     */
    event TakeProfitExecuted(
        uint256 indexed tokenId,
        uint256 indexed marginAccountID
    );
}
