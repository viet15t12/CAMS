#pagebreak(weak: true)
#import "../config/tables.typ": report-table

= Xây dựng phần mềm CAMS

== Môi trường phát triển và tổ chức mã nguồn

CAMS là ứng dụng máy tính để bàn phát triển bằng Python 3.11+, sử dụng Qt Quick/QML và PyQt6 cho giao diện, SQLite để lưu trữ, Jinja2 để tạo lệnh, Netmiko/Paramiko để giao tiếp và Dulwich để quản lý lịch sử cấu hình. Công cụ `uv` quản lý môi trường cùng các gói phụ thuộc của dự án.

Mã nguồn được tổ chức theo trách nhiệm: `UI/` chứa giao diện và các thành phần dùng chung; `core/` chứa đầu mối điều phối; `features/` tổ chức nghiệp vụ theo tính năng; `infrastructure/` cung cấp kết nối, lưu trữ và quản lý không gian làm việc. Tệp `main.py` khởi tạo ứng dụng và liên kết các thành phần. Cấu trúc chi tiết được trình bày trong phụ lục; chương này tập trung vào cách hiện thực các chức năng chính.

== Khởi tạo và kết nối giao diện với nghiệp vụ

Ứng dụng nạp màn hình chào để người dùng tạo hoặc mở dự án, thiết lập đường dẫn dữ liệu rồi chuyển vào giao diện chính. Các đối tượng Python, phương thức và tín hiệu PyQt6 truyền yêu cầu và kết quả giữa QML với tầng nghiệp vụ.

Các bộ điều khiển dữ liệu, Syslog, SFTP và không gian làm việc xử lý chức năng tương ứng. Tác vụ mạng chạy nền và gửi kết quả về giao diện. @fig-cams-workspace minh họa giao diện làm việc của ứng dụng.

#figure(
  image("/00_book/figures/gui/chapter-03/01-workspace-overview.png", width: 88%),
  caption: [Không gian làm việc tập trung của CAMS],
) <fig-cams-workspace>

== Hiện thực quản lý tập trung

=== Danh mục thiết bị và phiên kết nối

Giao diện Inventory lưu mã định danh, địa chỉ quản trị, tham số kết nối và vai trò router, switch L2 hoặc switch L3. Người dùng có thể thêm từng thiết bị hoặc nhập danh sách từ JSON/Excel, tìm kiếm và chọn các thiết bị cần thao tác. Danh mục này liên kết phiên làm việc với dữ liệu cấu hình và thông tin thu thập của từng thiết bị.

`DeviceSessionRegistry` quản lý các phiên kết nối và cho phép tái sử dụng phiên đang hoạt động. Khóa `operation_lock` điều phối những tác vụ cùng truy cập phiên; `BatchExecutor` hỗ trợ thực hiện trên nhiều thiết bị với kết quả tách riêng. Cách tổ chức này hạn chế việc gửi lệnh đan xen trên một kênh CLI và giúp xác định thiết bị gặp lỗi trong tác vụ hàng loạt.

=== Đồng bộ và lịch sử cấu hình

Chức năng đồng bộ thu thập `running-config`, lưu bản sao, phân tích các phần được hỗ trợ rồi cập nhật cơ sở dữ liệu. Dulwich quản lý lịch sử các bản sao trong kho Git cục bộ. Người quản trị có thể xem từng phiên bản và phần khác biệt để truy vết thay đổi, như @fig-cams-config-diff.

#figure(
  image("/00_book/figures/gui/chapter-12/12-running-config-diff.png", width: 100%),
  caption: [So sánh hai phiên bản cấu hình đã lưu],
) <fig-cams-config-diff>

Lịch sử này cung cấp dữ liệu tham chiếu khi kiểm tra sự cố. Việc khôi phục cấu hình thiết bị vẫn cần lựa chọn nội dung phù hợp, triển khai và xác minh lại, thay vì chỉ mở phiên bản cũ trong ứng dụng.

== Hiện thực tự động hóa cấu hình và chính sách

=== Quy trình View & Push dùng chung

Các chức năng thực hiện cùng một quy trình: kiểm tra dữ liệu biểu mẫu, lưu cấu hình chờ, lấy bản ghi cần thay đổi, kết xuất mẫu Jinja2 và mở cửa sổ xem trước. Khi người dùng chọn Push, tác vụ nền gửi lệnh qua phiên thiết bị, xử lý phản hồi và cập nhật kết quả. Với bản ghi chờ xóa, mẫu sinh lệnh gỡ bỏ tương ứng.

#figure(
  image("/00_book/figures/gui/chapter-05/07-view-push-preview.png", width: 100%),
  caption: [Kiểm duyệt lệnh cấu hình cổng (interface) trước khi triển khai],
) <fig-cams-view-push>

