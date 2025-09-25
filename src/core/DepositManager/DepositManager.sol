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

/**
 * @title DepositManager
 * @author Superlend
 * @notice Manages deposit requests for Superloop vaults with queuing and processing capabilities
 * @dev Handles deposit request lifecycle from creation to resolution with exchange rate preservation
 */
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

    function requestDeposit(uint256 amount, address onBehalfOf) external nonReentrant whenNotPaused {
        (DepositManagerCache memory cache, DepositManagerStorage.DepositManagerState storage $) =
            _createDepositManagerCache();
        ISuperloop(cache.vault).realizePerformanceFee();

        // vault, total pending deposit, userdepositrequestId,
        // asset, next deposit request id

        address user = onBehalfOf == address(0) ? _msgSender() : onBehalfOf;
        _validateDepositRequest(cache, $.userDepositRequestId, amount, user);
        _registerDepositRequest(cache, amount, user, _msgSender());

        emit DepositRequested(user, amount, $.nextDepositRequestId - 1);
    }

    function cancelDepositRequest(uint256 id) external nonReentrant whenNotPaused {
        (DepositManagerCache memory cache, DepositManagerStorage.DepositManagerState storage $) =
            _createDepositManagerCache();
        DataTypes.DepositRequestData memory _depositRequestCached = _depositRequest(id);
        _validateCancelDepositRequest(_depositRequestCached);

        // handle cancel deposit request
        uint256 amountRefunded = _handleCancelDepositRequest(cache, $, id, _depositRequestCached);

        // emit event
        emit DepositRequestCancelled(id, _msgSender(), amountRefunded);
    }

    function resolveDepositRequests(DataTypes.ResolveDepositRequestsData memory data) external onlyVault {
        (DepositManagerCache memory cache, DepositManagerStorage.DepositManagerState storage $) =
            _createDepositManagerCache();

        // validations
        _validateResolveDepositRequests(cache, data);

        // take a snapshot of the current exchange rate
        DataTypes.ExchangeRateSnapshot memory snapshot =
            _createExchangeRateSnapshot(cache.vault, cache.vaultDecimalOffset);

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
        SafeERC20.safeTransfer(IERC20(data.asset), cache.vault, data.amount);

        // call 'executeDeposit' function on the vault
        IDepositManagerCallbackHandler(cache.vault).executeDeposit(data.amount, callbackExecutionData);

        // update the snapshot
        snapshot.totalAssetsAfter = ISuperloop(cache.vault).totalAssets() + 1;

        // calculate shares such that the exchange rate is not updated
        uint256 totalNewSharesToMint = _calculateSharesToMint(snapshot, cache.vaultDecimalOffset);

        // decrease the total pending deposits before minting shares
        $.totalPendingDeposits -= data.amount;

        // calculate the share value of each of the deposit request that is getting resolved
        // go from current resolutionIdPointer => until assets are over
        uint256 amountToIngest = data.amount;
        uint256 currentId = cache.resolutionIdPointer;

        while (amountToIngest > 0) {
            DataTypes.DepositRequestData memory currentRequest = _depositRequest(currentId);
            if (
                currentRequest.state == DataTypes.RequestProcessingState.CANCELLED
                    || currentRequest.state == DataTypes.RequestProcessingState.PARTIALLY_CANCELLED
            ) {
                unchecked {
                    ++currentId;
                }
                continue;
            }

            uint256 amountAvailableInCurrentRequest = currentRequest.amount - currentRequest.amountProcessed;
            uint256 amountToIngestInCurrentRequest =
                amountToIngest > amountAvailableInCurrentRequest ? amountAvailableInCurrentRequest : amountToIngest;

            uint256 sharesToMint =
                Math.mulDiv(amountToIngestInCurrentRequest, totalNewSharesToMint, data.amount, Math.Rounding.Floor);

            if (sharesToMint != 0) {
                $.depositRequest[currentId].sharesMinted = currentRequest.sharesMinted + sharesToMint;
                ISuperloop(cache.vault).mintShares(currentRequest.user, sharesToMint);
            }

            amountToIngest -= amountToIngestInCurrentRequest;
            if (currentRequest.amountProcessed + amountToIngestInCurrentRequest != currentRequest.amount) {
                $.depositRequest[currentId].state = DataTypes.RequestProcessingState.PARTIALLY_PROCESSED;
                $.depositRequest[currentId].amountProcessed += amountToIngestInCurrentRequest;
            } else {
                unchecked {
                    ++currentId;
                }
            }
        }

        $.resolutionIdPointer = currentId;
    }

    function _validateDepositRequest(
        DepositManagerCache memory cache,
        mapping(address => uint256) storage userDepositRequestId,
        uint256 amount,
        address user
    ) internal view {
        // 1. supply cap
        // 2. Non zero amount
        // 3. Non zero share amount based on current exchange rate value
        // 4. User has no active deposit request

        require(amount > 0, Errors.INVALID_AMOUNT);
        uint256 allPendingDeposits = cache.totalPendingDeposits + amount;

        uint256 supplyCap = ISuperloop(cache.vault).maxDeposit(address(0));
        require(allPendingDeposits <= supplyCap, Errors.SUPPLY_CAP_EXCEEDED);

        uint256 expectedShares = ISuperloop(cache.vault).convertToShares(amount);
        require(expectedShares > 0, Errors.INVALID_SHARES_AMOUNT);

        uint256 id = userDepositRequestId[user];
        DataTypes.DepositRequestData memory _depositRequest = _depositRequest(id);
        if (id != 0) {
            bool isPending = _depositRequest.state == DataTypes.RequestProcessingState.UNPROCESSED;
            bool isUnderProcess = _depositRequest.state == DataTypes.RequestProcessingState.PARTIALLY_PROCESSED;

            if (isPending || isUnderProcess) {
                revert(Errors.DEPOSIT_REQUEST_ACTIVE);
            }
        }
    }

    function _registerDepositRequest(DepositManagerCache memory cache, uint256 amount, address user, address sender)
        internal
    {
        SafeERC20.safeTransferFrom(IERC20(cache.asset), sender, address(this), amount);

        uint256 id = cache.nextDepositRequestId;

        DepositManagerStorage.setDepositRequest(id, amount, 0, 0, user, DataTypes.RequestProcessingState.UNPROCESSED);
        DepositManagerStorage.setUserDepositRequest(user, id);
        DepositManagerStorage.setNextDepositRequestId();
        DepositManagerStorage.setTotalPendingDeposits(cache.totalPendingDeposits + amount);
    }

    function _validateCancelDepositRequest(DataTypes.DepositRequestData memory _depositRequest) internal view {
        bool doesExist = _depositRequest.amount > 0;
        if (!doesExist) revert(Errors.DEPOSIT_REQUEST_NOT_FOUND);

        bool isCancelled = _depositRequest.state == DataTypes.RequestProcessingState.CANCELLED
            || _depositRequest.state == DataTypes.RequestProcessingState.PARTIALLY_CANCELLED;
        if (isCancelled) revert(Errors.DEPOSIT_REQUEST_ALREADY_CANCELLED);

        bool isProcessed = _depositRequest.state == DataTypes.RequestProcessingState.FULLY_PROCESSED;
        if (isProcessed) revert(Errors.DEPOSIT_REQUEST_ALREADY_PROCESSED);

        require(_depositRequest.user == _msgSender(), Errors.CALLER_NOT_DEPOSIT_REQUEST_OWNER);
    }

    function _handleCancelDepositRequest(
        DepositManagerCache memory cache,
        DepositManagerStorage.DepositManagerState storage $,
        uint256 id,
        DataTypes.DepositRequestData memory _depositRequest
    ) internal returns (uint256) {
        uint256 amount = _depositRequest.amount;
        uint256 amountProcessed = _depositRequest.amountProcessed;
        uint256 amountToRefund = amount - amountProcessed;

        DepositManagerStorage.setUserDepositRequest(_depositRequest.user, 0);
        $.depositRequest[id].state = amountToRefund == amount
            ? DataTypes.RequestProcessingState.CANCELLED
            : DataTypes.RequestProcessingState.PARTIALLY_CANCELLED;
        $.totalPendingDeposits -= amountToRefund;

        SafeERC20.safeTransfer(IERC20(cache.asset), _depositRequest.user, amountToRefund);

        return amountToRefund;
    }

    function _validateResolveDepositRequests(
        DepositManagerCache memory cache,
        DataTypes.ResolveDepositRequestsData memory data
    ) internal pure {
        require(data.amount > 0 && data.amount <= cache.totalPendingDeposits, Errors.INVALID_AMOUNT);
        require(data.asset == cache.asset, Errors.INVALID_ASSET);
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
            snapshot.totalSupplyBefore, snapshot.totalAssetsAfter, snapshot.totalAssetsBefore, Math.Rounding.Ceil
        );
        uint256 totalNewSharesToMint = (totalSupplyAfter + 10 ** decimalOffset) - snapshot.totalSupplyBefore;

        return totalNewSharesToMint;
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    modifier onlyVault() {
        _onlyVault();
        _;
    }

    function _onlyVault() internal view {
        DepositManagerStorage.DepositManagerState storage $ = DepositManagerStorage.getDepositManagerStorage();
        require(_msgSender() == $.vault, Errors.CALLER_NOT_VAULT);
    }

    function _requireNotPaused() internal view {
        require(!ISuperloop(vault()).paused(), Errors.VAULT_PAUSED);
    }
}
