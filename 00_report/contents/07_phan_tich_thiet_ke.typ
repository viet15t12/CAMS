#pagebreak(weak: true)
#import "../config/tables.typ": report-table, table-code

= Phân tích và thiết kế hệ thống

== Tác nhân và yêu cầu chức năng

Tác nhân chính là người quản trị mạng, giảng viên hoặc sinh viên vận hành phòng thực hành. Người dùng tạo không gian làm việc, khai báo thiết bị, đồng bộ dữ liệu, chuẩn bị cấu hình, duyệt lệnh và theo dõi kết quả. Bộ định tuyến, bộ chuyển mạch và máy chủ cung cấp dịch vụ truyền tệp là các hệ thống bên ngoài mà CAMS kết nối; thiết bị mạng đồng thời là nguồn phát nhật ký.

Yêu cầu chức năng được phân theo bốn nhóm của đề tài để liên kết thiết kế với tiêu chí kiểm chứng.

#report-table(
  columns: (18%, 49%, 33%),
  header: ([Nhóm], [Yêu cầu], [Dữ liệu hoặc kết quả]),
  rows: (
    ([Quản lý], [Thêm, sửa, xóa và nhập danh mục; quản lý phiên; đồng bộ và lưu lịch sử cấu hình.], [Danh mục, trạng thái kết nối, bản sao cấu hình.]),
    ([Tự động hóa], [Kiểm tra dữ liệu; tạo lệnh theo từng chức năng; xem trước, áp dụng và trả kết quả riêng từng thiết bị.], [Cấu hình chờ, lệnh dự kiến, phản hồi thực thi.]),
    ([Giám sát], [Thu thập thông tin vận hành; nhận, lưu, lọc và xuất Syslog; gửi cảnh báo Email/Telegram.], [Trạng thái quan sát, nhật ký có nguồn và thời gian, kết quả gửi cảnh báo.]),
    ([Bảo mật], [Triển khai chính sách; chuẩn hóa sự kiện an ninh; đánh giá quy tắc tự động hóa và thực hiện phản ứng có kiểm soát.], [Chính sách đã gửi, sự kiện an ninh, hành động phản ứng và kết quả xác minh.]),
  ),
  caption: [Yêu cầu chức năng theo phạm vi đề tài],
)

SFTP, đầu cuối và chức năng đóng gói dự án là các tiện ích hỗ trợ vận hành. Syslog thuộc nhóm chức năng giám sát chính vì trực tiếp phục vụ mục tiêu giám sát an ninh tập trung. Khả năng cảnh báo được giới hạn ở việc khai thác sự kiện do thiết bị cung cấp, phù hợp với phạm vi đã xác định tại Chương 1.

=== Tác nhân và luồng tương tác

Người quản trị khởi tạo thao tác trên CAMS; thiết bị mạng cung cấp trạng thái, nhận cấu hình và phát nhật ký. Máy chủ SFTP, SMTP và Telegram Bot API là các dịch vụ ngoài hỗ trợ truyền tệp và gửi cảnh báo. Luồng cấu hình gồm đồng bộ trạng thái, chuẩn bị dữ liệu, xem trước lệnh, triển khai và xác minh.

CAMS kiểm tra tham số và lưu phản hồi CLI, nhưng kết luận một chính sách hoạt động vẫn cần lệnh kiểm tra hoặc lưu lượng thử. Nguyên tắc này được dùng để xây dựng tiêu chí cho các kịch bản ở Chương 5.

#pagebreak(weak: true)
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

Bộ thu Syslog, Automation Engine và đầu cuối được tổ chức thành các thành phần hoạt động độc lập với giao diện. Bộ thu chịu trách nhiệm tiếp nhận nhật ký, Automation Engine đánh giá sự kiện theo quy tắc, còn đầu cuối phục vụ thao tác CLI trực tiếp. Việc tách riêng giúp các tác vụ kéo dài không làm gián đoạn giao diện và cho phép từng thành phần được phát triển, kiểm tra theo đúng trách nhiệm.

Tầng dữ liệu và nghiệp vụ làm đầu mối xử lý yêu cầu từ giao diện, đồng thời điều phối các chức năng Syslog, truyền tệp và quản lý không gian làm việc. Nhờ đó, giao diện chỉ tập trung tiếp nhận thao tác và trình bày kết quả, không trực tiếp xử lý kết nối hoặc truy vấn cơ sở dữ liệu.

#pagebreak(weak: true)
== Luồng quản lý và tự động hóa cấu hình

=== Đồng bộ trạng thái cơ sở

Người dùng chọn thiết bị trong danh mục và mở kết nối. Bộ quản lý phiên thiết lập phiên SSH hoặc Telnet theo cấu hình. Tác vụ nền thu thập `running-config`, lưu bản sao và phân tích các phần được hỗ trợ để cập nhật cơ sở dữ liệu. Nếu kết nối hoặc phân tích thất bại, giao diện phải thông báo rõ để người dùng không nhầm dữ liệu cũ với trạng thái vừa được thu thập.

