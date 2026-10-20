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
    ([Tự động hóa], [Kiểm tra dữ liệu; tạo lệnh theo từng chức năng; xem trước, áp dụng và trả kết quả riêng từng thiết bị; chọn thiết bị theo mẫu và triển khai theo lô có đợt thử; thực thi quy tắc phản ứng theo sự kiện.], [Cấu hình chờ, lệnh dự kiến, phản hồi thực thi, nhật ký hành động tự động.]),
    ([Giám sát], [Thu thập thông tin vận hành; nhận, lưu, lọc và xuất Syslog; phát hiện mẫu sự kiện theo ngưỡng; gửi cảnh báo qua thư điện tử và Telegram.], [Trạng thái quan sát, nhật ký có nguồn và thời gian, cảnh báo đã gửi.]),
    ([Bảo mật], [Triển khai ACL, bảo mật cổng (Port Security), DHCP Snooping và DAI; hỗ trợ xem các sự kiện cảnh báo liên quan; đánh giá cấu hình đã sao lưu theo bộ quy tắc an ninh.], [Chính sách đã gửi, trạng thái và nhật ký để đối chiếu; điểm và kết quả từng quy tắc.]),
  ),
  caption: [Yêu cầu chức năng theo phạm vi đề tài],
)

SFTP, đầu cuối và chức năng đóng gói dự án là các tiện ích hỗ trợ vận hành. Syslog thuộc nhóm chức năng giám sát chính vì trực tiếp phục vụ mục tiêu giám sát an ninh tập trung. Khả năng cảnh báo được giới hạn ở việc khai thác sự kiện do thiết bị cung cấp, phù hợp với phạm vi đã xác định tại Chương 1. Bộ phản ứng tự động cũng chỉ dựa trên các sự kiện này; nó không phân tích gói tin và không thay thế quyết định của người quản trị đối với những thay đổi ngoài phạm vi quy tắc đã khai báo.

=== Tác nhân và luồng tương tác

Người quản trị khởi tạo thao tác trên CAMS; thiết bị mạng cung cấp trạng thái, nhận cấu hình và phát nhật ký. Máy chủ SFTP, máy chủ SMTP và giao diện lập trình Telegram Bot là các dịch vụ ngoài hỗ trợ truyền tệp và gửi cảnh báo. Luồng cấu hình gồm đồng bộ trạng thái, chuẩn bị dữ liệu, xem trước lệnh, triển khai và xác minh.

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

Bộ thu Syslog C++, đầu cuối Alacritty và bộ lập kế hoạch tự động hóa viết bằng Go là các tiến trình đồng hành ngoài luồng giao diện. Bộ thu Syslog trao đổi sự kiện JSON Lines với Python; NTTP/1 phục vụ đầu cuối; tiến trình Go nhận yêu cầu và trả kết quả dạng JSON Lines qua đầu vào và đầu ra chuẩn. @fig-layer-architecture chưa thể hiện tiến trình Go; vai trò của tiến trình này được mô tả tại @fig-automation-flow. Thành phần giao diện được nạp theo nhu cầu để trì hoãn khởi tạo các vùng chưa sử dụng.

Lớp `DatabaseManager` làm đầu mối cho nhiều thao tác từ giao diện; các bộ điều khiển Syslog, SFTP và không gian làm việc đảm nhiệm chức năng tương ứng. Cách tổ chức này hạn chế việc đặt logic kết nối hoặc truy vấn dữ liệu trực tiếp trong QML.

#pagebreak(weak: true)
== Luồng quản lý và tự động hóa cấu hình

=== Đồng bộ trạng thái cơ sở

Người dùng chọn thiết bị trong danh mục và mở kết nối. Bộ quản lý phiên thiết lập phiên SSH hoặc Telnet theo cấu hình. Tác vụ nền thu thập `running-config`, lưu bản sao và phân tích các phần được hỗ trợ để cập nhật cơ sở dữ liệu. Nếu kết nối hoặc phân tích thất bại, giao diện phải thông báo rõ để người dùng không nhầm dữ liệu cũ với trạng thái vừa được thu thập.

=== Chuẩn bị cấu hình mong muốn

Người dùng nhập tham số trên biểu mẫu của từng chức năng. Sau kiểm tra định dạng và quan hệ dữ liệu, ứng dụng lưu thay đổi ở trạng thái chờ. Việc lưu biểu mẫu chưa gửi lệnh tới thiết bị. Các bản ghi chờ thêm/sửa và chờ xóa được phân biệt để bộ tạo mẫu sinh đúng lệnh cấu hình hoặc lệnh gỡ bỏ.

