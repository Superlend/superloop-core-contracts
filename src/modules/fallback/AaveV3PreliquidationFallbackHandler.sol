// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DataTypes} from "../../common/DataTypes.sol";
import {DataTypes as AaveDataTypes} from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {Errors} from "../../common/Errors.sol";
import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReserveConfiguration} from "aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import {WadRayMath} from "aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

contract AaveV3PreliquidationFallbackHandler is Context {
    // aave  and vault related stuff
    uint256 public constant BPS = 1e4;
    IPoolAddressesProvider public immutable poolAddressesProvider;
    address public immutable vault;
    uint256 public immutable emodeCategory; // preliquidation module is supposed to be used in only one emode category

    // fallback handler related stuff
    address public immutable lendReserve;
    address public immutable borrowReserve;
    uint256 public immutable preLltv;
    uint256 public immutable preCF1;
    uint256 public immutable preCF2;
    uint256 public immutable preIF1;
    uint256 public immutable preIF2;

    constructor(
        address poolAddressesProvider_,
        address vault_,
        DataTypes.AaveV3PreliquidationInitParams memory preLiquidationParams_
    ) {
        vault = vault_;
        poolAddressesProvider = IPoolAddressesProvider(poolAddressesProvider_);
        IPool pool = IPool(IPoolAddressesProvider(poolAddressesProvider_).getPool());
        emodeCategory = pool.getUserEMode(vault_);

        _validatePreLiquidationParams(preLiquidationParams_, pool, emodeCategory);

        lendReserve = preLiquidationParams_.lendReserve;
        borrowReserve = preLiquidationParams_.borrowReserve;

        preLltv = preLiquidationParams_.preLltv;
        preCF1 = preLiquidationParams_.preLCF1;
        preCF2 = preLiquidationParams_.preLCF2;
        preIF1 = preLiquidationParams_.preLIF1;
        preIF2 = preLiquidationParams_.preLIF2;
    }

    function preliquidate(bytes32, DataTypes.CallType, DataTypes.AaveV3PreliquidationParams memory params) public {
        // make sure params.user = vault
        // make sure vault is in the same emode as stored
        // TODO: Implement
    }

    function _validatePreLiquidationParams(
        DataTypes.AaveV3PreliquidationInitParams memory preLiquidationParams_,
        IPool pool,
        uint256 _emodeCategory
    ) internal view {
        uint256 emodeLltv = 0;
        if (_emodeCategory != 0) {
            AaveDataTypes.EModeCategory memory emodeCategoryData = pool.getEModeCategoryData(uint8(_emodeCategory));
            emodeLltv = Math.mulDiv(emodeCategoryData.liquidationThreshold, WadRayMath.WAD, BPS); // NOTE: div because liquidationThreshold is in BPS
        }

        AaveDataTypes.ReserveConfigurationMap memory lendReserveConfiguration =
            pool.getConfiguration(preLiquidationParams_.lendReserve);
        uint256 lltvBps = ReserveConfiguration.getLiquidationThreshold(lendReserveConfiguration);
        uint256 effectiveLltv = Math.mulDiv(lltvBps, WadRayMath.WAD, BPS); // NOTE: div because lltv is in BPS

        if (_emodeCategory != 0) {
            uint256 _lendReserveEmodeCategory = ReserveConfiguration.getEModeCategory(lendReserveConfiguration);
            AaveDataTypes.ReserveConfigurationMap memory borrowReserveConfiguration =
                pool.getConfiguration(preLiquidationParams_.borrowReserve);
            uint256 _borrowReserveEmodeCategory = ReserveConfiguration.getEModeCategory(borrowReserveConfiguration);
            require(
                _lendReserveEmodeCategory == _borrowReserveEmodeCategory && _lendReserveEmodeCategory == _emodeCategory,
                Errors.AAVE_V3_PRELIQUIDATION_INVALID_EMODE_CATEGORY
            );
            effectiveLltv = emodeLltv;
        }

        require(preLiquidationParams_.preLltv < effectiveLltv, Errors.PRELIQUIDATION_PRELTV_TOO_HIGH);
        require(preLiquidationParams_.preLCF1 <= preLiquidationParams_.preLCF2, Errors.PRELIQUIDATION_LCF_DECREASING);
        require(preLiquidationParams_.preLCF1 <= WadRayMath.WAD, Errors.PRELIQUIDATION_LCF_TOO_HIGH);
        require(WadRayMath.WAD <= preLiquidationParams_.preLIF1, Errors.PRELIQUIDATION_LIF_TOO_LOW);
        require(preLiquidationParams_.preLIF1 <= preLiquidationParams_.preLIF2, Errors.PRELIQUIDATION_LIF_DECREASING);
        require(
            preLiquidationParams_.preLIF2 <= WadRayMath.wadDiv(WadRayMath.WAD, effectiveLltv),
            Errors.PRELIQUIDATION_LIF_TOO_HIGH
        );
    }
}
