// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @notice Mixin that provide separate owner and admin roles for RBAC
 */


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./tokens/IGrootV2Router02.sol";

contract OrderBook {

    //@audit-info Low - Confusing comments? Should be removed if not relevant
    // IGrootV2Router02 private IRouterGroot;
    // IGrootV2Router02 private IRouterBinance;
    
    //@audit - High - Owner can't be changed -  ownership can't be transferred
    //@audit - If it is not supposed to be changed, then make it immutable
    address owner; 
    constructor(address _owner) {
        owner = _owner;
    }

    event buyPairsData(address _address, uint256 _amount, address[] _pairAAddress, uint256 _transferAmount);
    //@audit - Should the fee be a state variable? This could cause input validation issues
    //@audit - No access control, anyone can call this function
    //@audit - Ambigous parameter name, should be changed - _binanceAddress? - This address should be the GrootDex Router address or any other routers to be used like Uniswap, Sushiswap etc
    // continued. - Set this as a state variable, so mistakes can't be made while calling the function with incorrect input data
    function sellBuyMarketPriceTokensDC(address[] calldata _path,uint256 _amountIn,uint256 minamount, uint256 _fee, IGrootV2Router02 _binanceAddress) public {
        //Check balance of user
        require(IERC20(_path[0]).balanceOf(msg.sender) >= _amountIn+_fee, "You have insufficient amount");

        uint deadline = block.timestamp + 300 seconds;

        (bool success,bytes memory returndata)=address(_binanceAddress).delegatecall(
            abi.encodeWithSelector(IGrootV2Router02(_binanceAddress).swapExactTokensForTokens.selector,_amountIn,minamount,_path,msg.sender,deadline)
        );
        if(success == false) revert("Insufficient Amount"); //@audit This could fail for other reasons as well, not just insufficient amount
        IERC20(_path[0]).transferFrom(msg.sender,owner,_fee); //@audit - Will fail if not approved
    }

    //@audit - No access control, anyone can call this function
    //@audit - Should the fee be a state variable? This could cause input validation issues
    //@audit-info - Typo in function name - should be sellBuyMarketPriceTokenAndCoin?
    //@audit Low - No fees are being applied, however the tokenToToken swap does have a fee?
    function sellBuyMarketPriceTokeAndCoin(address[] calldata _path,uint256 _amountIn,uint256 minamount, IGrootV2Router02 _binanceAddress) public payable{
        require(msg.value >= _amountIn, "You have insufficient amount"); //@audit - C
        uint deadline = block.timestamp + 300 seconds;
        // payable(owner).transfer(_fee);
        (bool success,bytes memory returndata)=address(_binanceAddress).delegatecall(
            abi.encodeWithSelector(IGrootV2Router02(_binanceAddress).swapETHForExactTokens.selector,minamount,_path,msg.sender,deadline)
        );
        if(success == false) revert("Insufficient Amount");
    }

    //@audit - No access control, anyone can call this function
    //@audit Unused function
    //@audit-info Looks like it transfers tokens from the contract to the owner? Funds are never transferred to the contract, but if they are then use receieve() function
      function transferPercentage(uint256 _fee) public payable{
        require(msg.value >= _fee, "You have insufficient amount");
        payable(owner).transfer(_fee);
    }

}