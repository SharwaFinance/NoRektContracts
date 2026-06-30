pragma solidity 0.8.20;

interface IOptionDataStorage {
    function getOptionOwner(
        uint collateralTokenID,
        address token
    ) external view returns (uint);

    function setOptionOwner(
        uint marginAccountID,
        address token,
        uint optionOwner
    ) external;

    function addActiveOption(address token, uint optionID) external;

    function removeActiveOption(address token, uint optionID) external;

    function getActiveOptions(
        address token
    ) external view returns (uint[] memory);

    function getERC721Type(
        address token,
        uint tokenId
    ) external view returns (uint);

    function setERC721Type(address token, uint tokenId, uint ercType) external;

    function removeERC721Type(address token, uint tokenId) external;
}
