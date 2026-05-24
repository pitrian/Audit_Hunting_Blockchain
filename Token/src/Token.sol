// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Token {
    mapping(address => uint256) public balances;
    uint256 public totalSupply;
    constructor(uint256 _totalSupply) public {
        balances[msg.sender] = totalSupply = _totalSupply;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(balances[msg.sender] - _value >= 0);
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        return true;
    }
    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }
}