@fig-cams-view-push cho thấy bước kiểm duyệt nằm giữa thao tác lưu dữ liệu và triển khai lên thiết bị. Quy trình này được dùng chung cho các nhóm nghiệp vụ, giúp thống nhất thao tác và cách trình bày trạng thái. Khi thực thi gặp lỗi, người dùng cần xem phản hồi và đồng bộ lại trước khi quyết định gửi lại lệnh.

=== Quản lý cổng (Interfaces), DHCP và định tuyến

Chức năng quản lý cổng (Interfaces) quản lý IPv4, mô tả và trạng thái cổng; hỗ trợ các cổng logic như Loopback, Subinterface và GRE Tunnel. Cổng vật lý được lấy từ thiết bị để chỉnh sửa thông số; các cổng logic được tạo hoặc gỡ theo nghiệp vụ tương ứng.

DHCP quản lý pool, dải địa chỉ loại trừ và relay. Định tuyến cung cấp tuyến tĩnh, tuyến mặc định, OSPFv2 và EIGRP. Các nhóm biểu mẫu phản ánh quan hệ giữa tiến trình, mạng quảng bá và tham số cổng (interface). Routing Group hỗ trợ chuẩn bị cấu hình cho nhóm router, giảm việc nhập lặp; kết quả vẫn cần kiểm tra trên từng thiết bị.

Các biểu mẫu FHRP hỗ trợ khai báo gateway dự phòng và tham số thành viên cho HSRP, VRRP, GLBP. Việc đánh giá chuyển đổi gateway thuộc kịch bản thực nghiệm, không được suy ra chỉ từ việc sinh đúng lệnh cấu hình.

=== ACL và NAT/PAT

Chức năng ACL cung cấp biểu mẫu cho Standard, Extended, Dynamic, Reflexive và MAC ACL theo khả năng của loại thiết bị. Quy tắc được quản lý theo thứ tự, kèm cổng áp dụng và chiều áp dụng. Điểm cần kiểm soát là thứ tự khớp luật và chính sách cho phép/từ chối; sau triển khai phải thử cả lưu lượng được phép và lưu lượng bị chặn.

NAT/PAT quản lý ánh xạ tĩnh, pool động, chế độ overload, vai trò inside/outside của cổng và điều kiện chọn lưu lượng. Dữ liệu từ bảng chuyển đổi địa chỉ giúp đối chiếu cấu hình với các phiên thực tế. NAT được xem là chức năng chuyển đổi địa chỉ, không thay thế cơ chế lọc truy cập.

=== Chuyển mạch và cập nhật chính sách Lớp 2

Chức năng chuyển mạch quản lý VLAN, access/trunk, EtherChannel, STP và VTP. Trên switch L3, SVI và định tuyến liên VLAN được cấu hình theo vai trò thiết bị. Mẫu lệnh giữ quan hệ giữa VLAN, cổng vật lý và cổng logic, đồng thời dùng chung bước xem trước để người quản trị kiểm tra phạm vi tác động.

Port Security, DHCP Snooping và DAI được trình bày trong nhóm bảo mật ở phần sau. Các chính sách này cũng được triển khai qua View & Push để duy trì cùng cơ chế kiểm duyệt và ghi nhận kết quả.

== Hiện thực giám sát và thu thập nhật ký

Chức năng Syslog gồm hai phần: cấu hình đích gửi trên thiết bị và vận hành bộ nhận trong System Logs. Địa chỉ, cổng và giao thức hai phía phải khớp nhau. Cấu hình hiện tại dùng cổng 5514 theo mặc định và cho phép thay đổi theo môi trường.

Bộ thu nhận C++ tiếp nhận bản tin qua UDP/TCP, phân tích và ghi dữ liệu vào SQLite, sau đó chuyển sự kiện qua cầu nối Python để cập nhật QML. Đây là luồng xử lý chính; bộ nhận Python được giữ lại để tương thích và kiểm thử. Hệ thống lưu bản tin gốc cùng trạng thái phân tích. Hai chỉ số `received` và `dropped` hỗ trợ theo dõi khả năng tiếp nhận khi lưu lượng tăng.

#figure(
  image("/00_book/figures/gui/chapter-13/01-system-logs-overview.png", width: 100%),
  caption: [System Logs tập trung nhật ký từ thiết bị mạng],
) <fig-cams-system-logs>

Giao diện tại @fig-cams-system-logs hỗ trợ lọc theo thiết bị, mức độ nghiêm trọng, giao thức, khoảng thời gian và nội dung. Smart Filter kết hợp điều kiện theo facility, mnemonic và từ khóa; cửa sổ chi tiết cho phép đối chiếu thời gian nhận với thời gian trên thiết bị và đọc bản tin gốc. Chức năng Export Excel xuất các dòng sau khi lọc để phục vụ phân tích.

