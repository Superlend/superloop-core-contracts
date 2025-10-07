// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DataTypes} from "../../common/DataTypes.sol";
import {DataTypes as AaveDataTypes} from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {Errors} from "../../common/Errors.sol";
import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {ReserveConfiguration} from "aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import {WadRayMath} from "aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IAaveOracle} from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract AaveV3PreliquidationFallbackHandler is Context {
    event PreliquidationDeployed(
        bytes32 indexed id,
        address lendReserve,
        address borrowReserve,
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preIF1,
        uint256 preIF2
    );

    event PreliquidationExecuted(
        bytes32 indexed id, address preliquidator, address vault, uint256 debtToCover, uint256 collateralToSieze
    );

    // aave  and vault related stuff
    uint256 public constant BPS = 1e4;
    IPoolAddressesProvider public immutable poolAddressesProvider;
    address public immutable vault;
    uint256 public immutable emodeCategory; // preliquidation module is supposed to be used in only one emode category
    uint8 public immutable interestRateMode;
    uint8 public immutable oracleDecimals;

    // fallback handler related stuff
    bytes32 public immutable id;
    address public immutable lendReserve;
    uint256 public immutable lendReserveDecimals;
    address public immutable borrowReserve;
    uint256 public immutable borrowReserveDecimals;
    uint256 public immutable Lltv;
    uint256 public immutable preLltv;
    uint256 public immutable preCF1;
    uint256 public immutable preCF2;
    uint256 public immutable preIF1;
    uint256 public immutable preIF2;

    constructor(
        address poolAddressesProvider_,
        address vault_,
        uint8 interestRateMode_,
        uint8 oracleDecimals_,
        DataTypes.AaveV3PreliquidationParamsInit memory preLiquidationParams_
    ) {
        vault = vault_;
        poolAddressesProvider = IPoolAddressesProvider(poolAddressesProvider_);
        IPool pool = IPool(IPoolAddressesProvider(poolAddressesProvider_).getPool());
        emodeCategory = pool.getUserEMode(vault_);
        interestRateMode = interestRateMode_;
        oracleDecimals = oracleDecimals_;

        uint256 effectiveLltv = _validatePreLiquidationParams(preLiquidationParams_, pool, emodeCategory);

        lendReserve = preLiquidationParams_.lendReserve;
        lendReserveDecimals = IERC20Metadata(lendReserve).decimals();
        borrowReserve = preLiquidationParams_.borrowReserve;
        borrowReserveDecimals = IERC20Metadata(borrowReserve).decimals();
        id = preLiquidationParams_.id;

        Lltv = effectiveLltv;
        preLltv = preLiquidationParams_.preLltv;
        preCF1 = preLiquidationParams_.preCF1;
        preCF2 = preLiquidationParams_.preCF2;
        preIF1 = preLiquidationParams_.preIF1;
        preIF2 = preLiquidationParams_.preIF2;

        emit PreliquidationDeployed(id, lendReserve, borrowReserve, preLltv, preCF1, preCF2, preIF1, preIF2);
    }

    function preliquidate(bytes32 id_, DataTypes.CallType, DataTypes.AaveV3ExecutePreliquidationParams memory params)
        public
    {
        IPool pool = IPool(poolAddressesProvider.getPool());
        IAaveOracle oracle = IAaveOracle(poolAddressesProvider.getPriceOracle());
        IPoolDataProvider poolDataProvider = IPoolDataProvider(poolAddressesProvider.getPoolDataProvider());

        // initial validations
        require(id_ == id, Errors.PRELIQUIDATION_INVALID_ID);
        require(params.user == vault && address(this) == params.user, Errors.PRELIQUIDATION_INVALID_USER);
        require(pool.getUserEMode(vault) == emodeCategory, Errors.AAVE_V3_PRELIQUIDATION_INVALID_EMODE_CATEGORY);
        address user = params.user;

        // get collateral tokens and it's USD value
        // get debt tokens and it's USD value
        (
            ,
            uint256 collateralUsdWAD,
            uint256 collateralPriceUSD,
            uint256 borrowTokens,
            uint256 borrowUsdWAD,
            uint256 borrowPriceUSD
        ) = _getPositions(poolDataProvider, oracle, user);

        // make sure borrowUSD <= collateralUSD * Lltv : bad debt
        require(borrowUsdWAD <= WadRayMath.wadMul(collateralUsdWAD, Lltv), Errors.PRELIQUIDATION_POSSIBLE_BAD_DEBT);

        // make sure borrowUSD > collateralUSD * preLltv : not in preliquidation state
        require(
            borrowUsdWAD > WadRayMath.wadMul(collateralUsdWAD, preLltv),
            Errors.PRELIQUIDATION_NOT_IN_PRELIQUIDATION_STATE
        );

        // calculate the current ltv : borrowedUSD / collateralUSD
        uint256 currentLtv = WadRayMath.wadDiv(borrowUsdWAD, collateralUsdWAD);

        // calculate the current quotient : (ltv - preLltv) / (Lltv - preLltv)
        uint256 currentQuotient = WadRayMath.wadDiv(currentLtv - preLltv, Lltv - preLltv);

        // calculate the current incentive factor : currentQuotient * (preIF2 - preIF1) + preIF1
        uint256 currentIncentiveFactor = WadRayMath.wadMul(currentQuotient, preIF2 - preIF1) + preIF1;

        // calculate the current close factor : currentQuotient * (preCF2 - preCF1) + preCF1
        uint256 currentCloseFactor = WadRayMath.wadMul(currentQuotient, preCF2 - preCF1) + preCF1;

        // calculate how much collateral to sieze : (debtCoverUSD / collateralPriceUSD) * incentiveFactor
        uint256 maxDebtToCover = (borrowTokens * currentCloseFactor) / WadRayMath.WAD; // in tokens
        uint256 debtToCover = Math.min(params.debtToCover, maxDebtToCover);
        uint256 debtCoverUSD = (debtToCover * borrowPriceUSD) / (10 ** borrowReserveDecimals); // in oracle decimals

        uint256 collateralToSieze = (
            ((debtCoverUSD * 10 ** lendReserveDecimals) / collateralPriceUSD) * currentIncentiveFactor
        ) / WadRayMath.WAD; // in tokens

        // transfer debt tokens to self
        SafeERC20.safeTransferFrom(IERC20(borrowReserve), _msgSender(), address(this), debtToCover);

        // approve debt tokens to pool
        SafeERC20.forceApprove(IERC20(borrowReserve), address(pool), debtToCover);

        // repay the debt
        pool.repay(borrowReserve, debtToCover, interestRateMode, address(this));

        // withdraw the collateral
        uint256 collateralWithdrawn = pool.withdraw(lendReserve, collateralToSieze, address(this));

        // transfer collateral to msg.sender ie. preliquidator
        SafeERC20.safeTransfer(IERC20(lendReserve), _msgSender(), collateralWithdrawn);

        // emit event
        emit PreliquidationExecuted(id, params.user, user, debtToCover, collateralToSieze);
    }

    function preliquidationParams(bytes32, DataTypes.CallType)
        external
        view
        returns (DataTypes.AaveV3PreliquidationParams memory)
    {
        return DataTypes.AaveV3PreliquidationParams({
            lendReserve: lendReserve,
            borrowReserve: borrowReserve,
            Lltv: Lltv,
            preLltv: preLltv,
            preCF1: preCF1,
            preCF2: preCF2,
            preIF1: preIF1,
            preIF2: preIF2
        });
    }

    function _validatePreLiquidationParams(
        DataTypes.AaveV3PreliquidationParamsInit memory preLiquidationParams_,
        IPool pool,
        uint256 _emodeCategory
    ) internal view returns (uint256) {
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
        require(preLiquidationParams_.preCF1 <= preLiquidationParams_.preCF2, Errors.PRELIQUIDATION_LCF_DECREASING);
        require(preLiquidationParams_.preCF1 <= WadRayMath.WAD, Errors.PRELIQUIDATION_LCF_TOO_HIGH);
        require(WadRayMath.WAD <= preLiquidationParams_.preIF1, Errors.PRELIQUIDATION_LIF_TOO_LOW);
        require(preLiquidationParams_.preIF1 <= preLiquidationParams_.preIF2, Errors.PRELIQUIDATION_LIF_DECREASING);
        require(
            preLiquidationParams_.preIF2 <= WadRayMath.wadDiv(WadRayMath.WAD, effectiveLltv),
            Errors.PRELIQUIDATION_LIF_TOO_HIGH
        );

        return effectiveLltv;
    }

    function _getPositions(IPoolDataProvider poolDataProvider, IAaveOracle oracle, address user_)
        internal
        view
        returns (
            uint256 collateralTokens,
            uint256 collateralUSD,
            uint256 collateralPriceUSD,
            uint256 borrowTokens,
            uint256 borrowUSD,
            uint256 borrowPriceUSD
        )
    {
        (collateralTokens,,,,,,,,) = poolDataProvider.getUserReserveData(lendReserve, user_);
        collateralPriceUSD = oracle.getAssetPrice(lendReserve);

        (,, borrowTokens,,,,,,) = poolDataProvider.getUserReserveData(borrowReserve, user_);
        borrowPriceUSD = oracle.getAssetPrice(borrowReserve);

        collateralUSD =
            (collateralTokens * collateralPriceUSD * WadRayMath.WAD) / (10 ** (lendReserveDecimals + oracleDecimals)); // in WAD
        borrowUSD = (borrowTokens * borrowPriceUSD * WadRayMath.WAD) / (10 ** (borrowReserveDecimals + oracleDecimals)); // in WAD
    }
}
