pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { MockOperationalTreasury } from "./MockOperationTreasury.sol";
import { MockPositionsManager } from "./MockPositionsManager.sol";
import {IHegicStrategy} from "../interfaces/modularSwapRouter/hegic/IHegicStrategy.sol";

contract IProxySellerMock {
    ERC20 public usdcE;
    MockOperationalTreasury public operationalTreasury;
    MockPositionsManager public positionsManager;
    uint public premium;

    constructor(
        ERC20 _usdcE,
        MockOperationalTreasury _operationalTreasury,
        MockPositionsManager _positionsManager
    ) {
        usdcE = _usdcE;
        operationalTreasury = _operationalTreasury;
        positionsManager = _positionsManager;
    }

    function setPremium(uint newPremium) external {
        premium = newPremium;
    }

    function buyWithReferal(
        IHegicStrategy strategy,
        uint256 amount,
        uint256 period,
        bytes[] calldata additional,
        address referrer
    )  external {
        positionsManager.mint(msg.sender);
        usdcE.transferFrom(msg.sender, address(operationalTreasury), premium);
    }
}
