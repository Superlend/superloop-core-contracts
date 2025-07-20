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
import {ISuperloopModuleRegistry} from "../interfaces/IModuleRegistry.sol";
import {DataTypes} from "../common/DataTypes.sol";
import {Errors} from "../common/Errors.sol";
import {SuperloopStorage} from "./lib/SuperLoopStorage.sol";
import {IAccountantModule} from "../interfaces/IAccountantModule.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

contract Superloop is ReentrancyGuardUpgradeable, ERC4626Upgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(DataTypes.VaultInitData memory data) public initializer {
        __ReentrancyGuard_init();
        __ERC4626_init(IERC20(data.asset));
        __ERC20_init(data.name, data.symbol);
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

    fallback() external payable {
        // TODO: implement fallback with callbacks logic
        revert("Superloop: fallback not allowed");
    }

    function operate() external pure {
        // TODO : handle execution context and upate in dex module

        // restrictions
        // TODO: implement operate logic
    }

    function totalAssets() public view override returns (uint256) {
        SuperloopStorage.SuperloopEssentialRoles storage $ = SuperloopStorage.getSuperloopEssentialRolesStorage();

        uint256 _totalAssets = IAccountantModule($.accountantModule).getTotalAssets();

        return _totalAssets;
    }

    function maxDeposit(address) public view override returns (uint256) {
        SuperloopStorage.SuperloopState storage $ = SuperloopStorage.getSuperloopStorage();

        uint256 totalAssetsCached = totalAssets();

        if ($.supplyCap == 0) {
            return type(uint256).max;
        } else if (totalAssetsCached > $.supplyCap) {
            return 0;
        } else {
            return $.supplyCap - totalAssetsCached;
        }
    }

    function previewDeposit(uint256 assets) public view override returns (uint256) {
        return _convertToSharesWithPerformanceFee(assets);
    }

    function previewMint(uint256 shares) public view override returns (uint256) {
        return _convertToAssetsWithPerformanceFee(shares);
    }

    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        return _convertToSharesWithPerformanceFee(assets);
    }

    function previewRedeem(uint256 shares) public view override returns (uint256) {
        return _convertToAssetsWithPerformanceFee(shares);
    }

    function maxMint(address) public view override returns (uint256) {
        uint256 maxDepositCached = maxDeposit(address(0));
        if (maxDepositCached == 0) {
            return 0;
        } else if (maxDepositCached == type(uint256).max) {
            return type(uint256).max;
        } else {
            return previewDeposit(maxDepositCached);
        }
    }

    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256) {
        // realize performance fee
        _realizePerformanceFee();

        require(assets > 0, Errors.INVALID_AMOUNT);
        // check supply cap
        require(totalSupply() + assets <= maxDeposit(address(0)), Errors.SUPPLY_CAP_EXCEEDED);

        // preview deposit
        uint256 shares = previewDeposit(assets);
        require(shares > 0, Errors.INVALID_SHARES_AMOUNT);
        _deposit(_msgSender(), receiver, assets, shares);

        return shares;
    }

    function mint(uint256 shares, address receiver) public override nonReentrant returns (uint256) {
        // realize performance fee
        _realizePerformanceFee();

        require(shares > 0, Errors.INVALID_SHARES_AMOUNT);
        require(shares <= maxMint(address(0)), Errors.SUPPLY_CAP_EXCEEDED);

        uint256 assets = previewMint(shares);
        require(assets > 0, Errors.INVALID_AMOUNT);
        _deposit(_msgSender(), receiver, assets, shares);

        return assets;
    }

    function withdraw(uint256 assets, address receiver, address owner) public override nonReentrant returns (uint256) {
        // realize performance fee
        _realizePerformanceFee();

        // check for max withdraw
        require(assets <= maxWithdraw(owner), Errors.INSUFFICIENT_BALANCE);

        uint256 shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) public override nonReentrant returns (uint256) {
        // realize performance fee
        _realizePerformanceFee();

        // check for max redeem
        require(shares <= maxRedeem(owner), Errors.INSUFFICIENT_BALANCE);

        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    function _decimalsOffset() internal pure override returns (uint8) {
        return SuperloopStorage.DECIMALS_OFFSET;
    }

    function transfer(address to, uint256 amount)
        public
        override(ERC20Upgradeable, IERC20)
        onlyPrivileged
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override(ERC20Upgradeable, IERC20)
        onlyPrivileged
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
    }

    function _realizePerformanceFee() internal {
        SuperloopStorage.SuperloopEssentialRoles storage $ = SuperloopStorage.getSuperloopEssentialRolesStorage();

        // calculate current exchange rate
        uint256 exchangeRate = _getCurrentExchangeRate();

        uint256 sharesToMint = _getPerformanceFeeAndShares(exchangeRate, $.accountantModule);

        // mint the shares to the treasury
        _mint($.treasury, sharesToMint);

        // update the last realized fee exchange rate on the accountant module via delegate call
        IAccountantModule($.accountantModule).setLastRealizedFeeExchangeRate(exchangeRate);
    }

    function _getCurrentExchangeRate() internal view returns (uint256) {
        uint256 assets = 1 * 10 ** IERC20Metadata(asset()).decimals();
        return Math.mulDiv(assets, totalAssets() + 1, totalSupply() + 10 ** _decimalsOffset(), Math.Rounding.Floor);
    }

    function _getPerformanceFeeAndShares(uint256 exchangeRate, address accountantModule)
        internal
        view
        returns (uint256 shares)
    {
        // get performance fee
        uint256 assets = IAccountantModule(accountantModule).getPerformanceFee(totalAssets(), exchangeRate);

        // calculate how much shares to dilute ie. mint for the treasury as performance fee
        uint256 totalAssetsCached = totalAssets();
        uint256 totalSupplyCached = totalSupply();
        uint256 denominator = totalAssetsCached - assets;
        uint256 numerator = (totalAssetsCached * totalSupplyCached) - (totalSupplyCached * denominator);
        shares = numerator / denominator;

        return shares;
    }

    function _convertToSharesWithPerformanceFee(uint256 assets) internal view returns (uint256) {
        uint256 treasuryShares = _getPerformanceFeeAndShares(
            _getCurrentExchangeRate(), SuperloopStorage.getSuperloopEssentialRolesStorage().accountantModule
        );
        uint256 _totalSupply = totalSupply() + treasuryShares + 10 ** _decimalsOffset();
        uint256 _totalAssets = totalAssets() + 1;

        uint256 shares = Math.mulDiv(assets, _totalSupply, _totalAssets, Math.Rounding.Floor);

        return shares;
    }

    function _convertToAssetsWithPerformanceFee(uint256 shares) internal view returns (uint256) {
        uint256 treasuryShares = _getPerformanceFeeAndShares(
            _getCurrentExchangeRate(), SuperloopStorage.getSuperloopEssentialRolesStorage().accountantModule
        );
        uint256 _totalSupply = totalSupply() + treasuryShares + 10 ** _decimalsOffset();
        uint256 _totalAssets = totalAssets() + 1;

        uint256 assets = Math.mulDiv(shares, _totalAssets, _totalSupply, Math.Rounding.Ceil);

        return assets;
    }

    modifier onlyPrivileged() {
        _onlyPrivileged();
        _;
    }

    function _onlyPrivileged() internal view {
        SuperloopStorage.SuperloopEssentialRoles storage $ = SuperloopStorage.getSuperloopEssentialRolesStorage();
        require($.privilegedAddresses[_msgSender()], Errors.CALLER_NOT_PRIVILEGED);
    }
}
