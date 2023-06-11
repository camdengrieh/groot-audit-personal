// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract multiSignatureWallet is Ownable {
    
    //@audit Gas optimization - Initialisation of default values
    //@audit Gas optimization - Use Storage slot packing to save gas
    uint256 public totalAddedOwners = 0;

    //@audit Is this state variable needed, because it can be changed arbitrarily by the owner anyway?
    //@audit-info - typo? totalAllowedOwners or totalAllowedSigners is less confusing
    uint256 public totalAllowOwners = 0;
    //@audit-info - typo? minimumAllowedOwners or minimumAllowedSigners is less confusing
    uint256 public minimumAllowOwnersForTransactions = 0;
    
    //@audit Gas - bytes32 is cheaper than string
    //@audit Gas - This could be immutable as it is not changed
    string public safeWalletName; //@audit-info Initialise the name of the wallet here instead and make it constabt?

    receive() external payable {}

    struct WalletsWithSign {
        address walletAddress;
        bool isAllow;
    }

    mapping (uint256 => WalletsWithSign) public setWallets;

    event tokenTransfer(address toAddress,uint256 amount,address from, address contractAddress);
    event balanceTransfer(address toAddress,uint256 amount,address from);

    constructor(address[] memory _walletAddress, uint256 _minimumAllowOwners, string memory _safeWalletName){
        safeWalletName = _safeWalletName;
        minimumAllowOwnersForTransactions = _minimumAllowOwners;

        totalAllowOwners = _walletAddress.length;
        //@audit Gas optimization - Initialisation of default values
        uint256 addedUsers = 0; 
        //@audit Gas Optimzation - Initialisation of default values
        //@audit Gas Optimzation - Use pre increment instead of post increment
        for (uint i = 0; i < _walletAddress.length; i++) {
            //@audit Gas Optimzation - Simply addedUsers++ instead of addedUsers = addedUsers + 1
            //@audit Gas Optimzation - Use unchecked to save gas
            addedUsers = addedUsers + 1; 
            setWallets[addedUsers] = WalletsWithSign(_walletAddress[i],false);
        }
        totalAddedOwners = addedUsers;
    }

    //@audit-info - Not sure why this is needed
    function changeName(string memory _safeWalletName) public onlyOwner{
        safeWalletName = _safeWalletName;
    }


    function addWalletAddress(address _address) public onlyOwner{
        require(totalAddedOwners <= totalAllowOwners,"multisign: you can't add more wallets");
        //@audit Gas optimization - Use totalAddedOwners++ instead of totalAddedOwners = totalAddedOwners + 1
        //@audit Gas optimization - Use unchecked to save gas
        totalAddedOwners = totalAddedOwners + 1;
        setWallets[totalAddedOwners] = WalletsWithSign(_address,false);
    }

    function removedWalletAddress(address _address) public onlyOwner{
        //@audit Gas - Use pre-incrementation
        for (uint256 i = 1; i <= totalAllowOwners; i++) {
            if(setWallets[i].walletAddress == _address) delete setWallets[i];
        }
    }

    function setMaxAllowWallets(uint256 _allowWallets) public onlyOwner{
        totalAllowOwners = _allowWallets;
    }

    function setMinAllowWallets(uint256 _allowWallets) public onlyOwner{
        minimumAllowOwnersForTransactions = _allowWallets;
    }

    //@audit-info Function name is confusing
    //@audit High - Missing index 0

    function getWalletHavingAllow(address _address) public view returns (WalletsWithSign memory wallets) {
        //@audit Gas - Use pre-incrementation
        for (uint256 i = 1; i <= totalAllowOwners; i++) {
            if(setWallets[i].walletAddress == _address) return setWallets[i];
        }
    }

    function getAllWallets() public view returns (WalletsWithSign[] memory wallets){
        WalletsWithSign[] memory _myWalletsWithSign = new WalletsWithSign[](totalAllowOwners);
        //@audit Gas - Use pre-incrementation
        //@audit High - Missing index 0
        for (uint256 i = 1; i <= totalAllowOwners; i++) {
            _myWalletsWithSign[i] = setWallets[i];
        }
        return _myWalletsWithSign;
    }
    
    //@audit-info Function name is confusing
    function getAllWalletsHavingAllow() public view returns (WalletsWithSign[] memory) {
        WalletsWithSign[] memory _myWalletsWithSign = new WalletsWithSign[](totalAllowOwners);
        //@audit Gas - Use pre-incrementation
        //@audit High - Missing index 0
        for (uint256 i = 1; i <= totalAllowOwners; i++) {
            if(setWallets[i].isAllow == true){
             _myWalletsWithSign[i] = setWallets[i];
            }
        }
        return _myWalletsWithSign;
    }

    //@audit-info Function name is confusing
    function getAllWalletsHavingDisallow() public view returns (WalletsWithSign[] memory) {
        WalletsWithSign[] memory _myWalletsWithSign = new WalletsWithSign[](totalAllowOwners);
        //@audit Gas - Use pre-incrementation
        //@audit High - Missing index 0
        for (uint256 i = 1; i <= totalAllowOwners; i++) {
            if(setWallets[i].isAllow == false){
             _myWalletsWithSign[i] = setWallets[i];
            }
        }
        return _myWalletsWithSign;
    }

    function getCountAllowOwners() public view returns (uint256){
        uint256 reNumber = 0; //@audit Gas optimization - Initialisation of default values
        //@audit Gas - Use pre-incrementation
        //@audit High - Missing index 0
        for (uint256 i = 1; i <= totalAllowOwners; i++) {
            //@audit Gas - Use reNumber++ instead of reNumber = reNumber + 1
            //@audit Gas - Use unchecked to save gas
            if(setWallets[i].isAllow == true) reNumber = reNumber + 1;
        }
        return reNumber;
    }
    
    //@audit-info Function name is confusing
    function checkHaveOwner() internal view returns (bool){
        //@audit Gas - Use pre-incrementation
        //@audit High - Missing index 0
        for (uint256 i = 1; i <= totalAllowOwners; i++) {
            if(setWallets[i].walletAddress == msg.sender) return true;
        }
        return false;
    }

    modifier allowOwners() {
        //@audit Critical - This does not do what is intended. This can pass and allow arbitrary external calls to be made
        require(getCountAllowOwners() >= minimumAllowOwnersForTransactions,"All Owners Not Allow"); //@audit-info Typo - Require string "All Owners Not Allowed"
        _;
    }

    //@audit-info Function name is confusing -  hasOwnerRole would be better?
    modifier haveOwner() {
        //@audit-info Require string is confusing
        require(checkHaveOwner(),"You Have Not Added In Owner List");
        _;
    }

    function changeApprovelStatus(bool status) public haveOwner{
        //@audit Gas - Use pre-incrementation
        for (uint256 i = 1; i <= totalAllowOwners; i++) {
            if(setWallets[i].walletAddress == msg.sender) setWallets[i].isAllow = status;
        }
    }

    function changeStatusAfterTransfer(bool status) public haveOwner{
        //@audit Gas - Use pre-incrementation
        for (uint256 i = 1; i <= totalAllowOwners; i++) {
           setWallets[i].isAllow = status;
        }
    }

    //@audit Critical - Anyone can call the function, the modifier allowOwners does not prevent this
    function transferTokensWithAllowOwners(address _contractAddress,address _toAddress, uint256 _amount) public allowOwners{
        IERC20(_contractAddress).transfer(_toAddress,_amount);
        changeStatusAfterTransfer(false);
        emit tokenTransfer(_toAddress,_amount,msg.sender, _contractAddress);
    }
    
    //@audit Critical - Anyone can call the function, the modifier allowOwners does not prevent this
    function transferBalanceWithAllowOwners(address _toAddress, uint256 _amount) public payable allowOwners{
        payable(_toAddress).transfer(_amount);
        changeStatusAfterTransfer(false);
        emit balanceTransfer(_toAddress,_amount,msg.sender);
    }

    //@audit High - Use transferFrom() instead of transfer()
    function addedTokens(address _contractAddress, uint256 _amount) public{
        IERC20(_contractAddress).transfer(address(this),_amount); //@audit - Tokens are not going anywhere, just being transferred from the contract to itself
        emit tokenTransfer(address(this),_amount,msg.sender, _contractAddress);
    }

    //@audit Use receive() or fallback() instead of a function
    function addBalance(uint256 _amount) public payable{
        payable(address(this)).transfer(_amount);
        emit balanceTransfer(address(this),_amount,msg.sender);
    }

}
