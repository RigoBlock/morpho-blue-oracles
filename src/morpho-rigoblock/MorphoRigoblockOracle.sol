// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IOracle} from "../../lib/morpho-blue/src/interfaces/IOracle.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {IMorphoRigoblockOracle} from "./interfaces/IMorphoRigoblockOracle.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {IBackGeoOracle} from "./interfaces/IBackGeoOracle.sol";
import {RigoblockDataFeedLib} from "./libraries/RigoblockDataFeedLib";
import {IERC4626, VaultLib} from "./libraries/VaultLib.sol";

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

/// @title IMorphoRigoblockOracle
/// @author Rigoblock
/// @notice Morpho Blue oracle using Rigoblock Price Feeds.
contract MorphoRigoblockOracle is IMorphoRigoblockOracle {
    using Math for uint256;
    using VaultLib for IERC4626;
    using RigoblockDataFeedLib for IBackGeoOracle;

    /* IMMUTABLES */
    IBackGeoOracle public immutable BACK_GEO_ORACLE;

    /// @inheritdoc IMorphoRigoblockOracle
    IERC4626 public immutable BASE_VAULT;

    /// @inheritdoc IMorphoRigoblockOracle
    uint256 public immutable BASE_VAULT_CONVERSION_SAMPLE;

    /// @inheritdoc IMorphoRigoblockOracle
    IERC4626 public immutable QUOTE_VAULT;

    /// @inheritdoc IMorphoRigoblockOracle
    uint256 public immutable QUOTE_VAULT_CONVERSION_SAMPLE;

    /// @inheritdoc IMorphoRigoblockOracle
    address public immutable BASE_TOKEN;

    /// @inheritdoc IMorphoRigoblockOracle
    address public immutable QUOTE_TOKEN;

    address public immutable BASE_POOL_1_TOKEN0;
    address public immutable BASE_POOL_1_TOKEN1;
    address public immutable BASE_POOL_2_TOKEN0;
    address public immutable BASE_POOL_2_TOKEN1;
    address public immutable QUOTE_POOL_1_TOKEN0;
    address public immutable QUOTE_POOL_1_TOKEN1;
    address public immutable QUOTE_POOL_2_TOKEN0;
    address public immutable QUOTE_POOL_2_TOKEN1;

    uint256 public immutable BASE_TOKEN_DECIMALS;
    uint256 public immutable QUOTE_TOKEN_DECIMALS;

    /// @inheritdoc IMorphoRigoblockOracle
    uint32 public immutable TWAP_WINDOW;

    BASE_TOKEN_DECIMALS;

    // TODO: verify if getPrice() method from lib will correctly handle vault decimal conversions when converting vault prices instead of token prices
    /// @dev Assumptions:
    /// - Vaults, if set, are ERC4626-compliant.
    /// - BackgeOracle is a valid Uniswap V4 hook with correct observations.
    /// - Token decimals are correct.
    /// - Vault conversion samples and prices don’t overflow.
    /// @param baseVault Base vault, or address(0) for token.
    /// @param baseVaultConversionSample Sample shares for base vault; 1 if no vault.
    /// @param quoteVault Quote vault, or address(0) for token.
    /// @param quoteVaultConversionSample Sample shares for quote vault; 1 if no vault.
    /// @param baseToken Underlying base token (collateral).
    /// @param quoteToken Underlying quote token (loan).
    /// @param oracle BackgeOracle contract address.
    /// @param poolKey Pool identifier (token0, token1, fee, hook, salt).
    /// @param twapWindow TWAP window in seconds.
    /// @param baseTokenDecimals Decimals of base token.
    /// @param quoteTokenDecimals Decimals of quote token.
    constructor(
        IBackgeoOracle backGeoOracle,
        IERC4626 baseVault,
        uint256 baseVaultConversionSample,
        IERC4626 quoteVault,
        uint256 quoteVaultConversionSample,
        address baseToken,
        address quoteToken,
        address basePool1Token0,
        address basePool1Token1,
        address basePool2Token0,
        address basePool2Token1,
        address quotePool1Token0,
        address quotePool1Token1,
        address quotePool2Token0,
        address quotePool2Token1,
        uint32 twapWindow,
        uint256 baseTokenDecimals,
        uint256 quoteTokenDecimals
    ) {
        // The ERC4626 vault parameters are used to price their respective conversion samples of their respective
        // shares, so it requires multiplying by `QUOTE_VAULT_CONVERSION_SAMPLE` and dividing
        // by `BASE_VAULT_CONVERSION_SAMPLE` in the `SCALE_FACTOR` definition.
        // Verify that vault = address(0) => vaultConversionSample = 1 for each vault.
        require(
            address(baseVault) != address(0) || baseVaultConversionSample == 1,
            ErrorsLib.VAULT_CONVERSION_SAMPLE_IS_NOT_ONE
        );
        require(
            address(quoteVault) != address(0) || quoteVaultConversionSample == 1,
            ErrorsLib.VAULT_CONVERSION_SAMPLE_IS_NOT_ONE
        );
        require(baseVaultConversionSample != 0, ErrorsLib.VAULT_CONVERSION_SAMPLE_IS_ZERO);
        require(quoteVaultConversionSample != 0, ErrorsLib.VAULT_CONVERSION_SAMPLE_IS_ZERO);

        // Validate vault assets and tokens
        // one of the tokens can be native currency
        require(baseToken != address(0) || quoteToken != address(0), "Invalid tokens");
        if (address(baseVault) != address(0)) {
            require(baseVault.asset() == baseToken, ErrorsLib.INVALID_VAULT_ASSET);
        }
        if (address(quoteVault) != address(0)) {
            require(quoteVault.asset() == quoteToken, ErrorsLib.INVALID_VAULT_ASSET);
        }

        // Validate oracle and poolKey
        require(address(oracle) != address(0), "Invalid oracle");
        require(twapWindow > 0, "Invalid TWAP window");

        // TODO: check sanitize non-nil lp addresses, but we could have some nil pools?
        require(
            !(basePool1Token0 == address(0) && basePool1Token1 == address(0) &&
              basePool2Token0 == address(0) && basePool2Token1 == address(0)),
            ErrorsLib.INVALID_POOL
        );
        require(
            !(quotePool1Token0 == address(0) && quotePool1Token1 == address(0) &&
              quotePool2Token0 == address(0) && quotePool2Token1 == address(0)),
            ErrorsLib.INVALID_POOL
        );

        require(
            baseToken == basePool1Token0 || baseToken == basePool1Token1 ||
            baseToken == basePool2Token0 || baseToken == basePool2Token1,
            ErrorsLib.TOKEN_NOT_IN_POOL
        );
        require(
            quoteToken == quotePool1Token0 || quoteToken == quotePool1Token1 ||
            quoteToken == quotePool2Token0 || quoteToken == quotePool2Token1,
            ErrorsLib.TOKEN_NOT_IN_POOL
        );

        require(baseTokenDecimals > 0 && baseTokenDecimals <= 38, ErrorsLib.INVALID_DECIMALS);
        require(quoteTokenDecimals > 0 && quoteTokenDecimals <= 38, ErrorsLib.INVALID_DECIMALS);

        BASE_VAULT = baseVault;
        BASE_VAULT_CONVERSION_SAMPLE = baseVaultConversionSample;
        QUOTE_VAULT = quoteVault;
        QUOTE_VAULT_CONVERSION_SAMPLE = quoteVaultConversionSample;
        BASE_TOKEN = baseToken;
        QUOTE_TOKEN = quoteToken;
        BACK_GEO_ORACLE = backGeoOracle;
        BASE_POOL_1_TOKEN0 = basePool1Token0;
        BASE_POOL_1_TOKEN1 = basePool1Token1;
        BASE_POOL_2_TOKEN0 = basePool2Token0;
        BASE_POOL_2_TOKEN1 = basePool2Token1;
        QUOTE_POOL_1_TOKEN0 = quotePool1Token0;
        QUOTE_POOL_1_TOKEN1 = quotePool1Token1;
        QUOTE_POOL_2_TOKEN0 = quotePool2Token0;
        QUOTE_POOL_2_TOKEN1 = quotePool2Token1;
        BASE_TOKEN_DECIMALS = baseTokenDecimals;
        QUOTE_TOKEN_DECIMALS = quoteTokenDecimals;
        TWAP_WINDOW = twapWindow;
    }

    /// @inheritdoc IMorphoRigoblockOracle
    function price() external view override returns (uint256) {
        int24 baseTick1 = BACK_GEO_ORACLE.getQuote(TWAP_WINDOW, BASE_POOL_1_TOKEN0, BASE_POOL_1_TOKEN1);
        int24 quoteTick1 = BACK_GEO_ORACLE.getQuote(TWAP_WINDOW, BASE_POOL_2_TOKEN0, BASE_POOL_2_TOKEN1);
        int24 baseTick2 = BACK_GEO_ORACLE.getQuote(TWAP_WINDOW, QUOTE_POOL_1_TOKEN0, QUOTE_POOL_1_TOKEN1);
        int24 quoteTick2 = BACK_GEO_ORACLE.getQuote(TWAP_WINDOW, QUOTE_POOL_2_TOKEN0, QUOTE_POOL_2_TOKEN1);

        int56 finalTick = int56(baseTick1) + int56(baseTick2) - (int56(quoteTick1) + int56(quoteTick2));
        require(finalTick >= BackgeOracleLib.MIN_TICK && finalTick <= BackgeOracleLib.MAX_TICK, ErrorsLib.TICK_OUT_OF_BOUNDS);

        uint128 baseAmount = uint128(10 ** BASE_TOKEN_DECIMALS);
        uint256 price = OracleLibrary.getQuoteAtTick(int24(finalTick), baseAmount, BASE_TOKEN, QUOTE_TOKEN);
        price = price.mulDiv(
            BASE_VAULT.getAssets(BASE_VAULT_CONVERSION_SAMPLE),
            QUOTE_VAULT.getAssets(QUOTE_VAULT_CONVERSION_SAMPLE)
        );
        assert(quotePrice > 0);
        return price * 10 ** 36;
    }
}