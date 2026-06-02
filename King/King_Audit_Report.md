# Smart Contract Security Audit: Ethernaut King

**Date:** 02/06/2026
**Prepared by:** Minh Chung
**Project:** Ethernaut Level 9 - King

---

## 1. Executive Summary

Hợp đồng `King` triển khai một trò chơi đơn giản: người chơi gửi một lượng Ether lớn hơn hoặc bằng giá trị phần thưởng hiện tại (`prize`) sẽ trở thành nhà vua mới (`king`), đồng thời số tiền này sẽ được hoàn trả lại cho nhà vua cũ. Tuy nhiên, một lỗ hổng nghiêm trọng thuộc nhóm Denial of Service (DoS) đã được phát hiện trong cơ chế phân phối lại Ether. Kẻ tấn công có thể vĩnh viễn chiếm giữ ngôi vị nhà vua và đóng băng toàn bộ hoạt động của hợp đồng mà không ai có thể lật đổ được.

## 2. Risk Classification

| Severity   | Description                                                                                 |
| :--------- | :------------------------------------------------------------------------------------------ |
| **High**   | Lỗ hổng có thể dẫn đến mất toàn bộ tiền trong hợp đồng hoặc chiếm quyền quản trị hoàn toàn. |
| **Medium** | Lỗ hổng ảnh hưởng đến logic vận hành nhưng không gây mất tiền ngay lập tức.                 |
| **Low**    | Các lỗi liên quan đến tối ưu hóa Gas hoặc thực hành code không tốt.                         |

---

## 3. Findings Summary

| ID   | Title                                                   | Severity | Status |
| :--- | :------------------------------------------------------ | :------- | :----- |
| H-01 | Denial of Service (DoS) via Unchecked External Transfer | High     | Found  |

---

## 4. Detailed Findings

### [H-01] Denial of Service (DoS) via Unchecked External Transfer

**Description:**
Lỗ hổng nằm ở cơ chế chuyển tiền cho nhà vua cũ bên trong hàm `receive()` đặc biệt:
    payable(king).transfer(msg.value);

Hợp đồng sử dụng hàm `.transfer()` để chuyển Ether đến địa chỉ của nhà vua hiện tại (`king`) trước khi cập nhật người chơi mới lên làm vua. Đặc tính của hàm `.transfer()` là nó giới hạn lượng Gas cố định ở mức 2300 gas và sẽ tự động `revert` toàn bộ giao dịch nếu địa chỉ nhận tiền từ chối nhận Ether hoặc xử lý thất bại.

Nếu một người chơi tương tác thông qua một hợp đồng thông minh (Smart Contract) thay vì ví cá nhân (EOA), hợp đồng đó hoàn toàn có quyền kiểm soát hành vi nhận tiền bằng cách cấu hình không tiếp nhận Ether hoặc chủ động kích hoạt lệnh `revert()`. khi hợp đồng độc hại này đã lên làm vua, không một ai khác có thể gửi tiền vào hàm `receive()` được nữa, vì lệnh xử lý hoàn tiền cho vua cũ luôn luôn thất bại.

**Impact:**
Mức độ ảnh hưởng là **Chí mạng (High)**. Trò chơi bị đóng băng hoàn toàn. Kẻ tấn công giữ vững ngôi vua vĩnh viễn và ngăn chặn mọi người chơi khác tham gia trò chơi, bẻ gãy hoàn toàn logic nghiệp vụ của hợp đồng.

**Proof of Concept (PoC):**
Auditor triển khai một hợp đồng độc hại để thực hiện cuộc tấn công Denial of Service theo các bước sau:

1. Tạo hợp đồng tấn công `KingAttacker` cố tình chặn mọi dòng tiền gửi đến:
    contract KingAttacker {
        function attack(address payable target) public payable {
            // Gửi Ether kèm dữ liệu trống để kích hoạt hàm receive() của mục tiêu nhằm chiếm ngôi vua
            (bool success, ) = target.call{value: msg.value}("");
            require(success, "Attack failed");
        }
        
        // Cố tình không khai báo receive() hoặc fallback() để từ chối nhận Ether, ép hàm .transfer() của nạn nhân bị revert
    }

2. Kẻ tấn công gọi hàm `attack()` với lượng Ether lớn hơn `prize` hiện tại để trở thành `king`.
3. Khi hệ thống Ethernaut hoặc một người chơi bất kỳ tìm cách gửi tiền nhiều hơn để giành lại quyền lực, lệnh `payable(king).transfer()` thực thi, gọi đến hợp đồng `KingAttacker`. Do không có hàm nhận tiền, giao dịch bị rollback hoàn toàn. Kẻ tấn công giữ ngôi vua mãi mãi.

**Recommendation:**
Thay đổi kiến trúc phân phối tiền từ mô hình "Đẩy tiền tự động" (Push Pattern) sang mô hình "Tự rút tiền" (Pull Pattern). Đây là mẫu thiết kế chuẩn để phòng chống tấn công DoS trong Solidity.

* Thiết kế một biến Mapping để ghi nhận số tiền mà các cựu vương được quyền nhận lại.
* Tạo một hàm riêng biệt (ví dụ: `claimReward()`) để người dùng tự chủ động vào rút tiền của mình ra. Như vậy, nếu contract của một ai đó bị lỗi khi nhận tiền, nó chỉ tự làm ảnh hưởng đến chính tài sản của họ chứ không thể làm đóng băng toàn bộ hệ thống.

---

## 5. Vulnerable Code Snippet

// Lỗ hổng nằm ở luồng xử lý đồng bộ gửi tiền cho bên thứ ba trước khi đổi trạng thái
contract King {
    address king;
    uint256 public prize;
    address public owner;

    receive() external payable {
        require(msg.value >= prize || msg.sender == owner);
        // ĐIỂM YẾU: Nếu địa chỉ "king" từ chối nhận tiền, toàn bộ hàm receive() sẽ bị kẹt vĩnh viễn
        payable(king).transfer(msg.value); 
        king = msg.sender;
        prize = msg.value;
    }
}

---

## 6. Conclusion

Hợp đồng `King` là ví dụ minh họa kinh điển cho thấy sự nguy hiểm của việc tin tưởng vào các thực thể bên ngoài khi xử lý luồng luân chuyển tài sản. Việc phụ thuộc vào sự thành công của một transaction chuyển khoản bên ngoài để cập nhật trạng thái quan trọng nội bộ luôn tiềm ẩn rủi ro Denial of Service rất lớn. Luôn ưu tiên thiết kế hệ thống theo mô hình "Pull over Push" để đảm bảo tính sẵn sàng và cô lập rủi ro cho hợp đồng thông minh.