#pagebreak(weak: true)
#import "../config/tables.typ": report-table, table-code

= Phân tích và thiết kế hệ thống

== Tác nhân và yêu cầu chức năng

Tác nhân chính là người quản trị mạng, giảng viên hoặc sinh viên vận hành phòng lab. Người dùng tạo không gian làm việc, khai báo thiết bị, đồng bộ dữ liệu, chuẩn bị cấu hình, duyệt lệnh và theo dõi kết quả. Router, switch và máy chủ cung cấp dịch vụ truyền tệp là các hệ thống bên ngoài mà CAMS kết nối; thiết bị mạng đồng thời là nguồn phát nhật ký.

Yêu cầu chức năng được phân theo bốn nhóm của đề tài để liên kết thiết kế với tiêu chí kiểm chứng.

#report-table(
  columns: (18%, 49%, 33%),
  header: ([Nhóm], [Yêu cầu], [Dữ liệu hoặc kết quả]),
  rows: (
    ([Quản lý], [Thêm, sửa, xóa và nhập danh mục; quản lý phiên; đồng bộ và lưu lịch sử cấu hình.], [Danh mục, trạng thái kết nối, bản sao cấu hình.]),
    ([Tự động hóa], [Kiểm tra dữ liệu; tạo lệnh theo từng chức năng; xem trước, áp dụng và trả kết quả riêng từng thiết bị.], [Cấu hình chờ, lệnh dự kiến, phản hồi thực thi.]),
    ([Giám sát], [Thu thập thông tin vận hành; nhận, lưu, lọc và xuất Syslog.], [Trạng thái quan sát, nhật ký có nguồn và thời gian.]),
    ([Bảo mật], [Triển khai ACL, Port Security, DHCP Snooping, DAI; hỗ trợ xem các sự kiện cảnh báo liên quan.], [Chính sách đã gửi, trạng thái và nhật ký để đối chiếu.]),
  ),
  caption: [Yêu cầu chức năng theo phạm vi đề tài],
)

SFTP, terminal và đóng gói dự án là các tiện ích hỗ trợ vận hành. Syslog thuộc nhóm chức năng giám sát chính vì trực tiếp phục vụ mục tiêu giám sát an ninh tập trung. Khả năng cảnh báo được giới hạn ở việc khai thác sự kiện do thiết bị cung cấp, phù hợp với phạm vi đã xác định tại Chương 1.

Các ca sử dụng chính được xác định trong ranh giới CAMS. Người quản trị khởi tạo các thao tác; thiết bị mạng tham gia thực thi và phát nhật ký; máy chủ SFTP và SMTP cung cấp dịch vụ bên ngoài. Ca sử dụng triển khai cấu hình bao gồm kiểm tra tham số và xem trước lệnh.


== Yêu cầu phi chức năng

- *Khả năng phản hồi:* các tác vụ mạng chạy nền; giao diện hiển thị tiến trình và kết quả thay vì chờ đồng bộ trên luồng chính.
- *Nhất quán dữ liệu:* kiểm tra tham số trước khi lưu và sinh lệnh; phân biệt dữ liệu chờ với dữ liệu đã áp dụng và dữ liệu mới thu thập.
- *Kiểm soát thực thi:* tuần tự hóa thao tác dùng chung phiên thiết bị, quản lý thời gian chờ và báo lỗi theo từng tác vụ.
- *Bảo vệ dữ liệu:* hạn chế lộ thông tin xác thực trong nhật ký và giao diện xem trước; hỗ trợ bảo vệ gói dự án khi lưu trữ hoặc trao đổi.
- *Khả năng truy vết:* giữ lịch sử cấu hình, thiết bị nguồn, thời gian nhận nhật ký và bản tin gốc để đối chiếu khi có sự cố.
- *Khả năng bảo trì:* tách giao diện, nghiệp vụ, lưu trữ và giao tiếp mạng để có thể kiểm thử từng thành phần.

Các yêu cầu này là tiêu chí thiết kế và đánh giá. Mức đáp ứng cần được kiểm tra bằng các kịch bản ở Chương 5, không suy ra chỉ từ việc lựa chọn thư viện hoặc mô hình kiến trúc.

== Kiến trúc phân lớp

