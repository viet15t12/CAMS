#pagebreak(weak: true)
#import "../config/tables.typ": report-table

= Xây dựng phần mềm CAMS

Chương 3 đã xác định kiến trúc phân lớp, mô hình dữ liệu và các luồng quản lý cấu hình, giám sát cùng bảo vệ dữ liệu. Chương này trình bày cách các thiết kế đó được hiện thực trong mã nguồn và giao diện CAMS. Trọng tâm là trách nhiệm của từng thành phần, đường đi của dữ liệu và cách ứng dụng xử lý tác vụ nền; kết quả vận hành trên mô hình mạng được dành cho Chương 5.

Nội dung được sắp xếp theo chuỗi sử dụng của hệ thống: khởi tạo ứng dụng, quản lý thiết bị, tự động hóa cấu hình, thu thập dữ liệu, triển khai chính sách bảo mật và sử dụng các tiện ích hỗ trợ. Cách trình bày này giữ liên kết giữa yêu cầu ở Chương 3 với bằng chứng kiểm thử ở chương tiếp theo.

== Môi trường phát triển và tổ chức mã nguồn

CAMS là ứng dụng máy tính để bàn dùng Python 3.11 trở lên, Qt Quick/QML và PyQt6 cho giao diện, SQLite để lưu trữ, Jinja2 để tạo lệnh, Netmiko/Paramiko để giao tiếp và Dulwich để quản lý lịch sử cấu hình. Công cụ `uv` quản lý môi trường và gói phụ thuộc.

Mã nguồn được tổ chức theo trách nhiệm: `UI/` chứa giao diện và các thành phần dùng chung; `core/` chứa đầu mối điều phối; `features/` tổ chức nghiệp vụ theo tính năng; `infrastructure/` cung cấp kết nối, lưu trữ và quản lý không gian làm việc. Tệp `main.py` khởi tạo ứng dụng và liên kết các thành phần. Cấu trúc chi tiết được trình bày trong phụ lục; chương này tập trung vào cách hiện thực các chức năng chính.

== Khởi tạo và kết nối giao diện với nghiệp vụ

Ứng dụng nạp màn hình chào để người dùng tạo hoặc mở dự án, thiết lập đường dẫn dữ liệu rồi chuyển vào giao diện chính. Khi khởi tạo, `main.py` tạo các thành phần dùng chung như bộ quản lý cơ sở dữ liệu, sổ đăng ký phiên thiết bị, bộ điều khiển không gian làm việc, SFTP và Syslog; sau đó công bố các đối tượng cần thiết cho QML qua ngữ cảnh của Qt.

QML tiếp nhận thao tác và gọi phương thức của bộ điều khiển Python. Tầng nghiệp vụ kiểm tra dữ liệu, thực hiện tác vụ rồi phát tín hiệu để giao diện cập nhật trạng thái hoặc hiển thị lỗi. Các thao tác mạng và lưu gói dự án được đưa sang tác vụ nền để không chặn luồng giao diện. @fig-cams-workspace minh họa không gian làm việc sau khi quá trình khởi tạo hoàn tất.

#figure(
  image("/00_book/figures/gui/chapter-03/01-workspace-overview.png", width: 88%),
  caption: [Không gian làm việc tập trung của CAMS],
) <fig-cams-workspace>

== Hiện thực quản lý tập trung

=== Danh mục thiết bị và phiên kết nối

Giao diện *Inventory* lưu mã định danh, địa chỉ quản trị, tham số kết nối và vai trò bộ định tuyến, bộ chuyển mạch Lớp 2 hoặc bộ chuyển mạch Lớp 3. Người dùng có thể thêm từng thiết bị hoặc nhập danh sách từ JSON/Excel, tìm kiếm và chọn các thiết bị cần thao tác. Danh mục này liên kết phiên làm việc với dữ liệu cấu hình và thông tin thu thập của từng thiết bị.

`DeviceSessionRegistry` quản lý các phiên kết nối và cho phép tái sử dụng phiên đang hoạt động. Khóa `operation_lock` điều phối những tác vụ cùng truy cập phiên; `BatchExecutor` hỗ trợ thực hiện trên nhiều thiết bị với kết quả tách riêng. Cách tổ chức này hạn chế việc gửi lệnh đan xen trên một kênh CLI và giúp xác định thiết bị gặp lỗi trong tác vụ hàng loạt.

=== Đồng bộ và lịch sử cấu hình

Chức năng đồng bộ thu thập `running-config`, lưu bản sao, phân tích các phần được hỗ trợ rồi cập nhật cơ sở dữ liệu. Dulwich quản lý lịch sử các bản sao trong kho Git cục bộ. Người quản trị có thể xem từng phiên bản và phần khác biệt để truy vết thay đổi, như @fig-cams-config-diff.

#figure(
  image("/00_book/figures/gui/chapter-12/12-running-config-diff.png", width: 100%),
  caption: [So sánh hai phiên bản cấu hình đã lưu],
) <fig-cams-config-diff>

Lịch sử này cung cấp dữ liệu tham chiếu khi kiểm tra sự cố. Việc khôi phục cấu hình thiết bị vẫn cần lựa chọn nội dung phù hợp, triển khai và xác minh lại, thay vì chỉ mở phiên bản cũ trong ứng dụng.

== Hiện thực tự động hóa cấu hình và chính sách

=== Quy trình *View & Push* dùng chung

