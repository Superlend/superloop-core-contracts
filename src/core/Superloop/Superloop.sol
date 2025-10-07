// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {Errors} from "../../common/Errors.sol";
import {SuperloopStorage} from "../lib/SuperloopStorage.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISuperloopModuleRegistry} from "../../interfaces/IModuleRegistry.sol";
import {SuperloopActions} from "./SuperloopActions.sol";
import {SuperloopVault} from "./SuperloopVault.sol";
import {SuperloopBase} from "./SuperloopBase.sol";

/**
 * @title Superloop
 * @author Superlend
 * @notice Main Superloop vault contract combining vault, actions, and base functionality
 * @dev Extends ERC4626 with module execution, callback handling, and asset management capabilities
 */
contract Superloop is SuperloopVault, SuperloopActions, SuperloopBase {
    /**
     * @notice Emitted when excess assets are skimmed from the vault
     * @param asset The address of the skimmed asset
     * @param amount The amount of assets skimmed
     * @param treasury The address of the treasury that received the assets
     */
    event AssetSkimmed(address indexed asset, uint256 amount, address indexed treasury);

    /**
     * @notice Constructor to disable initializers for implementation contract
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the Superloop vault with the provided configuration
     * @param data The vault initialization data containing all necessary parameters
     */
    function initialize(DataTypes.VaultInitData memory data) public initializer {
        __SuperloopVault_init(data.asset, data.name, data.symbol);
        __Superloop_init(data);
    }

    /**
     * @notice Internal initialization function for Superloop-specific configuration
     * @param data The vault initialization data
     */
    function __Superloop_init(DataTypes.VaultInitData memory data) internal onlyInitializing {
        SuperloopStorage.setSupplyCap(data.supplyCap);
        SuperloopStorage.setSuperloopModuleRegistry(data.superloopModuleRegistry);

        for (uint256 i = 0; i < data.modules.length; i++) {
            if (!ISuperloopModuleRegistry(data.superloopModuleRegistry).isModuleWhitelisted(data.modules[i])) {
                revert(Errors.INVALID_MODULE);
            }
            SuperloopStorage.setRegisteredModule(data.modules[i], true);
        }

        SuperloopStorage.setAccountantModule(data.accountant);
        SuperloopStorage.setWithdrawManagerModule(data.withdrawManager);
        SuperloopStorage.setDepositManager(data.depositManager);
        SuperloopStorage.setVaultAdmin(data.vaultAdmin);
        SuperloopStorage.setTreasury(data.treasury);
        SuperloopStorage.setCashReserve(data.cashReserve);
        SuperloopStorage.setVaultOperator(data.vaultOperator);

        _setPrivilegedAddress(data.vaultAdmin, true);
        _setPrivilegedAddress(data.treasury, true);
        _setPrivilegedAddress(data.withdrawManager, true);
        _setPrivilegedAddress(data.depositManager, true);
        _setPrivilegedAddress(data.vaultOperator, true);
    }

    /**
     * @notice Executes module operations (restricted to privileged addresses)
     * @param moduleExecutionData Array of module execution data
     */
    function operate(DataTypes.ModuleExecutionData[] memory moduleExecutionData)
        external
        whenNotFrozen
        onlyVaultOperatorOrVaultAdmin
    {
        _operate(moduleExecutionData);
    }

    /**
     * @notice Skims excess tokens from the vault (restricted to vault admin)
     * @param asset_ The address of the asset to skim (cannot be the vault's primary asset)
     */
    function skim(address asset_) public whenNotFrozen onlyVaultOperatorOrVaultAdmin {
        require(asset_ != asset(), Errors.INVALID_SKIM_ASSET);
        uint256 balance = IERC20(asset_).balanceOf(address(this));
        SafeERC20.safeTransfer(IERC20(asset_), SuperloopStorage.getSuperloopEssentialRolesStorage().treasury, balance);

        emit AssetSkimmed(asset_, balance, SuperloopStorage.getSuperloopEssentialRolesStorage().treasury);
    }

    /**
     * @notice Pauses or unpauses the vault
     * @param isPaused_ The boolean value to set the pause state to
     */
    function setPause(bool isPaused_) external onlyVaultAdmin {
        if (isPaused_) {
            _pause();
        } else {
            _unpause();
        }
    }

    /**
     * @notice Freezes or unfreezes the vault
     * @param isFrozen_ The boolean value to set the freeze state to
     */
    function setFrozen(bool isFrozen_) external onlyVaultAdmin {
        if (isFrozen_) {
            _freeze();
        } else {
            _unfreeze();
        }
    }

    function realizePerformanceFee() external {
        _realizePerformanceFee();
    }

    /**
     * @notice Fallback function to handle callback operations
     * @return The result of the callback execution
     */
    fallback(bytes calldata) external returns (bytes memory) {
        if (SuperloopStorage.isInExecutionContext()) {
            return _handleCallback();
        } else {
            return _handleFallback();
        }
    }

    /**
     * @notice Receives ETH sent to the vault
     * @dev This function allows the vault to receive and operate with ETH
     *      - WETH wrapping operations via WrapModule
     *      - Unwrap operations via UnwrapModule     *
     */
    receive() external payable {
        // ETH is accepted but should be managed through modules
        // This allows for WETH wrapping, unwrapping and other ETH-based operations
    }

    /**
     * @notice Internal function to handle callback execution
     * @return The result of the callback execution
     */
    function _handleCallback() internal returns (bytes memory) {
        address handler =
            SuperloopStorage.getSuperloopStorage().callbackHandlers[keccak256(abi.encodePacked(msg.sender, msg.sig))];
        require(handler != address(0), Errors.CALLBACK_HANDLER_NOT_FOUND);

        bytes memory data = Address.functionCall(handler, msg.data);

        if (data.length == 0) {
            return abi.encode(false);
        }

        (DataTypes.CallbackData memory calls, bool success) = abi.decode(data, (DataTypes.CallbackData, bool));
        if (calls.executionData.length != 0) {
            DataTypes.ModuleExecutionData[] memory moduleExecutionData =
                abi.decode(calls.executionData, (DataTypes.ModuleExecutionData[]));

            Superloop(payable(address(this))).operateSelf(moduleExecutionData);
        }

        if (calls.amountToApprove > 0) {
            SafeERC20.forceApprove(IERC20(calls.asset), calls.addressToApprove, calls.amountToApprove);
        }

        return abi.encode(success);
    }

    function _handleFallback() internal returns (bytes memory) {
        /**
         *  4 => selector
         *  32 => encodedId
         *  32 => callType
         */
        if (msg.data.length < 68) {
            return abi.encode(false);
        }

        (bytes32 encodedId, DataTypes.CallType callType) = abi.decode(msg.data[4:4 + 64], (bytes32, DataTypes.CallType));
        bytes32 key = keccak256(abi.encodePacked(msg.sig, encodedId, callType));
        address handler = SuperloopStorage.getSuperloopStorage().fallbackHandlers[key];
        require(handler != address(0), Errors.FALLBACK_HANDLER_NOT_FOUND);

        bytes memory returnData = abi.encode(true);
        if (callType == DataTypes.CallType.CALL) {
            bytes memory _returnData = Address.functionCall(handler, msg.data);
            if (_returnData.length > 0) {
                returnData = _returnData;
            }
        } else {
            bytes memory _returnData = Address.functionDelegateCall(handler, msg.data);
            if (_returnData.length > 0) {
                returnData = _returnData;
            }
        }

        return returnData;
    }

    modifier onlyVaultOperatorOrVaultAdmin() {
        _onlyVaultOperatorOrVaultAdmin();
        _;
    }

    function _onlyVaultOperatorOrVaultAdmin() internal view {
        SuperloopStorage.SuperloopEssentialRoles storage $ = SuperloopStorage.getSuperloopEssentialRolesStorage();
        require(
            $.vaultOperator == _msgSender() || $.vaultAdmin == _msgSender(),
            Errors.CALLER_NOT_VAULT_OPERATOR_OR_VAULT_ADMIN
        );
    }
}
