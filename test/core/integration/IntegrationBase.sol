// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {TestBase} from "../TestBase.sol";
import {Superloop} from "../../../src/core/Superloop/Superloop.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {IFlashLoanSimpleReceiver} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IPoolConfigurator} from "aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";
import {IRouter} from "../../../src/mock/MockIRouter.sol";
import {ICurvePool} from "../../../src/mock/ICurvePool.sol";
import {console} from "forge-std/console.sol";

abstract contract IntegrationBase is TestBase {
    struct CURVE_IJ {
        int128 i;
        int128 j;
    }

    Superloop public superloopImplementation;
    ProxyAdmin public proxyAdmin;

    address public user1;
    address public user2;
    address public user3;

    uint24 public constant XTZ_STXTZ_POOL_FEE = 100; // 0.01%
    address public constant XTZ_STXTZ_POOL = 0x74d80eE400D3026FDd2520265cC98300710b25D4;

    uint256 public constant ONE_SHARE = 10 ** 20;

    uint256 public constant INSTANT_WITHDRAW_FEE = 100;

    uint256 public constant XTZ_SCALE = 10 ** 18;
    uint256 public constant STXTZ_SCALE = 10 ** 6;

    CURVE_IJ public XTZ_STXTZ_SWAP;
    CURVE_IJ public STXTZ_XTZ_SWAP;

    function setUp() public virtual override {
        super.setUp();

        XTZ_STXTZ_SWAP = CURVE_IJ({i: 1, j: 0});
        STXTZ_XTZ_SWAP = CURVE_IJ({i: 0, j: 1});

        vm.startPrank(admin);
        _deployModules();

        address[] memory modules = new address[](9);
        modules[0] = address(dexModule);
        modules[1] = address(flashloanModule);
        modules[2] = address(callbackHandler);
        modules[3] = address(emodeModule);
        modules[4] = address(supplyModule);
        modules[5] = address(withdrawModule);
        modules[6] = address(borrowModule);
        modules[7] = address(repayModule);
        modules[8] = address(depositManagerCallbackHandler);

        DataTypes.VaultInitData memory initData = DataTypes.VaultInitData({
            asset: XTZ,
            name: "XTZ Vault",
            symbol: "XTZV",
            supplyCap: 100000 * 10 ** 18,
            minimumDepositAmount: 100,
            instantWithdrawFee: INSTANT_WITHDRAW_FEE,
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountant: address(accountant),
            withdrawManager: address(withdrawManager),
            depositManager: address(0),
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

        _deployAccountant(address(superloop));
        _deployWithdrawManager(address(superloop));
        _deployDepositManager(address(superloop));

        bytes32 key = keccak256(abi.encodePacked(POOL, IFlashLoanSimpleReceiver.executeOperation.selector));
        bytes32 depositKey =
            keccak256(abi.encodePacked(address(depositManager), depositManagerCallbackHandler.executeDeposit.selector));
        bytes32 withdrawKey = keccak256(
            abi.encodePacked(address(withdrawManager), withdrawManagerCallbackHandler.executeWithdraw.selector)
        );
        superloop.setCallbackHandler(key, address(callbackHandler));
        superloop.setCallbackHandler(depositKey, address(depositManagerCallbackHandler));
        superloop.setCallbackHandler(withdrawKey, address(withdrawManagerCallbackHandler));

        moduleRegistry.setModule("withdrawManager", address(withdrawManager));
        moduleRegistry.setModule("universalAccountant", address(accountant));
        moduleRegistry.setModule("depositManager", address(depositManager));

        superloop.setRegisteredModule(address(withdrawManager), true);
        superloop.setRegisteredModule(address(accountant), true);
        superloop.setRegisteredModule(address(depositManager), true);

        superloop.setAccountantModule(address(accountant));
        superloop.setWithdrawManagerModule(address(withdrawManager));
        superloop.setDepositManagerModule(address(depositManager));

        vm.stopPrank();
        vm.label(address(superloop), "superloop");

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        vm.label(user1, "user1");
        vm.label(user2, "user2");
        vm.label(user3, "user3");

        vm.startPrank(XTZ_WHALE);
        IERC20(XTZ).transfer(user1, 100 * 10 ** 18);
        IERC20(XTZ).transfer(user2, 100 * 10 ** 18);
        IERC20(XTZ).transfer(user3, 100 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(POOL_ADMIN);
        IPoolConfigurator(POOL_CONFIGURATOR).setReserveFlashLoaning(ST_XTZ, true);
        IPoolConfigurator(POOL_CONFIGURATOR).setSupplyCap(ST_XTZ, 10000000);
        vm.stopPrank();
    }

    function _resolveDepositRequestsCall(address asset, uint256 amount, bytes memory data)
        internal
        view
        returns (DataTypes.ModuleExecutionData memory)
    {
        DataTypes.ResolveDepositRequestsData memory resolveDepositRequestsData =
            DataTypes.ResolveDepositRequestsData({asset: asset, amount: amount, callbackExecutionData: data});
        return DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.CALL,
            module: address(depositManager),
            data: abi.encodeWithSelector(depositManager.resolveDepositRequests.selector, resolveDepositRequestsData)
        });
    }

    function _resolveWithdrawRequestsCall(uint256 shares, DataTypes.WithdrawRequestType requestType, bytes memory data)
        internal
        view
        returns (DataTypes.ModuleExecutionData memory)
    {
        DataTypes.ResolveWithdrawRequestsData memory resolveWithdrawRequestsData = DataTypes.ResolveWithdrawRequestsData({
            shares: shares,
            requestType: requestType,
            callbackExecutionData: data
        });
        return DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.CALL,
            module: address(withdrawManager),
            data: abi.encodeWithSelector(withdrawManager.resolveWithdrawRequests.selector, resolveWithdrawRequestsData)
        });
    }

    function _flashloanCall(address asset, uint256 amount, bytes memory data)
        internal
        view
        returns (DataTypes.ModuleExecutionData memory)
    {
        DataTypes.AaveV3FlashloanParams memory flashloanParams = DataTypes.AaveV3FlashloanParams({
            asset: asset,
            amount: amount,
            referralCode: 0,
            callbackExecutionData: data
        });
        return DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(flashloanModule),
            data: abi.encodeWithSelector(flashloanModule.execute.selector, flashloanParams)
        });
    }

    function _supplyCall(address asset, uint256 amount) internal view returns (DataTypes.ModuleExecutionData memory) {
        DataTypes.AaveV3ActionParams memory supplyParams = DataTypes.AaveV3ActionParams({asset: asset, amount: amount});
        return DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(supplyModule),
            data: abi.encodeWithSelector(supplyModule.execute.selector, supplyParams)
        });
    }

    function _borrowCall(address asset, uint256 amount) internal view returns (DataTypes.ModuleExecutionData memory) {
        DataTypes.AaveV3ActionParams memory borrowParams = DataTypes.AaveV3ActionParams({asset: asset, amount: amount});
        return DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(borrowModule),
            data: abi.encodeWithSelector(borrowModule.execute.selector, borrowParams)
        });
    }

    function _swapCallExactOut(
        address tokenIn,
        address tokenOut,
        uint256 swapAmount,
        uint256 amountOut,
        address router,
        uint24 fee
    ) internal view returns (DataTypes.ModuleExecutionData memory) {
        DataTypes.ExecuteSwapParamsData[] memory swapParamsData = new DataTypes.ExecuteSwapParamsData[](2);
        swapParamsData[0] = DataTypes.ExecuteSwapParamsData({
            target: tokenIn,
            data: abi.encodeWithSelector(IERC20.approve.selector, router, swapAmount)
        });
        swapParamsData[1] = DataTypes.ExecuteSwapParamsData({
            target: router,
            data: abi.encodeWithSelector(
                IRouter.exactOutputSingle.selector,
                IRouter.ExactOutputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    fee: fee,
                    recipient: address(superloop),
                    amountOut: amountOut,
                    amountInMaximum: swapAmount,
                    sqrtPriceLimitX96: 0
                })
            )
        });
        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: swapAmount,
            maxAmountIn: swapAmount,
            minAmountOut: amountOut,
            data: swapParamsData
        });

        return DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(dexModule),
            data: abi.encodeWithSelector(dexModule.execute.selector, swapParams)
        });
    }

    function _swapCallExactIn(
        address tokenIn,
        address tokenOut,
        uint256 withdrawAmount,
        uint256 amountOut,
        address router,
        uint24 fee
    ) internal view returns (DataTypes.ModuleExecutionData memory) {
        DataTypes.ExecuteSwapParamsData[] memory swapParamsData = new DataTypes.ExecuteSwapParamsData[](2);
        swapParamsData[0] = DataTypes.ExecuteSwapParamsData({
            target: tokenIn,
            data: abi.encodeWithSelector(IERC20.approve.selector, router, withdrawAmount)
        });
        swapParamsData[1] = DataTypes.ExecuteSwapParamsData({
            target: router,
            data: abi.encodeWithSelector(
                IRouter.exactInputSingle.selector,
                IRouter.ExactInputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    fee: fee,
                    recipient: address(superloop),
                    amountIn: withdrawAmount,
                    amountOutMinimum: amountOut,
                    sqrtPriceLimitX96: 0
                })
            )
        });

        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: withdrawAmount,
            maxAmountIn: withdrawAmount,
            minAmountOut: amountOut,
            data: swapParamsData
        });

        return DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(dexModule),
            data: abi.encodeWithSelector(dexModule.execute.selector, swapParams)
        });
    }

    function _swapCallExactOutCurve(
        address tokenIn,
        address tokenOut,
        address pool,
        uint256 amountIn,
        uint256 amountOut,
        CURVE_IJ memory swap
    ) internal view returns (DataTypes.ModuleExecutionData memory) {
        DataTypes.ExecuteSwapParamsData[] memory swapParamsData = new DataTypes.ExecuteSwapParamsData[](2);
        swapParamsData[0] = DataTypes.ExecuteSwapParamsData({
            target: tokenIn,
            data: abi.encodeWithSelector(IERC20.approve.selector, pool, amountIn)
        });
        swapParamsData[1] = DataTypes.ExecuteSwapParamsData({
            target: pool,
            data: abi.encodeWithSelector(ICurvePool.exchange.selector, swap.i, swap.j, amountIn, amountOut)
        });

        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            maxAmountIn: amountIn,
            minAmountOut: amountOut,
            data: swapParamsData
        });

        return DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(dexModule),
            data: abi.encodeWithSelector(dexModule.execute.selector, swapParams)
        });
    }

    function _repayCall(address asset, uint256 amount) internal view returns (DataTypes.ModuleExecutionData memory) {
        DataTypes.AaveV3ActionParams memory repayParams = DataTypes.AaveV3ActionParams({asset: asset, amount: amount});
        return DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(repayModule),
            data: abi.encodeWithSelector(repayModule.execute.selector, repayParams)
        });
    }

    function _withdrawCall(address asset, uint256 amount)
        internal
        view
        returns (DataTypes.ModuleExecutionData memory)
    {
        DataTypes.AaveV3ActionParams memory withdrawParams =
            DataTypes.AaveV3ActionParams({asset: asset, amount: amount});
        return DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(withdrawModule),
            data: abi.encodeWithSelector(withdrawModule.execute.selector, withdrawParams)
        });
    }

    /**
     * @dev Creates a partial deposit with resolution.
     * @notice Creates 3 deposit requests with 100 xtz each.
     * @notice request 1 is fully processed, request 2 is partially processed, request 3 is unprocessed.
     */
    function _createPartialDepositWithResolution(bool depositAll) internal returns (uint256, uint256) {
        uint256 depositAmountUnscaled = 100;
        uint256 depositAmount = depositAmountUnscaled * XTZ_SCALE;
        _makeDepositRequest(depositAmount, user1, true);
        _makeDepositRequest(depositAmount, user2, true);
        _makeDepositRequest(depositAmount, user3, true);

        uint256 depositAmountUnscaledBatch = depositAll ? depositAmountUnscaled * 3 : (3 * depositAmountUnscaled) / 2;
        uint256 supplyAmountUnscaled = (3 * depositAmountUnscaledBatch); // 3x
        uint256 borrowAmountUnscaled = (3 * supplyAmountUnscaled) / 4;

        uint256 depositAmountBatch = depositAmountUnscaledBatch * XTZ_SCALE;
        // build the operate call
        uint256 supplyAmount = supplyAmountUnscaled * STXTZ_SCALE;
        uint256 borrowAmount = borrowAmountUnscaled * XTZ_SCALE;
        uint256 swapAmount = borrowAmount + depositAmountBatch;
        uint256 supplyAmountWithPremium = supplyAmount + (supplyAmount * 1) / 10000;

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);
        moduleExecutionData[0] = _supplyCall(ST_XTZ, supplyAmount);
        moduleExecutionData[1] = _borrowCall(XTZ, borrowAmount);

        moduleExecutionData[2] =
            _swapCallExactOutCurve(XTZ, ST_XTZ, XTZ_STXTZ_POOL, swapAmount, supplyAmountWithPremium, XTZ_STXTZ_SWAP);

        DataTypes.ModuleExecutionData[] memory intermediateExecutionData = new DataTypes.ModuleExecutionData[](1);
        intermediateExecutionData[0] = _flashloanCall(ST_XTZ, supplyAmount, abi.encode(moduleExecutionData));

        DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](1);
        finalExecutionData[0] =
            _resolveDepositRequestsCall(XTZ, depositAmountBatch, abi.encode(intermediateExecutionData));

        uint256 exchangeRateBefore = superloop.convertToAssets(ONE_SHARE);

        uint256 user1SharesBefore = superloop.balanceOf(user1);
        uint256 user2SharesBefore = superloop.balanceOf(user2);
        uint256 user3SharesBefore = superloop.balanceOf(user3);

        vm.prank(admin);
        superloop.operate(finalExecutionData);

        if (!depositAll) {
            // user 1 and user user 2 should get shares
            // user 3 should not get shares

            uint256 user1SharesAfter = superloop.balanceOf(user1);
            uint256 user2SharesAfter = superloop.balanceOf(user2);
            uint256 user3SharesAfter = superloop.balanceOf(user3);

            // deposit manager should have 150 xtz now
            assertEq(IERC20(XTZ).balanceOf(address(depositManager)), 150 * XTZ_SCALE);
            // pending deposits should be 150 xtz
            assertEq(depositManager.totalPendingDeposits(), 150 * XTZ_SCALE);

            // resolution id pointer should be 2
            assertEq(depositManager.resolutionIdPointer(), 2);

            // deposit request 1 should be fully processed
            DataTypes.DepositRequestData memory depositRequest1 = depositManager.depositRequest(1);
            assertEq(uint256(depositRequest1.state), uint256(DataTypes.RequestProcessingState.FULLY_PROCESSED));
            assertEq(depositRequest1.amountProcessed, 100 * XTZ_SCALE);

            // deposit request 2 should be partially processed
            DataTypes.DepositRequestData memory depositRequest2 = depositManager.depositRequest(2);
            assertEq(uint256(depositRequest2.state), uint256(DataTypes.RequestProcessingState.PARTIALLY_PROCESSED));
            assertEq(depositRequest2.amountProcessed, 50 * XTZ_SCALE);

            // deposit request 3 should be unprocessed
            DataTypes.DepositRequestData memory depositRequest3 = depositManager.depositRequest(3);
            assertEq(uint256(depositRequest3.state), uint256(DataTypes.RequestProcessingState.UNPROCESSED));

            assertEq(user1SharesAfter - user1SharesBefore, depositRequest1.sharesMinted);
            assertEq(user2SharesAfter - user2SharesBefore, depositRequest2.sharesMinted);
            assertEq(user3SharesAfter - user3SharesBefore, depositRequest3.sharesMinted);

            // exchange rate before should equal to exchange rate after
            uint256 exchangeRateAfter = superloop.convertToAssets(ONE_SHARE);
            assertApproxEqAbs(exchangeRateBefore, exchangeRateAfter, 1000);
        }

        return (supplyAmountUnscaled, borrowAmountUnscaled);
    }

    function _makeDepositRequest(uint256 depositAmount, address user, bool _deal) internal {
        if (_deal) {
            deal(XTZ, user, depositAmount);
        }

        vm.startPrank(user);
        IERC20(XTZ).approve(address(depositManager), depositAmount);
        depositManager.requestDeposit(depositAmount, address(0));
        vm.stopPrank();
    }

    function _makeWithdrawRequest(
        address share,
        uint256 shareAmount,
        address user,
        DataTypes.WithdrawRequestType requestType
    ) internal {
        vm.startPrank(user);
        IERC20(share).approve(address(withdrawManager), shareAmount);
        withdrawManager.requestWithdraw(shareAmount, requestType);
        vm.stopPrank();
    }

    /**
     * @dev Creates a partial withdraw with resolution.
     * @notice Creates 3 withdraw requests with 100 shares each.
     * @notice request 1 is fully processed, request 2 is partially processed, request 3 is unprocessed.
     */
    function _createPartialWithdrawWithResolution(DataTypes.WithdrawRequestType requestType)
        internal
        returns (uint256, uint256, uint256)
    {
        (uint256 supplyAmountUnscaled, uint256 borrowAmountUnscaled) = _createPartialDepositWithResolution(true);

        // make 3 withdraw requests
        uint256 user1ShareBalance = superloop.balanceOf(user1);
        uint256 user2ShareBalance = superloop.balanceOf(user2);
        uint256 user3ShareBalance = superloop.balanceOf(user3);
        _makeWithdrawRequest(address(superloop), user1ShareBalance, user1, requestType);
        _makeWithdrawRequest(address(superloop), user2ShareBalance, user2, requestType);
        _makeWithdrawRequest(address(superloop), user3ShareBalance, user3, requestType);

        // resolve 1st fully, and 2nd partially
        // repay half of borrow amount
        uint256 repayAmount = (borrowAmountUnscaled * XTZ_SCALE) / 2;
        uint256 withdrawAmount = ((supplyAmountUnscaled + 10) * STXTZ_SCALE) / 2;
        uint256 repayAmountWithPremium = repayAmount + (repayAmount * 1) / 10000;
        uint256 totalShares = superloop.totalSupply();
        uint256 sharesToResolve = totalShares / 2;

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);
        moduleExecutionData[0] = _repayCall(XTZ, repayAmount);
        moduleExecutionData[1] = _withdrawCall(ST_XTZ, withdrawAmount);
        moduleExecutionData[2] =
            _swapCallExactOutCurve(ST_XTZ, XTZ, XTZ_STXTZ_POOL, withdrawAmount, repayAmountWithPremium, STXTZ_XTZ_SWAP);

        DataTypes.ModuleExecutionData[] memory intermediateExecutionData = new DataTypes.ModuleExecutionData[](1);
        intermediateExecutionData[0] = _flashloanCall(XTZ, repayAmount, abi.encode(moduleExecutionData));

        DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](1);
        finalExecutionData[0] =
            _resolveWithdrawRequestsCall(sharesToResolve, requestType, abi.encode(intermediateExecutionData));

        uint256 exchangeRateBefore = superloop.convertToAssets(ONE_SHARE);

        vm.prank(admin);
        superloop.operate(finalExecutionData);

        // withdraw requests should have claimable > 0 and sharesProcessed > 0, exchange rate remains the same
        DataTypes.WithdrawRequestData memory withdrawRequest1 = withdrawManager.withdrawRequest(1, requestType);
        DataTypes.WithdrawRequestData memory withdrawRequest2 = withdrawManager.withdrawRequest(2, requestType);
        DataTypes.WithdrawRequestData memory withdrawRequest3 = withdrawManager.withdrawRequest(3, requestType);
        uint256 resolutionIdPointer = withdrawManager.resolutionIdPointer(requestType);
        uint256 totalPendingWithdraws = withdrawManager.totalPendingWithdraws(requestType);

        assertTrue(withdrawRequest1.amountClaimable > 0);
        assertTrue(withdrawRequest1.sharesProcessed == withdrawRequest1.shares);
        assertTrue(withdrawRequest2.amountClaimable > 0);
        assertTrue(withdrawRequest2.sharesProcessed > 0 && withdrawRequest2.sharesProcessed < withdrawRequest2.shares);
        assertTrue(withdrawRequest3.amountClaimable == 0);
        assertTrue(withdrawRequest3.sharesProcessed == 0);

        assertTrue(withdrawRequest1.state == DataTypes.RequestProcessingState.FULLY_PROCESSED);
        assertTrue(withdrawRequest2.state == DataTypes.RequestProcessingState.PARTIALLY_PROCESSED);
        assertTrue(withdrawRequest3.state == DataTypes.RequestProcessingState.UNPROCESSED);

        uint256 exchangeRateAfter = superloop.convertToAssets(ONE_SHARE);

        assertApproxEqAbs(exchangeRateAfter, exchangeRateBefore, 1000);
        assertEq(totalPendingWithdraws, totalShares - sharesToResolve);
        assertEq(resolutionIdPointer, 2);

        return (totalShares - sharesToResolve, repayAmount, withdrawAmount);
    }
}
