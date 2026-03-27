// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {SuperloopAccountantPlugin} from "../../../src/plugins/Accountant/superloop/SuperloopAccountantPlugin.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";

contract MockTokenWithDecimals {
    uint8 private immutable _decimals;

    constructor(uint8 decimals_) {
        _decimals = decimals_;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }
}

contract MockAaveOracle {
    mapping(address asset => uint256 price) public prices;

    function setPrice(address asset, uint256 price) external {
        prices[asset] = price;
    }

    function getAssetPrice(address asset) external view returns (uint256) {
        return prices[asset];
    }
}

contract MockDepositManagerForPlugin {
    DataTypes.DepositRequestData public request;
    uint256 public requestId;

    function setUserDepositRequest(DataTypes.DepositRequestData memory req, uint256 id) external {
        request = req;
        requestId = id;
    }

    function userDepositRequest(address) external view returns (DataTypes.DepositRequestData memory, uint256) {
        return (request, requestId);
    }
}

contract MockWithdrawManagerForPlugin {
    mapping(uint8 requestType => DataTypes.WithdrawRequestData request) public requests;
    mapping(uint8 requestType => uint256 requestId) public requestIds;

    function setUserWithdrawRequest(
        DataTypes.WithdrawRequestType requestType,
        DataTypes.WithdrawRequestData memory req,
        uint256 id
    ) external {
        requests[uint8(requestType)] = req;
        requestIds[uint8(requestType)] = id;
    }

    function userWithdrawRequest(address, DataTypes.WithdrawRequestType requestType)
        external
        view
        returns (DataTypes.WithdrawRequestData memory, uint256)
    {
        return (requests[uint8(requestType)], requestIds[uint8(requestType)]);
    }
}

contract MockUnderlyingVaultForPlugin {
    address public asset;
    uint8 public decimals;
    address public withdrawManager;
    address public depositManagerModule;
    uint256 public exchangeRate;
    mapping(address owner => uint256 shares) public balanceOf;

    constructor(address asset_, uint8 decimals_, uint256 exchangeRate_) {
        asset = asset_;
        decimals = decimals_;
        exchangeRate = exchangeRate_;
    }

    function setManagers(address withdrawManager_, address depositManagerModule_) external {
        withdrawManager = withdrawManager_;
        depositManagerModule = depositManagerModule_;
    }

    function setBalance(address owner, uint256 shares) external {
        balanceOf[owner] = shares;
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        return shares * exchangeRate / (10 ** decimals);
    }
}

contract MockQueryVaultForPlugin {
    address public asset;

    constructor(address asset_) {
        asset = asset_;
    }
}

contract SuperloopAccountantPluginHarness is SuperloopAccountantPlugin {
    constructor(address owner) SuperloopAccountantPlugin(owner) {}

    function exposedGetAssetsFromWithdrawManager(GetAssetsFromManagerParams memory params)
        external
        view
        returns (uint256)
    {
        return _getAssetsFromWithdrawManager(params);
    }

    function exposedGetAssetsFromDepositManager(GetAssetsFromManagerParams memory params)
        external
        view
        returns (uint256)
    {
        return _getAssetsFromDepositManager(params);
    }

    function exposedGetAssetsFromUnderlyingVault(GetAssetsFromManagerParams memory params, address queryVault)
        external
        view
        returns (uint256)
    {
        return _getAssetsFromUnderlyingVault(params, queryVault);
    }
}

