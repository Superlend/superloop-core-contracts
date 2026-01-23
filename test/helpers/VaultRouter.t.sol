    // TODO : Update tests for periphery contract
// SPDX-License-Identifier: MIT
// pragma solidity ^0.8.13;

// import {Test, console} from "forge-std/Test.sol";
// import {Vm} from "forge-std/Vm.sol";
// import {VaultRouter} from "../../src/helpers/VaultRouter.sol";
// import {DataTypes} from "../../src/common/DataTypes.sol";
// import {Errors} from "../../src/common/Errors.sol";
// import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
// import {MockUniversalDexModule} from "../../src/mock/MockUniversalDexModule.sol";
// import {MockAsset} from "../../src/mock/MockAsset.sol";
// import {MockVault} from "../../src/mock/MockVault.sol";
// import {MockDepositManager} from "../../src/mock/MockDepositManager.sol";

// /**
//  * @title VaultRouterTest
//  * @author Superlend
//  * @notice Comprehensive unit tests for the VaultRouter contract
//  */
// contract VaultRouterTest is Test {
//     VaultRouter public vaultRouter;
//     MockUniversalDexModule public mockDexModule;
//     MockAsset public mockToken;
//     MockVault public mockVault;
//     MockDepositManager public mockDepositManager;

//     address public owner;
//     address public user;
//     address public nonOwner;

//     uint256 public constant INITIAL_SUPPLY = 1000000 * 10 ** 18;
//     uint256 public constant DEPOSIT_AMOUNT = 1000 * 10 ** 18;
//     uint256 public constant SWAP_OUTPUT = 950 * 10 ** 18; // 5% slippage

//     event VaultWhitelisted(address indexed vault, bool isWhitelisted);
//     event TokenWhitelisted(address indexed token, bool isWhitelisted);
//     event DepositManagerWhitelisted(address indexed depositManager, bool isWhitelisted);

//     function setUp() public {
//         owner = makeAddr("owner");
//         user = makeAddr("user");
//         nonOwner = makeAddr("nonOwner");

//         // Deploy mock contracts
//         mockToken = new MockAsset();
//         mockVault = new MockVault(IERC20(address(mockToken)), "Mock Vault", "MV");
//         mockDepositManager = new MockDepositManager();
//         mockDexModule = new MockUniversalDexModule(SWAP_OUTPUT);

//         // Setup initial arrays
//         address[] memory supportedVaults = new address[](1);
//         supportedVaults[0] = address(mockVault);

//         address[] memory supportedTokens = new address[](1);
//         supportedTokens[0] = address(mockToken);

//         address[] memory supportedDepositManagers = new address[](1);
//         supportedDepositManagers[0] = address(mockDepositManager);

//         // Deploy VaultRouter
//         vm.prank(owner);
//         vaultRouter =
//             new VaultRouter(supportedVaults, supportedTokens, address(mockDexModule), supportedDepositManagers);

//         // Transfer tokens to user for testing
//         mockToken.transfer(user, DEPOSIT_AMOUNT * 10);

//         // Label addresses for better debugging
//         vm.label(owner, "owner");
//         vm.label(user, "user");
//         vm.label(nonOwner, "nonOwner");
//         vm.label(address(mockToken), "mockToken");
//         vm.label(address(mockVault), "mockVault");
//         vm.label(address(mockDepositManager), "mockDepositManager");
//         vm.label(address(mockDexModule), "mockDexModule");
//         vm.label(address(vaultRouter), "vaultRouter");
//     }

//     // ============ Constructor Tests ============

//     function test_Constructor_InitializesCorrectly() public view {
//         assertTrue(vaultRouter.supportedVaults(address(mockVault)));
//         assertTrue(vaultRouter.supportedTokens(address(mockToken)));
//         assertTrue(vaultRouter.supportedDepositManagers(address(mockDepositManager)));
//         assertEq(address(vaultRouter.universalDexModule()), address(mockDexModule));
//         assertEq(vaultRouter.owner(), owner);
//     }

//     function test_Constructor_EmitsEvents() public {
//         address[] memory vaults = new address[](1);
//         vaults[0] = address(0x123);
//         address[] memory tokens = new address[](1);
//         tokens[0] = address(0x456);
//         address[] memory depositManagers = new address[](1);
//         depositManagers[0] = address(0x789);

//         vm.expectEmit(true, false, false, true);
//         emit VaultWhitelisted(address(0x123), true);

//         vm.expectEmit(true, false, false, true);
//         emit TokenWhitelisted(address(0x456), true);

