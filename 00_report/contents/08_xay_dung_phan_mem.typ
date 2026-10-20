#pagebreak(weak: true)
#import "../config/tables.typ": report-table, table-code

= Xây dựng phần mềm CAMS

Chương 3 đã xác định kiến trúc phân lớp, mô hình dữ liệu và các luồng quản lý cấu hình, giám sát cùng bảo vệ dữ liệu. Chương này trình bày cách các thiết kế đó được hiện thực trong mã nguồn và giao diện CAMS. Trọng tâm là trách nhiệm của từng thành phần, đường đi của dữ liệu và cách ứng dụng xử lý tác vụ nền; kết quả vận hành trên mô hình mạng được dành cho Chương 5.

Nội dung được sắp xếp theo chuỗi sử dụng của hệ thống: khởi tạo ứng dụng, quản lý thiết bị, tự động hóa cấu hình, thu thập dữ liệu, triển khai chính sách bảo mật và sử dụng các tiện ích hỗ trợ. Cách trình bày này giữ liên kết giữa yêu cầu ở Chương 3 với bằng chứng kiểm thử ở chương tiếp theo.

== Môi trường phát triển và tổ chức mã nguồn

CAMS là ứng dụng máy tính để bàn dùng Python 3.11 trở lên, Qt Quick/QML và PyQt6 cho giao diện, SQLite để lưu trữ, Jinja2 để tạo lệnh, Netmiko/Paramiko để giao tiếp và Dulwich để quản lý lịch sử cấu hình. Bộ thu Syslog được viết bằng C++; bộ lập kế hoạch tự động hóa được viết bằng Go và biên dịch thành tệp thực thi `cams-automation` trong bước cài đặt. Công cụ `uv` quản lý môi trường và gói phụ thuộc.

Mã nguồn được tổ chức theo trách nhiệm: `UI/` chứa giao diện và các thành phần dùng chung; `core/` chứa đầu mối điều phối; `features/` tổ chức nghiệp vụ theo tính năng; `infrastructure/` cung cấp kết nối, lưu trữ và quản lý không gian làm việc; `gocore/` chứa mã nguồn Go của bộ lập kế hoạch tự động hóa. Tệp `main.py` khởi tạo ứng dụng và liên kết các thành phần. Cấu trúc chi tiết được trình bày trong phụ lục; chương này tập trung vào cách hiện thực các chức năng chính.

== Khởi tạo và kết nối giao diện với nghiệp vụ

Ứng dụng nạp màn hình chào để người dùng tạo hoặc mở dự án, thiết lập đường dẫn dữ liệu rồi chuyển vào giao diện chính. Khi khởi tạo, `main.py` tạo các thành phần dùng chung như bộ quản lý cơ sở dữ liệu, sổ đăng ký phiên thiết bị, bộ điều khiển không gian làm việc, SFTP, Syslog, cảnh báo Telegram, đánh giá cấu hình và bộ quản lý tự động hóa; sau đó công bố các đối tượng cần thiết cho QML qua ngữ cảnh của Qt.

QML tiếp nhận thao tác và gọi phương thức của bộ điều khiển Python. Tầng nghiệp vụ kiểm tra dữ liệu, thực hiện tác vụ rồi phát tín hiệu để giao diện cập nhật trạng thái hoặc hiển thị lỗi. Các thao tác mạng và lưu gói dự án được đưa sang tác vụ nền để không chặn luồng giao diện. @fig-cams-workspace minh họa không gian làm việc sau khi quá trình khởi tạo hoàn tất.

#figure(
  image("/00_book/figures/gui/chapter-03/01-workspace-overview.png", width: 88%),
  caption: [Không gian làm việc tập trung của CAMS],
) <fig-cams-workspace>

== Hiện thực quản lý tập trung

=== Danh mục thiết bị và phiên kết nối

Giao diện *Inventory* lưu mã định danh, địa chỉ quản trị, tham số kết nối và vai trò bộ định tuyến, bộ chuyển mạch Lớp 2 hoặc bộ chuyển mạch Lớp 3. Người dùng có thể thêm từng thiết bị hoặc nhập danh sách từ JSON/Excel, tìm kiếm và chọn các thiết bị cần thao tác. Danh mục này liên kết phiên làm việc với dữ liệu cấu hình và thông tin thu thập của từng thiết bị.

Với thiết bị cũ chỉ hỗ trợ một số thuật toán SSH, biểu mẫu thiết bị cho phép khai báo riêng danh sách thuật toán trao đổi khóa, loại khóa máy chủ, thuật toán mã hóa và thuật toán xác thực thông điệp. Các giá trị này được lưu trong bảng `t01_ssh_algo` của không gian làm việc và chỉ được đưa vào tham số kết nối của đúng thiết bị đó. Tùy chọn này phục vụ khả năng tương thích; việc bật lại thuật toán cũ làm giảm mức an toàn của phiên và chỉ nên dùng khi thiết bị không hỗ trợ thuật toán mới hơn.

`DeviceSessionRegistry` quản lý các phiên kết nối và cho phép tái sử dụng phiên đang hoạt động. Khóa `operation_lock` điều phối những tác vụ cùng truy cập phiên; `BatchExecutor` hỗ trợ thực hiện trên nhiều thiết bị với kết quả tách riêng. Cách tổ chức này hạn chế việc gửi lệnh đan xen trên một kênh CLI và giúp xác định thiết bị gặp lỗi trong tác vụ hàng loạt.

=== Đồng bộ và lịch sử cấu hình