=== Chuẩn bị cấu hình mong muốn

Người dùng nhập tham số trên biểu mẫu của từng chức năng. Sau kiểm tra định dạng và quan hệ dữ liệu, ứng dụng lưu thay đổi ở trạng thái chờ. Việc lưu biểu mẫu chưa gửi lệnh tới thiết bị. Các bản ghi chờ thêm/sửa và chờ xóa được phân biệt để bộ tạo mẫu sinh đúng lệnh cấu hình hoặc lệnh gỡ bỏ.

=== Xem trước và thực thi

Luồng *View & Push* được mô tả tại @fig-state-flow. Hệ thống lấy dữ liệu chờ và chuyển thành khối lệnh theo mẫu của từng chức năng. Người dùng kiểm tra thiết bị đích, nội dung thay đổi và thứ tự lệnh trước khi chọn *Push*. Sau khi được xác nhận, tác vụ nền gửi lệnh qua phiên kết nối và xử lý phản hồi của thiết bị.

#figure(
  image("/00_book/figures/report/diagrams/02_state_flow.svg", width: 100%),
  caption: [Luồng cấu hình từ dữ liệu chờ đến thực thi và cập nhật kết quả],
) <fig-state-flow>

Trình tự trao đổi được thể hiện tại @fig-view-push-sequence. Giao diện chỉ bắt đầu thực thi sau khi người dùng xác nhận bản xem trước. Hệ thống lần lượt gửi lệnh, nhận phản hồi và cập nhật trạng thái liên quan. Kết quả được ghi nhận riêng theo thiết bị để một lỗi không che khuất kết quả của các thiết bị còn lại.

#pagebreak(weak: true)
#figure(
  image("/00_book/figures/report/diagrams/24_view_push_sequence.svg", width: 100%),
  caption: [Sơ đồ tuần tự của quy trình View \& Push],
) <fig-view-push-sequence>

Ứng dụng cập nhật trạng thái khi thành công và giữ thông tin lỗi để người dùng xử lý. Việc gửi lệnh thành công chưa chứng minh dịch vụ hoạt động đúng; người dùng vẫn phải kiểm tra trạng thái hoặc lưu lượng, nhất là khi khối lệnh có thể chỉ được áp dụng một phần.

Các thao tác trên cùng một thiết bị được xử lý tuần tự để tránh xung đột. Tuy nhiên, một nhóm lệnh CLI vẫn có thể chỉ được áp dụng một phần và không mặc nhiên có khả năng hoàn tác tự động.


== Luồng giám sát và khai thác cảnh báo

Giám sát có hai luồng: thu thập trạng thái bằng lệnh truy vấn và tiếp nhận Syslog do thiết bị gửi. Luồng Syslog gồm cấu hình địa chỉ đích trên thiết bị, khởi động bộ thu nhận tại CAMS, phân tích và lưu bản tin vào cơ sở dữ liệu, sau đó hiển thị kết quả trên giao diện.

Mỗi bản tin cần lưu nguồn gửi, thời gian nhận, mức độ nghiêm trọng, mã sự kiện nếu phân tích được và nội dung gốc. Giao diện hỗ trợ lọc theo thiết bị, thời gian, mức độ và từ khóa, qua đó giúp người quản trị khoanh vùng các sự kiện như thay đổi kết nối hoặc vi phạm chính sách. Khi đồng hồ trên thiết bị chưa được đồng bộ, hệ thống phải phân biệt thời gian do thiết bị ghi với thời gian CAMS nhận bản tin.

@fig-syslog-sequence mô tả quá trình tiếp nhận, phân tích, lưu trữ và khai thác Syslog. Hệ thống phân biệt nhóm nguồn của chuẩn Syslog với mã phân hệ của Cisco để tránh nhầm lẫn khi lọc. Sau khi được lưu, các bản tin phù hợp có thể tạo sự kiện an ninh, kích hoạt cảnh báo Email/Telegram hoặc được người dùng truy vấn trên giao diện.

#figure(
  image("/00_book/figures/report/diagrams/review-syslog-sequence.svg", width: 100%),
  caption: [Sơ đồ tuần tự thu nhận, lưu trữ và khai thác Syslog],
) <fig-syslog-sequence>

#pagebreak(weak: true)
=== Thiết kế vòng phản ứng tự động

Automation Engine tiếp nhận các sự kiện an ninh đã được chuẩn hóa và đối chiếu với bộ quy tắc do người quản trị thiết lập. Mỗi quy tắc xác định loại sự kiện cần quan tâm, phạm vi thiết bị, các điều kiện đi kèm và phản ứng tương ứng. Hệ thống đồng thời kiểm soát việc xử lý lặp và tần suất thực hiện để một sự kiện lặp lại liên tục không tạo ra quá nhiều hành động.

