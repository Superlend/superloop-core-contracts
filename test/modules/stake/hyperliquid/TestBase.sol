// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Superloop} from "../../../../src/core/Superloop/Superloop.sol";
import {DataTypes} from "../../../../src/common/DataTypes.sol";
import {SuperloopModuleRegistry} from "../../../../src/core/ModuleRegistry/ModuleRegistry.sol";
import {AaveV3FlashloanModule} from "../../../../src/modules/aave/AaveV3FlashloanModule.sol";
import {AaveV3CallbackHandler} from "../../../../src/modules/callback/AaveV3CallbackHandler.sol";
import {AaveV3EmodeModule} from "../../../../src/modules/aave/AaveV3EmodeModule.sol";
import {AaveV3SupplyModule} from "../../../../src/modules/aave/AaveV3SupplyModule.sol";
import {AaveV3WithdrawModule} from "../../../../src/modules/aave/AaveV3WithdrawModule.sol";
import {AaveV3BorrowModule} from "../../../../src/modules/aave/AaveV3BorrowModule.sol";
import {AaveV3RepayModule} from "../../../../src/modules/aave/AaveV3RepayModule.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {UniversalDexModule} from "../../../../src/modules/dex/UniversalDexModule.sol";
import {AccountantAaveV3} from "../../../../src/core/Accountant/aaveV3Accountant/AccountantAaveV3.sol";
import {WithdrawManager} from "../../../../src/core/WithdrawManager/WithdrawManager.sol";
import {DepositManager} from "../../../../src/core/DepositManager/DepositManager.sol";
import {DepositManagerCallbackHandler} from "../../../../src/modules/callback/DepositManagerCallbackHandler.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UniversalAccountant} from "../../../../src/core/Accountant/universalAccountant/UniversalAccountant.sol";
import {AaveV3AccountantPlugin} from "../../../../src/plugins/Accountant/AaveV3AccountantPlugin.sol";
import {WithdrawManagerCallbackHandler} from "../../../../src/modules/callback/WithdrawManagerCallbackHandler.sol";
import {UnwrapModule} from "../../../../src/modules/helper/UnwrapModule.sol";
import {WrapModule} from "../../../../src/modules/helper/WrapModule.sol";
import {HyperliquidStakeModule} from "../../../../src/modules/stake/hyperliquid/HyperliquidStakeModule.sol";
import {KinetiqStakeModule} from "../../../../src/modules/stake/hyperliquid/KinetiqStakeModule.sol";
import {HyperbeatStakingModule} from "../../../../src/modules/stake/hyperliquid/HyperbeatStakingModule.sol";

