import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ERC20Decimals.sol";

library SafetyTransfer {
	using SafeMath for uint256;

	//_amount is in ether (1e18) and we want to convert it to the token decimal
	function decimalsCorrection(address _token, uint256 _amount)
		internal
		view
		returns (uint256)
	{
		if (_token == address(0)) return _amount; //@audit Gas: This can be removed since address(0) is ETH and wont call the function
		if (_amount == 0) return 0;

		uint8 decimals = ERC20Decimals(_token).decimals();
		if (decimals < 18) {
			return _amount.div(10**(18 - decimals));
		} else {
			return _amount.mul(10**(decimals - 18));
		}
	}
}
