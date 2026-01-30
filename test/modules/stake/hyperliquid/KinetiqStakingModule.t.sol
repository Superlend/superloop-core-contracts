// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {TestBase} from "../../../core/TestBase.sol";
import {DataTypes} from "../../../../src/common/DataTypes.sol";
import {Superloop} from "../../../../src/core/Superloop/Superloop.sol";
import {
    TransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IPoolConfigurator} from "aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";
import {console} from "forge-std/console.sol";

contract KinetiqStakingModuleTest is TestBase {
    Superloop public superloopImplementation;
    address public user;
    uint256 public constant WHYPE_SCALE = 10 ** 18;

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);
        _deployHyperliquidStakeModule();

        address[] memory modules = new address[](5);
        modules[0] = address(hyperliquidStakeModule);
        modules[1] = address(kinetiqStakeModule);
        modules[2] = address(hyperbeatStakingModule);
        modules[3] = address(wrapModule);
        modules[4] = address(unwrapModule);

        DataTypes.VaultInitData memory initData = DataTypes.VaultInitData({
            asset: environment.vaultAsset,
            name: "Vault",
            symbol: "VLT",
            supplyCap: 100000 * 10 ** environment.vaultAssetDecimals,
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

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(superloopImplementation),
            address(this),
            abi.encodeWithSelector(Superloop.initialize.selector, initData)
        );
        superloop = Superloop(payable(address(proxy)));
        vm.stopPrank();

        user = makeAddr("user");
        vm.label(user, "user");
        vm.label(address(superloop), "superloop");
    }

    function test_KinetiqStake() public {
        // transfer 100 wHYPE to the vault
        deal(environment.vaultAsset, address(superloop), 100 * 10 ** environment.vaultAssetDecimals);

        // call unwrap module & kinetiq stake module
        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](2);
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(unwrapModule),
            data: abi.encodeWithSelector(
                unwrapModule.execute.selector,
                DataTypes.AaveV3ActionParams({asset: environment.vaultAsset, amount: 100 * WHYPE_SCALE})
            )
        });
        moduleExecutionData[1] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(kinetiqStakeModule),
            data: abi.encodeWithSelector(
                kinetiqStakeModule.execute.selector,
                DataTypes.StakeParams({
                    assets: 100 * 10 ** environment.vaultAssetDecimals, data: abi.encode(string(""))
                })
            )
        });

        uint256 currentBalanceKHype = IERC20(K_HYPE).balanceOf(address(superloop));

        vm.prank(admin);
        superloop.operate(moduleExecutionData);

        uint256 finalBalanceKHype = IERC20(K_HYPE).balanceOf(address(superloop));

        assertApproxEqAbs(finalBalanceKHype, currentBalanceKHype + 100 * WHYPE_SCALE, 5 * WHYPE_SCALE);
    }
}
