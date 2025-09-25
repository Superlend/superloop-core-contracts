// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {DataTypes} from "./DataTypes.sol";

/**
 * @title Storages
 * @author Superlend
 * @notice Library containing all storage structures used throughout the Superloop protocol
 * @dev Centralized storage definitions for consistent state management across contracts
 */
library Storages {
    /**
     * @notice Storage structure for withdraw manager state
     * @param vault The address of the associated vault
     * @param asset The address of the underlying asset
     * @param nextWithdrawRequestId The next withdrawal request ID to be assigned
     * @param resolvedWithdrawRequestId The ID of the last resolved withdrawal request
     * @param withdrawRequest Mapping from request ID to withdrawal request data
     * @param userWithdrawRequestId Mapping from user address to their withdrawal request ID
     */
    struct WithdrawManagerState {
        address vault;
        address asset;
        uint256 nextWithdrawRequestId;
        uint256 resolvedWithdrawRequestId;
        mapping(uint256 => DataTypes.WithdrawRequestDataLegacy) withdrawRequest;
        mapping(address => uint256) userWithdrawRequestId;
    }

    /**
     * @notice Storage structure for Superloop vault state
     * @param supplyCap The maximum supply cap for the vault
     * @param feeManager The address of the fee manager
     * @param withdrawManager The address of the withdraw manager
     * @param commonPriceOracle The address of the common price oracle
     * @param vaultAdmin The address of the vault admin
     * @param treasury The address of the treasury
     * @param performanceFee The performance fee percentage in basis points
     * @param userLastRealizedFeeExchangeRate Mapping from user address to their last realized fee exchange rate
     * @param registeredModules Mapping from module address to registration status
     */
    struct SuperloopState {
        uint256 supplyCap;
        address feeManager;
        address withdrawManager;
        address commonPriceOracle;
        address vaultAdmin;
        address treasury;
        uint16 performanceFee; // BPS
        mapping(address => uint256) userLastRealizedFeeExchangeRate;
        mapping(address => bool) registeredModules;
    }

    /**
     * @notice Storage structure for Superloop Aave V3 accountant state
     * @param poolAddressesProvider The Aave pool addresses provider
     * @param lendAssets Array of assets available for lending
     * @param borrowAssets Array of assets available for borrowing
     * @param oraclePriceStandard The address of the oracle price standard
     * @param performanceFee The performance fee percentage in basis points
     * @param userLastRealizedFeeExchangeRate Mapping from user address to their last realized fee exchange rate
     */
    struct SuperloopAccountantAaveV3State {
        address poolAddressesProvider;
        address[] lendAssets;
        address[] borrowAssets;
        address oraclePriceStandard;
        uint16 performanceFee; // BPS
        mapping(address => uint256) userLastRealizedFeeExchangeRate;
    }
}
