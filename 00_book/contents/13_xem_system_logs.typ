// Nguồn nội dung: DOC/13_xem_system_logs.md
#import "../config/commands.typ": report-note
#import "../config/images.typ": insert-image
#import "../config/tables.typ": report-table

= Xem log trên System Logs <ch13>

Workspace *System Logs* là nơi CAMS nhận, hiển thị, lọc và xuất bản ghi Syslog từ thiết bị mạng. Chức năng này khác với @ch10 : @ch10 tạo cấu hình để router gửi log, còn chương này hướng dẫn vận hành bộ nhận và đọc log đã tới CAMS.

Mở *System Logs* trên Activity Bar hoặc nhấn #raw("Ctrl+Alt+L").

== Khởi động bộ nhận log

#insert-image("figures/gui/chapter-13/02-listener-status.png",
  caption: [Listener đang nhận Syslog qua UDP và TCP.], width: 100.0%) <fig:ch13-02-listener-status>

Thanh trạng thái cho biết:

- *Listener active/stopped*: bộ nhận đang chạy hay đã dừng.
- Địa chỉ bind và port, ví dụ #raw("0.0.0.0:5514"): #raw("0.0.0.0") cho phép lắng nghe trên các địa chỉ mạng của máy CAMS; port phải trùng với port đích cấu hình trên router và được firewall cho phép.
- *UDP + TCP*: các giao thức vận chuyển listener đang chấp nhận.
- *received*: tổng số bản tin đã nhận trong phiên hiển thị.
- *dropped*: số bản tin bị loại bỏ. Nếu giá trị này tăng, cần kiểm tra cấu hình listener, kích thước/lưu lượng bản tin và tài nguyên máy.

Chọn *Start Listener* để bắt đầu nhận hoặc *Stop Listener* khi cần dừng. Địa chỉ bind, port, giao thức và chính sách lưu trữ được đặt trong *Settings → System Logs*. Trước khi thử, bảo đảm router gửi đến đúng IP của máy CAMS, đúng port và giao thức.

== Đọc bảng log

#insert-image("figures/gui/chapter-13/01-system-logs-overview.png",
  caption: [Tổng thể System Logs với đủ tám mức severity từ 0 đến 7.], width: 100.0%) <fig:ch13-01-system-logs-overview>

Mỗi dòng thể hiện thời điểm nhận, thiết bị nguồn, giao thức, severity, Cisco facility/mnemonic và nội dung bản tin. Có thể chọn một host ở panel bên trái để tập trung vào thiết bị đó, để giới hạn phạm vi phân tích log.

== Tám mức độ log Cisco: 0–7

Cisco Syslog có *8 mức severity*, được đánh số từ #raw("0") đến #raw("7"); số càng nhỏ thì sự kiện càng nghiêm trọng. Giao diện CAMS dùng tên *Notice* ở mức 5 và *Debug* ở mức 7; trong cấu hình Cisco hai mức này thường được gọi là *Notifications* và *Debugging*.

#report-table(
  columns: (0.45fr, 1.15fr, 1.25fr, 2.65fr),
  header: ([Mức], [Tên trên CAMS], [Tên thường gặp trên Cisco], [Ý nghĩa và cách xử lý cơ bản]),
  rows: (
    ([*0*], [Emergency], [Emergencies], [Hệ thống không thể sử dụng; xử lý ngay và kích hoạt quy trình sự cố.]),
    ([*1*], [Alert], [Alerts], [Điều kiện cần hành động ngay, ví dụ tài nguyên quan trọng bị lỗi.]),
    ([*2*], [Critical], [Critical], [Lỗi nghiêm trọng ảnh hưởng chức năng chính; ưu tiên điều tra cao.]),
    ([*3*], [Error], [Errors], [Có lỗi trong một chức năng hoặc thao tác; xác định phạm vi ảnh hưởng.]),
    ([*4*], [Warning], [Warnings], [Cảnh báo có thể dẫn đến lỗi; theo dõi và xử lý trước khi nghiêm trọng hơn.]),
    ([*5*], [Notice], [Notifications], [Sự kiện đáng chú ý nhưng hoạt động vẫn bình thường, như thay đổi cấu hình.]),
    ([*6*], [Informational], [Informational], [Thông tin vận hành thông thường, trạng thái interface hoặc phiên làm việc.]),
    ([*7*], [Debug], [Debugging], [Dữ liệu chẩn đoán rất chi tiết; chỉ bật khi cần vì có thể tạo nhiều log.]),
  ),
  caption: [Tám mức độ log Cisco: 0–7],
  figure-label: <tab:ch13-table-1>,
)