Khi một sự kiện đáp ứng đầy đủ điều kiện, hệ thống tạo lệnh phản ứng, gửi tới thiết bị qua phiên kết nối đang hoạt động, thực hiện bước kiểm tra và lưu kết quả. @fig-automation-go-sequence thể hiện ranh giới giữa ba nhiệm vụ: nhận biết sự kiện, quyết định phản ứng theo quy tắc và thực hiện phản ứng trên thiết bị. Cách phân chia này giúp quy tắc độc lập với cơ chế kết nối, đồng thời duy trì thông tin để người quản trị theo dõi và đối chiếu.

#figure(
  image("/00_book/figures/report/diagrams/automation-go-core-sequence.svg", width: 100%),
  caption: [Sơ đồ tuần tự từ sự kiện Syslog đến hành động phản ứng đã được xác minh],
) <fig-automation-go-sequence>


== Thiết kế cơ chế an ninh phân quyền và bảo mật dữ liệu

CAMS kiểm soát quyền thực thi trên thiết bị và bảo vệ dữ liệu xác thực khi lưu trữ. Hai cơ chế này có phạm vi khác nhau: quyền thiết bị do Cisco IOS quyết định, còn mã hóa cục bộ phụ thuộc vào khóa của phiên dự án.

=== Kiểm soát quyền thực thi và lỗi xác thực

CAMS sử dụng mức đặc quyền 15 cho các luồng quản trị Cisco IOS hiện có. Trước khi triển khai cấu hình, hệ thống nhận biết chế độ làm việc, kiểm tra mức quyền và thực hiện nâng quyền khi có thông tin xác thực phù hợp. Nếu không thể xác nhận quyền cần thiết, thao tác phải dừng và trả về thông báo để tránh gửi lệnh trong một phiên không đủ quyền.

Dấu nhắc lệnh chỉ cung cấp dấu hiệu ban đầu về chế độ làm việc và không phải lúc nào cũng chứng minh chính xác mức đặc quyền. Vì vậy, thiết kế ưu tiên kết quả kiểm tra trực tiếp từ thiết bị; các trường hợp chỉ dựa vào dấu nhắc vẫn cần được tiếp tục kiểm thử và hoàn thiện.

=== Thiết kế bảo vệ thông tin xác thực và dữ liệu dự án

Để hạn chế nguy cơ dò mật khẩu và sửa đổi dữ liệu lưu trữ, CAMS kết hợp dẫn xuất khóa bằng Argon2id với mã hóa có xác thực AES-256-GCM @rfc9106 @nistSp80038d. Khi dự án có mật khẩu, khóa bảo vệ được tạo từ chính mật khẩu đó; các trường thông tin xác thực và gói dự án sau đó được mã hóa trước khi ghi xuống bộ nhớ lưu trữ.

Dữ liệu mã hóa được liên kết với đúng ngữ cảnh sử dụng để hạn chế việc sao chép bản mã sang thiết bị hoặc trường dữ liệu khác. Nếu mật khẩu không đúng hoặc nội dung đã bị sửa, quá trình xác thực thất bại và dữ liệu không được chấp nhận. Đối với dự án không đặt mật khẩu, khóa tạo từ dữ liệu cục bộ chỉ cung cấp mức bảo vệ hạn chế hơn. Ngoài ra, thông tin rõ vẫn phải tồn tại tạm thời trong bộ nhớ khi thiết lập kết nối, nên mã hóa lưu trữ không loại bỏ mọi rủi ro.

#report-table(
  columns: (22%, 35%, 43%),
  header: ([Tính năng], [Công nghệ và thuật toán], [Cơ chế hoạt động]),
  rows: (
    ([Kiểm tra đặc quyền], [Cơ chế xác thực và nâng quyền của Cisco IOS], [Kiểm tra quyền trước khi cấu hình, nâng quyền khi cần và thông báo lỗi nếu không đáp ứng.]),
    ([Mã hóa dữ liệu lưu trữ], [Argon2id và AES-256-GCM], [Dẫn xuất khóa từ mật khẩu, mã hóa có xác thực và phát hiện dữ liệu bị sửa đổi.]),
    ([Nhật ký ACL], [Mẫu cấu hình và cơ chế ghi nhật ký Cisco IOS], [Tạo tùy chọn ghi nhật ký cho các quy tắc được hỗ trợ; thiết bị phải có đích Syslog và ngưỡng gửi phù hợp.]),
  ),
  caption: [Bảng tham chiếu kiến trúc an ninh, phân quyền và giám sát hệ thống],
) <tab-security-architecture>
// #pagebreak(weak: true)
== Thiết kế cơ sở dữ liệu

