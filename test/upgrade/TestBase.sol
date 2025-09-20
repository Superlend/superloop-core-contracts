// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Superloop} from "../../src/core/Superloop/Superloop.sol";
import {DataTypes} from "../../src/common/DataTypes.sol";
import {SuperloopModuleRegistry} from "../../src/core/ModuleRegistry/ModuleRegistry.sol";
import {AaveV3FlashloanModule} from "../../src/modules/AaveV3FlashloanModule.sol";
import {AaveV3CallbackHandler} from "../../src/modules/callback/AaveV3CallbackHandler.sol";
import {AaveV3EmodeModule} from "../../src/modules/AaveV3EmodeModule.sol";
import {AaveV3SupplyModule} from "../../src/modules/AaveV3SupplyModule.sol";
import {AaveV3WithdrawModule} from "../../src/modules/AaveV3WithdrawModule.sol";
import {AaveV3BorrowModule} from "../../src/modules/AaveV3BorrowModule.sol";
import {AaveV3RepayModule} from "../../src/modules/AaveV3RepayModule.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {UniversalDexModule} from "../../src/modules/UniversalDexModule.sol";
import {AccountantAaveV3} from "../../src/core/Accountant/aaveV3Accountant/AccountantAaveV3.sol";
import {WithdrawManager} from "../../src/core/WithdrawManager/Legacy/WithdrawManager.sol";
import {DepositManager} from "../../src/core/DepositManager/DepositManager.sol";

contract TestBase is Test {
    address public constant ST_XTZ = 0x01F07f4d78d47A64F4C3B2b65f513f15Be6E1854;
    address public constant XTZ = 0xc9B53AB2679f573e480d01e0f49e2B5CFB7a3EAb;
    address public constant AAVE_V3_POOL_ADDRESSES_PROVIDER = 0x5ccF60c7E10547c5389E9cBFf543E5D0Db9F4feC;
    address public constant AAVE_V3_POOL_DATA_PROVIDER = 0x99e8269dDD5c7Af0F1B3973A591b47E8E001BCac;
    address public constant AAVE_V3_PRICE_ORACLE = 0xeCF313dE38aA85EF618D06D1A602bAa917D62525;
    address public constant POOL = 0x3bD16D195786fb2F509f2E2D7F69920262EF114D;
    address public constant XTZ_WHALE = 0x008ae222661B6A42e3A097bd7AAC15412829106b;
    address public constant STXTZ_WHALE = 0x65142dEC2969f1a3083Ad31541Ef4B73871C8C9B;
    address public constant USDT_WHALE = 0x998098A1B2E95e2b8f15360676428EdFd976861f;
    uint256 public constant PERFORMANCE_FEE = 2000; // 20%
    address public constant USDT = 0x2C03058C8AFC06713be23e58D2febC8337dbfE6A;
    address public constant USDC = 0x796Ea11Fa2dD751eD01b53C372fFDB4AAa8f00F9;
    address public constant WXTZ = 0xc9B53AB2679f573e480d01e0f49e2B5CFB7a3EAb;
    address public constant WBTC = 0xbFc94CD2B1E55999Cfc7347a9313e88702B83d0F;
    address public constant ROUTER = 0xbfe9C246A5EdB4F021C8910155EC93e7CfDaB7a0;
    address public constant USDC_WHALE = 0xd03bfdF9B26DB1e6764724d914d7c3d18106a9Fb;
    address public constant POOL_CONFIGURATOR = 0x30F6880Bb1cF780a49eB4Ef64E64585780AAe060;
    address public constant POOL_ADMIN = 0x669bd328f6C494949Ed9fB2dc8021557A6Dd005f;

    address public admin;
    address public treasury;
    address public vaultOperator;

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
    DepositManager public depositManager;

    address public mockModule;
    AaveV3EmodeModule public emodeModule;
    IPoolDataProvider public poolDataProvider;
    IPool public pool;

    function setUp() public virtual {
        vm.createSelectFork("etherlink");

        moduleRegistry = SuperloopModuleRegistry(0x1480147Dd62d6Ea12630a617fb6743AB106CAFeA);
        accountantAaveV3 = AccountantAaveV3(0x3ffd7C95517Af13b999fDE7335c95201fD28B2Aa);
        withdrawManager = WithdrawManager(0x100295F097Aa724641E1037De05883C771BF3475);
        superloop = Superloop(0xe24e5DEbA01Ab0B5D78A0093442De0864832803E);
        flashloanModule = AaveV3FlashloanModule(0x653BDa572ca9D64B9f9De3Ade96Ed2Dd17fD55fB);
        callbackHandler = AaveV3CallbackHandler(0xbe775b5848D84283098e74a90F259A46f9342573);
        emodeModule = AaveV3EmodeModule(0x365916932cDCb4C6dcef136A065C4e3F81416BF6);
        supplyModule = AaveV3SupplyModule(0x66e82124412C61D7fF90ACFBa82936DD037D737E);
        withdrawModule = AaveV3WithdrawModule(0x1f5Ba080B9E5705DA47212167cA44611F78DB130);
        borrowModule = AaveV3BorrowModule(0x3de57294989d12066a94a8A16E977992F3cF8433);
        repayModule = AaveV3RepayModule(0x9AF8cCabC21ff594dA237f9694C4A9C6123480c6);
        dexModule = UniversalDexModule(0x38F5efC1267F6103c9b0FE802E1731E245f09Cd0);

        admin = 0x81b833Df09A7ce39C00ecE916EC54166d2a6B193;
        treasury = 0x669bd328f6C494949Ed9fB2dc8021557A6Dd005f;
        vaultOperator = 0x0E9852b16AE49C99B84b0241E3C6F4a5692C6b05;

        vm.label(address(flashloanModule), "flashloanModule");
        vm.label(address(callbackHandler), "callbackHandler");
        vm.label(address(emodeModule), "emodeModule");
        vm.label(address(supplyModule), "supplyModule");
        vm.label(address(withdrawModule), "withdrawModule");
        vm.label(address(borrowModule), "borrowModule");
        vm.label(address(repayModule), "repayModule");
        vm.label(address(dexModule), "dexModule");
        vm.label(admin, "admin");
        vm.label(treasury, "treasury");
        vm.label(vaultOperator, "vaultOperator");
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
}
