// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {
    ERC4626Upgradeable,
    ERC20Upgradeable
} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC20Metadata, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {ISuperloopModuleRegistry} from "../../interfaces/IModuleRegistry.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {Errors} from "../../common/Errors.sol";
import {SuperloopStorage} from "../lib/SuperLoopStorage.sol";
import {IAccountantModule} from "../../interfaces/IAccountantModule.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {SuperloopActions} from "./SuperloopActions.sol";
import {SuperloopVault} from "./SuperloopVault.sol";
import {SuperloopBase} from "./SuperloopBase.sol";

contract Superloop is SuperloopVault, SuperloopActions, SuperloopBase {
    constructor() {
        _disableInitializers();
    }

    function initialize(DataTypes.VaultInitData memory data) public initializer {
        __SuperloopVault_init(data.asset, data.name, data.symbol);
        __Superloop_init(data);
    }

    function __Superloop_init(DataTypes.VaultInitData memory data) internal onlyInitializing {
        SuperloopStorage.setSupplyCap(data.supplyCap);
        SuperloopStorage.setSuperloopModuleRegistry(data.superloopModuleRegistry);

        for (uint256 i = 0; i < data.modules.length; i++) {
            if (!ISuperloopModuleRegistry(address(0)).isModuleWhitelisted(data.modules[i])) {
                revert(Errors.INVALID_MODULE);
            }
            SuperloopStorage.setRegisteredModule(data.modules[i], true);
        }

        SuperloopStorage.setAccountantModule(data.accountantModule);
        SuperloopStorage.setWithdrawManagerModule(data.withdrawManagerModule);
        SuperloopStorage.setVaultAdmin(data.vaultAdmin);
        SuperloopStorage.setTreasury(data.treasury);
        SuperloopStorage.setPrivilegedAddress(data.vaultAdmin, true);
        SuperloopStorage.setPrivilegedAddress(data.treasury, true);
        SuperloopStorage.setPrivilegedAddress(data.withdrawManagerModule, true);
    }

    fallback() external {
        if (SuperloopStorage.isInExecutionContext()) {
            _handleCallback();
        }
    }

    function _handleCallback() internal {
        address handler =
            SuperloopStorage.getSuperloopStorage().callbackHandlers[keccak256(abi.encodePacked(msg.sender, msg.sig))];
        require(handler != address(0), Errors.CALLBACK_HANDLER_NOT_FOUND);

        bytes memory data = Address.functionCall(handler, msg.data);

        if (data.length == 0) {
            return;
        }

        DataTypes.CallbackData memory calls = abi.decode(data, (DataTypes.CallbackData));
        DataTypes.ModuleExecutionData[] memory moduleExecutionData =
            abi.decode(calls.executionData, (DataTypes.ModuleExecutionData[]));

        Superloop(payable(address(this))).operateSelf(moduleExecutionData);

        SafeERC20.forceApprove(IERC20(calls.asset), calls.addressToApprove, calls.amountToApprove);
    }
}
