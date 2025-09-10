// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {UniversalDexModule} from "../src/modules/UniversalDexModule.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AaveV3FlashloanModule} from "../src/modules/AaveV3FlashloanModule.sol";
import {AaveV3CallbackHandler} from "../src/modules/AaveV3CallbackHandler.sol";
import {AaveV3EmodeModule} from "../src/modules/AaveV3EmodeModule.sol";
import {AaveV3SupplyModule} from "../src/modules/AaveV3SupplyModule.sol";
import {AaveV3WithdrawModule} from "../src/modules/AaveV3WithdrawModule.sol";
import {AaveV3BorrowModule} from "../src/modules/AaveV3BorrowModule.sol";
import {AaveV3RepayModule} from "../src/modules/AaveV3RepayModule.sol";
import {SuperloopModuleRegistry} from "../src/core/ModuleRegistry/ModuleRegistry.sol";
import {AccountantAaveV3} from "../src/core/Accountant/aaveV3Accountant/AccountantAaveV3.sol";
import {WithdrawManager} from "../src/core/WithdrawManager/WithdrawManager.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {DataTypes} from "../src/common/DataTypes.sol";
import {Superloop} from "../src/core/Superloop/Superloop.sol";
import {IFlashLoanSimpleReceiver} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {VaultRouter} from "../src/helpers/VaultRouter.sol";

