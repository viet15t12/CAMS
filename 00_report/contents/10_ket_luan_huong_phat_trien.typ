#import "../config/tables.typ": report-table, table-code
#import "../config/commands.typ": report-note

#pagebreak(weak: true)
= Kết luận và hướng phát triển

== Kết quả đạt được

Đề tài *“Nghiên cứu và xây dựng hệ thống quản lý tập trung, tự động hóa cấu hình và giám sát an ninh mạng”* đã xây dựng được phần mềm CAMS và đạt các mục tiêu chính trong phạm vi phòng lab. Hệ thống kết hợp giao diện đồ họa, cơ sở dữ liệu quan hệ cục bộ và các thư viện tự động hóa mạng để hỗ trợ quy trình quản trị từ khai báo thiết bị đến cấu hình, xác minh và giám sát.

#report-table(
  columns: (23%, 39%, 38%),
  header: ([Mục tiêu đề tài], [Nội dung kỹ thuật đã hoàn thành], [Bằng chứng kiểm chứng thực nghiệm]),
  rows: (
    (
      [*Kiến trúc phần mềm & giao diện*],
      [Clean Architecture; Qt Quick/QML; Lazy Loading; đa tab; chia đôi không gian làm việc; giao diện sáng/tối.],
      [Tác vụ SSH được chuyển khỏi luồng giao diện để duy trì khả năng phản hồi khi thực thi.],
    ),
    (table.hline(stroke: 0.3pt + rgb("#b8b8b8")),),
    (
      [*Kiến trúc dữ liệu & quản lý phiên bản*],
      [SQLite gồm 93 bảng; tách biệt Desired State và Observed State; sao lưu Git bằng Dulwich.],
      [Hai cơ sở dữ liệu hoạt động độc lập; lưu lịch sử commit; hỗ trợ so sánh theo định dạng Unified Diff.],
    ),
    (table.hline(stroke: 0.3pt + rgb("#b8b8b8")),),
    (
      [*Tự động hóa cấu hình Lớp 2 & Lớp 3*],
      [Quy trình Staged Save $arrow$ Jinja2 Rendering $arrow$ Preview $arrow$ Push cho các nghiệp vụ định tuyến, chuyển mạch và bảo mật.],
      [Hoàn thành ba kịch bản EVE-NG được trình bày; cấu hình được xác minh qua terminal nhúng và phép thử lưu lượng.],
    ),
    (table.hline(stroke: 0.3pt + rgb("#b8b8b8")),),
    (
      [*Hệ sinh thái tiện ích mở rộng*],
      [Syslog Server thời gian thực; SFTP hai khung nhìn; terminal Alacritty giao tiếp IPC (NTTP/1).],
      [Lọc nhật ký theo Severity; truyền tệp nền an toàn; mở phiên CLI độc lập, không xung đột.],
    ),
    (table.hline(stroke: 0.3pt + rgb("#b8b8b8")),),
    (
      [*Đóng gói & an toàn hệ thống*],
      [Tệp Workspace #table-code(".ntp", size: 9.5pt); kiểm tra SHA-256; mã hóa Argon2id + AES-256-GCM; Host Lock.],
      [Dữ liệu dự án được bảo vệ khi lưu trữ và chia sẻ.],
    ),
  ),
  text-size: 10.5pt,
  cell-inset: (x: 6pt, y: 7pt),
  caption: [Tổng hợp kết quả đạt được đối chiếu với mục tiêu nghiên cứu],
) <tab-project-results-summary>

#pagebreak(weak: true)
== Ý nghĩa khoa học và thực tiễn

=== Ý nghĩa khoa học

Kết quả nghiên cứu trình bày cách tổ chức phần mềm phân lớp cho bài toán tự động hóa mạng và cho thấy tính khả thi của mô hình quản lý cấu hình theo trạng thái trong môi trường thử nghiệm. Cơ chế thực thi tuân theo nguyên tắc tuần tự hóa tác vụ trên cùng thiết bị bằng Host Lock và xử lý song song giữa các thiết bị độc lập bằng Batch Executor, qua đó hạn chế nguy cơ lệnh bị gửi đan xen trên một phiên kết nối.

