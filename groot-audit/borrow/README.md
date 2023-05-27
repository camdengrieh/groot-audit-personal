# DCHF Contracts

## Bug Bounty
Our bug bounty with bounties up to $100,000 is live on [Immunefi](https://immunefi.com/bounty/defifranc/).

## General Information
This repository was initially forked from [vesta finance](https://github.com/vesta-finance/vesta-protocol-v1/releases/tag/v1.0) and was changed in order to be deployable on Ethereum Mainnet.
It contains all contracts for the DCHF ecosystem, including Moneta Token, Dependencies and Interfaces.
More detailed information can be found on the [github page of liquity](https://github.com/liquity/dev).

## Important Contracts

### DfrancParameters.sol

All important parameters like the default CCR (Critical Collateralization Ratio) are set here.

### DCHFToken.sol

Contains the compatible ERC-20 DCHF token.

### BorrowerOperations.sol

Serves Borrower operations for the client. E.q. openTrove(...args).

### MONToken.sol

Contains the compatible ERC-20 Moneta token.

### LockedMON.sol

The vesting contract for Moneta Airdrops etc.



SP-Manager-addr: 0xEd66d5a6BA6FfcDb2fA311440ACB079c61274dEf
grootERC20-addr: 0x6e3F179f8a338CecAc2759D7BE8B34404317de86
adminContract-addr: 0x2f56bEE96105C7eBbb4e0D0DBaE12e1A4e925c09
dfrancParams-addr: 0x1AF124B64794991a1f650cA4d1cfEEe347dDE868
activePool-addr: 0x29e5dbD2d3E552bf7B59E0C173AF12565AA50A77
defaultPool-addr: 0x6863a0DD68B4D65A27140ED35363108f0E6C4bE6
priceFeed-addr: 0xE5403f31ACc2560FeD8886d1e3cf97f5A940a8ae
borrowerOperations-addr: 0x6f4D95B0eCA4a448Ee49C0F48238eE4DbF7d153c
troveManager-addr: 0x8a659d220A22A29377f62A8bE25D4A3034e2bF8b
troveManagerHelpers-addr: 0x85326Ee78319EB3c535139fb80270342f99b896F
sortedTroves-addr: 0x6ba5Df6277F2E66808cc6975eC757318a9Bc0093
communityIssuance-addr: 0xEEE5618aBC2BBa44882488E8cF875EB750B6369c
gasPool-addr: 0xd34Ee709bCc23b5dfb46B161ad76b5E848a9b734
collSurplusPool-addr: 0x5D37bF1f11D2d3b83De564Cb4c56c98B7a92AD04
hintHelpers-addr: 0xE391EA6CA5939E11659e9f27E688C413F79A0494
migrations-addr: 0x7a60C8B47bDeC4Fc4d3788D925833e11fD6159c5
multiTroveGetter-addr: 0x39b8c7DF4866eA0B65201b7BB6BBdb4E1b50362e
StabilityPool-addr: 0x668e4bB49aebBF58D362f1919B8d298dF766eF54
grootStableToken-addr: 0x8767491F011c9dF572dA7D26326B6d9D15b33730
grootStableStaking-addr: 0x90b1c50e9EA9668B484cB565EDA064864d25c96C