# CHƯƠNG 1: GIỚI THIỆU ĐỀ TÀI

## 1.1. Bối cảnh và Lý do chọn đề tài
Trong công tác quản trị và vận hành hạ tầng mạng máy tính, giao diện dòng lệnh (CLI) trực tiếp trên từng thiết bị truyền thống vẫn là phương thức phổ biến nhưng bộc lộ nhiều hạn chế. Việc thao tác thủ công lặp đi lặp lại chuỗi lệnh trên các cấu hình quy mô lớn làm giảm hiệu suất làm việc, tăng nguy cơ sai sót cú pháp hay nhầm lẫn địa chỉ IP, dẫn đến sự cố gián đoạn đường truyền và gây khó khăn cho việc khắc phục. Bên cạnh đó, việc thiếu một cơ sở dữ liệu quản trị tập trung khiến dữ liệu cấu hình bị phân tán, khó kiểm soát sự lệch chuẩn so với thiết kế ban đầu. Xuất phát từ thực trạng đó, việc nghiên cứu và xây dựng hệ thống **CAMS** (*Centralized Automation and Monitoring System*) nhằm tự động hóa cấu hình, quản lý tập trung và giám sát an ninh cho hạ tầng mạng Cisco IOS trong môi trường thực nghiệm là giải pháp cấp thiết và mang tính thực tiễn cao.

## 1.2. Mục tiêu đề tài
Mục tiêu tổng quát của đề tài là nghiên cứu, thiết kế và phát triển hoàn thiện phần mềm CAMS phục vụ quản lý tập trung và tự động hóa các tác vụ quản trị mạng máy tính. 

Về mục tiêu cụ thể, hệ thống được chuẩn hóa để hiện thực hóa quy trình quản trị dựa trên trạng thái (*State-driven*) thông qua luồng *View & Push* cho các phân hệ chuyển mạch Lớp 2, định tuyến Lớp 3 và dịch vụ mạng; tích hợp các tiện ích vận hành như máy chủ Syslog tập trung, máy khách SFTP hai khung nhìn và trình dòng lệnh nhúng; đồng thời đảm bảo tính an toàn hệ thống nhờ cơ chế khóa đồng bộ theo thiết bị (*Host Lock*) cùng giải pháp mã hóa dữ liệu đóng gói dự án (`.ntp`).

## 1.3. Đối tượng và Phạm vi nghiên cứu
Đối tượng nghiên cứu trọng tâm của đề tài là các thiết bị định tuyến (Router) và chuyển mạch (Switch) chạy hệ điều hành Cisco IOS, được thực nghiệm trực tiếp trên các dòng thiết bị ảo hóa Cisco vIOS L2 và vIOS L3 trong môi trường EVE-NG. Phần mềm CAMS được hiện thực hóa trên nền tảng ngôn ngữ Python 3.11+, giao diện Qt Quick/QML điều phối qua PyQt6, cơ sở dữ liệu quan hệ nhúng SQLite, kết hợp bộ tạo mẫu Jinja2, thư viện truyền thông Netmiko/Paramiko và quản lý kho lưu trữ Dulwich. 

Phạm vi ứng dụng của đề tài hiện được tối ưu cho môi trường phòng thực hành lab và doanh nghiệp vừa/nhỏ; chưa mở rộng sang kiến trúc cụm sẵn sàng cao (HA Cluster), phân quyền đa người dùng (RBAC), kho lưu trữ khóa bí mật chuyên dụng (Secret Vault) hay các giao thức định tuyến phức tạp dành cho nhà mạng như BGP.

## 1.4. Phương pháp nghiên cứu
Đề tài kết hợp đồng bộ các phương pháp nghiên cứu lý thuyết và thực nghiệm. Nhóm tác giả tiến hành khảo sát nghiệp vụ quản trị mạng thực tế, phân tích cấu trúc cú pháp CLI Cisco IOS và nhận diện các kịch bản lỗi thường gặp. Hệ thống được thiết kế theo mô hình kiến trúc phân lớp (*Clean Architecture*) hướng module nhằm cô lập chức năng và tối ưu khả năng bảo trì. Mô hình dữ liệu quan hệ SQLite được chuẩn hóa thành 93 bảng để quản lý song song trạng thái mong muốn (*Desired State*) và trạng thái quan sát (*Observed State*). Cuối cùng, tính đúng đắn và hiệu năng của hệ thống được kiểm chứng thông qua bộ kiểm thử tự động đa tầng (*Unit, Integration, Contract, Smoke Test*) kết hợp các kịch bản thực nghiệm topo thực tế trên EVE-NG.

