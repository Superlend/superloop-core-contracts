// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DataTypes} from "../common/DataTypes.sol";

interface VaultRouter {
    function depositWithToken(
        address vault,
        address tokenIn,
        uint256 amountIn,
        DataTypes.ExecuteSwapParams memory swapParams
    ) external returns (uint256);

    function whitelistVault(address vault, bool isWhitelisted) external;

    function whitelistToken(address token, bool isWhitelisted) external;

    function setUniversalDexModule(address _universalDexModule) external;
}
