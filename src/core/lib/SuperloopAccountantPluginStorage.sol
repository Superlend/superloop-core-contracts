// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

library SuperloopAccountantPluginStorage {
    struct SuperloopAccountantPluginState {
        address underlyingVault;
        address aaveOracle;
    }

    /**
     * @dev Storage location constant for the superloop accountant plugin storage.
     * Computed using: keccak256(abi.encode(uint256(keccak256("superloop.superloopAccountantPlugin.storage")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant SuperloopAccountantPluginStateStorageLocation =
        0x7799a0a358bbb7ebee37d1eda3bd8357d74d8f07761906714097d3fbd30aea00;

    function getSuperloopAccountantPluginStorage() internal pure returns (SuperloopAccountantPluginState storage $) {
        assembly {
            $.slot := SuperloopAccountantPluginStateStorageLocation
        }
    }

    function setUnderlyingVault(address underlyingVault_) internal {
        SuperloopAccountantPluginState storage $ = getSuperloopAccountantPluginStorage();
        $.underlyingVault = underlyingVault_;
    }

    function setAaveOracle(address aaveOracle_) internal {
        SuperloopAccountantPluginState storage $ = getSuperloopAccountantPluginStorage();
        $.aaveOracle = aaveOracle_;
    }
}