#insert-image("figures/gui/chapter-13/04-severity-levels.png",
  caption: [Bộ lọc cho phép chọn chính xác từng mức severity 0–7.], width: 48.0%) <fig:ch13-04-severity-levels>

#report-note[*Phân biệt mức gửi và bộ lọc xem*

Trên router, cấu hình mức trap #raw("5") thường có nghĩa là gửi mức #raw("0") đến #raw("5"), tức mức đã chọn và mọi mức nghiêm trọng hơn. Trong trang System Logs, đánh dấu riêng mức #raw("5") chỉ hiển thị bản ghi có severity đúng bằng #raw("5"). Muốn xem nhóm sự cố nghiêm trọng từ Emergency đến Error, chọn đồng thời #raw("0"), #raw("1"), #raw("2") và #raw("3").]

#insert-image("figures/gui/chapter-13/05-critical-filter-result.png",
  caption: [Kết quả khi lọc đồng thời bốn mức nghiêm trọng 0, 1, 2 và 3.], width: 100.0%) <fig:ch13-05-critical-filter-result>

== Lọc log trên thanh công cụ

#insert-image("figures/gui/chapter-13/03-log-filter-bar.png",
  caption: [Các điều kiện lọc nhanh trước khi đọc hoặc xuất log.], width: 100.0%) <fig:ch13-03-log-filter-bar>