contract TestBase is Test {
    address public AAVE_V3_POOL_ADDRESSES_PROVIDER;
    address public AAVE_V3_POOL_DATA_PROVIDER;
    address public AAVE_V3_PRICE_ORACLE;
    address public POOL;
    uint256 public PERFORMANCE_FEE; // 20%
    address public POOL_CONFIGURATOR;

    address public stakingManager = 0x393D0B87Ed38fc779FD9611144aE649BA6082109;
    address public stakingCore = 0xCeaD893b162D38e714D82d06a7fe0b0dc3c38E0b;
    address public overseer = 0xB96f07367e69e86d6e9C3F29215885104813eeAE;
    address public constant WHYPE = 0x5555555555555555555555555555555555555555;
    uint256 public constant WHYPE_SCALE = 10 ** 18;

    address public constant ST_HYPE = 0xfFaa4a3D97fE9107Cef8a3F48c069F577Ff76cC1;
    address public constant WST_HYPE = 0x94e8396e0869c9F2200760aF0621aFd240E1CF38;

    address public admin;
    address public treasury;

    SuperloopModuleRegistry public moduleRegistry;
    Superloop public superloop;
    AaveV3FlashloanModule public flashloanModule;
    DepositManagerCallbackHandler public depositManagerCallbackHandler;
    WithdrawManagerCallbackHandler public withdrawManagerCallbackHandler;
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

    HyperliquidStakeModule public hyperliquidStakeModule;
    KinetiqStakeModule public kinetiqStakeModule;
    HyperbeatStakingModule public hyperbeatStakingModule;

    DepositManager public depositManager;

    address public mockModule;
    AaveV3EmodeModule public emodeModule;
    IPoolDataProvider public poolDataProvider;
    IPool public pool;

    function setUp() public virtual {
        vm.createSelectFork("hyperevm");
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
    }

    function _deployModules() internal {
        unwrapModule = new UnwrapModule(WHYPE);
        moduleRegistry.setModule("UnwrapModule", address(unwrapModule));
        wrapModule = new WrapModule(WHYPE);
        moduleRegistry.setModule("WrapModule", address(wrapModule));

        hyperliquidStakeModule = new HyperliquidStakeModule(overseer);
        moduleRegistry.setModule("HyperliquidStakeModule", address(hyperliquidStakeModule));
        kinetiqStakeModule = new KinetiqStakeModule(stakingCore);
        moduleRegistry.setModule("KinetiqStakeModule", address(kinetiqStakeModule));
        hyperbeatStakingModule = new HyperbeatStakingModule(stakingManager);
        moduleRegistry.setModule("HyperbeatStakingModule", address(hyperbeatStakingModule));

        vm.label(address(unwrapModule), "unwrapModule");
        vm.label(address(wrapModule), "wrapModule");
        vm.label(address(hyperliquidStakeModule), "hyperliquidStakeModule");
        vm.label(address(kinetiqStakeModule), "kinetiqStakeModule");
        vm.label(address(hyperbeatStakingModule), "hyperbeatStakingModule");
    }

    // function _deployAccountant(address vault) internal {
    //     address[] memory lendAssets = new address[](1);
    //     lendAssets[0] = ST_XTZ;
    //     address[] memory borrowAssets = new address[](1);
    //     borrowAssets[0] = XTZ;

    //     DataTypes.AaveV3AccountantPluginModuleInitData memory accountantPluginInitData = DataTypes
    //         .AaveV3AccountantPluginModuleInitData({
    //         poolAddressesProvider: AAVE_V3_POOL_ADDRESSES_PROVIDER,
    //         lendAssets: lendAssets,
    //         borrowAssets: borrowAssets
    //     });
    //     address accountantPlugin = address(new AaveV3AccountantPlugin(accountantPluginInitData));

    //     address[] memory registeredAccountants = new address[](1);
    //     registeredAccountants[0] = accountantPlugin;

    //     // deploy accountant
    //     DataTypes.UniversalAccountantModuleInitData memory initData = DataTypes.UniversalAccountantModuleInitData({
    //         registeredAccountants: registeredAccountants,
    //         performanceFee: uint16(PERFORMANCE_FEE),
    //         vault: address(vault)
    //     });

    //     address accountantImplementation = address(new UniversalAccountant());
    //     TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
    //         accountantImplementation,
    //         address(this),
    //         abi.encodeWithSelector(UniversalAccountant.initialize.selector, initData)
    //     );

    //     accountant = UniversalAccountant(address(proxy));
    // }

    // function _deployDepositManager(address vault) internal {
    //     DepositManager depositManagerImplementation = new DepositManager();
    //     TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
    //         address(depositManagerImplementation),
    //         address(this),
    //         abi.encodeWithSelector(DepositManager.initialize.selector, vault)
    //     );

    //     depositManager = DepositManager(address(proxy));
    // }

    // function _deployWithdrawManager(address vault) internal {
    //     WithdrawManager withdrawManagerImplementation = new WithdrawManager();
    //     TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
    //         address(withdrawManagerImplementation),
    //         address(this),
    //         abi.encodeWithSelector(WithdrawManager.initialize.selector, vault)
    //     );
    //     withdrawManager = WithdrawManager(address(proxy));
    // }
}
