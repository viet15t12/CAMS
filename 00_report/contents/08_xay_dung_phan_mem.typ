#pagebreak(weak: true)
#import "../config/tables.typ": report-table

= Xây dựng phần mềm CAMS

== Môi trường phát triển và tổ chức mã nguồn

CAMS là ứng dụng desktop phát triển bằng Python 3.11+, sử dụng Qt Quick/QML và PyQt6 cho giao diện, SQLite cho lưu trữ, Jinja2 cho mẫu cấu hình, Netmiko/Paramiko cho giao tiếp và Dulwich cho lịch sử cấu hình. Công cụ `uv` quản lý môi trường và các phụ thuộc của dự án.

Mã nguồn được tổ chức theo trách nhiệm: `UI/` chứa giao diện và thành phần dùng chung; `core/` chứa các đầu mối điều phối; `features/` tổ chức nghiệp vụ theo tính năng; `infrastructure/` cung cấp kết nối, lưu trữ và workspace. Tệp `main.py` khởi tạo ứng dụng và kết nối các thành phần. Cấu trúc chi tiết được dành cho phụ lục để chương này tập trung vào cách hiện thực chức năng.

== Khởi tạo và kết nối giao diện với nghiệp vụ

Ứng dụng nạp màn hình chào để người dùng tạo hoặc mở dự án, thiết lập đường dẫn dữ liệu rồi mở giao diện chính. Các đối tượng Python, phương thức và tín hiệu PyQt6 chuyển yêu cầu và kết quả giữa QML với nghiệp vụ.

Các bộ điều khiển dữ liệu, Syslog, SFTP và workspace xử lý chức năng tương ứng. Tác vụ mạng chạy nền và gửi kết quả về giao diện. @fig-cams-workspace minh họa không gian làm việc của ứng dụng.

#figure(
  image("/00_book/figures/gui/chapter-03/01-workspace-overview.png", width: 88%),
  caption: [Không gian làm việc tập trung của CAMS],
) <fig-cams-workspace>

== Hiện thực quản lý tập trung

=== Danh mục thiết bị và phiên kết nối

Phân hệ Inventory lưu định danh, địa chỉ quản trị, tham số kết nối và vai trò router, switch L2 hoặc switch L3. Người dùng có thể thêm từng thiết bị hoặc nhập danh sách từ JSON/Excel, tìm kiếm và chọn các thiết bị cần thao tác. Danh mục là điểm liên kết giữa phiên làm việc, dữ liệu cấu hình và thông tin thu thập.

`DeviceSessionRegistry` quản lý các phiên kết nối và cho phép tái sử dụng phiên đang hoạt động. Khóa `operation_lock` điều phối những tác vụ cùng truy cập phiên; `BatchExecutor` hỗ trợ thực hiện trên nhiều thiết bị với kết quả tách riêng. Cách tổ chức này hạn chế việc gửi lệnh đan xen trên một kênh CLI và giúp xác định thiết bị gặp lỗi trong tác vụ hàng loạt.

=== Đồng bộ và lịch sử cấu hình

Phân hệ đồng bộ thu thập `running-config`, lưu bản sao và phân tích các phần được hỗ trợ vào cơ sở dữ liệu. Phân hệ sao lưu dùng Dulwich quản lý lịch sử trong kho Git cục bộ. Người quản trị có thể xem các bản cấu hình và phần khác biệt để truy vết thay đổi, như @fig-cams-config-diff.

#figure(
  image("/00_book/figures/gui/chapter-12/12-running-config-diff.png", width: 100%),
  caption: [So sánh hai phiên bản cấu hình đã lưu],
) <fig-cams-config-diff>

Lịch sử này cung cấp dữ liệu tham chiếu khi kiểm tra sự cố. Việc khôi phục cấu hình thiết bị vẫn cần lựa chọn nội dung phù hợp, triển khai và xác minh lại, thay vì chỉ mở phiên bản cũ trong ứng dụng.

== Hiện thực tự động hóa cấu hình và chính sách

=== Quy trình View & Push dùng chung

Các phân hệ thực hiện cùng một quy trình: kiểm tra dữ liệu biểu mẫu, lưu cấu hình chờ, lấy bản ghi cần thay đổi, kết xuất mẫu Jinja2 và mở cửa sổ xem trước. Khi người dùng chọn Push, tác vụ nền gửi lệnh qua phiên thiết bị, xử lý phản hồi và cập nhật kết quả. Với bản ghi chờ xóa, mẫu sinh lệnh gỡ bỏ tương ứng.

