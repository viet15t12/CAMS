#import "../config/commands.typ": front-heading

#front-heading[TÓM TẮT]

Trong công tác quản trị và thực hành mạng máy tính, cấu hình thiết bị qua giao diện dòng lệnh (CLI) thường đòi hỏi nhiều thao tác lặp lại, tiềm ẩn lỗi cú pháp và gây khó khăn khi kiểm soát sai lệch cấu hình. Để khắc phục những hạn chế đó, đề tài xây dựng CAMS, một hệ thống hỗ trợ quản lý tập trung, tự động hóa cấu hình và giám sát an ninh mạng cho thiết bị Cisco IOS trong môi trường học tập và thực nghiệm.

CAMS được thiết kế theo kiến trúc phân lớp, kết hợp giao diện khai báo bằng Qt Quick/QML, lớp điều phối PyQt6, hai cơ sở dữ liệu SQLite phân biệt cấu hình và dữ liệu quan sát, các tác vụ nền sử dụng Netmiko/Paramiko và bộ tạo mẫu Jinja2. Hệ thống vận hành theo quy trình quản trị dựa trên trạng thái: quản lý danh mục thiết bị, thu thập và sao lưu `running-config` vào kho Git cục bộ bằng Dulwich, xác lập cấu hình mong muốn, kiểm duyệt lệnh rồi triển khai xuống thiết bị.

Phạm vi của CAMS bao gồm chuyển mạch Lớp 2, định tuyến và các dịch vụ Lớp 3. Hệ thống còn tích hợp bộ thu nhận Syslog theo thời gian thực, máy khách SFTP và terminal nhúng phục vụ thao tác dòng lệnh. Trong phép thử ICMP của kịch bản OSPF, VPC11 gửi thành công 5/5 gói tin tới VPC14. Ở ảnh chụp bộ nhận Syslog, bộ đếm ghi nhận 245 bản tin tại thời điểm quan sát. Các số liệu này mô tả hai phép quan sát cụ thể, chưa xác định tỷ lệ thành công dài hạn, thông lượng hoặc mức cải thiện thời gian so với CLI thủ công.

*Từ khóa:* Tự động hóa mạng; quản lý tập trung; Cisco IOS; Syslog; kiểm duyệt cấu hình; an ninh mạng.
