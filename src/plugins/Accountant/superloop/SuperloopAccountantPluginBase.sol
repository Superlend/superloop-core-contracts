// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IAccountantPlugin} from "../../../interfaces/IAccountantPlugin.sol";
import {SuperloopAccountantPluginStorage} from "../../../core/lib/SuperloopAccountantPluginStorage.sol";

abstract contract SuperloopAccountantPluginBase is Ownable, IAccountantPlugin {
    event UnderlyingVaultUpdated(address indexed oldUnderlyingVault, address indexed newUnderlyingVault);
    event AaveOracleUpdated(address indexed oldAaveOracle, address indexed newAaveOracle);

    constructor(address owner) Ownable(owner) {}

    function setUnderlyingVault(address underlyingVault_) external onlyOwner {
        address oldUnderlyingVault =
            SuperloopAccountantPluginStorage.getSuperloopAccountantPluginStorage().underlyingVault;
        SuperloopAccountantPluginStorage.setUnderlyingVault(underlyingVault_);
        emit UnderlyingVaultUpdated(oldUnderlyingVault, underlyingVault_);
    }

    function setAaveOracle(address aaveOracle_) external onlyOwner {
        address oldAaveOracle = SuperloopAccountantPluginStorage.getSuperloopAccountantPluginStorage().aaveOracle;
        SuperloopAccountantPluginStorage.setAaveOracle(aaveOracle_);
        emit AaveOracleUpdated(oldAaveOracle, aaveOracle_);
    }

    function underlyingVault() external view returns (address) {
        return SuperloopAccountantPluginStorage.getSuperloopAccountantPluginStorage().underlyingVault;
    }

    function aaveOracle() external view returns (address) {
        return SuperloopAccountantPluginStorage.getSuperloopAccountantPluginStorage().aaveOracle;
    }
}
