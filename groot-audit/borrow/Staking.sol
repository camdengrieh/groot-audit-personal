//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

contract USDGStaking  {

    // Library usage
    using SafeERC20 for IERC20;
    using SafeMath for uint256; //@audit Gas - SafeMath is not needed for Solidity version 0.8.0 and above
    // Contract owner
    address public owner; //@audit Info - Use Openzeppelin Ownable.sol?
    // Store the balance of each user
    mapping (address => uint256) public userBalances;

        
    //@audit - This is vague, the values assigned to this variable appear to be block.timestamps, word the variables better
    // Map to store the information of stakers
    mapping(address => uint256) public stakers;

    // Store the amount of tokens received by each user
    mapping (address => uint256) public tokensReceived;


    // The ERC20 token contract address
    IERC20 public rewardTokenAddress;
    // The amount of tokens to be received per 100 USDT
    uint256 public tokensPer100USDT;

    
    // Stable Coin USDG 
    IERC20 public USDG ; //@audit Gas - Make immutable if it is set in the constructor and not changed

    uint256 public timePeriod = 30 days;


    // Event to emit when a user stakes
    event Staked(address staker, uint256 amount);


     // Event to emit when a user unstakes
    event Unstaked(address staker, uint256 amount);


    // Event to notify token rewards
    event TokenReward(address recipient, uint256 amount);


    modifier onlyOwner() {
        require(msg.sender == owner, "Message sender must be the contract's owner.");
        _;
    }

    // Constructor to set the ERC20 token contract address and the tokens per 100 USDT
    constructor(IERC20 _rootTokenAddress,IERC20 _depositorUSDGToken, uint256 _tokensPer100USDT) public {
        owner = msg.sender ; 
        rewardTokenAddress = _rootTokenAddress;
        USDG = _depositorUSDGToken;
        tokensPer100USDT = _tokensPer100USDT;
    }


      function setTimestamp(uint256 _timePeriodInSeconds) public onlyOwner  {
        timePeriod = _timePeriodInSeconds ;
    }


      function setReward(uint256 _tokensPer100USDT) public onlyOwner  {
        tokensPer100USDT = _tokensPer100USDT ;
    }

    //@audit typo - Function to deposit USDG?
    // Function to deposit USDT 
    function stake(uint256 amount) public payable {
        //@audit Gas - Use != 0 instead of > 0
        require(USDG.balanceOf(msg.sender) > 0,"INSUFFICIENT BALANCE"); //@audit Gas - If insufficient, this will revert anyway
        require(amount >= 100000000000000000000, "Amount must be greater 100 USDG");
         // Update the staker's information in the mapping
        stakers[msg.sender] = block.timestamp;

        // Update the user balance
        //@audit Gas - Use unchecked
        unchecked{
        userBalances[msg.sender] += amount;
        }

        USDG.safeTransferFrom(msg.sender, address(this), amount);
    }

    // Function to claim the reward
    //@audit Critical - reentrancy attack - balances are updated after the transfer of the reward token

    function unStake() public {
        require(userBalances[msg.sender] >= 100000000000000000000,"UNAUTHORISED NOT A STAKER");
        // Check if the staker has staked for more than a month
        uint256 stakedTimestamp = stakers[msg.sender];

        require(block.timestamp >= stakedTimestamp + timePeriod, "YOU NEED TO WAIT FOR A MONTH");

        // Calculate the number of tokens to be received
        //@audit Gas - Use unchecked
        unchecked{
        uint256 tokens = userBalances[msg.sender] / 100 * tokensPer100USDT;  
        }

        // Update the tokens received by the user
        tokensReceived[msg.sender] += tokens;

         // Emit the TokenReward event
        emit TokenReward(msg.sender, tokens);

        // Transfer  reward token to the staker
        IERC20 rewardToken = IERC20(rewardTokenAddress);
        rewardToken.transfer(msg.sender, tokens);

        USDG.transfer(msg.sender,userBalances[msg.sender]);
   
        // Emit the Unstaked event
        emit Unstaked(msg.sender, tokens);

        userBalances[msg.sender] = 0;

        //@audit-info If this reverts when already deleted, then this will prevent the reentrancy
        delete stakers[msg.sender];

    }   
}

