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

        (DataTypes.DepositRequestData memory _depositRequest,) = IDepositManager(
                ISuperloop(environment.externalVault).depositManagerModule()
            ).userDepositRequest(address(superloop));

        assertApproxEqAbs(_depositRequest.amount, depositAmountToProcess, 100);
        assertApproxEqAbs(_depositRequest.amountProcessed, 0, 10);
        assertApproxEqAbs(_depositRequest.sharesMinted, 0, 10);
        assertEq(_depositRequest.user, address(superloop));
        assertEq(uint256(_depositRequest.state), uint256(DataTypes.RequestProcessingState.UNPROCESSED));

        // partially resolve the vault's deposit request => have a partially processed deposit request
        // observe the total assets

        // completely process the vault's deposit request => have a fully processed deposit request
        // observe the total assets

        // donate some USDe to the underlying vault => simulating yield generation
        // observe the total assets

        // make 2 withdraw requests for the vault
        // observe the total assets

        // process one and cancel the other withdraw request
        // observe the total assets
    }
}
