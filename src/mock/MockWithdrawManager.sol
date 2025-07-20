// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Errors} from "../common/Errors.sol";
import {DataTypes} from "../common/DataTypes.sol";
import {Storages} from "../common/Storages.sol";

contract MockWithdrawManager {
    // // Mock-specific storage
    // mapping(uint256 => uint256) private withdrawRequestTimestamps;
    // uint256 private constant WITHDRAW_DELAY = 30 minutes;

    // constructor() {
    //     // _disableInitializers();
    // }

    function initialize(address _vault) public {
        // __ReentrancyGuard_init();
        // __SuperloopWithdrawManager_init(_vault);
    }

    // function __SuperloopWithdrawManager_init(address _vault) internal onlyInitializing {
    //     _setVault(_vault);
    //     _setAsset(IERC4626(_vault).asset());
    //     _setNextWithdrawRequestId();
    //     // TODO: set fee manager
    // }

    // function requestWithdraw(uint256 shares) external override {
    //     Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
    //     _validateWithdrawRequest($, _msgSender(), shares);
    //     // TODO : Handle fees
    //     _registerWithdrawRequest($, _msgSender(), shares);
    // }

    // function cancelWithdrawRequest(uint256 id) external override nonReentrant {
    //     Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
    //     _validateCancelWithdrawRequest($, id);
    //     _handleCancelWithdrawRequest($, id);
    // }

    // // Mock implementation - removed resolveWithdrawRequests logic
    // function resolveWithdrawRequests(uint256 resolvedIdLimit) external override onlyVault {
    //     // Mock implementation - no actual logic needed
    //     // In the mock, withdraw requests become claimable after 30 minutes automatically
    // }

    // function withdraw() external override nonReentrant {
    //     Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
    //     uint256 id = _validateWithdraw($);
    //     _handleWithdraw($, id);
    // }

    // function getWithdrawRequestState(uint256 id) public view override returns (DataTypes.WithdrawRequestState) {
    //     DataTypes.WithdrawRequestData memory withdrawRequest = withdrawRequest(id);

    //     if (withdrawRequest.user == address(0)) {
    //         return DataTypes.WithdrawRequestState.NOT_EXIST;
    //     }

    //     if (withdrawRequest.claimed) {
    //         return DataTypes.WithdrawRequestState.CLAIMED;
    //     }

    //     if (withdrawRequest.cancelled) {
    //         return DataTypes.WithdrawRequestState.CANCELLED;
    //     }

    //     // Check if 30 minutes have passed since the request was made
    //     if (block.timestamp >= withdrawRequestTimestamps[id] + WITHDRAW_DELAY) {
    //         return DataTypes.WithdrawRequestState.CLAIMABLE;
    //     }

    //     return DataTypes.WithdrawRequestState.UNPROCESSED;
    // }

    // function _registerWithdrawRequest(Storages.WithdrawManagerState storage $, address user, uint256 shares) internal {
    //     // Mock: Skip token transfer
    //     SafeERC20.safeTransferFrom(IERC20(vault()), user, address(this), shares);

    //     uint256 withdrawReqId = $.nextWithdrawRequestId;

    //     // Use shares as the amount (mock behavior)
    //     _setWithdrawRequest(user, shares, shares, withdrawReqId, false, false);
    //     _setUserWithdrawRequest(user, withdrawReqId);
    //     _setNextWithdrawRequestId();

    //     // Store the timestamp for the 30-minute delay
    //     withdrawRequestTimestamps[withdrawReqId] = block.timestamp;
    // }

    // // Mock implementation - removed actual resolve logic
    // function _handleResolveWithdrawRequests(Storages.WithdrawManagerState storage $, uint256 resolvedIdLimit)
    //     internal
    // {
    //     // Mock implementation - no actual logic needed
    //     // Withdraw requests become claimable after 30 minutes automatically
    // }

    // function _handleWithdraw(Storages.WithdrawManagerState storage $, uint256 id) internal {
    //     DataTypes.WithdrawRequestData memory withdrawRequest = $.withdrawRequest[id];

    //     // Validate that 30 minutes have passed
    //     require(block.timestamp >= withdrawRequestTimestamps[id] + WITHDRAW_DELAY, "Withdraw request not yet claimable");

    //     $.withdrawRequest[id].claimed = true;
    //     _setUserWithdrawRequest(withdrawRequest.user, 0);

    //     // Mock: Skip token transfer
    //     // SafeERC20.safeTransfer(IERC20(asset()), _msgSender(), withdrawRequest.amount);
    // }

    // function _handleCancelWithdrawRequest(Storages.WithdrawManagerState storage $, uint256 id) internal {
    //     DataTypes.WithdrawRequestData memory withdrawRequest = $.withdrawRequest[id];

    //     $.withdrawRequest[id].cancelled = true;
    //     _setUserWithdrawRequest(withdrawRequest.user, 0);

    //     // Mock: Skip token transfer
    //     SafeERC20.safeTransfer(IERC20(vault()), withdrawRequest.user, withdrawRequest.shares);
    // }

    // // Override the validator to allow withdraws after 30 minutes instead of requiring resolution
    // function _validateWithdraw(Storages.WithdrawManagerState storage $) internal view override returns (uint256) {
    //     uint256 id = $.userWithdrawRequestId[_msgSender()];
    //     require(id > 0, Errors.WITHDRAW_REQUEST_NOT_FOUND);
    //     DataTypes.WithdrawRequestData memory withdrawRequest = $.withdrawRequest[id];

    //     require(
    //         withdrawRequest.user == _msgSender() && withdrawRequest.claimed == false,
    //         Errors.WITHDRAW_REQUEST_ALREADY_CLAIMED
    //     );

    //     // Check if 30 minutes have passed instead of checking resolution
    //     require(block.timestamp >= withdrawRequestTimestamps[id] + WITHDRAW_DELAY, "Withdraw request not yet claimable");

    //     return id;
    // }

    // modifier onlyVault() {
    //     _onlyVault();
    //     _;
    // }

    // function _onlyVault() internal view {
    //     require(_msgSender() == vault(), Errors.CALLER_NOT_VAULT);
    // }

    // // Helper function to get the timestamp of a withdraw request
    // function getWithdrawRequestTimestamp(uint256 id) external view returns (uint256) {
    //     return withdrawRequestTimestamps[id];
    // }

    // // Helper function to check if a withdraw request is claimable
    // function isWithdrawRequestClaimable(uint256 id) external view returns (bool) {
    //     return block.timestamp >= withdrawRequestTimestamps[id] + WITHDRAW_DELAY;
    // }
}
