// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {WithdrawManagerStorage} from "./WithdrawManagerStorage.sol";
import {Errors} from "../../common/Errors.sol";
import {DataTypes} from "../../common/DataTypes.sol";

contract WithdrawManager is
    WithdrawManagerStorage,
    Initializable,
    ReentrancyGuardUpgradeable
{
    constructor() {
        _disableInitializers();
    }

    function initialize(address _vault) public initializer {
        __ReentrancyGuard_init_unchained();
        __SuperloopWithdrawManager_init(_vault);
    }

    function __SuperloopWithdrawManager_init(
        address _vault
    ) internal onlyInitializing {
        _setVault(_vault);
        _setNextWithdrawRequestId(1);
    }

    function requestWithdraw(uint256 shares) external {
        _validateWithdrawRequest(msg.sender, shares);
        // TODO : Handle fees
        _registerWithdrawRequest(msg.sender, shares);
    }

    function releaseWithdrawRequests(
        uint256 startId,
        uint256 endId,
        uint256 shares
    ) external onlyVault {
        _validateReleaseWithdrawRequests(startId, endId);
        _handleReleaseWithdrawRequests(startId, endId, shares);
    }

    function markWithdrawRequestProcessed(uint256 id) external onlyVault {
        _validateWithdrawRequestProcessed(id);
        _handleWithdrawRequestProcesessed(id);
    }

    function getWithdrawRequestState(
        uint256 id
    ) public view returns (DataTypes.WithdrawRequestState) {
        DataTypes.WithdrawRequestData memory withdrawRequest = withdrawRequest(
            id
        );
        (uint256 startId, uint256 endId) = withdrawWindow();

        if (withdrawRequest.user == address(0))
            return DataTypes.WithdrawRequestState.NOT_EXIST;

        if (id < startId) return DataTypes.WithdrawRequestState.EXPIRED;

        if (withdrawRequest.processed)
            return DataTypes.WithdrawRequestState.CLAIMED;

        if (id > endId) return DataTypes.WithdrawRequestState.UNPROCESSED;

        return DataTypes.WithdrawRequestState.CLAIMABLE;
    }

    function _validateWithdrawRequest(
        address user,
        uint256 shares
    ) internal view {
        require(shares > 0, Errors.INVALID_AMOUNT);
        uint256 id = userWithdrawRequestId(user);
        (uint256 startId, uint256 endId) = withdrawWindow();
        DataTypes.WithdrawRequestData memory withdrawRequest = withdrawRequest(
            id
        );

        if (withdrawRequest.user == user && (id >= startId && id <= endId)) {
            revert(Errors.WITHDRAW_REQUEST_ACTIVE);
        }
    }

    function _validateWithdrawRequestProcessed(uint256 id) internal view {
        require(
            getWithdrawRequestState(id) ==
                DataTypes.WithdrawRequestState.CLAIMABLE,
            Errors.INVALID_WITHDRAW_REQUEST_STATE
        );
    }

    function _validateReleaseWithdrawRequests(
        uint256 _newStartId,
        uint256 _newEndId
    ) internal view {
        (, uint256 endId) = withdrawWindow();
        uint256 withdrawReqId = nextWithdrawRequestId();

        require(_newStartId == endId + 1, Errors.INVALID_WITHDRAW_WINDOW_START);
        require(_newEndId < withdrawReqId, Errors.INVALID_WITHDRAW_WINDO_END);
    }

    function _registerWithdrawRequest(address user, uint256 shares) internal {
        uint256 withdrawReqId = nextWithdrawRequestId();
        _setWithdrawRequest(user, shares, withdrawReqId, false);
        _setUserWithdrawRequest(user, withdrawReqId);
        _setNextWithdrawRequestId(withdrawReqId + 1);
    }

    function _handleReleaseWithdrawRequests(
        uint256 startId,
        uint256 endId,
        uint256 shares
    ) internal {
        _setWithdrawWindowStartId(startId);
        _setWithdrawWindowEndId(endId);
        _setTotalWithdrawableShares(shares);
    }

    function _handleWithdrawRequestProcesessed(uint256 id) internal {
        address user = withdrawRequest(id).user;
        _setUserWithdrawRequest(user, 0);
    }

    modifier onlyVault() {
        _onlyVault();
        _;
    }

    function _onlyVault() internal view {
        require(msg.sender == vault(), Errors.CALLER_NOT_VAULT);
    }
}
