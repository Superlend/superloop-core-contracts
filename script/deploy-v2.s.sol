// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {UniversalDexModule} from "../src/modules/dex/UniversalDexModule.sol";
import {AaveV3FlashloanModule} from "../src/modules/aave/AaveV3FlashloanModule.sol";
import {AaveV3CallbackHandler} from "../src/modules/callback/AaveV3CallbackHandler.sol";
import {AaveV3EmodeModule} from "../src/modules/aave/AaveV3EmodeModule.sol";
import {AaveV3SupplyModule} from "../src/modules/aave/AaveV3SupplyModule.sol";
import {AaveV3WithdrawModule} from "../src/modules/aave/AaveV3WithdrawModule.sol";
import {AaveV3BorrowModule} from "../src/modules/aave/AaveV3BorrowModule.sol";
import {AaveV3RepayModule} from "../src/modules/aave/AaveV3RepayModule.sol";
import {SuperloopModuleRegistry} from "../src/core/ModuleRegistry/ModuleRegistry.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {DataTypes} from "../src/common/DataTypes.sol";
import {Superloop} from "../src/core/Superloop/Superloop.sol";
import {IFlashLoanSimpleReceiver} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {DepositManagerCallbackHandler} from "../src/modules/callback/DepositManagerCallbackHandler.sol";
import {WithdrawManagerCallbackHandler} from "../src/modules/callback/WithdrawManagerCallbackHandler.sol";
import {DepositManager} from "../src/core/DepositManager/DepositManager.sol";
import {WithdrawManager} from "../src/core/WithdrawManager/WithdrawManager.sol";
import {UniversalAccountant} from "../src/core/Accountant/universalAccountant/UniversalAccountant.sol";
import {AaveV3AccountantPlugin} from "../src/plugins/accountant/AaveV3AccountantPlugin.sol";

