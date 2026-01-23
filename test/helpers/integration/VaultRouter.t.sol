// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.13;

// import {IntegrationBase} from "../../core/integration/IntegrationBase.sol";
// import {console} from "forge-std/console.sol";
// import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// import {VaultRouter} from "../../../src/helpers/VaultRouter.sol";
// import {IRouter} from "../../../src/mock/MockIRouter.sol";
// import {DataTypes} from "../../../src/common/DataTypes.sol";
// import {Errors} from "../../../src/common/Errors.sol";

// // test to swap from usdc to wxtz then deposit via the vault router

// contract VaultRouterTest is IntegrationBase {
//     VaultRouter public vaultRouter;

//     function setUp() public override {
//         super.setUp();

//         address[] memory supportedVaults = new address[](1);
//         supportedVaults[0] = address(superloop);
//         address[] memory supportedTokens = new address[](3);
//         supportedTokens[0] = XTZ;
//         supportedTokens[1] = ST_XTZ;
//         supportedTokens[2] = USDC;

//         address[] memory supportedDepositManagers = new address[](1);
//         supportedDepositManagers[0] = address(depositManager);

//         vm.startPrank(admin);
//         vaultRouter = new VaultRouter(supportedVaults, supportedTokens, address(dexModule), supportedDepositManagers);
//         vm.stopPrank();

//         vm.prank(USDC_WHALE);
//         IERC20(USDC).transfer(user1, 100 * 10 ** 6);

//         vm.prank(XTZ_WHALE);
//         IERC20(XTZ).transfer(user1, 100 * 10 ** 18);
//     }

//     function test_normalDeposit() public {
//         uint256 amountIn = 1 * 10 ** 18;

//         DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
//             tokenIn: XTZ,
//             tokenOut: XTZ,
//             amountIn: amountIn,
//             maxAmountIn: amountIn,
//             minAmountOut: 0,
//             data: new DataTypes.ExecuteSwapParamsData[](0)
//         });

//         vm.startPrank(user1);
//         IERC20(XTZ).approve(address(vaultRouter), amountIn);
//         vm.expectRevert(bytes(Errors.INSUFFICIENT_CASH_SHORTFALL));
//         vaultRouter.depositWithToken(
//             address(superloop), address(depositManager), XTZ, amountIn, DataTypes.DepositType.INSTANT, swapParams
//         );
//     }

//     function test_swapAndDeposit() public {
//         uint256 amountIn = 1 * 10 ** 6;

//         // approve vault router to spend USDC
//         DataTypes.ExecuteSwapParamsData[] memory data = new DataTypes.ExecuteSwapParamsData[](2);

//         data[0] = DataTypes.ExecuteSwapParamsData({
//             target: address(USDC),
//             data: abi.encodeWithSelector(IERC20.approve.selector, address(ROUTER), amountIn)
//         });
//         data[1] = DataTypes.ExecuteSwapParamsData({
//             target: address(ROUTER),
//             data: abi.encodeWithSelector(
//                 IRouter.exactInputSingle.selector,
//                 IRouter.ExactInputSingleParams({
//                     tokenIn: USDC,
//                     tokenOut: XTZ,
//                     fee: 500,
//                     recipient: address(dexModule),
//                     amountIn: amountIn,
//                     amountOutMinimum: 0,
//                     sqrtPriceLimitX96: 0
//                 })
//             )
//         });

//         DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
//             tokenIn: USDC,
//             tokenOut: XTZ,
//             amountIn: amountIn,
//             maxAmountIn: amountIn,
//             minAmountOut: 0,
//             data: data
//         });

//         vm.startPrank(user1);
//         IERC20(USDC).approve(address(vaultRouter), amountIn);
//         vm.expectRevert(bytes(Errors.INSUFFICIENT_CASH_SHORTFALL));
//         vaultRouter.depositWithToken(
//             address(superloop), address(depositManager), USDC, amountIn, DataTypes.DepositType.INSTANT, swapParams
//         );
//     }

//     function test_depositRequest() public {
//         uint256 amountIn = 1 * 10 ** 18;

