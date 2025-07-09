// SPDX-License-Identifier: GPL-2.0-or-later
// TODO: check use later pragma
pragma solidity 0.8.27;

import {IMorphoRigoblockOracle} from "./interfaces/IMorphoRigoblockOracle.sol";
import {IBackGeoOracle} from "./interfaces/IBackGeoOracle.sol";
import {IMorphoRigoblockOracleFactory} from "./interfaces/IMorphoRigoblockOracleFactory.sol";
import {IERC4626} from "./libraries/VaultLib.sol";

import {MorphoRigoblockOracle} from "./MorphoRigoblockOracle.sol";

/// @title MorphoRigoblockOracleFactory
/// @author Rigoblock
/// @custom:contact security@rigoblock.com
/// @notice This contract allows to create MorphoRigoblockOracle oracles, and to index them easily.
contract MorphoRigoblockOracleFactory is IMorphoRigoblockOracleFactory {
    /* STORAGE */

    /// @inheritdoc IMorphoRigoblockOracleFactory
    mapping(address => bool) public isMorphoRigoblockOracle;

    /* EXTERNAL */
    /// @inheritdoc IMorphoRigoblockOracleFactory
    function createMorphoRigoblockOracle(
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
        uint256 quoteTokenDecimals,
        bytes32 salt
    ) external returns (IMorphoRigoblockOracle oracle) {
        oracle = new MorphoRigoblockOracle{salt: salt}(
            backGeoOracle,
            baseVault,
            baseVaultConversionSample,
            quoteVault,
            quoteVaultConversionSample,
            baseToken,
            quoteToken,
            basePool1Token0,
            basePool1Token1,
            basePool2Token0,
            basePool2Token1,
            quotePool1Token0,
            quotePool1Token1,
            quotePool2Token0,
            quotePool2Token1,
            twapWindow,
            baseTokenDecimals,
            quoteTokenDecimals
        );

        isMorphoRigoblockOracle[address(oracle)] = true;

        emit CreateMorphoRigoblockOracle(msg.sender, address(oracle));
    }
}
