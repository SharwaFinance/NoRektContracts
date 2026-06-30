// pragma solidity 0.8.20;

// /**
//  * SPDX-License-Identifier: GPL-3.0-or-later
//  * SharwaFinance
//  * Copyright (C) 2025 SharwaFinance
//  *
//  * This program is free software: you can redistribute it and/or modify
//  * it under the terms of the GNU General Public License as published by
//  * the Free Software Foundation, either version 3 of the License, or
//  * (at your option) any later version.
//  *
//  * This program is distributed in the hope that it will be useful,
//  * but WITHOUT ANY WARRANTY; without even the implied warranty of
//  * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  * GNU General Public License for more details.
//  *
//  * You should have received a copy of the GNU General Public License
//  * along with this program.  If not, see <http://www.gnu.org/licenses/>.
//  **/

// import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// import {StopMarketOrder} from "../StopMarketOrder.sol";
// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import {IQuoter} from "../interfaces/modularSwapRouter/uniswap/IQuoter.sol";


// contract UpkeepStopMarketOrder is 
//     AutomationCompatibleInterface, 
//     Ownable
// {
//     StopMarketOrder public stopMarketOrder;
//     IQuoter public quoter;

//     constructor(
//         StopMarketOrder _stopMarketOrder,
//         IQuoter _quoter
//     ) {
//         stopMarketOrder = _stopMarketOrder;
//         quoter = _quoter;
//     }

//     // OWNER FUNCTIONS //

//     function transferErc20(address token, address to, uint amount) external onlyOwner {
//         ERC20(token).transfer(to, amount);
//     }

//     function setStopMarketOrder(StopMarketOrder newStopMarketOrder) external onlyOwner {
//         stopMarketOrder = newStopMarketOrder;
//     }

//     // EXTERNAL FUNCTIONS // 

//     function checkUpkeep(
//         bytes calldata checkData
//     )
//         external
//         override
//         returns (bool upkeepNeeded, bytes memory performData)
//     {
//         (uint256 lowerBound, uint256 upperBound) = abi.decode(
//             checkData,
//             (uint256, uint256)
//         );

//         uint activeIdOrdersLength = stopMarketOrder.getActiveIdOrdersLength();

//         if (activeIdOrdersLength >= lowerBound && activeIdOrdersLength <= upperBound) {
//             for (uint256 i = lowerBound; i <= activeIdOrdersLength; i++) {
//                 uint orderID = stopMarketOrder.activeIdOrders(i);
//                 (,,,address addressTokenIn,uint amountTokenIn,address addressTokenOut,uint amountTokenOutMinimum,,,,) = stopMarketOrder.allOrders(orderID);
//                 uint amountOut = quoter.quoteExactInput(abi.encodePacked(addressTokenIn, uint24(500), addressTokenOut), amountTokenIn);
//                 if (stopMarketOrder.availableOrderForExecution(stopMarketOrder.activeIdOrders(i)) == 1 && amountOut >= amountTokenOutMinimum) {
//                     upkeepNeeded = true;
//                     performData = abi.encode(orderID);
//                     break;
//                 }
//             }
//         }

//         return (upkeepNeeded, performData);
//     }

//     function performUpkeep(bytes calldata performData) external override {
//         (uint256 orderID) = abi.decode(
//             performData,
//             (uint256)
//         );
//         stopMarketOrder.executeOrder(orderID);
//     }
// }