CAMS tổ chức trách nhiệm thành bốn lớp như @fig-layer-architecture. Lớp giao diện Qt Quick/QML nhận thao tác và hiển thị dữ liệu. Lớp cầu nối PyQt6 tiếp nhận yêu cầu, gọi chức năng và trả về tín hiệu cập nhật. Lớp nghiệp vụ và dữ liệu kiểm tra quy tắc, quản lý trạng thái và truy cập SQLite. Lớp mạng và thực thi quản lý kết nối, sinh lệnh và thực hiện tác vụ nền.

#figure(
  image("/00_book/figures/report/diagrams/22_architecture_overview.svg", width: 74%),
  caption: [Kiến trúc phân lớp của CAMS],
) <fig-layer-architecture>

Bộ thu Syslog C++ và terminal Alacritty là các tiến trình đồng hành ngoài luồng giao diện. Syslog trao đổi sự kiện JSON Lines với Python; NTTP/1 phục vụ terminal. Thành phần giao diện được nạp theo nhu cầu để trì hoãn khởi tạo các vùng chưa sử dụng.

Lớp `DatabaseManager` làm đầu mối cho nhiều thao tác từ giao diện; các bộ điều khiển Syslog, SFTP và không gian làm việc đảm nhiệm chức năng tương ứng. Cách tổ chức này hạn chế việc đặt logic kết nối hoặc truy vấn dữ liệu trực tiếp trong QML.

== Luồng quản lý và tự động hóa cấu hình

=== Đồng bộ trạng thái cơ sở

Người dùng chọn thiết bị trong danh mục và mở kết nối. Bộ quản lý phiên thiết lập phiên SSH hoặc Telnet theo cấu hình. Tác vụ nền thu thập `running-config`, lưu bản sao và phân tích các phần được hỗ trợ để cập nhật cơ sở dữ liệu. Nếu kết nối hoặc phân tích thất bại, giao diện phải thông báo rõ để người dùng không nhầm dữ liệu cũ với trạng thái vừa được thu thập.

=== Chuẩn bị cấu hình mong muốn

Người dùng nhập tham số trên biểu mẫu của từng chức năng. Sau kiểm tra định dạng và quan hệ dữ liệu, ứng dụng lưu thay đổi ở trạng thái chờ. Việc lưu biểu mẫu chưa gửi lệnh tới thiết bị. Các bản ghi chờ thêm/sửa và chờ xóa được phân biệt để bộ tạo mẫu sinh đúng lệnh cấu hình hoặc lệnh gỡ bỏ.

=== Xem trước và thực thi

Luồng View & Push được mô tả tại @fig-state-flow. Bộ điều khiển lấy dữ liệu chờ và dùng Jinja2 tạo khối lệnh. Người dùng kiểm tra thiết bị đích, nội dung thay đổi và thứ tự lệnh trước khi chọn Push. Tác vụ nền sử dụng phiên kết nối có khóa, gửi lệnh và xử lý phản hồi.

#figure(
  image("/00_book/figures/report/diagrams/02_state_flow.svg", width: 100%),
  caption: [Luồng cấu hình từ dữ liệu chờ đến thực thi và cập nhật kết quả],
) <fig-state-flow>

Với thao tác thành công, ứng dụng cập nhật trạng thái bản ghi; với lỗi, thông tin phải được giữ để người dùng kiểm tra và xử lý tiếp. Thành công ở bước gửi lệnh chưa chứng minh dịch vụ hoạt động đúng. Cần truy vấn trạng thái hoặc thử lưu lượng phù hợp để xác minh, nhất là khi một khối lệnh có thể đã được áp dụng một phần trước khi lỗi xuất hiện.

Luồng View & Push xác định thứ tự tương tác giữa người dùng, giao diện, nghiệp vụ, dữ liệu và thiết bị. Khóa phiên chỉ tuần tự hóa truy cập cùng thiết bị; không biến nhiều lệnh CLI thành một giao dịch có khả năng hoàn tác tự động.



== Luồng giám sát và khai thác cảnh báo

