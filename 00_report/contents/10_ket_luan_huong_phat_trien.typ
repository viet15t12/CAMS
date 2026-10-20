#import "../config/tables.typ": report-table, table-code
#import "../config/commands.typ": report-note

#pagebreak(weak: true)
= Kết luận và hướng phát triển

== Kết quả đạt được

Đề tài đã xây dựng CAMS và kiểm chứng chuỗi cấu hình, giám sát, cảnh báo cùng phản ứng tự động trong một bài thực hành tích hợp. Hệ thống hỗ trợ quy trình từ khai báo thiết bị, kiểm duyệt lệnh, xác minh cấu hình đến phân tích Syslog và thực thi Automation Rule.

#report-table(
  columns: (23%, 38%, 39%),
  header: ([Nhóm kết quả], [Nội dung hiện thực], [Minh chứng và phạm vi]),
  rows: (
    ([Kiến trúc và giao diện], [Qt Quick/QML, điều phối PyQt6, tác vụ nền và biểu mẫu theo chức năng.], [Lab tích hợp minh họa thao tác khai báo, xem trước, kiểm tra và Automation; chưa đo mức phản hồi giao diện dưới tải.]),
    ([Dữ liệu và sao lưu], [Hai tệp SQLite; 93 tên bảng trong lược đồ SQL nguồn (74 + 19); lịch sử Git bằng Dulwich.], [Đối chiếu mã nguồn ở Chương 3–4; số bảng khi vận hành phụ thuộc không gian làm việc và phiên bản.]),
    ([Cấu hình mạng], [Sinh lệnh và triển khai định tuyến, FHRP, chuyển mạch cùng các nghiệp vụ liên quan.], [Chương 5 xác nhận OSPF trên R1-R4, HSRP Active/Standby trên R3/R4 và VTP Server/Client trên SW5/SW6.]),
    ([Giám sát và phản ứng], [Thu nhận Syslog, lọc sự kiện, gửi Email/Telegram và đánh giá Automation Rule bằng Automation Engine (Go core).], [Lab xác nhận Email/Telegram, security event `ICMP_FLOOD` và hành động SSH shutdown cổng con của R4; chưa có phép đo tải.]),
    ([Tiện ích và bảo vệ dữ liệu], [SFTP, đầu cuối, gói dự án `.ntp`; `ENC$v2$`, Argon2id/AES-256-GCM và khóa theo thiết bị.], [Cơ chế được đối chiếu theo mã nguồn và ảnh chức năng ở Chương 3–4; chưa có kịch bản riêng đánh giá toàn bộ cơ chế mật mã, đặc quyền và truyền tệp.]),
    ([Tài liệu hướng dẫn], [Website hướng dẫn sử dụng gồm các quy trình theo từng nhóm chức năng.], [Đường dẫn website và mã QR được trình bày trong Chương 4 để người dùng truy cập trực tiếp.]),
  ),
  text-size: 9.5pt,
  cell-inset: (x: 5pt, y: 6pt),
  caption: [Kết quả hiện thực và mức kiểm chứng tương ứng],
) <tab-project-results-summary>

#pagebreak(weak: true)
== Ý nghĩa khoa học và thực tiễn

=== Ý nghĩa khoa học

Kết quả cho thấy mô hình quản lý cấu hình theo trạng thái có thể triển khai trong môi trường thử nghiệm. `Host Lock` tuần tự hóa tác vụ trên cùng thiết bị, còn `BatchExecutor` xử lý song song giữa các thiết bị độc lập, nhờ đó hạn chế lệnh bị gửi đan xen.

=== Ý nghĩa thực tiễn

CAMS hỗ trợ thực hành định tuyến, chuyển mạch và quy trình tự động hóa mạng. Bài thử cho thấy thao tác theo nhóm giúp chuẩn bị và rà soát cấu hình trên bốn bộ định tuyến cùng hai bộ chuyển mạch. Chuỗi Syslog - security event - Automation Rule - hành động SSH liên kết giám sát với phản ứng có kiểm soát trên cùng giao diện. Lịch sử Git và gói dự án `.ntp` hỗ trợ lưu trữ, khôi phục và phân phối bài thực hành.

== Hạn chế của đề tài

Các hạn chế chính gồm:

+ *Phạm vi thiết bị:* hệ thống được tối ưu cho Cisco IOS trong phòng thực hành; chưa kiểm chứng đầy đủ với nhà sản xuất khác.
+ *Bảo vệ thông tin xác thực:* `ENC$v2$` bảo vệ các trường mật khẩu, nhưng chưa có bằng chứng mọi dữ liệu cũ đã được di chuyển. Chế độ không có mật khẩu dự án cũng không tương đương kho thông tin xác thực của hệ điều hành hay TPM/HSM.
+ *Phụ thuộc bộ phân tích cú pháp CLI:* một số chức năng thu thập trạng thái vẫn phân tích văn bản thô từ lệnh `show`, nên có thể bị ảnh hưởng khi Cisco IOS thay đổi định dạng kết quả.
+ *Đánh giá định lượng:* chưa đo thời gian thao tác, tỷ lệ lỗi triển khai, thời gian hội tụ OSPF, chuyển đổi dự phòng HSRP, độ trễ cảnh báo hoặc khả năng chịu tải Syslog.
+ *Automation Rule:* hành động `shutdown` trong lab tác động toàn bộ cổng con, chưa có đánh giá dương tính giả, cơ chế phê duyệt nhiều cấp hoặc xác nhận Action History `verified` trong bộ ảnh.
+ *Hoàn tác tự động:* điểm khôi phục dự án và lịch sử Git chưa tự sinh lệnh hoàn tác xuống thiết bị khi thực thi chỉ thành công một phần; rule SSH hiện cũng chưa tự khôi phục cổng sau thời gian TTL.

== Lộ trình phát triển ưu tiên

Các hướng phát triển ưu tiên gồm:

+ *Bảo vệ thông tin xác thực:* tích hợp kho bí mật của hệ điều hành, kiểm tra di chuyển dữ liệu cũ sang `ENC$v2$` và quản lý vòng đời khóa.
+ *Hoàn tác:* sinh tập lệnh hoàn tác cho từng lần triển khai và yêu cầu người quản trị kiểm duyệt trước khi gửi.
+ *Khám phá mô hình mạng:* dùng CDP/LLDP để thu thập liên kết và vẽ cấu trúc mạng.
+ *Mở rộng nền tảng:* hoàn thiện BGP/VRF và xây dựng kiến trúc trình điều khiển cho nhiều nhà sản xuất.
+ *Mở rộng giao thức quản trị hiện đại:* tích hợp NETCONF/RESTCONF dựa trên mô hình dữ liệu YANG (IETF/OpenConfig) @rfc6241 @rfc8040 @rfc7950.
+ *Phân tích và cảnh báo:* hoàn thiện tương quan Syslog, bổ sung webhook và kiểm thử độ trễ, chống gửi trùng cùng độ tin cậy của Email/Telegram.
+ *Phản ứng an toàn:* bổ sung chế độ phê duyệt trước khi thi hành, hành động có TTL/rollback, mô phỏng tác động và chính sách giới hạn theo thiết bị hoặc cổng.

== Kiến nghị triển khai và đánh giá tiếp theo

Trước khi áp dụng ngoài phòng thực hành, cần xây dựng bộ kiểm thử lặp lại cho từng nhóm chức năng. Mỗi ca phải ghi phiên bản thiết bị, đầu vào, trạng thái ban đầu, lệnh dự kiến, kết quả và thời gian thực hiện; các ca mất kết nối hoặc lệnh bị từ chối phải kiểm tra cả dữ liệu chờ sau lỗi.

Trong giảng dạy, người học nên chuẩn bị cấu hình, đọc bản xem trước, dự đoán tác động, triển khai rồi đối chiếu bằng lệnh `show` và lưu lượng thử. Khi thí điểm thực tế, chỉ nên dùng thiết bị và mẫu cấu hình đã xác minh, đồng thời chuẩn bị quyền truy cập, bản sao cấu hình và phương án khôi phục.

== Kết luận chung

CAMS đã hình thành quy trình quản trị tập trung gồm lưu trữ dữ liệu, kiểm duyệt và thực thi lệnh, thu thập trạng thái, khai thác Syslog và phản ứng tự động theo quy tắc. Bài thực hành tích hợp cung cấp bằng chứng chức năng từ cấu hình OSPF/HSRP/VTP đến cảnh báo Email/Telegram và hành động SSH sau ICMP flood, nhưng chưa thay thế đánh giá định lượng về thời gian, độ tin cậy giao nhận, tải Syslog và khả năng phục hồi. Vì vậy, giai đoạn tiếp theo cần ưu tiên kiểm thử lặp lại, bảo vệ thông tin xác thực, rollback an toàn và xử lý lỗi trước khi mở rộng nền tảng hoặc giao thức.
