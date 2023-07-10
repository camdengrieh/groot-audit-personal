// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;
import "../Dependencies/CheckContract.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../Dependencies/ERC20Permit.sol";

contract MONToken is CheckContract, ERC20Permit {
	using SafeMath for uint256; 
	//@audit Gas - SafeMath library is not actually needed for these math operations as the value of 1 million * 100 will never overflow. Also not longer needed in Solidity 0.8.0
	//@audit Gas - Either initialize the value of the supply to be minted exactly to save the most gas or use unchecked 
	//@audit Low - CheckContract does not appear to be used

	// uint for use with SafeMath
	uint256 internal constant _1_MILLION = 1e24; // 1e6 * 1e18 = 1e24

	address public immutable treasury;

	constructor(address _treasurySig) ERC20("Moneta", "MON") {
		//@audit Low - Use CheckContract instead? best to not use CheckContract at all and use the require statement or check code size of the address, if its used only in constructor
		require(_treasurySig != address(0), "Invalid Treasury Sig");
		treasury = _treasurySig;
		_mint(msg.sender, _1_MILLION.mul(100));

		//Lazy Mint to setup protocol.
		//After the deployment scripts, deployer addr automatically send the fund to the treasury.
		_mint(_treasurySig, _1_MILLION.mul(100));
	}
}
