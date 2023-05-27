// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract multiSignatureWallet is Ownable {
    
    uint256 public totalAddedOwners = 0;
    uint256 public totalAllowOwners = 0;
    uint256 public minimumAllowOwnersForTransactions = 0;
    string public safeWalletName;

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
        uint256 addedUsers = 0;
        for (uint i = 0; i < _walletAddress.length; i++) {
            addedUsers = addedUsers + 1;
            setWallets[addedUsers] = WalletsWithSign(_walletAddress[i],false);
        }
        totalAddedOwners = addedUsers;
    }

    function changeName(string memory _safeWalletName) public onlyOwner{
        safeWalletName = _safeWalletName;
    }

    function addWalletAddress(address _address) public onlyOwner{
        require(totalAddedOwners <= totalAllowOwners,"multisign: you can't add more wallets");
        totalAddedOwners = totalAddedOwners + 1;
        setWallets[totalAddedOwners] = WalletsWithSign(_address,false);
    }

    function removedWalletAddress(address _address) public onlyOwner{
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

    function getWalletHavingAllow(address _address) public view returns (WalletsWithSign memory wallets) {
        for (uint256 i = 1; i <= totalAllowOwners; i++) {
            if(setWallets[i].walletAddress == _address) return setWallets[i];
        }
    }

    function getAllWallets() public view returns (WalletsWithSign[] memory wallets){
        WalletsWithSign[] memory _myWalletsWithSign = new WalletsWithSign[](totalAllowOwners);
        for (uint256 i = 1; i <= totalAllowOwners; i++) {
            _myWalletsWithSign[i] = setWallets[i];
        }
        return _myWalletsWithSign;
    }

    function getAllWalletsHavingAllow() public view returns (WalletsWithSign[] memory) {
        WalletsWithSign[] memory _myWalletsWithSign = new WalletsWithSign[](totalAllowOwners);
        for (uint256 i = 1; i <= totalAllowOwners; i++) {
            if(setWallets[i].isAllow == true){
             _myWalletsWithSign[i] = setWallets[i];
            }
        }
        return _myWalletsWithSign;
    }

    function getAllWalletsHavingDisallow() public view returns (WalletsWithSign[] memory) {
        WalletsWithSign[] memory _myWalletsWithSign = new WalletsWithSign[](totalAllowOwners);
        for (uint256 i = 1; i <= totalAllowOwners; i++) {
            if(setWallets[i].isAllow == false){
             _myWalletsWithSign[i] = setWallets[i];
            }
        }
        return _myWalletsWithSign;
    }

    function getCountAllowOwners() public view returns (uint256){
        uint256 reNumber = 0;
        for (uint256 i = 1; i <= totalAllowOwners; i++) {
            if(setWallets[i].isAllow == true) reNumber = reNumber + 1;
        }
        return reNumber;
    }
    
    function checkHaveOwner() internal view returns (bool){
        for (uint256 i = 1; i <= totalAllowOwners; i++) {
            if(setWallets[i].walletAddress == msg.sender) return true;
        }
        return false;
    }

    modifier allowOwners() {
        require(getCountAllowOwners() >= minimumAllowOwnersForTransactions,"All Owners Not Allow");
        _;
    }

    modifier haveOwner() {
        require(checkHaveOwner(),"You Have Not Added In Owner List");
        _;
    }

    function changeApprovelStatus(bool status) public haveOwner{
        for (uint256 i = 1; i <= totalAllowOwners; i++) {
            if(setWallets[i].walletAddress == msg.sender) setWallets[i].isAllow = status;
        }
    }

    function changeStatusAfterTransfer(bool status) public haveOwner{
        for (uint256 i = 1; i <= totalAllowOwners; i++) {
           setWallets[i].isAllow = status;
        }
    }

    function transferTokensWithAllowOwners(address _contractAddress,address _toAddress, uint256 _amount) public allowOwners{
        IERC20(_contractAddress).transfer(_toAddress,_amount);
        changeStatusAfterTransfer(false);
        emit tokenTransfer(_toAddress,_amount,msg.sender, _contractAddress);
    }

    function transferBalanceWithAllowOwners(address _toAddress, uint256 _amount) public payable allowOwners{
        payable(_toAddress).transfer(_amount);
        changeStatusAfterTransfer(false);
        emit balanceTransfer(_toAddress,_amount,msg.sender);
    }

    function addedTokens(address _contractAddress, uint256 _amount) public{
        IERC20(_contractAddress).transfer(address(this),_amount);
        emit tokenTransfer(address(this),_amount,msg.sender, _contractAddress);
    }

    function addBalance(uint256 _amount) public payable{
        payable(address(this)).transfer(_amount);
        emit balanceTransfer(address(this),_amount,msg.sender);
    }

}