Các chức năng thực hiện cùng một quy trình: kiểm tra dữ liệu biểu mẫu, lưu cấu hình chờ, lấy bản ghi cần thay đổi, kết xuất mẫu Jinja2 và mở cửa sổ xem trước. Khi người dùng chọn *Push*, tác vụ nền gửi lệnh qua phiên thiết bị, xử lý phản hồi và cập nhật kết quả. Với bản ghi chờ xóa, mẫu sinh lệnh gỡ bỏ tương ứng.

#figure(
  image("/00_book/figures/gui/chapter-05/07-view-push-preview.png", width: 100%),
  caption: [Kiểm duyệt lệnh cấu hình cổng mạng trước khi triển khai],
) <fig-cams-view-push>

@fig-cams-view-push cho thấy bước kiểm duyệt nằm giữa thao tác lưu dữ liệu và triển khai lên thiết bị. Quy trình này được dùng chung cho các nhóm nghiệp vụ, giúp thống nhất thao tác và cách trình bày trạng thái. Khi thực thi gặp lỗi, người dùng cần xem phản hồi và đồng bộ lại trước khi quyết định gửi lại lệnh.

=== Quản lý cổng mạng, DHCP và định tuyến

Chức năng *Interfaces* quản lý địa chỉ IPv4, mô tả và trạng thái cổng; đồng thời hỗ trợ các cổng logic như Loopback, cổng con và đường hầm GRE. Cổng vật lý được lấy từ thiết bị để chỉnh sửa thông số; các cổng logic được tạo hoặc gỡ theo nghiệp vụ tương ứng.

DHCP quản lý vùng cấp phát, dải địa chỉ loại trừ và tác nhân chuyển tiếp. Định tuyến cung cấp tuyến tĩnh, tuyến mặc định, OSPFv2 và EIGRP. Các nhóm biểu mẫu phản ánh quan hệ giữa tiến trình, mạng quảng bá và tham số cổng. Chức năng *Routing Group* hỗ trợ chuẩn bị cấu hình cho nhóm bộ định tuyến nhằm giảm thao tác nhập lặp; kết quả vẫn cần được kiểm tra trên từng thiết bị.

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

Trong phạm vi hiện tại, CAMS hỗ trợ khoanh vùng dấu hiệu bất thường qua nhật ký, đối chiếu chính sách và gửi cảnh báo thư điện tử. Hệ thống chưa có bộ tương quan sự kiện hoàn chỉnh, chưa phát hiện xâm nhập bằng phân tích gói tin và chưa hỗ trợ cảnh báo qua SMS.

== Hiện thực tiện ích vận hành và bảo vệ dữ liệu dự án

=== Truyền tệp và đầu cuối

`SftpController` điều phối không gian truyền tệp gồm hai khung cục bộ và từ xa, danh sách kết nối đã lưu, hàng đợi truyền cùng nhật ký thao tác. Bên cạnh SFTP, CAMS hỗ trợ giao thức sao chép an toàn (Secure Copy Protocol – SCP). Các lời gọi SFTP/SCP chạy ngoài luồng giao diện và được tuần tự hóa vì phiên Paramiko không an toàn khi nhiều luồng cùng sử dụng. Với máy chủ chưa biết, ứng dụng hiển thị loại khóa và dấu vân tay để người dùng xác nhận trước khi ghi vào `known_hosts`.

Đầu cuối Alacritty chạy như tiến trình đồng hành và trao đổi trạng thái phiên với CAMS qua NTTP/1. Công cụ này phục vụ chẩn đoán hoặc thao tác CLI trực tiếp, không đi qua dữ liệu chờ và cửa sổ *View & Push*. Vì vậy, sau khi thay đổi cấu hình thủ công, người quản trị cần đồng bộ lại để cơ sở dữ liệu phản ánh trạng thái mới của thiết bị.

=== Đóng gói không gian làm việc và điểm khôi phục

`WorkspaceService` quản lý vòng đời tạo, mở, lưu và đóng dự án. Gói `.ntp` chứa tệp mô tả, hai cơ sở dữ liệu SQLite, dữ liệu sao lưu cấu hình và các snapshot của không gian làm việc. Mỗi snapshot lưu trạng thái nhất quán cần thiết cho việc khôi phục; số snapshot tự động được giới hạn theo chính sách lưu giữ để tránh tăng kích thước gói không kiểm soát.

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

== Tài liệu hướng dẫn sử dụng trực tuyến

Bên cạnh quyển hướng dẫn dạng PDF, nhóm xây dựng phiên bản tài liệu trực tuyến bằng MkDocs để người dùng tra cứu theo từng chức năng, tìm kiếm nội dung và mở nhanh các chương liên quan trong quá trình thực hành. Nội dung website được đồng bộ với nguồn Typst của quyển hướng dẫn, gồm các phần cài đặt, điều hướng, quản lý thiết bị, cấu hình Router, cấu hình Switch và các công cụ vận hành.

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

== Tiểu kết chương

Chương 4 đã ánh xạ thiết kế ở Chương 3 vào các mô-đun hiện thực: QML và PyQt6 cho giao diện, SQLite cho trạng thái, tác vụ nền cho kết nối cùng các dịch vụ riêng cho Syslog, SFTP và không gian làm việc. Các nhóm nghiệp vụ dùng chung bước kiểm duyệt và trả kết quả theo thiết bị. Chương 5 tiếp tục đánh giá bằng cấu hình, lệnh xác minh, lưu lượng thử và bản tin nhật ký.
