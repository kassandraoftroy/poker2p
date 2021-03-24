// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title CErc20 interface for Compound ERC20 assets
 */
interface ICERC20 {
    function mint(uint256 mintAmount) external returns (uint256);
    function redeem(uint256 redeemTokens) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
    function borrow(uint256 borrowAmount) external returns (uint256);
    function repayBorrow(uint256 repayAmount) external returns (uint256);
    function balanceOfUnderlying(address account) external view returns (uint256);
    function exchangeRateCurrent() external view returns (uint256);
}