Giám sát có hai luồng: thu thập trạng thái bằng lệnh truy vấn và tiếp nhận Syslog do thiết bị gửi. Luồng Syslog gồm cấu hình địa chỉ đích trên thiết bị, khởi động bộ thu nhận tại CAMS, phân tích và lưu bản tin vào cơ sở dữ liệu, sau đó hiển thị kết quả trên giao diện.

Mỗi bản tin cần lưu nguồn gửi, thời gian nhận, mức độ nghiêm trọng, mã sự kiện nếu phân tích được và nội dung gốc. Giao diện hỗ trợ lọc theo thiết bị, thời gian, mức độ và từ khóa, qua đó giúp người quản trị khoanh vùng các sự kiện như thay đổi kết nối hoặc vi phạm chính sách. Khi đồng hồ trên thiết bị chưa được đồng bộ, hệ thống phải phân biệt thời gian do thiết bị ghi với thời gian CAMS nhận bản tin.

@fig-syslog-sequence mô tả luồng tiếp nhận ở tiến trình C++, lưu SQLite và thông báo sang Python bằng JSON Lines. Bộ phân tích giữ riêng nhóm nguồn Syslog từ PRI và mã phân hệ Cisco. Sau lưu trữ, bộ phát hiện theo ngưỡng và dịch vụ email xử lý các bản tin đáp ứng điều kiện; giao diện truy vấn dữ liệu qua bộ lọc.

#figure(
  image("/00_book/figures/report/diagrams/review-syslog-sequence.svg", width: 100%),
  caption: [Sơ đồ tuần tự thu nhận, lưu trữ và khai thác Syslog],
) <fig-syslog-sequence>

== Thiết kế cơ chế an ninh phân quyền và bảo mật dữ liệu

CAMS kiểm soát quyền thực thi trên thiết bị và bảo vệ dữ liệu xác thực khi lưu trữ. Hai cơ chế này có phạm vi khác nhau: quyền thiết bị do Cisco IOS quyết định, còn mã hóa cục bộ phụ thuộc vào khóa của phiên dự án.

=== Kiểm tra đặc quyền và xử lý lỗi xác thực
CAMS lựa chọn mức đặc quyền 15 cho các luồng quản trị Cisco IOS hiện có. Đây là chính sách của ứng dụng, không phải yêu cầu mọi lệnh Cisco IOS đều cần mức 15. Quy trình kiểm tra gồm:
- *Bước 1 (Prompt Level):* Nhận diện dấu nhắc lệnh ban đầu của thiết bị để xác định sơ bộ chế độ hoạt động (User EXEC hoặc Privileged EXEC).
- *Bước 2:* Với thiết bị Cisco, gửi `show privilege` để đọc mức quyền. Khi xác định mức quyền dưới 15, thiếu mật khẩu đặc quyền gây lỗi; nếu có mật khẩu, ứng dụng gọi `enable` hoặc `enable 15` rồi kiểm tra lại. Nhánh xác minh sau nâng quyền từ chối khi không xác nhận được mức quyền yêu cầu.

Mã nguồn hiện vẫn có nhánh dự phòng chấp nhận dấu nhắc `#` khi lần kiểm tra ban đầu không đọc được mức quyền. Vì dấu nhắc này cũng có thể xuất hiện ở mức quyền trung gian, chưa thể mô tả toàn bộ cơ chế là từ chối mặc định (fail-closed) trong mọi tình huống. Đây là giới hạn cần kiểm thử và hoàn thiện.

=== Vòng đời khóa phiên Argon2id và mã hóa AES-256-GCM (ENC\$v2\$)
Để chống lại các nỗ lực vét cạn ngoại tuyến (Offline Brute-force) và hoán đổi bản mã (Ciphertext Swapping), CAMS áp dụng kiến trúc mã hóa có xác thực:
- Khi dự án có mật khẩu, khóa mã hóa dữ liệu (Data Encryption Key – DEK) được dẫn xuất bằng Argon2id với 64 MiB bộ nhớ, ba lượt và bốn làn song song @rfc9106.
- Các trường mật khẩu được mã hóa bằng AES-256-GCM và lưu theo định dạng nội bộ `ENC$v2$`. Đây là phiên bản phong bì dữ liệu của CAMS, không phải tên một tiêu chuẩn mật mã @nistSp80038d.
- Dữ liệu xác thực bổ sung (Additional Authenticated Data – AAD) chứa ngữ cảnh `host:column`. Với bản ghi phiên bản 2 và đúng ngữ cảnh, việc đổi bản mã sang thiết bị hoặc cột khác làm xác minh thẻ thất bại (`InvalidTag`).
- Khóa do đối tượng mã hóa quản lý được giữ trong mảng byte để ghi đè khi hủy. Cơ chế này không xóa được mọi bản sao do môi trường chạy tạo ra. Dự án không có mật khẩu sử dụng khóa dẫn xuất từ dữ liệu cục bộ, nên không có cùng mức bảo vệ với khóa dựa trên bí mật người dùng.