//         vm.expectEmit(true, false, false, true);
//         emit DepositManagerWhitelisted(address(0x789), true);

//         vm.prank(owner);
//         new VaultRouter(vaults, tokens, address(mockDexModule), depositManagers);
//     }

//     // ============ Deposit Tests ============

//     function test_DepositWithToken_InstantDeposit_Success() public {
//         uint256 amountIn = DEPOSIT_AMOUNT;

//         DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
//             tokenIn: address(mockToken),
//             tokenOut: address(mockToken),
//             amountIn: amountIn,
//             maxAmountIn: amountIn,
//             minAmountOut: 0,
//             data: new DataTypes.ExecuteSwapParamsData[](0)
//         });

//         uint256 userBalanceBefore = mockToken.balanceOf(user);
//         uint256 vaultBalanceBefore = mockToken.balanceOf(address(mockVault));

//         vm.startPrank(user);
//         mockToken.approve(address(vaultRouter), amountIn);
//         vaultRouter.depositWithToken(
//             address(mockVault),
//             address(mockDepositManager),
//             address(mockToken),
//             amountIn,
//             DataTypes.DepositType.INSTANT,
//             swapParams
//         );
//         vm.stopPrank();

//         assertEq(mockToken.balanceOf(user), userBalanceBefore - amountIn);
//         assertEq(mockToken.balanceOf(address(mockVault)), vaultBalanceBefore + amountIn);
//     }

//     function test_DepositWithToken_RequestedDeposit_Success() public {
//         uint256 amountIn = DEPOSIT_AMOUNT;

//         DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
//             tokenIn: address(mockToken),
//             tokenOut: address(mockToken),
//             amountIn: amountIn,
//             maxAmountIn: amountIn,
//             minAmountOut: 0,
//             data: new DataTypes.ExecuteSwapParamsData[](0)
//         });

//         uint256 userBalanceBefore = mockToken.balanceOf(user);

//         vm.startPrank(user);
//         mockToken.approve(address(vaultRouter), amountIn);
//         vaultRouter.depositWithToken(
//             address(mockVault),
//             address(mockDepositManager),
//             address(mockToken),
//             amountIn,
//             DataTypes.DepositType.REQUESTED,
//             swapParams
//         );
//         vm.stopPrank();

//         assertEq(mockToken.balanceOf(user), userBalanceBefore - amountIn);
//         // For requested deposits, tokens are transferred to the deposit manager
//         // The mock deposit manager doesn't actually hold tokens, so we just check the shares
//     }

//     function test_DepositWithToken_WithSwap_Success() public {
//         // Create a different token for the vault
//         MockAsset vaultToken = new MockAsset();
//         MockVault swapVault = new MockVault(IERC20(address(vaultToken)), "Swap Vault", "SV");

//         // Whitelist the new vault and token
//         vm.startPrank(owner);
//         vaultRouter.whitelistVault(address(swapVault), true);
//         vaultRouter.whitelistToken(address(vaultToken), true);
//         vm.stopPrank();

//         // Transfer vault tokens to the VaultRouter to simulate the swap output
//         vaultToken.transfer(address(vaultRouter), SWAP_OUTPUT);

//         uint256 amountIn = DEPOSIT_AMOUNT;

//         DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
//             tokenIn: address(mockToken),
//             tokenOut: address(vaultToken),
//             amountIn: amountIn,
//             maxAmountIn: amountIn,
//             minAmountOut: 0,
//             data: new DataTypes.ExecuteSwapParamsData[](0)
//         });

//         uint256 userBalanceBefore = mockToken.balanceOf(user);
//         uint256 vaultBalanceBefore = vaultToken.balanceOf(address(swapVault));

//         vm.startPrank(user);
//         mockToken.approve(address(vaultRouter), amountIn);
//         vaultRouter.depositWithToken(
//             address(swapVault),
//             address(mockDepositManager),
//             address(mockToken),
//             amountIn,
//             DataTypes.DepositType.INSTANT,
//             swapParams
//         );
//         vm.stopPrank();

//         assertEq(mockToken.balanceOf(user), userBalanceBefore); // no diff should be there because unswapped tokens are returned to the user
//         assertEq(vaultToken.balanceOf(address(swapVault)), vaultBalanceBefore + SWAP_OUTPUT);
//     }

//     // ============ Access Control Tests ============

//     function test_DepositWithToken_VaultNotWhitelisted_Reverts() public {
//         address unwhitelistedVault = makeAddr("unwhitelistedVault");

