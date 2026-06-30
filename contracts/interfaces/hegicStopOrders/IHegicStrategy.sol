pragma solidity 0.8.20;

interface IHegicStrategy {
    /**
     * @return The address of the price provider.
     */
    function priceProvider() external view returns (address);

    /**
     * @param optionID The ID of the option.
     * @return The profit amount for the specified option.
     */
    function payOffAmount(uint256 optionID) external view returns (uint256);
}
