// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DataTypes} from "../../common/DataTypes.sol";
import {SuperloopActionModule} from "./SuperloopActionModule.sol";
import {IWithdrawManager} from "../../interfaces/IWithdrawManager.sol";
import {ISuperloop} from "../../interfaces/ISuperloop.sol";

contract SuperloopWithdrawModule is SuperloopActionModule {
    /**
     * @notice Emitted when a withdraw request is created
     * @param vault The address of the vault
     * @param shares The amount of shares to withdraw
     * @param requestType The type of withdraw request
     */
    event WithdrawRequestCreated(address indexed vault, uint256 shares, DataTypes.WithdrawRequestType requestType);

    /**
     * @notice Emitted when a withdraw request is cancelled
     * @param vault The address of the vault
     * @param requestId The id of the withdraw request
     * @param requestType The type of withdraw request
     */
    event WithdrawRequestCancelled(
        address indexed vault,
        uint256 requestId,
        DataTypes.WithdrawRequestType requestType,
        uint256 sharesRefunded,
        uint256 assetsClaimed
    );

    /**
     * @notice Emitted when a withdraw request is claimed
     * @param vault The address of the vault
     * @param requestId The id of the withdraw request
     * @param requestType The type of withdraw request
     * @param assetsClaimed The amount of assets claimed
     */
    event WithdrawRequestClaimed(
        address indexed vault, uint256 requestId, DataTypes.WithdrawRequestType requestType, uint256 assetsClaimed
    );

    constructor(address vaultAddress) SuperloopActionModule(vaultAddress) {}

    // execute function to create withdraw request
    function execute(DataTypes.SuperloopWithdrawParams memory params) external onlyExecutionContext {
        uint256 shares = params.amount == type(uint256).max ? ISuperloop(vault).balanceOf(address(this)) : params.amount;

        if (shares != 0) {
            // get the withdraw manager
            address withdrawManager = ISuperloop(vault).withdrawManager();

            // approve the shares to withdraw manager
            ISuperloop(vault).approve(address(withdrawManager), shares);

            // create withdraw request
            IWithdrawManager(withdrawManager).requestWithdraw(shares, params.requestType);

            emit WithdrawRequestCreated(vault, shares, params.requestType);
        }
    }

    // exit function to cancel withdraw request
    function exit(DataTypes.SuperloopExitWithdrawParams memory params) external onlyExecutionContext {
        // get the withdraw manager
        address withdrawManager = ISuperloop(vault).withdrawManager();

        DataTypes.WithdrawRequestData memory withdrawRequest =
            IWithdrawManager(withdrawManager).withdrawRequest(params.requestId, params.requestType);

        // if withdraw request is a state where it can be cancelled
        if (
            withdrawRequest.state == DataTypes.RequestProcessingState.UNPROCESSED
                || withdrawRequest.state == DataTypes.RequestProcessingState.PARTIALLY_PROCESSED
        ) {
            // get the shares refunded
            uint256 sharesRefunded = withdrawRequest.shares - withdrawRequest.sharesProcessed;
            // get the assets claimed
            uint256 assetsClaimed = withdrawRequest.amountClaimed + withdrawRequest.amountClaimable;

            // cancel the withdraw request
            IWithdrawManager(withdrawManager).cancelWithdrawRequest(params.requestId, params.requestType);

            emit WithdrawRequestCancelled(vault, params.requestId, params.requestType, sharesRefunded, assetsClaimed);
        }
    }

    // resolve function to claim processed withdraw request
    function resolve(DataTypes.SuperloopExitWithdrawParams memory params) external onlyExecutionContext {
        // get the withdraw manager
        address withdrawManager = ISuperloop(vault).withdrawManager();

        // get the withdraw request
        DataTypes.WithdrawRequestData memory withdrawRequest =
            IWithdrawManager(withdrawManager).withdrawRequest(params.requestId, params.requestType);

        if (
            withdrawRequest.state == DataTypes.RequestProcessingState.FULLY_PROCESSED
                || withdrawRequest.state == DataTypes.RequestProcessingState.PARTIALLY_PROCESSED
        ) {
            // claim the withdraw request
            IWithdrawManager(withdrawManager).withdraw(params.requestType);

            // get the assets claimed
            uint256 assetsClaimed = withdrawRequest.amountClaimed + withdrawRequest.amountClaimable;

            emit WithdrawRequestClaimed(vault, params.requestId, params.requestType, assetsClaimed);
        }
    }
}
