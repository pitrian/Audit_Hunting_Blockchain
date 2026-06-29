# Smart Contract Security Audit: Ethernaut Gatekeeper Two

**Date:** 29/06/2026
**Prepared by:** Minh Chung
**Project:** Ethernaut Level 14 - Gatekeeper Two

---

## 1. Executive Summary

Hợp đồng `GatekeeperTwo` thiết lập một cơ chế kiểm soát an ninh đa tầng thông qua 3 lớp Modifier rà soát (`gateOne`, `gateTwo`, `gateThree`). Đáng chú ý, hợp đồng tích hợp mã máy Assembly cấp thấp (`extcodesize`) để chặn đứng các cuộc gọi có nguồn gốc từ Smart Contract khác và áp dụng thuật toán mã hóa bit XOR để kiểm tra tính hợp lệ của khóa bí mật. Tuy nhiên, cuộc kiểm toán đã chứng minh hệ thống kiểm soát này hoàn toàn bị vô hiệu hóa khi kẻ tấn công lợi dụng đặc tính vòng đời khởi tạo của hợp đồng thông minh kết hợp với nghịch đảo toán học bit.

## 2. Risk Classification

| Severity   | Description                                                                                     |
| :--------- | :---------------------------------------------------------------------------------------------- |
| **High**   | Lỗ hổng có thể dẫn đến mất toàn bộ tiền trong hợp đồng hoặc chiếm quyền quản trị hoàn toàn.     |
| **Medium** | Lổng logic ảnh hưởng đến trạng thái hệ thống nhưng không trực tiếp gây thất thoát tài sản ngay. |
| **Low**    | Các lỗi liên quan đến tối ưu hóa Gas hoặc thực hành code không tốt.                             |

---

## 3. Findings Summary

| ID   | Title                                                           | Severity | Status |
| :--- | :-------------------------------------------------------------- | :------- | :----- |
| H-01 | Bypass Extcodesize Verification via Constructor-State Execution | High     | Found  |

---

## 4. Detailed Findings

### [H-01] Bypass Extcodesize Verification via Constructor-State Execution

**Description:**
Lỗ hổng an ninh phát sinh từ sự hiểu sai về mặt kiến trúc cơ chế vận hành của Opcode `extcodesize` trên EVM. Hợp đồng sử dụng đoạn mã Assembly sau để thực hiện chặn Contract độc hại:
    assembly { x := extcodesize(caller()) }
    require(x == 0);

Giả định thiết kế cho rằng chỉ có các tài khoản ví cá nhân (EOA) mới có kích thước mã nguồn bằng `0`. Tuy nhiên, quy chuẩn của EVM quy định rằng trong suốt quá trình hàm khởi tạo (`constructor`) của một Smart Contract đang thực thi, mã Bytecode runtime của nó chưa chính thức được lưu trữ và gán vào trạng thái ô nhớ của địa chỉ đó trên Blockchain. Do đó, nếu một Contract độc hại thực hiện lệnh gọi tấn công ngay từ bên trong hàm `constructor` của chính nó, `extcodesize` trả về chắc chắn bằng `0`, cho phép vượt qua hoàn toàn bộ lọc `gateTwo`.

Bên cạnh đó, việc sử dụng phép toán mã hóa bit đối xứng XOR (`^`) tại `gateThree` không mang lại tính bảo mật cao, do toán học máy tính cho phép thực hiện tính toán nghịch đảo một cách dễ dàng mà không cần Brute-force dữ liệu.

**Impact:**
Mức độ ảnh hưởng là **Chí mạng (High)**. Hệ thống tường lửa bảo vệ hoàn toàn sụp đổ, cho phép bất kỳ thực thể bên ngoài nào cũng cấu hình được mã độc để chiếm quyền ghi danh vào biến trạng thái hệ thống `entrant`.

**Proof of Concept (PoC):**
Cuộc tấn công bẻ gãy hệ thống được thực hiện tự động qua các pha:
1. Triển khai hợp đồng `GatekeeperTwoAttacker`.
2. Toàn bộ mã nguồn tấn công được đóng gói trọn vẹn trong hàm `constructor`. Tại đây, địa chỉ `address(this)` của mã độc được băm qua hàm `keccak256` và chuyển đổi sang kiểu `uint64`.
3. Áp dụng toán tử XOR với mặt nạ bit tối đa `type(uint64).max` để đảo toàn bộ chuỗi bit, tạo thành một chiếc chìa khóa `gateKey` hoàn hảo.
4. Mã độc gọi hàm `target.enter(gateKey)` ngay lập tức, vượt qua rào cản `extcodesize` thành công vì kích thước code tại thời điểm này được ghi nhận bằng `0`.

**Recommendation:**
1. Tuyệt đối không sử dụng lệnh kiểm tra `extcodesize == 0` để phân biệt giữa tài khoản ví cá nhân và tài khoản hợp đồng thông minh. Thay vào đó, nếu bắt buộc phải chặn các cuộc gọi từ Smart Contract, hãy sử dụng điều kiện kiểm tra nghiêm ngặt:
    require(msg.sender == tx.origin, "Contracts are not allowed");
2. Đối với các cơ chế xác thực hoặc trao đổi khóa, nên áp dụng các tiêu chuẩn chữ ký mã hóa bất đối xứng (ví dụ: ECDSA `ecrecover`) thay vì dựa vào các phép toán so sánh bit cơ bản trên chuỗi dữ liệu công khai của EVM.

---

## 5. Vulnerable Code Snippet

// Điểm yếu cốt tử nằm ở việc tin tưởng hoàn toàn vào extcodesize tại gateTwo
modifier gateTwo() {
    uint256 x;
    assembly { x := extcodesize(caller()) } // Lỗi kiến trúc: Bị bypass dễ dàng trong constructor
    require(x == 0);
    _;
}

---

## 6. Conclusion

Hợp đồng `GatekeeperTwo` đem lại bài học sâu sắc về tư duy lập trình EVM cấp thấp. Nhà phát triển cần hiểu rõ vòng đời sinh trưởng của một hợp đồng thông minh thay vì chỉ tin vào các thông số kiểm tra trạng thái tĩnh. Việc áp dụng sai Opcode bảo mật không những không gia tăng an toàn mà còn tạo ra các điểm mù logic nguy hiểm cho toàn bộ hệ thống DeFi.