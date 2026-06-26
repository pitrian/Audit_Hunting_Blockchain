# Smart Contract Security Audit: Ethernaut Elevator

**Date:** 17/06/2026
**Prepared by:** Minh Chung
**Project:** Ethernaut Level 11 - Elevator

---

## 1. Executive Summary

Hợp đồng `Elevator` mô phỏng một thang máy di chuyển giữa các tầng của tòa nhà dựa trên thông tin cung cấp bởi một hợp đồng bên ngoài đóng vai trò là `Building`. Mục tiêu thiết kế của hợp đồng là ngăn chặn người dùng kích hoạt thang máy lên tới tầng cao nhất (`top = true`) khi chưa thỏa mãn điều kiện kiểm tra. Tuy nhiên, một lỗ hổng logic nghiêm trọng đã được phát hiện khi hợp đồng tin tưởng tuyệt đối vào kết quả trả về của hàm không có tính chất bất biến (Non-view/Non-pure function) từ bên ngoài. Lỗ hổng này cho phép kẻ tấn công dễ dàng thao túng kết quả trả về để đánh lừa thang máy lên đỉnh tòa nhà.

## 2. Risk Classification

| Severity | Description |
| :--- | :--- |
| **High** | Lỗ hổng có thể dẫn đến mất toàn bộ tiền trong hợp đồng hoặc chiếm quyền quản trị hoàn toàn. |
| **Medium** | Lỗ hổng ảnh hưởng đến logic vận hành nhưng không gây mất tiền ngay lập tức. |
| **Low** | Các lỗi liên quan đến tối ưu hóa Gas hoặc thực hành code không tốt. |

---

## 3. Findings Summary

| ID | Title | Severity | Status |
| :--- | :--- | :--- | :--- |
| H-01 | Insecure Reliance on Untrusted External Contract State | High | Found |

---

## 4. Detailed Findings

### [H-01] Insecure Reliance on Untrusted External Contract State

**Description:**
Hợp đồng `Elevator` định nghĩa một Interface `Building` nhưng không có quyền kiểm soát thực thể nào sẽ triển khai Interface đó. Trong hàm `goTo()`, hợp đồng thực hiện ép kiểu người gọi (`msg.sender`) thành một đối tượng `Building` và gọi hàm `isLastFloor()` hai lần liên tiếp trong cùng một luồng giao dịch:
    if (!building.isLastFloor(_floor)) {
        floor = _floor;
        top = building.isLastFloor(floor);
    }

Sai lầm cốt lõi là việc hàm `isLastFloor()` trong Interface không được khai báo với thuộc tính gán view hoặc pure. Điều này cho phép bên triển khai (Mã độc) thoải mái thay đổi trạng thái lưu trữ nội bộ của họ sau mỗi lần hàm được gọi. Kẻ tấn công có thể cấu hình để hàm này trả về giá trị `false` ở lần gọi thứ nhất (để vượt qua điều kiện `if`), và lập tức trả về `true` ở lần gọi thứ hai ngay sau đó (để gán giá trị `true` cho biến `top`).

**Impact:**
Mức độ ảnh hưởng là **Chí mạng (High)**. Toàn bộ logic ràng buộc nghiệp vụ kiểm tra điều kiện của hợp đồng bị phá vỡ hoàn toàn bởi một tác nhân bên ngoài không đáng tin cậy.

**Proof of Concept (PoC):**
Cuộc tấn công được chứng minh thông qua cơ chế thay đổi trạng thái (State Toggle) như sau:
1. Triển khai hợp đồng `ElevatorAttacker` có chứa hàm `isLastFloor(uint256)` và một biến cờ hiệu `isSecondCall = false`.
2. Khi hàm `isLastFloor` được gọi lần đầu từ câu lệnh `if` của nạn nhân, nó thấy `isSecondCall == false`, liền đổi `isSecondCall = true` và trả về `false`. Thang máy tin rằng đây chưa phải tầng thượng và đi vào trong.
3. Ở dòng lệnh tiếp theo, nạn nhân gọi `isLastFloor` lần 2. Lúc này biến cờ hiệu đã là `true`, mã độc trả về kết quả `true`. Biến `top` bị ghi đè thành `true` thành công.

**Recommendation:**
1. **Sử dụng thuộc tính View/Pure trong Interface:** Ép buộc các hàm kiểm tra trạng thái trong Interface phải là hàm đọc dữ liệu (`view` hoặc `pure`). Điều này ngăn chặn việc các contract bên ngoài cố tình thay đổi trạng thái lưu trữ để tráo đổi kết quả giữa các lần gọi:
    interface Building {
        function isLastFloor(uint256) external view returns (bool);
    }

2. **Lưu trữ kết quả vào biến cục bộ (Local Variable):** Tránh việc gọi một hàm từ bên thứ ba nhiều lần cho cùng một mục đích kiểm tra dữ liệu. Chỉ gọi một lần duy nhất, lưu kết quả vào bộ nhớ tạm (Memory) và sử dụng biến tạm đó cho toàn bộ logic phía sau:
    bool isLast = building.isLastFloor(_floor);
    if (!isLast) {
        floor = _floor;
        top = isLast;
    }

---

## 5. Vulnerable Code Snippet

// Lỗ hổng nằm ở việc gọi hàm bên thứ ba hai lần liên tiếp không có thuộc tính view ràng buộc
contract Elevator {
    bool public top;
    uint256 public floor;

    function goTo(uint256 _floor) public {
        Building building = Building(msg.sender);

        // Lần gọi 1 có thể trả về false
        if (!building.isLastFloor(_floor)) {
            floor = _floor;
            // Lần gọi 2 của cùng một hàm có thể bị tráo đổi trả về true
            top = building.isLastFloor(floor); 
        }
    }
}

---

## 6. Conclusion

Hợp đồng `Elevator` đem lại bài học lớn về việc thiết lập ranh giới tin cậy (Trust Boundary) trong kiến trúc Smart Contract. Khi tương tác với bất kỳ thực thể bên ngoài nào nằm ngoài tầm kiểm soát, nhà phát triển phải mặc định coi chúng là độc hại. Việc không áp đặt các từ khóa nghiêm ngặt như `view`/`pure` lên Interface hoặc thực hiện gọi hàm lặp lại vô tội vạ sẽ luôn tạo điều kiện cho kẻ tấn công thực hiện thao túng logic dữ liệu thành công.