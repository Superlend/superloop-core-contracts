// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SuperloopModuleRegistry} from "../../../src/core/ModuleRegistry/ModuleRegistry.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {Errors} from "../../../src/common/Errors.sol";

contract ModuleRegistryTest is Test {
    SuperloopModuleRegistry public moduleRegistry;

    address public owner;
    address public user;
    address public module1;
    address public module2;
    address public module3;

    string public constant MODULE_NAME_1 = "UniversalDexModule";
    string public constant MODULE_NAME_2 = "AccountantModule";
    string public constant MODULE_NAME_3 = "WithdrawManagerModule";

    event ModuleSet(string name, bytes32 indexed id, address indexed module);

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        module1 = makeAddr("module1");
        module2 = makeAddr("module2");
        module3 = makeAddr("module3");

        vm.startPrank(owner);
        moduleRegistry = new SuperloopModuleRegistry();
        vm.stopPrank();
    }

    // ============ Constructor Tests ============

    function test_Constructor_SetsOwner() public view {
        assertEq(moduleRegistry.owner(), owner);
    }

    // ============ setModule Tests ============

    function test_SetModule_Success() public {
        vm.startPrank(owner);

        vm.expectEmit(true, true, false, true);
        emit ModuleSet(MODULE_NAME_1, keccak256(abi.encode(MODULE_NAME_1)), module1);

        moduleRegistry.setModule(MODULE_NAME_1, module1);

        vm.stopPrank();

        // Verify module was set correctly
        DataTypes.ModuleData memory moduleData = moduleRegistry.getModuleByName(MODULE_NAME_1);
        assertEq(moduleData.moduleName, MODULE_NAME_1);
        assertEq(moduleData.moduleAddress, module1);
    }

    function test_SetModule_OnlyOwner() public {
        vm.startPrank(user);

        vm.expectRevert();
        moduleRegistry.setModule(MODULE_NAME_1, module1);

        vm.stopPrank();
    }

    function test_SetModule_EmptyName() public {
        vm.startPrank(owner);

        vm.expectRevert();
        moduleRegistry.setModule("", module1);

        vm.stopPrank();
    }

    function test_SetModule_ZeroAddress() public {
        vm.startPrank(owner);

        vm.expectRevert();
        moduleRegistry.setModule(MODULE_NAME_1, address(0));

        vm.stopPrank();
    }

    function test_SetModule_MultipleModules() public {
        vm.startPrank(owner);

        moduleRegistry.setModule(MODULE_NAME_1, module1);
        moduleRegistry.setModule(MODULE_NAME_2, module2);
        moduleRegistry.setModule(MODULE_NAME_3, module3);

        vm.stopPrank();

        // Verify all modules were set correctly
        DataTypes.ModuleData memory moduleData1 = moduleRegistry.getModuleByName(MODULE_NAME_1);
        DataTypes.ModuleData memory moduleData2 = moduleRegistry.getModuleByName(MODULE_NAME_2);
        DataTypes.ModuleData memory moduleData3 = moduleRegistry.getModuleByName(MODULE_NAME_3);

        assertEq(moduleData1.moduleName, MODULE_NAME_1);
        assertEq(moduleData1.moduleAddress, module1);
        assertEq(moduleData2.moduleName, MODULE_NAME_2);
        assertEq(moduleData2.moduleAddress, module2);
        assertEq(moduleData3.moduleName, MODULE_NAME_3);
        assertEq(moduleData3.moduleAddress, module3);
    }

    function test_SetModule_OverwriteExisting() public {
        vm.startPrank(owner);

        moduleRegistry.setModule(MODULE_NAME_1, module1);
        moduleRegistry.setModule(MODULE_NAME_1, module2); // Overwrite with different address

        vm.stopPrank();

        // Verify module was overwritten
        DataTypes.ModuleData memory moduleData = moduleRegistry.getModuleByName(MODULE_NAME_1);
        assertEq(moduleData.moduleName, MODULE_NAME_1);
        assertEq(moduleData.moduleAddress, module2);
    }

    // ============ getModuleByName Tests ============

    function test_GetModuleByName_ExistingModule() public {
        vm.startPrank(owner);
        moduleRegistry.setModule(MODULE_NAME_1, module1);
        vm.stopPrank();

        DataTypes.ModuleData memory moduleData = moduleRegistry.getModuleByName(MODULE_NAME_1);
        assertEq(moduleData.moduleName, MODULE_NAME_1);
        assertEq(moduleData.moduleAddress, module1);
    }

    function test_GetModuleByName_NonExistentModule() public view {
        DataTypes.ModuleData memory moduleData = moduleRegistry.getModuleByName("NonExistentModule");
        assertEq(moduleData.moduleName, "");
        assertEq(moduleData.moduleAddress, address(0));
    }

    function test_GetModuleByName_CaseSensitive() public {
        vm.startPrank(owner);
        moduleRegistry.setModule(MODULE_NAME_1, module1);
        vm.stopPrank();

        // Different case should return empty data
        DataTypes.ModuleData memory moduleData = moduleRegistry.getModuleByName("universaldexmodule");
        assertEq(moduleData.moduleName, "");
        assertEq(moduleData.moduleAddress, address(0));
    }

    // ============ getModuleByAddress Tests ============

    function test_GetModuleByAddress_ExistingModule() public {
        vm.startPrank(owner);
        moduleRegistry.setModule(MODULE_NAME_1, module1);
        vm.stopPrank();

        DataTypes.ModuleData memory moduleData = moduleRegistry.getModuleByAddress(module1);
        assertEq(moduleData.moduleName, MODULE_NAME_1);
        assertEq(moduleData.moduleAddress, module1);
    }

    function test_GetModuleByAddress_NonExistentModule() public {
        DataTypes.ModuleData memory moduleData = moduleRegistry.getModuleByAddress(makeAddr("nonexistent"));
        assertEq(moduleData.moduleName, "");
        assertEq(moduleData.moduleAddress, address(0));
    }

    function test_GetModuleByAddress_ZeroAddress() public view {
        DataTypes.ModuleData memory moduleData = moduleRegistry.getModuleByAddress(address(0));
        assertEq(moduleData.moduleName, "");
        assertEq(moduleData.moduleAddress, address(0));
    }

    // ============ getModules Tests ============

    function test_GetModules_EmptyRegistry() public view {
        DataTypes.ModuleData[] memory modules = moduleRegistry.getModules();
        assertEq(modules.length, 0);
    }

    function test_GetModules_SingleModule() public {
        vm.startPrank(owner);
        moduleRegistry.setModule(MODULE_NAME_1, module1);
        vm.stopPrank();

        DataTypes.ModuleData[] memory modules = moduleRegistry.getModules();
        assertEq(modules.length, 1);
        assertEq(modules[0].moduleName, MODULE_NAME_1);
        assertEq(modules[0].moduleAddress, module1);
    }

    function test_GetModules_MultipleModules() public {
        vm.startPrank(owner);
        moduleRegistry.setModule(MODULE_NAME_1, module1);
        moduleRegistry.setModule(MODULE_NAME_2, module2);
        moduleRegistry.setModule(MODULE_NAME_3, module3);
        vm.stopPrank();

        DataTypes.ModuleData[] memory modules = moduleRegistry.getModules();
        assertEq(modules.length, 3);

        // Verify all modules are present (order may vary)
        bool found1 = false;
        bool found2 = false;
        bool found3 = false;

        for (uint256 i = 0; i < modules.length; i++) {
            if (keccak256(abi.encode(modules[i].moduleName)) == keccak256(abi.encode(MODULE_NAME_1))) {
                assertEq(modules[i].moduleAddress, module1);
                found1 = true;
            } else if (keccak256(abi.encode(modules[i].moduleName)) == keccak256(abi.encode(MODULE_NAME_2))) {
                assertEq(modules[i].moduleAddress, module2);
                found2 = true;
            } else if (keccak256(abi.encode(modules[i].moduleName)) == keccak256(abi.encode(MODULE_NAME_3))) {
                assertEq(modules[i].moduleAddress, module3);
                found3 = true;
            }
        }

        assertTrue(found1 && found2 && found3, "All modules should be found");
    }

    // ============ isModuleWhitelisted Tests ============

    function test_IsModuleWhitelisted_WhitelistedModule() public {
        vm.startPrank(owner);
        moduleRegistry.setModule(MODULE_NAME_1, module1);
        vm.stopPrank();

        assertTrue(moduleRegistry.isModuleWhitelisted(module1));
    }

    function test_IsModuleWhitelisted_NonWhitelistedModule() public view {
        assertFalse(moduleRegistry.isModuleWhitelisted(module1));
    }

    function test_IsModuleWhitelisted_ZeroAddress() public view {
        assertFalse(moduleRegistry.isModuleWhitelisted(address(0)));
    }

    // ============ Integration Tests ============

    function test_Integration_FullWorkflow() public {
        vm.startPrank(owner);

        // Set multiple modules
        moduleRegistry.setModule(MODULE_NAME_1, module1);
        moduleRegistry.setModule(MODULE_NAME_2, module2);
        moduleRegistry.setModule(MODULE_NAME_3, module3);

        vm.stopPrank();

        // Test getModuleByName for all modules
        DataTypes.ModuleData memory data1 = moduleRegistry.getModuleByName(MODULE_NAME_1);
        DataTypes.ModuleData memory data2 = moduleRegistry.getModuleByName(MODULE_NAME_2);
        DataTypes.ModuleData memory data3 = moduleRegistry.getModuleByName(MODULE_NAME_3);

        assertEq(data1.moduleName, MODULE_NAME_1);
        assertEq(data1.moduleAddress, module1);
        assertEq(data2.moduleName, MODULE_NAME_2);
        assertEq(data2.moduleAddress, module2);
        assertEq(data3.moduleName, MODULE_NAME_3);
        assertEq(data3.moduleAddress, module3);

        // Test getModuleByAddress for all modules
        DataTypes.ModuleData memory addrData1 = moduleRegistry.getModuleByAddress(module1);
        DataTypes.ModuleData memory addrData2 = moduleRegistry.getModuleByAddress(module2);
        DataTypes.ModuleData memory addrData3 = moduleRegistry.getModuleByAddress(module3);

        assertEq(addrData1.moduleName, MODULE_NAME_1);
        assertEq(addrData1.moduleAddress, module1);
        assertEq(addrData2.moduleName, MODULE_NAME_2);
        assertEq(addrData2.moduleAddress, module2);
        assertEq(addrData3.moduleName, MODULE_NAME_3);
        assertEq(addrData3.moduleAddress, module3);

        // Test isModuleWhitelisted for all modules
        assertTrue(moduleRegistry.isModuleWhitelisted(module1));
        assertTrue(moduleRegistry.isModuleWhitelisted(module2));
        assertTrue(moduleRegistry.isModuleWhitelisted(module3));

        // Test getModules returns all modules
        DataTypes.ModuleData[] memory allModules = moduleRegistry.getModules();
        assertEq(allModules.length, 3);
    }
}
