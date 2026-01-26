// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {console} from "forge-std/Test.sol";
import {TestEnv} from "./TestEnv.sol";
import {Vm} from "forge-std/Vm.sol";
import {Superloop} from "../../src/core/Superloop/Superloop.sol";
import {DataTypes} from "../../src/common/DataTypes.sol";
import {SuperloopModuleRegistry} from "../../src/core/ModuleRegistry/ModuleRegistry.sol";
import {AaveV3FlashloanModule} from "../../src/modules/aave/AaveV3FlashloanModule.sol";
import {AaveV3CallbackHandler} from "../../src/modules/callback/AaveV3CallbackHandler.sol";
import {AaveV3EmodeModule} from "../../src/modules/aave/AaveV3EmodeModule.sol";
import {AaveV3SupplyModule} from "../../src/modules/aave/AaveV3SupplyModule.sol";
import {AaveV3WithdrawModule} from "../../src/modules/aave/AaveV3WithdrawModule.sol";
import {AaveV3BorrowModule} from "../../src/modules/aave/AaveV3BorrowModule.sol";
import {AaveV3RepayModule} from "../../src/modules/aave/AaveV3RepayModule.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {UniversalDexModule} from "../../src/modules/dex/UniversalDexModule.sol";
import {AccountantAaveV3} from "../../src/core/Accountant/aaveV3Accountant/AccountantAaveV3.sol";
import {WithdrawManager} from "../../src/core/WithdrawManager/WithdrawManager.sol";
import {DepositManager} from "../../src/core/DepositManager/DepositManager.sol";
import {DepositManagerCallbackHandler} from "../../src/modules/callback/DepositManagerCallbackHandler.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UniversalAccountant} from "../../src/core/Accountant/universalAccountant/UniversalAccountant.sol";
import {AaveV3AccountantPlugin} from "../../src/plugins/Accountant/AaveV3AccountantPlugin.sol";
import {WithdrawManagerCallbackHandler} from "../../src/modules/callback/WithdrawManagerCallbackHandler.sol";
import {UnwrapModule} from "../../src/modules/helper/UnwrapModule.sol";
import {WrapModule} from "../../src/modules/helper/WrapModule.sol";
import {AaveV3PreliquidationFallbackHandler} from "../../src/modules/fallback/AaveV3PreliquidationFallbackHandler.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {HyperliquidStakeModule} from "../../src/modules/stake/hyperliquid/HyperliquidStakeModule.sol";
import {KinetiqStakeModule} from "../../src/modules/stake/hyperliquid/KinetiqStakeModule.sol";
import {HyperbeatStakingModule} from "../../src/modules/stake/hyperliquid/HyperbeatStakingModule.sol";
import {VaultSupplyModule} from "../../src/modules/vault/VaultSupplyModule.sol";
import {VaultWithdrawModule} from "../../src/modules/vault/VaultWithdrawModule.sol";

