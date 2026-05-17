# Smart Contract Security Audit: Ethernaut CoinFlip

**Date:** 17/05/2026

**Prepared by:** Minh Chung 

**Project:** Ethernaut Level 3 - CoinFlip

---

## 1. Executive Summary

Hợp đồng `CoinFlip` là một trò chơi tung đồng xu may rủi, yêu cầu người chơi đoán đúng kết quả (`true` hoặc `false`) liên tiếp 10 lần để chiến thắng. Tuy nhiên, một lỗ hổng nghiêm trọng liên quan đến nguồn tạo số ngẫu nhiên không an toàn (Insecure Randomness) đã được phát hiện. Toàn bộ logic tính toán kết quả của hợp đồng hoàn toàn dựa trên dữ liệu on-chain có thể đoán trước, cho phép kẻ tấn công xây dựng một hợp đồng độc hại để tính toán chính xác kết quả trong cùng một block và đạt tỉ lệ thắng tuyệt đối 100%.

---

## 2. Risk Classification

| Severity   | Description                                                                                                                   |
| :--------- | :---------------------------------------------------------------------------------------------------------------------------- |
| **High**   | Lỗ hổng có thể dẫn đến việc phá vỡ hoàn toàn logic cốt lõi của hợp đồng, thao túng trạng thái quản trị hoặc rút sạch tài sản. |
| **Medium** | Lỗ hổng ảnh hưởng đến logic vận hành nhưng yêu cầu điều kiện đặc biệt để khai thác.                                           |
| **Low**    | Các lỗi liên quan đến tối ưu hóa Gas hoặc thực hành code không tốt (Best Practices).                                          |

---

## 3. Findings Summary

| ID   | Title                                                       | Severity | Status |
| :--- | :---------------------------------------------------------- | :------- | :----- |
| H-01 | Predictable Randomness via On-chain Environmental Variables | High     | Found  |

---

## 4. Detailed Findings

### [H-01] Predictable Randomness via On-chain Environmental Variables

**Description:**
Hợp đồng `CoinFlip` sử dụng giá trị hash của block phía trước (`blockhash(block.number - 1)`) kết hợp với một hằng số cố định `FACTOR` để làm nguồn sinh số ngẫu nhiên cho việc quyết định kết quả lật xu.

Trong mạng lưới EVM, tất cả dữ liệu lịch sử block (bao gồm số block và blockhash) đều là thông tin công khai và có tính chất đồng nhất đối với tất cả các hợp đồng được thực thi trong cùng một block đó. 

Kẻ tấn công có thể triển khai một hợp đồng độc hại (Exploit Contract), sao chép y hệt công thức tính toán này. Vì giao dịch gọi từ hợp đồng tấn công sang hợp đồng `CoinFlip` diễn ra trong cùng một transaction (và cùng một block), giá trị `block.number` của cả hai bên là như nhau. Do đó, kết quả tính toán của kẻ tấn công luôn trùng khớp hoàn toàn với kết quả của hợp đồng mục tiêu.

**Impact:**
Logic may rủi của trò chơi bị vô hiệu hóa hoàn toàn. Kẻ tấn công có thể dễ dàng đạt được 10 trận thắng liên tiếp (hoặc vô hạn trận thắng) mà không gặp bất kỳ rủi ro nào. Đối với các hợp đồng cá cược hoặc sòng bạc on-chain thực tế, lỗ hổng này sẽ dẫn đến việc giao thức bị rút cạn toàn bộ tính thanh khoản.

**Proof of Concept (PoC):**
Kẻ tấn công triển khai một hợp đồng độc hại trỏ tới địa chỉ của `CoinFlip` và thực hiện hàm tấn công sau mỗi block:

1. Lấy giá trị `blockhash(block.number - 1)` hiện tại.
2. Chia cho hằng số `FACTOR` để xác định trước biến `side` sẽ là `true` hay `false`.
3. Gọi hàm `coinFlip.flip(side)` với kết quả vừa tính. 
4. Lặp lại quá trình này tại 10 block khác nhau để hoàn thành thử thách.

**Recommendation:**
* **Tuyệt đối không** sử dụng các thông số môi trường của block như `blockhash`, `block.timestamp`, `block.difficulty`, hoặc `coinbase` làm nguồn sinh số ngẫu nhiên cho các logic quan trọng hoặc ứng dụng mang tính bảo mật/trò chơi.
* **Giải pháp chuẩn công nghiệp:** Sử dụng các giải pháp Oracle phi tập trung cung cấp số ngẫu nhiên có thể xác thực được dưới dạng mật mã (Verifiable Random Function), ví dụ như **Chainlink VRF**. Cơ chế này đảm bảo số ngẫu nhiên được tạo ra ngoài chuỗi (off-chain) kèm theo bằng chứng mật mã chứng minh không ai (kể cả thợ đào hay validator) có thể thao túng hoặc dự đoán trước kết quả.

---

## 5. Vulnerable Code Snippet

    // Lỗ hổng nằm ở việc tính toán dựa trên dữ liệu công khai và có thể dự đoán trước trong cùng một block
    function flip(bool _guess) public returns (bool) {
        uint256 blockValue = uint256(blockhash(block.number - 1)); // <--- LỖ HỔNG CHÍ MẠNG

        if (lastHash == blockValue) {
            revert();
        }

        lastHash = blockValue;
        uint256 coinFlip = blockValue / FACTOR;
        bool side = coinFlip == 1 ? true : false;

        if (side == _guess) {
            consecutiveWins++;
            return true;
        } else {
            consecutiveWins = 0;
            return false;
        }
    }

---

## 6. Conclusion

Hợp đồng `CoinFlip` minh họa một trong những sai lầm phổ biến nhất của các nhà phát triển smart contract mới vào nghề: lầm tưởng rằng dữ liệu blockchain là ngẫu nhiên và an toàn. Trong môi trường phi tập trung của EVM, tính minh bạch đồng nghĩa với việc không có bí mật nào có thể giấu kín nếu nó nằm on-chain. Việc áp dụng các giải pháp kiến trúc oracle như Chainlink VRF là bắt buộc đối với bất kỳ hệ thống nào yêu cầu tính ngẫu nhiên minh bạch và không thể thao túng.