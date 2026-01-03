// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract FaucetToken is ERC20 {
    uint8 private _decimals;

    constructor(string memory tokenName,string memory symbol,uint8 decimals_) ERC20(tokenName,symbol) {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }


    function mint(address _to,uint256 _amount) public {
        _mint(_to,_amount);
    }
}