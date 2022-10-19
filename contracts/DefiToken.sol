// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./ERC20Callback.sol";

contract DefiToken is ERC20Callback {
    constructor(string memory _name, string memory _symbol, uint256 _initialSupply)
        ERC20Callback(_name, _symbol)
    {
        _mint(msg.sender, _initialSupply);
    }
}
