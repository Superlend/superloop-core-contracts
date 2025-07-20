// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

library SuperloopStorage {
    uint8 public constant DECIMALS_OFFSET = 2;

    struct SuperloopState {
        uint256 supplyCap;
        address feeManager;
        address withdrawManager;
        address commonPriceOracle;
        address vaultAdmin;
        address treasury;
        uint16 performanceFee; // BPS
        address superloopModuleRegistry;
        mapping(address => uint256) userLastRealizedFeeExchangeRate;
        mapping(address => bool) registeredModules;
    }

    /**
     * @dev Storage location constant for the superloop storage.
     * Computed using: keccak256(abi.encode(uint256(keccak256("superloop.Superloop.state")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant SuperloopStateStorageLocation =
        0xa35af3fd1440912a5a47a30e9b58a4830f4700f48114569c6bb05e8eec37b600;

    function getSuperloopStorage()
        internal
        pure
        returns (SuperloopState storage $)
    {
        assembly {
            $.slot := SuperloopStateStorageLocation
        }
    }

    // setter functions
    function setSupplyCap(uint256 supplyCap_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.supplyCap = supplyCap_;
    }

    function setFeeManager(address feeManager_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.feeManager = feeManager_;
    }

    function setWithdrawManager(address withdrawManager_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.withdrawManager = withdrawManager_;
    }

    function setCommonPriceOracle(address commonPriceOracle_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.commonPriceOracle = commonPriceOracle_;
    }

    function setVaultAdmin(address vaultAdmin_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.vaultAdmin = vaultAdmin_;
    }

    function setTreasury(address treasury_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.treasury = treasury_;
    }

    function setPerformanceFee(uint16 performanceFee_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.performanceFee = performanceFee_;
    }

    function setRegisteredModule(address module_, bool registered_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.registeredModules[module_] = registered_;
    }

    function setUserLastRealizedFeeExchangeRate(
        address user_,
        uint256 lastRealizedFeeExchangeRate_
    ) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.userLastRealizedFeeExchangeRate[user_] = lastRealizedFeeExchangeRate_;
    }

    function setSuperloopModuleRegistry(
        address superloopModuleRegistry_
    ) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.superloopModuleRegistry = superloopModuleRegistry_;
    }
}
