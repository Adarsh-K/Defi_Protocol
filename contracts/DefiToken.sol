// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./ERC20Callback.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DefiToken is ERC20Callback, Ownable {
    constructor(string memory _name, string memory _symbol, uint256 _initialSupply)
        ERC20Callback(_name, _symbol)
    {
        _mint(msg.sender, _initialSupply);
    }

    function mint(address userAddress, uint256 amount) external onlyOwner() {
        _mint(userAddress, amount);
    }
}
