// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {UniversalDexModule} from "../../src/modules/UniversalDexModule.sol";
import {DataTypes} from "../../src/common/DataTypes.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface ISwap {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

interface IRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}

contract UniversalDexModuleTest is Test {
    UniversalDexModule public dexModule;
    address public USDT = 0x2C03058C8AFC06713be23e58D2febC8337dbfE6A;
    address public USDC = 0x796Ea11Fa2dD751eD01b53C372fFDB4AAa8f00F9;
    address public WXTZ = 0xc9B53AB2679f573e480d01e0f49e2B5CFB7a3EAb;
    address public WBTC = 0xbFc94CD2B1E55999Cfc7347a9313e88702B83d0F;
    address public ROUTER = 0xbfe9C246A5EdB4F021C8910155EC93e7CfDaB7a0;
    IRouter public router;
    address public USER;

    address public USDT_WHALE = 0x998098A1B2E95e2b8f15360676428EdFd976861f;

    function setUp() public {
        vm.createSelectFork("etherlink");
        dexModule = new UniversalDexModule();
        USER = vm.addr(123);
        router = IRouter(ROUTER);

        // usdt whale
        vm.prank(USDT_WHALE);
        IERC20(USDT).transfer(USER, 10000 * 10 ** 6);

        vm.label(USDT, "USDT");
        vm.label(USDC, "USDC");
        vm.label(WXTZ, "WXTZ");
        vm.label(WBTC, "WBTC");
        vm.label(ROUTER, "ROUTER");
        vm.label(USER, "USER");
        vm.label(USDT_WHALE, "USDT_WHALE");
    }

    function test_executeSwap() public {
        address tokenIn = USDT;
        address tokenOut = USDC;

        uint256 amountIn = 1000 * 10 ** 6;
        uint256 maxAmountIn = 1000 * 10 ** 6;
        uint256 minAmountOut = 0;

        DataTypes.ExecuteSwapParamsData[]
            memory data = new DataTypes.ExecuteSwapParamsData[](2);

        data[0] = DataTypes.ExecuteSwapParamsData({
            target: USDT,
            data: abi.encodeWithSelector(
                IERC20.approve.selector,
                ROUTER,
                amountIn
            )
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

        DataTypes.ExecuteSwapParams memory params = DataTypes
            .ExecuteSwapParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                amountIn: amountIn,
                maxAmountIn: maxAmountIn,
                minAmountOut: minAmountOut,
                data: data
            });

        vm.startPrank(USER);

        IERC20(USDT).transfer(address(dexModule), amountIn);
        uint256 amountOut = dexModule.executeSwap(params);

        vm.stopPrank();

        console.log("amountOut", amountOut);
    }

    function test_executeSwapAndExit() public {
        address tokenIn = USDT;
        address tokenOut = USDC;

        uint256 amountIn = 1000 * 10 ** 6;
        uint256 maxAmountIn = 1000 * 10 ** 6;
        uint256 minAmountOut = 0;

        DataTypes.ExecuteSwapParamsData[]
            memory data = new DataTypes.ExecuteSwapParamsData[](2);

        data[0] = DataTypes.ExecuteSwapParamsData({
            target: USDT,
            data: abi.encodeWithSelector(
                IERC20.approve.selector,
                ROUTER,
                amountIn
            )
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

        DataTypes.ExecuteSwapParams memory params = DataTypes
            .ExecuteSwapParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                amountIn: amountIn,
                maxAmountIn: maxAmountIn,
                minAmountOut: minAmountOut,
                data: data
            });

        vm.startPrank(USER);

        IERC20(USDT).approve(address(dexModule), amountIn);
        uint256 amountOut = dexModule.executeSwapAndExit(params, USER);

        vm.stopPrank();
        uint256 usdcBalance = IERC20(USDC).balanceOf(USER);

        console.log("amountOut", amountOut);
        console.log("usdcBalance", usdcBalance);
    }
}
