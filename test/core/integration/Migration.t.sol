// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IntegrationBase} from "../integration/IntegrationBase.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {MigrationHelper} from "../../../src/helpers/MigrationHelper.sol";
import {ISuperloop} from "../../../src/interfaces/ISuperloop.sol";
import {IAccountantModule} from "../../../src/interfaces/IAccountantModule.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ISuperloopLegacy} from "../../../src/helpers/ISuperloopLegacy.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * Prerequisites for the migration to work
 * 1. The old vault's withdraw manager must be empty
 * 2. Both the vaults should share common aave action modules and dex module
 * 2. Migration helper contract must be set as priveledged address in the old vault
 * 3. Migration helper contract must be set as these in the new vault
 *     1. vault operator
 *     2. deposit manager in the new vault
 *     3. vault in the new accountant module
 * 4. Post migration
 *     1. Update vault operator on the new vault
 *     2. Update vault in the new accountant module
 *     3. Update deposit manager on the new vault
 *     4. Remove migration helper as priveledged address from the old vault
 */
contract MigrationTest is IntegrationBase {
    address REPAY_MODULE = 0x9AF8cCabC21ff594dA237f9694C4A9C6123480c6;
    address WITHDRAW_MODULE = 0x1f5Ba080B9E5705DA47212167cA44611F78DB130;
    address DEPOSIT_MODULE = 0x66e82124412C61D7fF90ACFBa82936DD037D737E;
    address BORROW_MODULE = 0x3de57294989d12066a94a8A16E977992F3cF8433;
    address DEX_MODULE = 0x38F5efC1267F6103c9b0FE802E1731E245f09Cd0;

    address oldVault = 0xe24e5DEbA01Ab0B5D78A0093442De0864832803E;

    // currently there are 115 holder who need to be migrated to the new vault
    address[] public ALL_HOLDERS = [
        0x8fb2FB82fF44da85E43d0A71CA992DbBC3243c5a,
        0xb3d1aCA9bF004d0da560930Cf9277c604eDf2283,
        0x11fC7853944570C1F9D9EBE7Ac24e2FeFddf0314,
        0xced306BfCB4a057aE3905063fD601774F9F18730,
        0x5d8809340760b1bB54642BE91Bb5A2871C0d7a10,
        0x40F832B71D2C525A9aa4b4908Ec511Ed93c8a308,
        0x52f86e43dAbdDee24A35227598bF4569FE59034D,
        0x4f2421553E571627C6801521316732693016d9cF,
        0x953D1668BC03e0EE9145A7c4F79956b73db90B67,
        0x6EA314366871459Dbc3e1A2Eb422e23B538c7ADC,
        0x46C9CCC6857E33a8209706BB5043700b4608Dda8,
        0x67Efd0FfD493Fa5C55f2a19033557557e3A5197C,
        0xbE00FA424243C56c7CF5792aFBd6b8Dc4d6CBE4E,
        0xEC23a0C9D4107cAD33271c4F1955a21f4c041208,
        0x07ABc6225724a3f29e09173f585AacDE7A701dB3,
        0x5EdF9DeC5b003AF80B65e129Ab17DBE64106a8e3,
        0x664324F8B7430b4C22Dc036234Dd752A4755Fda7,
        0x3d72971b117EE8EF445D138557151f66CB0D408F,
        0xB35722e595F2B974c2B1D14A80Fab5d0c60c2fa3,
        0x93e3A2a50e7A6091B877Fc939e0a3f43954811d8,
        0x37b14bF02B1D01E196E3439d1689fEf845E9314A,
        0xd9aeb979cbe3a85F2d6fca3723f846Af8CA56E05,
        0x4A2cFAa5B24850493298DCb8969fe11FEeFfc366,
        0xc2E97Ae6Ca9aAFB19CE0B8bCd1F4C50285db2377,
        0x68f6609d45A9dA001A88f7A3b9ec236Acf27e1f5,
        0x1C6Aed70006d8d65c6407Fa9b27C9359C1572f40,
        0x92c34B736B832d33209497f3904C4423d11E2a8a,
        0xCAf9131ADF841cC8A3f8C14cBc94Aa16cF0a2faA,
        0x9214835f82752E0574F3828A4400C36Ba386Df82,
        0xF09E6d5EE9b5B7FC84412260FD6E6D70dCadcd9C,
        0x8b529eF78046008f9d1FbC91c7407030De96EE32,
        0x669bd328f6C494949Ed9fB2dc8021557A6Dd005f,
        0xa77E705d7166750F53F60ca7e246BAFBE40f5c42,
        0x4fb30f8CcE1F80FC9CC45F7F626069be7549aF59,
        0xc210a4D56D99E095b126664fDCE545b369ED3FD0,
        0x03adFaA573aC1a9b19D2b8F79a5aAFFb9c2A0532,
        0xb6c82dCC296b055cEB6DBF1440d1379Bb4Dc1131,
        0x79bc970B69CC8fb31406C409692eD19612E39731,
        0x96b29b8dD6240144e203F9f45D55F8FE6fC466aB,
        0xb9b4800282BDC0DD2284fD321cf6800a24a7B8B0,
        0x06e477F88ae55721B72f0F2c545328eDe998803e,
        0xc25404122C1776689A6fD620d0F816Cb9e36e5dD,
        0x2192013589F926637cB288004db2f1dadb71D390,
        0xb0DebcB643eE79f19Ef659Bd01D0FAC12d058604,
        0x2E6Ff365367c9DB7C4a6140d37394aB8CF25C8A2,
        0x521e6f07bDfa2fF8D072887F0ef3bB908a3D9e2a,
        0x432d741Ae42175a2515121BcB917e7FE6d21Cf2e,
        0xAD89C778C7dBC0C7546cE7Fdf6A1d87C369A7892,
        0x8Fb2B9010780c418fbf84733ca3F0F5623EC2e7a,
        0x8B714cB45683733fD4Dc423FE6BF9A1d9F8DDD2C,
        0x4987f13D50AC3246E589433349095492e820f8fd,
        0xa4F2F6D9BAB9532d2A5B9B41504274E7FD0fEf4f,
        0x22472e7cA126b25fA031DeA6A7E0a7fbD9B2cdfd,
        0x595e187831CB1ebAf3e4c09423eef3E74DfDaD1E,
        0xaD96ACD2e6574682AEBf8f25774FA643bcaa3B5a,
        0x82C421023dBE34CC526F4c027577363E6C7Af9b6,
        0xc51101BAbC9Cc75118fBCe5187914e45841A7f01,
        0x09505A42D693D828B78CC87ed64DB9A0348Ca5e6,
        0xdD543DC0efeA305A4c595305C784166fbe87897B,
        0xb1f607F3B753bEf4756a30cfC235629A0c2d1E57,
        0x0E9B063789909565CEdA1Fba162474405A151E66,
        0x341979e95a3e2969EaDa286b635d6e29F7a76a71,
        0x117AD17Bf596D6337931f41141F34275Eab16129,
        0xbb85bFF98F145af30BA935Ae4DeD97C7A5Ce9bF2,
        0xfd005e01FAa45d3CD3fD4641FBCd9FFa1d26C703,
        0xaB14C744e5316475dd2384E6Bb95F9eCF4480bD5,
        0x595f5e9cF36dF0AAf12Ae27f1b3dC18622Fc5748,
        0xF5AC5943D16fC865824910033B756519DC396682,
        0xa0c507E52359160a334d9f1AeAA459b8BD39568a,
        0x007EA857fdbE8D19997b507a21B4c377e3B21D82,
        0x0E16cAA0E000cD3B68b4128C6aE62E846cb5b431,
        0x603c081e1d72063Cd691CAD3Bd2FEd68eBE8922a,
        0x5c53414E1f15D7668c2b9EC0A92482A64845f5f6,
        0xa87D56273CBE184927D92eEF1613ab2a72eacAC8,
        0xCc9757171B3cf4Dc86D1a86370D5B10662519096,
        0xeB92f0f58b218ad22a22741D5aa5bb7250E70045,
        0xa2608e76d835D0b3DB2Bbcbd4Bd1F78D47208353,
        0x9fD8Ef7E3867E962B401bC7289272653FEC11245,
        0x73cF6fCbEb5a5f56e550Cce5e0eeAC47f622EA2e,
        0x9b4A7002a086d4F8dFf04Af524987DdCa9b6ddCd,
        0x94Ae5310ba47b42D6D8DF3F20cD55650Ad43Be37,
        0xFd01eF34D30E6fA1169CBa769a22eEE454906f38,
        0xE3c3cD192Bdf289558A0bA645bc2c2c822F7EB06,
        0x18514a31077b33f32BDbeA52443f2C0EEb094Be1,
        0x0E9852b16AE49C99B84b0241E3C6F4a5692C6b05,
        0x49400E8A2d270669ED7cfc4Fd5A2804c0A87e1BB,
        0xDDc91d503Eeb7C3CB78559fB998C0a23354821ee,
        0x0C5Cd230e9EBF5A707CF1f822Dfc49664304DfD2,
        0x92751712B2F6ADE4AD1F35a837591A66394C6799,
        0x00ab2b9D924aaDCb60126A4050B68e8531A6A5a6,
        0x57Fe7D8A10F5C4aC2Ca953a5B0a6b4BBfEC187C9,
        0x5413E315A8c242132aC5DD626B0eceE616e5023D,
        0xC6Ad105483F89de96A3E423980fB550465A05D9b,
        0x26C43439031301a85e19868647DF46177869c4C8,
        0x9cB4a586bbdE7528DB256c3FCE08845255d892D9,
        0x1CbB1E8274E44287517A34De6AF3CF97dfD9E0Cb,
        0x2b3F539dAf59126F6F566adD0dEDc19959305e9d,
        0x2eCe359621497F4C9053c30912e9ecB7e74718c6,
        0x1A50D1AeD031eE6B22b37c84eD8f3f3487C5Ca47,
        0x5BD39fcEE33D45C5c5f615e09D2AA785Aa0c36C6,
        0x698230D8445C21E99f4CC81F8F733d205a661cD3,
        0x10b453C5379877d6b55B71D73Af7D8Fbc69eeF91,
        0x13deFCe8Be050f902f8eE06CB7f0E743e3e8b705,
        0xFF5A5bBC1b0f124974165b2190f460438d7CD220,
        0x7F5B2c355bFC0C6F3aE2D394534C29D3609FF542,
        0x97F4aa12F637BAe9c07cA492eE281534b4F3BB50,
        0x23b3511474c960960E4C030e572dADE633Cfc0F6,
        0x7cA50563448C1f87cF131D96dEF7124f995cf3aC,
        0xA8617c6BdE242B213bA283c93aCf034dfcbE66fA,
        0x37ae94b377B6D6522BCED1a448D144C69B6bfa9a,
        0xC44125EA298770DFA6B4a27A599CF014f19A573d,
        0x5F4BD8107FF5EB8fD25480C938662bBC11da27B8,
        0x57453361422BfBE5332eF75CBE1C38242c5deEEA,
        0x431588Aff8ea1BEcB1d8188D87195Aa95678BA0A,
        0x5952f70FEF1CbC26856d149646D4A8F97E923eE7,
        0x894d222eCeC91B9dFFf8bcBD164B7a72DF7469aD,
        0x5E9b31FA592913C2aD2356ed843F66057c81455D,
        0x58F1eFd2fBf415CFC0Ce30A13c36A2642690eDA0,
        0x84e47C7E20Ee8e8d6195A99788226EB488f5Fad7,
        0xCce7AcFb0d4760df15a1f87C92324B166e9C0638
    ];

    function setUp() public override {
        super.setUp();

        DataTypes.AaveV3EmodeParams memory params = DataTypes.AaveV3EmodeParams({emodeCategory: 3});

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(emodeModule),
            data: abi.encodeWithSelector(emodeModule.execute.selector, params)
        });

        vm.startPrank(admin);
        superloop.operate(moduleExecutionData);

        // register the above modules
        moduleRegistry.setModule("REPAY_MODULE", REPAY_MODULE);
        moduleRegistry.setModule("WITHDRAW_MODULE", WITHDRAW_MODULE);
        moduleRegistry.setModule("DEPOSIT_MODULE", DEPOSIT_MODULE);
        moduleRegistry.setModule("BORROW_MODULE", BORROW_MODULE);
        moduleRegistry.setModule("DEX_MODULE", DEX_MODULE);

        superloop.setRegisteredModule(REPAY_MODULE, true);
        superloop.setRegisteredModule(WITHDRAW_MODULE, true);
        superloop.setRegisteredModule(DEPOSIT_MODULE, true);
        superloop.setRegisteredModule(BORROW_MODULE, true);
        superloop.setRegisteredModule(DEX_MODULE, true);
        vm.stopPrank();

        vm.label(oldVault, "oldVault");
        vm.label(address(superloop), "newVault");
        vm.label(REPAY_MODULE, "REPAY_MODULE_OLD");
        vm.label(WITHDRAW_MODULE, "WITHDRAW_MODULE_OLD");
        vm.label(DEPOSIT_MODULE, "DEPOSIT_MODULE_OLD");
        vm.label(BORROW_MODULE, "BORROW_MODULE_OLD");
        vm.label(DEX_MODULE, "DEX_MODULE_OLD");
    }

    function test_migration() public {
        // deploy migration helper
        MigrationHelper migrationHelper = new MigrationHelper(
            AAVE_V3_POOL_ADDRESSES_PROVIDER,
            REPAY_MODULE,
            WITHDRAW_MODULE,
            DEPOSIT_MODULE,
            BORROW_MODULE,
            DEX_MODULE,
            USDC
        );
        vm.label(address(migrationHelper), "migrationHelper");

        // set migration helper contract as priveledged address in old vault
        address oldVaultAdmin = ISuperloop(oldVault).vaultAdmin();
        vm.prank(oldVaultAdmin);
        ISuperloop(oldVault).setPrivilegedAddress(address(migrationHelper), true);

        // set migration helper contract as deposit manager and vault operator in new vault
        vm.startPrank(admin);
        superloop.setDepositManagerModule(address(migrationHelper));
        superloop.setVaultOperator(address(migrationHelper));

        // set migration helper as vault in new accountant module
        accountant.setVault(address(migrationHelper));
        accountant.transferOwnership(address(migrationHelper));
        vm.stopPrank();

        address[] memory users = ALL_HOLDERS;

        // old balances
        uint256 oldVaultXTZBalance = IERC20(XTZ).balanceOf(oldVault);
        uint256 oldVaultSTXTZBalance = IERC20(ST_XTZ).balanceOf(oldVault);
        (uint256 oldVaultLendBalance,,,,,,,,) = poolDataProvider.getUserReserveData(ST_XTZ, oldVault);
        (,, uint256 oldVaultBorrowBalance,,,,,,) = poolDataProvider.getUserReserveData(XTZ, oldVault);

        console.log("OLD VAULT STATE INITIAL");
        console.log("oldVaultXTZBalance", oldVaultXTZBalance);
        console.log("oldVaultSTXTZBalance", oldVaultSTXTZBalance);
        console.log("oldVaultLendBalance", oldVaultLendBalance);
        console.log("oldVaultBorrowBalance", oldVaultBorrowBalance);
        console.log("old vault total supply", ISuperloop(oldVault).totalSupply());
        console.log("old vault total assets", ISuperloop(oldVault).totalAssets());

        assertEq(Ownable(address(accountant)).owner(), address(migrationHelper));
        assertEq(accountant.vault(), address(migrationHelper));

        uint256 maxSharesDelta = 100;

        // start recording gas
        uint256 startGas = gasleft();
        uint256 batches = 4;
        migrationHelper.migrate(oldVault, address(superloop), users, ST_XTZ, XTZ, batches, maxSharesDelta);

        console.log("migration complete");

        uint256 endGas = gasleft();
        uint256 gasUsed = startGas - endGas;
        console.log("gas used", gasUsed);
        uint256 newVaultXTZBalance = IERC20(XTZ).balanceOf(address(superloop));
        uint256 newVaultSTXTZBalance = IERC20(ST_XTZ).balanceOf(address(superloop));
        (uint256 newVaultLendBalance,,,,,,,,) = poolDataProvider.getUserReserveData(ST_XTZ, address(superloop));
        (,, uint256 newVaultBorrowBalance,,,,,,) = poolDataProvider.getUserReserveData(XTZ, address(superloop));
        uint256 newVaultLastRealizedFeeExchangeRate =
            IAccountantModule(ISuperloop(address(superloop)).accountant()).lastRealizedFeeExchangeRate();
        uint256 oldVaultLastRealizedFeeExchangeRate =
            IAccountantModule(ISuperloopLegacy(oldVault).accountantModule()).lastRealizedFeeExchangeRate();

        console.log("NEW VAULT STATE AFTER MIGRATION");
        console.log("newVaultXTZBalance", newVaultXTZBalance);
        console.log("newVaultSTXTZBalance", newVaultSTXTZBalance);
        console.log("newVaultLendBalance", newVaultLendBalance);
        console.log("newVaultBorrowBalance", newVaultBorrowBalance);
        console.log("new vault total supply", ISuperloop(address(superloop)).totalSupply());
        console.log("new vault total assets", ISuperloop(address(superloop)).totalAssets());
        console.log(
            "new vault last realized fee exchange rate",
            IAccountantModule(ISuperloop(address(superloop)).accountant()).lastRealizedFeeExchangeRate()
        );

        // assert balances of each of the users are the same

        for (uint256 i = 0; i < users.length; i++) {
            assertEq(ISuperloop(address(superloop)).balanceOf(users[i]), ISuperloop(oldVault).balanceOf(users[i]));
        }

        assertEq(newVaultLastRealizedFeeExchangeRate, oldVaultLastRealizedFeeExchangeRate);
        assertEq(Ownable(address(accountant)).owner(), address(admin));
        assertEq(accountant.vault(), address(superloop));

        console.log("gas used", gasUsed);

        oldVaultXTZBalance = IERC20(XTZ).balanceOf(oldVault);
        oldVaultSTXTZBalance = IERC20(ST_XTZ).balanceOf(oldVault);
        (oldVaultLendBalance,,,,,,,,) = poolDataProvider.getUserReserveData(ST_XTZ, oldVault);
        (,, oldVaultBorrowBalance,,,,,,) = poolDataProvider.getUserReserveData(XTZ, oldVault);

        console.log("OLD VAULT STATE AFTER MIGRATION");
        console.log("oldVaultXTZBalance", oldVaultXTZBalance);
        console.log("oldVaultSTXTZBalance", oldVaultSTXTZBalance);
        console.log("oldVaultLendBalance", oldVaultLendBalance);
        console.log("oldVaultBorrowBalance", oldVaultBorrowBalance);
        console.log("old vault total supply", ISuperloop(oldVault).totalSupply());
        console.log("old vault total assets", ISuperloop(oldVault).totalAssets());
        console.log(
            "old vault last realized fee exchange rate",
            IAccountantModule(ISuperloopLegacy(oldVault).accountantModule()).lastRealizedFeeExchangeRate()
        );
    }
}