=== Xem trước và thực thi

Luồng *View & Push* được mô tả tại @fig-state-flow. Bộ điều khiển lấy dữ liệu chờ và tạo khối lệnh bằng mẫu Jinja2 hoặc hàm Python của mô-đun tương ứng. Người dùng kiểm tra thiết bị đích, nội dung thay đổi và thứ tự lệnh trước khi chọn *Push*. Tác vụ nền sử dụng phiên kết nối có khóa, gửi lệnh và xử lý phản hồi.

#figure(
  image("/00_book/figures/report/diagrams/02_state_flow.svg", width: 100%),
  caption: [Luồng cấu hình từ dữ liệu chờ đến thực thi và cập nhật kết quả],
) <fig-state-flow>

Trình tự trao đổi chi tiết được thể hiện tại @fig-view-push-sequence. Giao diện chỉ tạo tác vụ thực thi sau khi người dùng xác nhận bản xem trước. Tác vụ nền lấy khóa của phiên thiết bị, gửi lệnh, nhận phản hồi và cập nhật trạng thái liên quan. Kết quả được trả riêng theo thiết bị để một lỗi không che khuất kết quả của các thiết bị còn lại.

#pagebreak(weak: true)
#figure(
  image("/00_book/figures/report/diagrams/24_view_push_sequence.svg", width: 100%),
  caption: [Sơ đồ tuần tự của quy trình View \& Push],
) <fig-view-push-sequence>

Ứng dụng cập nhật trạng thái khi thành công và giữ thông tin lỗi để người dùng xử lý. Việc gửi lệnh thành công chưa chứng minh dịch vụ hoạt động đúng; người dùng vẫn phải kiểm tra trạng thái hoặc lưu lượng, nhất là khi khối lệnh có thể chỉ được áp dụng một phần.

Khóa phiên tuần tự hóa truy cập cùng thiết bị nhưng không biến nhiều lệnh CLI thành một giao dịch có khả năng hoàn tác tự động.

=== Triển khai trên nhiều thiết bị

Khi một cấu hình nhóm được gửi tới nhiều thiết bị, mỗi thiết bị có bộ điều khiển và kết quả riêng. Lớp thực thi giới hạn số thiết bị chạy đồng thời, mặc định là 20 và tối đa 50. Ý tưởng triển khai theo đợt được tham khảo từ các tham số `serial` và `max_fail_percentage` của Ansible @ansibleNetworkDocs:

+ Nếu số thiết bị lớn hơn kích thước đợt thử (mặc định 5), các thiết bị đầu danh sách chạy trước. Các thiết bị còn lại chỉ bắt đầu khi đợt thử kết thúc.
+ Sau khi đủ số mẫu bằng kích thước đợt thử, nếu tỷ lệ lỗi vượt ngưỡng (mặc định 30%), không thiết bị mới nào được bắt đầu. Các thiết bị chưa chạy được đánh dấu bỏ qua và không bị thay đổi cấu hình.
+ Ba tham số trên được chỉnh trong *Settings* hoặc qua biến môi trường; giá trị mặc định không phải giới hạn cố định của mọi môi trường.

Ngưỡng dừng chỉ áp dụng cho bước gửi lệnh. Các thiết bị đã gửi thành công vẫn đi tiếp qua bước đối chiếu sau triển khai gồm bốn giai đoạn: lưu `running-config` thành `startup-config`, thu lại `running-config`, ghi bản sao lưu và đồng bộ cơ sở dữ liệu theo trạng thái thiết bị. Mỗi giai đoạn có mã lỗi riêng (`save`, `collect`, `backup`, `sync`). Nhờ đó giao diện phân biệt được trường hợp lệnh đã được thiết bị nhận nhưng bước lưu hoặc đồng bộ sau đó thất bại, thay vì gộp tất cả thành "thất bại".


== Luồng giám sát và khai thác cảnh báo

Giám sát có hai luồng: thu thập trạng thái bằng lệnh truy vấn và tiếp nhận Syslog do thiết bị gửi. Luồng Syslog gồm cấu hình địa chỉ đích trên thiết bị, khởi động bộ thu nhận tại CAMS, phân tích và lưu bản tin vào cơ sở dữ liệu, sau đó hiển thị kết quả trên giao diện.

