// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DataTypes} from "../../common/DataTypes.sol";
import {SuperloopActionModule} from "./SuperloopActionModule.sol";
import {ISuperloop} from "../../interfaces/ISuperloop.sol";
import {IDepositManager} from "../../interfaces/IDepositManager.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract SuperloopDepositModule is SuperloopActionModule {
    /**
     * @notice Emitted when a deposit operation is executed
     * @param vault The address of the vault
     * @param amount The amount of the asset deposited
     * @param user The address of the user who deposited
     */
    event DepositExecuted(address indexed vault, uint256 amount, address indexed user);

    /**
     * @notice Emitted when a deposit request is cancelled
     * @param requestId The id of the deposit request cancelled
     * @param user The address of the user who cancelled the deposit request
     * @param amountRefunded The amount of the asset refunded
     * @param sharesMinted The amount of shares minted
     */
    event DepositRequestCancelled(
        uint256 indexed requestId, address indexed user, uint256 amountRefunded, uint256 sharesMinted
    );

    constructor(address vaultAddress) SuperloopActionModule(vaultAddress) {}

    /**
     * @notice Executes a deposit operation on Superloop
     * @param params The parameters for the deposit operation
     */
    function execute(DataTypes.SuperloopDepositParams memory params) external onlyExecutionContext {
        uint256 amount =
            params.amount == type(uint256).max ? IERC20(params.asset).balanceOf(address(this)) : params.amount;

        if (amount != 0) {
            // get the deposit manager
            address depositManager = ISuperloop(vault).depositManagerModule();

            // approve the asset
            IERC20(params.asset).approve(address(depositManager), amount);

            // deposit the asset
            IDepositManager(depositManager).requestDeposit(amount, address(this));

            emit DepositExecuted(vault, amount, address(this));
        }
    }

    /**
     * @notice Cancels a pending deposit request and refunds assets
     * @param requestId The id of the deposit request to cancel
     */
    function exit(uint256 requestId) external onlyExecutionContext {
        // get the deposit request
        address depositManager = ISuperloop(vault).depositManagerModule();
        DataTypes.DepositRequestData memory depositRequest = IDepositManager(depositManager).depositRequest(requestId);

        // if deposit request is a state where it can be cancelled
        if (
            depositRequest.state == DataTypes.RequestProcessingState.UNPROCESSED
                || depositRequest.state == DataTypes.RequestProcessingState.PARTIALLY_PROCESSED
        ) {
            // cancel the deposit request
            IDepositManager(depositManager).cancelDepositRequest(requestId);

            // get the amount refunded
            uint256 amountRefunded = depositRequest.amount - depositRequest.amountProcessed;

            // emit the event
            emit DepositRequestCancelled(requestId, depositRequest.user, amountRefunded, depositRequest.sharesMinted);
        }
    }
}
