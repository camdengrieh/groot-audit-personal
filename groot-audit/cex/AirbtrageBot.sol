// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @notice Mixin that provide separate owner and admin roles for RBAC
 */


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./tokens/IGrootV2Router02.sol";

contract OrderBook {

    // IGrootV2Router02 private IRouterGroot;
    // IGrootV2Router02 private IRouterBinance;
    address owner;
    constructor(address _owner) {
        owner = _owner;
    }

    event buyPairsData(address _address, uint256 _amount, address[] _pairAAddress, uint256 _transferAmount);

    function sellBuyMarketPriceTokensDC(address[] calldata _path,uint256 _amountIn,uint256 minamount, uint256 _fee, IGrootV2Router02 _binanceAddress) public {
        require(IERC20(_path[0]).balanceOf(msg.sender) >= _amountIn+_fee, "You have insufficient amount");
        uint deadline = block.timestamp + 300 seconds;
        (bool success,bytes memory returndata)=address(_binanceAddress).delegatecall(
            abi.encodeWithSelector(IGrootV2Router02(_binanceAddress).swapExactTokensForTokens.selector,_amountIn,minamount,_path,msg.sender,deadline)
        );
        if(success == false) revert("Insufficient Amount");
        IERC20(_path[0]).transferFrom(msg.sender,owner,_fee);
    }

    function sellBuyMarketPriceTokeAndCoin(address[] calldata _path,uint256 _amountIn,uint256 minamount, IGrootV2Router02 _binanceAddress) public payable{
        require(msg.value >= _amountIn, "You have insufficient amount");
        uint deadline = block.timestamp + 300 seconds;
        // payable(owner).transfer(_fee);
        (bool success,bytes memory returndata)=address(_binanceAddress).delegatecall(
            abi.encodeWithSelector(IGrootV2Router02(_binanceAddress).swapETHForExactTokens.selector,minamount,_path,msg.sender,deadline)
        );
        if(success == false) revert("Insufficient Amount");
    }

      function transferPercentage(uint256 _fee) public payable{
        require(msg.value >= _fee, "You have insufficient amount");
        payable(owner).transfer(_fee);
    }

}