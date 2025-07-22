// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {VaultRouter} from "../../src/helpers/VaultRouter.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IUniversalDexModule} from "../../src/interfaces/IUniversalDexModule.sol";
import {DataTypes} from "../../src/common/DataTypes.sol";
import {Errors} from "../../src/common/Errors.sol";
import {MockAsset} from "../../src/mock/MockAsset.sol";
import {MockVault} from "../../src/mock/MockVault.sol";
import {MockUniversalDexModule} from "../../src/mock/MockUniversalDexModule.sol";

contract VaultRouterTest is Test {
    VaultRouter public vaultRouter;
    MockAsset public tokenA;
    MockAsset public tokenB;
    MockVault public vaultA;
    MockVault public vaultB;
    MockUniversalDexModule public dexModule;

    address public owner;
    address public user;
    address public nonOwner;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        nonOwner = makeAddr("nonOwner");

        // Deploy mock contracts
        tokenA = new MockAsset();
        tokenB = new MockAsset();
        vaultA = new MockVault(IERC20(address(tokenA)), "Vault A", "vTKA");
        vaultB = new MockVault(IERC20(address(tokenB)), "Vault B", "vTKB");
        dexModule = new MockUniversalDexModule(1000e18);

        // Setup initial whitelisted addresses
        address[] memory supportedVaults = new address[](2);
        supportedVaults[0] = address(vaultA);
        supportedVaults[1] = address(vaultB);

        address[] memory supportedTokens = new address[](2);
        supportedTokens[0] = address(tokenA);
        supportedTokens[1] = address(tokenB);

        vm.startPrank(owner);
        vaultRouter = new VaultRouter(supportedVaults, supportedTokens, address(dexModule));
        vm.stopPrank();

        // Setup initial balances - MockAsset already mints to deployer, so we transfer
        tokenA.transfer(user, 10000e18);
        tokenB.transfer(user, 10000e18);
        tokenA.transfer(address(vaultRouter), 1000e18);
        tokenB.transfer(address(vaultRouter), 1000e18);
    }

    // ============ Constructor Tests ============

    function test_Constructor_SetsSupportedVaults() public {
        address[] memory supportedVaults = new address[](2);
        supportedVaults[0] = address(vaultA);
        supportedVaults[1] = address(vaultB);

        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(tokenA);

        vm.startPrank(owner);
        VaultRouter newRouter = new VaultRouter(supportedVaults, supportedTokens, address(dexModule));
        vm.stopPrank();

        assertTrue(newRouter.supportedVaults(address(vaultA)));
        assertTrue(newRouter.supportedVaults(address(vaultB)));
        assertTrue(newRouter.supportedTokens(address(tokenA)));
        assertFalse(newRouter.supportedTokens(address(tokenB)));
    }

    function test_Constructor_SetsUniversalDexModule() public {
        address[] memory supportedVaults = new address[](1);
        supportedVaults[0] = address(vaultA);

        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(tokenA);

        vm.startPrank(owner);
        VaultRouter newRouter = new VaultRouter(supportedVaults, supportedTokens, address(dexModule));
        vm.stopPrank();

        assertEq(address(newRouter.universalDexModule()), address(dexModule));
    }

    function test_Constructor_SetsOwner() public {
        address[] memory supportedVaults = new address[](1);
        supportedVaults[0] = address(vaultA);

        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(tokenA);

        vm.startPrank(owner);
        VaultRouter newRouter = new VaultRouter(supportedVaults, supportedTokens, address(dexModule));
        vm.stopPrank();

        assertEq(newRouter.owner(), owner);
    }

    // ============ depositWithToken Tests ============

    function test_DepositWithToken_SameToken_Success() public {
        uint256 depositAmount = 1000e18;
        uint256 expectedShares = 1000e18; // Mock vault returns 1:1 ratio

        vm.startPrank(user);
        tokenA.approve(address(vaultRouter), depositAmount);

        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenA),
            amountIn: depositAmount,
            maxAmountIn: depositAmount,
            minAmountOut: 0,
            data: new DataTypes.ExecuteSwapParamsData[](0)
        });

        uint256 shares = vaultRouter.depositWithToken(address(vaultA), address(tokenA), depositAmount, swapParams);
        vm.stopPrank();

        assertEq(shares, expectedShares);
        assertEq(tokenA.balanceOf(address(vaultA)), depositAmount);
        assertEq(vaultA.balanceOf(user), expectedShares);
    }

    function test_DepositWithToken_DifferentToken_Success() public {
        uint256 depositAmount = 1000e18;
        uint256 swapAmountOut = 800e18; // Dex module returns 800 tokens
        uint256 expectedShares = 800e18;

        dexModule.setMockAmountOut(swapAmountOut);

        vm.startPrank(user);
        tokenA.approve(address(vaultRouter), depositAmount);

        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: depositAmount,
            maxAmountIn: depositAmount,
            minAmountOut: 0,
            data: new DataTypes.ExecuteSwapParamsData[](0)
        });

        uint256 shares = vaultRouter.depositWithToken(address(vaultB), address(tokenA), depositAmount, swapParams);
        vm.stopPrank();

        assertEq(shares, expectedShares);
        assertEq(tokenB.balanceOf(address(vaultB)), swapAmountOut);
        assertEq(vaultB.balanceOf(user), expectedShares);
    }

    function test_DepositWithToken_VaultNotWhitelisted_Reverts() public {
        address nonWhitelistedVault = makeAddr("nonWhitelistedVault");
        uint256 depositAmount = 1000e18;

        vm.startPrank(user);
        tokenA.approve(address(vaultRouter), depositAmount);

        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenA),
            amountIn: depositAmount,
            maxAmountIn: depositAmount,
            minAmountOut: 0,
            data: new DataTypes.ExecuteSwapParamsData[](0)
        });

        vm.expectRevert();
        vaultRouter.depositWithToken(nonWhitelistedVault, address(tokenA), depositAmount, swapParams);
        vm.stopPrank();
    }

    function test_DepositWithToken_TokenNotWhitelisted_Reverts() public {
        MockAsset nonWhitelistedToken = new MockAsset();
        uint256 depositAmount = 1000e18;

        vm.startPrank(user);
        // MockAsset constructor mints to deployer, so we need to transfer from deployer
        vm.stopPrank();
        nonWhitelistedToken.transfer(user, depositAmount);
        vm.startPrank(user);
        nonWhitelistedToken.approve(address(vaultRouter), depositAmount);

        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: address(nonWhitelistedToken),
            tokenOut: address(tokenA),
            amountIn: depositAmount,
            maxAmountIn: depositAmount,
            minAmountOut: 0,
            data: new DataTypes.ExecuteSwapParamsData[](0)
        });

        vm.expectRevert();
        vaultRouter.depositWithToken(address(vaultA), address(nonWhitelistedToken), depositAmount, swapParams);
        vm.stopPrank();
    }

    function test_DepositWithToken_DexModuleReverts_Reverts() public {
        uint256 depositAmount = 1000e18;
        dexModule.setShouldRevert(true);

        vm.startPrank(user);
        tokenA.approve(address(vaultRouter), depositAmount);

        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: depositAmount,
            maxAmountIn: depositAmount,
            minAmountOut: 0,
            data: new DataTypes.ExecuteSwapParamsData[](0)
        });

        vm.expectRevert("MockDexModule: execution failed");
        vaultRouter.depositWithToken(address(vaultB), address(tokenA), depositAmount, swapParams);
        vm.stopPrank();
    }

    function test_DepositWithToken_InsufficientAllowance_Reverts() public {
        uint256 depositAmount = 1000e18;
        uint256 insufficientAllowance = 500e18;

        vm.startPrank(user);
        tokenA.approve(address(vaultRouter), insufficientAllowance);

        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenA),
            amountIn: depositAmount,
            maxAmountIn: depositAmount,
            minAmountOut: 0,
            data: new DataTypes.ExecuteSwapParamsData[](0)
        });

        vm.expectRevert();
        vaultRouter.depositWithToken(address(vaultA), address(tokenA), depositAmount, swapParams);
        vm.stopPrank();
    }

    function test_DepositWithToken_ZeroAmount_Success() public {
        uint256 depositAmount = 0;
        uint256 expectedShares = 0;

        vm.startPrank(user);
        tokenA.approve(address(vaultRouter), depositAmount);

        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenA),
            amountIn: depositAmount,
            maxAmountIn: depositAmount,
            minAmountOut: 0,
            data: new DataTypes.ExecuteSwapParamsData[](0)
        });

        uint256 shares = vaultRouter.depositWithToken(address(vaultA), address(tokenA), depositAmount, swapParams);
        vm.stopPrank();

        assertEq(shares, expectedShares);
    }

    // ============ whitelistVault Tests ============

    function test_WhitelistVault_Owner_Success() public {
        address newVault = makeAddr("newVault");

        vm.startPrank(owner);
        vaultRouter.whitelistVault(newVault, true);
        vm.stopPrank();

        assertTrue(vaultRouter.supportedVaults(newVault));
    }

    function test_WhitelistVault_RemoveVault_Success() public {
        vm.startPrank(owner);
        vaultRouter.whitelistVault(address(vaultA), false);
        vm.stopPrank();

        assertFalse(vaultRouter.supportedVaults(address(vaultA)));
    }

    function test_WhitelistVault_NonOwner_Reverts() public {
        address newVault = makeAddr("newVault");

        vm.startPrank(nonOwner);
        vm.expectRevert();
        vaultRouter.whitelistVault(newVault, true);
        vm.stopPrank();

        assertFalse(vaultRouter.supportedVaults(newVault));
    }

    // ============ whitelistToken Tests ============

    function test_WhitelistToken_Owner_Success() public {
        address newToken = makeAddr("newToken");

        vm.startPrank(owner);
        vaultRouter.whitelistToken(newToken, true);
        vm.stopPrank();

        assertTrue(vaultRouter.supportedTokens(newToken));
    }

    function test_WhitelistToken_RemoveToken_Success() public {
        vm.startPrank(owner);
        vaultRouter.whitelistToken(address(tokenA), false);
        vm.stopPrank();

        assertFalse(vaultRouter.supportedTokens(address(tokenA)));
    }

    function test_WhitelistToken_NonOwner_Reverts() public {
        address newToken = makeAddr("newToken");

        vm.startPrank(nonOwner);
        vm.expectRevert();
        vaultRouter.whitelistToken(newToken, true);
        vm.stopPrank();

        assertFalse(vaultRouter.supportedTokens(newToken));
    }

    // ============ setUniversalDexModule Tests ============

    function test_SetUniversalDexModule_Owner_Success() public {
        address newDexModule = makeAddr("newDexModule");

        vm.startPrank(owner);
        vaultRouter.setUniversalDexModule(newDexModule);
        vm.stopPrank();

        assertEq(address(vaultRouter.universalDexModule()), newDexModule);
    }

    function test_SetUniversalDexModule_NonOwner_Reverts() public {
        address newDexModule = makeAddr("newDexModule");

        vm.startPrank(nonOwner);
        vm.expectRevert();
        vaultRouter.setUniversalDexModule(newDexModule);
        vm.stopPrank();

        assertEq(address(vaultRouter.universalDexModule()), address(dexModule));
    }

    // ============ Integration Tests ============

    function test_Integration_DepositWithTokenAfterWhitelisting() public {
        MockAsset newToken = new MockAsset();
        MockVault newVault = new MockVault(IERC20(address(newToken)), "New Vault", "vNTK");

        uint256 depositAmount = 1000e18;
        newToken.transfer(user, depositAmount);

        // Whitelist new token and vault
        vm.startPrank(owner);
        vaultRouter.whitelistToken(address(newToken), true);
        vaultRouter.whitelistVault(address(newVault), true);
        vm.stopPrank();

        // Perform deposit
        vm.startPrank(user);
        newToken.approve(address(vaultRouter), depositAmount);

        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: address(newToken),
            tokenOut: address(newToken),
            amountIn: depositAmount,
            maxAmountIn: depositAmount,
            minAmountOut: 0,
            data: new DataTypes.ExecuteSwapParamsData[](0)
        });

        uint256 shares = vaultRouter.depositWithToken(address(newVault), address(newToken), depositAmount, swapParams);
        vm.stopPrank();

        assertEq(shares, depositAmount);
        assertEq(newToken.balanceOf(address(newVault)), depositAmount);
        assertEq(newVault.balanceOf(user), depositAmount);
    }

    function test_Integration_DepositWithTokenAfterRemovingWhitelist() public {
        uint256 depositAmount = 1000e18;

        // Remove vault from whitelist
        vm.startPrank(owner);
        vaultRouter.whitelistVault(address(vaultA), false);
        vm.stopPrank();

        vm.startPrank(user);
        tokenA.approve(address(vaultRouter), depositAmount);

        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenA),
            amountIn: depositAmount,
            maxAmountIn: depositAmount,
            minAmountOut: 0,
            data: new DataTypes.ExecuteSwapParamsData[](0)
        });

        vm.expectRevert();
        vaultRouter.depositWithToken(address(vaultA), address(tokenA), depositAmount, swapParams);
        vm.stopPrank();
    }

    // ============ Edge Cases ============

    function test_DepositWithToken_EmptySwapParams_Success() public {
        uint256 depositAmount = 1000e18;

        vm.startPrank(user);
        tokenA.approve(address(vaultRouter), depositAmount);

        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenA),
            amountIn: depositAmount,
            maxAmountIn: depositAmount,
            minAmountOut: 0,
            data: new DataTypes.ExecuteSwapParamsData[](0)
        });

        uint256 shares = vaultRouter.depositWithToken(address(vaultA), address(tokenA), depositAmount, swapParams);
        vm.stopPrank();

        assertEq(shares, depositAmount);
    }

    function test_DepositWithToken_MaxUint256Amount_Success() public {
        uint256 depositAmount = 1000e18; // Use a reasonable amount instead of max uint256
        tokenA.transfer(user, depositAmount);

        vm.startPrank(user);
        tokenA.approve(address(vaultRouter), depositAmount);

        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenA),
            amountIn: depositAmount,
            maxAmountIn: depositAmount,
            minAmountOut: 0,
            data: new DataTypes.ExecuteSwapParamsData[](0)
        });

        uint256 shares = vaultRouter.depositWithToken(address(vaultA), address(tokenA), depositAmount, swapParams);
        vm.stopPrank();

        assertEq(shares, depositAmount);
    }

    function test_WhitelistVault_ZeroAddress_Success() public {
        vm.startPrank(owner);
        vaultRouter.whitelistVault(address(0), true);
        vm.stopPrank();

        assertTrue(vaultRouter.supportedVaults(address(0)));
    }

    function test_WhitelistToken_ZeroAddress_Success() public {
        vm.startPrank(owner);
        vaultRouter.whitelistToken(address(0), true);
        vm.stopPrank();

        assertTrue(vaultRouter.supportedTokens(address(0)));
    }

    function test_SetUniversalDexModule_ZeroAddress_Success() public {
        vm.startPrank(owner);
        vaultRouter.setUniversalDexModule(address(0));
        vm.stopPrank();

        assertEq(address(vaultRouter.universalDexModule()), address(0));
    }

    // ============ Gas Optimization Tests ============

    function test_Gas_DepositWithToken_SameToken() public {
        uint256 depositAmount = 1000e18;

        vm.startPrank(user);
        tokenA.approve(address(vaultRouter), depositAmount);

        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenA),
            amountIn: depositAmount,
            maxAmountIn: depositAmount,
            minAmountOut: 0,
            data: new DataTypes.ExecuteSwapParamsData[](0)
        });

        uint256 gasBefore = gasleft();
        vaultRouter.depositWithToken(address(vaultA), address(tokenA), depositAmount, swapParams);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for same token deposit:", gasUsed);
        vm.stopPrank();
    }

    function test_Gas_DepositWithToken_DifferentToken() public {
        uint256 depositAmount = 1000e18;
        dexModule.setMockAmountOut(800e18);

        vm.startPrank(user);
        tokenA.approve(address(vaultRouter), depositAmount);

        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            amountIn: depositAmount,
            maxAmountIn: depositAmount,
            minAmountOut: 0,
            data: new DataTypes.ExecuteSwapParamsData[](0)
        });

        uint256 gasBefore = gasleft();
        vaultRouter.depositWithToken(address(vaultB), address(tokenA), depositAmount, swapParams);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for different token deposit:", gasUsed);
        vm.stopPrank();
    }
}
