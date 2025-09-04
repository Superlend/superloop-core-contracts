// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IAaveV3AccountantPlugin {
    /**
     * @notice Gets the total assets managed by the accountant
     * @param vault The address of the vault
     * @return The total amount of assets
     */
    function getTotalAssets(address vault) external view returns (uint256);

    /**
     * @notice Sets the pool addresses provider
     * @param poolAddressesProvider_ The address of the pool addresses provider
     */
    function setPoolAddressesProvider(address poolAddressesProvider_) external;

    /**
     * @notice Sets the lend assets configuration
     * @param lendAssets_ Array of lend asset addresses
     */
    function setLendAssets(address[] memory lendAssets_) external;

    /**
     * @notice Sets the borrow assets configuration
     * @param borrowAssets_ Array of borrow asset addresses
     */
    function setBorrowAssets(address[] memory borrowAssets_) external;

    /**
     * @notice Gets the pool addresses provider
     * @return The address of the pool addresses provider
     */
    function poolAddressesProvider() external view returns (address);

    /**
     * @notice Gets the lend assets configuration
     * @return Array of lend asset addresses
     */
    function lendAssets() external view returns (address[] memory);

    /**
     * @notice Gets the borrow assets configuration
     * @return Array of borrow asset addresses
     */
    function borrowAssets() external view returns (address[] memory);
}
