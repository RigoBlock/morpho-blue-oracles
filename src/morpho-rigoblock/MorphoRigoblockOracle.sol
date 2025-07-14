// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IOracle} from "../../lib/morpho-blue/src/interfaces/IOracle.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IMorphoRigoblockOracle} from "./interfaces/IMorphoRigoblockOracle.sol";
import {Math} from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IBackGeoOracle} from "./interfaces/IBackGeoOracle.sol";
import {RigoblockDataFeedLib} from "./libraries/RigoblockDataFeedLib.sol";
import {IERC4626, VaultLib} from "./libraries/VaultLib.sol";

/// @title IMorphoRigoblockOracle
/// @author Rigoblock
/// @notice Morpho Blue oracle using Rigoblock Price Feeds.
contract MorphoRigoblockOracle is IMorphoRigoblockOracle {
    error InvalidPrice();
    error VaultConversionSampleIsNotOne();
    error VaultConversionSampleIsZero();
    error InvalidVaultAsset();
    error InvalidTokens();
    error InvalidOracle();
    error InvalidTwapWindow();
    error TokenNotInPool();
    error InvalidDecimals();
    error TickOutOfBounds();

    using Math for uint256;
    using VaultLib for IERC4626;
    using RigoblockDataFeedLib for *;

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

    // TODO: define as uint8
    uint256 public immutable BASE_TOKEN_DECIMALS;
    uint256 public immutable QUOTE_TOKEN_DECIMALS;

    /// @inheritdoc IMorphoRigoblockOracle
    uint32 public immutable TWAP_WINDOW;

    uint256 public immutable SCALE_FACTOR;

    /// @dev Assumptions:
    /// - Vaults, if set, are ERC4626-compliant.
    /// - BackGeOracle is a valid Uniswap V4 hook with correct observations.
    /// - Token decimals are correct.
    /// - Vault conversion samples and prices don’t overflow.
    /// @param backGeoOracle BackGeOracle contract address.
    /// @param baseVault Base vault, or address(0) for token.
    /// @param baseVaultConversionSample Sample shares for base vault; 1 if no vault.
    /// @param quoteVault Quote vault, or address(0) for token.
    /// @param quoteVaultConversionSample Sample shares for quote vault; 1 if no vault.
    /// @param baseToken Underlying base token (collateral).
    /// @param quoteToken Underlying quote token (loan).
    /// @param basePool1Token0 Address,
    /// @param basePool1Token1 Address,
    /// @param basePool2Token0 Address,
    /// @param basePool2Token1 Address,
    /// @param quotePool1Token0 Address,
    /// @param quotePool1Token1 Address,
    /// @param quotePool2Token0 Address,
    /// @param quotePool2Token1 Address,
    /// @param twapWindow TWAP window in seconds.
    /// @param baseTokenDecimals Decimals of base token.
    /// @param quoteTokenDecimals Decimals of quote token.
    constructor(
        IBackGeoOracle backGeoOracle,
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
        if (address(baseVault) == address(0) && baseVaultConversionSample != 1) {
            revert VaultConversionSampleIsNotOne();
        }
        if (address(quoteVault) == address(0) && quoteVaultConversionSample != 1) {
            revert VaultConversionSampleIsNotOne();
        }
        if (baseVaultConversionSample == 0) revert VaultConversionSampleIsZero();
        if (quoteVaultConversionSample == 0) revert VaultConversionSampleIsZero();

        // Validate tokens (allow baseToken or quoteToken to be address(0) for native currency)
        if (baseToken == address(0) && quoteToken == address(0)) revert InvalidTokens();
        if (address(baseVault) != address(0) && baseVault.asset() != baseToken) revert InvalidVaultAsset();
        if (address(quoteVault) != address(0) && quoteVault.asset() != quoteToken) revert InvalidVaultAsset();

        // Validate oracle and TWAP window
        if (address(backGeoOracle) == address(0)) revert InvalidOracle();
        if (twapWindow == 0) revert InvalidTwapWindow();

        // TODO: this is probably excessive, as the inputs will be given for a route known to exist
        // Validate tokens in pools (if any pools are provided)
        if (!(basePool1Token0 == address(0) && basePool1Token1 == address(0) &&
                basePool2Token0 == address(0) && basePool2Token1 == address(0) &&
                quotePool1Token0 == address(0) && quotePool1Token1 == address(0) &&
                quotePool2Token0 == address(0) && quotePool2Token1 == address(0))) {
            if (!(baseToken == basePool1Token0 || baseToken == basePool1Token1 ||
                baseToken == basePool2Token0 || baseToken == basePool2Token1)) {
                    revert TokenNotInPool();
            }
            if (!(quoteToken == quotePool1Token0 || quoteToken == quotePool1Token1 ||
                  quoteToken == quotePool2Token0 || quoteToken == quotePool2Token1)) {
                revert TokenNotInPool();
            }
        }

        if (baseTokenDecimals == 0 || baseTokenDecimals > 38) revert InvalidDecimals();
        if (quoteTokenDecimals == 0 || quoteTokenDecimals > 38) revert InvalidDecimals();

        BACK_GEO_ORACLE = backGeoOracle;
        BASE_VAULT = baseVault;
        BASE_VAULT_CONVERSION_SAMPLE = baseVaultConversionSample;
        QUOTE_VAULT = quoteVault;
        QUOTE_VAULT_CONVERSION_SAMPLE = quoteVaultConversionSample;
        BASE_TOKEN = baseToken;
        QUOTE_TOKEN = quoteToken;
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

        int256 baseVaultAdjustment = address(baseVault) != address(0)
            ? int256(baseVault.getDecimals()) - int256(baseVault.asset().getDecimals())
            : int256(0);
        int256 quoteVaultAdjustment = address(quoteVault) != address(0)
            ? int256(quoteVault.getDecimals()) - int256(quoteVault.asset().getDecimals())
            : int256(0);
        SCALE_FACTOR = 10 ** uint256(int256(36) - baseVaultAdjustment + quoteVaultAdjustment);
    }

    /// @inheritdoc IOracle
    function price() external view override returns (uint256) {
        int24 baseTick1 = BACK_GEO_ORACLE.getTick(TWAP_WINDOW, BASE_POOL_1_TOKEN0, BASE_POOL_1_TOKEN1);
        int24 baseTick2 = BACK_GEO_ORACLE.getTick(TWAP_WINDOW, BASE_POOL_2_TOKEN0, BASE_POOL_2_TOKEN1);
        int24 quoteTick1 = BACK_GEO_ORACLE.getTick(TWAP_WINDOW, QUOTE_POOL_1_TOKEN0, QUOTE_POOL_1_TOKEN1);
        int24 quoteTick2 = BACK_GEO_ORACLE.getTick(TWAP_WINDOW, QUOTE_POOL_2_TOKEN0, QUOTE_POOL_2_TOKEN1);

        int56 finalTick = int56(baseTick1) + int56(baseTick2) - int56(quoteTick1) - int56(quoteTick2);
        if (finalTick < TickMath.MIN_TICK || finalTick > TickMath.MAX_TICK) revert TickOutOfBounds();

        uint256 finalPrice = OracleLibrary.getQuoteAtTick(
            int24(finalTick),
            uint128(10 ** BASE_TOKEN_DECIMALS),
            BASE_TOKEN,
            QUOTE_TOKEN
        );

        // Assumes QUOTE_VAULT.getAssets(QUOTE_VAULT_CONVERSION_SAMPLE) > 0
        finalPrice = SCALE_FACTOR.mulDiv(
            BASE_VAULT.getAssets(BASE_VAULT_CONVERSION_SAMPLE) * finalPrice,
            QUOTE_VAULT.getAssets(QUOTE_VAULT_CONVERSION_SAMPLE)
        );
        if (finalPrice == 0) revert InvalidPrice();

        return finalPrice;
    }
}