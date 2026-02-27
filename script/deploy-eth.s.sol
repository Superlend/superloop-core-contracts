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
import {
    TransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {DataTypes} from "../src/common/DataTypes.sol";
import {Superloop} from "../src/core/Superloop/Superloop.sol";
import {IFlashLoanSimpleReceiver} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {DepositManagerCallbackHandler} from "../src/modules/callback/DepositManagerCallbackHandler.sol";
import {WithdrawManagerCallbackHandler} from "../src/modules/callback/WithdrawManagerCallbackHandler.sol";
import {DepositManager} from "../src/core/DepositManager/DepositManager.sol";
import {WithdrawManager} from "../src/core/WithdrawManager/WithdrawManager.sol";
import {UniversalAccountant} from "../src/core/Accountant/universalAccountant/UniversalAccountant.sol";
import {AaveV3AccountantPlugin} from "../src/plugins/accountant/AaveV3AccountantPlugin.sol";
import {AaveV3PreliquidationFallbackHandler} from "../src/modules/fallback/AaveV3PreliquidationFallbackHandler.sol";
import {VaultRouter} from "../src/helpers/VaultRouter.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {MorphoFlashloanModule} from "../src/modules/morpho/MorphoFlashloanModule.sol";
import {MorphoCallbackHandler} from "../src/modules/callback/MorphoCallbackHandler.sol";
import {MerklModule} from "../src/modules/merkl/MerklModule.sol";
import {IMorphoFlashLoanCallback} from "morpho-blue/interfaces/IMorphoCallbacks.sol";
import {VaultSupplyModule} from "../src/modules/vault/VaultSupplyModule.sol";

contract Deploy is Script {
    address public deployer;
    uint256 public deployerPvtKey;
    address public vaultAdmin;
    address public rebalanceAdmin;
    address public treasury;
    address public vaultOperator;

    address public asset;
    address[] public lendAssets;
    address[] public borrowAssets;
    string public name;
    string public symbol;
    uint256 public supplyCap;
    uint256 public minimumDepositAmount;
    uint256 public instantWithdrawFee;
    uint256 public cashReserve;
    uint256 public performanceFee;
    uint256 public seedAmount;

    address public AAVE_V3_POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address public constant USDe = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address public constant sUSDe = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address public constant DISTRIBUTOR = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
    address public constant VAULT_ADMIN = address(0); // TODO: change to actual address
    address public constant TREASURY = address(0); // TODO: change to actual address
    uint8 public constant EMODE_CATEGORY = 2;
    uint256 public constant USDe_SCALE = 10 ** 18;
    uint256 public constant sUSDe_SCALE = 10 ** 18;
    uint256 public constant USDC_SCALE = 10 ** 6;
    uint256 public constant USDT_SCALE = 10 ** 6;
    uint256 public constant DEPOSIT_AMOUNT = 2 * USDe_SCALE;

    SuperloopModuleRegistry public moduleRegistry;

    // aave modules
    AaveV3FlashloanModule public flashloanModule;
    AaveV3CallbackHandler public aaveFlashloanCallbackHandler;
    AaveV3EmodeModule public emodeModule;
    AaveV3SupplyModule public supplyModule;
    AaveV3WithdrawModule public withdrawModule;
    AaveV3BorrowModule public borrowModule;
    AaveV3RepayModule public repayModule;
    VaultSupplyModule public vaultSupplyModule;

    // morpho module
    MorphoFlashloanModule public morphoFlashloanModule;
    MorphoCallbackHandler public morphoCallbackHandler;

    // dex module
    UniversalDexModule public dexModule;

    // merkl module
    MerklModule public merklModule;

    DepositManagerCallbackHandler public depositManagerCallbackHandler;
    WithdrawManagerCallbackHandler public withdrawManagerCallbackHandler;

    // TODO: Add later
    AaveV3PreliquidationFallbackHandler public preliquidationFallbackHandler;

    address public accountantImplementation;
    address public withdrawManagerImplementation;
    address public depositManagerImplementation;
    address public vaultImplementation;

    address public accountantAaveV3Plugin;

    UniversalAccountant public accountant;
    WithdrawManager public withdrawManager;
    DepositManager public depositManager;

    Superloop public superloop;
    VaultRouter public vaultRouter;

    function setUp() public {
        asset = USDe;
        name = "Superloop USDe";
        symbol = "sloopUSDe";
        supplyCap = 100_000 * USDe_SCALE; // in token terms
        minimumDepositAmount = USDe_SCALE / 100; // in token terms
        instantWithdrawFee = 10; // 0.1% in BPS
        cashReserve = 100; // 1% in BPS
        performanceFee = 1000; // 15% in bps
        lendAssets = new address[](2);
        lendAssets[0] = USDe;
        lendAssets[1] = sUSDe;
        borrowAssets = new address[](2);
        borrowAssets[0] = USDC;
        borrowAssets[1] = USDT;

        seedAmount = (1 * USDe_SCALE) / 10; // in token terms

        // TODO: Check this config every time before deploying
        console.log("--------------------------------");
        console.log("Using configs: ");
        console.log("ASSET", asset);
        console.log("NAME", name);
        console.log("SYMBOL", symbol);
        console.log("PERFORMANCE_FEE", performanceFee);
        console.log("SUPPLY_CAP", supplyCap);
        console.log("MINIMUM_DEPOSIT_AMOUNT", minimumDepositAmount);
        console.log("INSTANT_WITHDRAW_FEE", instantWithdrawFee);
        console.log("CASH_RESERVE", cashReserve);
        console.log("SEED_AMOUNT", seedAmount);
        console.log("--------------------------------");

        vm.createSelectFork("mainnet");

        deployerPvtKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPvtKey);

        vaultAdmin = deployer; // TODO: change to actual address
        treasury = deployer;
        vaultOperator = 0x1A753f2F2BA0071AaD1B147B93404a622bc72386; // actual vault operator

        console.log("--------------------------------");
        console.log("Depolyer config and roles: ");
        console.log("DEPLOYER", deployer);
        console.log("VAULT_ADMIN", vaultAdmin);
        console.log("TREASURY", treasury);
        console.log("VAULT_OPERATOR", vaultOperator);
        console.log("--------------------------------");
    }

    function run() public {
        vm.startBroadcast(deployerPvtKey);

        // deploy module registry
        moduleRegistry = new SuperloopModuleRegistry();

        // deploy all the modules
        deployModules();

        address[] memory modules = new address[](14);
        modules[0] = address(flashloanModule);
        modules[1] = address(aaveFlashloanCallbackHandler);
        modules[2] = address(emodeModule);
        modules[3] = address(supplyModule);
        modules[4] = address(withdrawModule);
        modules[5] = address(borrowModule);
        modules[6] = address(repayModule);
        modules[7] = address(dexModule);
        modules[8] = address(morphoFlashloanModule);
        modules[9] = address(morphoCallbackHandler);
        modules[10] = address(merklModule);
        modules[11] = address(depositManagerCallbackHandler);
        modules[12] = address(withdrawManagerCallbackHandler);
        modules[13] = address(vaultSupplyModule);

        // deploy vault
        DataTypes.VaultInitData memory initData = DataTypes.VaultInitData({
            asset: asset,
            name: name,
            symbol: symbol,
            supplyCap: supplyCap,
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountant: address(accountant),
            withdrawManager: address(withdrawManager),
            minimumDepositAmount: minimumDepositAmount,
            instantWithdrawFee: instantWithdrawFee,
            cashReserve: cashReserve,
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
        _setupVaultRouter();

        // seed the vault
        _seedVault();

        /**
         * ROLE TRANSFERS :
         *     1. Vault admin => safe
         *     2. Vault proxy admin => safe
         *     3. Accountant plugin owner => safe
         *     4. Accountant => safe
         *     5. Accountant proxy admin => safe
         *     6. Deposit manager proxy admin => safe
         *     7. Withdraw manager proxy admin => safe
         *     8. Module registry owner => safe
         *     9. Vault operator => rebalance admin
         *     10. Vault router owner => vault admin
         */
        _logAddresses();

        vm.stopBroadcast();
    }

    function deployModules() internal {
        // deploy vault supply module
        vaultSupplyModule = new VaultSupplyModule();
        moduleRegistry.setModule("VaultSupplyModule", address(vaultSupplyModule));

        // deploy morpho flashloan module
        morphoFlashloanModule = new MorphoFlashloanModule(MORPHO);
        moduleRegistry.setModule("MorphoFlashloanModule", address(morphoFlashloanModule));

        morphoCallbackHandler = new MorphoCallbackHandler();
        moduleRegistry.setModule("MorphoCallbackHandler", address(morphoCallbackHandler));

        // deploy aave flashloan module
        flashloanModule = new AaveV3FlashloanModule(AAVE_V3_POOL_ADDRESSES_PROVIDER);
        moduleRegistry.setModule("AaveV3FlashloanModule", address(flashloanModule));

        aaveFlashloanCallbackHandler = new AaveV3CallbackHandler();
        moduleRegistry.setModule("AaveV3CallbackHandler", address(aaveFlashloanCallbackHandler));

        depositManagerCallbackHandler = new DepositManagerCallbackHandler();
        moduleRegistry.setModule("DepositManagerCallbackHandler", address(depositManagerCallbackHandler));

        withdrawManagerCallbackHandler = new WithdrawManagerCallbackHandler();
        moduleRegistry.setModule("WithdrawManagerCallbackHandler", address(withdrawManagerCallbackHandler));

        // TODO: add later
        // preliquidationFallbackHandler = new AaveV3PreliquidationFallbackHandler(
        //     AAVE_V3_POOL_ADDRESSES_PROVIDER,
        //     address(superloop),
        //     2,
        //     8,
        //     DataTypes.AaveV3PreliquidationParamsInit({})
        // );
        // moduleRegistry.setModule("AaveV3PreliquidationFallbackHandler", address(preliquidationFallbackHandler));

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

        // deploy merkl module
        merklModule = new MerklModule(DISTRIBUTOR);
        moduleRegistry.setModule("MerklModule", address(merklModule));
    }

    function _deployAccountant(address vault) internal {
        DataTypes.AaveV3AccountantPluginModuleInitData memory accountantPluginInitData =
            DataTypes.AaveV3AccountantPluginModuleInitData({
                poolAddressesProvider: AAVE_V3_POOL_ADDRESSES_PROVIDER,
                lendAssets: lendAssets,
                borrowAssets: borrowAssets
            });
        accountantAaveV3Plugin = address(new AaveV3AccountantPlugin(accountantPluginInitData));

        address[] memory registeredAccountants = new address[](1);
        registeredAccountants[0] = accountantAaveV3Plugin;

        // deploy accountant
        DataTypes.UniversalAccountantModuleInitData memory initData = DataTypes.UniversalAccountantModuleInitData({
            registeredAccountants: registeredAccountants, performanceFee: uint16(performanceFee), vault: address(vault)
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
        DataTypes.AaveV3EmodeParams memory params = DataTypes.AaveV3EmodeParams({emodeCategory: EMODE_CATEGORY});

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
        bytes32 morphoKey = keccak256(abi.encodePacked(MORPHO, IMorphoFlashLoanCallback.onMorphoFlashLoan.selector));
        bytes32 depositKey =
            keccak256(abi.encodePacked(address(depositManager), depositManagerCallbackHandler.executeDeposit.selector));
        bytes32 withdrawKey = keccak256(
            abi.encodePacked(address(withdrawManager), withdrawManagerCallbackHandler.executeWithdraw.selector)
        );
        superloop.setCallbackHandler(morphoKey, address(morphoCallbackHandler));
        superloop.setCallbackHandler(key, address(aaveFlashloanCallbackHandler));
        superloop.setCallbackHandler(depositKey, address(depositManagerCallbackHandler));
        superloop.setCallbackHandler(withdrawKey, address(withdrawManagerCallbackHandler));
    }

    function _seedVault() internal {
        IERC20(asset).approve(address(superloop), seedAmount);
        superloop.seed(seedAmount);
    }

    function _logAddresses() internal view {
        // log module registry address
        console.log("--------------------------------");
        console.log("Module Registry: %s", address(moduleRegistry));
        console.log("--------------------------------");

        // log morpho flashloan module
        console.log("--------------------------------");
        console.log("Morpho Flashloan Module: %s", address(morphoFlashloanModule));
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

        // log vault supply module
        console.log("--------------------------------");
        console.log("Vault Supply Module: %s", address(vaultSupplyModule));
        console.log("--------------------------------");

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
        console.log("Morpho Callback Handler: %s", address(morphoCallbackHandler));

        // log merkl module
        console.log("--------------------------------");
        console.log("Merkl Module: %s", address(merklModule));
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

        console.log("--------------------------------");
        console.log("Vault Router: %s", "--------------------------------");
        console.log("--------------------------------");
        console.log("Vault Router: %s", address(vaultRouter));
    }

    function _setupVaultRouter() internal {
        address[] memory supportedVaults = new address[](1);
        supportedVaults[0] = address(superloop);

        address[] memory supportedDepositManagers = new address[](1);
        supportedDepositManagers[0] = address(depositManager);

        address[] memory supportedTokens = new address[](4);
        supportedTokens[0] = USDe;
        supportedTokens[1] = USDC;
        supportedTokens[2] = USDT;
        supportedTokens[3] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH

        vaultRouter = new VaultRouter(supportedVaults, supportedTokens, address(dexModule), supportedDepositManagers);

        vaultRouter.transferOwnership(vaultAdmin);
    }
}
