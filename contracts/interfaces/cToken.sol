pragma solidity ^0.5.2;

interface cToken {
    function mint(uint mintAmount) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external  returns (uint);
    function exchangeRateCurrent() external returns (uint);
    function balanceOf(address account) external view returns (uint);
}
