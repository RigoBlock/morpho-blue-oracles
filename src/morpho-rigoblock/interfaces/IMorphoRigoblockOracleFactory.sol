// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IERC4626} from "../libraries/VaultLib.sol";
import {IBackGeoOracle} from "./IBackGeoOracle.sol";
import {IMorphoRigoblockOracle} from "./IMorphoRigoblockOracle.sol";

/// @title IMorphoRigoblockOracleFactory
/// @author Rigoblock
/// @custom:contact security@rigoblock.com
/// @notice Interface for IMorphoRigoblockOracleFactory
interface IMorphoRigoblockOracleFactory {
    /// @notice Emitted when a new Rigoblock oracle is created.
    /// @param oracle The address of the Rigoblock oracle.
    /// @param caller The caller of the function.
    event CreateMorphoRigoblockOracle(address caller, address oracle);

    /// @notice Whether a Rigoblock oracle vault was created with the factory.
    function isMorphoRigoblockOracle(address target) external view returns (bool);

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
    ) external returns (IMorphoRigoblockOracle oracle);
}
