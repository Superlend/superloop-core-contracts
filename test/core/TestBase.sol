// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Superloop} from "../../src/core/Superloop.sol";
import {DataTypes} from "../../src/common/DataTypes.sol";
import {SuperloopModuleRegistry} from "../../src/core/ModuleRegistry/ModuleRegistry.sol";

contract TestBase is Test {
    address public constant ST_XTZ = 0x01F07f4d78d47A64F4C3B2b65f513f15Be6E1854;
    address public constant XTZ = 0xc9B53AB2679f573e480d01e0f49e2B5CFB7a3EAb;
    address public constant AAVE_V3_POOL_ADDRESSES_PROVIDER = 0x5ccF60c7E10547c5389E9cBFf543E5D0Db9F4feC;
    address public constant AAVE_V3_POOL_DATA_PROVIDER = 0x99e8269dDD5c7Af0F1B3973A591b47E8E001BCac;
    address public constant AAVE_V3_PRICE_ORACLE = 0xeCF313dE38aA85EF618D06D1A602bAa917D62525;
    address public constant XTZ_WHALE = 0x008ae222661B6A42e3A097bd7AAC15412829106b;

    address public admin;
    address public treasury;

    SuperloopModuleRegistry public moduleRegistry;
    Superloop public superloop;

    function setUp() public virtual {
        vm.createSelectFork("etherlink");
        admin = makeAddr("admin");
        treasury = makeAddr("treasury");

        vm.startPrank(admin);
        moduleRegistry = new SuperloopModuleRegistry();
        vm.stopPrank();
    }
}
