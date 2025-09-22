// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {WithdrawManagerBase} from "./WithdrawManagerBase.sol";
import {WithdrawManagerStorage} from "../lib/WithdrawManagerStorage.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {ISuperloop} from "../../interfaces/ISuperloop.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {Errors} from "../../common/Errors.sol";
import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWithdrawManagerCallbackHandler} from "../../interfaces/IWithdrawManagerCallbackHandler.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {console} from "forge-std/console.sol";

contract WithdrawManager is Initializable, ReentrancyGuardUpgradeable, Context, WithdrawManagerBase {
    event WithdrawRequested(
        address indexed user, uint256 shares, uint256 requestId, DataTypes.WithdrawRequestType requestType
    );
    event WithdrawRequestCancelled(
        uint256 indexed requestId,
        address indexed user,
        uint256 sharesRefunded,
        uint256 assetsClaimed,
        DataTypes.WithdrawRequestType requestType
    );
    event WithdrawRequestClaimed(
        address indexed user,
        uint256 indexed requestId,
        DataTypes.WithdrawRequestType requestType,
        uint256 assetsClaimed
    );

    constructor() {
        _disableInitializers();
    }

    function initialize(address _vault) public initializer {
        __ReentrancyGuard_init();
        __SuperloopWithdrawManager_init(_vault);
    }

    function __SuperloopWithdrawManager_init(address _vault) internal onlyInitializing {
        address asset = ISuperloop(_vault).asset();
        uint8 decimalOffset = ISuperloop(_vault).decimals() - IERC20Metadata(asset).decimals();

        WithdrawManagerStorage.setVault(_vault);
        WithdrawManagerStorage.setAsset(asset);
        WithdrawManagerStorage.setDecimalOffset(decimalOffset);
        WithdrawManagerStorage.setNextWithdrawRequestId(DataTypes.WithdrawRequestType.GENERAL);
        WithdrawManagerStorage.setNextWithdrawRequestId(DataTypes.WithdrawRequestType.INSTANT);
        WithdrawManagerStorage.setNextWithdrawRequestId(DataTypes.WithdrawRequestType.PRIORITY);
        WithdrawManagerStorage.setNextWithdrawRequestId(DataTypes.WithdrawRequestType.DEFERRED);
    }

    function requestWithdraw(uint256 shares, DataTypes.WithdrawRequestType requestType)
        external
        nonReentrant
        whenNotPaused
    {
        ISuperloop(vault()).realizePerformanceFee();

        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        _validateWithdrawRequest($, _msgSender(), shares, requestType);
        _registerWithdrawRequest($, _msgSender(), shares, requestType);

        emit WithdrawRequested(_msgSender(), shares, $.queues[requestType].nextWithdrawRequestId - 1, requestType);
    }

    function cancelWithdrawRequest(uint256 id, DataTypes.WithdrawRequestType requestType)
        external
        nonReentrant
        whenNotPaused
    {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        DataTypes.WithdrawRequestData memory _withdrawRequest = _withdrawRequest(id, requestType);

        _validateCancelWithdrawRequest(_withdrawRequest);
        (uint256 sharesToRefund, uint256 amountToClaim) =
            _handleCancelWithdrawRequest($, id, requestType, _withdrawRequest);

        emit WithdrawRequestCancelled(id, _msgSender(), sharesToRefund, amountToClaim, requestType);
    }

    function withdraw(DataTypes.WithdrawRequestType requestType) external nonReentrant whenNotPaused {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        (uint256 id, DataTypes.WithdrawRequestData memory _withdrawRequest) = _validateWithdraw($, requestType);
        uint256 amountToClaim = _handleWithdraw($, id, _withdrawRequest, requestType);

        emit WithdrawRequestClaimed(_msgSender(), id, requestType, amountToClaim);
    }

    function resolveWithdrawRequests(DataTypes.ResolveWithdrawRequestsData memory data) external onlyVault {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();

        // validations
        _validateResolveWithdrawRequests($, data);

        address vaultCached = $.vault;
        // take a snapshot of the current exchange rate
        DataTypes.ExchangeRateSnapshot memory snapshot = _createExchangeRateSnapshot(vaultCached, $.vaultDecimalOffset);

        // encode the data to be used in the callback
        bytes memory callbackExecutionData = abi.encode(
            DataTypes.CallbackData({
                asset: vaultCached, // this variable is not needed for withdraws, hence vault address is used
                addressToApprove: address(0),
                amountToApprove: 0,
                executionData: data.callbackExecutionData
            })
        );

        // call 'executeWithdraw' function on the vault
        IWithdrawManagerCallbackHandler(vaultCached).executeWithdraw(data.shares, callbackExecutionData);

        // update the snapshot
        snapshot.totalSupplyAfter = snapshot.totalSupplyBefore - data.shares;
        snapshot.totalAssetsAfter = ISuperloop(vaultCached).totalAssets();

        // calculate how much assets I can get for the shares I am burning
        uint256 totalAssetsToClaim = _calculateAssetsToClaim(snapshot);

        // decrease the  call vault
        DataTypes.WithdrawQueue storage queue = $.queues[data.requestType];
        queue.totalPendingWithdraws -= data.shares;
        ISuperloop(vaultCached).burnSharesAndClaimAssets(data.shares, totalAssetsToClaim);

        uint256 sharesBurnt = data.shares;
        uint256 currentId = queue.resolutionIdPointer;
        while (sharesBurnt > 0) {
            DataTypes.WithdrawRequestData memory currentRequest = _withdrawRequest(currentId, data.requestType);
            if (
                currentRequest.state == DataTypes.RequestProcessingState.CANCELLED
                    || currentRequest.state == DataTypes.RequestProcessingState.PARTIALLY_CANCELLED
            ) {
                unchecked {
                    ++currentId;
                }
                continue;
            }

            uint256 sharesAvailableInCurrentRequest = currentRequest.shares - currentRequest.sharesProcessed;
            uint256 sharesToBurnInCurrentRequest =
                sharesBurnt > sharesAvailableInCurrentRequest ? sharesAvailableInCurrentRequest : sharesBurnt;

            uint256 assetsToClaim =
                Math.mulDiv(sharesToBurnInCurrentRequest, totalAssetsToClaim, data.shares, Math.Rounding.Floor);
            queue.withdrawRequest[currentId].amountClaimable = currentRequest.amountClaimable + assetsToClaim;

            sharesBurnt -= sharesToBurnInCurrentRequest;

            if (currentRequest.sharesProcessed + sharesToBurnInCurrentRequest != currentRequest.shares) {
                queue.withdrawRequest[currentId].state = DataTypes.RequestProcessingState.PARTIALLY_PROCESSED;
                queue.withdrawRequest[currentId].sharesProcessed =
                    currentRequest.sharesProcessed + sharesToBurnInCurrentRequest;
            } else {
                unchecked {
                    ++currentId;
                }
            }
        }

        queue.resolutionIdPointer = currentId;
    }

    function _validateCancelWithdrawRequest(DataTypes.WithdrawRequestData memory _withdrawRequest) internal view {
        bool doesExist = _withdrawRequest.shares > 0;
        if (!doesExist) revert(Errors.WITHDRAW_REQUEST_NOT_FOUND);

        bool isCancelled = _withdrawRequest.state == DataTypes.RequestProcessingState.CANCELLED
            || _withdrawRequest.state == DataTypes.RequestProcessingState.PARTIALLY_CANCELLED;
        if (isCancelled) revert(Errors.INVALID_WITHDRAW_REQUEST_STATE);

        bool isProcessed = _withdrawRequest.state == DataTypes.RequestProcessingState.FULLY_PROCESSED;
        if (isProcessed) revert(Errors.INVALID_WITHDRAW_REQUEST_STATE);

        require(_withdrawRequest.user == _msgSender(), Errors.CALLER_NOT_WITHDRAW_REQUEST_OWNER);
    }

    function _validateWithdrawRequest(
        WithdrawManagerStorage.WithdrawManagerState storage $,
        address user,
        uint256 shares,
        DataTypes.WithdrawRequestType requestType
    ) internal view {
        require(shares > 0, Errors.INVALID_SHARES_AMOUNT);

        // expected withdraw amount > 0
        uint256 expectedWithdrawAmount = ISuperloop(vault()).convertToAssets(shares);
        require(expectedWithdrawAmount > 0, Errors.INVALID_AMOUNT);

        uint256 id = $.queues[requestType].userWithdrawRequestId[user];
        DataTypes.WithdrawRequestData memory _withdrawRequest = _withdrawRequest(id, requestType);

        if (id != 0) {
            // should not have a pending request
            bool isPending = _withdrawRequest.state == DataTypes.RequestProcessingState.UNPROCESSED;
            bool isUnderProcess = _withdrawRequest.state == DataTypes.RequestProcessingState.PARTIALLY_PROCESSED;
            if (isPending || isUnderProcess) {
                revert(Errors.WITHDRAW_REQUEST_ACTIVE);
            }

            // should not have an unclaimed request
            bool isUnclaimed = _withdrawRequest.amountClaimable > 0;
            if (isUnclaimed) {
                revert(Errors.WITHDRAW_REQUEST_UNCLAIMED);
            }
        }
    }

    function _validateWithdraw(
        WithdrawManagerStorage.WithdrawManagerState storage $,
        DataTypes.WithdrawRequestType requestType
    ) internal view returns (uint256, DataTypes.WithdrawRequestData memory) {
        uint256 id = $.queues[requestType].userWithdrawRequestId[_msgSender()];
        require(id > 0, Errors.WITHDRAW_REQUEST_NOT_FOUND);
        DataTypes.WithdrawRequestData memory _withdrawRequest = _withdrawRequest(id, requestType);
        require(_withdrawRequest.user == _msgSender(), Errors.CALLER_NOT_WITHDRAW_REQUEST_OWNER);
        bool isClaimable = _withdrawRequest.amountClaimable > 0;
        bool isProcessed = _withdrawRequest.state == DataTypes.RequestProcessingState.FULLY_PROCESSED;
        bool isPending = _withdrawRequest.state == DataTypes.RequestProcessingState.UNPROCESSED;

        if (!isClaimable) {
            if (isProcessed) {
                revert(Errors.WITHDRAW_REQUEST_ALREADY_CLAIMED);
            } else if (isPending) {
                revert(Errors.WITHDRAW_REQUEST_ACTIVE);
            } else {
                revert(Errors.CANNOT_CLAIM_ZERO_AMOUNT); // not handling cancelled states because when requets are cancelled, they are automatically refunded, hence claim amount = 0
            }
        }

        return (id, _withdrawRequest);
    }

    function _validateResolveWithdrawRequests(
        WithdrawManagerStorage.WithdrawManagerState storage $,
        DataTypes.ResolveWithdrawRequestsData memory data
    ) internal view {
        require(data.shares > 0, Errors.INVALID_SHARES_AMOUNT);
        require(data.shares <= $.queues[data.requestType].totalPendingWithdraws, Errors.INVALID_SHARES_AMOUNT);
    }

    function _handleWithdraw(
        WithdrawManagerStorage.WithdrawManagerState storage $,
        uint256 id,
        DataTypes.WithdrawRequestData memory _withdrawRequest,
        DataTypes.WithdrawRequestType requestType
    ) internal returns (uint256) {
        uint256 amountToClaim = _withdrawRequest.amountClaimable;

        // State changes
        DataTypes.WithdrawQueue storage queue = $.queues[requestType];
        queue.withdrawRequest[id].amountClaimable = 0;
        queue.withdrawRequest[id].amountClaimed += amountToClaim;

        // send tokens
        if (amountToClaim > 0) {
            SafeERC20.safeTransfer(IERC20($.asset), _withdrawRequest.user, amountToClaim);
        }

        return amountToClaim;
    }

    function _registerWithdrawRequest(
        WithdrawManagerStorage.WithdrawManagerState storage $,
        address user,
        uint256 shares,
        DataTypes.WithdrawRequestType requestType
    ) internal {
        SafeERC20.safeTransferFrom(IERC20($.vault), user, address(this), shares);

        DataTypes.WithdrawQueue storage queue = $.queues[requestType];
        uint256 id = queue.nextWithdrawRequestId;
        WithdrawManagerStorage.setWithdrawRequest(
            requestType, id, shares, 0, 0, 0, user, DataTypes.RequestProcessingState.UNPROCESSED
        );
        WithdrawManagerStorage.setUserWithdrawRequest(requestType, user, id);
        WithdrawManagerStorage.setNextWithdrawRequestId(requestType);
        WithdrawManagerStorage.setTotalPendingWithdraws(requestType, queue.totalPendingWithdraws + shares);
    }

    function _handleCancelWithdrawRequest(
        WithdrawManagerStorage.WithdrawManagerState storage $,
        uint256 id,
        DataTypes.WithdrawRequestType requestType,
        DataTypes.WithdrawRequestData memory _withdrawRequest
    ) internal returns (uint256, uint256) {
        uint256 shares = _withdrawRequest.shares;
        uint256 sharesProcessed = _withdrawRequest.sharesProcessed;
        uint256 sharesToRefund = shares - sharesProcessed;
        uint256 amountToClaim = _withdrawRequest.amountClaimable;

        // State changes
        DataTypes.WithdrawQueue storage queue = $.queues[requestType];
        WithdrawManagerStorage.setUserWithdrawRequest(requestType, _withdrawRequest.user, 0);
        WithdrawManagerStorage.setTotalPendingWithdraws(requestType, queue.totalPendingWithdraws - sharesToRefund);
        queue.withdrawRequest[id].state = sharesToRefund == shares
            ? DataTypes.RequestProcessingState.CANCELLED
            : DataTypes.RequestProcessingState.PARTIALLY_CANCELLED;
        queue.withdrawRequest[id].amountClaimable = 0;
        queue.withdrawRequest[id].amountClaimed += amountToClaim;

        // Send the shares and tokens back
        if (sharesToRefund > 0) {
            SafeERC20.safeTransfer(IERC20($.vault), _withdrawRequest.user, sharesToRefund);
        }
        if (amountToClaim > 0) {
            SafeERC20.safeTransfer(IERC20($.asset), _withdrawRequest.user, amountToClaim);
        }

        return (sharesToRefund, amountToClaim);
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

    function _calculateAssetsToClaim(DataTypes.ExchangeRateSnapshot memory snapshot) internal pure returns (uint256) {
        uint256 totalAssetsAfterExpected = Math.mulDiv(
            snapshot.totalAssetsBefore, snapshot.totalSupplyAfter, snapshot.totalSupplyBefore, Math.Rounding.Floor
        );
        uint256 totalAssetsToClaim = snapshot.totalAssetsAfter - totalAssetsAfterExpected; // not adding underflow check because even at 100% slippage, the total assets to claim will be positive
        return totalAssetsToClaim;
    }

    modifier onlyVault() {
        _onlyVault();
        _;
    }

    function _onlyVault() internal view {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        require(_msgSender() == $.vault, Errors.CALLER_NOT_VAULT);
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    function _requireNotPaused() internal view {
        require(!ISuperloop(vault()).paused(), Errors.VAULT_PAUSED);
    }
}
