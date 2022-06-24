pragma solidity ^0.8.4;

interface IGoldCoin {

    //for recalculating the collateralRatio
    function collateralRatio() external view returns(uint256);

    //should incur 10% origination fee
    function depositCollateral(address _collateralType, uint256 _amount) payable external;

    //
    function withdrawCollateral(address _collateralType, uint256 _amount) external;
    // function liquidate() external;

    function addCollateralType(address _collateralType) external;

    function withdrawFees() external;

}