//         DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
//             tokenIn: address(mockToken),
//             tokenOut: address(mockToken),
//             amountIn: DEPOSIT_AMOUNT,
//             maxAmountIn: DEPOSIT_AMOUNT,
//             minAmountOut: 0,
//             data: new DataTypes.ExecuteSwapParamsData[](0)
//         });

//         vm.startPrank(user);
//         mockToken.approve(address(vaultRouter), DEPOSIT_AMOUNT);
//         vm.expectRevert(abi.encodePacked(Errors.VAULT_NOT_WHITELISTED));
//         vaultRouter.depositWithToken(
//             unwhitelistedVault,
//             address(mockDepositManager),
//             address(mockToken),
//             DEPOSIT_AMOUNT,
//             DataTypes.DepositType.INSTANT,
//             swapParams
//         );
//         vm.stopPrank();
//     }

//     function test_DepositWithToken_TokenNotWhitelisted_Reverts() public {
//         MockAsset unwhitelistedToken = new MockAsset();

//         DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
//             tokenIn: address(unwhitelistedToken),
//             tokenOut: address(unwhitelistedToken),
//             amountIn: DEPOSIT_AMOUNT,
//             maxAmountIn: DEPOSIT_AMOUNT,
//             minAmountOut: 0,
//             data: new DataTypes.ExecuteSwapParamsData[](0)
//         });

//         vm.startPrank(user);
//         unwhitelistedToken.approve(address(vaultRouter), DEPOSIT_AMOUNT);
//         vm.expectRevert(abi.encodePacked(Errors.TOKEN_NOT_WHITELISTED));
//         vaultRouter.depositWithToken(
//             address(mockVault),
//             address(mockDepositManager),
//             address(unwhitelistedToken),
//             DEPOSIT_AMOUNT,
//             DataTypes.DepositType.INSTANT,
//             swapParams
//         );
//         vm.stopPrank();
//     }

//     function test_DepositWithToken_DepositManagerNotWhitelisted_Reverts() public {
//         address unwhitelistedDepositManager = makeAddr("unwhitelistedDepositManager");

//         DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
//             tokenIn: address(mockToken),
//             tokenOut: address(mockToken),
//             amountIn: DEPOSIT_AMOUNT,
//             maxAmountIn: DEPOSIT_AMOUNT,
//             minAmountOut: 0,
//             data: new DataTypes.ExecuteSwapParamsData[](0)
//         });

//         vm.startPrank(user);
//         mockToken.approve(address(vaultRouter), DEPOSIT_AMOUNT);
//         vm.expectRevert(abi.encodePacked(Errors.DEPOSIT_MANAGER_NOT_WHITELISTED));
//         vaultRouter.depositWithToken(
//             address(mockVault),
//             unwhitelistedDepositManager,
//             address(mockToken),
//             DEPOSIT_AMOUNT,
//             DataTypes.DepositType.INSTANT,
//             swapParams
//         );
//         vm.stopPrank();
//     }

//     // ============ Whitelist Management Tests ============

//     function test_WhitelistVault_OnlyOwner_Success() public {
//         address newVault = makeAddr("newVault");

//         vm.expectEmit(true, false, false, true);
//         emit VaultWhitelisted(newVault, true);

//         vm.prank(owner);
//         vaultRouter.whitelistVault(newVault, true);

//         assertTrue(vaultRouter.supportedVaults(newVault));
//     }

//     function test_WhitelistVault_NonOwner_Reverts() public {
//         address newVault = makeAddr("newVault");

//         vm.prank(nonOwner);
//         vm.expectRevert();
//         vaultRouter.whitelistVault(newVault, true);
//     }

//     function test_WhitelistToken_OnlyOwner_Success() public {
//         address newToken = makeAddr("newToken");

//         vm.expectEmit(true, false, false, true);
//         emit TokenWhitelisted(newToken, true);

//         vm.prank(owner);
//         vaultRouter.whitelistToken(newToken, true);

//         assertTrue(vaultRouter.supportedTokens(newToken));
//     }

//     function test_WhitelistToken_NonOwner_Reverts() public {
//         address newToken = makeAddr("newToken");

//         vm.prank(nonOwner);
//         vm.expectRevert();
//         vaultRouter.whitelistToken(newToken, true);
//     }

//     function test_WhitelistDepositManager_OnlyOwner_Success() public {
//         address newDepositManager = makeAddr("newDepositManager");

