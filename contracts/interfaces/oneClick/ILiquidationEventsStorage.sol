pragma solidity 0.8.20;

interface ILiquidationEventsStorage {
    function emitLiquidate(uint marginAccountID) external;
}