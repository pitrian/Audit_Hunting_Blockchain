# Smart Contract Security Audit: Ethernaut Delegation

**Date:** 25/05/2026

**Prepared by:** Ngô Minh Chung

**Project:** Ethernaut Level 6 - Delegation

---

## 1. Executive Summary

Hợp đồng `Delegation` được thiết kế nhằm mục đích ủy quyền thực thi logic sang hợp đồng thư viện `Delegate` thông qua cơ chế cuộc gọi cấp thấp `delegatecall`. Tuy nhiên, việc sử dụng `delegatecall` bên trong hàm `fallback()` mà không có bất kỳ cơ chế kiểm soát truy cập (Access Control) nào đã tạo ra một lỗ hổng bảo mật nghiêm trọng. Kẻ tấn công có thể lợi dụng điều này để thực thi mã độc hại trong ngữ cảnh của `Delegation`, từ đó chiếm quyền sở hữu (`owner`) toàn bộ hợp đồng một cách dễ dàng.

---

## 2. Risk Classification

| Severity   | Description                                                                                 |
| :--------- | :------------------------------------------------------------------------------------------ |
| **High**   | Lỗ hổng có thể dẫn đến mất toàn bộ tiền trong hợp đồng hoặc chiếm quyền quản trị hoàn toàn. |
| **Medium** | Lỗ hổng ảnh hưởng đến logic vận hành nhưng không gây mất tiền ngay lập tức.                 |
| **Low**    | Các lỗi liên quan đến tối ưu hóa Gas hoặc thực hành code không tốt.                         |

---

## 3. Findings Summary

| ID   | Title                                                     | Severity | Status |
| :--- | :-------------------------------------------------------- | :------- | :----- |
| H-01 | Arbitrary Delegatecall via Untrusted Calldata in Fallback | High     | Found  |

---

## 4. Detailed Findings

### [H-01] Arbitrary Delegatecall via Untrusted Calldata in Fallback

**Description:**
Hợp đồng `Delegation` chứa một hàm `fallback()` nhận mọi dữ liệu đầu vào (`msg.data`) và chuyển tiếp trực tiếp đến hợp đồng `Delegate` thông qua lệnh `delegatecall`:

    (bool result,) = address(delegate).delegatecall(msg.data);

Cơ chế `delegatecall` sẽ thực thi đoạn mã của hợp đồng mục tiêu (`Delegate`) nhưng giữ nguyên ngữ cảnh lưu trữ (Storage Slot) và thực thể gọi (`msg.sender`) của hợp đồng hiện tại (`Delegation`). 

Do cả hai hợp đồng `Delegate` và `Delegation` đều khai báo biến `address public owner;` tại **Slot 0** trong bố cục bộ nhớ (Storage Layout), bất kỳ hàm nào ở hợp đồng `Delegate` ghi đè lên vị trí Slot 0 cũng sẽ vô tình ghi đè trực tiếp lên cấu trúc lưu trữ `owner` của `Delegation`. 

Kẻ tấn công có thể truyền vào thuộc tính `msg.data` mã định danh (Method ID) của hàm `pwn()`. Khi cuộc gọi đi qua `fallback()`, hợp đồng `Delegate` nhận lệnh và thực thi `owner = msg.sender`, khiến ô nhớ Slot 0 của `Delegation` bị thay đổi vĩnh viễn sang địa chỉ ví của kẻ tấn công.

**Impact:**
Kẻ tấn công hoàn toàn chiếm được quyền quản trị cao nhất (`owner`) của hợp đồng `Delegation`. Một khi quyền sở hữu bị tước đoạt, mọi chức năng đặc quyền hoặc tài sản do hợp đồng nắm giữ (nếu có) sẽ rơi vào tay kẻ tấn công.

**Proof of Concept (PoC):**
Kiểm thử cục bộ (Local Unit Test) sử dụng Foundry khẳng định kịch bản tấn công thành công 100%:
1. Mã hóa chữ ký hàm mục tiêu: `bytes memory payload = abi.encodeWithSignature("pwn()");`
2. Đóng vai hacker thực hiện lệnh gọi cấp thấp qua địa chỉ của `Delegation`:

    vm.startPrank(hacker);
    (bool success, ) = address(delegationContract).call(payload);

3. Kết quả xác thực: `assertEq(delegationContract.owner(), hacker);` -> Thao tác ghi đè ô nhớ Slot 0 hoàn tất, hacker trở thành chủ sở hữu mới.

**Recommendation:**
- Tránh sử dụng cơ chế `delegatecall` một cách tùy tiện với dữ liệu người dùng (`msg.data`) không được lọc sạch hoặc kiểm soát.
- Nếu bắt buộc phải sử dụng các mô hình thư viện proxy, hãy áp dụng các bộ thư viện tiêu chuẩn đã được kiểm định của OpenZeppelin (ví dụ: `UUPSUpgradeable` hoặc `TransparentUpgradeableProxy`).
- Kiểm tra chặt chẽ quyền thực thi hoặc áp dụng whitelist các cấu trúc chữ ký hàm cho phép trong hàm `fallback()`.

---

## 5. Vulnerable Code Snippet

Lỗ hổng nằm ở việc ủy quyền thực thi dữ liệu tùy ý từ `msg.data` mà không có rào cản kiểm soát quyền truy cập:

    contract Delegation {
        address public owner; // Slot 0
        Delegate delegate;    // Slot 1

        // ... constructor ...

        fallback() external {
            // RỦI RO: Chuyển tiếp calldata bất kỳ sang một hợp đồng khác bằng delegatecall
            (bool result,) = address(delegate).delegatecall(msg.data);
            if (result) {
                this;
            }
        }
    }

---

## 6. Conclusion

**Hợp đồng `Delegation` minh họa một mô hình lỗ hổng kinh điển liên quan đến quản lý trạng thái khi sử dụng các lời gọi hàm cấp thấp trong Solidity. Việc kết hợp một hàm `fallback()` mở với cơ chế `delegatecall` lỏng lẻo biến hợp đồng thành một thực thể dễ bị thao túng bộ nhớ.**

**Các nhà phát triển cần đặc biệt lưu ý về Storage Layout khi làm việc với mô hình Proxy-Implementation và tuyệt đối không để lộ các cổng kết nối `delegatecall` tự do ra môi trường bên ngoài.**