// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IUniversalDexModule} from "../interfaces/IUniversalDexModule.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Errors} from "../common/Errors.sol";
import {DataTypes} from "../common/DataTypes.sol";
import {IDepositManager} from "../interfaces/IDepositManager.sol";

/**
 * @title VaultRouter
 * @author Superlend
 * @notice Router contract for vault deposits with optional token swapping
 * @dev Handles deposits into vaults with automatic token conversion when needed
 */
contract VaultRouter is Ownable {
    /**
     * @notice Emitted when a vault is whitelisted or unwhitelisted
     * @param vault The address of the vault
     * @param isWhitelisted True if the vault is whitelisted, false if it is unwhitelisted
     */
    event VaultWhitelisted(address indexed vault, bool isWhitelisted);

    /**
     * @notice Emitted when a token is whitelisted or unwhitelisted
     * @param token The address of the token
     * @param isWhitelisted True if the token is whitelisted, false if it is unwhitelisted
     */
    event TokenWhitelisted(address indexed token, bool isWhitelisted);

    /**
     * @notice Emitted when a deposit manager is whitelisted or unwhitelisted
     * @param depositManager The address of the deposit manager
     * @param isWhitelisted True if the deposit manager is whitelisted, false if it is unwhitelisted
     */
    event DepositManagerWhitelisted(address indexed depositManager, bool isWhitelisted);

    /**
     * @notice Mapping of supported vault addresses to their whitelist status
     */
    mapping(address => bool) public supportedVaults;

    /**
     * @notice Mapping of supported token addresses to their whitelist status
     */
    mapping(address => bool) public supportedTokens;

    /**
     * @notice Mapping of supported deposit manager addresses to their whitelist status
     */
    mapping(address => bool) public supportedDepositManagers;

    /**
     * @notice The universal DEX module for token swaps
     */
    IUniversalDexModule public universalDexModule;

    /**
     * @notice Constructor to initialize the vault router
     * @param _supportedVaults Array of initially supported vault addresses
     * @param _supportedTokens Array of initially supported token addresses
     * @param _universalDexModule The address of the universal DEX module
     * @param _supportedDepositManagers Array of initially supported deposit manager addresses
     */
    constructor(
        address[] memory _supportedVaults,
        address[] memory _supportedTokens,
        address _universalDexModule,
        address[] memory _supportedDepositManagers
    ) Ownable(_msgSender()) {
        for (uint256 i = 0; i < _supportedVaults.length; i++) {
            supportedVaults[_supportedVaults[i]] = true;

            emit VaultWhitelisted(_supportedVaults[i], true);
        }

        for (uint256 i = 0; i < _supportedTokens.length; i++) {
            supportedTokens[_supportedTokens[i]] = true;

            emit TokenWhitelisted(_supportedTokens[i], true);
        }

        for (uint256 i = 0; i < _supportedDepositManagers.length; i++) {
            supportedDepositManagers[_supportedDepositManagers[i]] = true;

            emit DepositManagerWhitelisted(_supportedDepositManagers[i], true);
        }

        universalDexModule = IUniversalDexModule(_universalDexModule);
    }

    /**
     * @notice Deposits tokens into a vault with optional swap functionality
     * @param vault The address of the target vault
     * @param tokenIn The address of the input token
     * @param amountIn The amount of input tokens to deposit
     * @param swapParams Parameters for executing a swap if needed
     */
    function depositWithToken(
        address vault,
        address depositManager,
        address tokenIn,
        uint256 amountIn,
        DataTypes.DepositType depositType,
        DataTypes.ExecuteSwapParams memory swapParams
    ) external {
        require(supportedVaults[vault], Errors.VAULT_NOT_WHITELISTED);
        require(supportedTokens[tokenIn], Errors.TOKEN_NOT_WHITELISTED);
        require(supportedDepositManagers[depositManager], Errors.DEPOSIT_MANAGER_NOT_WHITELISTED);

        address vaultAsset = IERC4626(vault).asset();
        SafeERC20.safeTransferFrom(IERC20(tokenIn), _msgSender(), address(this), amountIn);

        if (vaultAsset == tokenIn) {
            _handleDeposit(vault, depositManager, tokenIn, amountIn, depositType);
            return;
        }

        SafeERC20.forceApprove(IERC20(tokenIn), address(universalDexModule), amountIn);
        uint256 amountOut = universalDexModule.executeAndExit(swapParams, address(this));

        _handleDeposit(vault, depositManager, vaultAsset, amountOut, depositType);
    }

    /**
     * @notice Adds or removes a vault from the whitelist (restricted to owner)
     * @param vault The address of the vault to whitelist/unwhitelist
     * @param isWhitelisted True to whitelist, false to remove from whitelist
     */
    function whitelistVault(address vault, bool isWhitelisted) external onlyOwner {
        supportedVaults[vault] = isWhitelisted;

        emit VaultWhitelisted(vault, isWhitelisted);
    }

    /**
     * @notice Adds or removes a token from the whitelist (restricted to owner)
     * @param token The address of the token to whitelist/unwhitelist
     * @param isWhitelisted True to whitelist, false to remove from whitelist
     */
    function whitelistToken(address token, bool isWhitelisted) external onlyOwner {
        supportedTokens[token] = isWhitelisted;

        emit TokenWhitelisted(token, isWhitelisted);
    }

    /**
     * @notice Adds or removes a deposit manager from the whitelist (restricted to owner)
     * @param depositManager The address of the deposit manager to whitelist/unwhitelist
     * @param isWhitelisted True to whitelist, false to remove from whitelist
     */
    function whitelistDepositManager(address depositManager, bool isWhitelisted) external onlyOwner {
        supportedDepositManagers[depositManager] = isWhitelisted;

        emit DepositManagerWhitelisted(depositManager, isWhitelisted);
    }

    /**
     * @notice Sets the universal DEX module address (restricted to owner)
     * @param _universalDexModule The address of the universal DEX module
     */
    function setUniversalDexModule(address _universalDexModule) external onlyOwner {
        universalDexModule = IUniversalDexModule(_universalDexModule);
    }

    /**
     * @notice Handles the deposit based on the deposit type
     * @param vault The address of the vault
     * @param depositManager The address of the deposit manager
     * @param tokenIn The address of the input token
     * @param amountIn The amount of input tokens to deposit
     * @param depositType The type of deposit
     */
    function _handleDeposit(
        address vault,
        address depositManager,
        address tokenIn,
        uint256 amountIn,
        DataTypes.DepositType depositType
    ) internal {
        if (depositType == DataTypes.DepositType.INSTANT) {
            _instantDeposit(vault, tokenIn, amountIn);
        } else {
            _requestedDeposit(depositManager, tokenIn, amountIn);
        }
    }

    /**
     * @notice Handles the instant deposit
     * @param vault The address of the vault
     * @param tokenIn The address of the input token
     * @param amountIn The amount of input tokens to deposit
     */
    function _instantDeposit(address vault, address tokenIn, uint256 amountIn) internal {
        SafeERC20.forceApprove(IERC20(tokenIn), vault, amountIn);
        IERC4626(vault).deposit(amountIn, _msgSender());
    }

    /**
     * @notice Handles the requested deposit
     * @param depositManager The address of the deposit manager
     * @param tokenIn The address of the input token
     * @param amountIn The amount of input tokens to deposit
     */
    function _requestedDeposit(address depositManager, address tokenIn, uint256 amountIn) internal {
        SafeERC20.forceApprove(IERC20(tokenIn), depositManager, amountIn);
        IDepositManager(depositManager).requestDeposit(amountIn, _msgSender());
    }
}