contract SuperloopAccountantPluginUnitTest is Test {
    SuperloopAccountantPluginHarness internal plugin;
    MockTokenWithDecimals internal underlyingAsset;
    MockTokenWithDecimals internal baseAsset;
    MockAaveOracle internal oracle;
    MockDepositManagerForPlugin internal depositManager;
    MockWithdrawManagerForPlugin internal withdrawManager;
    MockUnderlyingVaultForPlugin internal underlyingVault;
    MockQueryVaultForPlugin internal queryVault;

    uint8 internal constant UNDERLYING_ASSET_DECIMALS = 18;
    uint8 internal constant BASE_ASSET_DECIMALS = 8;
    uint8 internal constant VAULT_DECIMALS = 18;
    uint256 internal constant EXCHANGE_RATE = 2e18; // 1 share => 2 assets
    uint256 internal constant UNDERLYING_PRICE = 1e8;
    uint256 internal constant BASE_PRICE = 100 * 1e8;

    function setUp() public {
        plugin = new SuperloopAccountantPluginHarness(address(this));
        underlyingAsset = new MockTokenWithDecimals(UNDERLYING_ASSET_DECIMALS);
        baseAsset = new MockTokenWithDecimals(BASE_ASSET_DECIMALS);
        oracle = new MockAaveOracle();
        depositManager = new MockDepositManagerForPlugin();
        withdrawManager = new MockWithdrawManagerForPlugin();
        underlyingVault = new MockUnderlyingVaultForPlugin(address(underlyingAsset), VAULT_DECIMALS, EXCHANGE_RATE);
        queryVault = new MockQueryVaultForPlugin(address(baseAsset));

        underlyingVault.setManagers(address(withdrawManager), address(depositManager));
        oracle.setPrice(address(underlyingAsset), UNDERLYING_PRICE);
        oracle.setPrice(address(baseAsset), BASE_PRICE);

        plugin.setUnderlyingVault(address(underlyingVault));
        plugin.setAaveOracle(address(oracle));
    }

    function _params() internal view returns (SuperloopAccountantPlugin.GetAssetsFromManagerParams memory) {
        return SuperloopAccountantPlugin.GetAssetsFromManagerParams({
            vault: address(underlyingVault),
            vaultDecimals: VAULT_DECIMALS,
            exchangeRate: EXCHANGE_RATE,
            underlyingAssetPrice: UNDERLYING_PRICE,
            baseAssetPrice: BASE_PRICE,
            underlyingAssetDecimals: UNDERLYING_ASSET_DECIMALS,
            baseAssetDecimals: BASE_ASSET_DECIMALS
        });
    }

    function test_getAssetsFromWithdrawManager_sumsAllQueues() public {
        // assets from here = 10e18
        // expected in terms of base asset = 10e18 * 1e8 * 1e6/ 100 * 1e8 * 1e18

        DataTypes.WithdrawRequestData memory general = DataTypes.WithdrawRequestData({
            shares: 10e18,
            sharesProcessed: 0,
            amountClaimable: 0,
            amountClaimed: 0,
            user: address(underlyingVault),
            state: DataTypes.RequestProcessingState.UNPROCESSED
        }); // 2e7 assets from here
        DataTypes.WithdrawRequestData memory deferred = DataTypes.WithdrawRequestData({
            shares: 5e18,
            sharesProcessed: 5e18,
            amountClaimable: 5e18,
            amountClaimed: 0,
            user: address(underlyingVault),
            state: DataTypes.RequestProcessingState.FULLY_PROCESSED
        }); // 5e6 assets from here
        DataTypes.WithdrawRequestData memory priority = DataTypes.WithdrawRequestData({
            shares: 100e18,
            sharesProcessed: 0,
            amountClaimable: 0,
            amountClaimed: 0,
            user: address(underlyingVault),
            state: DataTypes.RequestProcessingState.CANCELLED
        }); // 0 assets from here
        DataTypes.WithdrawRequestData memory instant = DataTypes.WithdrawRequestData({
            shares: 1e18,
            sharesProcessed: 25e16,
            amountClaimable: 5e17,
            amountClaimed: 0,
            user: address(underlyingVault),
            state: DataTypes.RequestProcessingState.PARTIALLY_PROCESSED
        }); // 5e5 + 15e5 = 2e6 from here

        uint256 expectedTotalAssets = 2e7 + 5e6 + 0 + 2e6;

        withdrawManager.setUserWithdrawRequest(DataTypes.WithdrawRequestType.GENERAL, general, 1);
        withdrawManager.setUserWithdrawRequest(DataTypes.WithdrawRequestType.DEFERRED, deferred, 2);
        withdrawManager.setUserWithdrawRequest(DataTypes.WithdrawRequestType.PRIORITY, priority, 3);
        withdrawManager.setUserWithdrawRequest(DataTypes.WithdrawRequestType.INSTANT, instant, 4);

        uint256 assets = plugin.exposedGetAssetsFromWithdrawManager(_params());
        assertEq(assets, expectedTotalAssets);
    }

    function test_getAssetsFromDepositManager_onlyPartiallyProcessed() public {
        DataTypes.DepositRequestData memory req = DataTypes.DepositRequestData({
            amount: 10e18,
            amountProcessed: 5e18,
            sharesMinted: 5e18,
            user: address(underlyingVault),
            state: DataTypes.RequestProcessingState.PARTIALLY_PROCESSED
        });
        depositManager.setUserDepositRequest(req, 1);

        uint256 expectedAssets = 5e6;

        uint256 assets = plugin.exposedGetAssetsFromDepositManager(_params());
        assertEq(assets, expectedAssets);
    }

    function test_getAssetsFromDepositmanager_onlyPending() public {
        DataTypes.DepositRequestData memory req = DataTypes.DepositRequestData({
            amount: 10e18,
            amountProcessed: 0,
            sharesMinted: 5e18,
            user: address(underlyingVault),
            state: DataTypes.RequestProcessingState.UNPROCESSED
        });
        depositManager.setUserDepositRequest(req, 1);

        uint256 expectedAssets = 1e7;

        uint256 assets = plugin.exposedGetAssetsFromDepositManager(_params());
        assertEq(assets, expectedAssets);
    }


    function test_getAssetsFromDepositManager_returnsZeroForCancelled() public {
        DataTypes.DepositRequestData memory req = DataTypes.DepositRequestData({
            amount: 9e18,
            amountProcessed: 4e18,
            sharesMinted: 0,
            user: address(underlyingVault),
            state: DataTypes.RequestProcessingState.CANCELLED
        });
        depositManager.setUserDepositRequest(req, 1);

        uint256 assets = plugin.exposedGetAssetsFromDepositManager(_params());
        assertEq(assets, 0);
    }

    function test_getTotalAssets_includesWithdrawDepositAndUnderlyingVaultBalances() public {
        DataTypes.WithdrawRequestData memory general = DataTypes.WithdrawRequestData({
            shares: 10e18,
            sharesProcessed: 0,
            amountClaimable: 0,
            amountClaimed: 0,
            user: address(underlyingVault),
            state: DataTypes.RequestProcessingState.UNPROCESSED
        }); // 2e7 assets from here
        DataTypes.WithdrawRequestData memory deferred = DataTypes.WithdrawRequestData({
            shares: 5e18,
            sharesProcessed: 5e18,
            amountClaimable: 5e18,
            amountClaimed: 0,
            user: address(underlyingVault),
            state: DataTypes.RequestProcessingState.FULLY_PROCESSED
        }); // 5e6 assets from here
        DataTypes.WithdrawRequestData memory instant = DataTypes.WithdrawRequestData({
            shares: 1e18,
            sharesProcessed: 25e16,
            amountClaimable: 5e17,
            amountClaimed: 0,
            user: address(underlyingVault),
            state: DataTypes.RequestProcessingState.PARTIALLY_PROCESSED
        }); // 5e5 + 15e5 = 2e6 from here
        withdrawManager.setUserWithdrawRequest(DataTypes.WithdrawRequestType.GENERAL, general, 1);
        withdrawManager.setUserWithdrawRequest(DataTypes.WithdrawRequestType.DEFERRED, deferred, 2);
        withdrawManager.setUserWithdrawRequest(
            DataTypes.WithdrawRequestType.PRIORITY,
            DataTypes.WithdrawRequestData(0, 0, 0, 0, address(0), DataTypes.RequestProcessingState.NOT_EXIST),
            0
        );
        withdrawManager.setUserWithdrawRequest(DataTypes.WithdrawRequestType.INSTANT, instant, 4);
        uint256 expectedAssetsFromWithdrawManager = 2e7 + 5e6 + 2e6;

        DataTypes.DepositRequestData memory req = DataTypes.DepositRequestData({
            amount: 10e18,
            amountProcessed: 5e18,
            sharesMinted: 5e18,
            user: address(underlyingVault),
            state: DataTypes.RequestProcessingState.PARTIALLY_PROCESSED
        });
        depositManager.setUserDepositRequest(req, 1); // 5e6 assets from here
        uint256 expectedAssetsFromDepositManager = 5e6;

        underlyingVault.setBalance(address(queryVault), 10e18); // 2e7 assets from here
        uint256 expectedAssetsFromUnderlyingVault = 2e7;

        uint256 expectedTotalAssets = 
            expectedAssetsFromWithdrawManager + expectedAssetsFromDepositManager + expectedAssetsFromUnderlyingVault;

        uint256 totalAssets = plugin.getTotalAssets(address(queryVault));
        assertEq(totalAssets, expectedTotalAssets);
    }
}
