#import "../config/tables.typ": report-table, table-code
#import "../config/commands.typ": report-note

#pagebreak(weak: true)
= Kết luận và hướng phát triển

== Kết quả đạt được

Đề tài *“Nghiên cứu và xây dựng hệ thống quản lý tập trung, tự động hóa cấu hình và giám sát an ninh mạng”* đã xây dựng được phần mềm CAMS và kiểm chứng các chức năng cấu hình, truyền thông cùng giám sát qua năm kịch bản phòng lab. Hệ thống kết hợp giao diện đồ họa, cơ sở dữ liệu quan hệ cục bộ và các thư viện tự động hóa mạng để hỗ trợ quy trình quản trị từ khai báo thiết bị đến cấu hình, xác minh và giám sát.

#report-table(
  columns: (23%, 38%, 39%),
  header: ([Nhóm kết quả], [Nội dung hiện thực], [Minh chứng và phạm vi]),
  rows: (
    ([Kiến trúc và giao diện], [Qt Quick/QML, điều phối PyQt6, tác vụ nền và biểu mẫu theo chức năng.], [Ảnh năm lab minh họa khai báo, xem trước và kiểm tra; chưa đo mức phản hồi giao diện dưới tải.]),
    ([Dữ liệu và sao lưu], [Hai tệp SQLite; 93 tên bảng trong lược đồ SQL nguồn (74 + 19); lịch sử Git bằng Dulwich.], [Đối chiếu mã nguồn ở Chương 3–4; số bảng runtime phụ thuộc workspace và phiên bản.]),
    ([Cấu hình mạng], [Sinh lệnh và triển khai các nghiệp vụ Lớp 2, định tuyến, DHCP, GLBP, NAT/PAT và ACL.], [Năm kịch bản EVE-NG ở Chương 5; Lab 2 có output năm router và sáu loạt ping đều 5/5. Lab 3 mới xác nhận cấu hình GLBP/PAT, chưa kiểm thử failover.]),
    ([Giám sát an ninh], [Thu nhận Syslog, lọc sự kiện và gửi email; hỗ trợ cấu hình chính sách trên thiết bị.], [Lab 1 kiểm tra Snooping/DAI; Lab 4 có hai mẫu email; Lab 5 đối chiếu lưu lượng ACL bị chặn/được phép và nhật ký. Chưa đo mất log dưới tải.]),
    ([Tiện ích và bảo vệ dữ liệu], [SFTP, terminal, gói dự án .ntp; ENC\$v2\$, Argon2id/AES-256-GCM và Host Lock.], [Cơ chế đối chiếu theo mã nguồn và ảnh chức năng ở Chương 3–4; chưa có lab riêng đánh giá toàn bộ mật mã, đặc quyền và truyền tệp.]),
  ),
  text-size: 9.5pt,
  cell-inset: (x: 5pt, y: 6pt),
  caption: [Kết quả hiện thực và mức kiểm chứng tương ứng],
) <tab-project-results-summary>

#pagebreak(weak: true)
== Ý nghĩa khoa học và thực tiễn

=== Ý nghĩa khoa học

Kết quả nghiên cứu trình bày cách tổ chức phần mềm phân lớp cho bài toán tự động hóa mạng và cho thấy tính khả thi của mô hình quản lý cấu hình theo trạng thái trong môi trường thử nghiệm. Cơ chế thực thi tuân theo nguyên tắc tuần tự hóa tác vụ trên cùng thiết bị bằng Host Lock và xử lý song song giữa các thiết bị độc lập bằng Batch Executor, qua đó hạn chế nguy cơ lệnh bị gửi đan xen trên một phiên kết nối.

=== Ý nghĩa thực tiễn

CAMS hỗ trợ sinh viên ngành Công nghệ Kỹ thuật Viễn thông và Công nghệ Thông tin thực hành các nội dung mạng máy tính, định tuyến và chuyển mạch, đồng thời tiếp cận quy trình tự động hóa mạng và IaC. Trong Lab 2, khai báo theo nhóm, nhìn trực quan mạng/cổng/Area và xem trước lệnh giúp CAMS thuận tiện hơn cho việc chuẩn bị và rà soát cấu hình OSPF trên năm router. Ước tính 52 dòng CLI mô tả khối lượng lệnh của quy trình giả định, chưa chứng minh CAMS thực hiện nhanh hơn; CLI vẫn hữu ích khi dùng khối cấu hình có sẵn hoặc chẩn đoán chuyên sâu. Tính năng sao lưu bằng Git và đóng gói dự án `.ntp` cũng hỗ trợ giảng viên, quản trị viên lưu trữ, khôi phục và phân phối các kịch bản bài thực hành.