//         vm.expectEmit(true, false, false, true);
//         emit DepositManagerWhitelisted(newDepositManager, true);

//         vm.prank(owner);
//         vaultRouter.whitelistDepositManager(newDepositManager, true);

//         assertTrue(vaultRouter.supportedDepositManagers(newDepositManager));
//     }

//     function test_WhitelistDepositManager_NonOwner_Reverts() public {
//         address newDepositManager = makeAddr("newDepositManager");

//         vm.prank(nonOwner);
//         vm.expectRevert();
//         vaultRouter.whitelistDepositManager(newDepositManager, true);
//     }

//     function test_WhitelistVault_RemoveFromWhitelist_Success() public {
//         // First add to whitelist
//         vm.prank(owner);
//         vaultRouter.whitelistVault(address(mockVault), false);

//         assertFalse(vaultRouter.supportedVaults(address(mockVault)));
//     }

//     function test_WhitelistToken_RemoveFromWhitelist_Success() public {
//         // First add to whitelist
//         vm.prank(owner);
//         vaultRouter.whitelistToken(address(mockToken), false);

//         assertFalse(vaultRouter.supportedTokens(address(mockToken)));
//     }

//     function test_WhitelistDepositManager_RemoveFromWhitelist_Success() public {
//         // First add to whitelist
//         vm.prank(owner);
//         vaultRouter.whitelistDepositManager(address(mockDepositManager), false);

//         assertFalse(vaultRouter.supportedDepositManagers(address(mockDepositManager)));
//     }

//     // ============ Universal DEX Module Tests ============

//     function test_SetUniversalDexModule_OnlyOwner_Success() public {
//         MockUniversalDexModule newDexModule = new MockUniversalDexModule(1000);

//         vm.prank(owner);
//         vaultRouter.setUniversalDexModule(address(newDexModule));

//         assertEq(address(vaultRouter.universalDexModule()), address(newDexModule));
//     }

//     function test_SetUniversalDexModule_NonOwner_Reverts() public {
//         MockUniversalDexModule newDexModule = new MockUniversalDexModule(1000);

//         vm.prank(nonOwner);
//         vm.expectRevert();
//         vaultRouter.setUniversalDexModule(address(newDexModule));
//     }

//     // ============ Edge Cases and Error Conditions ============

//     function test_DepositWithToken_InsufficientAllowance_Reverts() public {
//         DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
//             tokenIn: address(mockToken),
//             tokenOut: address(mockToken),
//             amountIn: DEPOSIT_AMOUNT,
//             maxAmountIn: DEPOSIT_AMOUNT,
//             minAmountOut: 0,
//             data: new DataTypes.ExecuteSwapParamsData[](0)
//         });

//         vm.startPrank(user);
//         // Don't approve tokens
//         vm.expectRevert();
//         vaultRouter.depositWithToken(
//             address(mockVault),
//             address(mockDepositManager),
//             address(mockToken),
//             DEPOSIT_AMOUNT,
//             DataTypes.DepositType.INSTANT,
//             swapParams
//         );
//         vm.stopPrank();
//     }

//     function test_DepositWithToken_InsufficientBalance_Reverts() public {
//         uint256 excessiveAmount = mockToken.balanceOf(user) + 1;

//         DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
//             tokenIn: address(mockToken),
//             tokenOut: address(mockToken),
//             amountIn: excessiveAmount,
//             maxAmountIn: excessiveAmount,
//             minAmountOut: 0,
//             data: new DataTypes.ExecuteSwapParamsData[](0)
//         });

//         vm.startPrank(user);
//         mockToken.approve(address(vaultRouter), excessiveAmount);
//         vm.expectRevert();
//         vaultRouter.depositWithToken(
//             address(mockVault),
//             address(mockDepositManager),
//             address(mockToken),
//             excessiveAmount,
//             DataTypes.DepositType.INSTANT,
//             swapParams
//         );
//         vm.stopPrank();
//     }

//     function test_DepositWithToken_SwapFails_Reverts() public {
//         // Create a different token for the vault
//         MockAsset vaultToken = new MockAsset();
//         MockVault swapVault = new MockVault(IERC20(address(vaultToken)), "Swap Vault", "SV");

//         // Whitelist the new vault and token
//         vm.startPrank(owner);
//         vaultRouter.whitelistVault(address(swapVault), true);
//         vaultRouter.whitelistToken(address(vaultToken), true);
//         vm.stopPrank();

