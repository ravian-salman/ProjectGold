pragma solidity ^0.8.0;

interface IStabilityModule {

    function addTokens(address _collateralType, uint256 _amount) external payable;
 
}