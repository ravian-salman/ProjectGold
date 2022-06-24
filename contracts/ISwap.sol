pragma solidity ^0.8.0;

interface ISwap {

    function addLiquidity(address _collateralType, uint256 _amount) external payable;
 
}