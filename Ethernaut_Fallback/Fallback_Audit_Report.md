# Smart Contract Security Audit: Ethernaut Fallback

**Date:** 29/04/2026
**Prepared by:** Minh Chung 
**Project:** Ethernaut Level 1 - Fallback

---

## 1. Executive Summary

Hợp đồng `Fallback` được thiết kế để nhận đóng góp từ người dùng, quản lý quyền sở hữu dựa trên mức đóng góp và cho phép chủ sở hữu rút tiền. Tuy nhiên, một lỗ hổng nghiêm trọng đã được phát hiện trong logic quản trị, cho phép bất kỳ người dùng nào cũng có thể chiếm quyền sở hữu hợp đồng với chi phí cực thấp và rút sạch tiền.

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
| H-01 | Insecure Ownership Transfer via `receive()` function | High | Found |

---

## 4. Detailed Findings

### [H-01] Insecure Ownership Transfer via `receive()` function

**Description:**
Hợp đồng định nghĩa một hàm `receive()` đặc biệt, hàm này được kích hoạt khi hợp đồng nhận Ether mà không kèm theo dữ liệu gọi hàm. Trong hàm này, biến `owner` được cập nhật trực tiếp cho người gửi (`msg.sender`) nếu họ thỏa mãn hai điều kiện:
1. Gửi một lượng Ether lớn hơn 0 (`msg.value > 0`).
2. Đã từng đóng góp trước đó thông qua hàm `contribute()` (`contributions[msg.sender] > 0`).

**Impact:**
Kẻ tấn công có thể dễ dàng vượt qua điều kiện đóng góp với một lượng nhỏ Ether (ví dụ 1 wei) thông qua hàm `contribute()`, sau đó gửi tiếp 1 wei nữa trực tiếp vào địa chỉ hợp đồng để chiếm quyền `owner`. Sau khi là chủ sở hữu, kẻ tấn công có toàn quyền gọi hàm `withdraw()` để lấy sạch tiền trong hợp đồng.

**Proof of Concept (PoC):**
1. Gọi `contract.contribute({ value: 1 })`.
2. Gửi Ether trực tiếp: `contract.sendTransaction({ value: 1 })`.
3. Kiểm tra quyền sở hữu: `contract.owner() == attacker_address`.
4. Rút tiền: `contract.withdraw()`.

**Recommendation:**
Không bao giờ thực hiện việc chuyển giao quyền sở hữu (`ownership transfer`) bên trong các hàm `fallback` hoặc `receive`. Việc chuyển đổi quyền sở hữu nên được thực hiện tường minh thông qua một hàm có sự kiểm soát của `owner` hiện tại.

---

## 5. Vulnerable Code Snippet

```solidity
// Lỗ hổng nằm ở hàm này
receive() external payable {
    require(msg.value > 0 && contributions[msg.sender] > 0); // Điều kiện quá yếu
    owner = msg.sender; // Chiếm quyền sở hữu tại đây
}
```
## 6. Conclusion
Hợp đồng Fallback chứa một lỗi logic quản trị nghiêm trọng. Việc sử dụng các hàm nhận tiền mặc định để thay đổi trạng thái quan trọng của hợp đồng là một thực hành cực kỳ nguy hiểm. Các nhà phát triển nên tuân thủ nguyên tắc "Least Privilege" và đảm bảo các hàm quản trị phải có cơ chế xác thực chặt chẽ.