CAMS sử dụng hai cơ sở dữ liệu SQLite. Tệp `device_network.db` lưu danh mục thiết bị, cấu hình cổng mạng, DHCP, định tuyến, ACL, NAT, chuyển mạch và các đích Syslog cần cấu hình; tệp `info_collected.db` lưu dữ liệu quan sát như bảng định tuyến, bảng liên kết DHCP, thống kê ACL, phiên NAT và bản tin Syslog đã nhận. Cách tách này giúp dữ liệu cấu hình không bị trộn với dữ liệu thu thập trong quá trình vận hành.

Các bảng liên kết bằng khóa chính, khóa ngoại và mã thiết bị. Tầng nghiệp vụ kiểm tra địa chỉ, dải giá trị và quan hệ phụ thuộc trước khi ghi dữ liệu. Bản ghi trong luồng View \& Push có trạng thái chờ áp dụng, đã đồng bộ hoặc chờ xóa; các trạng thái này phục vụ sinh lệnh và theo dõi tiến trình, không thay thế việc đồng bộ lại từ thiết bị.

Đối chiếu các khai báo `CREATE TABLE` trong mã nguồn SQL hiện tại ghi nhận 74 tên bảng trong nhóm `device_network` và 19 tên bảng trong nhóm `info_collected`, tổng cộng 93 tên bảng. Đây là số đếm của lược đồ nguồn, không khẳng định mọi không gian làm việc đang chạy đều có đúng 93 bảng.

// Lược đồ được đối chiếu trực tiếp với các tệp SQL trong `infrastructure/database/schemas/`. Không dùng tổng số bảng như thước đo mức hoàn thiện vì số này phụ thuộc phiên bản, bảng di chuyển và bảng tạo bổ sung khi chạy. @tab-core-erd liệt kê các thực thể đại diện với đúng tên và khóa trong lược đồ hiện tại.

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
    ([#table-code("t05_router_iface_acl")], [PK: #table-code("id"); FK: #table-code("iface_id"), #table-code("acl_id")], [Gắn ACL vào cổng mạng theo chiều vào hoặc ra.]),
    ([#table-code("t05_NAT_DB")], [PK: #table-code("nat_id"); FK: #table-code("host")], [Cấu hình NAT và loại chuyển đổi.]),
    ([#table-code("t10_syslog_servers")], [PK ghép: #table-code("device_host"), #table-code("server_ip"), #table-code("protocol"), #table-code("port"); FK: #table-code("device_host")], [Đích Syslog và trạng thái triển khai cấu hình theo thiết bị.]),
  ),
  caption: [Các bảng và khóa đại diện trong lược đồ dữ liệu CAMS],
) <tab-core-erd>

@fig-core-erd chỉ thể hiện các khóa ngoại đã khai báo trong nhóm lược đồ `device_network`. Mỗi mũi tên đi từ bảng được tham chiếu (bảng cha) đến bảng chứa khóa ngoại (bảng con). Phần lớn là quan hệ một-nhiều: một bản ghi cha có thể chưa có hoặc có nhiều bản ghi con. Riêng `t02_interface_name` đến `t02_router_iface_l3` là quan hệ một-tối-đa-một vì mỗi cổng chỉ có tối đa một bản ghi cấu hình Lớp 3. Trong đó, `t05_router_iface_acl` tham chiếu đồng thời cổng mạng và ACL; `t10_syslog_servers` tham chiếu thiết bị qua `device_host`. Bảng `t12_syslog_messages` thuộc `info_collected.db`; trường `device_host` ở bảng này chỉ phục vụ đối chiếu logic và không phải khóa ngoại liên cơ sở dữ liệu.

#figure(
  image("/00_book/figures/report/diagrams/review-core-erd.svg", width: 100%),
  caption: [Lược đồ khóa ngoại đại diện trong cơ sở dữ liệu `device_network.db`],
) <fig-core-erd>

== Tiểu kết chương

Thiết kế CAMS liên kết các yêu cầu quản lý, tự động hóa, giám sát và bảo mật trong một kiến trúc phân lớp. Ba luồng chính gồm quản lý trạng thái thiết bị, triển khai cấu hình có bước kiểm duyệt và khai thác sự kiện để cảnh báo hoặc phản ứng tự động. Dữ liệu cấu hình dự kiến được tách khỏi dữ liệu quan sát, còn kết quả được ghi nhận theo từng thiết bị để hỗ trợ truy vết.

Các mô hình trong chương này là cơ sở để xây dựng giao diện và chức năng được trình bày ở Chương 4. Hiệu quả vận hành của thiết kế tiếp tục được kiểm chứng bằng cấu hình thực tế, lệnh xác minh, lưu lượng thử và bản tin nhật ký ở Chương 5.
