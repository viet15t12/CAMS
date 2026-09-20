#import "../config/commands.typ": report-note
// Nguồn nội dung: DOC/10_cau_hinh_syslog_server.md
#import "../config/images.typ": insert-image
#import "../config/tables.typ": report-table

= Cấu hình Syslog Server trên Router <ch10>

Tab *Syslog Server* cấu hình router gửi log tới một máy thu Syslog. Có thể tạo destination cho router đang chọn hoặc dùng *Syslog Group* để áp dụng cùng một policy cho nhiều thiết bị. Cửa sổ *View & Push SYSLOG* chỉ xử lý thay đổi Syslog, độc lập với các chức năng khác.

Trước khi cấu hình, xác định địa chỉ máy thu, giao thức UDP/TCP, port listener và đường định tuyến từ source interface của router tới máy thu. Các giá trị này phải khớp với dịch vụ Syslog đang lắng nghe.

== Xem danh sách Syslog destination

Chọn router rồi chọn *Syslog Server* trên Feature Bar. Khu vực *Syslog destinations* hiển thị các máy thu đã lưu cho thiết bị hiện tại.

#insert-image("figures/gui/chapter-10/01-syslog-destinations.png",
  caption: [Danh sách destination và trạng thái cấu hình Syslog của router.], width: 100.0%) <fig:ch10-01-syslog-destinations>

Chọn *Add server* để tạo mới. *View* chỉ xem, *Edit* cập nhật và *Delete* đánh dấu destination cần xóa; thay đổi chỉ tới thiết bị khi thực hiện Push. Trạng thái #raw("pending_apply") là đang chờ áp dụng, #raw("pending_delete") là chờ xóa, #raw("synchronized") là đã khớp với thiết bị và #raw("skipped") là chủ động bỏ qua.

== Thêm hoặc sửa Syslog server

#insert-image("figures/gui/chapter-10/02-syslog-server-editor.png",
  caption: [Biểu mẫu destination với địa chỉ máy thu, transport, port và policy log.], width: 100.0%) <fig:ch10-02-syslog-server-editor>

#report-table(
  breakable: true,
  columns: (1.15fr, 2.85fr),
  header: ([Tham số], [Cách nhập và ý nghĩa]),
  rows: (
    ([*Server IP*], [IPv4 hoặc IPv6 của máy thu Syslog, phải reachable từ router. Không nhập địa chỉ chỉ dùng để bind cục bộ nếu router không thể đi tới địa chỉ đó.]),
    ([*Protocol*], [UDP nhẹ và không thiết lập phiên; TCP có kết nối và phát hiện lỗi truyền tốt hơn. Giá trị phải giống transport của listener.]),
    ([*Port*], [Port đích từ 1 đến 65535. Ví dụ dùng 514 theo quy ước hoặc 5514 khi listener được cấu hình như vậy.]),
    ([*Source interface*], [Interface cung cấp địa chỉ nguồn cho gói Syslog. Ưu tiên Loopback để danh tính ổn định; cũng có thể dùng management interface hoặc SVI reachable.]),
    ([*Trap severity*], [Mức chi tiết cao nhất được gửi: 0 Emergencies, 1 Alerts, 2 Critical, 3 Errors, 4 Warnings, 5 Notifications, 6 Informational, 7 Debug. Chọn một mức sẽ bao gồm mức đó và các sự kiện nghiêm trọng hơn.]),
    ([*Millisecond timestamps*], [Thêm thời gian đến mili-giây, hữu ích khi đối chiếu các sự kiện xảy ra gần nhau.]),
    ([*Sequence numbers*], [Thêm số thứ tự tăng dần từ thiết bị, hỗ trợ phát hiện log thiếu hoặc sai thứ tự.]),
  ),
  caption: [Thêm hoặc sửa Syslog server],
  figure-label: <tab:ch10-table-1>,
)

#report-note[Không nên chọn Debug cho hệ thống vận hành bình thường nếu chưa đánh giá dung lượng log. Nếu dùng Loopback làm source, máy thu cũng phải có route quay về địa chỉ Loopback đó.]

== Cấu hình nhiều router bằng Syslog Group

Chọn *Syslog Group* để tạo cùng một destination và message policy cho 2–5 router. Quy trình gồm ba bước.

=== Bước 1 — Hosts

#insert-image("figures/gui/chapter-10/03-syslog-group-hosts.png",
  caption: [Chọn các router Connected đã có dữ liệu interface trong inventory.], width: 82.0%) <fig:ch10-03-syslog-group-hosts>

Chọn từ hai đến năm host. Thiết bị có nhãn *Inventory required* chưa đủ dữ liệu interface và không thể tham gia; hãy đồng bộ thiết bị trước rồi mở lại Syslog Group.

=== Bước 2 — Interfaces

#insert-image("figures/gui/chapter-10/04-syslog-group-interfaces.png",
  caption: [Chọn một source interface riêng cho từng router.], width: 82.0%) <fig:ch10-04-syslog-group-interfaces>

Mỗi host có thể dùng interface khác nhau nhưng tất cả interface đã chọn phải có đường tới máy thu. Loopback thường là lựa chọn ổn định nhất; nếu routing chưa quảng bá Loopback, hãy chọn management interface hoặc SVI reachable.

=== Bước 3 — Policy

#insert-image("figures/gui/chapter-10/05-syslog-group-policy.png",
  caption: [Nhập destination và chính sách thông báo dùng chung cho cả nhóm.], width: 82.0%) <fig:ch10-05-syslog-group-policy>

Nhập *Server IP*, *Transport*, *Port* và *Trap severity* dùng chung. Bật timestamp và sequence number nếu cần đối chiếu sự kiện. *Save* chỉ lưu cấu hình đang chờ; *Save & Push* lưu rồi bắt đầu quy trình áp dụng cho nhóm. Với tài liệu và môi trường cần kiểm soát, nên Save trước và xem preview độc lập.

== View & Push SYSLOG

Sau khi Save, chọn *View & Push* trong tab Syslog Server.

#insert-image("figures/gui/chapter-10/06-syslog-view-push.png",
  caption: [View & Push SYSLOG tổng hợp lệnh riêng cho R1 và R2.], width: 75.0%) <fig:ch10-06-syslog-view-push>

Xác nhận tiêu đề là *View & Push SYSLOG* và kiểm tra từng host, server IP, transport, port, source interface, severity, timestamp và sequence number. Nếu preview chứa lệnh #raw("no logging host"), kiểm tra lại destination đang xóa trước khi Push.

Sau Push, xác nhận listener đang chạy đúng IP/port/transport, tạo một sự kiện thử trên router và kiểm tra log đến từ đúng source address. Nếu không nhận được log, kiểm tra route, ACL/firewall, port listener và mức severity trước khi thay đổi cấu hình lần nữa.
