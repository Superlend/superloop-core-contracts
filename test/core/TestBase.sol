// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Superloop} from "../../src/core/Superloop/Superloop.sol";
import {DataTypes} from "../../src/common/DataTypes.sol";
import {SuperloopModuleRegistry} from "../../src/core/ModuleRegistry/ModuleRegistry.sol";
import {AaveV3FlashloanModule} from "../../src/modules/AaveV3FlashloanModule.sol";
import {AaveV3CallbackHandler} from "../../src/modules/AaveV3CallbackHandler.sol";
import {AaveV3EmodeModule} from "../../src/modules/AaveV3EmodeModule.sol";
import {AaveV3SupplyModule} from "../../src/modules/AaveV3SupplyModule.sol";
import {AaveV3WithdrawModule} from "../../src/modules/AaveV3WithdrawModule.sol";
import {AaveV3BorrowModule} from "../../src/modules/AaveV3BorrowModule.sol";
import {AaveV3RepayModule} from "../../src/modules/AaveV3RepayModule.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {UniversalDexModule} from "../../src/modules/UniversalDexModule.sol";
import {AccountantAaveV3} from "../../src/core/Accountant/AccountantAaveV3.sol";
import {WithdrawManager} from "../../src/core/WithdrawManager.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TestBase is Test {
    address public constant ST_XTZ = 0x01F07f4d78d47A64F4C3B2b65f513f15Be6E1854;
    address public constant XTZ = 0xc9B53AB2679f573e480d01e0f49e2B5CFB7a3EAb;
    address public constant AAVE_V3_POOL_ADDRESSES_PROVIDER = 0x5ccF60c7E10547c5389E9cBFf543E5D0Db9F4feC;
    address public constant AAVE_V3_POOL_DATA_PROVIDER = 0x99e8269dDD5c7Af0F1B3973A591b47E8E001BCac;
    address public constant AAVE_V3_PRICE_ORACLE = 0xeCF313dE38aA85EF618D06D1A602bAa917D62525;
    address public constant POOL = 0x3bD16D195786fb2F509f2E2D7F69920262EF114D;
    address public constant XTZ_WHALE = 0x008ae222661B6A42e3A097bd7AAC15412829106b;
    address public constant STXTZ_WHALE = 0x65142dEC2969f1a3083Ad31541Ef4B73871C8C9B;
    uint256 public constant PERFORMANCE_FEE = 2000; // 20%

    address public admin;
    address public treasury;

    SuperloopModuleRegistry public moduleRegistry;
    Superloop public superloop;
    AaveV3FlashloanModule public flashloanModule;
    AaveV3CallbackHandler public callbackHandler;
    AaveV3SupplyModule public supplyModule;
    AaveV3WithdrawModule public withdrawModule;
    AaveV3BorrowModule public borrowModule;
    AaveV3RepayModule public repayModule;
    UniversalDexModule public dexModule;
    AccountantAaveV3 public accountantAaveV3;
    WithdrawManager public withdrawManager;

    address public mockModule;
    AaveV3EmodeModule public emodeModule;
    IPoolDataProvider public poolDataProvider;
    IPool public pool;

    function setUp() public virtual {
        vm.createSelectFork("etherlink");
        admin = makeAddr("admin");
        treasury = makeAddr("treasury");

        vm.startPrank(admin);
        moduleRegistry = new SuperloopModuleRegistry();
        mockModule = makeAddr("mockModule");
        moduleRegistry.setModule("MockModule", mockModule);
        poolDataProvider = IPoolDataProvider(AAVE_V3_POOL_DATA_PROVIDER);
        pool = IPool(POOL);
        vm.stopPrank();

        vm.label(admin, "admin");
        vm.label(treasury, "treasury");
        vm.label(mockModule, "mockModule");
        vm.label(address(moduleRegistry), "moduleRegistry");
        vm.label(XTZ, "XTZ");
        vm.label(ST_XTZ, "ST_XTZ");
        vm.label(AAVE_V3_POOL_ADDRESSES_PROVIDER, "AAVE_V3_POOL_ADDRESSES_PROVIDER");
        vm.label(AAVE_V3_POOL_DATA_PROVIDER, "AAVE_V3_POOL_DATA_PROVIDER");
        vm.label(AAVE_V3_PRICE_ORACLE, "AAVE_V3_PRICE_ORACLE");
        vm.label(POOL, "POOL");
        vm.label(XTZ_WHALE, "XTZ_WHALE");
        vm.label(STXTZ_WHALE, "STXTZ_WHALE");
        vm.label(address(poolDataProvider), "poolDataProvider");
        vm.label(address(pool), "pool");
    }

    function _deployModules() internal {
        flashloanModule = new AaveV3FlashloanModule(AAVE_V3_POOL_ADDRESSES_PROVIDER);
        moduleRegistry.setModule("AaveV3FlashloanModule", address(flashloanModule));
        callbackHandler = new AaveV3CallbackHandler();
        moduleRegistry.setModule("AaveV3CallbackHandler", address(callbackHandler));
        emodeModule = new AaveV3EmodeModule(AAVE_V3_POOL_ADDRESSES_PROVIDER);
        moduleRegistry.setModule("AaveV3EmodeModule", address(emodeModule));
        supplyModule = new AaveV3SupplyModule(AAVE_V3_POOL_ADDRESSES_PROVIDER);
        moduleRegistry.setModule("AaveV3SupplyModule", address(supplyModule));
        withdrawModule = new AaveV3WithdrawModule(AAVE_V3_POOL_ADDRESSES_PROVIDER);
        moduleRegistry.setModule("AaveV3WithdrawModule", address(withdrawModule));
        borrowModule = new AaveV3BorrowModule(AAVE_V3_POOL_ADDRESSES_PROVIDER);
        moduleRegistry.setModule("AaveV3BorrowModule", address(borrowModule));
        repayModule = new AaveV3RepayModule(AAVE_V3_POOL_ADDRESSES_PROVIDER);
        moduleRegistry.setModule("AaveV3RepayModule", address(repayModule));
        dexModule = new UniversalDexModule();
        moduleRegistry.setModule("UniversalDexModule", address(dexModule));

        vm.label(address(flashloanModule), "flashloanModule");
        vm.label(address(callbackHandler), "callbackHandler");
        vm.label(address(emodeModule), "emodeModule");
        vm.label(address(supplyModule), "supplyModule");
        vm.label(address(withdrawModule), "withdrawModule");
        vm.label(address(borrowModule), "borrowModule");
        vm.label(address(repayModule), "repayModule");
        vm.label(address(dexModule), "dexModule");
    }

    function _deployAccountant(address vault) internal {
        address[] memory lendAssets = new address[](1);
        lendAssets[0] = ST_XTZ;
        address[] memory borrowAssets = new address[](1);
        borrowAssets[0] = XTZ;

        DataTypes.AaveV3AccountantModuleInitData memory initData = DataTypes.AaveV3AccountantModuleInitData({
            poolAddressesProvider: AAVE_V3_POOL_ADDRESSES_PROVIDER,
            lendAssets: lendAssets,
            borrowAssets: borrowAssets,
            performanceFee: uint16(PERFORMANCE_FEE),
            vault: vault
        });

        AccountantAaveV3 accountantAaveV3Implementation = new AccountantAaveV3();
        ProxyAdmin proxyAdmin = new ProxyAdmin(address(this));

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(accountantAaveV3Implementation),
            address(proxyAdmin),
            abi.encodeWithSelector(AccountantAaveV3.initialize.selector, initData)
        );

        accountantAaveV3 = AccountantAaveV3(address(proxy));
    }

    function _deployWithdrawManager(address vault) internal {
        WithdrawManager withdrawManagerImplementation = new WithdrawManager();
        ProxyAdmin proxyAdmin = new ProxyAdmin(address(this));

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(withdrawManagerImplementation),
            address(proxyAdmin),
            abi.encodeWithSelector(WithdrawManager.initialize.selector, vault)
        );

        withdrawManager = WithdrawManager(address(proxy));
    }
}
