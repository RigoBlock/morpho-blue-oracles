// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IBackGeoOracle} from "../interfaces/IBackGeoOracle.sol";

/// @title RigoblockDataFeedLib
/// @author Rigoblock
/// @custom:contact security@rigoblock.com
/// @notice Library exposing functions to interact with a Rigoblock-compliant feed.
library RigoblockDataFeedLib {
    /// @notice Fetches TWAP price from BackgeOracle using Uniswap V3 OracleLibrary.
    /// @param backGeoOracle The BackgeOracle contract.
    /// @param twapWindow The TWAP window in seconds.
    /// @param baseToken The base token address (collateral).
    /// @param quoteToken The quote token address (loan).
    /// @return tick The Uniswap v4 format pair observation tick.
    function getTick(
        IBackGeoOracle backGeoOracle,
        uint32 twapWindow,
        address baseToken,
        address quoteToken
    ) internal view returns (int24 tick) {
        if (baseToken == quoteToken) {
            return 0;
        }

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapWindow;

        bool isBaseTokenLower = address(baseToken) < address(quoteToken);
        address currency0 = isBaseTokenLower ? baseToken : quoteToken;
        address currency1 = isBaseTokenLower ? quoteToken : baseToken;
        
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(currency0),
            currency1: Currency.wrap(currency1),
            fee: 0,
            tickSpacing: TickMath.MAX_TICK_SPACING,
            hooks: IHooks(address(backGeoOracle))
        });

        // Calculate the mean tick over the twap window.
        (int48[] memory tickCumulatives,) = backGeoOracle.observe(key, secondsAgos);
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        tick = int24(tickCumulativesDelta / int56(uint56(twapWindow)));
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int56(uint56(twapWindow)) != 0)) tick--;

        return isBaseTokenLower ? tick : -tick;
    }
}
