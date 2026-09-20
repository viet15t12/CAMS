# CHƯƠNG 3: PHÂN TÍCH VÀ THIẾT KẾ HỆ THỐNG

## 3.1. Tác nhân chính và Ca sử dụng hệ thống
Hệ thống CAMS được thiết kế tối ưu cho môi trường phòng thực hành lab và các mạng doanh nghiệp vừa và nhỏ, trong đó tác nhân chính tương tác trực tiếp là người quản trị mạng, bao gồm giảng viên, kỹ sư hoặc sinh viên thực hành [117]. Toàn bộ vòng đời vận hành tự động hóa được mô hình hóa qua các ca sử dụng cốt lõi: quản lý danh mục thiết bị tập trung; kiểm tra kết nối và đồng bộ trạng thái cơ sở (Baseline Sync) từ cấu hình running-config; định nghĩa cấu hình mong muốn (Desired State) qua giao diện đồ họa; kiểm duyệt tập lệnh CLI phát sinh qua cơ chế xem trước (Preview); đẩy cấu hình an toàn xuống thiết bị (Push); lưu vết lịch sử phiên bản tự động bằng Git qua Dulwich; can thiệp lệnh thủ công qua terminal nhúng đồng hành; cùng các tiện ích giám sát nhật ký Syslog tập trung và truyền tệp an toàn SFTP [117, 118, 119, 120, 121].

## 3.2. Yêu cầu Chức năng và Phi chức năng
Về mặt chức năng, hệ thống phân định rõ hai nhóm tính năng chính:
- **Nhóm tính năng nghiệp vụ mạng cốt lõi**: Bao gồm quản lý danh mục thiết bị (Inventory) hỗ trợ nhập hàng loạt từ JSON/Excel; kết nối và bóc tách running-config; cấu hình địa chỉ IPv4 cho cổng vật lý, Subinterface 802.1Q, Loopback và GRE Tunnel; dịch vụ cấp phát IP động DHCP, dải IP loại trừ và Relay Helper; hệ thống định tuyến tĩnh, tuyến mặc định, định tuyến động OSPFv2 và EIGRP; chính sách kiểm soát truy cập ACL đa chủng loại bảo toàn thứ tự quy tắc; biên dịch địa chỉ NAT/PAT; cùng các chính sách chuyển mạch Lớp 2 (VLAN, Trunking, EtherChannel, STP, VTP) và bảo mật Lớp 2 (Port Security, DHCP Snooping, DAI) [121, 122, 123].
- **Nhóm tiện ích mở rộng và an toàn**: Bao gồm máy chủ Syslog tiếp nhận nhật ký thời gian thực theo lô; máy khách SFTP hai khung nhìn; trình dòng lệnh nhúng Alacritty độc lập giao tiếp qua socket IPC nội bộ; và trình quản lý đóng gói workspace nén `.ntp` bảo mật [123, 124].

Về mặt phi chức năng, CAMS thiết lập các tiêu chuẩn kỹ thuật nghiêm ngặt nhằm bảo đảm giao diện không bị đóng băng khi thực thi tác vụ mạng nhờ phân tách luồng nền (Worker Threads); cô lập môi trường phát triển Dev-mode theo nguyên tắc Fail-closed ngắt hoàn toàn kết nối thật; đảm bảo toàn vẹn dữ liệu quan hệ SQLite qua ràng buộc khóa ngoại; ngăn ngừa xung đột luồng lệnh CLI bằng cơ chế khóa tuần tự hóa theo thiết bị (Host Lock); và che giấu thông tin xác thực nhạy cảm trong nhật ký hệ thống [125, 126, 127].

## 3.3. Kiến trúc Phân lớp Hệ thống
CAMS tuân thủ kiến trúc phân lớp chuẩn mực (Clean Architecture) gồm 4 tầng độc lập nhằm phân tách trách nhiệm triệt để [127, 128]:
1. **Lớp Giao diện (Presentation Layer - Qt Quick / QML)**: Hiển thị khai báo các thành phần đồ họa trực quan, thẻ tiến trình và hộp thoại View & Push, hoàn toàn không chứa truy vấn SQL hay kết nối mạng [128].
2. **Lớp Cầu nối & Điều phối (Bridge / Facade Layer - PyQt6)**: Đóng vai trò trung gian, nạp đối tượng `DatabaseManager` làm Facade trung tâm vào QML Engine qua cơ chế `setContextProperty`, tiếp nhận yêu cầu `@pyqtSlot` và phát tín hiệu `@pyqtSignal` cập nhật giao diện [128, 129, 130].
3. **Lớp Dữ liệu & Nghiệp vụ (Domain & Persistence Layer)**: Xử lý logic nghiệp vụ, kiểm tra ràng buộc dữ liệu (Validation) và quản lý cơ sở dữ liệu quan hệ SQLite [129].
4. **Lớp Mạng & Thực thi (Network & Worker Layer)**: Quản lý phiên kết nối (`DeviceSessionRegistry`), thực thi cơ chế Host Lock, điều phối tiến trình song song (`BatchExecutor`), biên dịch tập lệnh qua Jinja2 và tương tác CLI bằng Netmiko/Paramiko [130].