contract Deploy is Script {
    address public deployer;
    uint256 public deployerPvtKey;
    address public vaultAdmin;
    address public rebalanceAdmin;
    address public treasury;

    address public AAVE_V3_POOL_ADDRESSES_PROVIDER = 0x5ccF60c7E10547c5389E9cBFf543E5D0Db9F4feC;
    address public constant ST_XTZ = 0x01F07f4d78d47A64F4C3B2b65f513f15Be6E1854;
    address public constant XTZ = 0xc9B53AB2679f573e480d01e0f49e2B5CFB7a3EAb;
    address public constant POOL = 0x3bD16D195786fb2F509f2E2D7F69920262EF114D;
    address public constant VAULT_ADMIN = 0x81b833Df09A7ce39C00ecE916EC54166d2a6B193;
    address public constant TREASURY = 0x669bd328f6C494949Ed9fB2dc8021557A6Dd005f;

    uint256 public constant PERFORMANCE_FEE = 1000; // 10%

    SuperloopModuleRegistry public moduleRegistry;

    AaveV3FlashloanModule public flashloanModule;
    AaveV3CallbackHandler public callbackHandler;
    AaveV3EmodeModule public emodeModule;
    AaveV3SupplyModule public supplyModule;
    AaveV3WithdrawModule public withdrawModule;
    AaveV3BorrowModule public borrowModule;
    AaveV3RepayModule public repayModule;
    UniversalDexModule public dexModule;

    address public accountantImplementation;
    address public withdrawManagerImplementation;
    address public accountantProxyAdmin;
    address public withdrawManagerProxyAdmin;
    address public vaultImplementation;
    address public vaultProxyAdmin;

    AccountantAaveV3 public accountantAaveV3;
    WithdrawManager public withdrawManager;

    Superloop public superloop;

    VaultRouter public vaultRouter;

    function setUp() public {
        vm.createSelectFork("etherlink");

        deployerPvtKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPvtKey);

        vaultAdmin = VAULT_ADMIN;
        rebalanceAdmin = deployer;
        treasury = TREASURY;

        console.log("deployer", deployer);
        console.log("vaultAdmin", vaultAdmin);
        console.log("rebalanceAdmin", rebalanceAdmin);
        console.log("treasury", treasury);
    }

    function run() public {
        vm.startBroadcast(deployerPvtKey);

        // deploy module registry
        moduleRegistry = new SuperloopModuleRegistry();

        // deploy all the modules
        deployModules();

        address[] memory modules = new address[](8);
        modules[0] = address(dexModule);
        modules[1] = address(flashloanModule);
        modules[2] = address(callbackHandler);
        modules[3] = address(emodeModule);
        modules[4] = address(supplyModule);
        modules[5] = address(withdrawModule);
        modules[6] = address(borrowModule);
        modules[7] = address(repayModule);

        // deploy vault
        DataTypes.VaultInitData memory initData = DataTypes.VaultInitData({
            asset: XTZ,
            name: "Superloop XTZ",
            symbol: "sloopXTZ",
            supplyCap: 10000 * 10 ** 18,
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountantModule: address(accountantAaveV3),
            withdrawManagerModule: address(withdrawManager),
            cashReserve: 1000,
            depositManager: address(0),
            vaultAdmin: deployer,
            treasury: treasury
        });
        vaultImplementation = address(new Superloop());
        vaultProxyAdmin = address(new ProxyAdmin(deployer));

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(vaultImplementation),
            address(vaultProxyAdmin),
            abi.encodeWithSelector(Superloop.initialize.selector, initData)
        );
        ProxyAdmin(vaultProxyAdmin).transferOwnership(vaultAdmin);
        superloop = Superloop(address(proxy));

        // deploy accountant
        _deployAccountant(address(superloop));
        superloop.setRegisteredModule(address(accountantAaveV3), true);
        superloop.setAccountantModule(address(accountantAaveV3));

        // deploy withdraw manager
        _deployWithdrawManager(address(superloop));
        superloop.setRegisteredModule(address(withdrawManager), true);
        superloop.setWithdrawManagerModule(address(withdrawManager));

        // set callback handler
        _setupCallbackHandler();
        // call emode module and setup emode 3
        _setupEmode();

        // setup vault router
        _setupVaultRouter();

        // set rebalance admin as priveledged account
        superloop.setPrivilegedAddress(rebalanceAdmin, true);

        // transfer vault admin role from deployer to vault admin after all the setup is done
        superloop.setVaultAdmin(vaultAdmin);

        _logAddresses();

        vm.stopBroadcast();
    }

    function deployModules() internal {
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

        accountantImplementation = address(new AccountantAaveV3());
        accountantProxyAdmin = address(new ProxyAdmin(deployer));

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(accountantImplementation),
            address(accountantProxyAdmin),
            abi.encodeWithSelector(AccountantAaveV3.initialize.selector, initData)
        );
        ProxyAdmin(accountantProxyAdmin).transferOwnership(vaultAdmin);

        accountantAaveV3 = AccountantAaveV3(address(proxy));
    }

    function _deployWithdrawManager(address vault) internal {
        withdrawManagerImplementation = address(new WithdrawManager());
        withdrawManagerProxyAdmin = address(new ProxyAdmin(deployer));

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(withdrawManagerImplementation),
            address(withdrawManagerProxyAdmin),
            abi.encodeWithSelector(WithdrawManager.initialize.selector, vault)
        );
        ProxyAdmin(withdrawManagerProxyAdmin).transferOwnership(vaultAdmin);

        withdrawManager = WithdrawManager(address(proxy));
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

    function _setupCallbackHandler() internal {
        bytes32 key = keccak256(abi.encodePacked(POOL, IFlashLoanSimpleReceiver.executeOperation.selector));
        superloop.setCallbackHandler(key, address(callbackHandler));
    }

    function _logAddresses() internal view {
        // log module registry address
        console.log("--------------------------------");
        console.log("Module Registry: %s", address(moduleRegistry));
        console.log("--------------------------------");

        // log all the module addresses
        console.log("--------------------------------");
        console.log("AaveV3FlashloanModule: %s", address(flashloanModule));
        console.log("--------------------------------");
        console.log("AaveV3CallbackHandler: %s", address(callbackHandler));
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
        console.log("--------------------------------");
        console.log("Universal Dex Module: %s", address(dexModule));
        console.log("--------------------------------");

        // log accountant and withdraw manager addresses along with their implementation and proxy admin
        console.log("--------------------------------");
        console.log("Accountant: %s", address(accountantAaveV3));
        console.log("--------------------------------");
        console.log("Accountant Implementation: %s", address(accountantImplementation));
        console.log("--------------------------------");
        console.log("Accountant Proxy Admin: %s", address(accountantProxyAdmin));
        console.log("--------------------------------");

        console.log("--------------------------------");
        console.log("Withdraw Manager: %s", address(withdrawManager));
        console.log("--------------------------------");
        console.log("Withdraw Manager Implementation: %s", address(withdrawManagerImplementation));
        console.log("--------------------------------");
        console.log("Withdraw Manager Proxy Admin: %s", address(withdrawManagerProxyAdmin));
        console.log("--------------------------------");

        // log superloop addresses along with its implementation and proxy admin
        console.log("--------------------------------");
        console.log("Superloop: %s", address(superloop));
        console.log("--------------------------------");
        console.log("Superloop Implementation: %s", address(vaultImplementation));
        console.log("--------------------------------");
        console.log("Superloop Proxy Admin: %s", address(vaultProxyAdmin));
        console.log("--------------------------------");

        // log vault router addresses along with its implementation and proxy admin
        console.log("--------------------------------");
        console.log("Vault Router: %s", address(vaultRouter));
        console.log("--------------------------------");
    }

    function _setupVaultRouter() internal {
        address[] memory supportedVaults = new address[](1);
        supportedVaults[0] = address(superloop);

        address[] memory supportedTokens = new address[](9);
        supportedTokens[0] = XTZ;
        supportedTokens[1] = 0x796Ea11Fa2dD751eD01b53C372fFDB4AAa8f00F9; // USDC
        supportedTokens[2] = 0x01F07f4d78d47A64F4C3B2b65f513f15Be6E1854; // ST_XTZ
        supportedTokens[3] = 0x2C03058C8AFC06713be23e58D2febC8337dbfE6A; // USDT
        supportedTokens[4] = 0xDD629E5241CbC5919847783e6C96B2De4754e438; // mtbill
        supportedTokens[5] = 0x2247B5A46BB79421a314aB0f0b67fFd11dd37Ee4; // mbasis
        supportedTokens[6] = 0xbFc94CD2B1E55999Cfc7347a9313e88702B83d0F; // wbtc
        supportedTokens[7] = 0xfc24f770F94edBca6D6f885E12d4317320BcB401; // weth
        supportedTokens[8] = 0xecAc9C5F704e954931349Da37F60E39f515c11c1; // lbtc

        vaultRouter = new VaultRouter(supportedVaults, supportedTokens, address(dexModule));

        vaultRouter.transferOwnership(vaultAdmin);
    }
}
