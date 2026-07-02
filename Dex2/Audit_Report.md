# Smart Contract Security Audit: Ethernaut Dex Two

**Date:** 02/07/2026

**Prepared by:** Minh Chung

**Project:** Ethernaut Level 23 - Dex Two

---

## 1. Executive Summary

Hợp đồng `DexTwo` là một biến thể sửa đổi từ giao thức hoán đổi mã thông báo `Dex` trước đó. Mục tiêu của hệ thống là cung cấp tính năng chuyển đổi tỷ giá thanh khoản tự động cho cặp tài sản `token1` và `token2`. Qua rà soát mã nguồn kiểm toán, một sai sót nghiêm trọng trong cơ chế kiểm soát dữ liệu đầu vào đã được phát hiện tại hàm `swap()`. Việc thiếu bộ lọc giới hạn danh sách tài sản hợp lệ cho phép kẻ tấn công đưa một tài khoản token giả mạo vào cấu trúc tính giá nhằm thao túng và bòn rút toàn bộ ngân quỹ của giao thức.

## 2. Risk Classification

| Severity   | Description                                                                                                           |
| :--------- | :-------------------------------------------------------------------------------------------------------------------- |
| **High**   | Lỗ hổng cho phép thực thể độc hại lấy toàn bộ tiền của pool thanh khoản, phá vỡ hoàn toàn tính toàn vẹn của hợp đồng. |
| **Medium** | Lỗi logic hệ thống có thể gây sai lệch trạng thái nhưng đòi hỏi một số điều kiện biên đặc biệt.                       |
| **Low**    | Các vấn đề liên quan đến phong cách lập trình hoặc tối ưu lượng Gas tiêu thụ.                                         |

---

## 3. Findings Summary

| ID   | Title                                                                      | Severity | Status |
| :--- | :------------------------------------------------------------------------- | :------- | :----- |
| H-01 | Liquidity Theft via Arbitrary Unvalidated Token Injection in Swap Function | High     | Found  |

---

## 4. Detailed Findings

### [H-01] Liquidity Theft via Arbitrary Unvalidated Token Injection in Swap Function

**Description:**
Trong các kiến trúc sàn giao dịch phi tập trung (DEX), việc xác thực tài sản giao dịch là điều kiện tiên quyết. Tuy nhiên, hàm `swap()` trong `DexTwo` đã loại bỏ hoàn toàn ràng buộc kiểm tra địa chỉ hợp lệ:
    function swap(address from, address to, uint256 amount) public

Hợp đồng chấp nhận mọi địa chỉ tương thích giao thức `IERC20` do người dùng tự định nghĩa. Khi thực hiện tính toán giá trị đầu ra, hàm `getSwapAmount` gọi hàm kiểm tra số dư trực tiếp từ địa chỉ do người dùng chỉ định:
    return ((amount * IERC20(to).balanceOf(address(this))) / IERC20(from).balanceOf(address(this)));

Kẻ tấn công có thể tự triển khai một token rác do mình toàn quyền kiểm soát, tự ý thay đổi số dư mẫu số `IERC20(from).balanceOf(address(this))` bằng cách chuyển một lượng nhỏ mã thông báo trực tiếp vào địa chỉ `DexTwo`. Từ đó, kẻ tấn công dễ dàng thiết lập tỷ lệ quy đổi $1:1$ nhân tạo để vét sạch các token lưu trữ hợp pháp.

**Impact:**
Mức độ ảnh hưởng là **Chí mạng (High)**. Toàn bộ thanh khoản lưu trữ gồm cả `token1` và `token2` của giao thức bị bòn rút hoàn toàn không để lại dấu vết.

**Proof of Concept (PoC):**
Các bước thực thi bypass bao gồm:
1. Tạo một token rác đặt tên là `FakeToken`.
2. Gửi trực tiếp 100 `FakeToken` vào tài khoản ví của `DexTwo`.
3. Kích hoạt lệnh gọi `swap(address(FakeToken), token1, 100)`. Phép toán định giá xử lý: $(100 \times 100) / 100 = 100$, rút cạn hoàn toàn `token1`.
4. Tiếp tục gọi lệnh `swap(address(FakeToken), token2, 200)`. Lúc này số dư mẫu số tăng lên 200, phép toán xử lý: $(200 \times 100) / 200 = 100$, rút sạch hoàn toàn `token2`.

**Recommendation:**
Thêm rào cản xác thực nghiêm ngặt để đảm bảo tài sản đầu vào thuộc danh sách quản lý hợp pháp của hệ thống:
    function swap(address from, address to, uint256 amount) public {
        require((from == token1 && to == token2) || (from == token2 && to == token1), "DexTwo: Invalid token swap pair");
        // ...
    }

---

## 5. Vulnerable Code Snippet

// Hàm hoán đổi mở cửa hoàn toàn cho các địa chỉ token rác thâm nhập thao túng giá
function swap(address from, address to, uint256 amount) public {
    // Thiếu hoàn toàn dòng kiểm tra require kiểm soát địa chỉ biến "from" và "to"
    require(IERC20(from).balanceOf(msg.sender) >= amount, "Not enough to swap");
    uint256 swapAmount = getSwapAmount(from, to, amount);
    // ...
}

---

## 6. Conclusion

Hợp đồng `DexTwo` chỉ ra một lỗi sơ đẳng nhưng cực kỳ phổ biến trong lập trình Smart Contract: Thiếu kiểm soát dữ liệu đầu vào (Lack of Input Validation). Một nguyên tắc nằm lòng đối với các kỹ sư Web3 cũng như Auditor là: **"Tuyệt đối không tin tưởng bất kỳ dữ liệu hay địa chỉ nào do người dùng truyền vào mà không qua kiểm tra nghiêm ngặt."**