=== Ý nghĩa thực tiễn

CAMS hỗ trợ sinh viên ngành Công nghệ Kỹ thuật Viễn thông và Công nghệ Thông tin thực hành các nội dung mạng máy tính, định tuyến và chuyển mạch, đồng thời tiếp cận quy trình tự động hóa mạng và IaC. Việc nhập tham số một lần, xem trước lệnh và triển khai theo nhóm giúp giảm thao tác lặp lại so với cấu hình thủ công trên từng thiết bị. Tính năng sao lưu bằng Git và đóng gói dự án `.ntp` cũng hỗ trợ giảng viên, quản trị viên lưu trữ, khôi phục và phân phối các kịch bản bài thực hành.

== Hạn chế của đề tài

Bên cạnh các kết quả đạt được, nhóm tác giả ghi nhận một số hạn chế thực tế để định hướng hoàn thiện trong các phiên bản tiếp theo:

+ *Phạm vi hỗ trợ thiết bị:* hệ thống hiện được tối ưu cho Cisco IOS trên các dòng router và switch phổ biến trong phòng lab; chưa có bộ điều hợp giao tiếp cho thiết bị của nhà sản xuất khác.
+ *Bảo mật thông tin xác thực:* mật khẩu đăng nhập thiết bị và khóa bí mật vẫn được lưu trực tiếp trong cơ sở dữ liệu SQLite cục bộ; chưa tích hợp kho bí mật hoặc cơ chế bảo vệ bằng TPM/HSM.
+ *Phụ thuộc bộ phân tích cú pháp CLI:* một số chức năng thu thập trạng thái vẫn phân tích văn bản thô từ lệnh `show`, nên có thể bị ảnh hưởng khi Cisco IOS thay đổi định dạng kết quả.
+ *Hoàn tác tự động:* hệ thống có điểm khôi phục ở mức dự án và lịch sử sao lưu Git, nhưng chưa tự động sinh rồi gửi chuỗi lệnh hoàn tác (`no ...`) xuống thiết bị khi quá trình thực thi chỉ thành công một phần.

== Lộ trình phát triển ưu tiên

Nhằm mở rộng tính năng và nâng cao độ tin cậy của CAMS, nhóm nghiên cứu đề xuất bảy hướng phát triển ưu tiên:

+ *Tăng cường bảo vệ thông tin xác thực:* tích hợp kho bí mật hoặc cơ chế mã hóa mật khẩu qua OS Keyring (Windows DPAPI, Linux Secret Service/Keyutils), bảo đảm mật khẩu không còn được lưu ở dạng rõ trong cơ sở dữ liệu.
+ *Xây dựng cơ chế hoàn tác thông minh:* phát triển bộ điều khiển tự động tạo tập lệnh hoàn tác tương ứng với từng tác vụ Push, cho phép đưa thiết bị về điểm an toàn gần nhất khi phát sinh lỗi.
+ *Tự động khám phá mô hình mạng:* ứng dụng CDP/LLDP để quét thiết bị, vẽ sơ đồ topology và hỗ trợ tính toán tuyến tĩnh.
+ *Mở rộng giao thức định tuyến:* bổ sung giao diện và mẫu Jinja2 cho BGP, VRF để phục vụ các kịch bản mạng ISP hoặc mạng lõi doanh nghiệp.
+ *Hỗ trợ nhiều nhà sản xuất:* xây dựng kiến trúc trình điều khiển hoặc plugin để hỗ trợ MikroTik RouterOS, VyOS, Juniper và router Linux.
+ *Mở rộng giao thức quản trị hiện đại:* tích hợp NETCONF/RESTCONF dựa trên mô hình dữ liệu YANG (IETF/OpenConfig).
+ *Tích hợp phân tích và cảnh báo:* phát triển công cụ phân tích sự kiện Syslog, tự động phát hiện dấu hiệu bất thường và gửi cảnh báo qua webhook hoặc email.
