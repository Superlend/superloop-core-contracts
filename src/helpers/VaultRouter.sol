// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IUniversalDexModule} from "../interfaces/IUniversalDexModule.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Errors} from "../common/Errors.sol";
import {DataTypes} from "../common/DataTypes.sol";

contract VaultRouter is Ownable {
    mapping(address => bool) public supportedVaults;
    mapping(address => bool) public supportedTokens;
    IUniversalDexModule public universalDexModule;

    constructor(address[] memory _supportedVaults, address[] memory _supportedTokens, address _universalDexModule)
        Ownable(_msgSender())
    {
        for (uint256 i = 0; i < _supportedVaults.length; i++) {
            supportedVaults[_supportedVaults[i]] = true;
        }

        for (uint256 i = 0; i < _supportedTokens.length; i++) {
            supportedTokens[_supportedTokens[i]] = true;
        }

        universalDexModule = IUniversalDexModule(_universalDexModule);
    }

    function depositWithToken(
        address vault,
        address tokenIn,
        uint256 amountIn,
        DataTypes.ExecuteSwapParams memory swapParams
    ) external returns (uint256) {
        require(supportedVaults[vault], Errors.VAULT_NOT_WHITELISTED);
        require(supportedTokens[tokenIn], Errors.TOKEN_NOT_WHITELISTED);

        address vaultAsset = IERC4626(vault).asset();
        SafeERC20.safeTransferFrom(IERC20(tokenIn), _msgSender(), address(this), amountIn);

        if (vaultAsset == tokenIn) {
            SafeERC20.forceApprove(IERC20(tokenIn), vault, amountIn);
            uint256 _shares = IERC4626(vault).deposit(amountIn, _msgSender());
            return _shares;
        }

        SafeERC20.forceApprove(IERC20(tokenIn), address(universalDexModule), amountIn);
        uint256 amountOut = universalDexModule.executeAndExit(swapParams, address(this));

        SafeERC20.forceApprove(IERC20(vaultAsset), vault, amountOut);
        uint256 shares = IERC4626(vault).deposit(amountOut, _msgSender());
        return shares;
    }

    function whitelistVault(address vault, bool isWhitelisted) external onlyOwner {
        supportedVaults[vault] = isWhitelisted;
    }

    function whitelistToken(address token, bool isWhitelisted) external onlyOwner {
        supportedTokens[token] = isWhitelisted;
    }

    function setUniversalDexModule(address _universalDexModule) external onlyOwner {
        universalDexModule = IUniversalDexModule(_universalDexModule);
    }
}