## 1.5. Đóng góp của đề tài và Bố cục báo cáo
Đề tài đóng góp một giải pháp phần mềm CAMS hoàn chỉnh với giao diện đồ họa trực quan, triển khai thành công quy trình quản trị cấu hình an toàn *View & Push*, giải quyết bài toán tranh chấp luồng lệnh nhờ cơ chế *Host Lock* và điều phối *Batch Executor*. Hệ thống còn tích hợp cơ chế quản lý phiên bản cấu hình Git tự động qua Dulwich và đóng gói workspace an toàn. 

Báo cáo nghiên cứu được bố cục thành 6 chương chính:
- **Chương 1**: Giới thiệu đề tài
- **Chương 2**: Cơ sở lý thuyết và công nghệ nền tảng
- **Chương 3**: Phân tích và thiết kế hệ thống
- **Chương 4**: Xây dựng phần mềm CAMS
- **Chương 5**: Thử nghiệm và đánh giá
- **Chương 6**: Kết luận và hướng phát triển

---

# CHƯƠNG 2: CƠ SỞ LÝ THUYẾT VÀ CÔNG NGHỆ NỀN TẢNG

## 2.1. Quản lý cấu hình và Tự động hóa mạng
Tự động hóa mạng đại diện cho việc ứng dụng phần mềm để thực thi tự động các tác vụ quản trị chuẩn hóa, giúp loại bỏ các thao tác thủ công lặp lại, nâng cao tính đồng bộ và hạn chế tối đa sai sót con người. Hệ thống tự động hóa vận hành theo quy trình khép kín: tiếp nhận dữ liệu, kiểm tra hợp lệ, sinh tập lệnh CLI, khởi tạo phiên kết nối, triển khai và xác minh phản hồi. 

Nhằm đảm bảo tính an toàn, CAMS áp dụng mô hình quản lý cấu hình theo trạng thái (*State-driven Configuration Management*). Mô hình này phân định rõ rệt giữa trạng thái hiện tại (*Observed State* - dữ liệu thu thập trực tiếp từ thiết bị) và trạng thái mong muốn (*Desired State* - tham số do người quản trị thiết lập). Mọi sự thay đổi trên giao diện ban đầu chỉ tồn tại ở dạng cấu hình chờ (*Pending*). Thông qua luồng *View & Push*, trạng thái mong muốn được bộ tạo mẫu biên dịch thành tập lệnh CLI để người quản trị kiểm duyệt (*Preview*) trước khi đẩy xuống thiết bị (*Push*) và cập nhật trạng thái đồng bộ thành công (*Applied*) sau khi xác minh.

## 2.2. Các giao thức truyền thông an toàn và Quản trị CLI
Trong quản trị thiết bị từ xa, giao thức SSH (RFC 4251) là chuẩn truyền tin mã hóa bất đối xứng và đối xứng bắt buộc nhằm bảo vệ thông tin xác thực và dữ liệu trao đổi, thay thế hoàn toàn cho giao thức Telnet vốn truyền văn bản rõ dễ bị nghe lén. Do phản hồi từ giao diện dòng lệnh CLI luôn ở dạng văn bản thô không cấu trúc, phần mềm quản trị phải sử dụng các bộ phân tích cú pháp (*Parser*) để chuyển đổi dữ liệu về dạng đối tượng cấu trúc phục vụ lưu trữ. Đồng thời, do CLI duy trì trạng thái phiên, việc xử lý đồng thời yêu cầu cơ chế khóa luồng nghiêm ngặt nhằm tránh hiện tượng tranh chấp lệnh làm sai lệch cấu hình thiết bị.