#report-table(
  columns: (22%, 35%, 43%),
  header: ([Tính năng], [Công nghệ & Thuật toán], [Cơ chế hoạt động]),
  rows: (
    ([Kiểm tra đặc quyền], [Phân tích mức quyền, Netmiko `enable`], [Đọc mức quyền, nâng quyền khi cần và kiểm tra lại; còn nhánh dự phòng dấu nhắc ở lần kiểm tra ban đầu.]),
    ([Mã hóa At-Rest (`ENC\$v2\$`)], [Argon2id (RFC 9106), AES-256-GCM], [Lưu bản mã cấu trúc `ENC\$v2\$...`. Sử dụng Record-Bound AAD để chống tráo đổi. Ghi đè bộ nhớ khi hủy khóa.]),
    ([Nhật ký ACL], [Jinja2, Cisco IOS logging], [Sinh tùy chọn ghi nhật ký cho các quy tắc hỗ trợ; thiết bị phải có đích Syslog và ngưỡng gửi phù hợp.]),
  ),
  caption: [Bảng tham chiếu kiến trúc an ninh, phân quyền và giám sát hệ thống],
) <tab-security-architecture>

== Thiết kế cơ sở dữ liệu

CAMS sử dụng hai cơ sở dữ liệu SQLite. Tệp `device_network.db` lưu danh mục thiết bị và cấu hình của các chức năng Interfaces, DHCP, định tuyến, ACL, NAT, chuyển mạch và Syslog; tệp `info_collected.db` lưu dữ liệu quan sát như bảng định tuyến, DHCP binding, thống kê ACL, phiên NAT và bản tin Syslog. Cách tách này giúp dữ liệu cấu hình không bị trộn với dữ liệu thu thập trong quá trình vận hành.

Các bảng liên kết với nhau bằng khóa chính, khóa ngoại và mã thiết bị. Trước khi ghi dữ liệu, tầng nghiệp vụ kiểm tra địa chỉ, dải giá trị và các quan hệ phụ thuộc. Những bản ghi tham gia luồng View \& Push còn có trạng thái chờ áp dụng, đã đồng bộ hoặc chờ xóa; trạng thái này phục vụ sinh lệnh và theo dõi tiến trình, không thay thế việc đồng bộ lại để xác nhận cấu hình thực tế trên thiết bị @elmasri2016database.

Để hệ thống hóa cấu trúc dữ liệu, hệ thống bao gồm 93 bảng nghiệp vụ khác nhau. Dưới đây là lược đồ các bảng chính yếu đại diện cho các phân hệ cốt lõi:

