// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

/// @title RigoblockDataFeedLib
/// @author Rigoblock
/// @custom:contact security@rigoblock.com
/// @notice Library exposing functions to interact with a Rigoblock-compliant feed.
library RigoblockDataFeedLib {
    /// @notice Fetches TWAP price from BackgeOracle using Uniswap V3 OracleLibrary.
    /// @param oracle The BackgeOracle contract.
    /// @param poolKey The pool identifier (token0, token1, fee, hook, salt).
    /// @param twapWindow The TWAP window in seconds.
    /// @param baseToken The base token address (collateral).
    /// @param quoteToken The quote token address (loan).
    /// @return price The price of 1 unit of base token in quote token, in quote token decimals.
    function getTick(
        IBackGeoOracle backGeoOracle,
        uint32 twapWindow,
        address baseToken,
        address quoteToken
    ) internal view returns (int24 tick) {
        // TODO: move in constructor, store as constant (private)
        require(twapWindow > 0, "Invalid TWAP window")

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapWindow;
        
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(baseToken),
            currency1: Currency.wrap(quoteToken),
            fee: 0,
            tickSpacing: TickMath.MAX_TICK_SPACING,
            hooks: IHooks(address(backGeoOracle))
        });

        // Calculate the mean tick over the twap window.
        (int48[] memory tickCumulatives,) = backGeoOracle.observe(key, secondsAgos);
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        int24 tick = int24(tickCumulativesDelta / int56(uint56(twapWindow)));
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int56(uint56(twapWindow)) != 0)) tick--;

        // assert tick is valid? is this needed?
        assert(tick >= MIN_TICK && tick <= MAX_TICK);
    }
}
