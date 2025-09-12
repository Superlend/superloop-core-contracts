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
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountantModule: address(accountantAaveV3),
            withdrawManagerModule: address(withdrawManager),
            depositManager: address(0),
            cashReserve: 1000,
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
        _deployDepositManager(address(superloop));

        bytes32 key = keccak256(abi.encodePacked(POOL, IFlashLoanSimpleReceiver.executeOperation.selector));
        bytes32 depositKey =
            keccak256(abi.encodePacked(address(depositManager), depositManagerCallbackHandler.executeDeposit.selector));
        superloop.setCallbackHandler(key, address(callbackHandler));
        superloop.setCallbackHandler(depositKey, address(depositManagerCallbackHandler));

        moduleRegistry.setModule("withdrawManager", address(withdrawManager));
        moduleRegistry.setModule("accountantAaveV3", address(accountantAaveV3));
        moduleRegistry.setModule("depositManager", address(depositManager));

        superloop.setRegisteredModule(address(withdrawManager), true);
        superloop.setRegisteredModule(address(accountantAaveV3), true);
        superloop.setRegisteredModule(address(depositManager), true);

        superloop.setAccountantModule(address(accountantAaveV3));
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
}