abstract contract TestBase is TestEnv {
    // address public constant AAVE_V3_POOL_ADDRESSES_PROVIDER =
    //     0x5ccF60c7E10547c5389E9cBFf543E5D0Db9F4feC;
    // address public constant AAVE_V3_POOL_DATA_PROVIDER =
    //     0x99e8269dDD5c7Af0F1B3973A591b47E8E001BCac;
    // address public constant AAVE_V3_PRICE_ORACLE =
    //     0xeCF313dE38aA85EF618D06D1A602bAa917D62525;
    // address public constant POOL = 0x3bD16D195786fb2F509f2E2D7F69920262EF114D;
    // address public constant XTZ_WHALE =
    //     0x008ae222661B6A42e3A097bd7AAC15412829106b;
    // address public constant STXTZ_WHALE =
    //     0x65142dEC2969f1a3083Ad31541Ef4B73871C8C9B;
    // address public constant USDT_WHALE =
    //     0x998098A1B2E95e2b8f15360676428EdFd976861f;
    // address public constant USDT = 0x2C03058C8AFC06713be23e58D2febC8337dbfE6A;
    // address public constant USDC = 0x796Ea11Fa2dD751eD01b53C372fFDB4AAa8f00F9;
    // address public constant ROUTER = 0xbfe9C246A5EdB4F021C8910155EC93e7CfDaB7a0;
    // address public constant USDC_WHALE =
    //     0xd03bfdF9B26DB1e6764724d914d7c3d18106a9Fb;
    // address public constant POOL_CONFIGURATOR =
    //     0x30F6880Bb1cF780a49eB4Ef64E64585780AAe060;
    // address public constant POOL_ADMIN =
    //     0x669bd328f6C494949Ed9fB2dc8021557A6Dd005f;

    uint256 public constant WAD = 10 ** 18;
    uint256 public constant BPS = 10000;
    bytes32 id = bytes32("1");
    uint256 public constant PRE_LLTV = (5000 * WAD) / BPS;
    uint256 public constant PRE_CF1 = (2000 * WAD) / BPS;
    uint256 public constant PRE_CF2 = (4000 * WAD) / BPS;
    uint256 public constant PRE_IF1 = ((BPS + 50) * WAD) / BPS;
    uint256 public constant PRE_IF2 = ((80 + BPS) * WAD) / BPS;
    uint256 public LLTV = (9600 * WAD) / BPS;

    TestEnvironment public environment;

    address public admin;
    address public treasury;

    SuperloopModuleRegistry public moduleRegistry;
    Superloop public superloop;
    AaveV3FlashloanModule public flashloanModule;
    DepositManagerCallbackHandler public depositManagerCallbackHandler;
    WithdrawManagerCallbackHandler public withdrawManagerCallbackHandler;
    AaveV3PreliquidationFallbackHandler public preliquidationFallbackHandler;
    AaveV3CallbackHandler public callbackHandler;
    AaveV3SupplyModule public supplyModule;
    AaveV3WithdrawModule public withdrawModule;
    AaveV3BorrowModule public borrowModule;
    AaveV3RepayModule public repayModule;
    UniversalDexModule public dexModule;
    AccountantAaveV3 public accountantAaveV3;
    UniversalAccountant public accountant;
    WithdrawManager public withdrawManager;
    UnwrapModule public unwrapModule;
    WrapModule public wrapModule;
    DepositManager public depositManager;

    Superloop public superloopBtc;
    DepositManager public depositManagerBtc;
    WithdrawManager public withdrawManagerBtc;
    UniversalAccountant public accountantBtc;
    AccountantAaveV3 public accountantAaveV3Btc;

    VaultSupplyModule public vaultSupplyModule;
    VaultWithdrawModule public vaultWithdrawModule;

    address public mockModule;
    AaveV3EmodeModule public emodeModule;
    IPoolDataProvider public poolDataProvider;
    IPool public pool;

    HyperliquidStakeModule public hyperliquidStakeModule;
    KinetiqStakeModule public kinetiqStakeModule;
    HyperbeatStakingModule public hyperbeatStakingModule;

    function setUp() public virtual override {
        super.setUp();

        uint256 envIndex = 2; // TODO: move this to config
        environment = testEnvironments[envIndex];

        vm.createSelectFork(environment.chainName);
        admin = makeAddr("admin");
        treasury = makeAddr("treasury");

        vm.startPrank(admin);
        moduleRegistry = new SuperloopModuleRegistry();
        mockModule = makeAddr("mockModule");
        moduleRegistry.setModule("MockModule", mockModule);
        poolDataProvider = IPoolDataProvider(environment.poolDataProvider);
        pool = IPool(environment.pool);
        vm.stopPrank();

        vm.label(admin, "admin");
        vm.label(treasury, "treasury");
        vm.label(mockModule, "mockModule");
        vm.label(address(moduleRegistry), "moduleRegistry");
        for (uint256 i = 0; i < environment.lendAssets.length; i++) {
            string memory symbol = IERC20Metadata(environment.lendAssets[i]).symbol();
            vm.label(environment.lendAssets[i], symbol);
        }
        for (uint256 i = 0; i < environment.borrowAssets.length; i++) {
            string memory symbol = IERC20Metadata(environment.borrowAssets[i]).symbol();
            vm.label(environment.borrowAssets[i], symbol);
        }
        vm.label(environment.poolAddressesProvider, "AAVE_V3_POOL_ADDRESSES_PROVIDER");
        vm.label(environment.poolDataProvider, "AAVE_V3_POOL_DATA_PROVIDER");
        vm.label(environment.priceOracle, "AAVE_V3_PRICE_ORACLE");
        vm.label(environment.pool, "POOL");
        vm.label(environment.vaultAssetWhale, "VAULT_ASSET_WHALE");
        vm.label(environment.stablecoin, "STABLECOIN");
        vm.label(environment.stablecoinWhale, "STABLECOIN_WHALE");
        // vm.label(STXTZ_WHALE, "STXTZ_WHALE");
    }

    function _deployModules() internal {
        flashloanModule = new AaveV3FlashloanModule(environment.poolAddressesProvider);
        moduleRegistry.setModule("AaveV3FlashloanModule", address(flashloanModule));

        callbackHandler = new AaveV3CallbackHandler();
        moduleRegistry.setModule("AaveV3CallbackHandler", address(callbackHandler));

        emodeModule = new AaveV3EmodeModule(environment.poolAddressesProvider);
        moduleRegistry.setModule("AaveV3EmodeModule", address(emodeModule));

        supplyModule = new AaveV3SupplyModule(environment.poolAddressesProvider);
        moduleRegistry.setModule("AaveV3SupplyModule", address(supplyModule));

        withdrawModule = new AaveV3WithdrawModule(environment.poolAddressesProvider);
        moduleRegistry.setModule("AaveV3WithdrawModule", address(withdrawModule));

        borrowModule = new AaveV3BorrowModule(environment.poolAddressesProvider);
        moduleRegistry.setModule("AaveV3BorrowModule", address(borrowModule));

        repayModule = new AaveV3RepayModule(environment.poolAddressesProvider);
        moduleRegistry.setModule("AaveV3RepayModule", address(repayModule));

        dexModule = new UniversalDexModule();
        moduleRegistry.setModule("UniversalDexModule", address(dexModule));

        depositManagerCallbackHandler = new DepositManagerCallbackHandler();
        moduleRegistry.setModule("DepositManagerCallbackHandler", address(depositManagerCallbackHandler));

        withdrawManagerCallbackHandler = new WithdrawManagerCallbackHandler();
        moduleRegistry.setModule("WithdrawManagerCallbackHandler", address(withdrawManagerCallbackHandler));

        unwrapModule = new UnwrapModule(environment.vaultAsset);
        moduleRegistry.setModule("UnwrapModule", address(unwrapModule));

        wrapModule = new WrapModule(environment.vaultAsset);
        moduleRegistry.setModule("WrapModule", address(wrapModule));

        vaultSupplyModule = new VaultSupplyModule();
        moduleRegistry.setModule("VaultSupplyModule", address(vaultSupplyModule));

        vaultWithdrawModule = new VaultWithdrawModule();
        moduleRegistry.setModule("VaultWithdrawModule", address(vaultWithdrawModule));

        vm.label(address(flashloanModule), "flashloanModule");
        vm.label(address(callbackHandler), "callbackHandler");
        vm.label(address(emodeModule), "emodeModule");
        vm.label(address(supplyModule), "supplyModule");
        vm.label(address(withdrawModule), "withdrawModule");
        vm.label(address(borrowModule), "borrowModule");
        vm.label(address(repayModule), "repayModule");
        vm.label(address(dexModule), "dexModule");
        vm.label(address(depositManagerCallbackHandler), "depositManagerCallbackHandler");
        vm.label(address(withdrawManagerCallbackHandler), "withdrawManagerCallbackHandler");
        vm.label(address(vaultSupplyModule), "vaultSupplyModule");
        vm.label(address(vaultWithdrawModule), "vaultWithdrawModule");
    }

    function _deployHyperliquidStakeModule() internal {
        if (environment.chainId != 999) return;

        wrapModule = new WrapModule(environment.vaultAsset);
        moduleRegistry.setModule("WrapModule", address(wrapModule));
        unwrapModule = new UnwrapModule(environment.vaultAsset);
        moduleRegistry.setModule("UnwrapModule", address(unwrapModule));
        hyperliquidStakeModule = new HyperliquidStakeModule(overseer_hyperevm);
        moduleRegistry.setModule("HyperliquidStakeModule", address(hyperliquidStakeModule));
        kinetiqStakeModule = new KinetiqStakeModule(stakingManager_hyperevm);
        moduleRegistry.setModule("KinetiqStakeModule", address(kinetiqStakeModule));
        hyperbeatStakingModule = new HyperbeatStakingModule(stakingCore_hyperevm);
        moduleRegistry.setModule("HyperbeatStakingModule", address(hyperbeatStakingModule));
    }

    function _deployAccountant(address vault, address[] memory lendAssets, address[] memory borrowAssets)
        internal
        returns (UniversalAccountant)
    {
        DataTypes.AaveV3AccountantPluginModuleInitData memory accountantPluginInitData = DataTypes
            .AaveV3AccountantPluginModuleInitData({
            poolAddressesProvider: environment.poolAddressesProvider,
            lendAssets: lendAssets,
            borrowAssets: borrowAssets
        });
        address accountantPlugin = address(new AaveV3AccountantPlugin(accountantPluginInitData));

        address[] memory registeredAccountants = new address[](1);
        registeredAccountants[0] = accountantPlugin;

        // deploy accountant
        DataTypes.UniversalAccountantModuleInitData memory initData = DataTypes.UniversalAccountantModuleInitData({
            registeredAccountants: registeredAccountants,
            performanceFee: uint16(PERFORMANCE_FEE),
            vault: address(vault)
        });

        address accountantImplementation = address(new UniversalAccountant());
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            accountantImplementation,
            address(this),
            abi.encodeWithSelector(UniversalAccountant.initialize.selector, initData)
        );

        accountant = UniversalAccountant(address(proxy));
        return accountant;
    }

    function _deployDepositManager(address vault) internal returns (DepositManager) {
        DepositManager depositManagerImplementation = new DepositManager();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(depositManagerImplementation),
            address(this),
            abi.encodeWithSelector(DepositManager.initialize.selector, vault)
        );

        depositManager = DepositManager(address(proxy));
        return depositManager;
    }

    function _deployWithdrawManager(address vault) internal returns (WithdrawManager) {
        WithdrawManager withdrawManagerImplementation = new WithdrawManager();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(withdrawManagerImplementation),
            address(this),
            abi.encodeWithSelector(WithdrawManager.initialize.selector, vault)
        );
        withdrawManager = WithdrawManager(address(proxy));
        return withdrawManager;
    }

    function _deployPreliquidationFallbackHandler(address vault) internal {
        preliquidationFallbackHandler = new AaveV3PreliquidationFallbackHandler(
            environment.poolAddressesProvider,
            vault,
            2,
            8,
            DataTypes.AaveV3PreliquidationParamsInit({
                id: id,
                lendReserve: environment.lendAssets[0],
                borrowReserve: environment.borrowAssets[0],
                preLltv: PRE_LLTV,
                preCF1: PRE_CF1,
                preCF2: PRE_CF2,
                preIF1: PRE_IF1,
                preIF2: PRE_IF2
            })
        );
        moduleRegistry.setModule("AaveV3PreliquidationFallbackHandler", address(preliquidationFallbackHandler));
        vm.label(address(preliquidationFallbackHandler), "preliquidationFallbackHandler");
    }
}
