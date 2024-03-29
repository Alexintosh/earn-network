pragma solidity ^0.5.2;

interface iToken {
    function mint(address receiver, uint256 depositAmount) external returns (uint256 mintAmount);

    function burn(
        address receiver,
        uint256 burnAmount)
        external
        returns (uint256 loanAmountPaid);

    function claimLoanToken()
        external
        returns (uint256 claimedAmount);

    function donateAsset(
        address tokenAddress)
        external
        returns (bool);

    function assetBalanceOf(
        address _owner)
        external
        view
        returns (uint256);

    function tokenPrice()
        external
        view
        returns (uint256 price);
}