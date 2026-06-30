# Smart Contract Security Audit: Ethernaut Naught Coin

**Date:** 30/06/2026

**Prepared by:** Minh Chung

**Project:** Ethernaut Level 15 - Naught Coin

---

## 1. Executive Summary

Hợp đồng `NaughtCoin` triển khai một cơ chế phân phối mã thông báo tiêu chuẩn ERC20, tích hợp thêm điều khoản khóa token (Timelock) trong thời hạn 10 năm đối với người chơi gốc. Mục tiêu thiết kế của dự án là ngăn chặn hoàn toàn mọi hành vi chuyển nhượng token của người chơi ra thị trường trước khi thời hạn kết thúc. Tuy nhiên, một sai sót nghiêm trọng trong tư duy tích hợp tiêu chuẩn (Standard Integration) đã được phát hiện. Việc chỉ thực hiện vá lỗ hổng cục bộ trên hàm `transfer` mà bỏ quên các hàm phụ trợ trong cùng tiêu chuẩn đã tạo điều kiện cho người chơi rút toàn bộ tài sản một cách hợp lệ.

## 2. Risk Classification

| Severity   | Description                                                                                               |
| :--------- | :-------------------------------------------------------------------------------------------------------- |
| **High**   | Lỗ hổng có thể dẫn đến mất toàn bộ tiền trong hợp đồng hoặc phá vỡ hoàn toàn quy trình nghiệp vụ cốt lõi. |
| **Medium** | Lỗ hổng ảnh hưởng đến logic vận hành nhưng không gây mất tiền ngay lập tức.                               |
| **Low**    | Các lỗi liên quan đến tối ưu hóa Gas hoặc thực hành code không tốt.                                       |

---

## 3. Findings Summary

| ID   | Title                                                                        | Severity | Status |
| :--- | :--------------------------------------------------------------------------- | :------- | :----- |
| H-01 | Business Logic Timelock Bypass via Unprotected ERC20 `transferFrom` Function | High     | Found  |

---

## 4. Detailed Findings

### [H-01] Business Logic Timelock Bypass via Unprotected ERC20 `transferFrom` Function

**Description:**
Hợp đồng thực hiện ghi đè (`override`) hàm `transfer` của thư viện OpenZeppelin và gắn kèm bộ lọc `lockTokens` nhằm ngăn chặn người chơi di chuyển token:
    function transfer(address _to, uint256 _value) public override lockTokens returns (bool)

Tuy nhiên, tiêu chuẩn ERC20 cung cấp hai phương thức độc lập để thực hiện chuyển dịch số dư giữa các tài khoản:
1. Phương thức chuyển trực tiếp: `transfer(to, value)`.
2. Phương thức chuyển gián tiếp thông qua bên thứ ba: `approve(spender, value)` kết hợp với `transferFrom(from, to, value)`.

Do nhà phát triển chỉ tập trung cấu hình bảo vệ hàm `transfer`, hàm `transferFrom` kế thừa từ `ERC20.sol` vẫn hoàn toàn ở trạng thái mặc định và không bị ràng buộc bởi bất kỳ cơ chế kiểm tra dòng thời gian `lockTokens` nào. Kẻ tấn công có thể lợi dụng kẽ hở phân quyền này bằng cách tự ủy quyền chi tiêu cho một tài khoản phụ, sau đó dùng tài khoản phụ gọi lệnh rút tiền gián tiếp ra ngoài.

**Impact:**
Mức độ ảnh hưởng là **Chí mạng (High)**. Toàn bộ cơ chế Timelock khóa token trong vòng 10 năm của dự án bị vô hiệu hóa hoàn toàn ngay lập tức. Kẻ tấn công có thể thanh khoản hoặc chuyển nhượng toàn bộ số token tự do bất cứ lúc nào.

**Proof of Concept (PoC):**
Hành vi bypass được chứng minh qua chuỗi tương tác sau:
1. Người chơi (`player`) gọi hàm `approve(attackerAddress, INITIAL_SUPPLY)` để cấp quyền tối đa cho tài khoản phụ được phép tiêu token. Giao dịch này thành công vì hàm `approve` không có bộ lọc.
2. Kẻ tấn công sử dụng tài khoản phụ đã được cấp quyền, kích hoạt lệnh gọi `transferFrom(player, attackerAddress, INITIAL_SUPPLY)`.
3. Hệ thống xử lý khấu trừ số dư của người chơi về bằng `0` mà không kích hoạt bất kỳ cảnh báo lỗi Revert nào.

**Recommendation:**
Khi thực hiện nâng cấp hoặc sửa đổi hành vi của một tiêu chuẩn mã nguồn mở (như ERC20, ERC721), bắt buộc phải rà soát và áp dụng đồng bộ các bộ lọc an ninh lên TOÀN BỘ các hàm có khả năng thay đổi trạng thái số dư tương tự. Đối với trường hợp này, cần bổ sung ghi đè hàm `transferFrom` và áp dụng modifier tương tự:
    function transferFrom(address _from, address _to, uint256 _value) public override lockTokens returns (bool) {
        return super.transferFrom(_from, _to, _value);
    }

---

## 5. Vulnerable Code Snippet

// Hợp đồng chỉ ghi đè hàm transfer công khai, bỏ quên hoàn toàn hàm transferFrom của lớp cha
contract NaughtCoin is ERC20 {
    // ...
    function transfer(address _to, uint256 _value) public override lockTokens returns (bool) {
        super.transfer(_to, _value);
    }
    // Lỗ hổng: Hàm transferFrom mặc định của OpenZeppelin ERC20 không bị lockTokens giám sát
}

---

## 6. Conclusion

Hợp đồng `NaughtCoin` mang lại bài học lớn về việc Audit các lỗi Logic tích hợp tiêu chuẩn. Một hệ thống chỉ an toàn khi tất cả các cửa ngõ dẫn đến sự thay đổi trạng thái đều được bảo vệ nghiêm ngặt. Việc chỉ đóng cửa chính (`transfer`) nhưng để mở cửa sổ (`transferFrom`) là nguyên nhân phổ biến dẫn tới các vụ hack nghiêm trọng trong các giao thức DeFi thực tế.