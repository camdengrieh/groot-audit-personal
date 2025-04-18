// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract TradeBot {

    using SafeMath for uint; //@audit Gas - no longer required in Solidity 0.8.0 because it has internal overflow / underflow checks

    address public percentageForwardAddress; //@audit Gas - make immutable as the variable cannot be changed after deployment

    address payable public owner;

    //@audit Gas - Use storage slot packing to save gas 
    struct orderBookStruct{
        address _address;
        uint256 _amountIn;
        uint256 _amountOut;
        address _tokenIn;
        address _tokenOut;
        string _status;
        string _orderType;
    }
    
    constructor(address _percentageForwardAddress) {
        percentageForwardAddress = _percentageForwardAddress;
        owner = payable(msg.sender);
    } 

    event Received(address, uint);
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    mapping(address=>mapping(address=>mapping(address=>orderBookStruct))) public orderBook;

    mapping(address=>mapping(string=>mapping(string=>orderBookStruct))) public orderBookWithNoPair;

    event cancelOrder(address[] pairs, uint256[] pairsAmount, address _user);
    event limitOrderBook(address[] pairs, uint256[] pairsAmount, address indexed userAddress, string ordertype);
    event buySelllimitOrderBook(address userAddressA, address userAddressB, address[] pairAddressA,address[] pairAddressB,uint256[] pairsAmountA,uint256[] pairsAmountB);
    
    
    // limit market items with No Pairs
    
    function setLimitOrder(uint256[] memory _pairsAmount,address[] memory _pairs, string memory _orderType, uint256 _fee, string[] memory _pairsNames) public payable{

        if(keccak256(abi.encodePacked(_pairsNames[0])) == keccak256(abi.encodePacked("BNB"))){
            require(msg.value >= _pairsAmount[0] + _fee, "You have insufficient amount");
            require(orderBook[msg.sender][_pairs[0]][_pairs[1]]._tokenIn != _pairs[0], "You have already set order");
            owner.transfer(_fee);
            payable(address(this)).transfer(_pairsAmount[0]);
            orderBook[msg.sender][_pairs[0]][_pairs[1]] = orderBookStruct(msg.sender,_pairsAmount[0],_pairsAmount[1],_pairs[0],_pairs[1],"pending",_orderType);
        }else{
            require(IERC20(_pairs[0]).balanceOf(msg.sender) >= _pairsAmount[0] + _fee, "You have insufficient amount");
            require(orderBook[msg.sender][_pairs[0]][_pairs[1]]._tokenIn != _pairs[0], "You have already set order");
            IERC20(_pairs[0]).transferFrom(msg.sender,percentageForwardAddress,_fee);
            IERC20(_pairs[0]).transferFrom(msg.sender,address(this),_pairsAmount[0]);
            orderBook[msg.sender][_pairs[0]][_pairs[1]] = orderBookStruct(msg.sender,_pairsAmount[0],_pairsAmount[1],_pairs[0],_pairs[1],"pending",_orderType);
        }
    
        emit limitOrderBook(_pairs,_pairsAmount, msg.sender, _orderType);   
    }

    function buySellLimitOrder(address _userAddressA,address _userAddressB,uint256[] memory _pairsAmountA,address[] memory _pairsA, uint256[] memory _pairsAmountB,address[] memory _pairsB, string[] memory _pairsNames) public {

        if(keccak256(abi.encodePacked(_pairsNames[0])) == keccak256(abi.encodePacked("BNB"))){
            
            require(address(this).balance >= _pairsAmountB[0], "we have insufficient amount of pair A");
            require(IERC20(_pairsB[1]).balanceOf(address(this)) >= _pairsAmountA[0], "we have insufficient amount of pair B");

            require(orderBook[_userAddressB][_pairsB[0]][_pairsB[1]]._address == _userAddressB, "User B has not set order");
            require(orderBook[_userAddressA][_pairsA[0]][_pairsA[1]]._address == _userAddressA, "User A has not set order");

            //transfer amount user A
            uint256 amountB = orderBook[_userAddressB][_pairsB[0]][_pairsB[1]]._amountIn;
            payable(_userAddressA).transfer(amountB);

            //transfer amount user B
            uint256 amountA = orderBook[_userAddressA][_pairsA[0]][_pairsA[1]]._amountIn;
            IERC20(_pairsB[1]).transfer(_userAddressB,amountA);

            delete orderBook[_userAddressA][_pairsA[0]][_pairsA[1]];
            delete orderBook[_userAddressB][_pairsB[0]][_pairsB[1]];
        }
        else{
            require(IERC20(_pairsA[1]).balanceOf(address(this)) >= _pairsAmountB[0], "we have insufficient amount of pair A");
            require(IERC20(_pairsB[1]).balanceOf(address(this)) >= _pairsAmountA[0], "we have insufficient amount of pair B");

            require(orderBook[_userAddressB][_pairsB[0]][_pairsB[1]]._address == _userAddressB, "User B has not set order");
            require(orderBook[_userAddressA][_pairsA[0]][_pairsA[1]]._address == _userAddressA, "User A has not set order");

            //transfer amount user A
            uint256 amountA = orderBook[_userAddressA][_pairsA[0]][_pairsA[1]]._amountIn;
            IERC20(_pairsB[1]).transfer(_userAddressA,amountA);

            //transfer amount user B
            uint256 amountB = orderBook[_userAddressB][_pairsB[0]][_pairsB[1]]._amountIn;
            IERC20(_pairsA[1]).transfer(_userAddressB,amountB);

            delete orderBook[_userAddressA][_pairsA[0]][_pairsA[1]];
            delete orderBook[_userAddressB][_pairsB[0]][_pairsB[1]];

        }

        emit buySelllimitOrderBook(_userAddressA,_userAddressB,_pairsA,_pairsB,_pairsAmountA,_pairsAmountB);
    }

   // cancel order

    function orderCancel(address[] memory _pairs, uint256[] memory _amount, string[] memory _pairsNames) public {

        if(keccak256(abi.encodePacked(_pairsNames[0])) == keccak256(abi.encodePacked("BNB"))){
            require(address(this).balance >= orderBook[msg.sender][_pairs[0]][_pairs[1]]._amountIn, "we have insufficient amount please try again later");

            require(orderBook[msg.sender][_pairs[0]][_pairs[1]]._address == msg.sender,"You have not set order");
            uint256 amountA = orderBook[msg.sender][_pairs[0]][_pairs[1]]._amountIn;
            payable(msg.sender).transfer(amountA);
            delete orderBook[msg.sender][_pairs[0]][_pairs[1]];
        }
        else{
            require(IERC20(_pairs[0]).balanceOf(address(this)) >= orderBook[msg.sender][_pairs[0]][_pairs[1]]._amountIn, "we have insufficient amount please try again later");

            require(orderBook[msg.sender][_pairs[0]][_pairs[1]]._address == msg.sender,"You have not set order");
            uint256 amountA = orderBook[msg.sender][_pairs[0]][_pairs[1]]._amountIn;
            IERC20(_pairs[0]).transferFrom(address(this),msg.sender,amountA);
            delete orderBook[msg.sender][_pairs[0]][_pairs[1]];
        }
        
        emit cancelOrder(_pairs,_amount,msg.sender);
    }


    function updateOwnerAddress(address _address) public {
        require(owner == msg.sender,"you are not owner");
        owner = payable(_address);
    }   
}
