// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IAccountantModule {
    function getTotalAssets() external view returns (uint256);

    function getPerformanceFee(uint256 totalShares, uint256 exchangeRate, uint8 decimals)
        external
        view
        returns (uint256);

    function setLastRealizedFeeExchangeRate(uint256 lastRealizedFeeExchangeRate_) external;
}
