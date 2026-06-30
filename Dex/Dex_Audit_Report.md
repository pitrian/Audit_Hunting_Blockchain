# Smart Contract Security Audit: Ethernaut Dex

**Date:** 01/07/2026

**Prepared by:** Minh Chung

**Project:** Ethernaut Level 22 - Dex

---

## 1. Executive Summary

Hợp đồng `Dex` đóng vai trò là một thị trường giao dịch phi tập trung tối giản cho phép hoán đổi giữa hai loại mã thông báo `token1` và `token2`. Hợp đồng tự cài đặt thuật toán tính giá dựa trên tỷ lệ thanh khoản hiện tại có trong bộ lưu trữ. Quá trình kiểm toán phát hiện một sai lầm toán học nghiêm trọng trong công thức định giá tự chế của hàm `getSwapPrice`. Việc thiếu cơ chế giữ hằng số thanh khoản và lỗi xử lý phép chia số nguyên đã tạo điều kiện cho kẻ tấn công thực hiện thao túng giá, rút cạn toàn bộ tài sản của sàn giao dịch.

## 2. Risk Classification

| Severity   | Description                                                                                                         |
| :--------- | :------------------------------------------------------------------------------------------------------------------ |
| **High**   | Lỗ hổng dẫn đến thất thoát toàn bộ tài sản trong bể thanh khoản hoặc phá hủy hoàn toàn logic kinh tế của giao thức. |
| **Medium** | Lỗi logic ảnh hưởng đến tính đúng đắn của dữ liệu nhưng có điều kiện ràng buộc.                                     |
| **Low**    | Lỗi tối ưu hóa Gas hoặc vi phạm các tiêu chuẩn viết code sạch.                                                      |

---

## 3. Findings Summary

| ID   | Title                                                                      | Severity | Status |
| :--- | :------------------------------------------------------------------------- | :------- | :----- |
| H-01 | Pool Liquidity Depletion via Flawed Automated Market Maker Pricing Formula | High     | Found  |

---

## 4. Detailed Findings

### [H-01] Pool Liquidity Depletion via Flawed Automated Market Maker Pricing Formula

**Description:**
Thuật toán định giá nội bộ của hợp đồng được cấu hình thông qua hàm sau:
    return ((amount * IERC20(to).balanceOf(address(this))) / IERC20(from).balanceOf(address(this)));

Công thức này vi phạm nguyên tắc thiết kế của các hệ thống AMM chuẩn hóa (như mô hình sản phẩm không đổi $x \times y = k$ của Uniswap). Do giá trị trả về tỷ lệ thuận hoàn toàn với số dư khả dụng tức thời của Pool, hành vi Swap liên tục toàn bộ số dư của người dùng sẽ tạo ra một xung lực trượt giá nhân tạo lớn. 

Sau mỗi chu kỳ hoán đổi qua lại, lượng token thu về của người dùng gia tăng theo cấp số nhân trong khi lượng lưu trữ của Pool giảm dần. Lỗ hổng này nghiêm trọng hơn do Solidity cắt bỏ phần thập phân trong phép chia số nguyên, làm biến dạng hoàn toàn tỷ giá thực tế có lợi cho kẻ tấn công.

**Impact:**
Mức độ ảnh hưởng là **Chí mạng (High)**. Toàn bộ nguồn vốn thanh khoản ban đầu của sàn giao dịch bị bòn rút hoàn toàn, phá hủy tính năng chuyển đổi tỷ giá của giao thức.

**Proof of Concept (PoC):**
Hành vi khai thác được tiến hành tuần tự theo chuỗi hoán đổi:
1. Thực hiện Swap liên tục toàn bộ số dư khả dụng của tài khoản từ Token1 sang Token2 và ngược lại.
2. Tại vòng thứ 6, tính toán lượng Token đầu vào chính xác dựa trên số dư còn lại của Pool nhằm tránh lỗi thiếu hụt thanh khoản (Revert).
3. Sau 6 lệnh gọi `swap()`, số dư của một trong hai token trong Pool bị rút cạn hoàn toàn về `0`.

**Recommendation:**
1. Tuyệt đối không tự thiết kế hoặc sử dụng các công thức định giá giao dịch tuyến tính dựa trực tiếp trên số dư thô (`balanceOf`) của token trong hợp đồng mà không có cơ chế giữ hằng số invariant.
2. Khuyến nghị tích hợp và sử dụng giải pháp Oracle giá phi tập trung (như Chainlink Price Feeds) hoặc áp dụng trực tiếp mô hình thư viện AMM đã qua kiểm định nghiêm ngặt như Uniswap V2/V3 để đảm bảo an toàn cho cấu trúc kinh tế của token.

---

## 5. Vulnerable Code Snippet

// Điểm yếu chí mạng nằm ở công thức tính toán giá thiếu hằng số bảo vệ thanh khoản
function getSwapPrice(address from, address to, uint256 amount) public view returns (uint256) {
    // Phép tính phụ thuộc trực tiếp vào số dư động biến thiên liên tục
    return ((amount * IERC20(to).balanceOf(address(this))) / IERC20(from).balanceOf(address(this))); 
}

---

## 6. Conclusion

Hợp đồng `Dex` là một bài học xương máu về lỗi thiết kế Logic kinh tế (Economic Design Flaw). Trong thế giới Smart Contract, lỗi mã hóa logic toán học nguy hiểm không kém gì lỗi bảo mật kỹ thuật. Việc thấu hiểu các mô hình toán học tài chính phi tập trung là yếu tố then chốt đối với một Auditor khi tiến hành đánh giá an toàn cho các giao thức DeFi hiện đại.