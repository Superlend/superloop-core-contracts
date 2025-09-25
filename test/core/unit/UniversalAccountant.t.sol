// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {TestBase} from "../TestBase.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {MockVault} from "../../../src/mock/MockVault.sol";
import {UniversalAccountant} from "../../../src/core/Accountant/universalAccountant/UniversalAccountant.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IAaveOracle} from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import {IPriceOracleGetter} from "aave-v3-core/contracts/interfaces/IPriceOracleGetter.sol";
import {AaveV3AccountantPlugin} from "../../../src/plugins/Accountant/AaveV3AccountantPlugin.sol";

contract AccountantAaveV3Test is TestBase {
    UniversalAccountant public accountantImplementation;
    AaveV3AccountantPlugin public accountantPlugin;

    IERC20 public asset;
    MockVault public vault;

    // Test data
    uint256 public constant INITIAL_WHALE_BALANCE = 1000 ether;

    function setUp() public override {
        super.setUp();

        asset = IERC20(XTZ);
        vault = new MockVault(asset, "Mock Vault", "mVLT");

        address[] memory lendAssets = new address[](1);
        lendAssets[0] = ST_XTZ;
        address[] memory borrowAssets = new address[](1);
        borrowAssets[0] = XTZ;

        // deploy accountant plugin
        DataTypes.AaveV3AccountantPluginModuleInitData memory accountantPluginInitData = DataTypes
            .AaveV3AccountantPluginModuleInitData({
            poolAddressesProvider: AAVE_V3_POOL_ADDRESSES_PROVIDER,
            lendAssets: lendAssets,
            borrowAssets: borrowAssets
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

        // Fund the accountant with XTZ from whale
        vm.startPrank(XTZ_WHALE);
        asset.transfer(address(vault), INITIAL_WHALE_BALANCE);
        vm.stopPrank();
    }

    function test_Initialize() public view {
        assertEq(accountant.getTotalAssets(), INITIAL_WHALE_BALANCE);
        assertEq(accountant.performanceFee(), PERFORMANCE_FEE);
        assertEq(accountant.vault(), address(vault));
        assertEq(accountant.registeredAccountants()[0], address(accountantPlugin));
    }

    function test_InitializeRevertIfAlreadyInitialized() public {
        // Test that initialize reverts if called again
        address[] memory lendAssets = new address[](1);
        lendAssets[0] = ST_XTZ;
        address[] memory borrowAssets = new address[](1);
        borrowAssets[0] = XTZ;

        address[] memory registeredAccountants = new address[](1);
        registeredAccountants[0] = address(accountantPlugin);

        DataTypes.UniversalAccountantModuleInitData memory initData = DataTypes.UniversalAccountantModuleInitData({
            registeredAccountants: registeredAccountants,
            performanceFee: uint16(PERFORMANCE_FEE),
            vault: address(vault)
        });

        vm.expectRevert();
        accountant.initialize(initData);
    }

    function test_GetTotalAssets() public view {
        // Test getTotalAssets calculation using actual fork data
        uint256 totalAssets = accountant.getTotalAssets();

        // Should return the base asset balance since there are no lend/borrow positions yet
        assertEq(totalAssets, INITIAL_WHALE_BALANCE);

        console.log("Total assets:", totalAssets);
        console.log("Expected assets:", INITIAL_WHALE_BALANCE);
    }

    function test_GetTotalAssetsWithMultipleAssets() public {
        // mock pool data provider and price oracle
        _enableMockingPoolDataProvider();
        _enableMockingPriceOracle(1.01e8, 1e8);

        uint256 totalAssets = accountant.getTotalAssets();

        // Calculate expected total assets based on mock data:
        // Lend assets: 1000 ether * 1.01e8 (ST_XTZ price) = 1010e8
        // Borrow assets: -800 ether * 1e8 (XTZ price) = -800e8
        // Base asset balance: 1000 ether * 1e8 (XTZ price) = 1000e8
        // Total in market reference currency: 1010e8 - 800e8 + 1000e8 = 1210e8
        // Convert to base asset: 1210e18 / 1e18 = 1210 ether
        uint256 expectedTotalAssets = 1210 ether;

        assertEq(totalAssets, expectedTotalAssets);
        console.log("Total assets with multiple assets:", totalAssets);
        console.log("Expected total assets:", expectedTotalAssets);
    }

    function test_GetPerformanceFee() public {
        uint256 totalShares = 1000 ether;
        uint256 exchangeRate = 1.1e18; // 10% increase
        uint256 lastRealizedFeeExchangeRate = 1.0e18;
        uint256 totalSupply = 1000 ether;

        // Set the last realized fee exchange rate
        vm.prank(address(vault));
        accountant.setLastRealizedFeeExchangeRate(lastRealizedFeeExchangeRate, totalSupply);

        // Calculate expected performance fee
        uint256 latestAssetAmount = totalShares * exchangeRate;
        uint256 prevAssetAmount = totalShares * lastRealizedFeeExchangeRate;
        uint256 interestGenerated = latestAssetAmount - prevAssetAmount;
        uint256 expectedPerformanceFee = (interestGenerated * PERFORMANCE_FEE) / (10000 * 1e18);

        vm.prank(address(vault));
        uint256 actualPerformanceFee = accountant.getPerformanceFee(totalShares, exchangeRate, 18);

        console.log("Performance fee:", actualPerformanceFee);
        console.log("Expected fee:", expectedPerformanceFee);

        assertEq(actualPerformanceFee, expectedPerformanceFee);
    }

    function test_GetPerformanceFeeNoInterest() public {
        uint256 totalShares = 1000 ether;
        uint256 exchangeRate = 0.9e18; // 10% decrease
        uint256 lastRealizedFeeExchangeRate = 1.0e18;
        uint256 totalSupply = 1000 ether;
        // Set the last realized fee exchange rate
        vm.prank(address(vault));
        accountant.setLastRealizedFeeExchangeRate(lastRealizedFeeExchangeRate, totalSupply);

        vm.prank(address(vault));
        uint256 performanceFee = accountant.getPerformanceFee(totalShares, exchangeRate, 18);

        // Should return 0 when there's no interest (exchange rate decreased)
        assertEq(performanceFee, 0);
    }

    function test_GetPerformanceFeeRevertIfNotVault() public {
        uint256 totalShares = 1000 ether;
        uint256 exchangeRate = 1.1e18;

        vm.expectRevert();
        accountant.getPerformanceFee(totalShares, exchangeRate, 18);
    }

    function test_SetLastRealizedFeeExchangeRate() public {
        uint256 newExchangeRate = 1.2e18;
        uint256 totalSupply = 1000 ether;

        vm.prank(address(vault));
        accountant.setLastRealizedFeeExchangeRate(newExchangeRate, totalSupply);

        // Test that the exchange rate was set correctly by calling getPerformanceFee
        vm.prank(address(vault));
        uint256 performanceFee = accountant.getPerformanceFee(1000 ether, 1.3e18, 18);

        // Should calculate based on the new exchange rate
        uint256 expectedInterest = 1000 ether * 1.3e18 - 1000 ether * newExchangeRate;
        uint256 expectedFee = (expectedInterest * PERFORMANCE_FEE) / (10000 * 1e18);

        assertEq(performanceFee, expectedFee);
    }

    function test_SetLastRealizedFeeExchangeRateRevertIfNotVault() public {
        uint256 newExchangeRate = 1.2e18;
        uint256 totalSupply = 1000 ether;

        vm.expectRevert();
        accountant.setLastRealizedFeeExchangeRate(newExchangeRate, totalSupply);
    }

    function test_GetTotalAssetsWithZeroBalances() public view {
        // Test getTotalAssets when there are no lend/borrow positions
        // This should be the default state since we haven't interacted with Aave V3
        uint256 totalAssets = accountant.getTotalAssets();

        // Should only include base asset balance
        assertEq(totalAssets, INITIAL_WHALE_BALANCE);
    }

    function test_PerformanceFeeCalculationEdgeCases() public {
        // Test performance fee calculation with edge cases

        // Case 1: Zero shares
        vm.prank(address(vault));
        accountant.setLastRealizedFeeExchangeRate(1.0e18, 1000 ether);

        vm.prank(address(vault));
        uint256 fee1 = accountant.getPerformanceFee(0, 1.1e18, 18);
        assertEq(fee1, 0);

        // Case 2: Same exchange rate (no change)
        vm.prank(address(vault));
        uint256 fee2 = accountant.getPerformanceFee(1000 ether, 1.0e18, 18);
        assertEq(fee2, 0);

        // Case 3: Very small interest
        vm.prank(address(vault));
        uint256 fee3 = accountant.getPerformanceFee(1000 ether, 1.0001e18, 18);
        assertGt(fee3, 0);

        console.log("Small interest fee:", fee3);
    }

    function _enableMockingPoolDataProvider() internal {
        vm.mockCall(
            AAVE_V3_POOL_DATA_PROVIDER,
            abi.encodeWithSelector(IPoolDataProvider.getUserReserveData.selector, ST_XTZ, address(vault)),
            abi.encode(1000 * 10 ** 6, 0, 0, 0, 0, 0, 0, 0, 0)
        );

        vm.mockCall(
            AAVE_V3_POOL_DATA_PROVIDER,
            abi.encodeWithSelector(IPoolDataProvider.getUserReserveData.selector, XTZ, address(vault)),
            abi.encode(0, 0, 800 ether, 0, 0, 0, 0, 0, 0)
        );
    }

    function _enableMockingPriceOracle(uint256 stXtzPrice, uint256 xtzPrice) internal {
        vm.mockCall(
            AAVE_V3_PRICE_ORACLE,
            abi.encodeWithSelector(IPriceOracleGetter.getAssetPrice.selector, ST_XTZ),
            abi.encode(stXtzPrice)
        );

        vm.mockCall(
            AAVE_V3_PRICE_ORACLE,
            abi.encodeWithSelector(IPriceOracleGetter.getAssetPrice.selector, XTZ),
            abi.encode(xtzPrice)
        );
    }
}
