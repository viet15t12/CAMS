#import "../config/tables.typ": report-table, table-code
#import "../config/commands.typ": report-note

#pagebreak(weak: true)
= Kết luận và hướng phát triển

== Kết quả đạt được

Đề tài *“Nghiên cứu và xây dựng hệ thống quản lý tập trung, tự động hóa cấu hình và giám sát an ninh mạng”* đã xây dựng phần mềm CAMS và kiểm chứng các chức năng cấu hình, truyền thông cùng giám sát qua năm kịch bản trong phòng thực hành. Hệ thống kết hợp giao diện đồ họa, cơ sở dữ liệu quan hệ cục bộ và các thư viện tự động hóa mạng để hỗ trợ quy trình quản trị từ khai báo thiết bị đến cấu hình, xác minh và giám sát.

#report-table(
  columns: (23%, 38%, 39%),
  header: ([Nhóm kết quả], [Nội dung hiện thực], [Minh chứng và phạm vi]),
  rows: (
    ([Kiến trúc và giao diện], [Qt Quick/QML, điều phối PyQt6, tác vụ nền và biểu mẫu theo chức năng.], [Ảnh của năm kịch bản minh họa thao tác khai báo, xem trước và kiểm tra; chưa đo mức phản hồi giao diện dưới tải.]),
    ([Dữ liệu và sao lưu], [Hai tệp SQLite; 93 tên bảng trong lược đồ SQL nguồn (74 + 19); lịch sử Git bằng Dulwich.], [Đối chiếu mã nguồn ở Chương 3–4; số bảng khi vận hành phụ thuộc không gian làm việc và phiên bản.]),
    ([Cấu hình mạng], [Sinh lệnh và triển khai các nghiệp vụ Lớp 2, định tuyến, DHCP, GLBP, NAT/PAT và ACL.], [Năm kịch bản EVE-NG ở Chương 5; kịch bản 2 có kết quả trên năm bộ định tuyến và sáu loạt kiểm tra ICMP đều nhận đủ 5/5 hồi đáp. Kịch bản 3 mới xác nhận cấu hình GLBP/PAT, chưa kiểm thử chuyển đổi dự phòng.]),
    ([Giám sát an ninh], [Thu nhận Syslog, lọc sự kiện và gửi thư điện tử; hỗ trợ cấu hình chính sách trên thiết bị.], [Kịch bản 1 kiểm tra DHCP Snooping/DAI; kịch bản 4 có hai mẫu thư cảnh báo; kịch bản 5 đối chiếu lưu lượng ACL bị chặn, lưu lượng được phép và nhật ký. Chưa đo tỷ lệ mất bản tin dưới tải.]),
    ([Tiện ích và bảo vệ dữ liệu], [SFTP, đầu cuối, gói dự án `.ntp`; `ENC$v2$`, Argon2id/AES-256-GCM và khóa theo thiết bị.], [Cơ chế được đối chiếu theo mã nguồn và ảnh chức năng ở Chương 3–4; chưa có kịch bản riêng đánh giá toàn bộ cơ chế mật mã, đặc quyền và truyền tệp.]),
  ),
  text-size: 9.5pt,
  cell-inset: (x: 5pt, y: 6pt),
  caption: [Kết quả hiện thực và mức kiểm chứng tương ứng],
) <tab-project-results-summary>

#pagebreak(weak: true)
== Ý nghĩa khoa học và thực tiễn

=== Ý nghĩa khoa học

Kết quả nghiên cứu trình bày cách tổ chức phần mềm phân lớp cho bài toán tự động hóa mạng và cho thấy tính khả thi của mô hình quản lý cấu hình theo trạng thái trong môi trường thử nghiệm. Cơ chế khóa theo thiết bị (`Host Lock`) tuần tự hóa tác vụ trên cùng thiết bị, còn bộ thực thi theo lô (`BatchExecutor`) xử lý song song giữa các thiết bị độc lập. Cách tổ chức này hạn chế lệnh bị gửi đan xen trên một phiên kết nối.

