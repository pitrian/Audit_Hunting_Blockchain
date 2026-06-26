// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 1. INTERFACE ĐÃ ĐƯỢC BẢO MẬT
interface Building {
    // Thêm từ khóa "view" để đảm bảo các hợp đồng triển khai hàm này 
    // chỉ được phép ĐỌC dữ liệu từ blockchain, KHÔNG THỂ thay đổi trạng thái (State) 
    // của bộ nhớ để lật switch dữ liệu giữa các lần gọi.
    function isLastFloor(uint256) external view returns (bool);
}

// 2. SMART CONTRACT ELEVATOR AN TOÀN
contract SecuredElevator {
    bool public top;
    uint256 public floor;

    function goTo(uint256 _floor) public {
        Building building = Building(msg.sender);

        // GIẢI PHÁP AN TOÀN: 
        // Chỉ gọi hàm từ bên thứ ba MỘT LẦN DUY NHẤT và lưu kết quả vào biến cục bộ (Local Variable).
        // Ngay cả khi bên thứ ba cố tình tìm cách thay đổi kết quả (nếu không có view), 
        // thì giá trị trong transaction hiện tại vẫn không bị thay đổi.
        bool isLast = building.isLastFloor(_floor);

        if (!isLast) {
            floor = _floor;
            top = isLast; // Gán giá trị an toàn đã lưu trong bộ nhớ tạm
        }
    }
}