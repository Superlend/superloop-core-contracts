// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {DataTypes} from "../../common/DataTypes.sol";

library DepositManagerStorage {
    struct DepositManagerState {
        address vault;
        address asset;
        uint8 vaultDecimalOffset;
        uint256 nextDepositRequestId;
        uint256 resolutionIdPointer;
        uint256 totalPendingDeposits;
        mapping(uint256 => DataTypes.DepositRequestData) depositRequest;
        mapping(address => uint256) userDepositRequestId;
    }

    /**
     * @dev Storage location constant for the withdraw manager storage.
     * Computed using: keccak256(abi.encode(uint256(keccak256("superloop.storage.DepositManager")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant DepositManagerStorageLocation =
        0x988ac3176da2ebf6d8080874e04b39631deefbc5a917a8db625eae5851a39900;

    function getDepositManagerStorage() internal pure returns (DepositManagerState storage $) {
        assembly {
            $.slot := DepositManagerStorageLocation
        }
    }

    function setDepositRequest(
        uint256 id,
        uint256 amount,
        uint256 amountProcessed,
        address user,
        DataTypes.RequestProcessingState state
    ) internal {
        DepositManagerState storage $ = getDepositManagerStorage();

        $.depositRequest[id] = DataTypes.DepositRequestData(amount, amountProcessed, user, state);
    }

    function setNextDepositRequestId() internal {
        DepositManagerState storage $ = getDepositManagerStorage();
        $.nextDepositRequestId = $.nextDepositRequestId + 1;
    }

    function setUserDepositRequest(address user, uint256 id) internal {
        DepositManagerState storage $ = getDepositManagerStorage();
        $.userDepositRequestId[user] = id;
    }

    function setVault(address __vault) internal {
        DepositManagerState storage $ = getDepositManagerStorage();
        $.vault = __vault;
    }

    function setAsset(address __asset) internal {
        DepositManagerState storage $ = getDepositManagerStorage();
        $.asset = __asset;
    }

    function setDecimalOffset(uint8 __decimalOffset) internal {
        DepositManagerState storage $ = getDepositManagerStorage();
        $.vaultDecimalOffset = __decimalOffset;
    }

    function setTotalPendingDeposits(uint256 __totalPendingDeposits) internal {
        DepositManagerState storage $ = getDepositManagerStorage();
        $.totalPendingDeposits = __totalPendingDeposits;
    }

    function setResolutionIdPointer(uint256 __resolutionIdPointer) internal {
        DepositManagerState storage $ = getDepositManagerStorage();
        $.resolutionIdPointer = __resolutionIdPointer;
    }
}
