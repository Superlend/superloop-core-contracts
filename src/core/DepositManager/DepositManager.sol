// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {DepositManagerBase} from "./DepositManagerBase.sol";
import {DepositManagerStorage} from "../lib/DepositManagerStorage.sol";
import {ISuperloop} from "../../interfaces/ISuperloop.sol";
import {Errors} from "../../common/Errors.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {IDepositManagerCallbackHandler} from "../../interfaces/IDepositManagerCallbackHandler.sol";

contract DepositManager is Initializable, ReentrancyGuardUpgradeable, Context, DepositManagerBase {
    event DepositRequested(address indexed user, uint256 amount, uint256 requestId);
    event DepositRequestCancelled(uint256 indexed requestId, address indexed user, uint256 amountRefunded);

    constructor() {
        _disableInitializers();
    }

    function initialize(address _vault) public initializer {
        __ReentrancyGuard_init();
        __SuperloopDepositManager_init(_vault);
    }

    function __SuperloopDepositManager_init(address _vault) internal onlyInitializing {
        address asset = ISuperloop(_vault).asset();
        uint8 decimalOffset = ISuperloop(_vault).decimals() - IERC20Metadata(asset).decimals();

        DepositManagerStorage.setVault(_vault);
        DepositManagerStorage.setAsset(asset);
        DepositManagerStorage.setDecimalOffset(decimalOffset);
        DepositManagerStorage.setNextDepositRequestId();
    }

    function requestDeposit(uint256 amount, address onBehalfOf) external nonReentrant {
        ISuperloop(vault()).realizePerformanceFee();

        DepositManagerStorage.DepositManagerState storage $ = DepositManagerStorage.getDepositManagerStorage();
        address userCached = onBehalfOf == address(0) ? _msgSender() : onBehalfOf;
        _validateWithdrawRequest($, amount, userCached);
        _registerDepositRequest($, amount, userCached, _msgSender());

        emit DepositRequested(userCached, amount, $.nextDepositRequestId - 1);
    }

    function cancelDepositRequest(uint256 id) external nonReentrant {
        DepositManagerStorage.DepositManagerState storage $ = DepositManagerStorage.getDepositManagerStorage();
        _validateCancelDepositRequest($, id);

        // handle cancel deposit request
        uint256 amountRefunded = _handleCancelDepositRequest($, id);

        // emit event
        emit DepositRequestCancelled(id, _msgSender(), amountRefunded);
    }

    function resolveDepositRequests(DataTypes.ResolveDepositRequestsData memory data) external onlyVault {
        DepositManagerStorage.DepositManagerState storage $ = DepositManagerStorage.getDepositManagerStorage();

        // validations
        _validateResolveDepositRequests($, data);

        address vaultCached = $.vault;
        // take a snapshot of the current exchange rate
        DataTypes.ExchangeRateSnapshot memory snapshot = _createExchangeRateSnapshot(vaultCached, $.vaultDecimalOffset);

        // encode the data to be used in the callback
        bytes memory callbackExecutionData = abi.encode(
            DataTypes.CallbackData({
                asset: data.asset,
                addressToApprove: address(0),
                amountToApprove: 0,
                executionData: data.callbackExecutionData
            })
        );

        // transfer the assets to the vault
        SafeERC20.safeTransfer(IERC20(data.asset), vaultCached, data.amount);

        // call 'executeDeposit' function on the vault
        IDepositManagerCallbackHandler(vaultCached).executeDeposit(data.amount, callbackExecutionData);

        // update the snapshot
        snapshot.totalAssetsAfter = ISuperloop(vaultCached).totalAssets() + 1;

        // calculate shares such that the exchange rate is not updated
        uint256 totalNewSharesToMint = _calculateSharesToMint(snapshot, $.vaultDecimalOffset);

        // calculate the share value of each of the deposit request that is getting resolved
        // go from current resolutionIdPointer => until assets are over
        uint256 amountToIngest = data.amount;
        uint256 currentId = $.resolutionIdPointer;
        while (amountToIngest > 0) {
            DataTypes.DepositRequestData memory currentRequest = $.depositRequest[currentId];
            uint256 amountAvailableInCurrentRequest = currentRequest.amount - currentRequest.amountProcessed;
            uint256 amountToIngestInCurrentRequest =
                amountToIngest > amountAvailableInCurrentRequest ? amountAvailableInCurrentRequest : amountToIngest;

            uint256 sharesToMint =
                Math.mulDiv(amountToIngestInCurrentRequest, totalNewSharesToMint, data.amount, Math.Rounding.Floor);

            if (sharesToMint != 0) {
                ISuperloop(vaultCached).mintShares(currentRequest.user, sharesToMint);
            }

            amountToIngest -= amountToIngestInCurrentRequest;
            if (currentRequest.amountProcessed + amountToIngestInCurrentRequest != currentRequest.amount) {
                $.depositRequest[currentId].state = DataTypes.DepositRequestProcessingState.PARTIALLY_PROCESSED;
                $.depositRequest[currentId].amountProcessed += amountToIngestInCurrentRequest;
            } else {
                unchecked {
                    ++currentId;
                }
            }
        }

        $.resolutionIdPointer = currentId;
        $.totalPendingDeposits -= data.amount;
    }

    function _validateWithdrawRequest(DepositManagerStorage.DepositManagerState storage $, uint256 amount, address user)
        internal
        view
    {
        // 1. supply cap
        // 2. Non zero amount
        // 3. Non zero share amount based on current exchange rate value
        // 4. User has no active deposit request

        require(amount > 0, Errors.INVALID_AMOUNT);
        uint256 allPendingDeposits = $.totalPendingDeposits + amount;

        address vaultCached = vault();

        uint256 supplyCap = ISuperloop(vaultCached).maxDeposit(address(0));
        require(allPendingDeposits <= supplyCap, Errors.SUPPLY_CAP_EXCEEDED);

        uint256 expectedShares = ISuperloop(vaultCached).convertToShares(amount);
        require(expectedShares > 0, Errors.INVALID_SHARES_AMOUNT);

        uint256 id = $.userDepositRequestId[user];
        DataTypes.DepositRequestData memory _depositRequest = $.depositRequest[id];
        if (id != 0) {
            bool isPending =
                id > $.resolutionIdPointer && _depositRequest.state != DataTypes.DepositRequestProcessingState.CANCELLED;
            bool isUnderProcess =
                id == $.resolutionIdPointer && _depositRequest.amount != _depositRequest.amountProcessed;

            if (isPending || isUnderProcess) {
                revert(Errors.DEPOSIT_REQUEST_ACTIVE);
            }
        }
    }

    function _registerDepositRequest(
        DepositManagerStorage.DepositManagerState storage $,
        uint256 amount,
        address user,
        address sender
    ) internal {
        SafeERC20.safeTransferFrom(IERC20($.asset), sender, address(this), amount);

        uint256 id = $.nextDepositRequestId;

        DepositManagerStorage.setDepositRequest(
            id, amount, 0, user, DataTypes.DepositRequestProcessingState.UNPROCESSED
        );
        DepositManagerStorage.setUserDepositRequest(user, id);
        DepositManagerStorage.setNextDepositRequestId();
        DepositManagerStorage.setTotalPendingDeposits($.totalPendingDeposits + amount);
    }

    function _validateCancelDepositRequest(DepositManagerStorage.DepositManagerState storage $, uint256 id)
        internal
        view
    {
        // validations
        // 1. request should not be processed already
        // 2. reques should not be cancelled already
        // 3. request can be partially cancelled
        DataTypes.DepositRequestData memory _depositRequest = $.depositRequest[id];
        uint256 resolutionPointer = $.resolutionIdPointer;

        bool doesExist = _depositRequest.amount > 0;
        if (!doesExist) revert(Errors.DEPOSIT_REQUEST_NOT_FOUND);

        bool isCancelled = _depositRequest.state == DataTypes.DepositRequestProcessingState.CANCELLED
            || _depositRequest.state == DataTypes.DepositRequestProcessingState.PARTIALLY_CANCELLED;
        if (isCancelled) revert(Errors.DEPOSIT_REQUEST_ALREADY_CANCELLED);

        bool isProcessed = id < resolutionPointer
            || (id == resolutionPointer && _depositRequest.amountProcessed == _depositRequest.amount);

        if (isProcessed) revert(Errors.DEPOSIT_REQUEST_ALREADY_PROCESSED);

        require(_depositRequest.user == _msgSender(), Errors.CALLER_NOT_DEPOSIT_REQUEST_OWNER);
    }

    function _handleCancelDepositRequest(DepositManagerStorage.DepositManagerState storage $, uint256 id)
        internal
        returns (uint256)
    {
        uint256 amount = $.depositRequest[id].amount;
        uint256 amountProcessed = $.depositRequest[id].amountProcessed;
        uint256 amountToRefund = amount - amountProcessed;

        $.depositRequest[id].state = amountToRefund == amount
            ? DataTypes.DepositRequestProcessingState.CANCELLED
            : DataTypes.DepositRequestProcessingState.PARTIALLY_CANCELLED;
        DepositManagerStorage.setUserDepositRequest($.depositRequest[id].user, 0);
        $.totalPendingDeposits -= amountToRefund;

        SafeERC20.safeTransfer(IERC20($.asset), $.depositRequest[id].user, amountToRefund);

        return amountToRefund;
    }

    function _validateResolveDepositRequests(
        DepositManagerStorage.DepositManagerState storage $,
        DataTypes.ResolveDepositRequestsData memory data
    ) internal view {
        require(data.amount > 0 && data.amount <= $.totalPendingDeposits, Errors.INVALID_AMOUNT);
        require(data.asset == $.asset, Errors.INVALID_ASSET);
    }

    function _createExchangeRateSnapshot(address vault, uint8 decimalOffset)
        internal
        view
        returns (DataTypes.ExchangeRateSnapshot memory)
    {
        uint256 totalSupplyBefore = ISuperloop(vault).totalSupply() + 10 ** decimalOffset;
        uint256 totalAssetsBefore = ISuperloop(vault).totalAssets() + 1;
        return DataTypes.ExchangeRateSnapshot({
            totalSupplyBefore: totalSupplyBefore,
            totalSupplyAfter: 0,
            totalAssetsBefore: totalAssetsBefore,
            totalAssetsAfter: 0
        });
    }

    function _calculateSharesToMint(DataTypes.ExchangeRateSnapshot memory snapshot, uint8 decimalOffset)
        internal
        pure
        returns (uint256)
    {
        uint256 totalSupplyAfter = Math.mulDiv(
            snapshot.totalSupplyBefore, snapshot.totalAssetsAfter, snapshot.totalAssetsBefore, Math.Rounding.Floor
        );
        uint256 totalNewSharesToMint = (totalSupplyAfter + 10 ** decimalOffset) - snapshot.totalSupplyBefore;

        return totalNewSharesToMint;
    }

    modifier onlyVault() {
        _onlyVault();
        _;
    }

    function _onlyVault() internal view {
        DepositManagerStorage.DepositManagerState storage $ = DepositManagerStorage.getDepositManagerStorage();
        require(_msgSender() == $.vault, Errors.CALLER_NOT_VAULT);
    }
}