Mỗi bản tin cần lưu nguồn gửi, thời gian nhận, mức độ nghiêm trọng, mã sự kiện nếu phân tích được và nội dung gốc. Giao diện hỗ trợ lọc theo thiết bị, thời gian, mức độ và từ khóa, qua đó giúp người quản trị khoanh vùng các sự kiện như thay đổi kết nối hoặc vi phạm chính sách. Khi đồng hồ trên thiết bị chưa được đồng bộ, hệ thống phải phân biệt thời gian do thiết bị ghi với thời gian CAMS nhận bản tin.

@fig-syslog-sequence mô tả luồng tiếp nhận ở tiến trình C++, lưu dữ liệu vào SQLite và thông báo sang Python bằng JSON Lines. Bộ phân tích giữ riêng nhóm nguồn Syslog từ PRI và mã phân hệ Cisco. Sau khi lưu trữ, bộ phát hiện theo ngưỡng cùng hai dịch vụ cảnh báo qua thư điện tử và Telegram xử lý các bản tin đáp ứng điều kiện; giao diện truy vấn dữ liệu qua bộ lọc.

#figure(
  image("/00_book/figures/report/diagrams/review-syslog-sequence.svg", width: 100%),
  caption: [Sơ đồ tuần tự thu nhận, lưu trữ và khai thác Syslog],
) <fig-syslog-sequence>

=== Phát hiện mẫu sự kiện theo ngưỡng

Bộ phát hiện `SecurityEventDetector` đếm các bản tin cùng loại theo khóa nguồn (địa chỉ, cổng hoặc địa chỉ MAC) trong một cửa sổ thời gian trượt. Khi số bản tin hoặc số gói được nêu trong bản tin đạt ngưỡng, bộ phát hiện tạo một cảnh báo `%CAMS-...` và tạm ngừng cảnh báo lặp cho cùng khóa trong thời gian chờ mặc định 300 giây. Sáu quy tắc mặc định được liệt kê tại @tab-security-detectors.