contract Deploy is Script {
    address public deployer;
    uint256 public deployerPvtKey;
    address public vaultAdmin;
    address public rebalanceAdmin;
    address public treasury;
    address public vaultOperator;

    address public AAVE_V3_POOL_ADDRESSES_PROVIDER = 0x5ccF60c7E10547c5389E9cBFf543E5D0Db9F4feC;
    address public constant ST_XTZ = 0x01F07f4d78d47A64F4C3B2b65f513f15Be6E1854;
    address public constant XTZ = 0xc9B53AB2679f573e480d01e0f49e2B5CFB7a3EAb;
    address public constant POOL = 0x3bD16D195786fb2F509f2E2D7F69920262EF114D;
    address public constant VAULT_ADMIN = 0x81b833Df09A7ce39C00ecE916EC54166d2a6B193;
    address public constant TREASURY = 0x669bd328f6C494949Ed9fB2dc8021557A6Dd005f;

    uint256 public constant PERFORMANCE_FEE = 1000; // 10%

    SuperloopModuleRegistry public moduleRegistry;

    // aave modules
    AaveV3FlashloanModule public flashloanModule;
    AaveV3CallbackHandler public aaveFlashloanCallbackHandler;
    AaveV3EmodeModule public emodeModule;
    AaveV3SupplyModule public supplyModule;
    AaveV3WithdrawModule public withdrawModule;
    AaveV3BorrowModule public borrowModule;
    AaveV3RepayModule public repayModule;

    // dex module
    UniversalDexModule public dexModule = UniversalDexModule(0x38F5efC1267F6103c9b0FE802E1731E245f09Cd0);

    DepositManagerCallbackHandler public depositManagerCallbackHandler;
    WithdrawManagerCallbackHandler public withdrawManagerCallbackHandler;

    address public accountantImplementation;
    address public withdrawManagerImplementation;
    address public depositManagerImplementation;
    address public vaultImplementation;

    address public accountantAaveV3Plugin;

    UniversalAccountant public accountant;
    WithdrawManager public withdrawManager;
    DepositManager public depositManager;

    Superloop public superloop;

    // TODO: add vault router later
    // VaultRouter public vaultRouter;

    function setUp() public {
        vm.createSelectFork("etherlink");

        deployerPvtKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPvtKey);

        vaultAdmin = deployer;
        rebalanceAdmin = deployer;
        treasury = TREASURY;
        vaultOperator = deployer;

        console.log("deployer", deployer);
        console.log("vaultAdmin", vaultAdmin);
        console.log("rebalanceAdmin", rebalanceAdmin);
        console.log("treasury", treasury);
        console.log("vaultOperator", vaultOperator);
    }

    function run() public {
        vm.startBroadcast(deployerPvtKey);

        // deploy module registry
        moduleRegistry = new SuperloopModuleRegistry();

        // deploy all the modules
        deployModules();

        address[] memory modules = new address[](10);
        modules[0] = address(flashloanModule);
        modules[1] = address(aaveFlashloanCallbackHandler);
        modules[2] = address(emodeModule);
        modules[3] = address(supplyModule);
        modules[4] = address(withdrawModule);
        modules[5] = address(borrowModule);
        modules[6] = address(repayModule);
        modules[7] = address(dexModule);
        modules[8] = address(depositManagerCallbackHandler);
        modules[9] = address(withdrawManagerCallbackHandler);

        // deploy vault
        DataTypes.VaultInitData memory initData = DataTypes.VaultInitData({
            asset: XTZ,
            name: "Test Superloop XTZ v3",
            symbol: "TestsloopXTZv3",
            supplyCap: 10000 * 10 ** 18,
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountant: address(accountant),
            withdrawManager: address(withdrawManager),
            cashReserve: 100,
            depositManager: address(depositManager),
            vaultAdmin: vaultAdmin,
            treasury: treasury,
            vaultOperator: vaultOperator
        });
        vaultImplementation = address(new Superloop());
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(vaultImplementation),
            address(vaultAdmin),
            abi.encodeWithSelector(Superloop.initialize.selector, initData)
        );
        superloop = Superloop(payable(address(proxy)));

        // deploy accountant
        _deployAccountant(address(superloop));
        moduleRegistry.setModule("universalAccountant", address(accountant));
        superloop.setRegisteredModule(address(accountant), true);
        superloop.setAccountantModule(address(accountant));

        // deploy withdraw manager
        _deployWithdrawManager(address(superloop));
        moduleRegistry.setModule("withdrawManager", address(withdrawManager));
        superloop.setRegisteredModule(address(withdrawManager), true);
        superloop.setWithdrawManagerModule(address(withdrawManager));

        // deploy deposit manager
        _deployDepositManager(address(superloop));
        moduleRegistry.setModule("depositManager", address(depositManager));
        superloop.setRegisteredModule(address(depositManager), true);
        superloop.setDepositManagerModule(address(depositManager));

        // set callback handler
        _setupCallbackHandlers();

        // call emode module and setup emode 3
        _setupEmode();

        // setup vault router
        // TODO: add vault router later
        // _setupVaultRouter();

        // set rebalance admin as priveledged account
        // superloop.setPrivilegedAddress(rebalanceAdmin, true);

        // transfer vault admin role from deployer to vault admin after all the setup is done
        // superloop.setVaultAdmin(vaultAdmin);

        _logAddresses();

        vm.stopBroadcast();
    }

    function deployModules() internal {
        flashloanModule = new AaveV3FlashloanModule(AAVE_V3_POOL_ADDRESSES_PROVIDER);
        moduleRegistry.setModule("AaveV3FlashloanModule", address(flashloanModule));

        aaveFlashloanCallbackHandler = new AaveV3CallbackHandler();
        moduleRegistry.setModule("AaveV3CallbackHandler", address(aaveFlashloanCallbackHandler));

        depositManagerCallbackHandler = new DepositManagerCallbackHandler();
        moduleRegistry.setModule("DepositManagerCallbackHandler", address(depositManagerCallbackHandler));

        withdrawManagerCallbackHandler = new WithdrawManagerCallbackHandler();
        moduleRegistry.setModule("WithdrawManagerCallbackHandler", address(withdrawManagerCallbackHandler));

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

        // dexModule = new UniversalDexModule();
        moduleRegistry.setModule("UniversalDexModule", address(dexModule));
    }

    function _deployAccountant(address vault) internal {
        address[] memory lendAssets = new address[](1);
        lendAssets[0] = ST_XTZ;
        address[] memory borrowAssets = new address[](1);
        borrowAssets[0] = XTZ;

        DataTypes.AaveV3AccountantPluginModuleInitData memory accountantPluginInitData = DataTypes
            .AaveV3AccountantPluginModuleInitData({
            poolAddressesProvider: AAVE_V3_POOL_ADDRESSES_PROVIDER,
            lendAssets: lendAssets,
            borrowAssets: borrowAssets
        });
        accountantAaveV3Plugin = address(new AaveV3AccountantPlugin(accountantPluginInitData));

        address[] memory registeredAccountants = new address[](1);
        registeredAccountants[0] = accountantAaveV3Plugin;

        // deploy accountant
        DataTypes.UniversalAccountantModuleInitData memory initData = DataTypes.UniversalAccountantModuleInitData({
            registeredAccountants: registeredAccountants,
            performanceFee: uint16(PERFORMANCE_FEE),
            vault: address(vault)
        });

        accountantImplementation = address(new UniversalAccountant());
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            accountantImplementation,
            address(vaultAdmin),
            abi.encodeWithSelector(UniversalAccountant.initialize.selector, initData)
        );

        accountant = UniversalAccountant(address(proxy));
    }

    function _deployWithdrawManager(address vault) internal {
        withdrawManagerImplementation = address(new WithdrawManager());

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(withdrawManagerImplementation),
            address(vaultAdmin),
            abi.encodeWithSelector(WithdrawManager.initialize.selector, vault)
        );

        withdrawManager = WithdrawManager(address(proxy));
    }

    function _deployDepositManager(address vault) internal {
        depositManagerImplementation = address(new DepositManager());
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(depositManagerImplementation),
            address(vaultAdmin),
            abi.encodeWithSelector(DepositManager.initialize.selector, vault)
        );
        depositManager = DepositManager(address(proxy));
    }

    function _setupEmode() internal {
        DataTypes.AaveV3EmodeParams memory params = DataTypes.AaveV3EmodeParams({emodeCategory: 3});

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(emodeModule),
            data: abi.encodeWithSelector(emodeModule.execute.selector, params)
        });

        superloop.operate(moduleExecutionData);
    }

    function _setupCallbackHandlers() internal {
        bytes32 key = keccak256(abi.encodePacked(POOL, IFlashLoanSimpleReceiver.executeOperation.selector));
        bytes32 depositKey =
            keccak256(abi.encodePacked(address(depositManager), depositManagerCallbackHandler.executeDeposit.selector));
        bytes32 withdrawKey = keccak256(
            abi.encodePacked(address(withdrawManager), withdrawManagerCallbackHandler.executeWithdraw.selector)
        );
        superloop.setCallbackHandler(key, address(aaveFlashloanCallbackHandler));
        superloop.setCallbackHandler(depositKey, address(depositManagerCallbackHandler));
        superloop.setCallbackHandler(withdrawKey, address(withdrawManagerCallbackHandler));
    }

    function _logAddresses() internal view {
        // log module registry address
        console.log("--------------------------------");
        console.log("Module Registry: %s", address(moduleRegistry));
        console.log("--------------------------------");

        // log all aave module addresses
        console.log("--------------------------------");
        console.log("AaveV3 Modules: %s", "--------------------------------");
        console.log("--------------------------------");
        console.log("AaveV3FlashloanModule: %s", address(flashloanModule));
        console.log("--------------------------------");
        console.log("AaveV3EmodeModule: %s", address(emodeModule));
        console.log("--------------------------------");
        console.log("AaveV3SupplyModule: %s", address(supplyModule));
        console.log("--------------------------------");
        console.log("AaveV3WithdrawModule: %s", address(withdrawModule));
        console.log("--------------------------------");
        console.log("AaveV3BorrowModule: %s", address(borrowModule));
        console.log("--------------------------------");
        console.log("AaveV3RepayModule: %s", address(repayModule));

        // log all the dex modules
        console.log("--------------------------------");
        console.log("Dex Modules: %s", "--------------------------------");
        console.log("--------------------------------");
        console.log("Universal Dex Module: %s", address(dexModule));
        console.log("--------------------------------");

        // log all the callback handler modules
        console.log("--------------------------------");
        console.log("Callback Handler Modules: %s", "--------------------------------");
        console.log("--------------------------------");
        console.log("Deposit Manager Callback Handler: %s", address(depositManagerCallbackHandler));
        console.log("--------------------------------");
        console.log("Withdraw Manager Callback Handler: %s", address(withdrawManagerCallbackHandler));
        console.log("--------------------------------");
        console.log("AaveV3CallbackHandler: %s", address(aaveFlashloanCallbackHandler));
        console.log("--------------------------------");

        // log accountant along with accountant plugin
        console.log("--------------------------------");
        console.log("Accountant: %s", "--------------------------------");
        console.log("--------------------------------");
        console.log("Accountant: %s", address(accountant));
        console.log("--------------------------------");
        console.log("Accountant Implementation: %s", address(accountantImplementation));
        console.log("--------------------------------");
        console.log("Accountant Plugin: %s", address(accountantAaveV3Plugin));
        console.log("--------------------------------");

        // log withdraw manager along with withdraw manager implementation
        console.log("--------------------------------");
        console.log("Withdraw Manager: %s", "--------------------------------");
        console.log("--------------------------------");
        console.log("Withdraw Manager: %s", address(withdrawManager));
        console.log("--------------------------------");
        console.log("Withdraw Manager Implementation: %s", address(withdrawManagerImplementation));
        console.log("--------------------------------");

        // log deposit manager along with deposit manager implementation
        console.log("--------------------------------");
        console.log("Deposit Manager: %s", "--------------------------------");
        console.log("--------------------------------");
        console.log("Deposit Manager: %s", address(depositManager));
        console.log("--------------------------------");
        console.log("Deposit Manager Implementation: %s", address(depositManagerImplementation));
        console.log("--------------------------------");

        // log superloop along with implementation and proxy admin
        console.log("--------------------------------");
        console.log("Superloop: %s", "--------------------------------");
        console.log("--------------------------------");
        console.log("Superloop: %s", address(superloop));
        console.log("--------------------------------");
        console.log("Superloop Implementation: %s", address(vaultImplementation));
        console.log("--------------------------------");

        // TODO: add vault router later
        // log vault router along with its implementation and proxy admin
        // console.log("--------------------------------");
        // console.log("Vault Router: %s", "--------------------------------");
        // console.log("--------------------------------");
        // console.log("Vault Router: %s", address(vaultRouter));
    }

    function _setupVaultRouter() internal {
        // address[] memory supportedVaults = new address[](1);
        // supportedVaults[0] = address(superloop);

        // address[] memory supportedTokens = new address[](9);
        // supportedTokens[0] = XTZ;
        // supportedTokens[1] = 0x796Ea11Fa2dD751eD01b53C372fFDB4AAa8f00F9; // USDC
        // supportedTokens[2] = 0x01F07f4d78d47A64F4C3B2b65f513f15Be6E1854; // ST_XTZ
        // supportedTokens[3] = 0x2C03058C8AFC06713be23e58D2febC8337dbfE6A; // USDT
        // supportedTokens[4] = 0xDD629E5241CbC5919847783e6C96B2De4754e438; // mtbill
        // supportedTokens[5] = 0x2247B5A46BB79421a314aB0f0b67fFd11dd37Ee4; // mbasis
        // supportedTokens[6] = 0xbFc94CD2B1E55999Cfc7347a9313e88702B83d0F; // wbtc
        // supportedTokens[7] = 0xfc24f770F94edBca6D6f885E12d4317320BcB401; // weth
        // supportedTokens[8] = 0xecAc9C5F704e954931349Da37F60E39f515c11c1; // lbtc

        // vaultRouter = new VaultRouter(supportedVaults, supportedTokens, address(dexModule));

        // vaultRouter.transferOwnership(vaultAdmin);
    }
}
