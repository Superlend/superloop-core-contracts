// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IAccountantModule {
    function getTotalAssets() external view returns (uint256);

    function getPerformanceFee(uint256 totalShares, uint256 exchangeRate, uint8 decimals)
        external
        view
        returns (uint256);

    function setLastRealizedFeeExchangeRate(uint256 lastRealizedFeeExchangeRate_) external;

    function setPoolAddressesProvider(address poolAddressesProvider_) external;

    function setLendAssets(address[] memory lendAssets_) external;

    function setBorrowAssets(address[] memory borrowAssets_) external;

    function setPerformanceFee(uint16 performanceFee_) external;

    function setVault(address vault_) external;

    function poolAddressesProvider() external view returns (address);

    function lendAssets() external view returns (address[] memory);

    function borrowAssets() external view returns (address[] memory);

    function performanceFee() external view returns (uint16);

    function vault() external view returns (address);

    function lastRealizedFeeExchangeRate() external view returns (uint256);
}
