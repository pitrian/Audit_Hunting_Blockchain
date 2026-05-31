# Smart Contract Security Audit: Ethernaut Vault

**Date:** 31/05/2026

**Prepared by:** Minh Chung 


**Project:** Ethernaut Level 8 - Vault


---

## 1. Executive Summary

Hợp đồng `Vault` được thiết kế để bảo vệ một mật khẩu 32-bytes (`password`) và khóa trạng thái của hợp đồng. Chỉ những ai cung cấp chính xác mật khẩu thông qua hàm `unlock()` mới có thể mở khóa hợp đồng. Tuy nhiên, một lỗ hổng nghiêm trọng về bảo mật dữ liệu đã được phát hiện, cho phép bất kỳ ai cũng có thể đọc trộm mật khẩu này trực tiếp từ bộ nhớ lưu trữ của blockchain để bẻ khóa một cách dễ dàng.

## 2. Risk Classification

| Severity   | Description                                                                                 |
| :--------- | :------------------------------------------------------------------------------------------ |
| **High**   | Lỗ hổng có thể dẫn đến mất toàn bộ tiền trong hợp đồng hoặc chiếm quyền quản trị hoàn toàn. |
| **Medium** | Lỗ hổng ảnh hưởng đến logic vận hành nhưng không gây mất tiền ngay lập tức.                 |
| **Low**    | Các lỗi liên quan đến tối ưu hóa Gas hoặc thực hành code không tốt.                         |

---

## 3. Findings Summary

| ID   | Title                                                         | Severity | Status |
| :--- | :------------------------------------------------------------ | :------- | :----- |
| H-01 | Private State Variable Readability via EVM Storage Inspection | High     | Found  |

---

## 4. Detailed Findings

### [H-01] Private State Variable Readability via EVM Storage Inspection

**Description:**
Hợp đồng khai báo biến `password` với thuộc tính `private` nhằm mục đích che giấu mật khẩu:
    bytes32 private password;

Trong Solidity, từ khóa `private` chỉ có tác dụng ngăn chặn các hợp đồng khác truy cập hoặc đọc trực tiếp bằng mã nguồn ở tầng ứng dụng. Tuy nhiên, thuộc tính này hoàn toàn không có tính năng mã hóa dữ liệu trên môi trường Ethereum Virtual Machine (EVM). Mọi thông tin lưu trữ (Storage) của Smart Contract đều được công khai minh bạch trên các Node Blockchain.

Dựa theo quy tắc sắp xếp bộ nhớ (Storage Layout) của EVM:
* Biến `bool public locked` được xếp đầu tiên nên sẽ nằm trọn ở **Slot 0**.
* Biến `bytes32 private password` xếp thứ hai nên sẽ chiếm trọn vẹn 32 bytes của **Slot 1**.

**Impact:**
Tính năng bảo mật bằng mật khẩu của Vault hoàn toàn bị vô hiệu hóa. Kẻ tấn công chỉ cần sử dụng các hàm RPC tiêu chuẩn (như `eth_getStorageAt`) là có thể dễ dàng "đọc trộm" toàn bộ nội dung của Slot 1 mà không gặp bất kỳ rào cản nào. Sau khi lấy được chuỗi mật khẩu từ Slot 1, kẻ tấn công có thể trực tiếp gọi hàm `unlock()` để chuyển trạng thái `locked` từ `true` thành `false`, bẻ khóa hợp đồng thành công.

**Proof of Concept (PoC):**
1. Đọc dữ liệu thô tại Slot 1 thông qua Web3 Console để lấy mật khẩu rò rỉ:
    bytes32 leakedPassword = await web3.eth.getStorageAt(instance, 1);
2. Thực hiện tấn công mở khóa bằng cách truyền mật khẩu vừa tìm được vào hàm `unlock()`:
    await contract.unlock(leakedPassword);
3. Kiểm tra lại trạng thái hợp đồng xem đã bẻ khóa thành công chưa:
    await contract.locked(); // Trả về false

**Recommendation:**
Không bao giờ lưu trữ các thông tin nhạy cảm, mật khẩu hoặc các chuỗi văn bản thô chưa được mã hóa trực tiếp lên Storage của Smart Contract.
* Nếu ứng dụng bắt buộc phải sử dụng cơ chế xác thực mật khẩu, hãy chuyển sang lưu trữ chuỗi băm cryptographic (ví dụ: `keccak256(password)`) thay vì lưu chuỗi text thô.
* Khi người dùng kích hoạt mở khóa, họ sẽ truyền vào chuỗi mật khẩu gốc (preimage), và hợp đồng sẽ chỉ tiến hành so sánh kết quả băm để xác thực quyền truy cập.

---

## 5. Vulnerable Code Snippet

// Lỗ hổng nằm ở việc khai báo biến password là private nhưng không được mã hóa
contract Vault {
    bool public locked;
    bytes32 private password; 

    constructor(bytes32 _password) {
        locked = true;
        password = _password;
    }

    function unlock(bytes32 _password) public {
        if (password == _password) {
            locked = false;
        }
    }
}

---

## 6. Conclusion

Hợp đồng `Vault` phản ánh một sai lầm kinh điển về tính riêng tư và minh bạch dữ liệu trong thế giới Web3. Trên môi trường Blockchain, thuộc tính "private" không có nghĩa là bí mật. Các nhà phát triển cần hiểu rõ kiến trúc lưu trữ các ô nhớ (Storage Slot) của EVM để áp dụng các giải pháp mã hóa, hoặc cơ chế cam kết (Commitment Scheme) phù hợp khi xử lý các dữ liệu nhạy cảm.