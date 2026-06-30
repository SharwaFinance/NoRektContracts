pragma solidity 0.8.20;

import {IOptionDataStorage} from "../../interfaces/oneClick/IOptionDataStorage.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract OptionDataStorage is IOptionDataStorage, AccessControl {
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    bytes32 public constant ONE_CLICK_PROXY_ROLE =
        keccak256("ONE_CLICK_PROXY_ROLE");

    mapping(address => mapping(uint => uint)) public erc721Owner;
    mapping(address => mapping(uint => uint)) public erc721Type;
    mapping(address => uint[]) public activeOptions;

    // VIEW FUNCTIONS

    function getOptionOwner(
        uint collateralTokenID,
        address token
    ) external view returns (uint) {
        return erc721Owner[token][collateralTokenID];
    }

    function getActiveOptions(
        address token
    ) external view returns (uint[] memory) {
        return activeOptions[token];
    }

    function getERC721Type(
        address token,
        uint tokenId
    ) external view returns (uint) {
        return erc721Type[token][tokenId];
    }

    // ONLY ONE_CLICK_PROXY_ROLE FUNCTIONS

    function setERC721Type(
        address token,
        uint tokenId,
        uint ercType
    ) external onlyRole(ONE_CLICK_PROXY_ROLE) {
        erc721Type[token][tokenId] = ercType;
    }

    function removeERC721Type(
        address token,
        uint tokenId
    ) external onlyRole(ONE_CLICK_PROXY_ROLE) {
        delete erc721Type[token][tokenId];
    }

    function setOptionOwner(
        uint marginAccountID,
        address token,
        uint collateralTokenID
    ) external onlyRole(ONE_CLICK_PROXY_ROLE) {
        erc721Owner[token][collateralTokenID] = marginAccountID;
    }

    function addActiveOption(
        address token,
        uint optionID
    ) external onlyRole(ONE_CLICK_PROXY_ROLE) {
        activeOptions[token].push(optionID);
    }

    function removeActiveOption(
        address token,
        uint optionID
    ) external onlyRole(ONE_CLICK_PROXY_ROLE) {
        uint[] memory options = activeOptions[token];
        for (uint i = 0; i < options.length; i++) {
            if (options[i] == optionID) {
                activeOptions[token][i] = activeOptions[token][
                    activeOptions[token].length - 1
                ];
                activeOptions[token].pop();
                break;
            }
        }
    }
}
