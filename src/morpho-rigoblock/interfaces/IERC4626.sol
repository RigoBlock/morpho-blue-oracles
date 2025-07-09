// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface IERC4626 {
    function asset() external view returns (address);
    function convertToAssets(uint256) external view returns (uint256);
}
