// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

abstract contract TestEnv is Test {
    struct TestEnvironment {
        uint256 chainId;
        string chainName;
        address vaultAsset;
        uint8 vaultAssetDecimals;
        address[] lendAssets;
        address[] borrowAssets;
        address poolAddressesProvider;
        address poolDataProvider;
        address priceOracle;
        address pool;
        address vaultAssetWhale;
        address poolConfigurator;
        address poolAdmin;
        address router;
        address stablecoin;
        address stablecoinWhale;
    }

    // etlk chain
    address public constant ST_XTZ = 0x01F07f4d78d47A64F4C3B2b65f513f15Be6E1854;
    address public constant WXTZ = 0xc9B53AB2679f573e480d01e0f49e2B5CFB7a3EAb;
    address public constant LBTC = 0xecAc9C5F704e954931349Da37F60E39f515c11c1;
    address public constant WBTC = 0xbFc94CD2B1E55999Cfc7347a9313e88702B83d0F;
    address public constant USDC_ETLK = 0x796Ea11Fa2dD751eD01b53C372fFDB4AAa8f00F9;
    address public constant USDT_ETLK = 0x2C03058C8AFC06713be23e58D2febC8337dbfE6A;
    address public constant USDT_ETLK_WHALE = 0x998098A1B2E95e2b8f15360676428EdFd976861f;
    address public constant USDC_ETLK_WHALE = 0xd03bfdF9B26DB1e6764724d914d7c3d18106a9Fb;

    // eth mainnet chain
    address public constant USDe = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address public constant USDeWhale = 0x4F5923Fc5FD4a93352581b38B7cD26943012DECF;
    address public constant sUSDe = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address public constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDC_ETH_Whale = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
    address public constant USDT_ETH = 0x2C03058C8AFC06713be23e58D2febC8337dbfE6A;

    // address public constant
    uint256 public constant PERFORMANCE_FEE = 2000; // 20%
    TestEnvironment[] internal testEnvironments;

    function setUp() public virtual {
        // etherlink xtz
        testEnvironments.push(
            TestEnvironment({
                chainId: 42793,
                chainName: "etherlink",
                vaultAsset: WXTZ,
                vaultAssetDecimals: 18,
                lendAssets: _singleAddressArray(ST_XTZ),
                borrowAssets: _singleAddressArray(WXTZ),
                poolAddressesProvider: 0x5ccF60c7E10547c5389E9cBFf543E5D0Db9F4feC,
                poolDataProvider: 0x99e8269dDD5c7Af0F1B3973A591b47E8E001BCac,
                priceOracle: 0xeCF313dE38aA85EF618D06D1A602bAa917D62525,
                pool: 0x3bD16D195786fb2F509f2E2D7F69920262EF114D,
                vaultAssetWhale: 0x008ae222661B6A42e3A097bd7AAC15412829106b,
                poolConfigurator: 0x30F6880Bb1cF780a49eB4Ef64E64585780AAe060,
                poolAdmin: 0x669bd328f6C494949Ed9fB2dc8021557A6Dd005f,
                router: 0xbfe9C246A5EdB4F021C8910155EC93e7CfDaB7a0,
                stablecoin: 0x2C03058C8AFC06713be23e58D2febC8337dbfE6A,
                stablecoinWhale: 0x998098A1B2E95e2b8f15360676428EdFd976861f
            })
        );

        // etherlink btc
        testEnvironments.push(
            TestEnvironment({
                chainId: 42793,
                chainName: "etherlink",
                vaultAsset: WBTC,
                vaultAssetDecimals: 8,
                lendAssets: _singleAddressArray(LBTC),
                borrowAssets: _singleAddressArray(WBTC),
                poolAddressesProvider: 0x5ccF60c7E10547c5389E9cBFf543E5D0Db9F4feC,
                poolDataProvider: 0x99e8269dDD5c7Af0F1B3973A591b47E8E001BCac,
                priceOracle: 0xeCF313dE38aA85EF618D06D1A602bAa917D62525,
                pool: 0x3bD16D195786fb2F509f2E2D7F69920262EF114D,
                vaultAssetWhale: 0xfCA0802cb10b3b134a91e07f03965f63eF4B23eA,
                poolConfigurator: 0x30F6880Bb1cF780a49eB4Ef64E64585780AAe060,
                poolAdmin: 0x669bd328f6C494949Ed9fB2dc8021557A6Dd005f,
                router: 0xbfe9C246A5EdB4F021C8910155EC93e7CfDaB7a0,
                stablecoin: 0x2C03058C8AFC06713be23e58D2febC8337dbfE6A,
                stablecoinWhale: 0x998098A1B2E95e2b8f15360676428EdFd976861f
            })
        );

        // eth mainnet ethena
        testEnvironments.push(
            TestEnvironment({
                chainId: 1,
                chainName: "mainnet",
                vaultAsset: USDe,
                vaultAssetDecimals: 18,
                lendAssets: _twoAddressArray(USDe, sUSDe),
                borrowAssets: _twoAddressArray(USDT_ETH, USDC_ETH),
                poolAddressesProvider: 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e,
                poolDataProvider: 0x0a16f2FCC0D44FaE41cc54e079281D84A363bECD,
                priceOracle: 0x54586bE62E3c3580375aE3723C145253060Ca0C2,
                pool: 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2,
                vaultAssetWhale: USDeWhale,
                poolConfigurator: 0x64b761D848206f447Fe2dd461b0c635Ec39EbB27,
                poolAdmin: 0x72B8fD3eb0c08275b8B60F96aAb0C8a50Cb80EcA,
                router: address(0),
                stablecoin: USDC_ETH,
                stablecoinWhale: USDC_ETH_Whale
            })
        );
    }

    function _singleAddressArray(address a) internal pure returns (address[] memory) {
        address[] memory array = new address[](1);
        array[0] = a;
        return array;
    }

    function _twoAddressArray(address a, address b) internal pure returns (address[] memory) {
        address[] memory array = new address[](2);
        array[0] = a;
        array[1] = b;
        return array;
    }
}
