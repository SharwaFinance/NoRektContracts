pragma solidity 0.8.20;

interface IMarginAccountsRatiosData {

    /**
     * @notice Getting the margin account ratio for the marginAccountID array.
     * @param arrMarginAccountID The ID of the margin account.
     * @return arrMarginAccountRatio The margin account ratio array for the marginAccountID array.
     */
    function checkGetMarginAccountRatio(uint[] memory arrMarginAccountID) external returns(uint[] memory arrMarginAccountRatio);

}