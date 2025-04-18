pragma solidity ^0.8.14;

interface IPriceFeed {

    // --- Events ---
    event LastGoodPriceUpdated(address _token,uint _lastGoodPrice);
   
    // --- Function ---
    function fetchPrice(address _token) external returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/*
* PriceFeed placeholder for testnet and development. The price is simply set manually and saved in a state 
* variable. The contract does not connect to a live Chainlink price feed. 
*/
contract PriceFeedTestnet is IPriceFeed {
    
    uint256 private _price = 500 * 1e18; 

    // --- Functions ---

    // View price getter for simplicity in tests
    function getPrice() external view returns (uint256) {
        return _price;
    }

    function fetchPrice(address _token) external override returns (uint256) {
        // Fire an event just like the mainnet version would.
        // This lets the subgraph rely on events to get the latest price even when developing locally.
        emit LastGoodPriceUpdated(_token,_price);
        return _price;
    }

    // Manual external price setter.
    function setPrice(uint256 price) external returns (bool) {
        _price = price;
        return true;
    }
}
