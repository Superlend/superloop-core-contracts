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

// TODO: update address(0) to actual addresses
contract Migration is Script {
    uint256 public migratorPvtKey;
    address public migrator;
    address public oldVault;
    address public newVault;
    MigrationHelper public migrationHelper;

    IPoolDataProvider public poolDataProvider = IPoolDataProvider(0x99e8269dDD5c7Af0F1B3973A591b47E8E001BCac);
    address public AAVE_V3_POOL_ADDRESSES_PROVIDER = 0x5ccF60c7E10547c5389E9cBFf543E5D0Db9F4feC;
    address public REPAY_MODULE = 0x9AF8cCabC21ff594dA237f9694C4A9C6123480c6;
    address public WITHDRAW_MODULE = 0x1f5Ba080B9E5705DA47212167cA44611F78DB130;
    address public DEPOSIT_MODULE = 0x66e82124412C61D7fF90ACFBa82936DD037D737E;
    address public BORROW_MODULE = 0x3de57294989d12066a94a8A16E977992F3cF8433;
    address public DEX_MODULE = 0x38F5efC1267F6103c9b0FE802E1731E245f09Cd0;
    address public constant USDC = 0x796Ea11Fa2dD751eD01b53C372fFDB4AAa8f00F9;

    address public constant LBTC = 0xecAc9C5F704e954931349Da37F60E39f515c11c1;
    address public constant WBTC = 0xbFc94CD2B1E55999Cfc7347a9313e88702B83d0F;

    address newVaultDepositManager = address(0);
    uint256 maxSharesDelta = 0;
    uint256 batches = 1;
    uint256 maxPercentageChangeInExchangeRate = 5; // 0.05%

    // TODO: 42 holders, check this before running
    address[] public ALL_USERS = [
        0x9D5132Dd45CdaCd1De3a7b7f1f13da7F025fF726,
        0xa7CBb758849979CEc43FD146fe01EB2BF560202C,
        0x6bA9c7d86eBD6A20817d482C42C9dE2806EeFB7e,
        0x9D0214C3dB28875fe2b9eb9cD9d4F71E7817890A,
        0x2B38f0De645E05Ec410AE86Ef479a1e42E45Bd12,
        0x8fb2FB82fF44da85E43d0A71CA992DbBC3243c5a,
        0xced306BfCB4a057aE3905063fD601774F9F18730,
        0x0C1856Cb7444cc8596c706185b54535F45C2623B,
        0x11fC7853944570C1F9D9EBE7Ac24e2FeFddf0314,
        0xb3d1aCA9bF004d0da560930Cf9277c604eDf2283,
        0xB438Dbaae78225eEfcDBB04E207A8eFB06036a2c,
        0x997b96BAD648c39226281Bc002f9857274E42A01,
        0xd52929B69680A6f74D2eB9c8F1ef482f37b1b32B,
        0x706FC1a8e457De0cf52e7679C2922aEF7F7a397e,
        0x3497818F50f79A11236B941dDAd35Da68A57864E,
        0xB35722e595F2B974c2B1D14A80Fab5d0c60c2fa3,
        0xA9f7b86FCC86EA1b913dDcaB8c9514a8e677666E,
        0x7077e395C9FA4E480366A5DC5792d2504d78dffF,
        0x664324F8B7430b4C22Dc036234Dd752A4755Fda7,
        0xD22ADba687aAd7DD9CEC3b18D970C581734783bA,
        0x5BC81274740A73D33ec8539182c326b8b58004C2,
        0x02F73B8e29dD6Ec38Bc5D8B3826051DC562c3060,
        0x4e90Da1dDCD5B0Fb295b6A69251b5D04D5bCCA7a,
        0x150a0D516C0ceFa39f980Da57d5422E91A94238b,
        0x4fb30f8CcE1F80FC9CC45F7F626069be7549aF59,
        0xF382ce5457Bba6113e082DD638b6671Cb2277B1f,
        0xb95f08B2eda7B23Ce412A6dE82eA5f5100335A3A,
        0x5b6Da8BC8696Aa4D20030151345ec652cf1eC727,
        0x0396816A361e2353a91Fde8438600a9353b34ce7,
        0xA1ebf2043e76446eFA2724bD1Ec18321776096FF,
        0x9214835f82752E0574F3828A4400C36Ba386Df82,
        0xb0DebcB643eE79f19Ef659Bd01D0FAC12d058604,
        0x3d72971b117EE8EF445D138557151f66CB0D408F,
        0x09e63186b4F94FafcCC60a42D3f77b4A10995674,
        0xc210a4D56D99E095b126664fDCE545b369ED3FD0,
        0xEC23a0C9D4107cAD33271c4F1955a21f4c041208,
        0x03adFaA573aC1a9b19D2b8F79a5aAFFb9c2A0532,
        0x6a58EBB35664A171A1B070DE48ee93278A63c168,
        0x521e6f07bDfa2fF8D072887F0ef3bB908a3D9e2a,
        0xF5AC5943D16fC865824910033B756519DC396682,
        0xBD73cF5baf12F120Ee3f6C4ad82df9a12649e578,
        0x44119A62EA645242234cAF408c4c20513E660EBb
    ];

    function setUp() public {
        vm.createSelectFork("etherlink");
        migratorPvtKey = vm.envUint("PRIVATE_KEY");
        migrator = vm.addr(migratorPvtKey);

        oldVault = 0xC557529dd252e5a02E6C653b0B88984aFa3c8199;
        newVault = address(0);

        migrationHelper = MigrationHelper(address(0));

        vm.label(oldVault, "oldVault");
        vm.label(newVault, "newVault");
        vm.label(address(migrationHelper), "migrationHelper");
    }

    function run() public {
        vm.startBroadcast(migratorPvtKey);

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
        ISuperloop(oldVault).setPrivilegedAddress(address(migrationHelper), true);

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
        address withdrawManager = ISuperloopLegacy(oldVault).withdrawManagerModule();
        assert(IERC20(WBTC).balanceOf(withdrawManager) == 0 && IERC20(oldVault).balanceOf(withdrawManager) == 0);
        assert(ISuperloop(newVault).depositManagerModule() == address(migrationHelper));
        assert(ISuperloop(newVault).vaultOperator() == address(migrationHelper));
        assert(IAccountantModule(ISuperloop(newVault).accountant()).vault() == address(migrationHelper));
        assert(
            Ownable(address(IAccountantModule(ISuperloop(newVault).accountant()))).owner() == address(migrationHelper)
        );
    }

    function _performMigration() internal {
        migrationHelper.migrate(
            oldVault, newVault, ALL_USERS, LBTC, WBTC, batches, maxSharesDelta, maxPercentageChangeInExchangeRate
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
        assert(Ownable(address(accountant)).owner() == address(migrator));
        assert(accountant.vault() == address(newVault));
    }

    function _postMigrationSetup() internal {
        ISuperloop(newVault).setVaultOperator(migrator);
        ISuperloop(newVault).setDepositManagerModule(newVaultDepositManager);

        ISuperloop(newVault).setRegisteredModule(REPAY_MODULE, false);
        ISuperloop(newVault).setRegisteredModule(WITHDRAW_MODULE, false);
        ISuperloop(newVault).setRegisteredModule(DEPOSIT_MODULE, false);
        ISuperloop(newVault).setRegisteredModule(BORROW_MODULE, false);
        ISuperloop(newVault).setRegisteredModule(DEX_MODULE, false);

        // assert these roles
        assert(ISuperloop(newVault).vaultOperator() == migrator);
        assert(ISuperloop(newVault).depositManagerModule() == newVaultDepositManager);
        assert(Ownable(address(IAccountantModule(ISuperloop(newVault).accountant()))).owner() == address(migrator));
        assert(IAccountantModule(ISuperloop(newVault).accountant()).vault() == newVault);
    }

    function _logVaultState(address vault) internal view {
        uint256 vaultXTZBalance = IERC20(WBTC).balanceOf(vault);
        uint256 vaultSTXTZBalance = IERC20(LBTC).balanceOf(vault);
        (uint256 vaultLendBalance,,,,,,,,) = poolDataProvider.getUserReserveData(LBTC, vault);
        (,, uint256 vaultBorrowBalance,,,,,,) = poolDataProvider.getUserReserveData(WBTC, vault);

        console.log("vaultXTZBalance", vaultXTZBalance);
        console.log("vaultSTXTZBalance", vaultSTXTZBalance);
        console.log("vaultLendBalance", vaultLendBalance);
        console.log("vaultBorrowBalance", vaultBorrowBalance);
        console.log("vault total supply", ISuperloop(vault).totalSupply());
        console.log("vault total assets", ISuperloop(vault).totalAssets());
    }
}
