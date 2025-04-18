// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// WETH = WBNB
// ETH = BNB

/**
    This contract creates the lock on behalf of each presale. This contract will be whitelisted to bypass the flat rate 
    ETH fee. Please do not use the below locking code in your own contracts as the lock will fail without the ETH fee
*/

pragma solidity 0.6.12;

import "./Ownable.sol";
import "./TransferHelper.sol";
import "./IERC20.sol";

interface IPresaleFactory {
    function registerPresale (address _presaleAddress) external;
    function presaleIsRegistered(address _presaleAddress) external view returns (bool);
}

interface IGrootswapLocker {
    function lockLPToken (address _lpToken, uint256 _amount, uint256 _unlock_date, address payable _referral, bool _fee_in_eth, address payable _withdrawer) external payable;
}

interface IGrootswapFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IGrootswapPair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

contract PresaleLockForwarder is Ownable {
    
    IPresaleFactory public PRESALE_FACTORY;
    // @audit Grootswap Locker and Factory do not exist in 
    // the entire master repo
    IGrootswapLocker public GROOTSWAP_LOCKER;
    IGrootswapFactory public GROOTSWAP_FACTORY;
    
    //@audit-info - The addresses have not been set, make sure they're set in production. Also make the variables they're set to - immutable or constant and declare without constructor.

    constructor() public {
        PRESALE_FACTORY = IPresaleFactory();
        GROOTSWAP_LOCKER = IGrootswapLocker();
        GROOTSWAP_FACTORY = IGrootswapFactory();
    }

    /**
        Send in _token0 as the PRESALE token, _token1 as the BASE token (usually WETH) for the check to work. As anyone can create a pair,
        and send WETH to it while a presale is running, but no one should have access to the presale token. If they do and they send it to 
        the pair, scewing the initial liquidity, this function will return true
    */
    function grootswapPairIsInitialised (address _token0, address _token1) public view returns (bool) {
        address pairAddress = GROOTSWAP_FACTORY.getPair(_token0, _token1);
        if (pairAddress == address(0)) {
            return false;
        }
        uint256 balance = IERC20(_token0).balanceOf(pairAddress);
        //@audit Gas - Using !0 instead of > 0 can be cheaper in gas in some versions of solidity
        if (balance > 0) {
            return true;
        }
        return false;
    }
    
    function lockLiquidity (IERC20 _baseToken, IERC20 _saleToken, uint256 _baseAmount, uint256 _saleAmount, uint256 _unlock_date, address payable _withdrawer) external {
        //@audit-info Ensure that the correct presale contracts can be registered in the factory
        require(PRESALE_FACTORY.presaleIsRegistered(msg.sender), 'PRESALE NOT REGISTERED');
        address pair = GROOTSWAP_FACTORY.getPair(address(_baseToken), address(_saleToken));
        if (pair == address(0)) {
            GROOTSWAP_FACTORY.createPair(address(_baseToken), address(_saleToken));
            pair = GROOTSWAP_FACTORY.getPair(address(_baseToken), address(_saleToken));
        }
        
        TransferHelper.safeTransferFrom(address(_baseToken), msg.sender, address(pair), _baseAmount);
        TransferHelper.safeTransferFrom(address(_saleToken), msg.sender, address(pair), _saleAmount);
        IGrootswapPair(pair).mint(address(this));
        uint256 totalLPTokensMinted = IGrootswapPair(pair).balanceOf(address(this));
        require(totalLPTokensMinted != 0 , "LP creation failed");
    
        TransferHelper.safeApprove(pair, address(GROOTSWAP_LOCKER), totalLPTokensMinted);
        // @audit ternary operator test
        //@audit-info Unlock date is at least - Saturday, 20 November 2286 17:46:39
        uint256 unlock_date = _unlock_date > 9999999999 ? 9999999999 : _unlock_date;

        //@audit This requires the GrootswapLocker contract, its not visible in the repository 
        GROOTSWAP_LOCKER.lockLPToken(pair, totalLPTokensMinted, unlock_date, address(0), true, _withdrawer);
    }
    
}