Chức năng đồng bộ thu thập `running-config`, lưu bản sao, phân tích các phần được hỗ trợ rồi cập nhật cơ sở dữ liệu. Dulwich quản lý lịch sử các bản sao trong kho Git cục bộ. Người quản trị có thể xem từng phiên bản và phần khác biệt để truy vết thay đổi, như @fig-cams-config-diff.

#figure(
  image("/00_book/figures/gui/chapter-12/12-running-config-diff.png", width: 100%),
  caption: [So sánh hai phiên bản cấu hình đã lưu],
) <fig-cams-config-diff>

Lịch sử này cung cấp dữ liệu tham chiếu khi kiểm tra sự cố. Việc khôi phục cấu hình thiết bị vẫn cần lựa chọn nội dung phù hợp, triển khai và xác minh lại, thay vì chỉ mở phiên bản cũ trong ứng dụng.

Ba thao tác có tên gần nhau nhưng tác động lên ba đối tượng khác nhau:
- *Get running-config:* đọc cấu hình đang chạy, lưu một mốc sao lưu và đồng bộ các phần được hỗ trợ vào cơ sở dữ liệu.
- *Save configuration:* gửi lệnh lưu `running-config` thành `startup-config` trên thiết bị; thao tác này không thay đổi dữ liệu dự án.
- *Save Workspace:* ghi gói dự án `.ntp` trên máy trạm; thao tác này không gửi lệnh tới thiết bị.

Khi đồng bộ thủ công (*Manual Sync*), CAMS thu lại cấu hình rồi đối chiếu với các bản ghi đang chờ triển khai. Nếu không có xung đột, hệ thống dùng chế độ an toàn. Nếu một nhóm dữ liệu vừa có thay đổi cục bộ đang chờ vừa có cấu hình khác trên thiết bị, hộp thoại xung đột cho phép giữ thay đổi đang chờ (bỏ qua nhóm dữ liệu đó khi đồng bộ), dùng trạng thái thiết bị (bỏ thay đổi đang chờ) hoặc hủy. Cơ chế này tránh việc dữ liệu thu từ thiết bị âm thầm ghi đè cấu hình mong muốn mà người dùng chưa triển khai.

== Hiện thực tự động hóa cấu hình và chính sách

=== Quy trình *View & Push* dùng chung

Các chức năng thực hiện cùng một quy trình: kiểm tra dữ liệu biểu mẫu, lưu cấu hình chờ, lấy bản ghi cần thay đổi, sinh tập lệnh và mở cửa sổ xem trước. Bộ sinh lệnh được tổ chức theo từng mô-đun: định tuyến, DHCP, FHRP, ACL và NAT dùng mẫu Jinja2; cổng mạng, chuyển mạch và cấu hình Syslog trên thiết bị dùng hàm Python dựng lệnh trực tiếp. Khi người dùng chọn *Push*, tác vụ nền gửi lệnh qua phiên thiết bị, xử lý phản hồi và cập nhật kết quả. Với bản ghi chờ xóa, mẫu sinh lệnh gỡ bỏ tương ứng.

#figure(
  image("/00_book/figures/gui/chapter-05/07-view-push-preview.png", width: 100%),
  caption: [Kiểm duyệt lệnh cấu hình cổng mạng trước khi triển khai],
) <fig-cams-view-push>

@fig-cams-view-push cho thấy bước kiểm duyệt nằm giữa thao tác lưu dữ liệu và triển khai lên thiết bị. Quy trình này được dùng chung cho các nhóm nghiệp vụ, giúp thống nhất thao tác và cách trình bày trạng thái. Khi thực thi gặp lỗi, người dùng cần xem phản hồi và đồng bộ lại trước khi quyết định gửi lại lệnh.

=== Chọn thiết bị và triển khai hàng loạt

Thành phần `HostSelectionBar` cho phép chọn nhiều thiết bị bằng mẫu thay vì đánh dấu từng dòng. Bộ phân tích `HostPattern` hỗ trợ các dạng mẫu tại @tab-host-pattern; nhiều mẫu có thể được kết hợp và mẫu sai cú pháp bị báo lỗi mà không làm thay đổi lựa chọn hiện tại. Thanh chọn còn có các nút *All*, *None*, *Routers*, *Switches* và *Invert*. Thành phần này được dùng lại ở danh sách thiết bị, Routing Group, Syslog Group, VTP Group và FHRP.

