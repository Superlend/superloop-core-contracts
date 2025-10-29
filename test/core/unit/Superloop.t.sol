// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {TestBase} from "../TestBase.sol";
import {Superloop} from "../../../src/core/Superloop/Superloop.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Errors} from "../../../src/common/Errors.sol";

contract SuperloopTest is TestBase {
    Superloop public superloopImplementation;
    ProxyAdmin public proxyAdmin;
    address public user1;
    address public user2;

    function setUp() public override {
        super.setUp();

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.startPrank(admin);
        _deployModules();

        address[] memory modules = new address[](5);
        modules[0] = address(supplyModule);
        modules[1] = address(withdrawModule);
        modules[2] = address(borrowModule);
        modules[3] = address(repayModule);
        modules[4] = address(dexModule);

        DataTypes.VaultInitData memory initData = DataTypes.VaultInitData({
            asset: XTZ,
            name: "XTZ Vault",
            symbol: "XTZV",
            supplyCap: 100000 * 10 ** 18,
            minimumDepositAmount: 100,
            instantWithdrawFee: 0,
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountant: mockModule,
            withdrawManager: mockModule,
            depositManager: mockModule,
            cashReserve: 1000,
            vaultAdmin: admin,
            treasury: treasury,
            vaultOperator: admin
        });
        superloopImplementation = new Superloop();
        proxyAdmin = new ProxyAdmin(address(this));

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(superloopImplementation),
            address(proxyAdmin),
            abi.encodeWithSelector(Superloop.initialize.selector, initData)
        );
        superloop = Superloop(payable(address(proxy)));

        _deployAccountant(address(superloop), _singleAddressArray(ST_XTZ), _singleAddressArray(XTZ));
        _deployWithdrawManager(address(superloop));

        superloop.setAccountantModule(address(accountantAaveV3));
        superloop.setWithdrawManagerModule(address(withdrawManager));

        vm.stopPrank();

        vm.label(address(superloop), "superloop");
        vm.label(user1, "user1");
        vm.label(user2, "user2");
    }

    // ============ Superloop.sol Tests ============

    function test_Initialize() public {
        // Test that initialization works correctly
        address[] memory modules = new address[](1);
        modules[0] = address(supplyModule);

        DataTypes.VaultInitData memory initData = DataTypes.VaultInitData({
            asset: XTZ,
            name: "Test Vault",
            symbol: "TEST",
            supplyCap: 1000 * 10 ** 18,
            minimumDepositAmount: 100,
            instantWithdrawFee: 0,
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountant: mockModule,
            withdrawManager: mockModule,
            depositManager: mockModule,
            cashReserve: 1000,
            vaultAdmin: admin,
            treasury: treasury,
            vaultOperator: admin
        });

        Superloop newImplementation = new Superloop();
        ProxyAdmin newProxyAdmin = new ProxyAdmin(address(this));

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(newImplementation),
            address(newProxyAdmin),
            abi.encodeWithSelector(Superloop.initialize.selector, initData)
        );

        Superloop newSuperloop = Superloop(payable(address(proxy)));

        // Test that the contract is properly initialized
        assertEq(newSuperloop.name(), "Test Vault");
        assertEq(newSuperloop.symbol(), "TEST");
        assertEq(newSuperloop.asset(), XTZ);
    }

    function test_InitializeRevertIfAlreadyInitialized() public {
        // Test that initialize reverts if called again
        address[] memory modules = new address[](1);
        modules[0] = address(supplyModule);

        DataTypes.VaultInitData memory initData = DataTypes.VaultInitData({
            asset: XTZ,
            name: "Test Vault",
            symbol: "TEST",
            supplyCap: 1000 * 10 ** 18,
            minimumDepositAmount: 100,
            instantWithdrawFee: 0,
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountant: mockModule,
            withdrawManager: mockModule,
            depositManager: mockModule,
            cashReserve: 1000,
            vaultAdmin: admin,
            treasury: treasury,
            vaultOperator: admin
        });

        vm.expectRevert();
        superloop.initialize(initData);
    }

    function test_InitializeRevertIfInvalidModule() public {
        // Test that initialization reverts if module is not whitelisted
        address[] memory modules = new address[](1);
        modules[0] = address(0x123); // Invalid module

        DataTypes.VaultInitData memory initData = DataTypes.VaultInitData({
            asset: XTZ,
            name: "Test Vault",
            symbol: "TEST",
            supplyCap: 1000 * 10 ** 18,
            minimumDepositAmount: 100,
            instantWithdrawFee: 0,
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountant: mockModule,
            withdrawManager: mockModule,
            depositManager: mockModule,
            cashReserve: 1000,
            vaultAdmin: admin,
            treasury: treasury,
            vaultOperator: admin
        });

        Superloop newImplementation = new Superloop();
        ProxyAdmin newProxyAdmin = new ProxyAdmin(address(this));

        vm.expectRevert(bytes(Errors.INVALID_MODULE));
        new TransparentUpgradeableProxy(
            address(newImplementation),
            address(newProxyAdmin),
            abi.encodeWithSelector(Superloop.initialize.selector, initData)
        );
    }

    function test_ConstructorDisablesInitializers() public {
        // Test that the constructor properly disables initializers
        Superloop newContract = new Superloop();

        // Should revert if we try to initialize directly
        address[] memory modules = new address[](1);
        modules[0] = address(supplyModule);

        DataTypes.VaultInitData memory initData = DataTypes.VaultInitData({
            asset: XTZ,
            name: "Test Vault",
            symbol: "TEST",
            supplyCap: 1000 * 10 ** 18,
            minimumDepositAmount: 100,
            instantWithdrawFee: 100,
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountant: mockModule,
            withdrawManager: mockModule,
            depositManager: mockModule,
            cashReserve: 1000,
            vaultAdmin: admin,
            treasury: treasury,
            vaultOperator: admin
        });

        vm.expectRevert();
        newContract.initialize(initData);
    }

    // ============ SuperloopBase.sol Tests ============

    function test_SetSupplyCapRevertIfNotAdmin() public {
        uint256 newSupplyCap = 50000 * 10 ** 18;

        vm.prank(user1);
        vm.expectRevert(bytes(Errors.CALLER_NOT_VAULT_ADMIN));
        superloop.setSupplyCap(newSupplyCap);
    }

    function test_SetSuperloopModuleRegistry() public {
        address newRegistry = makeAddr("newRegistry");

        vm.prank(admin);
        superloop.setSuperloopModuleRegistry(newRegistry);

        // Note: We can't directly test the storage change, but we can verify it doesn't revert
    }

    function test_SetSuperloopModuleRegistryRevertIfNotAdmin() public {
        address newRegistry = makeAddr("newRegistry");

        vm.prank(user1);
        vm.expectRevert(bytes(Errors.CALLER_NOT_VAULT_ADMIN));
        superloop.setSuperloopModuleRegistry(newRegistry);
    }

    function test_SetRegisteredModule() public {
        address newModule = makeAddr("newModule");

        vm.prank(admin);
        superloop.setRegisteredModule(newModule, true);

        // Note: We can't directly test the storage change, but we can verify it doesn't revert
    }

    function test_SetRegisteredModuleRevertIfNotAdmin() public {
        address newModule = makeAddr("newModule");

        vm.prank(user1);
        vm.expectRevert(bytes(Errors.CALLER_NOT_VAULT_ADMIN));
        superloop.setRegisteredModule(newModule, true);
    }

    function test_SetCallbackHandler() public {
        bytes32 key = keccak256(abi.encodePacked(address(0x123), bytes4(0x12345678)));
        address handler = makeAddr("handler");

        vm.prank(admin);
        superloop.setCallbackHandler(key, handler);

        // Note: We can't directly test the storage change, but we can verify it doesn't revert
    }

    function test_SetCallbackHandlerRevertIfNotAdmin() public {
        bytes32 key = keccak256(abi.encodePacked(address(0x123), bytes4(0x12345678)));
        address handler = makeAddr("handler");

        vm.prank(user1);
        vm.expectRevert(bytes(Errors.CALLER_NOT_VAULT_ADMIN));
        superloop.setCallbackHandler(key, handler);
    }

    function test_SetAccountantModule() public {
        address newAccountant = makeAddr("newAccountant");

        vm.prank(admin);
        superloop.setAccountantModule(newAccountant);

        // Note: We can't directly test the storage change, but we can verify it doesn't revert
    }

    function test_SetAccountantModuleRevertIfNotAdmin() public {
        address newAccountant = makeAddr("newAccountant");

        vm.prank(user1);
        vm.expectRevert(bytes(Errors.CALLER_NOT_VAULT_ADMIN));
        superloop.setAccountantModule(newAccountant);
    }

    function test_SetWithdrawManagerModule() public {
        address newWithdrawManager = makeAddr("newWithdrawManager");

        vm.prank(admin);
        superloop.setWithdrawManagerModule(newWithdrawManager);

        // Note: We can't directly test the storage change, but we can verify it doesn't revert
    }

    function test_SetWithdrawManagerModuleRevertIfNotAdmin() public {
        address newWithdrawManager = makeAddr("newWithdrawManager");

        vm.prank(user1);
        vm.expectRevert(bytes(Errors.CALLER_NOT_VAULT_ADMIN));
        superloop.setWithdrawManagerModule(newWithdrawManager);
    }

    function test_SetVaultAdmin() public {
        address newAdmin = makeAddr("newAdmin");

        vm.prank(admin);
        superloop.setVaultAdmin(newAdmin);

        // Test that new admin can call admin functions
        vm.prank(newAdmin);
        superloop.setSupplyCap(1000 * 10 ** 18);
    }

    function test_SetVaultAdminRevertIfNotAdmin() public {
        address newAdmin = makeAddr("newAdmin");

        vm.prank(user1);
        vm.expectRevert(bytes(Errors.CALLER_NOT_VAULT_ADMIN));
        superloop.setVaultAdmin(newAdmin);
    }

    function test_SetTreasury() public {
        address newTreasury = makeAddr("newTreasury");

        vm.prank(admin);
        superloop.setTreasury(newTreasury);

        // Note: We can't directly test the storage change, but we can verify it doesn't revert
    }

    function test_SetTreasuryRevertIfNotAdmin() public {
        address newTreasury = makeAddr("newTreasury");

        vm.prank(user1);
        vm.expectRevert(bytes(Errors.CALLER_NOT_VAULT_ADMIN));
        superloop.setTreasury(newTreasury);
    }

    function test_SetPrivilegedAddressRevertIfNotAdmin() public {
        address privilegedUser = makeAddr("privilegedUser");

        vm.prank(user1);
        vm.expectRevert(bytes(Errors.CALLER_NOT_VAULT_ADMIN));
        superloop.setPrivilegedAddress(privilegedUser, true);
    }

    function test_SetInstantWithdrawFeeRevertIfNotAdmin() public {
        uint256 newInstantWithdrawFee = 100;

        vm.prank(user1);
        vm.expectRevert(bytes(Errors.CALLER_NOT_VAULT_ADMIN));
        superloop.setInstantWithdrawFee(newInstantWithdrawFee);
    }

    function test_SetInstantWithdrawFeeRevertIfInvalidFee() public {
        uint256 newInstantWithdrawFee = 1000;

        vm.prank(admin);
        vm.expectRevert(bytes(Errors.INVALID_INSTANT_WITHDRAW_FEE));
        superloop.setInstantWithdrawFee(newInstantWithdrawFee);
    }

    function test_SetInstantWithdrawFee() public {
        uint256 newInstantWithdrawFee = 100;

        vm.prank(admin);
        superloop.setInstantWithdrawFee(newInstantWithdrawFee);

        assertEq(superloop.instantWithdrawFee(), newInstantWithdrawFee);
    }

    // ============ SuperloopVault.sol Tests ============

    function test_TotalAssets() public {
        // Mock the accountant module to return a specific value
        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector),
            abi.encode(1000 * 10 ** 18)
        );

        uint256 totalAssets = superloop.totalAssets();
        assertEq(totalAssets, 1000 * 10 ** 18);
    }

    function test_MaxDepositWithSupplyCap() public {
        // Set a supply cap
        vm.prank(admin);
        superloop.setSupplyCap(1000 * 10 ** 18);

        // Mock total assets to be less than supply cap
        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector),
            abi.encode(500 * 10 ** 18)
        );

        uint256 maxDeposit = superloop.maxDeposit(address(0));
        assertEq(maxDeposit, 500 * 10 ** 18);
    }

    function test_MaxDepositExceedsSupplyCap() public {
        // Set a supply cap
        vm.prank(admin);
        superloop.setSupplyCap(1000 * 10 ** 18);

        // Mock total assets to exceed supply cap
        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector),
            abi.encode(1500 * 10 ** 18)
        );

        uint256 maxDeposit = superloop.maxDeposit(address(0));
        assertEq(maxDeposit, 0);
    }

    function test_DecimalsOffset() public view {
        // Test that decimals offset is correctly applied
        // The offset should be 2 as defined in SuperloopStorage
        assertEq(superloop.decimals(), 20); // Standard ERC20 decimals
    }

    // ============ Integration Tests ============

    function test_skimRevertIfInvalidAsset() public {
        deal(XTZ, address(superloop), 1000 * 10 ** 18);

        vm.expectRevert(bytes(Errors.INVALID_SKIM_ASSET));

        vm.prank(admin);
        superloop.skim(XTZ);
    }

    function test_skim() public {
        deal(ST_XTZ, address(superloop), 1000 * 10 ** 18);

        vm.prank(admin);
        superloop.skim(ST_XTZ);

        assertEq(IERC20(ST_XTZ).balanceOf(treasury), 1000 * 10 ** 18);
        assertEq(IERC20(ST_XTZ).balanceOf(address(superloop)), 0);
    }

    function _seed() internal {
        vm.startPrank(admin);
        deal(XTZ, admin, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);
        superloop.deposit(100 * 10 ** 18, admin);
        vm.stopPrank();
    }
}
