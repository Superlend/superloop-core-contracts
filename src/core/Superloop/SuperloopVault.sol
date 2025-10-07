// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {
    ERC4626Upgradeable,
    ERC20Upgradeable
} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SuperloopStorage} from "../lib/SuperloopStorage.sol";
import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {IAccountantModule} from "../../interfaces/IAccountantModule.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Errors} from "../../common/Errors.sol";
import {PausableUpgradeableEnhanced} from "../../helpers/PausableUpgradeableEnhanced.sol";

abstract contract SuperloopVault is ERC4626Upgradeable, ReentrancyGuardUpgradeable, PausableUpgradeableEnhanced {
    event PerformanceFeeRealized(uint256 sharesMinted, address indexed treasury);

    function __SuperloopVault_init(address asset, string memory name, string memory symbol) internal onlyInitializing {
        __ReentrancyGuard_init();
        __PausableUpgradeableEnhanced_init();
        __ERC4626_init(IERC20(asset));
        __ERC20_init(name, symbol);
    }

    function totalAssets() public view override returns (uint256) {
        SuperloopStorage.SuperloopEssentialRoles storage $ = SuperloopStorage.getSuperloopEssentialRolesStorage();

        uint256 _totalAssets = IAccountantModule($.accountant).getTotalAssets();

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
        return _convertToSharesWithPerformanceFee(assets, Math.Rounding.Floor);
    }

    function previewMint(uint256 shares) public view override returns (uint256) {
        return _convertToAssetsWithPerformanceFee(shares, Math.Rounding.Ceil);
    }

    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        return _convertToSharesWithPerformanceFee(assets, Math.Rounding.Ceil);
    }

    function previewRedeem(uint256 shares) public view override returns (uint256) {
        return _convertToAssetsWithPerformanceFee(shares, Math.Rounding.Floor);
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

    function deposit(uint256 assets, address receiver) public override nonReentrant whenNotPaused returns (uint256) {
        // realize performance fee
        _realizePerformanceFee();

        require(assets > 0, Errors.INVALID_AMOUNT);
        // check supply cap
        require(assets <= maxDeposit(address(0)), Errors.SUPPLY_CAP_EXCEEDED);

        // calculate the cash reserve at curren total assets
        uint256 cashReserveShortfall = _getCashReserveShortfall();
        require(assets <= cashReserveShortfall, Errors.INSUFFICIENT_CASH_SHORTFALL);

        // preview deposit
        uint256 shares = previewDeposit(assets);
        require(shares > 0, Errors.INVALID_SHARES_AMOUNT);
        _deposit(_msgSender(), receiver, assets, shares);

        return shares;
    }

    function mint(uint256 shares, address receiver) public override nonReentrant whenNotPaused returns (uint256) {
        // realize performance fee
        _realizePerformanceFee();

        require(shares > 0, Errors.INVALID_SHARES_AMOUNT);
        require(shares <= maxMint(address(0)), Errors.SUPPLY_CAP_EXCEEDED);

        uint256 assets = previewMint(shares);

        uint256 cashReserveShortfall = _getCashReserveShortfall();
        require(assets <= cashReserveShortfall, Errors.INSUFFICIENT_CASH_SHORTFALL);

        require(assets > 0, Errors.INVALID_AMOUNT);
        _deposit(_msgSender(), receiver, assets, shares);

        return assets;
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        // realize performance fee
        _realizePerformanceFee();

        // check for max withdraw
        require(assets <= maxWithdraw(owner), Errors.INSUFFICIENT_BALANCE);

        uint256 shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        // realize performance fee
        _realizePerformanceFee();

        // check for max redeem
        require(shares <= maxRedeem(owner), Errors.INSUFFICIENT_BALANCE);

        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
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

    function mintShares(address to, uint256 amount) public onlyDepositManager {
        _mint(to, amount);
    }

    function burnSharesAndClaimAssets(uint256 shares, uint256 assets) public onlyWithdrawManager {
        address receiver = _msgSender();
        _burn(receiver, shares);
        SafeERC20.safeTransfer(IERC20(asset()), receiver, assets);
    }

    function _realizePerformanceFee() internal {
        SuperloopStorage.SuperloopEssentialRoles storage $ = SuperloopStorage.getSuperloopEssentialRolesStorage();

        // calculate current exchange rate
        (uint256 exchangeRate, uint8 decimals) = _getCurrentExchangeRate();

        uint256 sharesToMint = _getPerformanceFeeAndShares(exchangeRate, $.accountant, decimals);

        // if vault made profit, take a performance fee
        if (sharesToMint > 0) {
            // mint the shares to the treasury
            _mint($.treasury, sharesToMint);

            // update the last realized fee exchange rate on the accountant module
            (exchangeRate,) = _getCurrentExchangeRate();
            IAccountantModule($.accountant).setLastRealizedFeeExchangeRate(exchangeRate, totalSupply());

            emit PerformanceFeeRealized(sharesToMint, $.treasury);
        }
    }

    function _getPerformanceFeeAndShares(uint256 exchangeRate, address accountant, uint8 decimals)
        internal
        view
        returns (uint256 shares)
    {
        uint256 totalAssetsCached = totalAssets();
        uint256 totalSupplyCached = totalSupply();

        // get performance fee
        uint256 assets = IAccountantModule(accountant).getPerformanceFee(totalSupplyCached, exchangeRate, decimals);

        // calculate how much shares to dilute ie. mint for the treasury as performance fee
        uint256 numerator = (totalSupplyCached + 10 ** _decimalsOffset()) * assets;
        uint256 denominator = totalAssetsCached + 1 - assets;

        if (numerator != 0) {
            shares = numerator / denominator;
        }

        return shares;
    }

    function _getCurrentExchangeRate() internal view returns (uint256, uint8) {
        uint8 decimals = IERC20Metadata(asset()).decimals();
        uint256 assets = 1 * 10 ** decimals;
        return (
            Math.mulDiv(assets, totalAssets() + 1, totalSupply() + 10 ** _decimalsOffset(), Math.Rounding.Floor),
            decimals
        );
    }

    function _convertToSharesWithPerformanceFee(uint256 assets, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        (uint256 exchangeRate, uint8 decimals) = _getCurrentExchangeRate();
        uint256 treasuryShares = _getPerformanceFeeAndShares(
            exchangeRate, SuperloopStorage.getSuperloopEssentialRolesStorage().accountant, decimals
        );
        uint256 _totalSupply = totalSupply() + treasuryShares + 10 ** _decimalsOffset();
        uint256 _totalAssets = totalAssets() + 1;

        uint256 shares = Math.mulDiv(assets, _totalSupply, _totalAssets, rounding);

        return shares;
    }

    function _convertToAssetsWithPerformanceFee(uint256 shares, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        (uint256 exchangeRate, uint8 decimals) = _getCurrentExchangeRate();
        uint256 treasuryShares = _getPerformanceFeeAndShares(
            exchangeRate, SuperloopStorage.getSuperloopEssentialRolesStorage().accountant, decimals
        );
        uint256 _totalSupply = totalSupply() + treasuryShares + 10 ** _decimalsOffset();
        uint256 _totalAssets = totalAssets() + 1;

        uint256 assets = Math.mulDiv(shares, _totalAssets, _totalSupply, rounding);

        return assets;
    }

    function _decimalsOffset() internal pure override returns (uint8) {
        return SuperloopStorage.DECIMALS_OFFSET;
    }

    function _getCashReserveShortfall() internal view returns (uint256) {
        uint256 cashReserveExpected = Math.mulDiv(
            totalAssets(),
            SuperloopStorage.getSuperloopStorage().cashReserve,
            SuperloopStorage.MAX_BPS_VALUE,
            Math.Rounding.Floor
        );
        uint256 cashReserveActual = IERC20(asset()).balanceOf(address(this));
        return cashReserveExpected > cashReserveActual ? cashReserveExpected - cashReserveActual : 0;
    }

    modifier onlyPrivileged() {
        _onlyPrivileged();
        _;
    }

    function _onlyPrivileged() internal view {
        uint256 isPrivileged = SuperloopStorage.getSuperloopEssentialRolesStorage().privilegedAddresses[_msgSender()];
        require(isPrivileged > 0, Errors.CALLER_NOT_PRIVILEGED);
    }

    modifier onlyWithdrawManager() {
        _onlyWithdrawManager();
        _;
    }

    function _onlyWithdrawManager() internal view {
        SuperloopStorage.SuperloopEssentialRoles storage $ = SuperloopStorage.getSuperloopEssentialRolesStorage();
        require($.withdrawManager == _msgSender(), Errors.CALLER_NOT_WITHDRAW_MANAGER);
    }

    modifier onlyDepositManager() {
        _onlyDepositManager();
        _;
    }

    function _onlyDepositManager() internal view {
        SuperloopStorage.SuperloopEssentialRoles storage $ = SuperloopStorage.getSuperloopEssentialRolesStorage();
        require($.depositManager == _msgSender(), Errors.CALLER_NOT_DEPOSIT_MANAGER);
    }
}
