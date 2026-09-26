#pagebreak(weak: true)
#import "../config/tables.typ": report-table

= Phân tích và thiết kế hệ thống

== Tác nhân và yêu cầu chức năng

Tác nhân chính là người quản trị mạng, giảng viên hoặc sinh viên vận hành phòng lab. Người dùng tạo không gian làm việc, khai báo thiết bị, đồng bộ dữ liệu, chuẩn bị cấu hình, duyệt lệnh và theo dõi kết quả. Router, switch và máy chủ cung cấp dịch vụ truyền tệp là các hệ thống bên ngoài mà CAMS kết nối; thiết bị mạng đồng thời là nguồn phát nhật ký.

Yêu cầu chức năng được phân theo bốn nhóm của đề tài để liên kết thiết kế với tiêu chí kiểm chứng.

#report-table(
  columns: (18%, 49%, 33%),
  header: ([Nhóm], [Yêu cầu], [Dữ liệu hoặc kết quả]),
  rows: (
    ([Quản lý], [Thêm, sửa, xóa và nhập danh mục; quản lý phiên; đồng bộ và lưu lịch sử cấu hình.], [Danh mục, trạng thái kết nối, bản sao cấu hình.]),
    ([Tự động hóa], [Kiểm tra dữ liệu; tạo lệnh theo phân hệ; xem trước, áp dụng và trả kết quả riêng từng thiết bị.], [Cấu hình chờ, lệnh dự kiến, phản hồi thực thi.]),
    ([Giám sát], [Thu thập thông tin vận hành; nhận, lưu, lọc và xuất Syslog.], [Trạng thái quan sát, nhật ký có nguồn và thời gian.]),
    ([Bảo mật], [Triển khai ACL, Port Security, DHCP Snooping, DAI; hỗ trợ xem các sự kiện cảnh báo liên quan.], [Chính sách đã gửi, trạng thái và log để đối chiếu.]),
  ),
  caption: [Yêu cầu chức năng theo phạm vi đề tài],
)

SFTP, terminal và đóng gói dự án là các tiện ích hỗ trợ vận hành. Syslog thuộc nhóm chức năng giám sát chính vì trực tiếp phục vụ mục tiêu giám sát an ninh tập trung. Phần phát hiện/cảnh báo được giới hạn ở việc khai thác sự kiện do thiết bị cung cấp như đã xác định tại Chương 1.

== Yêu cầu phi chức năng

- *Khả năng phản hồi:* các tác vụ mạng chạy nền; giao diện hiển thị tiến trình và kết quả thay vì chờ đồng bộ trên luồng chính.
- *Nhất quán dữ liệu:* kiểm tra tham số trước khi lưu và sinh lệnh; phân biệt dữ liệu chờ với dữ liệu đã áp dụng và dữ liệu mới thu thập.
- *Kiểm soát thực thi:* tuần tự hóa thao tác dùng chung phiên thiết bị, quản lý thời gian chờ và báo lỗi theo từng tác vụ.
- *Bảo vệ dữ liệu:* hạn chế lộ thông tin xác thực trong log và giao diện xem trước; hỗ trợ bảo vệ gói dự án khi lưu trữ hoặc trao đổi.
- *Khả năng truy vết:* giữ lịch sử cấu hình, thiết bị nguồn, thời gian nhận log và bản tin gốc để đối chiếu khi có sự cố.
- *Khả năng bảo trì:* tách giao diện, nghiệp vụ, lưu trữ và giao tiếp mạng để có thể kiểm thử từng thành phần.

Các yêu cầu này là tiêu chí thiết kế và đánh giá. Mức đáp ứng cần được kiểm tra bằng các kịch bản ở Chương 5, không suy ra chỉ từ việc lựa chọn thư viện hoặc mô hình kiến trúc.

== Kiến trúc phân lớp

CAMS tổ chức trách nhiệm thành bốn lớp như @fig-layer-architecture. Lớp giao diện Qt Quick/QML nhận thao tác và hiển thị dữ liệu. Lớp cầu nối PyQt6 tiếp nhận yêu cầu, gọi chức năng và trả tín hiệu cập nhật. Lớp nghiệp vụ và dữ liệu kiểm tra quy tắc, quản lý trạng thái và truy cập SQLite. Lớp mạng và thực thi quản lý kết nối, sinh lệnh và thực hiện tác vụ nền.

#figure(
  image("/00_book/figures/report/diagrams/22_architecture_overview.svg", width: 74%),
  caption: [Kiến trúc phân lớp của CAMS],
) <fig-layer-architecture>

Đối tượng `DatabaseManager` làm đầu mối cho nhiều thao tác từ giao diện; các bộ điều khiển Syslog, SFTP và workspace đảm nhiệm chức năng tương ứng. Cách tổ chức này giảm việc đặt logic kết nối hoặc truy vấn dữ liệu trực tiếp trong QML. Hệ thống chạy cục bộ, còn router và switch thực thi cấu hình và phát sinh trạng thái, sự kiện.

== Luồng quản lý và tự động hóa cấu hình

=== Đồng bộ trạng thái cơ sở

Người dùng chọn thiết bị trong danh mục và mở kết nối. Bộ quản lý phiên thiết lập phiên SSH hoặc Telnet theo cấu hình. Tác vụ nền thu thập `running-config`, lưu bản sao và phân tích các phần được hỗ trợ thành dữ liệu cơ sở. Nếu kết nối hoặc phân tích thất bại, giao diện cần thông báo rõ để người dùng không hiểu dữ liệu cũ là trạng thái vừa cập nhật.

=== Chuẩn bị cấu hình mong muốn

