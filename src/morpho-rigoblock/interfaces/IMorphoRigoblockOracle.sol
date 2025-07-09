// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IERC4626} from "./IERC4626.sol";
import {IOracle} from "../../../lib/morpho-blue/src/interfaces/IOracle.sol";

/// @title IMorphoRigoblockOracle
/// @author Rigoblock
/// @custom:contact security@morpho.org
/// @notice Interface of MorphoChainlinkOracleV2.
interface IMorphoRigoblockOracle is IOracle {
    /// @notice Returns the address of the base ERC4626 vault.
    function BASE_VAULT() external view returns (IERC4626);

    /// @notice Returns the base vault conversion sample.
    function BASE_VAULT_CONVERSION_SAMPLE() external view returns (uint256);

    /// @notice Returns the address of the quote ERC4626 vault.
    function QUOTE_VAULT() external view returns (IERC4626);

    /// @notice Returns the quote vault conversion sample.
    function QUOTE_VAULT_CONVERSION_SAMPLE() external view returns (uint256);

    /// @notice Returns.
    function BASE_TOKEN() external view returns (address);

    /// @notice Returns.
    function QUOTE_TOKEN() external view returns (address);

    /// @notice Returns.
    function BASE_POOL_1_TOKEN0() external view returns (address);

    /// @notice Returns.
    function BASE_POOL_1_TOKEN1() external view returns (address);

    /// @notice Returns.
    function BASE_POOL_2_TOKEN0() external view returns (address);

    /// @notice Returns.
    function BASE_POOL_2_TOKEN1() external view returns (address);

    /// @notice Returns.
    function QUOTE_POOL_1_TOKEN0() external view returns (address);

    /// @notice Returns.
    function QUOTE_POOL_1_TOKEN1() external view returns (address);

    /// @notice Returns.
    function QUOTE_POOL_2_TOKEN0() external view returns (address);

    /// @notice Returns.
    function QUOTE_POOL_2_TOKEN1() external view returns (address);

    /// @notice Returns.
    function BASE_TOKEN_DECIMALS() external view returns (uint256);

    /// @notice Returns.
    function QUOTE_TOKEN_DECIMALS() external view returns (uint256);

    /// @notice Returns.
    function TWAP_WINDOW() external view returns (uint32);

    /// @notice Returns the price scale factor, calculated at contract creation.
    function SCALE_FACTOR() external view returns (uint256);
}