#report-table(
  columns: (27%, 13%, 25%, 35%),
  header: ([Quy tắc], [Cửa sổ], [Ngưỡng], [Nguồn sự kiện]),
  rows: (
    ([#table-code("ICMP_FLOOD")], [10 giây], [1 bản tin], [Chính sách EEM trên thiết bị đã đếm lưu lượng ICMP và phát bản tin #table-code("HA_EM", size: 8.5pt).]),
    ([#table-code("ACL_DROP_FLOOD")], [60 giây], [10 bản tin hoặc 100 gói], [Bản tin ACL từ chối từ cùng một nguồn.]),
    ([#table-code("DHCP_ROGUE_SERVER")], [60 giây], [3 bản tin], [DHCPOFFER, DHCPACK hoặc DHCPNAK nhận trên cổng không tin cậy.]),
    ([#table-code("DHCP_SNOOPING_FLOOD")], [60 giây], [10 bản tin], [Các lần DHCP Snooping loại bỏ gói từ cùng một nguồn.]),
    ([#table-code("DAI_ARP_SPOOF")], [60 giây], [5 bản tin hoặc 5 gói], [Bản tin ARP không hợp lệ do DAI ghi nhận.]),
    ([#table-code("PORT_SECURITY_REPEAT")], [60 giây], [3 bản tin], [Vi phạm Port Security lặp lại trên cùng một cổng.]),
  ),
  text-size: 9.5pt,
  caption: [Quy tắc phát hiện mặc định của bộ giám sát an ninh],
) <tab-security-detectors>

Cảnh báo của bộ phát hiện là dấu hiệu cần điều tra, không phải kết luận chắc chắn có tấn công. Thiết bị Cisco IOS có thể gộp hoặc giới hạn tốc độ phát bản tin, nên số bản tin không tương ứng một–một với số gói. Bộ phát hiện chỉ dùng Syslog; hệ thống không phân tích lưu lượng nên không phải một hệ thống phát hiện xâm nhập hoàn chỉnh.

== Luồng tự động hóa phản ứng theo sự kiện

Bộ tự động hóa nối kết quả của bộ phát hiện với hành động trên thiết bị. Thiết kế tách ba trách nhiệm cho ba thành phần như @fig-automation-flow:

- *Python (CAMS):* chuyển cảnh báo thành sự kiện trong bảng hàng đợi `t13_automation_events`, giữ phiên SSH, thông tin xác thực và cơ sở dữ liệu, thực thi hành động và ghi kết quả vào `t13_automation_actions`.
- *Tiến trình Go (`cams-automation`):* đọc các tệp quy tắc `.rule.cams` đang bật, đối chiếu sự kiện với điều kiện, kiểm tra thời gian chờ và giới hạn số hành động mỗi giờ, rồi trả về danh sách hành động có kiểu xác định. Tiến trình này không nhận mật khẩu và không tự mở kết nối tới thiết bị; khi khởi chạy, CAMS loại bỏ biến môi trường chứa khóa phiên.
- *Thiết bị mạng:* nhận lệnh qua phiên SSH mà người dùng đã mở trong CAMS. Nếu không có phiên đang hoạt động, hành động được ghi là thất bại; hệ thống không tự mở phiên mới hay chuyển sang giao thức khác.

#figure(
  kind: image,
  {
    set text(size: 8.5pt)
    show raw: set text(size: 7.5pt)
    let node(body, fill) = block(
      width: 100%, inset: 6pt, radius: 3pt, fill: fill,
      stroke: 0.6pt + rgb("#5a6b7d"), align(center, body),
    )
    let py = rgb("#e3eef9")
    let go = rgb("#e4f4e4")
    let cpp = rgb("#fbeede")
    grid(
      columns: (1fr, 14pt, 1fr, 14pt, 1fr),
      row-gutter: 6pt,
      align: center + horizon,
      node([*Bộ thu Syslog (C++)* \ lưu `t12_syslog_messages`], cpp), [→],
      node([*Bộ phát hiện (Python)* \ cảnh báo theo ngưỡng], py), [→],
      node([*Hàng đợi sự kiện* \ `t13_automation_events`], py),
      [], [], [], [], [↓],
      node([*Bộ thực thi (Python)* \ phiên SSH đang mở, lệnh xác minh, ghi `verified` hoặc `failed`], py), [←],
      node([*Hành động chờ* \ `t13_automation_actions` trạng thái `ready`], py), [←],
      node([*Bộ lập kế hoạch (Go)* \ đối chiếu quy tắc, thời gian chờ, giới hạn mỗi giờ], go),
    )
  },
  caption: [Luồng tự động hóa phản ứng theo sự kiện (màu cam: tiến trình C++, xanh lam: Python, xanh lục: Go)],
) <fig-automation-flow>

Python và Go trao đổi qua đầu vào và đầu ra chuẩn bằng các thông điệp JSON Lines có số phiên bản giao thức và mã yêu cầu. Mỗi chu kỳ, CAMS gửi tối đa 100 sự kiện chờ xử lý; tiến trình Go trả về hành động mới, danh sách sự kiện đã xử lý và lỗi của từng tệp quy tắc nếu có. Sau đó bộ thực thi nhận tối đa 10 hành động ở trạng thái `ready`, giữ quyền xử lý bằng một hợp đồng thuê (lease) lưu trong SQLite rồi chuyển hành động qua các trạng thái `claimed`, `applying` và kết thúc ở `verified`, `noop_verified` hoặc `failed`. Nếu hợp đồng thuê hết hạn giữa chừng, hành động đổi trạng thái giao diện cổng được trả về `ready` vì có thể lặp lại an toàn; chuỗi lệnh CLI được chuyển sang `failed` thay vì tự gửi lại.

Lược đồ bảng hành động đã có sẵn các trạng thái chờ phê duyệt và hoàn tác theo thời gian (`pending_approval`, `revert_due`, `reverted`). Bộ kiểm tra quy tắc hiện chỉ chấp nhận hai chế độ `dry-run` và `auto`, đồng thời buộc trường `ttl_seconds` bằng 0 với hành động tự động. Do đó quy trình phê duyệt và tự hoàn tác chưa hoạt động; các trạng thái trên chỉ là phần chuẩn bị của lược đồ.


== Thiết kế cơ chế an ninh phân quyền và bảo mật dữ liệu

CAMS kiểm soát quyền thực thi trên thiết bị và bảo vệ dữ liệu xác thực khi lưu trữ. Hai cơ chế này có phạm vi khác nhau: quyền thiết bị do Cisco IOS quyết định, còn mã hóa cục bộ phụ thuộc vào khóa của phiên dự án.

=== Kiểm tra đặc quyền và xử lý lỗi xác thực
CAMS lựa chọn mức đặc quyền 15 cho các luồng quản trị Cisco IOS hiện có. Đây là chính sách của ứng dụng, không phải yêu cầu mọi lệnh Cisco IOS đều cần mức 15. Quy trình kiểm tra gồm:
- *Bước 1 – nhận diện dấu nhắc:* CAMS nhận diện dấu nhắc lệnh ban đầu của thiết bị để xác định sơ bộ chế độ thực thi người dùng (User EXEC) hoặc chế độ thực thi đặc quyền (Privileged EXEC).
- *Bước 2:* Với thiết bị Cisco, gửi `show privilege` để đọc mức quyền. Khi xác định mức quyền dưới 15, ứng dụng gọi `enable` hoặc `enable 15` với mật khẩu đặc quyền rồi kiểm tra lại. Nếu trường Enable Secret bỏ trống, CAMS dùng mật khẩu đăng nhập làm giá trị thử; chỉ khi cả hai đều trống thì quy trình dừng với lỗi thiếu mật khẩu đặc quyền. Nhánh xác minh sau nâng quyền từ chối khi không xác nhận được mức quyền yêu cầu.

Mã nguồn hiện vẫn có nhánh dự phòng chấp nhận dấu nhắc `#` khi lần kiểm tra ban đầu không đọc được mức quyền. Vì dấu nhắc này cũng có thể xuất hiện ở mức quyền trung gian, chưa thể mô tả toàn bộ cơ chế là từ chối khi chưa xác minh trong mọi tình huống. Đây là giới hạn cần kiểm thử và hoàn thiện.

=== Vòng đời khóa phiên Argon2id và mã hóa AES-256-GCM (ENC\$v2\$)
Để hạn chế nguy cơ dò mật khẩu ngoại tuyến và hoán đổi bản mã, CAMS áp dụng cơ chế mã hóa có xác thực:
- Khi dự án có mật khẩu, khóa mã hóa dữ liệu (Data Encryption Key – DEK) được dẫn xuất bằng Argon2id với 64 MiB bộ nhớ, ba lượt và bốn làn song song @rfc9106. Muối (salt) của khóa này là 16 byte đầu của giá trị băm SHA-256 tính từ mã dự án, nên cố định theo dự án chứ không sinh ngẫu nhiên như muối của mã hóa toàn gói `.ntp`.
- Các trường mật khẩu được mã hóa bằng AES-256-GCM và lưu theo định dạng nội bộ `ENC$v2$`. Đây là phiên bản phong bì dữ liệu của CAMS, không phải tên một tiêu chuẩn mật mã @nistSp80038d.
- Dữ liệu xác thực bổ sung (Additional Authenticated Data – AAD) chứa ngữ cảnh `host:column`. Với bản ghi phiên bản 2 và đúng ngữ cảnh, việc đổi bản mã sang thiết bị hoặc cột khác làm xác minh thẻ thất bại (`InvalidTag`).
- Khóa do đối tượng mã hóa quản lý được giữ trong mảng byte để ghi đè khi hủy. Cơ chế này không xóa được mọi bản sao do môi trường chạy tạo ra. Dự án không có mật khẩu sử dụng khóa dẫn xuất từ dữ liệu cục bộ, nên không có cùng mức bảo vệ với khóa dựa trên bí mật người dùng.
- Để tiến trình con (như đầu cuối ngoài) giải mã được dữ liệu, khóa phiên được chuyển qua biến môi trường `CAMS_CREDENTIAL_KEY` và tệp tạm `.credential_key` trong thư mục làm việc với quyền `0600`. Khóa vì vậy không chỉ nằm trong bộ nhớ của tiến trình chính. Tệp tạm được dọn cùng thư mục làm việc khi dự án đóng bình thường; cơ chế này không bảo đảm xóa tệp khi ứng dụng dừng đột ngột. Riêng tiến trình tự động hóa viết bằng Go được khởi chạy với môi trường đã loại bỏ biến chứa khóa.
- Để tương thích dữ liệu cũ, bộ giải mã thử thêm các khóa thế hệ trước (`ENC$v1$`, Argon2id 32 MiB) và chuyển khóa giải mã thành công lên làm khóa chính của phiên. Bước chuyển đổi định dạng chỉ quét hai cột mật khẩu trong bảng `t01_devices`; khi giải mã lỗi, tầng truy xuất trả lại giá trị gốc thay vì dừng thao tác.

#report-table(
  columns: (22%, 35%, 43%),
  header: ([Tính năng], [Công nghệ và thuật toán], [Cơ chế hoạt động]),
  rows: (
    ([Kiểm tra đặc quyền], [Phân tích mức quyền, Netmiko `enable`], [Đọc mức quyền, nâng quyền khi cần và kiểm tra lại; còn nhánh dự phòng dấu nhắc ở lần kiểm tra ban đầu.]),
    ([Mã hóa dữ liệu lưu trữ (`ENC$v2$`)], [Argon2id (RFC 9106), AES-256-GCM], [Lưu bản mã theo cấu trúc `ENC$v2$...`; liên kết AAD với ngữ cảnh bản ghi để chống tráo đổi; ghi đè mảng byte khi hủy khóa.]),
    ([Nhật ký ACL], [Jinja2, cơ chế ghi nhật ký Cisco IOS], [Sinh tùy chọn ghi nhật ký cho các quy tắc hỗ trợ; thiết bị phải có đích Syslog và ngưỡng gửi phù hợp.]),
  ),
  caption: [Bảng tham chiếu kiến trúc an ninh, phân quyền và giám sát hệ thống],
) <tab-security-architecture>
#pagebreak(weak: true)
== Thiết kế cơ sở dữ liệu

CAMS sử dụng hai cơ sở dữ liệu SQLite. Tệp `device_network.db` lưu danh mục thiết bị, cấu hình cổng mạng, DHCP, định tuyến, ACL, NAT, chuyển mạch và các đích Syslog cần cấu hình; tệp `info_collected.db` lưu dữ liệu quan sát như bảng định tuyến, bảng liên kết DHCP, thống kê ACL, phiên NAT, bản tin Syslog đã nhận, cùng hàng đợi sự kiện và trạng thái hành động của bộ tự động hóa. Cách tách này giúp dữ liệu cấu hình không bị trộn với dữ liệu thu thập trong quá trình vận hành.

Các bảng liên kết bằng khóa chính, khóa ngoại và mã thiết bị. Tầng nghiệp vụ kiểm tra địa chỉ, dải giá trị và quan hệ phụ thuộc trước khi ghi dữ liệu. Bản ghi trong luồng View \& Push có trạng thái chờ áp dụng, đã đồng bộ hoặc chờ xóa; các trạng thái này phục vụ sinh lệnh và theo dõi tiến trình, không thay thế việc đồng bộ lại từ thiết bị.

Đối chiếu các khai báo `CREATE TABLE` trong mã nguồn SQL hiện tại ghi nhận 74 tên bảng trong nhóm `device_network` và 21 tên bảng trong nhóm `info_collected`, tổng cộng 95 tên bảng. Hai bảng `t13_automation_events` và `t13_automation_actions` lưu sự kiện chờ xử lý và trạng thái hành động của bộ tự động hóa. Đây là số đếm của lược đồ nguồn, không khẳng định mọi không gian làm việc đang chạy đều có đúng 95 bảng.

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

== Thiết kế giao diện và xử lý lỗi

Giao diện gồm khu vực danh mục thiết bị, thẻ làm việc, vùng chức năng và thanh trạng thái. Các biểu mẫu dùng chung cách nhập, lưu và xem trước thay đổi. *System Logs* cung cấp không gian đọc nhật ký tập trung; các tiện ích SFTP và đầu cuối được mở theo nhu cầu. Hình minh họa giao diện được trình bày tại Chương 4 để gắn thiết kế với phần hiện thực.

Cơ chế khóa theo thiết bị (`Host Lock`) bảo vệ truy cập phiên dùng chung; bộ thực thi theo lô (`BatchExecutor`) điều phối tác vụ giữa các thiết bị. Mỗi lỗi cần gắn với thiết bị và thao tác gây lỗi. Hủy tác vụ hoặc hết thời gian chờ không đồng nghĩa hoàn tác lệnh đã gửi; sau sự cố cần đồng bộ lại để xác định phần cấu hình thực tế đã thay đổi.

// == Tiểu kết chương

// Thiết kế CAMS liên kết ba luồng: quản lý trạng thái, thực thi có kiểm duyệt và giám sát kết quả. Dữ liệu chờ được tách khỏi trạng thái quan sát; tác vụ mạng chạy ngoài luồng giao diện; phản hồi được lưu theo thiết bị để hỗ trợ truy vết.

// Chương 4 trình bày phần hiện thực trong mã nguồn và giao diện; Chương 5 kiểm tra bằng cấu hình, lệnh xác minh, lưu lượng thử và bản tin nhật ký. Các sơ đồ không thay thế bằng chứng vận hành.
