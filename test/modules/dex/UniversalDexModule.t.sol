// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {console} from "forge-std/Test.sol";
import {UniversalDexModule} from "../../../src/modules/dex/UniversalDexModule.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {TestBase} from "../../core/TestBase.sol";
import {Superloop} from "../../../src/core/Superloop/Superloop.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IRouter} from "../../../src/mock/MockIRouter.sol";

contract UniversalDexModuleTest is TestBase {
    Superloop public superloopImplementation;
    ProxyAdmin public proxyAdmin;
    address public user;

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);
        _deployModules();

        address[] memory modules = new address[](1);
        modules[0] = address(dexModule);

        DataTypes.VaultInitData memory initData = DataTypes.VaultInitData({
            asset: XTZ,
            name: "XTZ Vault",
            symbol: "XTZV",
            supplyCap: 100000 * 10 ** 18,
            minimumDepositAmount: 100,
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
        vm.stopPrank();

        user = makeAddr("user");
        vm.label(user, "user");
        vm.label(address(superloop), "superloop");
    }

    function test_executeSwap() public {
        address tokenIn = USDT;
        address tokenOut = USDC;

        uint256 amountIn = 1000 * 10 ** 6;
        uint256 maxAmountIn = 1000 * 10 ** 6;
        uint256 minAmountOut = 900 * 10 ** 6;

        DataTypes.ExecuteSwapParamsData[] memory swapParamsData = new DataTypes.ExecuteSwapParamsData[](2);
        swapParamsData[0] = DataTypes.ExecuteSwapParamsData({
            target: USDT,
            data: abi.encodeWithSelector(IERC20.approve.selector, ROUTER, amountIn)
        });
        swapParamsData[1] = DataTypes.ExecuteSwapParamsData({
            target: ROUTER,
            data: abi.encodeWithSelector(
                IRouter.exactInputSingle.selector,
                IRouter.ExactInputSingleParams({
                    tokenIn: USDT,
                    tokenOut: USDC,
                    fee: 100,
                    recipient: address(superloop),
                    amountIn: amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            )
        });

        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            maxAmountIn: maxAmountIn,
            minAmountOut: minAmountOut,
            data: swapParamsData
        });

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(dexModule),
            data: abi.encodeWithSelector(dexModule.execute.selector, swapParams)
        });

        vm.startPrank(USDT_WHALE);
        IERC20(USDT).transfer(address(superloop), amountIn);
        vm.stopPrank();

        vm.startPrank(admin);
        superloop.operate(moduleExecutionData);
        vm.stopPrank();

        uint256 usdcBalance = IERC20(USDC).balanceOf(address(superloop));
        assertGt(usdcBalance, 0);
    }

    function test_executeSwapAndExit() public {
        vm.startPrank(USDT_WHALE);
        IERC20(USDT).transfer(address(user), 1000 * 10 ** 6);
        vm.stopPrank();

        address tokenIn = USDT;
        address tokenOut = USDC;

        uint256 amountIn = 1000 * 10 ** 6;
        uint256 maxAmountIn = 1000 * 10 ** 6;
        uint256 minAmountOut = 900 * 10 ** 6;

        DataTypes.ExecuteSwapParamsData[] memory data = new DataTypes.ExecuteSwapParamsData[](2);
        data[0] = DataTypes.ExecuteSwapParamsData({
            target: USDT,
            data: abi.encodeWithSelector(IERC20.approve.selector, ROUTER, amountIn)
        });
        data[1] = DataTypes.ExecuteSwapParamsData({
            target: ROUTER,
            data: abi.encodeWithSelector(
                IRouter.exactInputSingle.selector,
                IRouter.ExactInputSingleParams({
                    tokenIn: USDT,
                    tokenOut: USDC,
                    fee: 100,
                    recipient: address(dexModule),
                    amountIn: amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            )
        });

        DataTypes.ExecuteSwapParams memory params = DataTypes.ExecuteSwapParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            maxAmountIn: maxAmountIn,
            minAmountOut: minAmountOut,
            data: data
        });

        vm.startPrank(user);
        IERC20(USDT).approve(address(dexModule), amountIn);
        uint256 amountOut = dexModule.executeAndExit(params, user);

        vm.stopPrank();

        uint256 usdcBalanceUser = IERC20(USDC).balanceOf(address(user));
        assertEq(usdcBalanceUser, amountOut);
    }
}
