# Smart Contract Security Audit: Ethernaut Reentrancy

**Date:** 08/06/2026

**Prepared by:** Minh Chung

**Project:** Ethernaut Level 10 - Reentrance

---

## 1. Executive Summary

Hợp đồng `Reentrance` hoạt động như một ngân quỹ cho phép người dùng quyên góp và rút tiền tương ứng với số dư của họ. Tuy nhiên, một lỗ hổng bảo mật nghiêm trọng thuộc nhóm Reentrancy (Tấn công tái nhập) đã được phát hiện trong logic của hàm `withdraw`. Lỗ hổng này cho phép kẻ tấn công sử dụng một hợp đồng độc hại để rút tiền liên tục nhiều lần trong cùng một giao dịch, qua đó chiếm đoạt hoàn toàn toàn bộ số dư có trong hợp đồng.

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
| H-01 | Reentrancy Vulnerability via Low-Level Call and Delayed State Update | High | Found |

---

## 4. Detailed Findings

### [H-01] Reentrancy Vulnerability via Low-Level Call and Delayed State Update

**Description:**
Lỗ hổng xảy ra do hợp đồng vi phạm nghiêm trọng quy tắc thiết kế an toàn "Checks-Effects-Interactions" bên trong hàm `withdraw()`. Hãy xem xét trình tự thực thi mã nguồn:
    (bool result,) = msg.sender.call{value: _amount}("");
    if (result) { _amount; }
    balances[msg.sender] -= _amount;

Hợp đồng tiến hành tương tác bên ngoài (gửi Ether bằng `msg.sender.call`) trước khi thực hiện hiệu ứng thay đổi trạng thái nội bộ (khấu trừ số dư `balances[msg.sender]`). 

Khi `msg.sender` là một hợp đồng thông minh độc hại, lệnh `.call` sẽ chuyển giao quyền kiểm soát dòng lệnh (control flow) sang hàm `receive()` hoặc `fallback()` của hợp đồng độc hại đó. Do số dư nội bộ chưa bị khấu trừ, kẻ tấn công có thể thực hiện một lệnh gọi ngược lại (re-enter) vào chính hàm `withdraw()` để yêu cầu rút thêm tiền. Quy trình này tạo thành một vòng lặp đệ quy rút tiền không giới hạn cho đến khi bộ nhớ cạn kiệt hoặc hợp đồng nạn nhân bị cạn tiền hoàn toàn.

**Impact:**
Mức độ ảnh hưởng là **Chí mạng (High)**. Bất kỳ người dùng nào cũng có thể cấu hình mã độc để chiếm đoạt bất hợp pháp toàn bộ số Ether được lưu trữ trong hợp đồng vốn thuộc về các người dùng lương thiện khác.

**Proof of Concept (PoC):**
Cuộc tấn công được chứng minh thông qua các bước xử lý tự động sau:
1. Triển khai hợp đồng tấn công `ReentrancyAttacker` liên kết với địa chỉ của Vault mục tiêu.
2. Gọi hàm `attack()` kèm theo một lượng nhỏ Ether (ví dụ: 0.001 ETH) để tạo bản ghi số dư thông qua hàm `donate()`.
3. Gọi hàm `withdraw(0.001 ETH)` để kích hoạt đợt chuyển khoản đầu tiên.
4. Khi hàm `receive()` của mã độc nhận tiền, nó kiểm tra số dư tổng của Vault. Nếu Vault còn tiền, nó lập tức thực hiện lại lệnh `withdraw(0.001 ETH)`. Lúc này điều kiện kiểm tra `balances` của mục tiêu vẫn thấy giá trị cũ nên tiếp tục duyệt chi.
5. Vòng lặp kết thúc khi toàn bộ số dư của mục tiêu bị rút sạch về ví của kẻ tấn công.

**Recommendation:**
Áp dụng hai biện pháp phòng vệ độc lập nhưng bổ trợ cho nhau để triệt tiêu hoàn toàn rủi ro tái nhập:

1. Kiến trúc lại mã nguồn theo mô hình Checks-Effects-Interactions. Luôn luôn cập nhật thay đổi số dư nội bộ lên bộ nhớ trước, sau đó mới thực hiện các hành động tương tác gửi tiền ra bên ngoài:
    function withdraw(uint256 _amount) public {
        require(balances[msg.sender] >= _amount);
        balances[msg.sender] -= _amount; // Thực hiện Effect trước
        (bool result,) = msg.sender.call{value: _amount}(""); // Tương tác Interaction sau
        require(result, "Transfer failed");
    }

2. Sử dụng khóa Mutex chống tái nhập (`ReentrancyGuard`) từ các thư viện chuẩn hóa như OpenZeppelin. Thêm modifier `nonReentrant` vào các hàm có tính năng chuyển tài sản để ngăn chặn mọi hành vi gọi đệ quy lặp lại trong cùng một ngữ cảnh giao dịch.

---

## 5. Vulnerable Code Snippet

// Điểm yếu cốt tử nằm ở thứ tự dòng lệnh xử lý của hàm withdraw
function withdraw(uint256 _amount) public {
    if (balances[msg.sender] >= _amount) {
        // Sai lầm: Gửi tiền đi trước khi cập nhật số dư
        (bool result,) = msg.sender.call{value: _amount}("");
        if (result) {
            _amount;
        }
        // Việc trừ tiền bị trì hoãn xuống cuối cùng tạo cơ hội cho mã độc tái nhập
        balances[msg.sender] -= _amount;
    }
}

---

## 6. Conclusion

Hợp đồng `Reentrance` là bài học xương máu kinh điển nhấn mạnh tầm quan trọng của kiểm soát luồng thực thi lệnh trong môi trường tính toán phi tập trung EVM. Các nhà phát triển không được phép giả định các giao dịch gửi tiền ra bên ngoài là điểm kết thúc an toàn. Quy tắc "Checks-Effects-Interactions" cùng việc tích hợp các bộ khóa bảo vệ `ReentrancyGuard` phải là tiêu chuẩn bắt buộc áp dụng cho mọi hàm có nghiệp vụ luân chuyển tài sản trong DeFi.