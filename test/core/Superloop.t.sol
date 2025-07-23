// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {TestBase} from "./TestBase.sol";
import {Superloop} from "../../src/core/Superloop/Superloop.sol";
import {DataTypes} from "../../src/common/DataTypes.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Errors} from "../../src/common/Errors.sol";

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
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountantModule: mockModule,
            withdrawManagerModule: mockModule,
            vaultAdmin: admin,
            treasury: treasury
        });
        superloopImplementation = new Superloop();
        proxyAdmin = new ProxyAdmin(address(this));

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(superloopImplementation),
            address(proxyAdmin),
            abi.encodeWithSelector(Superloop.initialize.selector, initData)
        );
        superloop = Superloop(address(proxy));

        _deployAccountant(address(superloop));
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
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountantModule: mockModule,
            withdrawManagerModule: mockModule,
            vaultAdmin: admin,
            treasury: treasury
        });

        Superloop newImplementation = new Superloop();
        ProxyAdmin newProxyAdmin = new ProxyAdmin(address(this));

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(newImplementation),
            address(newProxyAdmin),
            abi.encodeWithSelector(Superloop.initialize.selector, initData)
        );

        Superloop newSuperloop = Superloop(address(proxy));

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
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountantModule: mockModule,
            withdrawManagerModule: mockModule,
            vaultAdmin: admin,
            treasury: treasury
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
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountantModule: mockModule,
            withdrawManagerModule: mockModule,
            vaultAdmin: admin,
            treasury: treasury
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

    function test_FallbackNotInExecutionContext() public {
        // Test that fallback reverts when not in execution context
        vm.expectRevert(bytes(Errors.CALLER_NOT_PRIVILEGED));
        (bool success,) = address(superloop).call(abi.encodeWithSignature("nonExistentFunction()"));
        assertTrue(success);
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
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountantModule: mockModule,
            withdrawManagerModule: mockModule,
            vaultAdmin: admin,
            treasury: treasury
        });

        vm.expectRevert();
        newContract.initialize(initData);
    }

    // ============ SuperloopBase.sol Tests ============

    function test_SetSupplyCap() public {
        uint256 newSupplyCap = 50000 * 10 ** 18;

        vm.prank(admin);
        superloop.setSupplyCap(newSupplyCap);

        // Test that supply cap was set correctly by trying to deposit more than cap
        vm.startPrank(user1);
        deal(XTZ, user1, 60000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);

        // Should revert when trying to deposit more than supply cap
        vm.expectRevert(bytes(Errors.SUPPLY_CAP_EXCEEDED));
        superloop.deposit(60000 * 10 ** 18, user1);
        vm.stopPrank();
    }

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

    function test_SetPrivilegedAddress() public {
        address privilegedUser = makeAddr("privilegedUser");

        vm.prank(admin);
        superloop.setPrivilegedAddress(privilegedUser, true);

        // Test that privileged user can transfer tokens
        vm.startPrank(privilegedUser);
        deal(XTZ, privilegedUser, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);
        superloop.deposit(100 * 10 ** 18, privilegedUser);

        // Should be able to transfer shares
        superloop.transfer(user2, 50 * 10 ** 18);
        vm.stopPrank();
    }

    function test_SetPrivilegedAddressRevertIfNotAdmin() public {
        address privilegedUser = makeAddr("privilegedUser");

        vm.prank(user1);
        vm.expectRevert(bytes(Errors.CALLER_NOT_VAULT_ADMIN));
        superloop.setPrivilegedAddress(privilegedUser, true);
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

    function test_MaxDepositNoSupplyCap() public {
        // Set supply cap to 0 (no cap)
        vm.prank(admin);
        superloop.setSupplyCap(0);

        uint256 maxDeposit = superloop.maxDeposit(address(0));
        assertEq(maxDeposit, type(uint256).max);
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

    function test_PreviewDeposit() public {
        _seed();
        // Mock total assets and total supply for preview calculation
        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector),
            abi.encode(1000 * 10 ** 18)
        );

        uint256 assets = 100 * 10 ** 18;
        uint256 shares = superloop.previewDeposit(assets);

        // Should return shares (conversion with performance fee consideration)
        assertGt(shares, 0);
    }

    function test_PreviewMint() public {
        _seed();
        // Mock total assets and total supply for preview calculation
        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector),
            abi.encode(1000 * 10 ** 18)
        );

        uint256 shares = 100 * 10 ** 20;
        uint256 assets = superloop.previewMint(shares);

        // Should return assets (conversion with performance fee consideration)
        assertGt(assets, 0);
    }

    function test_PreviewWithdraw() public {
        _seed();
        // Mock total assets and total supply for preview calculation
        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector),
            abi.encode(1000 * 10 ** 18)
        );

        uint256 assets = 100 * 10 ** 18;
        uint256 shares = superloop.previewWithdraw(assets);

        // Should return shares (conversion with performance fee consideration)
        assertGt(shares, 0);
    }

    function test_PreviewRedeem() public {
        _seed();
        // Mock total assets and total supply for preview calculation
        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector),
            abi.encode(1000 * 10 ** 18)
        );

        uint256 shares = 100 * 10 ** 18;
        uint256 assets = superloop.previewRedeem(shares);

        // Should return assets (conversion with performance fee consideration)
        assertGt(assets, 0);
    }

    function test_MaxMint() public {
        _seed();
        // Set a supply cap
        vm.prank(admin);
        superloop.setSupplyCap(1000 * 10 ** 18);

        // Mock total assets to be less than supply cap
        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector),
            abi.encode(500 * 10 ** 18)
        );

        uint256 maxMint = superloop.maxMint(address(0));
        assertGt(maxMint, 0);
    }

    function test_Deposit() public {
        vm.startPrank(user1);
        deal(XTZ, user1, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);

        // Mock accountant module calls
        vm.mockCall(
            address(accountantAaveV3), abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector), abi.encode(0)
        );

        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getPerformanceFee.selector),
            abi.encode(0)
        );

        uint256 assets = 100 * 10 ** 18;
        uint256 shares = superloop.deposit(assets, user1);

        assertGt(shares, 0);
        assertEq(superloop.balanceOf(user1), shares);
        vm.stopPrank();
    }

    function test_DepositRevertIfZeroAmount() public {
        vm.startPrank(user1);
        deal(XTZ, user1, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);

        vm.expectRevert(bytes(Errors.INVALID_AMOUNT));
        superloop.deposit(0, user1);
        vm.stopPrank();
    }

    function test_DepositRevertIfExceedsSupplyCap() public {
        // Set a low supply cap
        vm.prank(admin);
        superloop.setSupplyCap(50 * 10 ** 18);

        vm.startPrank(user1);
        deal(XTZ, user1, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);

        vm.expectRevert(bytes(Errors.SUPPLY_CAP_EXCEEDED));
        superloop.deposit(100 * 10 ** 18, user1);
        vm.stopPrank();
    }

    function test_Mint() public {
        vm.startPrank(user1);
        deal(XTZ, user1, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);

        // Mock accountant module calls
        vm.mockCall(
            address(accountantAaveV3), abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector), abi.encode(0)
        );

        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getPerformanceFee.selector),
            abi.encode(0)
        );

        uint256 shares = 100 * 10 ** 18;
        uint256 assets = superloop.mint(shares, user1);

        assertGt(assets, 0);
        assertEq(superloop.balanceOf(user1), shares);
        vm.stopPrank();
    }

    function test_MintRevertIfZeroShares() public {
        vm.startPrank(user1);
        deal(XTZ, user1, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);

        vm.expectRevert(bytes(Errors.INVALID_SHARES_AMOUNT));
        superloop.mint(0, user1);
        vm.stopPrank();
    }

    function test_Withdraw() public {
        // First deposit some assets
        vm.startPrank(user1);
        deal(XTZ, user1, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);

        // Mock accountant module calls for deposit
        vm.mockCall(
            address(accountantAaveV3), abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector), abi.encode(0)
        );

        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getPerformanceFee.selector),
            abi.encode(0)
        );

        superloop.deposit(100 * 10 ** 18, user1);

        // Mock for withdraw
        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector),
            abi.encode(100 * 10 ** 18)
        );

        uint256 assets = 50 * 10 ** 18;
        uint256 shares = superloop.withdraw(assets, user1, user1);

        assertGt(shares, 0);
        vm.stopPrank();
    }

    function test_WithdrawRevertIfInsufficientBalance() public {
        vm.startPrank(user1);
        deal(XTZ, user1, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);

        // Mock accountant module calls
        vm.mockCall(
            address(accountantAaveV3), abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector), abi.encode(0)
        );

        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getPerformanceFee.selector),
            abi.encode(0)
        );

        superloop.deposit(100 * 10 ** 18, user1);

        // Try to withdraw more than deposited
        vm.expectRevert(bytes(Errors.INSUFFICIENT_BALANCE));
        superloop.withdraw(200 * 10 ** 18, user1, user1);
        vm.stopPrank();
    }

    function test_Redeem() public {
        // First deposit some assets
        vm.startPrank(user1);
        deal(XTZ, user1, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);

        // Mock accountant module calls for deposit
        vm.mockCall(
            address(accountantAaveV3), abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector), abi.encode(0)
        );

        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getPerformanceFee.selector),
            abi.encode(0)
        );

        uint256 initialShares = superloop.deposit(100 * 10 ** 18, user1);

        // Mock for redeem
        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector),
            abi.encode(100 * 10 ** 18)
        );

        uint256 shares = initialShares / 2;
        uint256 assets = superloop.redeem(shares, user1, user1);

        assertGt(assets, 0);
        vm.stopPrank();
    }

    function test_RedeemRevertIfInsufficientBalance() public {
        _seed();

        vm.startPrank(user1);
        deal(XTZ, user1, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);
        uint256 shares = superloop.deposit(100 * 10 ** 18, user1);

        // Try to redeem more shares than owned
        vm.expectRevert(bytes(Errors.INSUFFICIENT_BALANCE));
        superloop.redeem(shares + 1, user1, user1);
        vm.stopPrank();
    }

    function test_TransferOnlyPrivileged() public {
        // Set user1 as privileged
        vm.prank(admin);
        superloop.setPrivilegedAddress(user1, true);

        // Give user1 some shares
        vm.startPrank(user1);
        deal(XTZ, user1, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);

        // Mock accountant module calls
        vm.mockCall(
            address(accountantAaveV3), abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector), abi.encode(0)
        );

        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getPerformanceFee.selector),
            abi.encode(0)
        );

        superloop.deposit(100 * 10 ** 18, user1);

        // Should be able to transfer
        superloop.transfer(user2, 50 * 10 ** 18);
        assertEq(superloop.balanceOf(user2), 50 * 10 ** 18);
        vm.stopPrank();
    }

    function test_TransferRevertIfNotPrivileged() public {
        // Give user1 some shares without making them privileged
        vm.startPrank(user1);
        deal(XTZ, user1, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);

        // Mock accountant module calls
        vm.mockCall(
            address(accountantAaveV3), abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector), abi.encode(0)
        );

        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getPerformanceFee.selector),
            abi.encode(0)
        );

        superloop.deposit(100 * 10 ** 18, user1);

        // Should not be able to transfer
        vm.expectRevert(bytes(Errors.CALLER_NOT_PRIVILEGED));
        superloop.transfer(user2, 50 * 10 ** 18);
        vm.stopPrank();
    }

    function test_TransferFromOnlyPrivileged() public {
        _seed();
        // Set user2 as privileged
        vm.prank(admin);
        superloop.setPrivilegedAddress(user2, true);

        // Give user2 some shares
        vm.startPrank(user2);
        deal(XTZ, user2, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);

        superloop.deposit(100 * 10 ** 18, user2);
        vm.stopPrank();

        // user1 should be able to transferFrom
        vm.startPrank(user2);
        superloop.transfer(user1, 100);
        assertEq(superloop.balanceOf(user1), 100);
        vm.stopPrank();
    }

    function test_TransferFromRevertIfNotPrivileged() public {
        // Give user2 some shares
        vm.startPrank(user2);
        deal(XTZ, user2, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);

        // Mock accountant module calls
        vm.mockCall(
            address(accountantAaveV3), abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector), abi.encode(0)
        );

        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getPerformanceFee.selector),
            abi.encode(0)
        );

        superloop.deposit(100 * 10 ** 18, user2);
        vm.stopPrank();

        // user1 should not be able to transferFrom without being privileged
        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.CALLER_NOT_PRIVILEGED));
        superloop.transferFrom(user2, user1, 50 * 10 ** 18);
        vm.stopPrank();
    }

    function test_PerformanceFeeRealization() public {
        // Set up initial deposit
        vm.startPrank(user1);
        deal(XTZ, user1, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);

        // Mock accountant module calls for initial deposit
        vm.mockCall(
            address(accountantAaveV3), abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector), abi.encode(0)
        );

        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getPerformanceFee.selector),
            abi.encode(0)
        );

        superloop.deposit(100 * 10 ** 18, user1);

        // Mock for performance fee calculation (simulate growth)
        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getTotalAssets.selector),
            abi.encode(110 * 10 ** 18) // 10% growth
        );

        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.getPerformanceFee.selector),
            abi.encode(2 * 10 ** 18) // 2% performance fee
        );

        // Mock setLastRealizedFeeExchangeRate call
        vm.mockCall(
            address(accountantAaveV3),
            abi.encodeWithSelector(accountantAaveV3.setLastRealizedFeeExchangeRate.selector),
            abi.encode()
        );

        // Perform another deposit to trigger performance fee realization
        superloop.deposit(10 * 10 ** 18, user1);

        // Treasury should have received performance fee shares
        assertGt(superloop.balanceOf(treasury), 0);
        vm.stopPrank();
    }

    function test_DecimalsOffset() public view {
        // Test that decimals offset is correctly applied
        // The offset should be 2 as defined in SuperloopStorage
        assertEq(superloop.decimals(), 20); // Standard ERC20 decimals
    }

    // ============ Integration Tests ============

    function test_CompleteVaultLifecycle() public {
        _seed();
        // Test a complete vault lifecycle: deposit, mint, withdraw, redeem

        // 1. Initial deposit
        vm.startPrank(user1);
        deal(XTZ, user1, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);

        uint256 initialShares = superloop.deposit(100 * 10 ** 18, user1);
        assertGt(initialShares, 0);

        // 2. Mint additional shares
        uint256 additionalShares = 50 * 10 ** 20;
        uint256 assetsForMint = superloop.mint(additionalShares, user1);
        assertGt(assetsForMint, 0);

        // 3. Withdraw some assets
        uint256 withdrawAssets = 25 * 10 ** 18;
        uint256 withdrawShares = superloop.withdraw(withdrawAssets, user1, user1);
        assertGt(withdrawShares, 0);

        // 4. Redeem some shares
        uint256 redeemShares = 25 * 10 ** 20;
        uint256 redeemAssets = superloop.redeem(redeemShares, user1, user1);
        assertGt(redeemAssets, 0);

        vm.stopPrank();
    }

    function test_SupplyCapEnforcement() public {
        // Test that supply cap is properly enforced across multiple users
        _seed();

        // Set a supply cap
        vm.prank(admin);
        superloop.setSupplyCap(250 * 10 ** 18);

        // User1 deposits
        vm.startPrank(user1);
        deal(XTZ, user1, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);

        superloop.deposit(100 * 10 ** 18, user1);
        vm.stopPrank();

        // User2 tries to deposit more than remaining cap
        vm.startPrank(user2);
        deal(XTZ, user2, 1000 * 10 ** 18);
        IERC20(XTZ).approve(address(superloop), type(uint256).max);

        // Should be able to deposit up to the cap
        superloop.deposit(50 * 10 ** 18, user2);

        // Should not be able to deposit more
        vm.expectRevert(bytes(Errors.SUPPLY_CAP_EXCEEDED));
        superloop.deposit(1 * 10 ** 18, user2);
        vm.stopPrank();
    }

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
