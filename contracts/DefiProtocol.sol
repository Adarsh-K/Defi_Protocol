// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DefiProtocol {
    using SafeMath for uint256;

    IERC20 immutable private _token;
    mapping(address => uint256) private _stakes;

    constructor(address token) {
        require(token != address(0x0));
        _token = IERC20(token);
    }

    function stake(uint256 amount) public {
        _token.transferFrom(msg.sender, address(this), amount);
        _stakes[msg.sender] = _stakes[msg.sender].add(amount);
    }

    function unstake(uint256 amount) public {
        require(_stakes[msg.sender] >= amount, "Insufficient Stake");
        _token.transfer(msg.sender, amount);
        _stakes[msg.sender] = _stakes[msg.sender].sub(amount);
    }
}
