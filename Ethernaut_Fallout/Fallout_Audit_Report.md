# Smart Contract Security Audit: Ethernaut Fallout

**Date:** 16/05/2026

**Prepared by:** Ngô Minh Chung

**Project:** Ethernaut Level 2 - Fallout

---

## 1. Executive Summary

Hợp đồng `Fallout` được thiết kế nhằm mục đích kêu gọi vốn thông qua cơ chế phân bổ (`allocations`). Tuy nhiên, một lỗi đánh máy (typo) nghiêm trọng trong việc khai báo hàm khởi tạo (constructor) đã tạo ra một lỗ hổng bảo mật mức độ phá hoại. Bất kỳ người dùng nào cũng có thể trở thành chủ sở hữu của hợp đồng chỉ bằng một giao dịch thông thường, từ đó giành quyền kiểm soát toàn bộ số tiền đang được lưu trữ.

## 2. Risk Classification

| Severity   | Description                                                                                 |
| :--------- | :------------------------------------------------------------------------------------------ |
| **High**   | Lỗ hổng có thể dẫn đến mất toàn bộ tiền trong hợp đồng hoặc chiếm quyền quản trị hoàn toàn. |
| **Medium** | Lỗ hổng ảnh hưởng đến logic vận hành nhưng không gây mất tiền ngay lập tức.                 |
| **Low**    | Các lỗi liên quan đến tối ưu hóa Gas hoặc thực hành code không tốt.                         |

---

## 3. Findings Summary

| ID   | Title                                              | Severity | Status |
| :--- | :------------------------------------------------- | :------- | :----- |
| H-01 | Broken Access Control via Typo in Constructor Name | High     | Found  |

---

## 4. Detailed Findings

### [H-01] Broken Access Control via Typo in Constructor Name

**Description:**
Trong Solidity phiên bản cũ (trước 0.4.22), hàm khởi tạo được định nghĩa bằng tên trùng với tên hợp đồng. Tuy nhiên, ở đây có sự sai lệch:
1. Tên hợp đồng: `Fallout`
2. Tên hàm dự kiến làm constructor: `Fal1out` (Sử dụng số **1** thay vì chữ **l**).

Do tên không khớp, trình biên dịch hiểu `Fal1out` là một hàm public thông thường, có thể gọi được bất cứ lúc nào sau khi deploy.

**Impact:**
Kẻ tấn công có thể gọi hàm `Fal1out()` để thay đổi biến `owner` thành địa chỉ của mình. Sau khi chiếm quyền chủ sở hữu, kẻ tấn công có thể gọi hàm `collectAllocations()` để rút sạch Ether hiện có trong hợp đồng.

**Proof of Concept (PoC):**
1. Gọi hàm lỗi: `await contract.Fal1out({ value: toWei('0.0001') })`.
2. Xác nhận quyền sở hữu: `await contract.owner() == player`.
3. Rút tiền: `await contract.collectAllocations()`.

**Recommendation:**
- Đổi tên hàm cho đúng chính tả để trùng với tên contract.
- **Khuyến nghị:** Sử dụng phiên bản Solidity mới hơn và dùng từ khóa `constructor` rõ ràng để tránh các lỗi logic về tên gọi.

---

## 5. Vulnerable Code Snippet
```solidity
/* constructor */
// Lỗ hổng nằm ở việc sai tên hàm (Fal1out thay vì Fallout)
function Fal1out() public payable {
    owner = msg.sender;
    allocations[owner] = msg.value;
}
```
## 6. Conclusion
**Hợp đồng `Fallout` chứa một lỗi logic sơ đẳng nhưng cực kỳ nguy hiểm. Việc không kiểm tra kỹ tên hàm khởi tạo dẫn đến việc lộ lọt quyền quản trị tối cao.**

**Các nhà phát triển cần sử dụng trình biên dịch hiện đại và thực hiện `Unit Test` đầy đủ để phát hiện các lỗi typo tương tự trước khi deploy lên mainnet.**