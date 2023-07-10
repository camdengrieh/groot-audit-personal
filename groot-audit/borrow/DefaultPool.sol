// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./Interfaces/IDefaultPool.sol";
import "./Dependencies/CheckContract.sol";
import "./Dependencies/SafetyTransfer.sol";
import "./Dependencies/Initializable.sol";

/*
 * The Default Pool holds the ETH and DCHF debt (but not DCHF tokens) from liquidations that have been redistributed
 * to active troves but not yet "applied", i.e. not yet recorded on a recipient active trove's struct.
 *
 * When a trove makes an operation that applies its pending ETH and DCHF debt, its pending ETH and DCHF debt is moved
 * from the Default Pool to the Active Pool.
 */
contract DefaultPool is Ownable, CheckContract, Initializable, IDefaultPool {
	using SafeMath for uint256;
	using SafeERC20 for IERC20; //@audit Gas - SafeMath is not needed for Solidity version 0.8.0 and above

	string public constant NAME = "DefaultPool"; 

	address constant ETH_REF_ADDRESS = address(0); //@audit Gas: This is a default value so it doesn't to be assigned a value

	address public troveManagerAddress; 
	address public troveManagerHelpersAddress;
	address public activePoolAddress;

	bool public isInitialized; //@audit redundant with Initializable.sol

	mapping(address => uint256) internal assetsBalance;
	mapping(address => uint256) internal DCHFDebts; // debt

	// --- Dependency setters ---

	function setAddresses(
		address _troveManagerAddress, 
		address _troveManagerHelpersAddress, 
		address _activePoolAddress
	  ) external
		initializer
		onlyOwner
	{
		require(!isInitialized, "Already initialized"); //@audit redundant with Initializable.sol
		checkContract(_troveManagerAddress);
		checkContract(_activePoolAddress);
		checkContract(_troveManagerHelpersAddress);
		isInitialized = true; //@audit redundant with Initializable.sol

		troveManagerAddress = _troveManagerAddress;
		troveManagerHelpersAddress = _troveManagerHelpersAddress;
		activePoolAddress = _activePoolAddress;

		emit TroveManagerAddressChanged(_troveManagerAddress);
		emit ActivePoolAddressChanged(_activePoolAddress);

		renounceOwnership();
	}

	// --- Getters for public variables. Required by IPool interface ---

	/*
	 * Returns the ETH state variable.
	 *
	 * Not necessarily equal to the the contract's raw ETH balance - ether can be forcibly sent to contracts.
	 */
	function getAssetBalance(address _asset) external view override returns (uint256) {
		return assetsBalance[_asset];
	}

	function getDCHFDebt(address _asset) external view override returns (uint256) {
		return DCHFDebts[_asset];
	}

	// --- Pool functionality ---

	//@note Redeclared methods, very similar to the one in the active pool. Use a library? or override the method and put the method in a parent contract?
	// better for Single Responsibility and Open-Closed Principle
	function sendAssetToActivePool(address _asset, uint256 _amount)
		external
		override
		callerIsTroveManager
	{
		address activePool = activePoolAddress; // cache to save an SLOAD

		uint256 safetyTransferAmount = SafetyTransfer.decimalsCorrection(_asset, _amount);
		if (safetyTransferAmount == 0) return;

		assetsBalance[_asset] = assetsBalance[_asset].sub(_amount);

		if (_asset != ETH_REF_ADDRESS) {
			IERC20(_asset).safeTransfer(activePool, safetyTransferAmount);
			IDeposit(activePool).receivedERC20(_asset, _amount);
		} else {
			(bool success, ) = activePool.call{ value: _amount }("");
			require(success, "DefaultPool: sending ETH failed");
		}

		emit DefaultPoolAssetBalanceUpdated(_asset, assetsBalance[_asset]);
		emit AssetSent(activePool, _asset, safetyTransferAmount);
	}

	function increaseDCHFDebt(address _asset, uint256 _amount)
		external
		override
		callerIsTroveManager
	{
		DCHFDebts[_asset] = DCHFDebts[_asset].add(_amount);
		emit DefaultPoolDCHFDebtUpdated(_asset, DCHFDebts[_asset]);
	}

	function decreaseDCHFDebt(address _asset, uint256 _amount)
		external
		override
		callerIsTroveManager
	{
		DCHFDebts[_asset] = DCHFDebts[_asset].sub(_amount);
		emit DefaultPoolDCHFDebtUpdated(_asset, DCHFDebts[_asset]);
	}

	// --- 'require' functions ---

	modifier callerIsActivePool() {
		require(msg.sender == activePoolAddress, "DefaultPool: Caller is not the ActivePool"); //@audit Gas: Require string is too long
		_;
	}

	modifier callerIsTroveManager() {
		require(
			msg.sender == troveManagerAddress ||
			msg.sender == troveManagerHelpersAddress, 
			"DefaultPool: Caller is not the TroveManager");
		_;
	}

	function receivedERC20(address _asset, uint256 _amount)
		external
		override
		callerIsActivePool
	{
		require(_asset != ETH_REF_ADDRESS, "ETH Cannot use this functions");
		//@audit Gas: Not possible for the ActivePool to accidentally use ETH Reference address, but if it does
		// Should it not just use the fallback function?

		assetsBalance[_asset] = assetsBalance[_asset].add(_amount);
		emit DefaultPoolAssetBalanceUpdated(_asset, assetsBalance[_asset]);
	}

	// --- Fallback function ---

	receive() external payable callerIsActivePool {
		assetsBalance[ETH_REF_ADDRESS] = assetsBalance[ETH_REF_ADDRESS].add(msg.value);
		emit DefaultPoolAssetBalanceUpdated(ETH_REF_ADDRESS, assetsBalance[ETH_REF_ADDRESS]);
	}
}
