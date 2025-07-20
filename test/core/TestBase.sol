// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Superloop} from "../../src/core/Superloop.sol";
import {DataTypes} from "../../src/common/DataTypes.sol";
import {SuperloopModuleRegistry} from "../../src/core/ModuleRegistry/ModuleRegistry.sol";

contract TestBase is Test {
    address public constant ST_XTZ = 0x0000000000000000000000000000000000000000;
    address public constant XTZ = 0x0000000000000000000000000000000000000000;
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
