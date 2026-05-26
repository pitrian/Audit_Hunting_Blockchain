# Smart Contract Security Audit: Ethernaut Token

**Date:** 24/05/2026

**Prepared by:** Minh Chung (junior Auditor)

**Project:** Ethernaut Level 5 - Token

---

## 1. Executive Summary

Hợp đồng `Token` được thiết kế để triển khai một hệ thống chuyển tiền token ERC-20 đơn giản, quản lý nguồn cung và số dư của người dùng. Tuy nhiên, qua quá trình kiểm toán thực tế, chúng tôi đã phát hiện một lỗ hổng **Integer Underflow** cực kỳ nghiêm trọng trong hàm `transfer` cùng lỗi vi phạm tiêu chuẩn thiết kế ERC-20 (thiếu Event Log). Các lỗ hổng này cho phép người dùng lách qua cơ chế kiểm tra điều kiện để tự tạo ra số dư vô hạn, đồng thời làm mất khả năng theo dõi dòng tiền của các ứng dụng off-chain.

---

## 2. Risk Classification

| Severity     | Description                                                                                                                    |
| :----------- | :----------------------------------------------------------------------------------------------------------------------------- |
| **Critical** | Lỗ hổng cho phép bypass cơ chế kiểm soát số dư, tạo ra nguồn cung vô hạn và thao túng trạng thái sổ cái một cách bất hợp pháp. |
| **High**     | Lỗ hổng có thể dẫn đến việc phá vỡ logic cốt lõi của hợp đồng hoặc rút sạch tài sản nhưng cần một số điều kiện biên.           |
| **Medium**   | Lỗ hổng ảnh hưởng đến logic vận hành hoặc vi phạm nghiêm trọng tiêu chuẩn ERC (EIP-20) gây lỗi tích hợp hệ thống.              |
| **Low**      | Các lỗi liên quan đến tối ưu hóa Gas hoặc thực hành code không tốt (Best Practices).                                           |

---

## 3. Findings Summary

| ID   | Title                                                     | Severity | Status |
| :--- | :-------------------------------------------------------- | :------- | :----- |
| C-01 | Integer Underflow in `transfer` Function                  | Critical | Found  |
| M-01 | Missing `Transfer` Event Emission (ERC-20 Non-compliance) | Medium   | Found  |

---

## 4. Detailed Findings

### [C-01] Integer Underflow in `transfer` Function

**Description:**
Hợp đồng được biên dịch với cấu hình Solidity phiên bản `pragma solidity ^0.6.0`. Tại các phiên bản cũ này, các phép toán số học trên kiểu dữ liệu số nguyên không dấu (`uint256`) không được tích hợp sẵn cơ chế kiểm tra tràn số (Bound Checking).

Lỗ hổng nằm trực tiếp tại dòng ràng buộc điều kiện:
`require(balances[msg.sender] - _value >= 0);`

Khi người dùng thực hiện lệnh chuyển đi một lượng token `_value` lớn hơn số dư hiện tại của họ (`balances[msg.sender]`), máy ảo EVM sẽ thực hiện phép tính trừ trước. Vì là kiểu số nguyên không dấu, kết quả không thể âm, dẫn đến hiện tượng **Underflow** (quay đầu số). Giá trị kết quả sẽ cuộn ngược từ số `0` về giá trị tối đa của 256-bit (tương đương 2^256 - 1). 

Do một số cực lớn hiển nhiên thỏa mãn điều kiện `>= 0`, biểu thức `require` hoàn toàn bị vô hiệu hóa (Bypass).

**Impact:**
Ngay sau khi vượt qua `require`, dòng tiếp theo `balances[msg.sender] -= _value;` sẽ chính thức cập nhật số dư của kẻ tấn công thành con số khổng lồ. Kẻ tấn công có thể tạo ra lượng token vô hạn từ hư không mà không cần sở hữu bất kỳ tài sản nào trước đó.

**Proof of Concept (PoC):**
Giao thức cấp cho người chơi (địa chỉ ví `player`) số dư ban đầu là `20` token. Kẻ tấn công thực thi các bước sau thông qua Developer Console:

1. Gọi hàm `transfer` chuyển đi `21` token đến một địa chỉ bất kỳ:
   `await contract.transfer("0x0000000000000000000000000000000000000000", 21)`
2. Phép tính toán học diễn ra tại EVM: 20 - 21 = 2^256 - 1.
3. Hàm `require` kiểm tra: (2^256 - 1) >= 0 => **True**. Giao dịch được chấp nhận.
4. Kiểm tra lại số dư tài khoản bằng hàm `balanceOf`:
   `await contract.balanceOf(player)`
   Kết quả trả về một đối tượng `BigNumber` có giá trị chuỗi tương đương với 2^256 - 1, chứng minh lỗ hổng đã được khai thác thành công.

**Recommendation:**
* **Giải pháp tối ưu:** Nâng cấp mã nguồn hợp đồng lên các phiên bản **Solidity ^0.8.0**. Kể từ phiên bản này, trình biên dịch sẽ tự động sinh mã kiểm tra tràn số (Panic Error) và `revert` giao dịch ngay lập tức nếu phát hiện Overflow/Underflow.
* **Giải pháp thay thế (cho phiên bản cũ):** Sử dụng thư viện **SafeMath** của OpenZeppelin để bọc toàn bộ các phép toán. Đoạn code sửa đổi bắt buộc phải sử dụng hàm `.sub()` bảo mật thay cho dấu trừ thông thường:
  ```solidity
  require(balances[msg.sender] >= _value, "Số dư không đủ");
  balances[msg.sender] = balances[msg.sender].sub(_value);
  ```

---

### [M-01] Missing `Transfer` Event Emission (ERC-20 Non-compliance)

**Description:**
Theo tiêu chuẩn token ERC-20 (EIP-20), bất kỳ hành động nào làm thay đổi số dư của các tài khoản (như hàm `transfer` và `transferFrom`) **bắt buộc** phải phát ra sự kiện `Transfer`. Tuy nhiên, trong hàm `transfer` hiện tại của hợp đồng, sự kiện này hoàn toàn bị bỏ sót sau khi trạng thái sổ cái thay đổi.

**Impact:**
* Các ứng dụng bên ngoài (Off-chain dApps), giao diện Frontend, ví điện tử (như MetaMask), và các công ty phân tích dữ liệu chuỗi (như Etherscan) dựa vào Event Logs để cập nhật số dư thời gian thực. Việc thiếu sự kiện này khiến giao dịch diễn ra trong "âm thầm", hệ thống off-chain không thể đồng bộ hóa lịch sử chuyển tiền của token.

**Recommendation:**
Khai báo sự kiện `Transfer` ở phần đầu hợp đồng và kích hoạt nó bằng từ khóa `emit` ngay trước khi kết thúc hàm `transfer`:
```solidity
// Khai báo ở trên cùng contract
event Transfer(address indexed from, address indexed to, uint256 value);

// Thêm vào cuối hàm transfer
balances[msg.sender] -= _value;
balances[_to] += _value;
emit Transfer(msg.sender, _to, _value); // <--- SỬA TẠI ĐÂY
return true;
```

---

## 5. Vulnerable Code Snippet

```solidity
    function transfer(address _to, uint256 _value) public returns (bool) {
        // LỖ HỔNG CHÍ MẠNG: Phép trừ bị underflow trước khi require so sánh
        require(balances[msg.sender] - _value >= 0); 
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        // THIẾU SÓT: Không có emit Transfer(msg.sender, _to, _value); ở đây
        return true;
    }
```

---

## 6. Conclusion

Hợp đồng `Token` minh họa một trong những lỗ hổng kinh điển và nguy hiểm nhất trong lịch sử bảo mật Smart Contract. Việc tính toán số học thiếu an toàn kết hợp với việc không tuân thủ nghiêm ngặt tiêu chuẩn EIP-20 khiến hợp đồng này gặp rủi ro lớn cả về mặt bảo mật lẫn khả năng tích hợp hệ thống. Đội ngũ kiểm toán khuyến nghị **KHÔNG** triển khai mã nguồn này lên Mainnet và yêu cầu tái cấu trúc toàn bộ các toán tử toán học cùng Event Log theo khuyến nghị ở mục 4.