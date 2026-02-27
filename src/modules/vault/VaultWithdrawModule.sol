// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {VaultActionModule} from "./VaultActionModule.sol";

/**
 * @title VaultWithdrawModule
 * @author Superlend
 * @notice Module for withdrawing assets from a vault
 * @dev Extends IERC4626 to provide vault withdraw functionality
 */
contract VaultWithdrawModule is VaultActionModule {
    /**
     * @notice Executes the withdraw operation
     * @param params The parameters for the withdraw operation
     */
    function execute(DataTypes.VaultActionParams memory params) external override onlyExecutionContext {
        uint256 amount =
            params.amount == type(uint256).max ? IERC4626(params.vault).maxWithdraw(address(this)) : params.amount;

        if (amount == 0) return;

        uint256 shares = IERC4626(params.vault).withdraw(amount, address(this), address(this));

        emit VaultWithdrawn(params.vault, amount, shares);
    }
}
