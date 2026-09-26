#import "../config/commands.typ": front-heading

#front-heading[TÓM TẮT]

Trong công tác quản trị và thực hành mạng máy tính, cấu hình thiết bị qua giao diện dòng lệnh (CLI) thường đòi hỏi nhiều thao tác lặp lại, tiềm ẩn lỗi cú pháp và gây khó khăn khi kiểm soát sai lệch cấu hình. Để khắc phục những hạn chế đó, đề tài xây dựng CAMS, một hệ thống hỗ trợ quản lý tập trung, tự động hóa cấu hình và giám sát an ninh mạng cho thiết bị Cisco IOS trong môi trường học tập và thực nghiệm.

CAMS được thiết kế theo kiến trúc phân lớp, kết hợp giao diện khai báo bằng Qt Quick/QML, lớp điều phối PyQt6, hai cơ sở dữ liệu SQLite với 93 bảng nghiệp vụ, các tác vụ nền sử dụng Netmiko/Paramiko và bộ tạo mẫu Jinja2. Hệ thống vận hành theo quy trình quản trị dựa trên trạng thái: quản lý danh mục thiết bị, thu thập và sao lưu `running-config` vào kho Git cục bộ bằng Dulwich, xác lập cấu hình mong muốn, kiểm duyệt lệnh rồi triển khai xuống thiết bị.

Phạm vi của CAMS bao gồm chuyển mạch Lớp 2, định tuyến và các dịch vụ Lớp 3. Hệ thống còn tích hợp bộ thu nhận Syslog theo thời gian thực, máy khách SFTP và terminal nhúng phục vụ thao tác dòng lệnh. Kết quả thử nghiệm trên EVE-NG cho thấy CAMS có thể triển khai đồng bộ cấu hình trên nhiều thiết bị, lưu lại kết quả và hỗ trợ đối chiếu trạng thái sau khi thực thi.

// *Từ khóa:* Tự động hóa mạng, Quản lý tập trung, CAMS, Cisco IOS, Qt Quick/QML, PyQt6, SQLite, Jinja2, View & Push.
