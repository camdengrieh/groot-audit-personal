// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED
// Groot reserves all rights on this code. You may NOT copy these contracts.

// WETH = WBNB
// ETH = BNB

// This contract generates Presale01 contracts and registers them in the PresaleFactory.

pragma solidity 0.6.12;

import "./Presale01.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./IERC20.sol";
import "./TransferHelper.sol";
import "./PresaleHelper.sol";

interface IPresaleFactory {
    function registerPresale (address _presaleAddress) external;
    function presaleIsRegistered(address _presaleAddress) external view returns (bool);
}

interface IGrootswapLocker {
    function lockLPToken (address _lpToken, uint256 _amount, uint256 _unlock_date, address payable _referral, bool _fee_in_eth, address payable _withdrawer) external payable;
}

contract PresaleGenerator01 is Ownable {
    using SafeMath for uint256; //@audit - SafeMath is not needed in the contract with solidity 0.8.0
    
    IPresaleFactory public PRESALE_FACTORY;
    IPresaleSettings public PRESALE_SETTINGS;
    
    //@audit Gas - Storage slot packing
    struct PresaleParams {
        uint256 amount;
        uint256 tokenPrice;
        uint256 maxSpendPerBuyer;
        uint256 hardcap;
        uint256 softcap;
        uint256 liquidityPercent;
        uint256 listingRate; // sale token listing price on grootswap
        uint256 startblock;
        uint256 endblock;
        uint256 lockPeriod;
    }

    //@audit-info - The addresses have not been set, make sure they're set in production. Also make the variables they're set to - immutable or constant and declare without constructor.
    constructor() public {
        PRESALE_FACTORY = IPresaleFactory(); 
        PRESALE_SETTINGS = IPresaleSettings();
    }
    
    /**
     * @notice Creates a new Presale contract and registers it in the PresaleFactory.sol.
     */

     //@audit-info - Anyone can call this function and create a presale, is that expected behavior, or do we want to permit Presale owners to create presales?
    function createPresale (
      address payable _presaleOwner,
      IERC20 _presaleToken,
      IERC20 _baseToken,
      address payable _referralAddress,
      uint256[10] memory uint_params
      ) public payable {
        
        PresaleParams memory params;
        params.amount = uint_params[0];
        params.tokenPrice = uint_params[1];
        params.maxSpendPerBuyer = uint_params[2];
        params.hardcap = uint_params[3];
        params.softcap = uint_params[4];
        params.liquidityPercent = uint_params[5];
        params.listingRate = uint_params[6];
        params.startblock = uint_params[7];
        params.endblock = uint_params[8];
        params.lockPeriod = uint_params[9];
        
        if (params.lockPeriod < 4 weeks) {
            params.lockPeriod = 4 weeks;
        }
        
        // Charge ETH fee for contract creation
        require(msg.value == PRESALE_SETTINGS.getEthCreationFee(), 'FEE NOT MET');
        PRESALE_SETTINGS.getEthAddress().transfer(PRESALE_SETTINGS.getEthCreationFee());
        
        if (_referralAddress != address(0)) {
            require(PRESALE_SETTINGS.referrerIsValid(_referralAddress), 'INVALID REFERRAL');
        }
        
        require(params.amount >= 10000, 'MIN DIVIS'); // minimum divisibility
        require(params.endblock.sub(params.startblock) <= PRESALE_SETTINGS.getMaxPresaleLength());
        require(params.tokenPrice.mul(params.hardcap) > 0, 'INVALID PARAMS'); // ensure no overflow for future calculations
        require(params.liquidityPercent >= 300 && params.liquidityPercent <= 1000, 'MIN LIQUIDITY'); // 30% minimum liquidity lock
        
        uint256 tokensRequiredForPresale = PresaleHelper.calculateAmountRequired(params.amount, params.tokenPrice, params.listingRate, params.liquidityPercent, PRESALE_SETTINGS.getTokenFee());
        
        //@audit Gas - Seems more expensive to be calling these initialise functions and updating storage slots that have been intialised at the constructor. Can we not put them all in the constructor and make the variables immutable? if they cannot be changed
        Presale01 newPresale = new Presale01(address(this));
        TransferHelper.safeTransferFrom(address(_presaleToken), address(msg.sender), address(newPresale), tokensRequiredForPresale);
        //@audit-info Calls the presale contract to initialise the presale 
        newPresale.init1(_presaleOwner, params.amount, params.tokenPrice, params.maxSpendPerBuyer, params.hardcap, params.softcap, 
        params.liquidityPercent, params.listingRate, params.startblock, params.endblock, params.lockPeriod);
        //@audit-info Calls the presale contract to initialise the presale 
        newPresale.init2(_baseToken, _presaleToken, PRESALE_SETTINGS.getBaseFee(), PRESALE_SETTINGS.getTokenFee(), PRESALE_SETTINGS.getReferralFee(), PRESALE_SETTINGS.getEthAddress(), PRESALE_SETTINGS.getTokenAddress(), _referralAddress);
        PRESALE_FACTORY.registerPresale(address(newPresale));
    }
    
}