Ngoài nhật ký, dữ liệu quan sát như bảng định tuyến, DHCP binding, thống kê ACL, phiên NAT, bộ đếm cổng và bảng MAC hỗ trợ kiểm tra hoạt động của các chức năng. Các giá trị này chỉ phản ánh thời điểm thu thập; muốn kết luận về trạng thái hiện tại, người dùng phải cập nhật dữ liệu trước khi đối chiếu.

== Hiện thực hỗ trợ bảo mật và khai thác cảnh báo

=== Triển khai chính sách trên thiết bị

CAMS cung cấp biểu mẫu Port Security để đặt giới hạn MAC, chế độ học và hành động khi vi phạm. Với DHCP Snooping và DAI, người dùng chọn VLAN áp dụng cùng cổng tin cậy theo mô hình mạng. Các thay đổi được lưu ở trạng thái chờ và kiểm duyệt trước khi gửi, như @fig-cams-l2-security.

#figure(
  image("/00_book/figures/gui/chapter-16/04-l2-security-view-push.png", width: 100%),
  caption: [Xem trước chính sách bảo vệ Lớp 2 trước khi áp dụng],
) <fig-cams-l2-security>

Thiết bị mạng thực thi chính sách và có thể phát sinh nhật ký tùy theo tính năng, chế độ và cấu hình logging. Vì vậy, việc kiểm chứng cảnh báo cần một tình huống phù hợp với cơ chế đã bật, đồng thời phải bảo đảm đường truyền nhật ký đến CAMS hoạt động.

=== Lọc và phân tích sự kiện cảnh báo

System Logs cho phép tập trung các sự kiện cần chú ý bằng cách chọn mức độ và điều kiện lọc. @fig-cams-critical-log minh họa kết quả lọc các mức 0, 1, 2 và 3. Kết quả này thể hiện khả năng truy vấn nhật ký, nhưng không đủ để kết luận phần mềm đã phát hiện một cuộc tấn công.

#figure(
  image("/00_book/figures/gui/chapter-13/05-critical-filter-result.png", width: 100%),
  caption: [Lọc các bản tin có severity từ 0 đến 3 trên System Logs],
) <fig-cams-critical-log>

Ngưỡng gửi trên thiết bị và bộ lọc hiển thị có ý nghĩa khác nhau: ngưỡng gửi thường bao gồm mức đã chọn cùng các mức nghiêm trọng hơn, còn bộ lọc trong CAMS chọn các mức cụ thể. Khi điều tra, người dùng cần đọc nội dung, nguồn và chuỗi thời gian thay vì kết luận chỉ dựa trên màu hoặc severity.

Trong phạm vi hiện tại, CAMS hỗ trợ phân tích dấu hiệu bất thường qua nhật ký và kiểm tra chính sách. Hệ thống chưa hoàn thiện bộ tương quan sự kiện, khả năng phát hiện xâm nhập bằng phân tích gói tin hoặc cảnh báo tự động qua email/SMS.

== Tiện ích vận hành và bảo vệ dự án

SFTP cung cấp hai khung tệp cục bộ và từ xa, xác nhận khóa máy chủ và hàng đợi truyền nền. Terminal đồng hành cung cấp phiên CLI phục vụ thao tác trực tiếp. Sau thay đổi thủ công, cần đồng bộ lại để dữ liệu trong CAMS phản ánh cấu hình mới.

Không gian làm việc lưu dữ liệu và lịch sử sao lưu trong gói `.ntp`, hỗ trợ điểm khôi phục cùng tùy chọn bảo vệ bằng Argon2id và AES-256-GCM. Cơ chế mã hóa chỉ áp dụng cho gói được bảo vệ; việc khôi phục không gian làm việc không tự động hoàn tác cấu hình trên thiết bị.

#figure(
  image("/00_book/figures/report/misc/xxd-ntp.png", width: 100%),
  caption: [Phần đầu tệp dự án được bảo vệ, quan sát bằng công cụ xxd],
) <fig-cams-encrypted-project>

@fig-cams-encrypted-project cho thấy dấu nhận dạng `NTPAES1` và phần thông tin đầu tệp, gồm thuật toán AES-256-GCM, hàm dẫn xuất khóa Argon2id cùng các tham số liên quan. Phần thông tin này có thể đọc được để phục vụ xử lý tệp; ảnh minh họa cấu trúc lưu trữ, không thay thế kiểm thử mã hóa và giải mã. Chương 5 trình bày các kịch bản kiểm chứng chức năng.