//         // Transfer vault tokens to the VaultRouter to simulate the swap output
//         vaultToken.transfer(address(vaultRouter), SWAP_OUTPUT);

//         // Make the DEX module revert
//         mockDexModule.setShouldRevert(true);

//         uint256 amountIn = DEPOSIT_AMOUNT;

//         DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
//             tokenIn: address(mockToken),
//             tokenOut: address(vaultToken),
//             amountIn: amountIn,
//             maxAmountIn: amountIn,
//             minAmountOut: 0,
//             data: new DataTypes.ExecuteSwapParamsData[](0)
//         });

//         vm.startPrank(user);
//         mockToken.approve(address(vaultRouter), amountIn);
//         vm.expectRevert("MockDexModule: execution failed");
//         vaultRouter.depositWithToken(
//             address(swapVault),
//             address(mockDepositManager),
//             address(mockToken),
//             amountIn,
//             DataTypes.DepositType.INSTANT,
//             swapParams
//         );
//         vm.stopPrank();
//     }

//     // ============ Integration Tests ============

//     function test_FullDepositFlow_InstantDeposit() public {
//         uint256 amountIn = DEPOSIT_AMOUNT;

//         DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
//             tokenIn: address(mockToken),
//             tokenOut: address(mockToken),
//             amountIn: amountIn,
//             maxAmountIn: amountIn,
//             minAmountOut: 0,
//             data: new DataTypes.ExecuteSwapParamsData[](0)
//         });

//         // Record initial state
//         uint256 userTokenBalanceBefore = mockToken.balanceOf(user);
//         uint256 vaultTokenBalanceBefore = mockToken.balanceOf(address(mockVault));

//         // Execute deposit
//         vm.startPrank(user);
//         mockToken.approve(address(vaultRouter), amountIn);
//         vaultRouter.depositWithToken(
//             address(mockVault),
//             address(mockDepositManager),
//             address(mockToken),
//             amountIn,
//             DataTypes.DepositType.INSTANT,
//             swapParams
//         );
//         vm.stopPrank();

//         // Verify final state
//         assertEq(mockToken.balanceOf(user), userTokenBalanceBefore - amountIn);
//         assertEq(mockToken.balanceOf(address(mockVault)), vaultTokenBalanceBefore + amountIn);
//     }

//     function test_FullDepositFlow_RequestedDeposit() public {
//         uint256 amountIn = DEPOSIT_AMOUNT;

//         DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
//             tokenIn: address(mockToken),
//             tokenOut: address(mockToken),
//             amountIn: amountIn,
//             maxAmountIn: amountIn,
//             minAmountOut: 0,
//             data: new DataTypes.ExecuteSwapParamsData[](0)
//         });

//         // Record initial state
//         uint256 userTokenBalanceBefore = mockToken.balanceOf(user);

//         // Execute deposit
//         vm.startPrank(user);
//         mockToken.approve(address(vaultRouter), amountIn);
//         vaultRouter.depositWithToken(
//             address(mockVault),
//             address(mockDepositManager),
//             address(mockToken),
//             amountIn,
//             DataTypes.DepositType.REQUESTED,
//             swapParams
//         );
//         vm.stopPrank();

//         // Verify final state
//         assertEq(mockToken.balanceOf(user), userTokenBalanceBefore - amountIn);
//         // For requested deposits, tokens are transferred to the deposit manager
//         // The mock deposit manager doesn't actually hold tokens, so we just check the shares
//     }

//     // ============ Gas Optimization Tests ============

//     function test_DepositWithToken_GasUsage() public {
//         uint256 amountIn = DEPOSIT_AMOUNT;

//         DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
//             tokenIn: address(mockToken),
//             tokenOut: address(mockToken),
//             amountIn: amountIn,
//             maxAmountIn: amountIn,
//             minAmountOut: 0,
//             data: new DataTypes.ExecuteSwapParamsData[](0)
//         });

//         vm.startPrank(user);
//         mockToken.approve(address(vaultRouter), amountIn);

//         uint256 gasStart = gasleft();
//         vaultRouter.depositWithToken(
//             address(mockVault),
//             address(mockDepositManager),
//             address(mockToken),
//             amountIn,
//             DataTypes.DepositType.INSTANT,
//             swapParams
//         );
//         uint256 gasUsed = gasStart - gasleft();

//         console.log("Gas used for instant deposit:", gasUsed);
//         vm.stopPrank();

//         // Gas usage should be reasonable (less than 200k gas)
//         assertLt(gasUsed, 200000);
//     }
// }