#report-table(
  columns: (34%, 66%),
  header: ([Mẫu], [Ý nghĩa]),
  rows: (
    ([#table-code("all", size: 8.5pt), #table-code("*", size: 8.5pt)], [Tất cả thiết bị.]),
    ([#table-code("192.168.1.10", size: 8.5pt), #table-code("192.168.1.0/24", size: 8.5pt)], [Một địa chỉ hoặc một mạng con.]),
    ([#table-code("192.168.1.10-50", size: 8.5pt), #table-code("10.0.0.1-10.0.0.9", size: 8.5pt)], [Dải địa chỉ IPv4.]),
    ([#table-code("R1-R10", size: 8.5pt), #table-code("SW1-20", size: 8.5pt)], [Dải theo số thứ tự ở cuối tên thiết bị.]),
    ([#table-code("router", size: 8.5pt), #table-code("switch", size: 8.5pt), #table-code("l2", size: 8.5pt), #table-code("l3", size: 8.5pt)], [Theo vai trò thiết bị đã khai báo.]),
    ([#table-code("SW*", size: 8.5pt), #table-code("core-?", size: 8.5pt)], [Ký tự đại diện theo tên hoặc địa chỉ, không phân biệt chữ hoa và chữ thường.]),
    ([#table-code("!mẫu", size: 8.5pt)], [Loại trừ các thiết bị khớp mẫu.]),
  ),
  text-size: 9.5pt,
  caption: [Cú pháp chọn thiết bị theo mẫu],
) <tab-host-pattern>

Khi triển khai một cấu hình nhóm, `ViewPushBatchService` áp dụng chính sách đã nêu ở Chương 3: số thiết bị chạy đồng thời, kích thước đợt thử và ngưỡng tỷ lệ lỗi. Màn hình *Settings → Batch Push* cho phép đặt ba giá trị này trong các khoảng 1–50, 0–50 và 0–100%; giá trị được lưu bằng `QSettings`. Hộp thoại triển khai hiển thị tiến độ theo đợt, thời gian chạy và tổng kết riêng số thiết bị thành công, thất bại và bị bỏ qua. Với 300 thiết bị, mỗi thiết bị 30 giây, ước lượng lý thuyết theo công thức $T approx ceil(N slash P) times t$ cho khoảng 30 phút khi chạy 5 thiết bị đồng thời và khoảng 7,5 phút khi chạy 20 thiết bị. Đây là ước lượng chưa được đo; thời gian thực còn phụ thuộc số phiên VTY của thiết bị, tài nguyên phòng thực hành và khả năng ghi đồng thời của SQLite.

Sau khi gửi lệnh thành công, mỗi thiết bị đi qua `PostPushService.reconcile` trên cùng phiên kết nối và trong cùng khóa thiết bị: lưu cấu hình khởi động, thu lại `running-config`, ghi bản sao lưu rồi đồng bộ cơ sở dữ liệu theo trạng thái thiết bị. Nếu một bước lỗi, kết quả trả về ghi rõ bước đó (`save`, `collect`, `backup` hoặc `sync`) cùng các bước đã hoàn tất trước đó.

=== Quản lý cổng mạng, DHCP và định tuyến

Chức năng *Interfaces* quản lý địa chỉ IPv4, mô tả và trạng thái cổng; đồng thời hỗ trợ các cổng logic như Loopback, cổng con và đường hầm GRE. Cổng vật lý được lấy từ thiết bị để chỉnh sửa thông số; các cổng logic được tạo hoặc gỡ theo nghiệp vụ tương ứng.

DHCP quản lý vùng cấp phát, dải địa chỉ loại trừ và tác nhân chuyển tiếp. Định tuyến cung cấp tuyến tĩnh, tuyến mặc định, OSPFv2 và EIGRP. Các nhóm biểu mẫu phản ánh quan hệ giữa tiến trình, mạng quảng bá và tham số cổng. Chức năng *Routing Group* hỗ trợ chuẩn bị cấu hình cho nhóm bộ định tuyến nhằm giảm thao tác nhập lặp; kết quả vẫn cần được kiểm tra trên từng thiết bị. Ở bước định danh, người dùng có thể áp một Process ID (OSPF) hoặc số AS (EIGRP) cho mọi thiết bị đã chọn và dùng nút *Auto ID* để sinh Router ID tăng dần; Router ID không có thao tác áp chung vì phải khác nhau giữa các thiết bị. Ở bước khai báo mạng, danh sách mạng có thể được chọn hoặc loại trừ theo mẫu (mạng con, dải địa chỉ, tên cổng như `Loopback*`) rồi gán cùng một vùng OSPF bằng *Set area*.

Các thao tác hàng loạt tương tự có ở những nhóm khác: Syslog Group chọn cổng nguồn theo mẫu (ví dụ `Vlan*`) và liệt kê thiết bị không có cổng khớp; VTP Group cho phép đặt một chế độ cho mọi bộ chuyển mạch hoặc chọn "máy đầu là server, các máy còn lại là client"; FHRP cho phép áp cùng mức ưu tiên và tùy chọn chiếm quyền (preempt) cho các bộ định tuyến thành viên. Số thiết bị trong một nhóm không còn giới hạn ở năm mà bằng số thiết bị đủ điều kiện hiện có.

Các biểu mẫu FHRP hỗ trợ khai báo cổng mặc định dự phòng và tham số thành viên cho HSRP, VRRP, GLBP. Việc đánh giá chuyển đổi cổng mặc định thuộc kịch bản thử nghiệm, không được suy ra chỉ từ việc sinh đúng lệnh cấu hình.

=== ACL và NAT/PAT

Chức năng ACL cung cấp biểu mẫu cho ACL chuẩn, mở rộng, động, phản xạ và ACL theo địa chỉ MAC, tùy theo khả năng của thiết bị. Quy tắc được quản lý theo thứ tự, kèm cổng và chiều áp dụng.

Các mẫu Jinja2 sinh tập lệnh ACL tự động gắn từ khóa `log` vào cuối những quy tắc được hỗ trợ. Khi lưu lượng khớp với danh sách kiểm soát, thiết bị tạo bản tin Syslog, chẳng hạn `%SEC-6-IPACCESSLOGP`, rồi gửi về bộ thu nhận của CAMS. Cơ chế này hỗ trợ giám sát mà không cần bổ sung thủ công từ khóa ghi nhật ký cho từng quy tắc. Sau khi triển khai, người quản trị phải kiểm tra thứ tự khớp luật và thử cả lưu lượng được phép lẫn lưu lượng bị chặn.

NAT/PAT quản lý ánh xạ tĩnh, vùng địa chỉ động, chế độ quá tải, vai trò phía trong hoặc phía ngoài của cổng và điều kiện chọn lưu lượng. Dữ liệu từ bảng chuyển đổi địa chỉ giúp đối chiếu cấu hình với các phiên thực tế. NAT là chức năng chuyển đổi địa chỉ, không thay thế cơ chế lọc truy cập.

=== Chuyển mạch và cập nhật chính sách Lớp 2

Chức năng chuyển mạch quản lý VLAN, cổng truy cập, đường trung kế, EtherChannel, STP và VTP. Trên bộ chuyển mạch Lớp 3, SVI và định tuyến liên VLAN được cấu hình theo vai trò thiết bị. Mẫu lệnh giữ quan hệ giữa VLAN, cổng vật lý và cổng logic, đồng thời dùng chung bước xem trước để người quản trị kiểm tra phạm vi tác động.

Port Security, DHCP Snooping và DAI được trình bày trong nhóm bảo mật ở phần sau. Các chính sách này cũng được triển khai qua *View & Push* để duy trì cùng cơ chế kiểm duyệt và ghi nhận kết quả.

== Hiện thực giám sát và thu thập nhật ký

Chức năng Syslog gồm hai phần: cấu hình đích gửi trên thiết bị và vận hành bộ nhận trong System Logs. Địa chỉ, cổng và giao thức hai phía phải khớp nhau. Cấu hình hiện tại dùng cổng 5514 theo mặc định và cho phép thay đổi theo môi trường.

Bộ thu nhận C++ tiếp nhận bản tin qua UDP/TCP, phân tích và ghi dữ liệu vào SQLite, sau đó chuyển sự kiện qua cầu nối Python để cập nhật QML. Đây là luồng xử lý chính; bộ nhận Python được giữ lại để tương thích và kiểm thử. Hệ thống lưu bản tin gốc cùng trạng thái phân tích theo các trường của Syslog @rfc5424. Hai chỉ số `received` và `dropped` hỗ trợ theo dõi khả năng tiếp nhận khi lưu lượng tăng.

#figure(
  image("/00_book/figures/gui/chapter-13/01-system-logs-overview.png", width: 100%),
  caption: [System Logs tập trung nhật ký từ thiết bị mạng],
) <fig-cams-system-logs>

Giao diện tại @fig-cams-system-logs hỗ trợ lọc theo thiết bị, mức độ nghiêm trọng, giao thức, khoảng thời gian và nội dung. Chức năng *Smart Filter* kết hợp điều kiện theo nhóm nguồn Syslog, mã sự kiện và từ khóa; cửa sổ chi tiết cho phép đối chiếu thời gian nhận với thời gian trên thiết bị và đọc bản tin gốc. Chức năng *Export Excel* xuất các dòng sau khi lọc để phục vụ phân tích.

Sau khi lưu bản tin, `SyslogManager` đồng thời chuyển bản ghi tới `EmailAlertService`. Dịch vụ chỉ tiếp nhận các mức độ nghiêm trọng đã chọn, loại bản tin trùng theo cặp thiết bị–mã Cisco trong khoảng chống gửi lặp và có thể gom nhiều bản tin trong một cửa sổ thời gian. Hàng đợi cùng một luồng gửi riêng tách thao tác SMTP khỏi luồng nhận Syslog, nhờ đó thời gian kết nối máy chủ thư không chặn bộ thu nhận nhật ký.

Màn hình *Email Alerts* cho phép khai báo máy chủ và cổng SMTP, tài khoản gửi, danh sách người nhận, các mức Syslog cần cảnh báo, thời gian chống gửi trùng và thời gian gom bản tin. Mỗi thư gồm nội dung văn bản thuần và HTML; màu, tiêu đề cùng khuyến nghị xử lý thay đổi theo mức độ nghiêm trọng. Với Gmail, CAMS dùng kết nối SMTP qua TLS ngầm định trên cổng `465` và mật khẩu ứng dụng. Giá trị bí mật được mã hóa khi lưu, không được trả về QML và chỉ hiển thị dưới dạng che khuất trên giao diện.

Kênh cảnh báo thứ hai là Telegram, cấu hình tại *Settings → Telegram Alerts*. Người dùng nhập mã bot (Bot Token), mã cuộc trò chuyện dạng số hoặc tên kênh dạng `@channel`, chọn các mức Syslog từ 0 đến 7 cần cảnh báo (mặc định 0–2), thời gian chống gửi trùng (mặc định 300 giây) và thời gian gom bản tin (mặc định 10 giây). Dịch vụ dùng chung luồng sau lưu trữ với cảnh báo thư điện tử, nhận cả bản tin Syslog thường lẫn cảnh báo của bộ phát hiện, rồi gửi qua phương thức `sendMessage` của Telegram Bot API. Nội dung được cắt để không vượt giới hạn 4096 ký tự của một tin nhắn. Mã bot được mã hóa bằng cùng giao diện mã hóa trường dữ liệu và không được trả ngược về QML. Nút gửi thử chạy bất đồng bộ để không chặn giao diện.

#figure(
  rect(
    width: 100%, height: 55mm, stroke: (paint: gray, dash: "dashed"),
    align(center + horizon, text(fill: gray)[TODO: chèn ảnh màn hình *Settings → Telegram Alerts*]),
  ),
  caption: [Cấu hình cảnh báo qua Telegram],
) <fig-cams-telegram>

Kiểm thử tự động của hai kênh cảnh báo dùng đối tượng giả lập thay cho dịch vụ thật. Kịch bản 4 ở Chương 5 có hai thư cảnh báo thực tế; kênh Telegram chưa có minh chứng gửi tới dịch vụ thật trong báo cáo. Hệ thống cũng chưa được đo độ trễ hoặc tỷ lệ gửi thành công trong thời gian dài.

Ngoài nhật ký, dữ liệu quan sát như bảng định tuyến, bảng liên kết DHCP, thống kê ACL, phiên NAT, bộ đếm cổng và bảng MAC hỗ trợ kiểm tra hoạt động của các chức năng. Các giá trị này chỉ phản ánh thời điểm thu thập; muốn kết luận về trạng thái hiện tại, người dùng phải cập nhật dữ liệu trước khi đối chiếu.

== Hiện thực chính sách bảo mật và liên kết sự kiện

Nhóm chức năng này kết hợp hai phần đã tách trong thiết kế: thiết bị mạng thực thi chính sách, còn CAMS chuẩn bị cấu hình và khai thác sự kiện do thiết bị phát sinh. Vì vậy, luồng triển khai tiếp tục sử dụng *View & Push* ở Mục 4.4, trong khi luồng quan sát sử dụng bộ thu Syslog ở Mục 4.5.

=== Triển khai chính sách trên thiết bị

CAMS cung cấp biểu mẫu Port Security để đặt giới hạn địa chỉ MAC, chế độ học và hành động khi vi phạm. Với DHCP Snooping và DAI, người dùng chọn VLAN áp dụng cùng cổng tin cậy theo mô hình mạng. Các thay đổi được lưu ở trạng thái chờ và kiểm duyệt trước khi gửi, như @fig-cams-l2-security.

#figure(
  image("/00_book/figures/gui/chapter-16/04-l2-security-view-push.png", width: 100%),
  caption: [Xem trước chính sách bảo vệ Lớp 2 trước khi áp dụng],
) <fig-cams-l2-security>

Thiết bị mạng thực thi chính sách và có thể phát sinh nhật ký tùy theo tính năng, chế độ cùng cấu hình ghi nhật ký. Vì vậy, việc kiểm chứng cảnh báo cần một tình huống phù hợp với cơ chế đã bật, đồng thời phải bảo đảm đường truyền nhật ký đến CAMS hoạt động.

=== Liên kết chính sách với sự kiện giám sát

Sau khi thiết bị áp dụng chính sách, System Logs cung cấp điểm đối chiếu sự kiện theo nguồn, mức độ nghiêm trọng, mã phân hệ và nội dung. @fig-cams-critical-log minh họa kết quả lọc các mức 0, 1, 2 và 3. Kết quả lọc chứng minh khả năng truy vấn nhật ký, nhưng không tự chứng minh phần mềm đã phát hiện một cuộc tấn công.

#figure(
  image("/00_book/figures/gui/chapter-13/05-critical-filter-result.png", width: 100%),
  caption: [Lọc các bản tin có mức độ nghiêm trọng từ 0 đến 3 trên System Logs],
) <fig-cams-critical-log>

Ngưỡng gửi trên thiết bị và bộ lọc hiển thị có ý nghĩa khác nhau: ngưỡng gửi thường bao gồm mức đã chọn cùng các mức nghiêm trọng hơn, còn bộ lọc trong CAMS chọn các mức cụ thể. Khi điều tra, người dùng cần đọc nội dung, nguồn và chuỗi thời gian thay vì kết luận chỉ dựa trên màu hoặc mức độ nghiêm trọng.

Bộ lọc *Smart Filter* có nhóm *Security events* để lọc riêng bản tin ACL, DHCP Snooping, DAI, Port Security, xác thực, bảo vệ STP và cảnh báo của bộ phát hiện. Bộ phát hiện theo ngưỡng (@tab-security-detectors) gắn nhãn *Security Alert* cho các cảnh báo `%CAMS-...`; nhãn an ninh được tính khi đọc nên áp dụng được cho cả nhật ký đã lưu trước đó.

Trong phạm vi hiện tại, CAMS hỗ trợ khoanh vùng dấu hiệu bất thường qua nhật ký, đối chiếu chính sách và gửi cảnh báo qua thư điện tử hoặc Telegram. Hệ thống chưa có bộ tương quan sự kiện hoàn chỉnh, chưa phát hiện xâm nhập bằng phân tích gói tin và chưa hỗ trợ cảnh báo qua SMS hay webhook tổng quát.

=== Đánh giá cấu hình theo bộ quy tắc an ninh

Chức năng *Compliance Audit* đánh giá bản sao lưu `running-config` gần nhất của từng thiết bị theo 16 quy tắc. Bộ quy tắc được nhóm tác giả xây dựng dựa trên các khuyến nghị cứng hóa thiết bị Cisco IOS phổ biến, chia thành năm nhóm tại @tab-compliance-rules. Mỗi quy tắc có mức nghiêm trọng, trọng số, phạm vi vai trò áp dụng, giải thích và gợi ý lệnh khắc phục.

#report-table(
  columns: (13%, 63%, 12%, 12%),
  header: ([Nhóm], [Quy tắc], [Số quy tắc], [Trọng số]),
  rows: (
    ([#table-code("AUTH", size: 8.5pt)], [Dùng #table-code("enable secret", size: 8.5pt); bật mã hóa mật khẩu dịch vụ; tài khoản cục bộ dùng #table-code("secret", size: 8.5pt); bắt buộc xác thực trên Console và VTY.], [4], [5–15]),
    ([#table-code("MGMT", size: 8.5pt)], [Chỉ cho phép SSH trên VTY; giới hạn địa chỉ quản trị bằng #table-code("access-class", size: 8.5pt); đặt #table-code("exec-timeout", size: 8.5pt); có biểu ngữ cảnh báo.], [4], [3–15]),
    ([#table-code("HARD", size: 8.5pt)], [Tắt máy chủ HTTP không mã hóa, định tuyến nguồn IP và Proxy ARP.], [3], [3–5]),
    ([#table-code("LOG", size: 8.5pt)], [Có máy chủ Syslog tập trung; nhãn thời gian đến mili giây; số thứ tự bản tin.], [3], [3–10]),
    ([#table-code("L2", size: 8.5pt)], [Port Security trên cổng truy cập; DHCP Snooping theo VLAN. Chỉ áp dụng cho bộ chuyển mạch.], [2], [10]),
  ),
  text-size: 9.5pt,
  caption: [Nhóm quy tắc của chức năng Compliance Audit],
) <tab-compliance-rules>

Điểm của mỗi thiết bị bắt đầu từ 100. Quy tắc không đạt trừ đúng trọng số; quy tắc ở mức cảnh báo trừ một nửa trọng số, tối thiểu 1 điểm; quy tắc không áp dụng cho vai trò thiết bị không bị trừ điểm. Điểm được quy đổi thành xếp loại A (từ 90), B (từ 80), C (từ 65), D (từ 50) và F. Kết quả hiển thị các dòng cấu hình liên quan sau khi che mật khẩu, chuỗi băm và chuỗi cộng đồng; báo cáo có thể xuất thành tệp Markdown.

#figure(
  rect(
    width: 100%, height: 60mm, stroke: (paint: gray, dash: "dashed"),
    align(center + horizon, text(fill: gray)[TODO: chèn ảnh màn hình *Compliance Audit* với điểm và chi tiết một quy tắc]),
  ),
  caption: [Kết quả đánh giá cấu hình theo bộ quy tắc an ninh],
) <fig-cams-compliance>

Chức năng này chỉ đọc cấu hình đã sao lưu và không gửi lệnh khắc phục xuống thiết bị. Kết quả phụ thuộc độ mới của bản sao lưu; người dùng cần thu lại cấu hình trước khi đánh giá. Đây là bộ quy tắc nội bộ của CAMS, không thay thế việc đánh giá đầy đủ theo một tiêu chuẩn như CIS Benchmark.

== Hiện thực tự động hóa phản ứng theo sự kiện

Mục này mô tả cách hiện thực luồng đã thiết kế tại @fig-automation-flow. `AutomationManager` khởi động tiến trình `cams-automation` cùng ứng dụng, gửi thông điệp khởi tạo chứa mã dự án và thư mục quy tắc, rồi định kỳ gửi các sự kiện chờ xử lý. Thanh trạng thái trên các trang *Automation* hiển thị `RUNNING`, `STOPPED` hoặc `ERROR`; người dùng có thể dừng và khởi động lại tiến trình.

=== Định dạng quy tắc `.rule.cams`

Mỗi quy tắc là một tệp JSON đặt trong thư mục `automation/rules` của không gian làm việc. Lược đồ được kiểm tra chặt: trường sai tên hoặc trường không có trong lược đồ làm quy tắc bị từ chối khi nhập hoặc lưu. Python và Go kiểm tra cùng một tập ràng buộc. @tab-rule-cams-structure tóm tắt các khối chính.

#report-table(
  columns: (18%, 30%, 52%),
  header: ([Khối], [Trường chính], [Ý nghĩa và giới hạn]),
  rows: (
    ([#table-code("version", size: 8.5pt)], [1, 2 hoặc 3], [Phiên bản 1 dùng hành động có kiểu; phiên bản 2 cho phép chuỗi lệnh CLI; phiên bản 3 bổ sung biến có kiểu lấy từ Syslog.]),
    ([#table-code("metadata", size: 8.5pt)], [#table-code("id", size: 8.5pt), #table-code("name", size: 8.5pt), #table-code("enabled", size: 8.5pt)], [Mã quy tắc đồng thời là tên tệp; chỉ quy tắc đang bật mới được đánh giá.]),
    ([#table-code("schedule", size: 8.5pt)], [#table-code("interval_seconds", size: 8.5pt)], [Chu kỳ đánh giá từ 1 đến 3600 giây.]),
    ([#table-code("match", size: 8.5pt)], [#table-code("event_type", size: 8.5pt), #table-code("network", size: 8.5pt), #table-code("subnet_mask", size: 8.5pt), #table-code("attributes", size: 8.5pt)], [Loại sự kiện cần bắt; có thể giới hạn theo mạng con của thiết bị phát sự kiện và theo thuộc tính bằng nhau.]),
    ([#table-code("policy", size: 8.5pt)], [#table-code("mode", size: 8.5pt), #table-code("cooldown_seconds", size: 8.5pt), #table-code("max_actions_per_hour", size: 8.5pt)], [#table-code("dry-run", size: 8.5pt) chỉ lập kế hoạch, #table-code("auto", size: 8.5pt) mới gửi lệnh; thời gian chờ 0–86400 giây; 1–1000 hành động mỗi giờ.]),
    ([#table-code("variables", size: 8.5pt)], [#table-code("source", size: 8.5pt), #table-code("pattern", size: 8.5pt), #table-code("type", size: 8.5pt)], [Chỉ có ở phiên bản 3: 1–16 biến, trích từ nội dung bản tin Syslog bằng biểu thức chính quy và kiểm tra theo kiểu #table-code("interface", size: 8.5pt), #table-code("ipv4", size: 8.5pt) hoặc #table-code("identifier", size: 8.5pt).]),
    ([#table-code("action", size: 8.5pt)], [#table-code("type", size: 8.5pt), #table-code("transport", size: 8.5pt), #table-code("ttl_seconds", size: 8.5pt)], [Loại hành động; phương thức gửi bắt buộc là #table-code("ssh", size: 8.5pt) với chế độ tự động; #table-code("ttl_seconds", size: 8.5pt) phải bằng 0 với hành động tự động.]),
  ),
  text-size: 9.5pt,
  caption: [Cấu trúc tệp quy tắc tự động hóa #table-code(".rule.cams", size: 8.5pt)],
) <tab-rule-cams-structure>

Hành động được hỗ trợ gồm:
- *`interface.admin-state` (phiên bản 1):* sinh `interface` kèm `shutdown` hoặc `no shutdown`. Bộ thực thi đọc trạng thái cổng trước và sau khi gửi; nếu cổng đã ở đúng trạng thái, kết quả là `noop_verified`.
- *`ssh.cli` (phiên bản 2 và 3):* gửi 1–100 lệnh, mỗi lệnh tối đa 512 ký tự và tổng không quá 16 KiB, ở chế độ cấu hình hoặc chế độ EXEC; tối đa 20 lệnh `show` dùng để lưu bằng chứng sau khi gửi. Lệnh không được chứa ký tự xuống dòng hoặc ký tự rỗng và không được cần trả lời câu hỏi tương tác.
- *`acl.deny-protocol-source`:* chỉ có ở chế độ `dry-run` để ghi lại kế hoạch, chưa có bộ thực thi gửi lệnh.

Với phiên bản 3, CAMS đọc đúng bản tin nguồn của sự kiện từ bảng `t12_syslog_messages` bằng truy vấn có tham số; quy tắc không được cung cấp câu SQL. Nếu thiếu bản tin, biểu thức không khớp hoặc giá trị trích được không hợp lệ theo kiểu khai báo, hệ thống không tạo hành động. Cơ chế này cho phép một quy tắc tắt đúng cổng được nêu trong bản tin cảnh báo thay vì một cổng cố định.

Khối dưới đây là một quy tắc phiên bản 1 dựa trên tài liệu mẫu của dự án, đã lược bớt trường mô tả và một số trường tùy chọn để dễ đọc. Quy tắc tắt cổng `GigabitEthernet0/3` khi nhận sự kiện `ICMP_FLOOD` từ thiết bị thuộc mạng `192.168.122.0/24`, tối đa hai lần mỗi giờ và cách nhau ít nhất 300 giây:

```json
{
  "version": 1,
  "metadata": { "id": "shutdown-gi0-3-on-icmp-flood",
                "name": "Shutdown Gi0/3 on ICMP flood", "enabled": true },
  "schedule": { "interval_seconds": 1 },
  "match": { "event_type": "ICMP_FLOOD", "network": "192.168.122.0",
             "subnet_mask": "255.255.255.0", "attributes": { "protocol": "icmp" } },
  "policy": { "mode": "auto", "cooldown_seconds": 300, "max_actions_per_hour": 2 },
  "action": { "type": "interface.admin-state", "transport": "ssh",
              "interface": "GigabitEthernet0/3", "enabled": false, "ttl_seconds": 0 }
}
```

=== Quản lý quy tắc và lịch sử hành động

Trang *Rule Editor* có hai cách soạn quy tắc: *Quick Builder* cho quy tắc phiên bản 1 đơn giản và *Advanced JSON* cho mọi phiên bản. Trang *Rule Files* liệt kê, bật hoặc tắt, nhập, sửa và xóa tệp quy tắc; sau mỗi thay đổi, CAMS yêu cầu tiến trình Go nạp lại quy tắc nếu tiến trình đang chạy. Các tệp mẫu đi kèm đều để `enabled: false` để tránh thay đổi thiết bị ngay khi nhập. Trang *Action History* hiển thị từng hành động cùng trạng thái, lỗi và kết quả lệnh xác minh. Sự kiện bị chặn bởi thời gian chờ, giới hạn số lần hoặc trùng lặp chỉ làm tăng bộ đếm, không tạo bản ghi hành động.

#figure(
  rect(
    width: 100%, height: 60mm, stroke: (paint: gray, dash: "dashed"),
    align(center + horizon, text(fill: gray)[TODO: chèn ảnh màn hình *Automation* (Rule Files hoặc Action History)]),
  ),
  caption: [Quản lý quy tắc và lịch sử hành động tự động],
) <fig-cams-automation>

Các giới hạn hiện tại gồm: chưa có bước phê duyệt trước khi thực thi; chưa tự hoàn tác sau một khoảng thời gian; hành động chỉ chạy khi thiết bị có phiên SSH đang mở trong CAMS. Quy tắc phiên bản 2 và 3 cho phép gửi lệnh CLI tùy ý trong giới hạn độ dài, nên chỉ được nhập từ nguồn tin cậy và cần được thử ở chế độ `dry-run` trước khi bật `auto`. Quy tắc và nhật ký hành động được lưu trong không gian làm việc, vì vậy không được chứa mật khẩu, chuỗi cộng đồng SNMP hay khóa bí mật.

== Hiện thực tiện ích vận hành và bảo vệ dữ liệu dự án

=== Truyền tệp và đầu cuối

`SftpController` điều phối không gian truyền tệp gồm hai khung cục bộ và từ xa, danh sách kết nối đã lưu, hàng đợi truyền cùng nhật ký thao tác. Bên cạnh SFTP, CAMS hỗ trợ giao thức sao chép an toàn (Secure Copy Protocol – SCP). Các lời gọi SFTP/SCP chạy ngoài luồng giao diện và được tuần tự hóa vì phiên Paramiko không an toàn khi nhiều luồng cùng sử dụng. Với máy chủ chưa biết, ứng dụng hiển thị loại khóa và dấu vân tay để người dùng xác nhận trước khi ghi vào `known_hosts`.

Đầu cuối Alacritty chạy như tiến trình đồng hành và trao đổi trạng thái phiên với CAMS qua NTTP/1. Công cụ này phục vụ chẩn đoán hoặc thao tác CLI trực tiếp, không đi qua dữ liệu chờ và cửa sổ *View & Push*. Vì vậy, sau khi thay đổi cấu hình thủ công, người quản trị cần đồng bộ lại để cơ sở dữ liệu phản ánh trạng thái mới của thiết bị.

=== Đóng gói không gian làm việc và điểm khôi phục

`WorkspaceService` quản lý vòng đời tạo, mở, lưu và đóng dự án. Gói `.ntp` chứa tệp mô tả, hai cơ sở dữ liệu SQLite, dữ liệu sao lưu cấu hình, thư mục quy tắc tự động hóa `automation/rules` và các snapshot của không gian làm việc. Khi mở gói, mục trong thư mục tự động hóa được kiểm tra tên và không được chứa thư mục con; gói tạo từ phiên bản cũ không có thư mục này vẫn mở được. Mỗi snapshot lưu trạng thái nhất quán cần thiết cho việc khôi phục; số snapshot tự động được giới hạn theo chính sách lưu giữ để tránh tăng kích thước gói không kiểm soát.

Khi khôi phục, hệ thống kiểm tra snapshot, tạo một điểm an toàn cho trạng thái hiện tại, thay thế dữ liệu trong không gian làm việc rồi ghi lại gói theo cơ chế thay thế nguyên tử. Thao tác này chỉ khôi phục dữ liệu dự án; nó không tự gửi lệnh hoàn tác xuống thiết bị. Phần mở rộng `.ntp` là định dạng dự án của CAMS, không liên quan đến giao thức đồng bộ thời gian NTP.

=== Bảo vệ thông tin xác thực

Mô-đun `credential_cipher` mã hóa mật khẩu thiết bị theo định dạng `ENC$v2$` bằng AES-256-GCM. Dữ liệu xác thực bổ sung gắn bản mã với ngữ cảnh `host:column`, nên bản mã bị chuyển sang thiết bị hoặc trường khác sẽ không vượt qua bước xác minh. Khi dự án có mật khẩu, khóa được dẫn xuất bằng Argon2id; nếu không, hệ thống dùng khóa HKDF từ dữ liệu cục bộ với mức bảo vệ thấp hơn @rfc9106 @nistSp80038d.

Mật khẩu ứng dụng thư điện tử trong `alert_settings.json` được xử lý qua cùng giao diện mã hóa với ngữ cảnh `smtp:sender_app_password`. Tệp được ghi bằng thao tác thay thế và đặt quyền `0600` trên hệ điều hành hỗ trợ. Đây là bảo vệ ở mức trường dữ liệu, khác với mã hóa toàn bộ gói dự án.

=== Bảo vệ toàn bộ gói dự án

Khi người dùng đặt mật khẩu dự án, mô-đun `workspace.crypto` mã hóa tải ZIP của gói `.ntp` bằng AES-256-GCM. Khóa 256 bit được dẫn xuất bằng Argon2id với 64 MiB bộ nhớ, ba lượt và bốn làn. Phần đầu có phiên bản chứa dấu nhận dạng `NTPAES1`, tham số dẫn xuất khóa, nonce và độ dài dữ liệu; phần đầu này được xác thực cùng bản mã. Dự án không có mật khẩu vẫn được đóng gói nhưng toàn bộ gói không được mã hóa.

#figure(
  image("/00_book/figures/report/misc/xxd-ntp.png", width: 100%),
  caption: [Phần đầu tệp dự án được bảo vệ, quan sát bằng công cụ xxd],
) <fig-cams-encrypted-project>

@fig-cams-encrypted-project cho thấy dấu nhận dạng và phần thông tin có thể đọc để bộ giải mã xác định định dạng. Hình chỉ minh họa cấu trúc lưu trữ, không chứng minh quy trình mở gói đúng mật khẩu, từ chối sai mật khẩu hoặc phát hiện bản mã bị sửa. Các cơ chế này chưa có kịch bản kiểm thử riêng trong Chương 5.
#pagebreak(weak: true)
== Website hướng dẫn sử dụng

Nhóm xây dựng website hướng dẫn sử dụng CAMS để người dùng tra cứu theo từng chức năng, tìm kiếm nội dung và mở nhanh các phần liên quan trong quá trình thực hành. Nội dung website gồm các phần cài đặt, điều hướng, quản lý thiết bị, cấu hình Router, cấu hình Switch và các công cụ vận hành.

#grid(
  columns: (1fr, 38mm),
  gutter: 8mm,
  align: top,
  [
    #set par(justify: false)
    Tài liệu được công bố tại:

    #link("https://viet15t12.github.io/CAMS/")[#raw("https://viet15t12.github.io/CAMS/")]

    Người đọc có thể mở trực tiếp đường dẫn hoặc quét mã QR trong @fig-cams-online-manual. Vì website có thể được cập nhật sau khi báo cáo được in, ngày truy cập và phiên bản phần mềm vẫn cần được ghi nhận khi dùng tài liệu làm căn cứ đối chiếu.
  ],
  [
    #set text(size: 9pt)
    #figure(
      image("/00_report/figures/qr-tai-lieu-huong-dan-cams.svg", width: 28mm),
      caption: [Tài liệu hướng dẫn CAMS trực tuyến],
    ) <fig-cams-online-manual>
  ],
)

// == Tiểu kết chương

// Chương 4 đã ánh xạ thiết kế ở Chương 3 vào các mô-đun hiện thực: QML và PyQt6 cho giao diện, SQLite cho trạng thái, tác vụ nền cho kết nối cùng các dịch vụ riêng cho Syslog, SFTP và không gian làm việc. Các nhóm nghiệp vụ dùng chung bước kiểm duyệt và trả kết quả theo thiết bị. Chương 5 tiếp tục đánh giá bằng cấu hình, lệnh xác minh, lưu lượng thử và bản tin nhật ký.
