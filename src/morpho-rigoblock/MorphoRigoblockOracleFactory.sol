// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {IMorphoRigoblockOracle} from "./interfaces/IMorphoRigoblockOracle.sol";
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
        uint32 twapWindow,
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
            twapWindow,
            baseTokenDecimals,
            quoteTokenDecimals
        );

        isMorphoRigoblockOracle[address(oracle)] = true;

        emit CreateMorphoRigoblockOracle(msg.sender, address(oracle));
    }
}