//         DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
//             tokenIn: XTZ,
//             tokenOut: XTZ,
//             amountIn: amountIn,
//             maxAmountIn: amountIn,
//             minAmountOut: 0,
//             data: new DataTypes.ExecuteSwapParamsData[](0)
//         });

//         vm.startPrank(user1);
//         IERC20(XTZ).approve(address(vaultRouter), amountIn);
//         vaultRouter.depositWithToken(
//             address(superloop), address(depositManager), XTZ, amountIn, DataTypes.DepositType.REQUESTED, swapParams
//         );

//         DataTypes.DepositRequestData memory request = depositManager.depositRequest(1);
//         assertEq(request.amount, amountIn);
//         assertEq(request.user, user1);
//     }

//     function test_depositRequestWithSwap() public {
//         uint256 amountIn = 1 * 10 ** 6;

//         // approve vault router to spend USDC
//         DataTypes.ExecuteSwapParamsData[] memory data = new DataTypes.ExecuteSwapParamsData[](2);

//         data[0] = DataTypes.ExecuteSwapParamsData({
//             target: address(USDC),
//             data: abi.encodeWithSelector(IERC20.approve.selector, address(ROUTER), amountIn)
//         });
//         data[1] = DataTypes.ExecuteSwapParamsData({
//             target: address(ROUTER),
//             data: abi.encodeWithSelector(
//                 IRouter.exactInputSingle.selector,
//                 IRouter.ExactInputSingleParams({
//                     tokenIn: USDC,
//                     tokenOut: XTZ,
//                     fee: 500,
//                     recipient: address(dexModule),
//                     amountIn: amountIn,
//                     amountOutMinimum: 0,
//                     sqrtPriceLimitX96: 0
//                 })
//             )
//         });

//         DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
//             tokenIn: USDC,
//             tokenOut: XTZ,
//             amountIn: amountIn,
//             maxAmountIn: amountIn,
//             minAmountOut: 0,
//             data: data
//         });

//         vm.startPrank(user1);
//         IERC20(USDC).approve(address(vaultRouter), amountIn);
//         vaultRouter.depositWithToken(
//             address(superloop), address(depositManager), USDC, amountIn, DataTypes.DepositType.REQUESTED, swapParams
//         );

//         DataTypes.DepositRequestData memory request = depositManager.depositRequest(1);
//         assertGt(request.amount, 0);
//         assertEq(request.user, user1);
//     }

//     function test_frontrunningProtection() public {
//         uint256 amountIn = 1 * 10 ** 6;

//         // approve vault router to spend USDC
//         DataTypes.ExecuteSwapParamsData[] memory data = new DataTypes.ExecuteSwapParamsData[](2);

//         data[0] = DataTypes.ExecuteSwapParamsData({
//             target: address(USDC),
//             data: abi.encodeWithSelector(IERC20.approve.selector, address(ROUTER), amountIn)
//         });
//         data[1] = DataTypes.ExecuteSwapParamsData({
//             target: address(ROUTER),
//             data: abi.encodeWithSelector(
//                 IRouter.exactInputSingle.selector,
//                 IRouter.ExactInputSingleParams({
//                     tokenIn: USDC,
//                     tokenOut: XTZ,
//                     fee: 500,
//                     recipient: address(dexModule),
//                     amountIn: amountIn,
//                     amountOutMinimum: 0,
//                     sqrtPriceLimitX96: 0
//                 })
//             )
//         });

//         DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
//             tokenIn: USDC,
//             tokenOut: XTZ,
//             amountIn: amountIn,
//             maxAmountIn: amountIn,
//             minAmountOut: 0,
//             data: data
//         });

//         vm.prank(user1);
//         IERC20(USDC).approve(address(vaultRouter), amountIn);

//         vm.prank(user2);
//         vm.expectRevert();
//         vaultRouter.depositWithToken(
//             address(superloop), address(depositManager), USDC, amountIn, DataTypes.DepositType.INSTANT, swapParams
//         );
//     }
// }
