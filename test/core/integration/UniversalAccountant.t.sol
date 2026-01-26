// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestBase} from "../TestBase.sol";
import {UniversalAccountant} from "../../../src/core/Accountant/universalAccountant/UniversalAccountant.sol";
import {AaveV3AccountantPlugin} from "../../../src/plugins/Accountant/AaveV3AccountantPlugin.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {console} from "forge-std/console.sol";
import {MockVault} from "../../../src/mock/MockVault.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IAaveOracle} from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";

contract UniversalAccountantTest is TestBase {
    UniversalAccountant public accountantImplementation;
    AaveV3AccountantPlugin public accountantPlugin;

    MockVault public vault;

    function setUp() public override {
        super.setUp();

        vault = new MockVault(IERC20(environment.vaultAsset), "Mock Vault", "mVLT");

        // deploy accountant plugin
        DataTypes.AaveV3AccountantPluginModuleInitData memory accountantPluginInitData = DataTypes
            .AaveV3AccountantPluginModuleInitData({
            poolAddressesProvider: environment.poolAddressesProvider,
            lendAssets: environment.lendAssets,
            borrowAssets: environment.borrowAssets
        });
        accountantPlugin = new AaveV3AccountantPlugin(accountantPluginInitData);

        address[] memory registeredAccountants = new address[](1);
        registeredAccountants[0] = address(accountantPlugin);

        // deploy accountant
        DataTypes.UniversalAccountantModuleInitData memory initData = DataTypes.UniversalAccountantModuleInitData({
            registeredAccountants: registeredAccountants,
            performanceFee: uint16(PERFORMANCE_FEE),
            vault: address(vault)
        });

        accountantImplementation = new UniversalAccountant();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(accountantImplementation),
            address(this),
            abi.encodeWithSelector(UniversalAccountant.initialize.selector, initData)
        );

        accountant = UniversalAccountant(address(proxy));
    }

    function test_UniversalAccountWithMutlipleTokens() public {
        // create lend posiitions
        vm.startPrank(address(vault));
        for (uint256 i = 0; i < environment.lendAssets.length; i++) {
            uint8 decimals = IERC20Metadata(environment.lendAssets[i]).decimals();
            deal(environment.lendAssets[i], address(vault), 1000 * 10 ** decimals);
            IERC20(environment.lendAssets[i]).approve(environment.pool, 1000 * 10 ** decimals);
            IPool(environment.pool).supply(environment.lendAssets[i], 1000 * 10 ** decimals, address(vault), 0);
        }

        // create borrow positions
        for (uint256 i = 0; i < environment.borrowAssets.length; i++) {
            uint8 decimals = IERC20Metadata(environment.borrowAssets[i]).decimals();
            IPool(environment.pool).borrow(
                environment.borrowAssets[i], 500 * 10 ** decimals, INTEREST_RATE_MODE, 0, address(vault)
            );
        }
        vm.stopPrank();

        for (uint256 i = 0; i < environment.lendAssets.length; i++) {
            (uint256 currentSupply,,,,,,,,) = IPoolDataProvider(environment.poolDataProvider).getUserReserveData(
                environment.lendAssets[i], address(vault)
            );
            assertApproxEqAbs(currentSupply, 1000 * 10 ** IERC20Metadata(environment.lendAssets[i]).decimals(), 2);
        }
        for (uint256 i = 0; i < environment.borrowAssets.length; i++) {
            (,, uint256 currentBorrow,,,,,,) = IPoolDataProvider(environment.poolDataProvider).getUserReserveData(
                environment.borrowAssets[i], address(vault)
            );

            assertApproxEqAbs(currentBorrow, 500 * 10 ** IERC20Metadata(environment.borrowAssets[i]).decimals(), 2);
        }

        // fund the vault for some tokens
        deal(environment.vaultAsset, address(vault), 1000 * 10 ** environment.vaultAssetDecimals);
        uint256 totalAssets = accountant.getTotalAssets();
        assert(totalAssets > (1200 + 1000) * 10 ** environment.vaultAssetDecimals); // aprox 1200 for lend and borrow positions and 1000 for the vault asset
    }
}
