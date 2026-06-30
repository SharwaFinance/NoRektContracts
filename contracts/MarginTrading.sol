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

import {IModularSwapRouter} from "./interfaces/modularSwapRouter/IModularSwapRouter.sol";
import {IMarginAccountManager} from "./interfaces/IMarginAccountManager.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IMarginAccount} from "./interfaces/IMarginAccount.sol";
import {IMarginTrading} from "./interfaces/IMarginTrading.sol";
import {ILiquidityPool} from "./interfaces/ILiquidityPool.sol";

/**
 * @title MarginTrading
 * @notice This contract allows users to manage margin accounts, provide collateral, borrow, and repay tokens.
 * @dev The contract uses modular architecture with separate modules for swap routing, margin account management, and storage.
 * It also includes access control mechanisms for managing roles and permissions.
 * @author 0nika0
 */
contract MarginTrading is IMarginTrading, AccessControl, ReentrancyGuard {
    uint private constant COEFFICIENT_DECIMALS = 1e5;

    address public immutable BASE_TOKEN;

    uint public redCoeff = 1.17 * 1e5;
    uint public swapID = 0;

    IModularSwapRouter public modularSwapRouter;
    IMarginAccountManager public immutable marginAccountManager;
    IMarginAccount public immutable marginAccount;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant ONE_CLICK_PROXY_ROLE =
        keccak256("ONE_CLICK_PROXY_ROLE");

    constructor(
        address _positionsManager,
        address _baseToken,
        address _portfolioLendingStorage
    ) {
        BASE_TOKEN = _baseToken;
        marginAccountManager = IMarginAccountManager(_positionsManager);
        marginAccount = IMarginAccount(_portfolioLendingStorage);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier ensureMarginAccountRatioForDebt(uint marginAccountID) {
        _;
        require(
            getMarginAccountRatioForDebt(marginAccountID) >= redCoeff,
            "Operation rejected due to insufficient margin account ratio"
        );
    }

    // ONLY MANAGER_ROLE FUNCTIONS //

    function setModularSwapRouter(
        IModularSwapRouter newModularSwapRouter
    ) external onlyRole(MANAGER_ROLE) {
        modularSwapRouter = newModularSwapRouter;
        emit UpdateModularSwapRouter(address(newModularSwapRouter));
    }

    function setRedCoeff(uint newRedCoeff) external onlyRole(MANAGER_ROLE) {
        redCoeff = newRedCoeff;
        emit UpdateRedCoeff(newRedCoeff);
    }

    function revokeOneClickProxyRole(
        address account
    ) external onlyRole(MANAGER_ROLE) {
        _revokeRole(ONE_CLICK_PROXY_ROLE, account);
    }

    function revokeLiquidatorRole(
        address account
    ) external onlyRole(MANAGER_ROLE) {
        _revokeRole(LIQUIDATOR_ROLE, account);
    }

    // PUBLIC FUNCTIONS //

    function calculateMarginAccountValue(
        uint marginAccountID
    ) public returns (uint marginAccountValue) {
        (
            IModularSwapRouter.ERC20PositionInfo[] memory erc20Params,
            IModularSwapRouter.ERC721PositionInfo[] memory erc721Params
        ) = prepareTokensParams(marginAccountID, BASE_TOKEN);
        marginAccountValue = modularSwapRouter.calculateTotalPositionValue(
            erc20Params,
            erc721Params
        );
    }

    function calculateMarginAccountValueForDebt(
        uint marginAccountID
    ) public returns (uint marginAccountValue) {
        (
            IModularSwapRouter.ERC20PositionInfo[] memory erc20Params,

        ) = prepareTokensParams(marginAccountID, BASE_TOKEN);
        IModularSwapRouter.ERC721PositionInfo[] memory erc721Params;
        marginAccountValue = modularSwapRouter.calculateTotalPositionValue(
            erc20Params,
            erc721Params
        );
    }

    function calculateMarginAccountValueUSDC(
        uint marginAccountID
    ) public returns (uint marginAccountValue) {
        (
            IModularSwapRouter.ERC20PositionInfo[] memory erc20Params,
            IModularSwapRouter.ERC721PositionInfo[] memory erc721Params
        ) = prepareTokensParams(marginAccountID, BASE_TOKEN);
        marginAccountValue = modularSwapRouter.calculateTotalPositionValueUSDC(
            erc20Params,
            erc721Params
        );
    }

    function calculateDebtWithAccruedInterest(
        uint marginAccountID
    ) public returns (uint debtSizeInUSDC) {
        (
            IModularSwapRouter.ERC20PositionInfo[] memory erc20Params,
            IModularSwapRouter.ERC721PositionInfo[] memory erc721Params
        ) = prepareTokensParamsByDebt(marginAccountID, BASE_TOKEN);
        debtSizeInUSDC += modularSwapRouter.calculateTotalPositionValue(
            erc20Params,
            erc721Params
        );
    }

    function getMarginAccountRatio(uint marginAccountID) public returns (uint) {
        uint marginAccountValue = calculateMarginAccountValue(marginAccountID);
        uint debtWithAccruedInterest = calculateDebtWithAccruedInterest(
            marginAccountID
        );
        return
            _calculatePortfolioRatio(
                marginAccountValue,
                debtWithAccruedInterest
            );
    }

    function getMarginAccountRatioForDebt(
        uint marginAccountID
    ) public returns (uint) {
        uint marginAccountValue = calculateMarginAccountValueForDebt(
            marginAccountID
        );
        uint debtWithAccruedInterest = calculateDebtWithAccruedInterest(
            marginAccountID
        );
        return
            _calculatePortfolioRatio(
                marginAccountValue,
                debtWithAccruedInterest
            );
    }

    // ONLY ONE_CLICK_PROXY_ROLE //

    function provideERC20(
        uint marginAccountID,
        address token,
        uint amount
    ) external nonReentrant onlyRole(ONE_CLICK_PROXY_ROLE) {
        marginAccount.provideERC20(marginAccountID, msg.sender, token, amount);

        emit ProvideERC20(marginAccountID, msg.sender, token, amount);
    }

    function provideERC721(
        uint marginAccountID,
        address token,
        uint collateralTokenID
    ) external nonReentrant onlyRole(ONE_CLICK_PROXY_ROLE) {
        require(
            modularSwapRouter.checkValidityERC721(
                token,
                BASE_TOKEN,
                collateralTokenID
            ),
            "token id is not valid"
        );
        require(
            modularSwapRouter.checkStrategy(
                token,
                BASE_TOKEN,
                collateralTokenID
            ),
            "Invalid strategy"
        );
        marginAccount.provideERC721(
            marginAccountID,
            msg.sender,
            BASE_TOKEN,
            token,
            collateralTokenID
        );

        emit ProvideERC721(
            marginAccountID,
            msg.sender,
            token,
            collateralTokenID
        );
    }

    function withdrawERC20(
        uint marginAccountID,
        address token,
        uint amount
    )
        external
        nonReentrant
        ensureMarginAccountRatioForDebt(marginAccountID)
        onlyRole(ONE_CLICK_PROXY_ROLE)
    {
        require(
            marginAccount.checkERC20Amount(marginAccountID, token, amount),
            "Insufficient token balance for withdrawal"
        );

        marginAccount.withdrawERC20(marginAccountID, token, amount, msg.sender);

        emit WithdrawERC20(marginAccountID, msg.sender, token, amount);
    }

    function withdrawERC721(
        uint marginAccountID,
        address token,
        uint value
    )
        external
        nonReentrant
        ensureMarginAccountRatioForDebt(marginAccountID)
        onlyRole(ONE_CLICK_PROXY_ROLE)
    {
        require(
            marginAccount.checkERC721Value(marginAccountID, token, value),
            "The ERC721 token you are attempting to withdraw is not available for withdrawal"
        );

        marginAccount.withdrawERC721(marginAccountID, token, value, msg.sender);

        emit WithdrawERC721(marginAccountID, msg.sender, token, value);
    }

    function borrow(
        uint marginAccountID,
        address token,
        uint amount
    )
        external
        nonReentrant
        ensureMarginAccountRatioForDebt(marginAccountID)
        onlyRole(ONE_CLICK_PROXY_ROLE)
    {
        require(
            marginAccount.checkLiquidityPool(token),
            "Token is not supported"
        );

        marginAccount.borrow(marginAccountID, token, amount);

        emit Borrow(marginAccountID, msg.sender, token, amount);
    }

    function repay(
        uint marginAccountID,
        address token,
        uint amount
    ) external nonReentrant onlyRole(ONE_CLICK_PROXY_ROLE) {
        marginAccount.repay(marginAccountID, token, amount);

        emit Repay(marginAccountID, msg.sender, token, amount);
    }

    function swap(
        uint marginAccountID,
        address tokenIn,
        address tokenOut,
        uint amountIn,
        uint amountOutMinimum
    )
        external
        nonReentrant
        ensureMarginAccountRatioForDebt(marginAccountID)
        onlyRole(ONE_CLICK_PROXY_ROLE)
    {
        require(
            getMarginAccountRatio(marginAccountID) >= redCoeff,
            "Cannot swap"
        );
        emit Swap(marginAccountID, swapID, tokenIn, tokenOut, amountIn);

        marginAccount.swap(
            marginAccountID,
            swapID,
            tokenIn,
            tokenOut,
            amountIn,
            amountOutMinimum
        );

        swapID++;
    }

    function exercise(
        uint marginAccountID,
        address token,
        uint collateralTokenID
    )
        external
        nonReentrant
        onlyRole(ONE_CLICK_PROXY_ROLE)
    {
        require(
            marginAccount.checkERC721Value(
                marginAccountID,
                token,
                collateralTokenID
            ),
            "You are not allowed to execute this ERC721 token"
        );

        marginAccount.exercise(
            marginAccountID,
            token,
            BASE_TOKEN,
            collateralTokenID,
            msg.sender
        );

        emit Exercise(marginAccountID, token, BASE_TOKEN, collateralTokenID);

        require(
            getMarginAccountRatio(marginAccountID) >= redCoeff,
            "Operation rejected due to insufficient margin account ratio"
        );
    }

    // ONLY LIQUIDATOR_ROLE FUNCTIONS //

    function liquidate(
        uint marginAccountID,
        uint minTotalMarginAccountValue
    ) external nonReentrant onlyRole(LIQUIDATOR_ROLE) {
        uint debt = calculateDebtWithAccruedInterest(marginAccountID);
        require(debt > 0, "Margin Account is debt-free");
        require(
            getMarginAccountRatio(marginAccountID) <= redCoeff,
            "ratio too high"
        );

        uint totalMarginAccountValue = calculateMarginAccountValueUSDC(
            marginAccountID
        );
        require(
            totalMarginAccountValue >= minTotalMarginAccountValue,
            "Slippage is too high"
        );

        marginAccount.liquidate(
            marginAccountID,
            BASE_TOKEN,
            marginAccountManager.ownerOf(marginAccountID),
            msg.sender
        );

        uint256 balance = marginAccount.getErc20ByContract(
            marginAccountID,
            BASE_TOKEN
        );
        marginAccount.withdrawERC20(
            marginAccountID,
            BASE_TOKEN,
            balance,
            marginAccountManager.ownerOf(marginAccountID)
        );

        emit Liquidate(marginAccountID, msg.sender);
    }

    // PRIIVATE FUNCTIONS //

    /**
     * @dev Calculates the margin account ratio.
     * @param marginAccountValue The total value of the margin account.
     * @param debtWithAccruedInterest The total debt with accrued interest.
     * @return marginAccountRatio The calculated margin account ratio.
     */
    function _calculatePortfolioRatio(
        uint marginAccountValue,
        uint debtWithAccruedInterest
    ) private pure returns (uint marginAccountRatio) {
        if (debtWithAccruedInterest == 0) {
            return type(uint256).max;
        }
        marginAccountRatio =
            (marginAccountValue * COEFFICIENT_DECIMALS) /
            debtWithAccruedInterest;
    }

    function prepareTokensParams(
        uint marginAccountID,
        address baseToken
    )
        public
        view
        returns (
            IModularSwapRouter.ERC20PositionInfo[] memory erc20Params,
            IModularSwapRouter.ERC721PositionInfo[] memory erc721Params
        )
    {
        address[] memory availableErc20 = marginAccount.getAvailableErc20();
        address[] memory availableErc721 = marginAccount.getAvailableErc721();
        erc20Params = new IModularSwapRouter.ERC20PositionInfo[](
            availableErc20.length
        );
        erc721Params = new IModularSwapRouter.ERC721PositionInfo[](
            availableErc721.length
        );
        for (uint i; i < availableErc20.length; i++) {
            uint erc20Balance = marginAccount.getErc20ByContract(
                marginAccountID,
                availableErc20[i]
            );
            erc20Params[i] = IModularSwapRouter.ERC20PositionInfo(
                availableErc20[i],
                baseToken,
                erc20Balance
            );
        }

        for (uint i; i < availableErc721.length; i++) {
            uint[] memory erc721TokensByContract = marginAccount
                .getErc721ByContract(marginAccountID, availableErc721[i]);
            erc721Params[i] = IModularSwapRouter.ERC721PositionInfo(
                availableErc721[i],
                baseToken,
                address(0),
                erc721TokensByContract
            );
        }
    }

    function prepareTokensParamsByDebt(
        uint marginAccountID,
        address baseToken
    )
        public
        view
        returns (
            IModularSwapRouter.ERC20PositionInfo[] memory erc20Params,
            IModularSwapRouter.ERC721PositionInfo[] memory erc721Params
        )
    {
        address[] memory availableTokenToLiquidityPool = marginAccount
            .getAvailableTokenToLiquidityPool();
        erc20Params = new IModularSwapRouter.ERC20PositionInfo[](
            availableTokenToLiquidityPool.length
        );
        for (uint i; i < availableTokenToLiquidityPool.length; i++) {
            address liquidityPoolAddress = marginAccount.tokenToLiquidityPool(
                availableTokenToLiquidityPool[i]
            );
            erc20Params[i] = IModularSwapRouter.ERC20PositionInfo(
                availableTokenToLiquidityPool[i],
                baseToken,
                ILiquidityPool(liquidityPoolAddress).getDebtWithAccruedInterest(
                    marginAccountID
                )
            );
        }
    }
}
