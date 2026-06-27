# Smart Contract Security Audit: Ethernaut Gatekeeper One

**Date:** 27/06/2026

**Prepared by:** Minh Chung

**Project:** Ethernaut Level 13 - Gatekeeper One

---

## 1. Executive Summary

Hợp đồng `GatekeeperOne` triển khai một hệ thống kiểm soát truy cập phân tầng bao gồm 3 lớp Modifier (`gateOne`, `gateTwo`, `gateThree`) để bảo vệ hàm ghi danh `enter()`. Hệ thống giả định rằng việc kết hợp các ràng buộc về nguồn gốc thực thi, kiểm tra số dư Gas động và ép kiểu dữ liệu phức tạp sẽ ngăn chặn hoàn toàn các truy cập trái phép. Tuy nhiên, qua quá trình kiểm toán chuyên sâu, toàn bộ các cơ chế này đều có thể bị bẻ gãy một cách có hệ thống thông qua việc kết hợp Contract trung gian, kỹ thuật tính toán mặt nạ bit dữ liệu và công cụ dò tìm Gas tự động.

## 2. Risk Classification

| Severity   | Description                                                                                 |
| :--------- | :------------------------------------------------------------------------------------------ |
| **High**   | Lỗ hổng có thể dẫn đến mất toàn bộ tiền trong hợp đồng hoặc chiếm quyền quản trị hoàn toàn. |
| **Medium** | Lỗ hổng ảnh hưởng đến logic vận hành nhưng không gây mất tiền ngay lập tức.                 |
| **Low**    | Các lỗi liên quan đến tối ưu hóa Gas hoặc thực hành code không tốt.                         |

---

## 3. Findings Summary

| ID   | Title                                                    | Severity | Status |
| :--- | :------------------------------------------------------- | :------- | :----- |
| H-01 | Access Control Bypass via Multi-Vector Gate Manipulation | High     | Found  |

---

## 4. Detailed Findings

### [H-01] Access Control Bypass via Multi-Vector Gate Manipulation

**Description:**
Hợp đồng thiết lập hệ thống phòng vệ dựa trên các giả định bảo mật không an toàn tại cả 3 cổng:

1. **Gate One (tx.origin vs msg.sender):** Giả định rằng việc chặn `msg.sender == tx.origin` sẽ lọc được người dùng thông thường. Bản chất cơ chế này bị bypass dễ dàng bằng cách triển khai một Smart Contract tấn công đứng tên làm trung gian truyền tải chỉ thị cuộc gọi.
2. **Gate Two (gasleft() Check):** Ép buộc số lượng Gas còn lại phải chia hết cho 8191. Do chi phí Gas thực thi Opcode trên EVM có tính chất xác định (Deterministic), kẻ tấn công sử dụng một vòng lặp Brute-force cục bộ trong môi trường kiểm thử để dò tìm độ lệch Gas chính xác (`baseGas + i`), triệt tiêu hoàn toàn tính rào cản của cổng.
3. **Gate Three (Data Masking & Type Casting):** Thực hiện một chuỗi các phép so sánh toán học ép kiểu biểu diễn từ `bytes8` về các dạng kích thước nhỏ hơn (`uint32`, `uint16`). Do các phép cắt bit tuân theo quy tắc toán học nhị phân cố định, một mặt nạ bit (Bitwise Mask) được xây dựng dựa trên địa chỉ của `tx.origin` sẽ dễ dàng thỏa mãn đồng thời cả 3 điều kiện `require`.

**Impact:**
Mức độ ảnh hưởng là **Chí mạng (High)**. Kẻ tấn công vượt qua toàn bộ tường lửa để ghi đè quyền sở hữu/đăng ký thông tin vào biến trạng thái `entrant`, vô hiệu hóa mục đích bảo mật ban đầu của hợp đồng.

**Proof of Concept (PoC):**
Hành vi tấn công được thực thi tuần tự qua các pha xử lý:
1. Tính toán giá trị khóa `_gateKey` bằng cách lấy địa chỉ ví người chơi triển khai phép toán logic And (`&`) với `0xFFFFFFFF0000FFFF` nhằm làm sạch các byte rác, sau đó phép toán Or (`|`) với `0xFFFFFFFF00000000` để vượt qua vòng kiểm tra Part Two.
2. Đóng gói lệnh gọi trong một vòng lặp tăng dần cấu hình Gas gửi đi từ một hợp đồng độc hại để kiểm tra điểm rơi chia hết cho 8191 của hàm `gasleft()`.
3. Giao dịch thành công và biến `entrant` được cập nhật chính xác về địa chỉ ví người chơi.

**Recommendation:**
1. Tránh việc xây dựng các logic nghiệp vụ quan trọng phụ thuộc vào lượng Gas còn lại (`gasleft()`), vì chi phí gas của các Opcode có thể thay đổi sau các bản nâng cấp Hardfork của Ethereum (ví dụ: EIP-150, EIP-2929), làm sập toàn bộ hệ thống đang vận hành hợp pháp.
2. Không sử dụng phép so sánh ép kiểu dữ liệu nhị phân thô để làm cơ chế xác thực bảo mật vì các giá trị này hoàn toàn tính toán đảo ngược được bằng toán học máy tính.

---

## 5. Vulnerable Code Snippet

// Toàn bộ chuỗi rào cản bảo mật lỗi thời có thể phá vỡ bằng code tự động
contract GatekeeperOne {
    address public entrant;

    modifier gateOne() {
        require(msg.sender != tx.origin); // Điểm yếu: Chống ví cá nhân nhưng bỏ quên contract trung gian
        _;
    }

    modifier gateTwo() {
        require(gasleft() % 8191 == 0); // Điểm yếu: Hoàn toàn brute-force được lượng gas
        _;
    }

    modifier gateThree(bytes8 _gateKey) {
        // Điểm yếu: Ép kiểu dữ liệu có thể tính toán chính xác bằng Bitwise mask
        require(uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)), "invalid gateThree part one");
        require(uint32(uint64(_gateKey)) != uint64(_gateKey), "invalid gateThree part two");
        require(uint32(uint64(_gateKey)) == uint16(uint160(tx.origin)), "invalid gateThree part three");
        _;
    }
}

---

## 6. Conclusion

Hợp đồng `GatekeeperOne` là một minh chứng thực tế cho thấy tư duy bảo mật theo kiểu "làm mờ code và đánh đố" (Security through Obscurity) luôn thất bại trước các kỹ thuật phân tích kỹ thuật hệ thống tốt. Các nhà phát triển cần tập trung vào việc thiết kế hệ thống phân quyền chuẩn hóa (như áp dụng OpenZeppelin Access Control) thay vì tạo ra các rào cản toán học nhị phân hoặc cấu hình Gas dễ tổn thương trên EVM.