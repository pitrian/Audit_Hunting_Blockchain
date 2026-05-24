# Smart Contract Security Audit: Ethernaut Telephone

**Date:** 19/05/2026  
**Prepared by:** Minh Chung (Cren)  
**Project:** Ethernaut Level 4 - Telephone  

---

## 1. Executive Summary

Hợp đồng `Telephone` định nghĩa một hàm thay đổi quyền sở hữu `changeOwner()` nhằm cho phép ủy quyền quản trị sang một địa chỉ mới dựa trên một bộ lọc điều kiện cụ thể. Tuy nhiên, qua quá trình rà soát kiểm soát truy cập, một lỗ hổng nghiêm trọng đã được phát hiện trong cơ chế xác thực luồng giao dịch. Lỗ hổng này cho phép kẻ tấn công dễ dàng vượt qua bộ lọc bằng cách sử dụng một hợp đồng thông minh trung gian làm proxy, từ đó chiếm đoạt hoàn toàn đặc quyền `owner`.

---

## 2. Risk Classification

| Severity | Description |
| :--- | :--- |
| **High** | Lỗ hổng có thể dẫn đến mất toàn bộ tiền trong hợp đồng, thay đổi trạng thái quan trọng hoặc chiếm quyền quản trị hoàn toàn. |
| **Medium** | Lỗ hổng ảnh hưởng đến logic vận hành hoặc gây gián đoạn dịch vụ nhưng không làm mất tài sản ngay lập tức. |
| **Low** | Các lỗi liên quan đến tối ưu hóa Gas, thực hành code không chuẩn (Bad practices) hoặc hiển thị thông tin. |

---

## 3. Findings Summary

| ID | Title | Severity | Status |
| :--- | :--- | :--- | :--- |
| H-01 | Insecure Access Control via Authorization Flaw in `tx.origin` | High | Exploited |

---

## 4. Detailed Findings

### [H-01] Insecure Access Control via Authorization Flaw in `tx.origin`

**Description:** Hợp đồng sử dụng biến toàn cục `tx.origin` để xác thực và lọc quyền truy cập trong hàm `changeOwner(address _owner)` thông qua điều kiện:
```solidity
if (tx.origin != msg.sender)
```
Mục đích ban đầu của nhà phát triển là tạo ra một rào cản ngăn chặn hành vi gọi ngoài ý muốn. Tuy nhiên, trong mô hình thực thi của Ethereum:
1. `tx.origin` luôn là địa chỉ của ví cá nhân (EOA) ký và kích hoạt giao dịch đầu tiên.
2. `msg.sender` là địa chỉ của thực thể trực tiếp gọi vào hợp đồng hiện tại (có thể là một hợp đồng thông minh khác).

Nếu người dùng tương tác với hợp đồng `Telephone` thông qua một hợp đồng thông minh trung gian tấn công (`AttackContract`), mối quan hệ logic sẽ là: `tx.origin != msg.sender` (Ví cá nhân khác địa chỉ hợp đồng tấn công). Điều này vô tình làm thỏa mãn điều kiện `if` và kích hoạt lệnh gán quyền sở hữu bất hợp pháp.

**Impact:** Kẻ tấn công có thể dễ dàng chiếm toàn quyền kiểm soát biến trạng thái `owner` của hợp đồng, phá vỡ hoàn toàn hệ thống phân quyền nội bộ mà không cần sự cho phép của chủ sở hữu cũ.

**Proof of Concept (PoC):** 
1. Lấy chính xác địa chỉ instance của hợp đồng mục tiêu bằng lệnh `contract.address` (ví dụ: `0x41bbaFb412d25b0b3bb938B28a10B7205524FA9D`).
2. Triển khai hợp đồng tấn công `AttackTelephone` lên mạng lưới với tham số khởi tạo là địa chỉ instance vừa lấy.
3. Sử dụng ví cá nhân gọi hàm `attack()` trên hợp đồng tấn công. Hoạt động này tạo ra chuỗi cuộc gọi: `Ví cá nhân (tx.origin) -> Attack Contract -> Telephone Contract (msg.sender)`.
4. Điều kiện `tx.origin != msg.sender` được thỏa mãn. Kiểm tra lại trạng thái: `contract.owner() == attacker_address`.

**Recommendation:** Tuyệt đối không sử dụng biến `tx.origin` phục vụ cho mục đích phân quyền hay xác thực quyền truy cập dưới bất kỳ hình thức nào để tránh các cuộc tấn công lừa đảo ủy nhiệm (Phishing/Proxy attack). Hãy sử dụng giải pháp chuẩn mực bằng cách quản lý quyền sở hữu dựa trên `msg.sender` kết hợp với thư viện `Ownable` của OpenZeppelin.

---

## 5. Vulnerable Code Snippet

```solidity
function changeOwner(address _owner) public {
    // Lỗ hổng nằm ở điều kiện kiểm tra logic này
    if (tx.origin != msg.sender) { 
        owner = _owner; // Chiếm quyền sở hữu trái phép tại đây
    }
}
```

---

## 6. Conclusion

Hợp đồng Telephone chứa một lỗi nghiêm trọng trong việc nhận diện thực thể giao dịch. Việc hiểu sai bản chất kiến trúc giữa `tx.origin` và `msg.sender` là nguyên nhân cốt lõi dẫn đến lỗ hổng kiểm soát truy cập này. Các nhà phát triển cần tuân thủ nghiêm ngặt việc sử dụng `msg.sender` cho xác thực quyền hạn và thực hiện kiểm thử đầy đủ các kịch bản tương tác đa hợp đồng (Cross-contract calls) trước khi triển khai thực tế.
