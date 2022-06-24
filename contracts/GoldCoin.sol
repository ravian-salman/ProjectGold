//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "contracts/IGoldCoin.sol";
import "contracts/ISwap.sol";
import "contracts/IStabilityModule.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';

contract Chrysus is ERC20, IGoldCoin {
    
    uint256 liquidationRatio; 
    uint256 collateralizationRatio; 
    uint256 ethBalance;
    uint256 ethFees;

    address[] approvedTokens;

    AggregatorV3Interface oracleCHC;
    AggregatorV3Interface oracleXAU;

    ISwapRouter public immutable swapRouter;

    address governance;
    address treasury;
    address swapSolution;
    address stabilityModule;

    struct Collateral {
        bool approved;
        uint256 balance;
        uint256 fees;
        AggregatorV3Interface oracle;
    }

    struct Deposit {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address=>mapping(address=>Deposit)) userDeposits; //user -> token address -> Deposit struct

    mapping(address=>Collateral) approvedCollateral;

    constructor(address _daiAddress, address _oracleDAI, address _oracleETH,
                address _oracleCHC, address _oracleXAU,
                address _governance,
                ISwapRouter _swapRouter)
                 ERC20("Chrysus", "CHC") {

        liquidationRatio = 110;

        //add Dai as approved collateral
        approvedCollateral[_daiAddress].approved = true;

        //represent eth deposits as address 0 (a placeholder)
        approvedCollateral[address(0)].approved = true;

        approvedTokens.push(_daiAddress);
        approvedTokens.push(address(0));

        //connect to oracles
        approvedCollateral[_daiAddress].oracle = AggregatorV3Interface(_oracleDAI);
        approvedCollateral[address(0)].oracle = AggregatorV3Interface(_oracleETH);

        oracleCHC = AggregatorV3Interface(_oracleCHC);
        oracleXAU = AggregatorV3Interface(_oracleXAU);

        governance = _governance;

        swapRouter = _swapRouter;

    }

    function addCollateralType(address _collateralType) override external {

        require(msg.sender == governance, "can only be called by CGT governance");
        require(approvedCollateral[_collateralType].approved == false, "this collateral type already approved");
        
        approvedTokens.push(_collateralType);
        approvedCollateral[_collateralType].approved = true;
    
    }

    function collateralRatio() public view override returns(uint256) {
        
        //get CHC price using oracle
        (, int priceCHC, , ,) = oracleCHC.latestRoundData();

        //multiply CHC price * CHC total supply
        uint256 valueCHC = uint(priceCHC) * totalSupply();

        address collateralType;

        int collateralPrice;
        //declare collateral sum
        uint256 totalcollateralValue;
        //declare usd price
        uint256 singleCollateralValue;

        //for each collateral type...
        for (uint i; i < approvedTokens.length; i++) {

            collateralType = approvedTokens[i];
            //read oracle price
            (, collateralPrice, , ,) = approvedCollateral[collateralType].oracle.latestRoundData();

            //multiply collateral amount in contract * oracle price to get USD price
            singleCollateralValue = approvedCollateral[collateralType].balance * uint(collateralPrice);
            //add to sum
            totalcollateralValue += singleCollateralValue;

        }

        //divide value of CHC * 100 by value of collateral sum / 10000
        return valueCHC * 100 / totalcollateralValue / 1000;

    }

    function depositCollateral(address _collateralType, uint256 _amount) override payable public {

        //10% of initial collateral collected as fee
        uint256 ethFee = 10 * 100 * msg.value / 10000;
        uint256 tokenFee = 10 * 100 * _amount / 10000;

        //increase fee balance
        approvedCollateral[address(0)].fees += ethFee;

        if(_collateralType != address(0)) {
            approvedCollateral[_collateralType].fees += tokenFee;
        }
        // //catch ether deposits
        // userTokenDeposits[msg.sender][address(0)].amount += msg.value - ethFee;

        //catch token deposits
        userDeposits[msg.sender][_collateralType].amount += _amount - tokenFee;

        //incrase balance in approvedColateral mapping
        approvedCollateral[_collateralType].balance += _amount - tokenFee;


        //read CHC/USD oracle
        (, int priceCHC, , ,) = oracleCHC.latestRoundData();

        //read XAU/USD oracle
        (, int priceXAU, , ,) = oracleXAU.latestRoundData();

        //create CHC/XAU ratio
        uint256 ratio = uint(priceCHC * 100 / priceXAU / 10000);

        //read collateral price to calculate amount of CHC to mint
        (, int priceCollateral, , ,) = approvedCollateral[_collateralType].oracle.latestRoundData();
        uint256 amountToMint = (_amount - tokenFee) * uint(priceCollateral) * 100 / uint(priceCHC) / 10000;

        //divide amount minted by CHC/XAU ratio
        amountToMint = amountToMint * 100 / ratio / 10000;

        //update collateralization ratio
        collateralizationRatio = collateralRatio();

        //approve and transfer from token (if address is not address 0)
        if (_collateralType != address(0)) {
            IERC20(_collateralType).approve(address(this), _amount);
        }
        //mint new tokens (mint _amount * CHC/XAU ratio)
        _mint(msg.sender, amountToMint);


    }
    
    function liquidate(address _collateralType) external {

        // //require collateralizaiton ratio is under liquidation ratio

        // //sell collteral on swap solution above price of XAU

        // //sell collateral on uniswap above price of XAU

        // TransferHelper.safeTransferFrom(_collateralType,
        // msg.sender,
        // address(this),
        // userDeposits[msg.sender][_collateralType].amount
        // );

        // TransferHelper.safeApprove(_collateralType, address(swapRouter), userDeposits[msg.sender][_collateralType].amount);

        // // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        // ISwapRouter.ExactInputSingleParams memory params =
        //     ISwapRouter.ExactInputSingleParams({
        //         tokenIn: DAI,
        //         tokenOut: WETH9,
        //         fee: 3000,
        //         recipient: msg.sender,
        //         deadline: block.timestamp,
        //         amountIn: amountIn,
        //         amountOutMinimum: 0,
        //         sqrtPriceLimitX96: 0
        //     });

        // // The call to `exactInputSingle` executes the swap.
        // amountOut = swapRouter.exactInputSingle(params);
        

        // //auction off the rest
    }

    //withdraws collateral in exchange for a given amount of CHC tokens
    function withdrawCollateral(address _collateralType, uint256 _amount) override external {

        //transfer CHC back to contract
        transfer(address(this), _amount);

        //convert value of CHC into value of collateral
        //multiply by CHC/USD price
        (, int priceCHC, , ,) = oracleCHC.latestRoundData();
        (, int priceCollateral, , ,) = approvedCollateral[_collateralType].oracle.latestRoundData();
        //divide by collateral to USD price
        uint256 collateralToReturn = _amount * uint(priceCHC) * 100 / uint(priceCollateral) / 10000;

        //burn the CHC amount
        _burn(msg.sender, _amount);

        //update collateralization ratio
        collateralizationRatio = collateralRatio();

        //require that the transfer to msg.sender of collat amount is successful
        if (_collateralType == address(0)) {
            (bool success, ) = msg.sender.call{value: collateralToReturn}("");
            require(success, "return of ether collateral was unsuccessful");
        } else {
            require(IERC20(_collateralType).transfer(msg.sender, collateralToReturn));
        }
    }

    function withdrawFees() override external {

        //30% to treasury
        //20% to swap solution for liquidity
        //50% to stability module

        //iterate through collateral types

        address collateralType;

        for (uint i; i < approvedTokens.length; i++) {

            collateralType = approvedTokens[i];

            //send as ether if ether
            if (collateralType == address(0)) {
                
                (bool success, ) = treasury.call{value: approvedCollateral[collateralType].fees * 3000 / 10000}("");
                (success, ) = swapSolution.call{value: approvedCollateral[collateralType].fees * 2000 / 10000}("");
                (success, ) = stabilityModule.call{value: approvedCollateral[collateralType].fees * 5000 / 10000}("");

                approvedCollateral[collateralType].fees = 0;

            } else {
                //transfer as token if token
                transferFrom(address(this), treasury, approvedCollateral[collateralType].fees * 3000 / 10000);

                IERC20(collateralType).approve(swapSolution, approvedCollateral[collateralType].fees * 2000 / 10000);
                ISwap(swapSolution).addLiquidity(collateralType, approvedCollateral[collateralType].fees * 2000 / 10000);

                IERC20(collateralType).approve(stabilityModule, approvedCollateral[collateralType].fees * 5000 / 10000);
                IStabilityModule(swapSolution).addTokens(collateralType, approvedCollateral[collateralType].fees * 2000 / 10000);

                approvedCollateral[collateralType].fees = 0;
            }

        }
    }

    
    //for depositing ETH as collateral
    receive() payable external {

        depositCollateral(address(0), msg.value);

    }

}