#report-table(
  columns: (25%, 35%, 40%),
  header: ([Tên bảng (Table)], [Khóa chính / Khóa ngoại], [Vai trò và dữ liệu lưu trữ]),
  rows: (
    ([#table-code("t01_devices")], [PK: #table-code("host")], [Lưu định danh, thông tin kết nối, OS và `enable_password` (ENC\$v2\$)]),
    ([#table-code("t02_interfaces")], [PK: #table-code("id") / FK: #table-code("host")], [Quản lý cấu hình cổng L3, L2, trạng thái UP/DOWN và mô tả]),
    ([#table-code("t03_routing_ospf")], [PK: #table-code("id") / FK: #table-code("host")], [Lưu thông tin tiến trình OSPF, vùng Area, Router ID]),
    ([#table-code("t04_acl_rules")], [PK: #table-code("id") / FK: #table-code("host")], [Lưu danh sách kiểm soát truy cập, thứ tự, hành động và từ khóa `log`]),
    ([#table-code("t05_nat_pat")], [PK: #table-code("id") / FK: #table-code("host")], [Quản lý danh sách ánh xạ địa chỉ biên (NAT/PAT), Inside/Outside]),
    ([#table-code("t06_syslog_events")], [PK: #table-code("id")], [Nằm trong `info_collected.db`: Lưu trữ bản tin Syslog gốc, phân loại RFC 5424]),
  ),
  caption: [Lược đồ thực thể - quan hệ (ERD) các bảng nghiệp vụ cốt lõi của CAMS],
) <tab-core-erd-summary>

Lược đồ được đối chiếu trực tiếp với các tệp SQL trong `infrastructure/database/schemas/`. Không dùng tổng số bảng như thước đo mức hoàn thiện vì số này phụ thuộc phiên bản, bảng di chuyển và bảng tạo bổ sung khi chạy. @tab-core-erd liệt kê các thực thể đại diện với đúng tên và khóa trong lược đồ hiện tại.

#report-table(
  columns: (34%, 29%, 37%),
  header: ([Bảng], [Khóa chính / khóa ngoại], [Vai trò]),
  rows: (
    ([#table-code("t01_devices")], [PK: #table-code("host")], [Danh mục và thông tin kết nối thiết bị.]),
    ([#table-code("t02_interface_name")], [PK: #table-code("iface_id"); FK: #table-code("host")], [Cổng mạng và trạng thái cấu hình.]),
    ([#table-code("t04_ospf_processes")], [PK: #table-code("ospf_id"); FK: #table-code("host")], [Tiến trình OSPF và Router ID.]),
    ([#table-code("t04_ospf_networks")], [PK: #table-code("id"); FK: #table-code("ospf_id")], [Mạng, wildcard và vùng OSPF.]),
    ([#table-code("t05_ACL_DB")], [PK: #table-code("Acl_id"); FK: #table-code("host")], [Tên, loại ACL và trạng thái cấu hình.]),
    ([#table-code("t05_extended_acl_rules")], [PK: #table-code("id"); FK: #table-code("acl_id")], [Thứ tự, hành động và điều kiện khớp luật.]),
    ([#table-code("t05_NAT_DB")], [PK: #table-code("nat_id"); FK: #table-code("host")], [Cấu hình NAT và loại chuyển đổi.]),
    ([#table-code("t12_syslog_messages")], [PK: #table-code("id"); #table-code("device_host") là trường liên kết logic], [Thuộc cơ sở dữ liệu quan sát; lưu nguồn, PRI, mức độ, mã Cisco và bản tin gốc.]),
  ),
  caption: [Các bảng và khóa đại diện trong lược đồ dữ liệu CAMS],
) <tab-core-erd>

@fig-core-erd thể hiện các quan hệ một–nhiều. Đường liền là khóa ngoại trong cùng cơ sở dữ liệu; đường đứt là đối chiếu logic giữa hai tệp SQLite. Bảng Syslog không khai báo khóa ngoại sang danh mục thiết bị, nên không được mô tả như quan hệ toàn vẹn tham chiếu do SQLite tự bảo đảm.

#figure(
  image("/00_book/figures/report/diagrams/review-core-erd.svg", width: 100%),
  caption: [Lược đồ quan hệ đại diện giữa thiết bị, cấu hình và nhật ký],
) <fig-core-erd>

== Thiết kế giao diện và xử lý lỗi

Giao diện gồm khu vực danh mục thiết bị, tab làm việc, vùng chức năng và thanh trạng thái. Các biểu mẫu dùng chung cách nhập, lưu và xem trước thay đổi. System Logs cung cấp không gian đọc nhật ký tập trung; các tiện ích SFTP và terminal được mở theo nhu cầu. Hình minh họa giao diện được trình bày tại Chương 4 để gắn thiết kế với phần hiện thực.

Cơ chế Host Lock bảo vệ truy cập phiên dùng chung; Batch Executor điều phối tác vụ giữa các thiết bị. Mỗi lỗi cần gắn với thiết bị và thao tác gây lỗi. Hủy tác vụ hoặc hết thời gian chờ không đồng nghĩa hoàn tác lệnh đã gửi; sau sự cố cần đồng bộ lại để biết phần cấu hình thực tế đã thay đổi.
