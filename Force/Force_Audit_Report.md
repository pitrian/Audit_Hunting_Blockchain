# Smart Contract Security Audit: Ethernaut Force

**Date:** 25/05/2026  
**Prepared by:** Ngô Minh Chung  
**Project:** Ethernaut Level 7 - Force  

---

## 1. Executive Summary

Hợp đồng `Force` là một hợp đồng hoàn toàn trống rỗng, không chứa bất kỳ logic xử lý nào, đồng thời không khai báo các hàm nhận tiền tiêu chuẩn như `receive()` hay `fallback() external payable`. Mục tiêu của bài kiểm tra là tìm cách tăng số dư (balance) của hợp đồng này lên lớn hơn 0. 

Lỗ hổng không nằm ở bản thân mã nguồn của hợp đồng, mà nằm ở một đặc tính cố hữu của mạng lưới Ethereum (**EVM-level feature**): cơ chế tự hủy `selfdestruct` cho phép ép buộc chuyển Ether vào một địa chỉ bất kỳ mà không kích hoạt các điều kiện kiểm tra hay hàm nhận tiền của hợp đồng mục tiêu.

---

## 2. Risk Classification

| Severity     | Description                                                                                                                                                 |
| :----------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 🔴 **High**   | Lỗ hổng có thể dẫn đến việc phá vỡ các logic tính toán dựa trên số dư thực tế (`address(this).balance`), gây sai lệch trạng thái nghiêm trọng của hệ thống. |
| 🟡 **Medium** | Ảnh hưởng đến luồng vận hành luân chuyển dòng tiền nhưng không gây đóng băng hệ thống hoặc thất thoát tài sản ngay lập tức.                                 |
| 🔵 **Low**    | Các vấn đề tối ưu hóa gas hoặc thiết kế mã nguồn chưa tối ưu, ít nguy cơ bị khai thác trực tiếp.                                                            |

---

## 3. Findings Summary

|    ID    | Title                                                | Severity |  Status   |
| :------: | :--------------------------------------------------- | :------: | :-------: |
| **H-01** | Forced Ether Injection via Contract Self-Destruction |  🔴 High  | **Found** |

---

## 4. Detailed Findings

### [H-01] Forced Ether Injection via Contract Self-Destruction

#### Description
Trong Solidity, một hợp đồng thông thường muốn nhận Ether thì bắt buộc phải triển khai hàm `receive()` hoặc `fallback() external payable`. Nếu không, mọi giao dịch gửi Ether thông thường đến hợp đồng đó đều sẽ bị EVM từ chối và revert.

Tuy nhiên, có một số kịch bản ngoại lệ trong EVM cho phép bỏ qua cơ chế bảo vệ này để đưa Ether vào hợp đồng một cách cưỡng bức. Phương pháp phổ biến nhất là sử dụng mã opcode `SELFDESTRUCT`. Khi một hợp đồng thực thi lệnh tự hủy, toàn bộ số dư Ether hiện có của nó sẽ được mạng lưới ép gửi thẳng về một địa chỉ mục tiêu được chỉ định:

\`\`\`solidity
selfdestruct(payable(targetAddress));
\`\`\`

Quá trình chuyển tiền này diễn ra hoàn toàn ở cấp độ EVM và không thực hiện bất kỳ lời gọi hàm (call) nào tới hợp đồng mục tiêu. Do đó, hợp đồng mục tiêu dù không chứa hàm nhận tiền vẫn bị tăng số dư lên một cách thụ động mà không có cách nào từ chối.

#### Impact
Việc có thể ép buộc nạp Ether vào một hợp đồng tưởng chừng như "khép kín" sẽ gây ra hậu quả cực kỳ nghiêm trọng nếu các nhà phát triển sử dụng thuộc tính `address(this).balance` làm điều kiện logic cốt lõi. 

* **Hệ quả:** Kẻ tấn công có thể dễ dàng phá vỡ các điều kiện logic nghiêm ngặt (như các hàm tính toán tỉ lệ chia thưởng, kiểm tra điều kiện để khóa/mở khóa quỹ, hoặc các trò chơi dựa trên số dư chính xác) bằng cách truyền dư thừa một lượng nhỏ Ether vào hợp đồng thông qua một hợp đồng trung gian tự hủy.

#### Proof of Concept (PoC)
Kiểm thử cục bộ (Local Unit Test) khẳng định kịch bản tấn công thành công bằng cách tạo một hợp đồng trung gian thực hiện nạp tiền và tự hủy:

1. **Triển khai hợp đồng tấn công độc hại nhận tiền thông qua constructor:**
\`\`\`solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ForceAttack {
    constructor() payable {}
    
    function attack(address payable target) public {
        selfdestruct(target);
    }
}
\`\`\`

2. **Thực hiện kịch bản tấn công trong Foundry Test:**
\`\`\`solidity
function testForceAttack() public {
    // Nạp sẵn 1 ether vào hợp đồng tấn công khi deploy
    ForceAttack attacker = new ForceAttack{value: 1 ether}();
    
    // Kích hoạt tự hủy để đẩy tiền sang hợp đồng Force trống
    attacker.attack(payable(address(forceContract)));
    
    // Xác thực số dư của Force đã bị ép lên lớn hơn 0
    assertEq(address(forceContract).balance, 1 ether);
}
\`\`\`

#### Recommendation
* **Không tin tưởng số dư động:** Tuyệt đối không bao giờ thiết kế các logic kiểm tra nghiêm ngặt dựa vào số dư chính xác của hợp đồng thông qua thuộc tính `address(this).balance`.
* **Sử dụng biến trạng thái nội bộ:** Nếu cần quản lý và theo dõi lượng quỹ hoặc tài sản nạp vào hợp đồng phục vụ cho các tính toán logic, hãy sử dụng một biến trạng thái lưu trữ nội bộ (State Variable) riêng (ví dụ: `uint256 public totalDeposited;`) để ghi nhận lượng tiền thông qua các hàm nạp/rút tiền chính thống.

---

## 5. Vulnerable Code Snippet

Hợp đồng mục tiêu hoàn toàn không chứa mã nguồn kiểm soát việc nhận tiền, tạo ra một sự chủ quan hệ thống nếu nhà phát triển nghĩ rằng hợp đồng trống thì không thể nhận Ether:

\`\`\`solidity
contract Force {
    /* MEOW ? */
    // Không chứa receive() hay fallback()
}
\`\`\`

---

## 6. Conclusion

Bài toán `Force` phản ánh một tư duy thiết kế quan trọng trong bảo mật Smart Contract: **Số dư Ether của một hợp đồng luôn là một yếu tố nằm ngoài tầm kiểm soát tuyệt đối của mã nguồn**. 

Các nhà phát triển phải luôn giả định rằng hợp đồng của mình có thể bị tấn công nạp tiền thụ động bất cứ lúc nào, từ đó cần thiết kế các biến quản lý trạng thái nội bộ độc lập hoàn toàn với bộ đếm số dư của EVM nhằm đảm bảo tính an toàn tuyệt đối cho toàn bộ hệ thống.