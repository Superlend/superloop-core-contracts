// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MigrationHelper} from "../src/helpers/MigrationHelper.sol";
import {ISuperloop} from "../src/interfaces/ISuperloop.sol";
import {IAccountantModule} from "../src/interfaces/IAccountantModule.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ISuperloopLegacy} from "../src/helpers/ISuperloopLegacy.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {console2} from "forge-std/console2.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";

contract Migration is Script {
    uint256 public adminPvtKey;
    address public admin;
    address public oldVault;
    address public newVault;
    MigrationHelper public migrationHelper;

    IPoolDataProvider public poolDataProvider = IPoolDataProvider(0x99e8269dDD5c7Af0F1B3973A591b47E8E001BCac);
    address public AAVE_V3_POOL_ADDRESSES_PROVIDER = 0x5ccF60c7E10547c5389E9cBFf543E5D0Db9F4feC;
    address REPAY_MODULE = 0xB8A8415B20b119aDEaff3Ed078980B0585190E5B;
    address WITHDRAW_MODULE = 0x545D45227Ec1dE0dae88C5B576A234931fa2e428;
    address DEPOSIT_MODULE = 0x193EcEA94c424dF41d466b6bcA597ADb5B788999;
    address BORROW_MODULE = 0x23fd2A315e6F30552278849AF467e978EF76c5C4;
    address DEX_MODULE = 0x2871677D649019A4e901C8b0f5a3B6Fa88900a91;
    address public constant USDC = 0x796Ea11Fa2dD751eD01b53C372fFDB4AAa8f00F9;

    address public constant ST_XTZ = 0x01F07f4d78d47A64F4C3B2b65f513f15Be6E1854;
    address public constant XTZ = 0xc9B53AB2679f573e480d01e0f49e2B5CFB7a3EAb;
    address public constant LBTC = 0xecAc9C5F704e954931349Da37F60E39f515c11c1;
    address public constant WBTC = 0xbFc94CD2B1E55999Cfc7347a9313e88702B83d0F;

    address newVaultDepositManager = 0xC2d2325DF20bB36E5859068dEBBbeefd239D6192;
    uint256 maxSharesDelta = 100;
    uint256 batches = 1;
    uint256 maxPercentageChangeInExchangeRate = 5; // 0.05% ?

    // TODO: Add read time users to the list
    address[] public ALL_USERS = [
        0x5c53414E1f15D7668c2b9EC0A92482A64845f5f6,
        0x52f86e43dAbdDee24A35227598bF4569FE59034D,
        0x03adFaA573aC1a9b19D2b8F79a5aAFFb9c2A0532,
        0xF5AC5943D16fC865824910033B756519DC396682
    ];

    function setUp() public {
        vm.createSelectFork("etherlink");
        adminPvtKey = vm.envUint("PRIVATE_KEY");
        admin = vm.addr(adminPvtKey);

        // TODO: Add old vault address
        oldVault = 0x9a3f9C4d3B5A40fc064f4f9dB11dE617CDCBD3eF;
        newVault = 0x93fcCf4b8dDE650c98f6F1c18831B5c8D2966210;

        migrationHelper = _deployMigrationHelper();

        vm.label(oldVault, "oldVault");
        vm.label(newVault, "newVault");
        vm.label(address(migrationHelper), "migrationHelper");
    }

    function run() public {
        vm.startBroadcast(adminPvtKey);

        console.log("OLD VAULT STATE BEFORE MIGRATION");
        _logVaultState(oldVault);
        console.log(
            "old vault last realized fee exchange rate",
            IAccountantModule(ISuperloopLegacy(oldVault).accountantModule()).lastRealizedFeeExchangeRate()
        );

        console.log("================================================");

        _preMigrationSetup();
        _performMigration();
        _postMigrationSetup();

        console.log("NEW VAULT STATE AFTER MIGRATION");
        _logVaultState(newVault);
        console.log(
            "new vault last realized fee exchange rate",
            IAccountantModule(ISuperloop(newVault).accountant()).lastRealizedFeeExchangeRate()
        );
        console.log("================================================");

        console.log("OLD VAULT STATE AFTER MIGRATION");
        _logVaultState(oldVault);
        console.log(
            "old vault last realized fee exchange rate",
            IAccountantModule(ISuperloopLegacy(oldVault).accountantModule()).lastRealizedFeeExchangeRate()
        );

        console.log("================================================");

        vm.stopBroadcast();
    }

    function _deployMigrationHelper() internal returns (MigrationHelper) {
        return new MigrationHelper(
            AAVE_V3_POOL_ADDRESSES_PROVIDER,
            REPAY_MODULE,
            WITHDRAW_MODULE,
            DEPOSIT_MODULE,
            BORROW_MODULE,
            DEX_MODULE,
            USDC
        );
    }

    function _preMigrationSetup() internal {
        ISuperloop(oldVault).setVaultAdmin(address(migrationHelper));
        // ISuperloop(oldVault).setPrivilegedAddress(
        //     address(migrationHelper),
        //     true
        // );

        ISuperloop(newVault).setRegisteredModule(REPAY_MODULE, true);
        ISuperloop(newVault).setRegisteredModule(WITHDRAW_MODULE, true);
        ISuperloop(newVault).setRegisteredModule(DEPOSIT_MODULE, true);
        ISuperloop(newVault).setRegisteredModule(BORROW_MODULE, true);
        ISuperloop(newVault).setRegisteredModule(DEX_MODULE, true);

        ISuperloop(newVault).setDepositManagerModule(address(migrationHelper));
        ISuperloop(newVault).setVaultOperator(address(migrationHelper));
        IAccountantModule(ISuperloop(newVault).accountant()).setVault(address(migrationHelper));
        Ownable(address(IAccountantModule(ISuperloop(newVault).accountant()))).transferOwnership(
            address(migrationHelper)
        );

        // assert these roles
        assert(ISuperloop(newVault).depositManagerModule() == address(migrationHelper));
        assert(ISuperloop(newVault).vaultOperator() == address(migrationHelper));
        assert(IAccountantModule(ISuperloop(newVault).accountant()).vault() == address(migrationHelper));
        assert(
            Ownable(address(IAccountantModule(ISuperloop(newVault).accountant()))).owner() == address(migrationHelper)
        );
    }

    function _performMigration() internal {
        migrationHelper.migrate(
            oldVault, newVault, ALL_USERS, ST_XTZ, XTZ, batches, maxSharesDelta, maxPercentageChangeInExchangeRate
        );

        for (uint256 i = 0; i < ALL_USERS.length; i++) {
            assert(ISuperloop(newVault).balanceOf(ALL_USERS[i]) == ISuperloop(oldVault).balanceOf(ALL_USERS[i]));
        }
        IAccountantModule accountant = IAccountantModule(ISuperloop(newVault).accountant());
        uint256 newVaultLastRealizedFeeExchangeRate =
            IAccountantModule(ISuperloop(newVault).accountant()).lastRealizedFeeExchangeRate();
        uint256 oldVaultLastRealizedFeeExchangeRate =
            IAccountantModule(ISuperloopLegacy(oldVault).accountantModule()).lastRealizedFeeExchangeRate();

        assert(newVaultLastRealizedFeeExchangeRate == oldVaultLastRealizedFeeExchangeRate);
        assert(Ownable(address(accountant)).owner() == address(admin));
        assert(accountant.vault() == address(newVault));
    }

    function _postMigrationSetup() internal {
        ISuperloop(newVault).setVaultOperator(admin);
        ISuperloop(newVault).setDepositManagerModule(newVaultDepositManager);

        // ISuperloop(oldVault).setPrivilegedAddress(address(migrationHelper), false);

        ISuperloop(newVault).setRegisteredModule(REPAY_MODULE, false);
        ISuperloop(newVault).setRegisteredModule(WITHDRAW_MODULE, false);
        ISuperloop(newVault).setRegisteredModule(DEPOSIT_MODULE, false);
        ISuperloop(newVault).setRegisteredModule(BORROW_MODULE, false);
        ISuperloop(newVault).setRegisteredModule(DEX_MODULE, false);

        // assert these roles
        assert(ISuperloop(newVault).vaultOperator() == admin);
        assert(ISuperloop(newVault).depositManagerModule() == newVaultDepositManager);
        assert(Ownable(address(IAccountantModule(ISuperloop(newVault).accountant()))).owner() == address(admin));
        assert(IAccountantModule(ISuperloop(newVault).accountant()).vault() == newVault);
    }

    function _logVaultState(address vault) internal view {
        uint256 vaultXTZBalance = IERC20(XTZ).balanceOf(vault);
        uint256 vaultSTXTZBalance = IERC20(ST_XTZ).balanceOf(vault);
        (uint256 vaultLendBalance,,,,,,,,) = poolDataProvider.getUserReserveData(ST_XTZ, vault);
        (,, uint256 vaultBorrowBalance,,,,,,) = poolDataProvider.getUserReserveData(XTZ, vault);

        console.log("vaultXTZBalance", vaultXTZBalance);
        console.log("vaultSTXTZBalance", vaultSTXTZBalance);
        console.log("vaultLendBalance", vaultLendBalance);
        console.log("vaultBorrowBalance", vaultBorrowBalance);
        console.log("vault total supply", ISuperloop(vault).totalSupply());
        console.log("vault total assets", ISuperloop(vault).totalAssets());
    }
}
