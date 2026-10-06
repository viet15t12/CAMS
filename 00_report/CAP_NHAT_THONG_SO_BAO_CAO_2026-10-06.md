# Cập nhật thông số báo cáo CAMS ngày 06/10/2026

Phạm vi: toàn bộ nguồn Typst đang được `00_report/main.typ` đưa vào PDF. Bản xuất sau sửa có 119 trang PDF. Các bản nháp trong thư mục `chapters/`, `md/` và nguồn không được include không phải bản báo cáo hiện tại.

## Những điểm đã sửa

- Tách môi trường Lab 1, 2, 5 của Nguyễn Phan Kiên và Lab 3, 4 của Nguyễn Quốc Việt theo xác nhận của người dùng; không coi là cùng máy EVE-NG.
- Thay danh sách lựa chọn Fedora/Ubuntu, Ryzen/Core i7 và phiên bản EVE/IOS chưa có bằng chứng bằng thông tin xác nhận được và các trường chưa xác nhận. Máy hiện tại: Fedora Linux 44 Workstation, Intel Core i7-14650HX, 16 lõi/24 luồng; RAM hệ thống khoảng 15,33 GiB khả dụng (16 GB danh nghĩa); môi trường `.venv`: Python 3.14.7, PyQt 6.10.2, Qt 6.10.0. Các số này được ghi là thông tin đối chiếu khi biên tập, không suy thành phiên bản của mọi ảnh cũ.
- Cập nhật danh sách năm kịch bản, quy mô và nguồn minh chứng; kịch bản 5 là ACL/Syslog, không phải thực nghiệm mật mã hoặc phân quyền.
- Giữ địa chỉ riêng từng lab: R1 Lab 2 quản trị 192.168.122.101; R1 Lab 5 quản trị 192.168.122.104. Không đổi IP theo một quy hoạch chung giả định.
- Sửa các chú thích/mô tả GLBP–DHCP–NAT/PAT còn gọi nhầm Kịch bản 2 thành Kịch bản 3.
- Giải thích traceroute UDP Type 3 Code 3 đúng cơ chế; ở Lab 3, ghi rõ cần đối chiếu địa chỉ upstream/loopback do IP phản hồi khác đích 1.1.1.1. Chưa suy ra failover GLBP hoặc phiên PAT từ running-config.
- Khối DHCP được giữ đúng ảnh: chưa xác nhận excluded-address/DNS/lease; không tự thêm lệnh làm kết quả PC1 .4 mâu thuẫn với cấu hình mới chưa chạy.
- Phân biệt Syslog facility 23 (local7) và Cisco facility LINEPROTO; chép đủ tiền tố 000108 trong raw message. Giữ ảnh chi tiết gốc và chỉ rõ nhãn Clock synchronized không nhất quán với dấu * trong bản tin, không khẳng định parser hiện tại còn lỗi đó.
- Loại bảng tên thực thể không tồn tại; SQL nguồn có 74 tên bảng device_network và 19 info_collected, tổng 93. Phân biệt số đếm nguồn với bảng runtime.
- Sửa phụ lục tên QML, đường dẫn mô-đun, bảng SQL và mẫu lệnh; sơ đồ thư mục dùng các đường dẫn tồn tại. Không dùng tên class/tệp giả định.
- Sửa kết luận ba lab thành năm; phân biệt cơ chế đã hiện thực và nội dung đã kiểm chứng. Mã nguồn có ENC$v2$; không còn kết luận toàn bộ mật khẩu luôn lưu dạng rõ hoặc email chỉ là việc tương lai.
- Làm rõ mã hóa trường mật khẩu khác mã hóa toàn gói .ntp; giải thích phần mở rộng dự án khác giao thức NTP; mô tả giới hạn khóa cục bộ và việc di chuyển dữ liệu cũ.
- Bỏ ngưỡng giả định 6 thiết bị/30 giây và parse 99% khỏi mục tiêu đánh giá hiện tại. Giữ 52 dòng CLI ở Lab 2 là ước tính theo cấu hình và giữ nhận xét CAMS thuận tiện hơn khi khai báo/rà soát OSPF; không biến thành kết luận thời gian đo.
- Bổ sung bảng kết quả/giới hạn năm lab, cập nhật tóm tắt DAI/ACL và lộ trình phát triển. Không cộng bộ đếm Syslog của các lab độc lập hoặc dùng gói ping như số lần triển khai.

## Các thông tin cần bổ sung từ thực nghiệm thật

- Cấu hình máy trạm và các phiên bản Python/Qt thực sự dùng cho Lab 3, 4 của Quốc Việt.
- Phiên bản và bản Community/Professional, vCPU/RAM cấp cho từng máy EVE-NG; không lấy cấu hình máy trạm thay thế.
- Output show version để xác định image/build IOS đầy đủ của router/switch từng lab. Running-config Lab 2 ghi version 15.5 chưa đủ xác định bản dựng.
- Khi hoàn thiện Lab 3: xác minh excluded-address thực tế, trạng thái/đổi vai trò GLBP và bảng phiên NAT. Không có dữ liệu này thì các giới hạn đã được ghi rõ trong PDF.

## Kiểm tra sau sửa

- Biên dịch `00_report/main.typ` thành PDF thành công; giữ nguyên nguồn để sửa tiếp.
- Đối chiếu tổng tên bảng SQL bằng khai báo CREATE TABLE; đối chiếu tệp QML, mô-đun và mẫu lệnh trong kho mã nguồn.
- Kiểm tra văn bản PDF để loại các tên bảng/tệp và cấu hình mẫu cũ, kiểm tra số trang và các chuỗi thông số quan trọng.
- Render các trang thay đổi, mục lục/danh mục, bảng và phụ lục; xem ảnh tổng quan và các trang phóng lớn bằng PyMuPDF/Poppler. Bảng không tràn lề và chú thích cập nhật theo dàn trang.
- Không chạy lại EVE-NG hoặc tạo số đo mới. Các thay đổi sẵn có ở features/switching/worker.py và tests/test_switching_worker.py không bị chỉnh sửa trong công việc này.