== Hạn chế của đề tài

Bên cạnh các kết quả đạt được, nhóm tác giả ghi nhận một số hạn chế thực tế để định hướng hoàn thiện trong các phiên bản tiếp theo:

+ *Phạm vi hỗ trợ thiết bị:* hệ thống hiện được tối ưu cho Cisco IOS trên các dòng router và switch phổ biến trong phòng lab; chưa kiểm chứng đầy đủ quy trình cấu hình trên các nhà sản xuất khác. Việc mã nguồn có một số mẫu lệnh cho nền tảng khác không chứng minh hỗ trợ hoàn chỉnh.
+ *Bảo mật thông tin xác thực:* mã nguồn đã có mã hóa trường mật khẩu thiết bị theo ENC\$v2\$ và hàm di chuyển bản ghi cũ. Chưa có bằng chứng mọi workspace cũ đều đã được di chuyển; chế độ không có mật khẩu dự án dùng khóa từ dữ liệu cục bộ và chưa tích hợp OS Keyring hoặc TPM/HSM. Mã hóa một số trường không đồng nghĩa mã hóa toàn bộ SQLite.
+ *Phụ thuộc bộ phân tích cú pháp CLI:* một số chức năng thu thập trạng thái vẫn phân tích văn bản thô từ lệnh `show`, nên có thể bị ảnh hưởng khi Cisco IOS thay đổi định dạng kết quả.
+ *Đánh giá định lượng:* số gói ICMP và số bản tin Syslog chỉ mô tả các phép quan sát được lưu lại. Chưa có đo thời gian CLI/CAMS, tỷ lệ lỗi triển khai, thời gian hội tụ, failover GLBP hoặc khả năng chịu tải. Hai nhóm môi trường lab khác nhau nên không gộp kết quả thành một phép đo hiệu năng chung.
+ *Hoàn tác tự động:* hệ thống có điểm khôi phục ở mức dự án và lịch sử sao lưu Git, nhưng chưa tự động sinh rồi gửi chuỗi lệnh hoàn tác (`no ...`) xuống thiết bị khi quá trình thực thi chỉ thành công một phần.

== Lộ trình phát triển ưu tiên

Nhằm mở rộng tính năng và nâng cao độ tin cậy của CAMS, nhóm tác giả đề xuất bảy hướng phát triển ưu tiên:

+ *Tăng cường bảo vệ thông tin xác thực:* tích hợp OS Keyring hoặc kho bí mật, kiểm tra quá trình di chuyển dữ liệu cũ sang ENC\$v2\$ và quản lý vòng đời khóa khi mở/đóng dự án.
+ *Xây dựng cơ chế hoàn tác thông minh:* phát triển bộ điều khiển tự động tạo tập lệnh hoàn tác tương ứng với từng tác vụ Push, cho phép đưa thiết bị về điểm an toàn gần nhất khi phát sinh lỗi.
+ *Tự động khám phá mô hình mạng:* ứng dụng CDP/LLDP để quét thiết bị, vẽ sơ đồ topology và hỗ trợ tính toán tuyến tĩnh.
+ *Mở rộng giao thức định tuyến:* hoàn thiện và kiểm chứng quy trình BGP hiện có trong mã nguồn, bổ sung quản lý VRF để phục vụ các kịch bản mạng ISP hoặc mạng lõi doanh nghiệp.
+ *Hỗ trợ nhiều nhà sản xuất:* xây dựng kiến trúc trình điều khiển hoặc plugin để hỗ trợ MikroTik RouterOS, VyOS, Juniper và router Linux.
+ *Mở rộng giao thức quản trị hiện đại:* tích hợp NETCONF/RESTCONF dựa trên mô hình dữ liệu YANG (IETF/OpenConfig) @rfc6241 @rfc8040 @rfc7950.
+ *Tích hợp phân tích và cảnh báo:* hoàn thiện tương quan sự kiện Syslog, bổ sung webhook và kiểm thử độ trễ, chống gửi trùng cùng độ tin cậy của cảnh báo email đã hiện thực.