#figure(
  image("/00_book/figures/gui/chapter-05/07-view-push-preview.png", width: 100%),
  caption: [Kiểm duyệt lệnh cấu hình cổng (interface) trước khi triển khai],
) <fig-cams-view-push>

@fig-cams-view-push cho thấy bước kiểm duyệt giữa lưu dữ liệu và tác động lên thiết bị. Quy trình này được sử dụng lại cho các nhóm nghiệp vụ, giúp thống nhất thao tác và cách trình bày trạng thái. Khi thực thi lỗi, người dùng cần xem phản hồi và đồng bộ lại trước khi quyết định gửi lại lệnh.

=== Quản lý cổng (Interfaces), DHCP và định tuyến

Phân hệ quản lý cổng (Interfaces) quản lý IPv4, mô tả và trạng thái cổng; hỗ trợ các cổng logic như Loopback, Subinterface và GRE Tunnel. Cổng vật lý được lấy từ thiết bị để chỉnh sửa thông số; các cổng logic được tạo hoặc gỡ theo nghiệp vụ tương ứng.

DHCP quản lý pool, dải địa chỉ loại trừ và relay. Định tuyến cung cấp tuyến tĩnh, tuyến mặc định, OSPFv2 và EIGRP. Các nhóm biểu mẫu phản ánh quan hệ giữa tiến trình, mạng quảng bá và tham số cổng (interface). Routing Group hỗ trợ chuẩn bị cấu hình cho nhóm router, giảm việc nhập lặp; kết quả vẫn cần kiểm tra trên từng thiết bị.

Các biểu mẫu FHRP hỗ trợ khai báo gateway dự phòng và tham số thành viên cho HSRP, VRRP, GLBP. Việc đánh giá chuyển đổi gateway thuộc kịch bản thực nghiệm, không được suy ra chỉ từ việc sinh đúng lệnh cấu hình.

=== ACL và NAT/PAT

Phân hệ ACL cung cấp biểu mẫu cho Standard, Extended, Dynamic, Reflexive và MAC ACL theo khả năng của loại thiết bị. Quy tắc được quản lý theo thứ tự, kèm cổng áp dụng và chiều áp dụng. Điểm cần kiểm soát là thứ tự khớp luật và chính sách cho phép/từ chối; sau triển khai phải thử cả lưu lượng được phép và lưu lượng bị chặn.

NAT/PAT quản lý ánh xạ tĩnh, pool động và overload, cùng vai trò inside/outside của cổng và điều kiện chọn lưu lượng. Dữ liệu từ bảng chuyển đổi địa chỉ giúp đối chiếu cấu hình với phiên thực tế. Báo cáo tách chức năng chuyển đổi địa chỉ khỏi chức năng bảo mật để không đồng nhất NAT với cơ chế lọc truy cập.

=== Chuyển mạch và cập nhật chính sách Lớp 2

Phân hệ switching quản lý VLAN, access/trunk, EtherChannel, STP và VTP. Trên switch L3, SVI và chức năng định tuyến liên VLAN được cấu hình theo vai trò thiết bị. Mẫu lệnh giữ quan hệ giữa VLAN, cổng vật lý và cổng logic, đồng thời dùng chung bước xem trước để người quản trị kiểm tra phạm vi tác động.

Port Security, DHCP Snooping và DAI được trình bày trong nhóm bảo mật ở phần sau. Các chính sách này cũng được triển khai qua View & Push để duy trì cùng cơ chế kiểm duyệt và ghi nhận kết quả.

== Hiện thực giám sát và thu thập nhật ký

Phân hệ Syslog gồm hai phần: cấu hình đích gửi trên thiết bị và vận hành bộ nhận trong System Logs. Địa chỉ, cổng và giao thức hai phía phải khớp nhau. Cấu hình hiện tại dùng cổng 5514 theo mặc định và cho phép thay đổi theo môi trường.

Bộ thu nhận C++ nhận UDP/TCP, phân tích và ghi bản tin vào SQLite, sau đó chuyển sự kiện qua cầu nối Python để cập nhật QML. Đây là đường xử lý hiện tại; bộ nhận Python được giữ để tương thích và kiểm thử. Hệ thống lưu bản tin gốc cùng trạng thái phân tích. Chỉ số received và dropped hỗ trợ kiểm tra tiếp nhận khi lưu lượng tăng.

#figure(
  image("/00_book/figures/gui/chapter-13/01-system-logs-overview.png", width: 100%),
  caption: [System Logs tập trung nhật ký từ thiết bị mạng],
) <fig-cams-system-logs>