Người dùng nhập tham số trên biểu mẫu của từng phân hệ. Sau kiểm tra định dạng và quan hệ dữ liệu, ứng dụng lưu thay đổi ở trạng thái chờ. Việc lưu biểu mẫu chưa gửi lệnh tới thiết bị. Các bản ghi chờ thêm/sửa và chờ xóa được phân biệt để bộ tạo mẫu sinh đúng lệnh cấu hình hoặc lệnh gỡ bỏ.

=== Xem trước và thực thi

Luồng View & Push được mô tả tại @fig-state-flow. Bộ điều khiển lấy dữ liệu chờ và dùng Jinja2 tạo khối lệnh. Người dùng kiểm tra thiết bị đích, nội dung thay đổi và thứ tự lệnh trước khi chọn Push. Tác vụ nền sử dụng phiên kết nối có khóa, gửi lệnh và xử lý phản hồi.

#figure(
  image("/00_book/figures/report/diagrams/02_state_flow.svg", width: 100%),
  caption: [Luồng cấu hình từ dữ liệu chờ đến thực thi và cập nhật kết quả],
) <fig-state-flow>

Với thao tác thành công, ứng dụng cập nhật trạng thái bản ghi; với lỗi, thông tin phải được giữ để người dùng kiểm tra và xử lý tiếp. Thành công ở bước gửi lệnh chưa chứng minh dịch vụ hoạt động đúng. Cần truy vấn trạng thái hoặc thử lưu lượng phù hợp để xác minh, nhất là khi một khối lệnh có thể đã được áp dụng một phần trước khi lỗi xuất hiện.

== Luồng giám sát và khai thác cảnh báo

Giám sát có hai luồng: thu thập trạng thái bằng lệnh truy vấn và tiếp nhận Syslog do thiết bị gửi. Luồng Syslog gồm cấu hình đích nhận trên thiết bị, khởi động bộ thu nhận tại CAMS, phân tích và lưu bản tin, sau đó hiển thị kết quả truy vấn.

Mỗi bản tin cần giữ nguồn gửi, thời gian nhận, mức severity, mã sự kiện nếu phân tích được và nội dung gốc. Giao diện hỗ trợ lọc theo thiết bị, thời gian, mức độ và từ khóa; qua đó người quản trị khoanh vùng các sự kiện như thay đổi kết nối hoặc vi phạm chính sách. Khi thời gian trên thiết bị chưa đồng bộ, phải phân biệt thời gian do thiết bị ghi với thời gian CAMS nhận bản tin.

Chuỗi kiểm chứng cho một sự kiện bảo mật là: chính sách đã được triển khai trên thiết bị, tình huống thử kích hoạt cơ chế tương ứng, thiết bị tạo log, CAMS nhận được log và người dùng truy vấn thấy đúng nguồn, nội dung. Thiếu một mắt xích trong chuỗi này không đủ cơ sở để kết luận chức năng cảnh báo đã đạt yêu cầu.

== Thiết kế dữ liệu

CAMS sử dụng hai tệp SQLite để tách dữ liệu cấu hình với dữ liệu quan sát. Số bảng phụ thuộc phiên bản lược đồ; báo cáo tập trung vào vai trò và quan hệ dữ liệu.

#report-table(
  columns: (33%, 67%),
  header: ([Kho dữ liệu], [Nội dung chính]),
  rows: (
    ([`device_network.db`], [Danh mục thiết bị; cấu hình cổng (interface), DHCP, định tuyến, ACL, NAT, chuyển mạch và các chính sách liên quan.]),
    ([`info_collected.db`], [Thông tin thu thập như bảng định tuyến, DHCP binding, thống kê ACL, phiên NAT và nhật ký Syslog.]),
  ),
  caption: [Phân tách dữ liệu cấu hình và dữ liệu quan sát],
) <tab-database-schema-config>

Thiết bị là đối tượng liên kết với nhiều cổng (interfaces) và nhiều bản ghi nghiệp vụ. Khóa chính định danh bản ghi; khóa ngoại liên kết bản ghi với thiết bị hoặc đối tượng liên quan. Các kiểm tra địa chỉ, dải giá trị và quan hệ phụ thuộc được thực hiện ở tầng nghiệp vụ trước khi lưu hoặc sinh lệnh.

Trong các bảng áp dụng cơ chế cấu hình chờ, trường `success` thể hiện ba trạng thái: `0` là chờ thêm hoặc cập nhật, `1` là đã đồng bộ/áp dụng, `-1` là chờ xóa. Đây là cờ quản lý quy trình, không phải chỉ số chứng minh thiết bị luôn khớp cấu hình, vì trạng thái thực tế có thể thay đổi sau lần đồng bộ gần nhất.

== Thiết kế giao diện và xử lý lỗi

Giao diện gồm khu vực danh mục thiết bị, tab làm việc, vùng chức năng và thanh trạng thái. Các biểu mẫu dùng chung cách nhập, lưu và xem trước thay đổi. System Logs cung cấp không gian đọc nhật ký tập trung; các tiện ích SFTP và terminal được mở theo nhu cầu. Hình minh họa giao diện được trình bày tại Chương 4 để gắn thiết kế với phần hiện thực.

Cơ chế Host Lock bảo vệ truy cập phiên dùng chung; Batch Executor điều phối tác vụ giữa các thiết bị. Mỗi lỗi cần gắn với thiết bị và thao tác gây lỗi. Hủy tác vụ hoặc hết thời gian chờ không đồng nghĩa hoàn tác lệnh đã gửi; sau sự cố cần đồng bộ lại để biết phần cấu hình thực tế đã thay đổi.