## 2.3. Kiến trúc các dịch vụ Lớp 2 và Lớp 3 trên Cisco IOS
Hạ tầng mạng Cisco IOS vận hành dựa trên sự kết hợp chặt chẽ giữa các phân hệ Lớp 2 và Lớp 3:
- **Phân hệ Lớp 3 và Dịch vụ IP**: Quản lý địa chỉ IPv4 cho các cổng vật lý, cổng ảo Loopback, đường hầm GRE Tunnel và Subinterface 802.1Q (Router-on-a-Stick); dịch vụ cấp phát IP động DHCP/DHCP Relay theo quy trình DORA; cơ chế định tuyến tĩnh và tuyến mặc định; giao thức định tuyến động OSPFv2 (thuật toán Dijkstra, chia vùng Area, Router ID, Passive Interface) và EIGRP (Autonomous System, metric 5 thành phần); chính sách lọc gói tin ACL (Standard, Extended, Dynamic); cơ chế biên dịch địa chỉ NAT/PAT (Static, Dynamic, Overload); và giải pháp dự phòng Virtual Gateway GLBP.
- **Phân hệ Chuyển mạch và An ninh Lớp 2**: Phân chia miền quảng bá bằng VLAN, cổng Access/Trunk 802.1Q, gộp kênh EtherChannel (LACP/PAgP); chống vòng lặp Lớp 2 bằng Spanning Tree Protocol (STP/PVST+); đồng bộ cơ sở dữ liệu VLAN qua VTP Domain; kết hợp các cơ chế bảo mật nâng cao gồm DHCP Snooping ngăn Server giả mạo, Dynamic ARP Inspection (DAI) chống ARP Spoofing và Port Security giới hạn địa chỉ MAC truy cập.

## 2.4. Cơ sở dữ liệu quan hệ nhúng SQLite
Theo triết lý phần mềm Local-first, CAMS cần một cơ sở dữ liệu nhúng cục bộ để duy trì danh mục quản lý và lịch sử vận hành ngoài phiên kết nối SSH. SQLite được lựa chọn nhờ đặc tính đóng gói toàn bộ dữ liệu trong tệp đơn, truy xuất trực tiếp không qua tiến trình server riêng biệt, đáp ứng tính gọn nhẹ và hiệu năng cao. Hệ thống phân hoạch CSDL thành 2 tệp độc lập: `device_network.db` (73 bảng lưu trữ Desired State) và `info_collected.db` (20 bảng lưu trữ Observed State), sử dụng triệt để mối quan hệ một-nhiều (1-n) và ràng buộc khóa ngoại để bảo đảm tính toàn vẹn dữ liệu.

## 2.5. Kiến trúc giao diện người dùng Qt Quick/QML và Cầu nối PyQt6
Giao diện ứng dụng CAMS tuân thủ nguyên tắc phân tách trách nhiệm (*Clean Architecture*). Lớp hiển thị sử dụng Qt Quick/QML theo phong cách khai báo trực quan để mô tả thành phần UI, thuộc tính và tín hiệu. Lớp cầu nối PyQt6 đóng vai trò điều phối trung tâm: nạp các đối tượng Python vào QML Engine thông qua cơ chế `setContextProperty`, cho phép giao diện gọi trực tiếp các phương thức xử lý nghiệp vụ backend `@pyqtSlot` và nhận phản hồi tức thì qua tín hiệu `pyqtSignal` mà không chứa mã SQL hay kết nối mạng trực tiếp trong UI.

## 2.6. Thư viện tự động hóa và Tiện ích phụ trợ
Nền tảng backend của CAMS tích hợp bộ thư viện Python chuyên dụng:
- **Netmiko & Paramiko**: Quản lý kết nối SSH/CLI, tự động hóa xử lý dấu nhắc dòng lệnh và gửi tập lệnh tới thiết bị Cisco IOS.
- **Jinja2**: Engine tạo mẫu giúp tách biệt logic xử lý khỏi cú pháp CLI, biên dịch dữ liệu từ CSDL thành khối lệnh Cisco IOS hoàn chỉnh.
- **Dulwich**: Thư viện Git thuần Python quản lý kho lưu trữ cục bộ, tự động commit file `running-config` và hỗ trợ so sánh sai lệch cấu hình Unified Diff.
- **Argon2id & AES-256-GCM**: Bộ thuật toán mã hóa đối xứng và sinh khóa bảo vệ an toàn cho các gói tệp dự án đóng gói `.ntp`.

## 2.7. Cơ chế xử lý đồng thời và Mô hình tác vụ nền
Do các tác vụ giao tiếp SSH thường có độ trễ lớn, việc thực thi trực tiếp trên luồng giao diện chính (*UI Thread*) sẽ làm ngắt quãng Event Loop gây đóng băng ứng dụng. CAMS giải quyết triệt để bằng cách đẩy toàn bộ các thao tác mạng sang các luồng nền (*Worker Threads*) độc lập. Để kiểm soát truy cập đồng thời, hệ thống triển khai cơ chế khóa theo thiết bị (*Host Lock* - `operation_lock`) để tuần tự hóa các lệnh trên cùng một luồng CLI chống hiện tượng Race Condition, kết hợp bộ điều phối Batch Executor để thực thi song song bất đồng bộ giữa nhiều thiết bị khác nhau, tối ưu hóa hiệu năng vận hành tổng thể.