## 3.4. Các Luồng Dữ liệu Cốt lõi
Mọi thao tác quản trị trên CAMS được điều phối qua 3 luồng dữ liệu chính [130]:
- **Luồng 1 - Quản lý và Đồng bộ trạng thái (Sync)**: Khởi tạo phiên kết nối SSH/Telnet, kiểm tra khả năng đáp ứng, thu thập `running-config`, tự động lưu bản sao Dulwich Git snapshot và bóc tách dữ liệu có cấu trúc vào cơ sở dữ liệu làm trạng thái cơ sở (Baseline) [131, 132].
- **Luồng 2 - Định nghĩa cấu hình mong muốn (Desired State)**: Kỹ sư nhập tham số trên giao diện; hệ thống kiểm tra tính hợp lệ và lưu vào cơ sở dữ liệu với cờ trạng thái chờ `success = 0` (Pending Add/Update) hoặc `success = -1` (Pending Delete), đồng thời đánh dấu màu cảnh báo trên UI mà chưa tác động xuống thiết bị thật [132, 133].
- **Luồng 3 - Xem trước và Thực thi cấu hình (View & Push)**: Bộ điều khiển quét các bản ghi chờ, chuyển qua engine Jinja2 để kết xuất tập lệnh CLI Cisco IOS; hiển thị cửa sổ View & Push để người quản trị kiểm duyệt trực quan (Preview); sau đó kích hoạt Worker nền lấy quyền truy cập, áp dụng Host Lock, đẩy tập lệnh xuống thiết bị và cập nhật `success = 1` (Applied) sau khi xác minh phản hồi thành công [134, 135, 136].

## 3.5. Thiết kế Cơ sở Dữ liệu Quan hệ
Cơ sở dữ liệu SQLite nhúng của CAMS được phân hoạch thành 2 tệp độc lập nhằm tách biệt cấu hình định nghĩa với dữ liệu giám sát quan sát được [136]:
- **Tệp `device_network.db` (73 bảng)**: Lưu trữ trạng thái mong muốn (Desired State) do người dùng thiết lập, bao gồm danh mục thiết bị (`t01_*`), thông số giao diện L3/WAN (`t02_*`), dịch vụ DHCP (`t03_*`), định tuyến L3 (`t04_*`), ACL & NAT (`t05_*`), chuyển mạch L2 (`t06_*`), dự phòng FHRP (`t08_*`) và VTP Domain (`t09_*`) [137, 138, 139].
- **Tệp `info_collected.db` (20 bảng)**: Lưu trữ dữ liệu chỉ đọc (Observed State) được thu thập tự động từ thiết bị, gồm bảng định tuyến thực tế (`t08_info_*`), trạng thái cấp phát DHCP (`t09_info_*`), thống kê ACL (`t10_info_*`), bảng phiên NAT (`t11_info_*`) và nhật ký Syslog (`t12_syslog_*`) [139, 140].

Trường cờ `success` trong các bảng nghiệp vụ đóng vai trò quyết định vòng đời dữ liệu: `0` đại diện cho trạng thái chờ xử lý (Pending), `1` thể hiện dữ liệu đã đồng bộ thành công (Applied), và `-1` đánh dấu bản ghi chờ gỡ bỏ (Pending Delete) [140, 141].

## 3.6. Thiết kế Giao diện Người dùng và Cơ chế An toàn
Giao diện CAMS được tổ chức theo bố cục Khung ứng dụng chính (Application Shell) gồm 4 khu vực: Thanh tiêu đề & Menu hệ thống, Thanh điều hướng tính năng (Feature Bar), Thanh quản lý tab thiết bị đa nhiệm và Thanh trạng thái [141, 142, 143]. Để tối ưu hiệu năng và duy trì tốc độ phản hồi 60 FPS, ứng dụng áp dụng cơ chế nạp thành phần lười (Lazy Loading) thông qua các Loader QML [143, 144]. Trải nghiệm người dùng được chuẩn hóa bằng các UI Pattern như Khung biểu mẫu chia đôi (Split Form Pane), Thẻ quy trình định tuyến (Process Card) và Hộp thoại kiểm duyệt View & Push [144, 145, 146].

Để đảm bảo an toàn tuyệt đối khi vận hành, CAMS tích hợp cơ chế phòng vệ đa tầng: chế độ Dev-mode ngắt kết nối thật theo nguyên tắc Fail-closed và chạy qua Mock Worker; cơ chế Host Lock (`operation_lock`) loại trừ xung đột luồng lệnh CLI; cơ chế hủy tác vụ bất đồng bộ an toàn kèm ngắt thời gian chờ (Timeout); và giải pháp bảo mật dữ liệu dự án đóng gói `.ntp` bằng thuật toán Argon2id kết hợp AES-256-GCM [146, 147, 148, 149].
