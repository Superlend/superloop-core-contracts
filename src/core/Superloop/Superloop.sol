// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {ERC4626Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {ISuperloopModuleRegistry} from "../../interfaces/IModuleRegistry.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {Errors} from "../../common/Errors.sol";
import {SuperloopStorage} from "../lib/SuperLoopStorage.sol";

contract Superloop is ReentrancyGuardUpgradeable, ERC4626Upgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(
        DataTypes.VaultInitData memory data
    ) public initializer {
        __ReentrancyGuard_init();
        __ERC4626_init(IERC20(data.asset));
        __ERC20_init(data.name, data.symbol);
        __Superloop_init(data);
    }

    function __Superloop_init(
        DataTypes.VaultInitData memory data
    ) internal onlyInitializing {
        SuperloopStorage.setSupplyCap(data.supplyCap);
        SuperloopStorage.setFeeManager(data.feeManager);
        SuperloopStorage.setWithdrawManager(data.withdrawManager);
        SuperloopStorage.setCommonPriceOracle(data.commonPriceOracle);
        SuperloopStorage.setVaultAdmin(data.vaultAdmin);
        SuperloopStorage.setTreasury(data.treasury);
        SuperloopStorage.setPerformanceFee(data.performanceFee);
        SuperloopStorage.setSuperloopModuleRegistry(
            data.superloopModuleRegistry
        );

        for (uint256 i = 0; i < data.modules.length; i++) {
            if (
                !ISuperloopModuleRegistry(address(0)).isModuleWhitelisted(
                    data.modules[i]
                )
            ) {
                revert(Errors.INVALID_MODULE);
            }
            SuperloopStorage.setRegisteredModule(data.modules[i], true);
        }
    }

    fallback() external payable {
        // TODO: implement fallback with callbacks logic
        revert("Superloop: fallback not allowed");
    }

    function operate() external {
        // restrictions
        // TODO: implement operate logic
    }

    function totalAssets() public view override returns (uint256) {
        // TODO: implement totalAssets logic

        // have a module called superloopAccountant
        // 1. Take care of last stored exchange rate of the users
        // 2. Take care of totalAssetCalculation

        return 0;
    }

    function maxDeposit(address) public view override returns (uint256) {
        return 0;
    }

    function maxMint(address) public view override returns (uint256) {
        return 0;
    }

    function deposit(
        uint256 assets,
        address receiver
    ) public override nonReentrant returns (uint256) {
        require(assets > 0, Errors.INVALID_AMOUNT);

        // realize performance fee

        // preview deposit

        // require(shares > 0, Errors.INVALID_AMOUNT);

        // _deposit();

        // return shares;

        // uint256 shares = previewDeposit(assets);
        // require(shares > 0, "ERC4626: zero shares mint");
        // _deposit(_msgSender(), receiver, assets, shares);
        // return shares;
        return 0;
    }

    function mint(
        uint256 shares,
        address receiver
    ) public override nonReentrant returns (uint256) {
        return 0;
    }

    /**
     * @dev Withdraws assets by burning shares.
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override nonReentrant returns (uint256) {
        // require(assets > 0, "ERC4626: zero withdraw");
        // require(
        //     assets <= maxWithdraw(owner),
        //     "ERC4626: withdraw more than max"
        // );
        // uint256 shares = previewWithdraw(assets);
        // _withdraw(_msgSender(), receiver, owner, assets, shares);
        // return shares;
        return 0;
    }

    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal override {
        // SafeERC20.safeTransferFrom(
        //     IERC20(asset()),
        //     caller,
        //     address(this),
        //     assets
        // );
        // SuperlendAaveV3StrategyStorage
        //     storage $ = _getSuperlendAaveV3StrategyStorage();
        // IERC20(asset()).approve(address($.pool), assets);
        // $.pool.deposit(asset(), assets, address(this), 0);
        // _mint(receiver, shares);
        // emit Deposit(caller, receiver, assets, shares);
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        // if (caller != owner) {
        //     _spendAllowance(owner, caller, shares);
        // }
        // _burn(owner, shares);
        // SuperlendAaveV3StrategyStorage
        //     storage $ = _getSuperlendAaveV3StrategyStorage();
        // $.pool.withdraw(asset(), assets, address(this));
        // SafeERC20.safeTransfer(IERC20(asset()), receiver, assets);
        // emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function _maxDeposit() internal view returns (uint256) {
        // SuperlendAaveV3StrategyStorage
        //     storage $ = _getSuperlendAaveV3StrategyStorage();
        // DataTypes.ReserveData memory reserveData = $.pool.getReserveData(
        //     asset()
        // );
        // uint256 supplyCap = ReserveConfiguration.getSupplyCap(
        //     reserveData.configuration
        // );
        // uint256 maxAssetsDeposit = type(uint256).max;
        // if (supplyCap != 0) {
        //     uint256 formattedSupplyCap = supplyCap *
        //         (10 **
        //             ReserveConfiguration.getDecimals(
        //                 reserveData.configuration
        //             ));
        //     uint256 totalAssetsSupplied = IAToken(reserveData.aTokenAddress)
        //         .scaledTotalSupply() +
        //         WadRayMath.rayMul(
        //             reserveData.accruedToTreasury,
        //             reserveData.liquidityIndex
        //         );
        //     maxAssetsDeposit = formattedSupplyCap - totalAssetsSupplied;
        // }
        // return maxAssetsDeposit;
    }

    function _decimalsOffset() internal view override returns (uint8) {
        return SuperloopStorage.DECIMALS_OFFSET;
    }
}
