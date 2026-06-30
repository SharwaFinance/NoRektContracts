pragma solidity 0.8.20;

interface ILendingMarginAccountManager {
    function isLendingMarginAccount(uint id) external view returns (bool);
}
