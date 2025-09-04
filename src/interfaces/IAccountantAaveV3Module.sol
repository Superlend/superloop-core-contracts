// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IAccountantModule} from "./IAccountantModule.sol";

/**
 * @title IAccountantAaveV3Module
 * @author Superlend
 * @notice Interface for accountant module operations including asset management and fee calculations
 * @dev Handles total assets calculation, performance fees, and configuration management
 */
interface IAccountantAaveV3Module is IAccountantModule {
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
