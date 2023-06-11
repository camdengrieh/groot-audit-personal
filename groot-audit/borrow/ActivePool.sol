// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;
//@audit - SafeMath is no longer needed in solidity 0.8.0 and above
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Interfaces/IActivePool.sol";
import "./Interfaces/IDefaultPool.sol";
import "./Interfaces/IStabilityPoolManager.sol";
import "./Interfaces/IStabilityPool.sol";
import "./Interfaces/ICollSurplusPool.sol";
import "./Interfaces/IDeposit.sol";
import "./Dependencies/CheckContract.sol";
import "./Dependencies/SafetyTransfer.sol";
import "./Dependencies/Initializable.sol";

/*
 * The Active Pool holds the collaterals and DCHF debt (but not DCHF tokens) for all active troves.
 *
 * When a trove is liquidated, it's collateral and DCHF debt are transferred from the Active Pool, to either the
 * Stability Pool, the Default Pool, or both, depending on the liquidation conditions.
 *
 */
contract ActivePool is
	Ownable,
	ReentrancyGuard,
	CheckContract,
	Initializable,
	IActivePool
{
	using SafeERC20 for IERC20;
	using SafeMath for uint256; //@audit - SafeMath is no longer needed in solidity 0.8.0 and above

	string public constant NAME = "ActivePool";
	address constant ETH_REF_ADDRESS = address(0); //@audit Gas: This is a default value so it doesn't to be assigned a value

	address public borrowerOperationsAddress;
	address public troveManagerAddress;
	address public troveManagerHelpersAddress;
	IDefaultPool public defaultPool;
	ICollSurplusPool public collSurplusPool;

	IStabilityPoolManager public stabilityPoolManager;

	bool public isInitialized; //@audit redundant with Initializable.sol

	mapping(address => uint256) internal assetsBalance;
	mapping(address => uint256) internal DCHFDebts;

	// --- Contract setters ---

	//@audit Gas: Use the constructor instead of a function and then make the variables immutable
	function setAddresses(
		address _borrowerOperationsAddress,
		address _troveManagerAddress,
		address _troveManagerHelpersAddress,
		address _stabilityManagerAddress,
		address _defaultPoolAddress,
		address _collSurplusPoolAddress
	) external initializer onlyOwner {
		require(!isInitialized, "Already initialized"); //@audit Already using Initializable.sol, so this is redundant
		checkContract(_borrowerOperationsAddress);
		checkContract(_troveManagerAddress);
		checkContract(_troveManagerHelpersAddress);
		checkContract(_stabilityManagerAddress);
		checkContract(_defaultPoolAddress);
		checkContract(_collSurplusPoolAddress);
		isInitialized = true; //@audit redundant with Initializable.sol

		borrowerOperationsAddress = _borrowerOperationsAddress;
		troveManagerAddress = _troveManagerAddress;
		troveManagerHelpersAddress = _troveManagerHelpersAddress;
		stabilityPoolManager = IStabilityPoolManager(_stabilityManagerAddress);
		defaultPool = IDefaultPool(_defaultPoolAddress);
		collSurplusPool = ICollSurplusPool(_collSurplusPoolAddress);

		emit BorrowerOperationsAddressChanged(_borrowerOperationsAddress);
		emit TroveManagerAddressChanged(_troveManagerAddress);
		emit StabilityPoolAddressChanged(_stabilityManagerAddress);
		emit DefaultPoolAddressChanged(_defaultPoolAddress);

		renounceOwnership();
	}

	// --- Getters for public variables. Required by IPool interface ---

	//@audit Use NatSpec comments for documentation
	/*
	 * Returns the ETH state variable.
	 *
	 *Not necessarily equal to the the contract's raw ETH balance - ether can be forcibly sent to contracts.
	 */
	 //@audit Following from the comments above, it appears that the receive function is already implemented, to mitigate this issue?
	function getAssetBalance(address _asset) external view override returns (uint256) {
		return assetsBalance[_asset];
	}

	function getDCHFDebt(address _asset) external view override returns (uint256) {
		return DCHFDebts[_asset];
	}

	// --- Pool functionality ---

	function sendAsset(
		address _asset,
		address _account,
		uint256 _amount
	) external override nonReentrant callerIsBOorTroveMorSP {
		if (stabilityPoolManager.isStabilityPool(msg.sender)) {
			assert(address(stabilityPoolManager.getAssetStabilityPool(_asset)) == msg.sender);
		}

		//@audit Gas: Reduce any unnecessary gas usage, such as declaring safetyTransferAmount when it may not be needed

		// uint256 safetyTransferAmount = SafetyTransfer.decimalsCorrection(_asset, _amount);
		// if (safetyTransferAmount == 0) return; //@audit Gas: Returns nothing. Consider reverting instead?

		// assetsBalance[_asset] = assetsBalance[_asset].sub(_amount);

		// if (_asset != ETH_REF_ADDRESS) {
		// 	IERC20(_asset).safeTransfer(_account, safetyTransferAmount);

		// 	if (isERC20DepositContract(_account)) {
		// 		IDeposit(_account).receivedERC20(_asset, _amount);
		// 	}
		// } else {
		// 	(bool success, ) = _account.call{ value: _amount }("");
		// 	require(success, "ActivePool: sending ETH failed");
		// }


		//assetsBalance[_asset] = assetsBalance[_asset].sub(_amount);
		assetsBalance[_asset] -= _amount; //@audit Gas: Cheaper to use -=, less operations

		if (_asset == ETH_REF_ADDRESS) {
			(bool success, ) = _account.call{ value: _amount }("");
			require(success, "ActivePool: sending ETH failed");
			emit AssetSent(_account, _asset, _amount);
			
		} else {
			uint256 safetyTransferAmount = SafetyTransfer.decimalsCorrection(_asset, _amount);
			if (safetyTransferAmount == 0) return; //@audit Gas: Returns nothing. Consider reverting instead?
			
			IERC20(_asset).safeTransfer(_account, safetyTransferAmount);

			if (isERC20DepositContract(_account)) {
				IDeposit(_account).receivedERC20(_asset, _amount);
			}
			emit AssetSent(_account, _asset, safetyTransferAmount);

		}

		emit ActivePoolAssetBalanceUpdated(_asset, assetsBalance[_asset]);
	}

	function isERC20DepositContract(address _account) private view returns (bool) {
		return (_account == address(defaultPool) ||
			_account == address(collSurplusPool) ||
			stabilityPoolManager.isStabilityPool(_account));
	}

	function increaseDCHFDebt(address _asset, uint256 _amount)
		external
		override
		callerIsBOorTroveM
	{
		DCHFDebts[_asset] = DCHFDebts[_asset].add(_amount); //@audit Gas: Use += _amount instead
		emit ActivePoolDCHFDebtUpdated(_asset, DCHFDebts[_asset]);
	}

	function decreaseDCHFDebt(address _asset, uint256 _amount)
		external
		override
		callerIsBOorTroveMorSP
	{
		DCHFDebts[_asset] = DCHFDebts[_asset].sub(_amount); //@audit Gas: Use -= _amount instead
		emit ActivePoolDCHFDebtUpdated(_asset, DCHFDebts[_asset]);
	}

	// --- 'require' functions ---

	//@audit Gas: Consider using custom error messages to reduce gas usage

	modifier callerIsBorrowerOperationOrDefaultPool() {
		require(
			msg.sender == borrowerOperationsAddress || msg.sender == address(defaultPool),
			"ActivePool: Caller is neither BO nor Default Pool" //@audit Gas: Require String is too long. Reduce under 32 characters so its not more than 32 bytes
		);

		_;
	}

	modifier callerIsBOorTroveMorSP() {
		require(
			msg.sender == borrowerOperationsAddress ||
				msg.sender == troveManagerAddress ||
				msg.sender == troveManagerHelpersAddress ||
				stabilityPoolManager.isStabilityPool(msg.sender),
			"ActivePool: Caller is neither BorrowerOperations nor TroveManager nor StabilityPool" //@audit Gas - Require string is too long.
		);
		_;
	}

	modifier callerIsBOorTroveM() {
		require(
			msg.sender == borrowerOperationsAddress || 
			msg.sender == troveManagerAddress ||
			msg.sender == troveManagerHelpersAddress,
			"ActivePool: Caller is neither BorrowerOperations nor TroveManager" //@audit Gas - Require string is too long.
		);

		_;
	}

	function receivedERC20(address _asset, uint256 _amount)
		external
		override
		callerIsBorrowerOperationOrDefaultPool
	{
		assetsBalance[_asset] = assetsBalance[_asset].add(_amount); //@audit Gas: Use += _amount instead
		emit ActivePoolAssetBalanceUpdated(_asset, assetsBalance[_asset]);
	}

	// --- Fallback function ---

	receive() external payable callerIsBorrowerOperationOrDefaultPool {
		assetsBalance[ETH_REF_ADDRESS] = assetsBalance[ETH_REF_ADDRESS].add(msg.value); //@audit Gas: Use += _amount instead
		emit ActivePoolAssetBalanceUpdated(ETH_REF_ADDRESS, assetsBalance[ETH_REF_ADDRESS]);
	}

	//@audit - Critical: It allows anyone to withdraw ETH from the contract. Consider adding access permissions to this function, and only for balance that is not recorded in assetsBalance[ETH_REF_ADDRESS], or removing it entirely
	function withdrawETH(uint256 _amount) public {
		require(address(this).balance >= _amount, "Insufficient balance.");
		payable(msg.sender).transfer(_amount);
	}
}
