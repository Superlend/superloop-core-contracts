// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/**
 * @title IAccountantModule
 * @author Superlend
 * @notice Interface for accountant module operations including asset management and fee calculations
 * @dev Handles total assets calculation, performance fees, and configuration management
 */
interface IAccountantModule {
    /**
     * @notice Gets the total assets managed by the accountant
     * @return The total amount of assets
     */
    function getTotalAssets() external view returns (uint256);

    /**
     * @notice Calculates the performance fee based on shares and exchange rate
     * @param totalShares The total number of shares
     * @param exchangeRate The current exchange rate
     * @param decimals The number of decimals for the asset
     * @return The calculated performance fee
     */
    function getPerformanceFee(uint256 totalShares, uint256 exchangeRate, uint8 decimals)
        external
        view
        returns (uint256);

    /**
     * @notice Sets the last realized fee exchange rate
     * @param lastRealizedFeeExchangeRate_ The new last realized fee exchange rate
     * @param totalSupply The total supply of the vault
     */
    function setLastRealizedFeeExchangeRate(uint256 lastRealizedFeeExchangeRate_, uint256 totalSupply) external;

    /**
     * @notice Sets the performance fee percentage
     * @param performanceFee_ The new performance fee percentage
     */
    function setPerformanceFee(uint16 performanceFee_) external;

    /**
     * @notice Sets the vault address
     * @param vault_ The address of the vault
     */
    function setVault(address vault_) external;

    /**
     * @notice Gets the performance fee percentage
     * @return The performance fee percentage
     */
    function performanceFee() external view returns (uint16);

    /**
     * @notice Gets the vault address
     * @return The address of the vault
     */
    function vault() external view returns (address);

    /**
     * @notice Gets the last realized fee exchange rate
     * @return The last realized fee exchange rate
     */
    function lastRealizedFeeExchangeRate() external view returns (uint256);
}