=== Ý nghĩa thực tiễn

CAMS hỗ trợ sinh viên ngành Công nghệ Kỹ thuật Viễn thông và Công nghệ Thông tin thực hành mạng máy tính, định tuyến và chuyển mạch, đồng thời tiếp cận quy trình tự động hóa mạng và quản lý hạ tầng bằng mã (IaC). Trong kịch bản 2, thao tác khai báo theo nhóm, biểu diễn trực quan mạng, cổng và vùng OSPF hỗ trợ chuẩn bị và rà soát cấu hình trên năm bộ định tuyến. Ước tính 52 dòng CLI chỉ mô tả khối lượng lệnh của quy trình giả định, chưa chứng minh CAMS thực hiện nhanh hơn; CLI vẫn hữu ích khi dùng khối cấu hình có sẵn hoặc chẩn đoán chuyên sâu. Tính năng sao lưu bằng Git và đóng gói dự án `.ntp` cũng hỗ trợ giảng viên cùng người quản trị lưu trữ, khôi phục và phân phối các kịch bản bài thực hành.

== Hạn chế của đề tài

Bên cạnh các kết quả đạt được, nhóm tác giả ghi nhận một số hạn chế thực tế để định hướng hoàn thiện trong các phiên bản tiếp theo:

+ *Phạm vi hỗ trợ thiết bị:* hệ thống hiện được tối ưu cho Cisco IOS trên các bộ định tuyến và bộ chuyển mạch phổ biến trong phòng thực hành; chưa kiểm chứng đầy đủ quy trình cấu hình trên thiết bị của nhà sản xuất khác. Việc mã nguồn có một số mẫu lệnh cho nền tảng khác không chứng minh khả năng hỗ trợ hoàn chỉnh.
+ *Bảo vệ thông tin xác thực:* mã nguồn đã có cơ chế mã hóa trường mật khẩu thiết bị theo `ENC$v2$` và hàm di chuyển bản ghi cũ. Chưa có bằng chứng mọi không gian làm việc cũ đều đã được di chuyển; chế độ không có mật khẩu dự án dùng khóa từ dữ liệu cục bộ và chưa tích hợp kho thông tin xác thực của hệ điều hành hoặc TPM/HSM. Mã hóa một số trường không đồng nghĩa với mã hóa toàn bộ cơ sở dữ liệu SQLite.
+ *Phụ thuộc bộ phân tích cú pháp CLI:* một số chức năng thu thập trạng thái vẫn phân tích văn bản thô từ lệnh `show`, nên có thể bị ảnh hưởng khi Cisco IOS thay đổi định dạng kết quả.
+ *Đánh giá định lượng:* số gói ICMP và số bản tin Syslog chỉ mô tả các phép quan sát được lưu lại. Chưa có phép đo thời gian thao tác giữa CLI và CAMS, tỷ lệ lỗi triển khai, thời gian hội tụ, chuyển đổi dự phòng GLBP hoặc khả năng chịu tải. Hai môi trường thử nghiệm khác nhau nên không gộp kết quả thành một phép đo hiệu năng chung.
+ *Hoàn tác tự động:* hệ thống có điểm khôi phục ở mức dự án và lịch sử sao lưu Git, nhưng chưa tự động sinh rồi gửi chuỗi lệnh hoàn tác (`no ...`) xuống thiết bị khi quá trình thực thi chỉ thành công một phần.

== Lộ trình phát triển ưu tiên

Nhằm mở rộng tính năng và nâng cao độ tin cậy của CAMS, nhóm tác giả đề xuất bảy hướng phát triển ưu tiên:

+ *Tăng cường bảo vệ thông tin xác thực:* tích hợp kho thông tin xác thực của hệ điều hành, kiểm tra quá trình di chuyển dữ liệu cũ sang `ENC$v2$` và quản lý vòng đời khóa khi mở hoặc đóng dự án.
+ *Xây dựng cơ chế hoàn tác:* phát triển bộ điều khiển tạo tập lệnh hoàn tác tương ứng với từng lần triển khai, sau đó yêu cầu người quản trị kiểm duyệt trước khi gửi.
+ *Tự động khám phá mô hình mạng:* ứng dụng CDP/LLDP để thu thập quan hệ kết nối, vẽ sơ đồ cấu trúc liên kết và hỗ trợ tính toán tuyến tĩnh.
+ *Mở rộng giao thức định tuyến:* hoàn thiện và kiểm chứng quy trình BGP hiện có trong mã nguồn, bổ sung quản lý VRF để phục vụ các kịch bản mạng ISP hoặc mạng lõi doanh nghiệp.
+ *Hỗ trợ nhiều nhà sản xuất:* xây dựng kiến trúc trình điều khiển hoặc trình cắm để hỗ trợ MikroTik RouterOS, VyOS, Juniper và bộ định tuyến Linux.
+ *Mở rộng giao thức quản trị hiện đại:* tích hợp NETCONF/RESTCONF dựa trên mô hình dữ liệu YANG (IETF/OpenConfig) @rfc6241 @rfc8040 @rfc7950.
+ *Tích hợp phân tích và cảnh báo:* hoàn thiện tương quan sự kiện Syslog, bổ sung webhook và kiểm thử độ trễ, cơ chế chống gửi trùng cùng độ tin cậy của cảnh báo thư điện tử đã hiện thực.

== Kiến nghị triển khai và đánh giá tiếp theo

Trước khi áp dụng CAMS ngoài phòng thực hành, cần xây dựng bộ kiểm thử lặp lại được cho từng nhóm chức năng. Mỗi ca nên ghi rõ phiên bản thiết bị, dữ liệu đầu vào, trạng thái kết nối ban đầu, lệnh dự kiến, kết quả trên thiết bị và thời gian thực hiện. Các ca lỗi như sai địa chỉ, mất kết nối giữa lúc triển khai hoặc lệnh bị Cisco IOS từ chối cần được kiểm tra cùng trạng thái dữ liệu chờ sau lỗi. Cách ghi nhận này giúp tách lỗi của phần mềm khỏi lỗi mô hình mạng và tạo cơ sở so sánh giữa các phiên bản.

Trong giảng dạy, CAMS nên được sử dụng theo quy trình có kiểm soát: người học chuẩn bị cấu hình, đọc bản xem trước, dự đoán tác động, triển khai rồi đối chiếu bằng lệnh `show` và lưu lượng thử. Với môi trường vận hành thật, phạm vi thí điểm nên giới hạn ở nhóm thiết bị và mẫu cấu hình đã được xác minh; quyền truy cập, bản sao cấu hình và phương án khôi phục phải được chuẩn bị trước khi mở rộng quy mô.

== Kết luận chung

Kết quả của đề tài cho thấy CAMS đã hình thành được một quy trình quản trị tập trung gồm lưu trữ dữ liệu, sinh và kiểm duyệt lệnh, thực thi nền, thu thập trạng thái và khai thác Syslog. Năm kịch bản cung cấp bằng chứng chức năng cho các nội dung trọng tâm trong phạm vi phòng thực hành. Tuy nhiên, các kết quả này chưa thay thế đánh giá định lượng về thời gian, độ tin cậy, tải Syslog và khả năng phục hồi khi lỗi xảy ra.

Giá trị chính của hệ thống nằm ở việc liên kết cấu hình mong muốn với trạng thái quan sát và bằng chứng kiểm tra theo từng thiết bị. Các hướng phát triển nêu trên vì vậy cần ưu tiên khả năng kiểm chứng, bảo vệ thông tin xác thực và xử lý lỗi trước khi mở rộng thêm nền tảng hoặc giao thức. Đây cũng là cơ sở để CAMS tiếp tục được hoàn thiện thành công cụ hỗ trợ thực hành và quản trị mạng có phạm vi sử dụng rõ ràng.
