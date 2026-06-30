// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FlashLoan {
    IERC20 public usdc;
    IERC20 public weth;
    IERC20 public wbtc;

    address[] public availableTokens;

    constructor(address _usdc, address _weth, address _wbtc) {
        usdc = IERC20(_usdc);
        weth = IERC20(_weth);
        wbtc = IERC20(_wbtc);
    }

    function flashLoan(
        address[] calldata tokens,
        address to,
        uint256[] calldata amounts,
        bytes calldata data
    ) external {
        require(
            tokens.length == amounts.length,
            "Tokens and amounts length mismatch"
        );

        uint256[] memory balancesBefore = new uint256[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            balancesBefore[i] = IERC20(tokens[i]).balanceOf(address(this));
            require(
                balancesBefore[i] >= amounts[i],
                "Not enough liquidity for one of the tokens"
            );
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).transfer(to, amounts[i]);
        }

        (bool success, ) = to.call(data);
        require(success, "FlashLoan: Callback failed");

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 balanceAfter = IERC20(tokens[i]).balanceOf(address(this));
            require(
                balanceAfter >= balancesBefore[i],
                "FlashLoan not returned for one of the tokens"
            );
        }
    }
}
