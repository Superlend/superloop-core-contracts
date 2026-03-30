// deploy a new vault of wBTC use usde vault as one of the venues

import {console} from "forge-std/console.sol";
import {IntegrationBase} from "./IntegrationBase.sol";
import {SuperloopAccountantPlugin} from "../../../src/plugins/Accountant/superloop/SuperloopAccountantPlugin.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IPoolDataProvider} from "../../../lib/aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {UniversalAccountant} from "../../../src/core/Accountant/universalAccountant/UniversalAccountant.sol";
import {IDepositManager} from "../../../src/interfaces/IDepositManager.sol";
import {ISuperloop} from "../../../src/interfaces/ISuperloop.sol";
import {IWithdrawManager} from "../../../src/interfaces/IWithdrawManager.sol";
import {IAaveOracle} from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";

contract BtcCarryTradeTest is IntegrationBase {
    SuperloopAccountantPlugin public superloopPlugin;

    function setUp() public override {
        super.setUp();

        // deploy the new accountant plugin and add it to the universal accountant
        DataTypes.SuperloopAccountantPluginModuleInitData memory data = DataTypes.SuperloopAccountantPluginModuleInitData({
            underlyingVault: environment.externalVault, aaveOracle: environment.priceOracle
        });
        superloopPlugin = new SuperloopAccountantPlugin(data);

        address[] memory registeredAccountants = accountant.registeredAccountants();

        address[] memory newRegisteredAccountants = new address[](registeredAccountants.length + 1);
        for (uint256 i = 0; i < registeredAccountants.length; i++) {
            newRegisteredAccountants[i] = registeredAccountants[i];
        }
        newRegisteredAccountants[registeredAccountants.length] = address(superloopPlugin);

        address _owner = accountant.owner();
        vm.prank(_owner);
        accountant.setRegisteredAccountants(newRegisteredAccountants);
    }

    function testInit() public {
        assertEq(depositManager.vault(), address(superloop));
        assertEq(depositManager.asset(), environment.vaultAsset);
        assertEq(depositManager.nextDepositRequestId(), 1);
        assertEq(withdrawManager.vault(), address(superloop));
        assertEq(withdrawManager.asset(), environment.vaultAsset);
        assertEq(withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.GENERAL), 1);
        assertEq(withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.INSTANT), 1);
        assertEq(withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.PRIORITY), 1);
        assertEq(withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.DEFERRED), 1);
        assertEq(superloopPlugin.underlyingVault(), environment.externalVault);
        assertEq(superloopPlugin.aaveOracle(), environment.priceOracle);
        address __accountant = superloop.accountant();
        assertEq(UniversalAccountant(__accountant).registeredAccountants().length, 2);
    }

    function test_depositAndFullLoop() public {
        uint256 vaultAssetScale = 10 ** environment.vaultAssetDecimals;
        uint256 usdeAssetScale = 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals();

        uint256 depositAmount = 1 * vaultAssetScale;
        deal(environment.vaultAsset, user1, depositAmount);
        vm.startPrank(user1);
        IERC20(environment.vaultAsset).approve(address(depositManager), depositAmount);
        depositManager.requestDeposit(depositAmount, address(0));
        vm.stopPrank();

        // now i should 1btc worth of deposit request in my deposit manager
        DataTypes.DepositRequestData memory depositRequest = depositManager.depositRequest(1);
        assertEq(depositRequest.amount, depositAmount);
        assertEq(depositRequest.amountProcessed, 0);
        assertEq(depositRequest.sharesMinted, 0);
        assertEq(depositRequest.user, user1);
        assertEq(uint256(depositRequest.state), uint256(DataTypes.RequestProcessingState.UNPROCESSED));

        uint256 borrowAmount = 30000 * usdeAssetScale;
        uint256 depositAmountToProcess = 25000 * usdeAssetScale;
        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);
        // deposit 1 btc
        moduleExecutionData[0] = _supplyCall(environment.lendAssets[0], type(uint256).max);
        // borrow 30k USDe
        moduleExecutionData[1] = _borrowCall(environment.borrowAssets[0], borrowAmount);
        // put 25k out of the 30k into the USDe vault (make deposit req)
        moduleExecutionData[2] = _superloopDepositCall(depositAmountToProcess, environment.borrowAssets[0]);

        DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](1);
        finalExecutionData[0] =
            _resolveDepositRequestsCall(environment.vaultAsset, depositAmount, abi.encode(moduleExecutionData));

        vm.prank(admin);
        superloop.operate(finalExecutionData);

        uint256 totalAssets = superloop.totalAssets();
        uint256 borrowBalance = IERC20(environment.borrowAssets[0]).balanceOf(address(superloop));
        uint256 lendBalance = IERC20(environment.lendAssets[0]).balanceOf(address(superloop));

        assertApproxEqAbs(totalAssets, depositAmount, 100);
        assertApproxEqAbs(borrowBalance, borrowAmount - depositAmountToProcess, 1);

        (uint256 currentSupply,,,,,,,,) = IPoolDataProvider(environment.poolDataProvider)
            .getUserReserveData(environment.lendAssets[0], address(superloop));
        (,, uint256 currentBorrowBalance,,,,,,) = IPoolDataProvider(environment.poolDataProvider)
            .getUserReserveData(environment.borrowAssets[0], address(superloop));

        assertApproxEqAbs(currentSupply, depositAmount, 10);
        assertApproxEqAbs(currentBorrowBalance, borrowAmount, 10);

        address usdeDepositManager = ISuperloop(environment.externalVault).depositManagerModule();

        (DataTypes.DepositRequestData memory _depositRequest,) =
            IDepositManager(usdeDepositManager).userDepositRequest(address(superloop));

        assertApproxEqAbs(_depositRequest.amount, depositAmountToProcess, 100);
        assertApproxEqAbs(_depositRequest.amountProcessed, 0, 10);
        assertApproxEqAbs(_depositRequest.sharesMinted, 0, 10);
        assertEq(_depositRequest.user, address(superloop));
        assertEq(uint256(_depositRequest.state), uint256(DataTypes.RequestProcessingState.UNPROCESSED));

        // partially resolve the vault's deposit request => have a partially processed deposit request
        address usdeAdmin = ISuperloop(environment.externalVault).vaultOperator();
        // do am empty resolution of 10k USDe from USDe vault admin
        DataTypes.ModuleExecutionData[] memory emptyModuleExecutionData = new DataTypes.ModuleExecutionData[](0);
        DataTypes.ModuleExecutionData[] memory emptyResolutionExecutionData = new DataTypes.ModuleExecutionData[](1);
        emptyResolutionExecutionData[0] = _resolveDepositRequestsCall(
            environment.borrowAssets[0],
            depositAmountToProcess / 2,
            usdeDepositManager,
            abi.encode(emptyModuleExecutionData)
        );

        vm.prank(usdeAdmin);
        ISuperloop(environment.externalVault).operate(emptyResolutionExecutionData);

        (_depositRequest,) = IDepositManager(usdeDepositManager).userDepositRequest(address(superloop));
        assertApproxEqAbs(_depositRequest.amount, depositAmountToProcess, 100);
        assertApproxEqAbs(_depositRequest.amountProcessed, depositAmountToProcess / 2, 10);
        assertEq(uint256(_depositRequest.state), uint256(DataTypes.RequestProcessingState.PARTIALLY_PROCESSED));

        uint256 shareBalance = ISuperloop(environment.externalVault).balanceOf(address(superloop));
        uint256 exchangeRate = ISuperloop(environment.externalVault).convertToAssets(ONE_SHARE);

        // observe the total assets
        totalAssets = superloop.totalAssets();
        uint256 estimatedProcessedAssets = shareBalance * exchangeRate / 1e20;
        assertApproxEqAbs(estimatedProcessedAssets, depositAmountToProcess / 2, 1e6);
        assertApproxEqAbs(totalAssets, depositAmount, 100);

        // completely process the vault's deposit request => have a fully processed deposit request
        // observe the total assets
        vm.prank(usdeAdmin);
        ISuperloop(environment.externalVault).operate(emptyResolutionExecutionData);
        (_depositRequest,) = IDepositManager(usdeDepositManager).userDepositRequest(address(superloop));
        assertApproxEqAbs(_depositRequest.amount, depositAmountToProcess, 100);
        assertApproxEqAbs(_depositRequest.amountProcessed, depositAmountToProcess, 10);
        assertEq(uint256(_depositRequest.state), uint256(DataTypes.RequestProcessingState.FULLY_PROCESSED));
        shareBalance = ISuperloop(environment.externalVault).balanceOf(address(superloop));
        exchangeRate = ISuperloop(environment.externalVault).convertToAssets(ONE_SHARE);

        totalAssets = superloop.totalAssets();
        estimatedProcessedAssets = shareBalance * exchangeRate / 1e20;
        assertApproxEqAbs(estimatedProcessedAssets, depositAmountToProcess, 1e6);
        assertApproxEqAbs(totalAssets, depositAmount, 100);

        // make another deposit request and cancel it.
        moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] =
            _superloopDepositCall((borrowAmount - depositAmountToProcess) / 2, environment.borrowAssets[0]);
        vm.prank(admin);
        superloop.operate(moduleExecutionData);

        (DataTypes.DepositRequestData memory __depositRequest, uint256 requestId) =
            IDepositManager(usdeDepositManager).userDepositRequest(address(superloop));
        assertApproxEqAbs(__depositRequest.amount, (borrowAmount - depositAmountToProcess) / 2, 100);
        assertApproxEqAbs(__depositRequest.amountProcessed, 0, 10);
        assertEq(uint256(__depositRequest.state), uint256(DataTypes.RequestProcessingState.UNPROCESSED));

        totalAssets = superloop.totalAssets();
        assertApproxEqAbs(totalAssets, depositAmount, 100);

        moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] = _superloopExitDepositCall(requestId);
        vm.prank(admin);
        superloop.operate(moduleExecutionData);
        totalAssets = superloop.totalAssets();
        assertApproxEqAbs(totalAssets, depositAmount, 100);

        // donate some USDe to the underlying vault => simulating yield
        // make the exchange rate exactly 2
        uint256 amountToDonate = (2 * ISuperloop(environment.externalVault).totalSupply() / 100)
            - ISuperloop(environment.externalVault).totalAssets() + 100;
        address tempUser = makeAddr("tempUser");
        deal(environment.borrowAssets[0], tempUser, amountToDonate);

        vm.prank(tempUser);
        IERC20(environment.borrowAssets[0]).transfer(address(environment.externalVault), amountToDonate);

        ISuperloop(environment.externalVault).realizePerformanceFee();

        exchangeRate = ISuperloop(environment.externalVault).convertToAssets(ONE_SHARE);
        totalAssets = superloop.totalAssets();
        // observe the total assets
        assertTrue(totalAssets > depositAmount); // because of yield generation
        uint256 totalAssetsBenchmark = totalAssets;

        // make 2 withdraw requests for the vault
        moduleExecutionData = new DataTypes.ModuleExecutionData[](2);
        moduleExecutionData[0] = _superloopWithdrawCall(100 * ONE_SHARE, DataTypes.WithdrawRequestType.GENERAL);
        moduleExecutionData[1] = _superloopWithdrawCall(200 * ONE_SHARE, DataTypes.WithdrawRequestType.INSTANT);

        vm.prank(admin);
        superloop.operate(moduleExecutionData);

        address usdeWithdrawManager = ISuperloop(environment.externalVault).withdrawManager();
        (DataTypes.WithdrawRequestData memory withdrawRequestGeneral, uint256 withdrawRequestIdGeneral) = IWithdrawManager(
                usdeWithdrawManager
            ).userWithdrawRequest(address(superloop), DataTypes.WithdrawRequestType.GENERAL);
        (DataTypes.WithdrawRequestData memory withdrawRequestInstant, uint256 withdrawRequestIdInstant) = IWithdrawManager(
                usdeWithdrawManager
            ).userWithdrawRequest(address(superloop), DataTypes.WithdrawRequestType.INSTANT);

        // observe the total assets
        assertEq(withdrawRequestGeneral.shares, 100 * ONE_SHARE);
        assertEq(withdrawRequestGeneral.sharesProcessed, 0);
        assertEq(uint256(withdrawRequestGeneral.state), uint256(DataTypes.RequestProcessingState.UNPROCESSED));
        assertEq(withdrawRequestInstant.shares, 200 * ONE_SHARE);
        assertEq(withdrawRequestInstant.sharesProcessed, 0);
        assertEq(uint256(withdrawRequestInstant.state), uint256(DataTypes.RequestProcessingState.UNPROCESSED));

        totalAssets = superloop.totalAssets();
        assertApproxEqAbs(totalAssets, totalAssetsBenchmark, 100);

        // process one and cancel the other withdraw request
        // observe the total assets
        moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] =
            _superloopExitWithdrawCall(withdrawRequestIdInstant, DataTypes.WithdrawRequestType.INSTANT);
        vm.prank(admin);
        superloop.operate(moduleExecutionData);

        withdrawRequestInstant = IWithdrawManager(usdeWithdrawManager)
            .withdrawRequest(withdrawRequestIdInstant, DataTypes.WithdrawRequestType.INSTANT);
        assertEq(withdrawRequestInstant.shares, 200 * ONE_SHARE);
        assertEq(withdrawRequestInstant.sharesProcessed, 0);
        assertEq(withdrawRequestInstant.amountClaimed, 0);
        assertEq(withdrawRequestInstant.amountClaimable, 0);
        assertEq(uint256(withdrawRequestInstant.state), uint256(DataTypes.RequestProcessingState.CANCELLED));

        totalAssets = superloop.totalAssets();
        assertApproxEqAbs(totalAssets, totalAssetsBenchmark, 100);

        // process one withdraw, don't claim yet just resolve and query total assets
        emptyModuleExecutionData = new DataTypes.ModuleExecutionData[](0);
        emptyResolutionExecutionData = new DataTypes.ModuleExecutionData[](1);
        emptyResolutionExecutionData[0] = _resolveWithdrawRequestsCall(
            50 * ONE_SHARE,
            DataTypes.WithdrawRequestType.GENERAL,
            usdeWithdrawManager,
            abi.encode(emptyModuleExecutionData)
        );

        vm.prank(usdeAdmin);
        ISuperloop(environment.externalVault).operate(emptyResolutionExecutionData);

        withdrawRequestInstant = IWithdrawManager(usdeWithdrawManager)
            .withdrawRequest(withdrawRequestIdGeneral, DataTypes.WithdrawRequestType.GENERAL);
        assertEq(withdrawRequestInstant.shares, 100 * ONE_SHARE);
        assertEq(withdrawRequestInstant.sharesProcessed, 50 * ONE_SHARE);
        assertEq(withdrawRequestInstant.amountClaimed, 0);
        assertTrue(withdrawRequestInstant.amountClaimable > 0);
        assertEq(uint256(withdrawRequestInstant.state), uint256(DataTypes.RequestProcessingState.PARTIALLY_PROCESSED));

        totalAssets = superloop.totalAssets();
        assertApproxEqAbs(totalAssets, totalAssetsBenchmark, 100);

        moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] =
            _superloopClaimWithdrawCall(withdrawRequestIdGeneral, DataTypes.WithdrawRequestType.GENERAL);

        vm.prank(admin);
        superloop.operate(moduleExecutionData);
        withdrawRequestInstant = IWithdrawManager(usdeWithdrawManager)
            .withdrawRequest(withdrawRequestIdGeneral, DataTypes.WithdrawRequestType.GENERAL);
        assertEq(withdrawRequestInstant.shares, 100 * ONE_SHARE);
        assertEq(withdrawRequestInstant.sharesProcessed, 50 * ONE_SHARE);
        assertTrue(withdrawRequestInstant.amountClaimable == 0);
        assertTrue(withdrawRequestInstant.amountClaimed > 0);
        assertEq(uint256(withdrawRequestInstant.state), uint256(DataTypes.RequestProcessingState.PARTIALLY_PROCESSED));

        totalAssets = superloop.totalAssets();
        assertApproxEqAbs(totalAssets, totalAssetsBenchmark, 100);

        vm.prank(usdeAdmin);
        ISuperloop(environment.externalVault).operate(emptyResolutionExecutionData);
        withdrawRequestInstant = IWithdrawManager(usdeWithdrawManager)
            .withdrawRequest(withdrawRequestIdGeneral, DataTypes.WithdrawRequestType.GENERAL);
        assertEq(withdrawRequestInstant.shares, 100 * ONE_SHARE);
        assertEq(withdrawRequestInstant.sharesProcessed, 100 * ONE_SHARE);
        assertTrue(withdrawRequestInstant.amountClaimable > 0);
        assertTrue(withdrawRequestInstant.amountClaimed > 0);
        assertEq(uint256(withdrawRequestInstant.state), uint256(DataTypes.RequestProcessingState.FULLY_PROCESSED));

        totalAssets = superloop.totalAssets();
        assertApproxEqAbs(totalAssets, totalAssetsBenchmark, 100);
    }
}
