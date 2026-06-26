# Smart Contract Security Audit: Ethernaut Privacy

**Date:** 26/06/2026

**Prepared by:** Minh Chung

**Project:** Ethernaut Level 12 - Privacy

---

## 1. Executive Summary

Hợp đồng `Privacy` được thiết kế nhằm mục đích bảo vệ trạng thái đóng khóa (`locked = true`) thông qua một cơ chế kiểm tra mật mã lưu trữ trong mảng ẩn `data`. Chỉ người chơi cung cấp chính xác mảnh ghép dữ liệu `data[2]` đã được ép kiểu mới có thể mở khóa hệ thống. Tuy nhiên, một lỗ hổng nghiêm trọng liên quan đến tính minh bạch dữ liệu trên EVM đã được xác định. Bằng việc tính toán chính xác ô nhớ (Storage Slot Packing Layout), bất kỳ ai cũng có thể đọc trích xuất trực tiếp mật mã từ các Node công khai để bẻ khóa hoàn toàn hợp đồng.

## 2. Risk Classification

| Severity   | Description                                                                                 |
| :--------- | :------------------------------------------------------------------------------------------ |
| **High**   | Lỗ hổng có thể dẫn đến mất toàn bộ tiền trong hợp đồng hoặc chiếm quyền quản trị hoàn toàn. |
| **Medium** | Lỗ hổng ảnh hưởng đến logic vận hành nhưng không gây mất tiền ngay lập tức.                 |
| **Low**    | Các lỗi liên quan đến tối ưu hóa Gas hoặc thực hành code không tốt.                         |

---

## 3. Findings Summary

| ID   | Title                                                                           | Severity | Status |
| :--- | :------------------------------------------------------------------------------ | :------- | :----- |
| H-01 | Information Disclosure via EVM Storage Layout Inspection and Packing Prediction | High     | Found  |

---

## 4. Detailed Findings

### [H-01] Information Disclosure via EVM Storage Layout Inspection and Packing Prediction

**Description:**
Hợp đồng gán thuộc tính `private` cho mảng dữ liệu mật mã `bytes32[3] private data` với giả định rằng thông tin này sẽ được bảo mật khỏi các tác nhân bên ngoài. Tuy nhiên, kiến trúc lưu trữ của Ethereum Virtual Machine (EVM) quy định rằng tất cả dữ liệu lưu trữ đều được công khai minh bạch.

Dựa theo quy tắc sắp xếp và nén dữ liệu (Storage Packing Rules) của EVM:
* Slot 0: Biến `locked` (1 byte).
* Slot 1: Biến `ID` (32 bytes - do kích thước lớn nên đẩy sang ô nhớ mới).
* Slot 2: Đóng gói chung ba biến kích thước nhỏ bao gồm `flattening` (1 byte), `denomination` (1 byte), và `awkwardness` (2 bytes).
* Slot 3: Phần tử mảng đầu tiên `data[0]` (32 bytes).
* Slot 4: Phần tử mảng thứ hai `data[1]` (32 bytes).
* Slot 5: Phần tử mảng thứ ba `data[2]` (32 bytes).

Kẻ tấn công chỉ cần thực hiện truy vấn hàm JSON-RPC `eth_getStorageAt` tại vị trí chỉ mục số 5 là thu thập được toàn bộ giá trị của mật mã `data[2]`. Kết hợp với hành vi ép kiểu giảm cấp (`Downcasting`) từ `bytes32` về `bytes16` bằng cách cắt lấy 16 bytes đầu tiên, điều kiện kiểm tra của hàm `unlock` hoàn toàn bị vô hiệu hóa.

**Impact:**
Mức độ ảnh hưởng là **Chí mạng (High)**. Cơ chế bảo vệ khóa bảo mật của toàn bộ hợp đồng bị phá vỡ hoàn toàn, cho phép bất kỳ ai cũng có thể chiếm quyền thay đổi biến `locked` thành `false`.

**Proof of Concept (PoC):**
Cuộc tấn công bẻ khóa được chứng minh thông qua các bước xử lý sau:
1. Thực hiện lệnh gọi RPC lấy dữ liệu tại ô nhớ số 5 của hợp đồng bia ngắm:
    bytes32 rawData = web3.eth.getStorageAt(instanceAddress, 5);
2. Tiến hành lấy dữ liệu 16 bytes đầu tiên từ chuỗi kết quả nhận được (tương ứng cắt lấy chuỗi ký tự độ dài thích hợp).
3. Thực hiện gọi hàm `unlock(_key)` kèm theo tham số vừa trích xuất để chuyển đổi trạng thái `locked` thành công.

**Recommendation:**
Không bao giờ sử dụng các biến trạng thái trên bộ nhớ Storage của Smart Contract để lưu giữ khóa bí mật hay mật khẩu chưa được mã hóa độc lập.
* Nếu bắt buộc phải thực hiện các cơ chế xác thực chuỗi, hãy sử dụng giải pháp băm dữ liệu kết hợp muối (Salted Hashing) hoặc mô hình bằng chứng không tiết lộ thông tin (Zero-Knowledge Proofs).
* Hạn chế thiết kế các logic nghiệp vụ phụ thuộc vào tính bí mật của các ô nhớ để tránh rủi ro rò rỉ dữ liệu.

---

## 5. Vulnerable Code Snippet

// Lỗ hổng nằm ở việc tính toán sai quy tắc đóng gói ô nhớ khiến dữ liệu mảng mật mã bị lộ diện
contract Privacy {
    bool public locked = true;
    uint256 public ID = block.timestamp;
    uint8 private flattening = 10;
    uint8 private denomination = 255;
    uint16 private awkwardness = uint16(block.timestamp);
    // data[2] được lưu trữ cố định minh bạch tại vị trí Slot thứ 5 trên EVM
    bytes32[3] private data; 

    function unlock(bytes16 _key) public {
        require(_key == bytes16(data[2])); // Điểm yếu xác thực dữ liệu thô
        locked = false;
    }
}

---

## 6. Conclusion

Hợp đồng `Privacy` nhấn mạnh một nguyên tắc nền tảng trong phát triển ứng dụng Web3: Thuộc tính `private` chỉ cung cấp tính năng phân tách phạm vi truy cập của mã nguồn (Mức độ hiển thị kiểm soát code), hoàn toàn không cung cấp tính năng bảo mật hay mã hóa dữ liệu trên môi trường blockchain công khai. Hiểu rõ cơ chế quản lý dữ liệu Storage của EVM là điều bắt buộc để đảm bảo an toàn thiết kế hệ thống.