#report-table(
  columns: (1.15fr, 2.85fr),
  header: ([Bộ lọc], [Cách sử dụng]),
  rows: (
    ([*Smart Filter*], [Mở trình tạo điều kiện theo nội dung, host, facility, mnemonic, severity, giao thức và thời gian.]),
    ([*Host*], [Chọn một hoặc nhiều thiết bị gửi log; để trống để xem tất cả host đã kết nối.]),
    ([*Severity*], [Chọn chính xác một hay nhiều mức trong dải 0–7.]),
    ([*Protocol*], [Giới hạn theo UDP, TCP hoặc để *All protocols*.]),
    ([*From / To (UTC)*], [Khoảng thời gian UTC dạng ISO, ví dụ #raw("2026-08-26T18:00"). Hai đầu khoảng thời gian đều được tính.]),
    ([*Latest N per host*], [Chỉ giữ N bản ghi mới nhất của mỗi host sau các điều kiện khác; #raw("0") là không giới hạn, tối đa #raw("500").]),
    ([*Reset*], [Xóa toàn bộ điều kiện và trở về danh sách mặc định.]),
    ([*Export Excel*], [Xuất đúng các dòng đang hiển thị sau khi áp dụng tất cả bộ lọc.]),
  ),
  caption: [Lọc log trên thanh công cụ],
  figure-label: <tab:ch13-table-2>,
)

Nên lọc theo khoảng thời gian và host trước, sau đó thêm severity hoặc từ khóa. Cách này làm tập kết quả nhỏ hơn và giúp so sánh chuỗi sự kiện dễ hơn.

== Tạo Smart Filter

Nhấp vào ô *Click to build a Smart Filter…* để mở biểu mẫu. Chỉ nhập những điều kiện cần thiết; CAMS tự tạo biểu thức ở cuối cửa sổ.

#insert-image("figures/gui/chapter-13/06-smart-filter-builder.png",
  caption: [Smart Filter kết hợp host, severity, facility, mnemonic và thời gian.], width: 78.0%) <fig:ch13-06-smart-filter-builder>

#report-table(
  columns: (1.15fr, 2.85fr),
  header: ([Tham số], [Ý nghĩa và cách dùng]),
  rows: (
    ([Message contains], [tìm chuỗi không phân biệt chữ hoa/thường trong nội dung bản tin.]),
    ([Hosts], [nhập đúng host/IP; nhiều giá trị được phân tách bằng dấu phẩy.]),
    ([Cisco facility], [nhập một phần tên facility như #raw("LINK"), #raw("LINEPROTO"), #raw("SYS") hoặc #raw("OSPF").]),
    ([Mnemonic], [nhập mã sự kiện như #raw("UPDOWN"), #raw("CONFIG_I") hoặc #raw("ADJCHG").]),
    ([Severities], [dùng số #raw("0–7") hoặc tên; có thể nhập nhiều mức bằng dấu phẩy, ví dụ #raw("error,warning") hoặc #raw("3,4").]),
    ([Protocol], [Any giữ lựa chọn trên thanh công cụ; UDP, TCP hoặc UDP + TCP sẽ ghi đè điều kiện giao thức tương ứng.]),
    ([From / To (UTC)], [khoảng thời gian tuyệt đối. *Recent window* nhận dạng như #raw("30m"), #raw("2h"), #raw("7d"), #raw("1w") và thay thế From khi được nhập.]),
    ([Latest per host], [số bản ghi mới nhất cho mỗi host; #raw("0") không giới hạn.]),
  ),
  caption: [Tạo Smart Filter — tham số],
  figure-label: <tab:ch13-fields-2>,
)

Điều kiện trong Smart Filter sẽ *ghi đè bộ lọc cùng loại* trên thanh công cụ. Ví dụ, nếu Smart Filter có #raw("severity:3,4"), lựa chọn severity trên thanh công cụ không còn quyết định điều kiện severity. Đọc biểu thức *Generated Smart Filter* trước khi chọn *Apply Filter*.

== Xem chi tiết một bản tin

Nhấp đúp một dòng log để mở cửa sổ chi tiết tại @fig:ch13-07-log-message-details.

#insert-image("figures/gui/chapter-13/07-log-message-details.png",
  caption: [Thông tin đã phân tích và raw message của một sự kiện Cisco.], width: 78.0%) <fig:ch13-07-log-message-details>

#report-table(
  columns: (1.15fr, 2.85fr),
  header: ([Thuộc tính], [Ý nghĩa]),
  rows: (
    ([*Source / Protocol*], [IP nguồn và UDP/TCP đã mang bản tin đến CAMS.]),
    ([*Received*], [Thời điểm CAMS nhận bản tin; dùng mốc này khi đồng hồ thiết bị không tin cậy.]),
    ([*Device time*], [Thời gian do thiết bị ghi trong bản tin.]),
    ([*PRI / Syslog facility*], [PRI Syslog và facility chuẩn được phân tích từ message.]),
    ([*Parse status*], [Trạng thái CAMS phân tích cấu trúc bản tin.]),
    ([*Cisco facility / Subfacility*], [Thành phần Cisco phát sinh sự kiện, hỗ trợ khoanh vùng module.]),
    ([*Severity / Mnemonic*], [Mức 0–7 và mã sự kiện Cisco.]),
    ([*Sequence / Clock*], [Số thứ tự bản tin và trạng thái đồng bộ đồng hồ nếu có.]),
    ([*Raw message*], [Bản tin gốc; dùng để đối chiếu khi trường đã phân tích thiếu hoặc không như mong đợi.]),
  ),
  caption: [Xem chi tiết một bản tin],
  figure-label: <tab:ch13-table-4>,
)

Khi điều tra, nên đọc theo thứ tự: *Received/Device time → Host → Severity → Facility/Mnemonic → Raw message*. Nếu thời gian giữa nhiều thiết bị lệch nhau, kiểm tra NTP trước khi kết luận thứ tự sự kiện.

== Xuất log phục vụ phân tích

Áp dụng bộ lọc phù hợp rồi chọn *Export Excel*. CAMS chỉ xuất các dòng đang hiển thị sau mọi bộ lọc, vì vậy nên ghi nhận khoảng thời gian, host, severity và Smart Filter đã dùng. Không xuất toàn bộ dữ liệu khi chỉ cần một sự cố ngắn vì tệp lớn sẽ khó kiểm tra và có thể chứa thông tin vận hành không liên quan.