Giao diện tại @fig-cams-system-logs hỗ trợ lọc theo host, mức severity, giao thức, khoảng thời gian và nội dung. Smart Filter kết hợp điều kiện theo facility, mnemonic và từ khóa; cửa sổ chi tiết cho phép đối chiếu thời gian nhận với thời gian thiết bị và đọc raw message. Chức năng Export Excel xuất các dòng sau khi lọc để phục vụ phân tích.

Ngoài log, dữ liệu quan sát như bảng định tuyến, DHCP binding, thống kê ACL, phiên NAT, bộ đếm cổng và bảng MAC hỗ trợ kiểm tra hoạt động của các phân hệ. Các giá trị này phản ánh thời điểm thu thập; khi cần kết luận về trạng thái hiện tại phải thực hiện cập nhật phù hợp.

== Hiện thực hỗ trợ bảo mật và khai thác cảnh báo

=== Triển khai chính sách trên thiết bị

CAMS cung cấp biểu mẫu Port Security để đặt giới hạn MAC, chế độ học và hành động khi vi phạm. Với DHCP Snooping và DAI, người dùng chọn VLAN áp dụng cùng cổng tin cậy theo topology. Các thay đổi được lưu chờ và kiểm duyệt trước khi gửi, như @fig-cams-l2-security.

#figure(
  image("/00_book/figures/gui/chapter-16/04-l2-security-view-push.png", width: 100%),
  caption: [Xem trước chính sách bảo vệ Lớp 2 trước khi áp dụng],
) <fig-cams-l2-security>

Thiết bị mạng thực thi chính sách và có thể phát sinh log tùy tính năng, chế độ và cấu hình logging. Do đó, muốn kiểm chứng cảnh báo cần tạo tình huống phù hợp với cơ chế đã bật, đồng thời bảo đảm đường truyền log đến CAMS hoạt động.

=== Lọc và phân tích sự kiện cảnh báo

System Logs cho phép tập trung các sự kiện cần chú ý bằng cách chọn mức độ và điều kiện lọc. @fig-cams-critical-log minh họa kết quả lọc các mức 0, 1, 2 và 3. Đây là minh họa khả năng truy vấn nhật ký, không tự thân chứng minh phần mềm đã phát hiện một cuộc tấn công.

#figure(
  image("/00_book/figures/gui/chapter-13/05-critical-filter-result.png", width: 100%),
  caption: [Lọc các bản tin có severity từ 0 đến 3 trên System Logs],
) <fig-cams-critical-log>

Mức gửi log trên thiết bị và bộ lọc hiển thị có ý nghĩa khác nhau: ngưỡng gửi thường bao gồm mức đã chọn cùng các mức nghiêm trọng hơn, còn bộ lọc trong CAMS chọn các mức cụ thể. Khi điều tra cần đọc nội dung, nguồn và chuỗi thời gian, tránh kết luận chỉ từ màu hoặc severity.

Phạm vi hiện thực là hỗ trợ phân tích dấu hiệu bất thường qua log và kiểm tra chính sách. Bộ tương quan sự kiện, phát hiện xâm nhập bằng phân tích gói tin và cảnh báo tự động qua email/SMS chưa được tính là chức năng đã hoàn thành.

== Tiện ích vận hành và bảo vệ dự án

SFTP cung cấp hai khung tệp cục bộ và từ xa, xác nhận khóa máy chủ và hàng đợi truyền nền. Terminal đồng hành cung cấp phiên CLI phục vụ thao tác trực tiếp. Sau thay đổi thủ công, cần đồng bộ lại để dữ liệu trong CAMS phản ánh cấu hình mới.

Workspace lưu dữ liệu và lịch sử sao lưu trong gói `.ntp`, hỗ trợ điểm khôi phục và tùy chọn bảo vệ bằng Argon2id, AES-256-GCM. Mã hóa áp dụng cho gói được bảo vệ; khôi phục workspace không tự động hoàn tác cấu hình thiết bị.

#figure(
  image("/00_book/figures/report/misc/xxd-ntp.png", width: 100%),
  caption: [Phần đầu tệp dự án được bảo vệ, quan sát bằng công cụ xxd],
) <fig-cams-encrypted-project>

@fig-cams-encrypted-project cho thấy dấu nhận dạng `NTPAES1` và phần thông tin đầu tệp, gồm thuật toán AES-256-GCM, hàm dẫn xuất khóa Argon2id cùng các tham số liên quan. Phần thông tin này có thể đọc được để phục vụ xử lý tệp; ảnh minh họa cấu trúc lưu trữ, không thay thế kiểm thử mã hóa và giải mã. Chương 5 trình bày các kịch bản kiểm chứng chức năng.
