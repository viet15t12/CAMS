#pagebreak(weak: true)
#import "../config/tables.typ": report-table

= Xây dựng phần mềm CAMS

Chương 3 đã xác định kiến trúc phân lớp, mô hình dữ liệu và các luồng quản lý cấu hình, giám sát cùng bảo vệ dữ liệu. Chương này trình bày cách các thiết kế đó được xây dựng thành những chức năng cụ thể trên CAMS. Trọng tâm là quy trình hoạt động, khả năng mà phần mềm cung cấp và cách người dùng tương tác với hệ thống; kết quả vận hành trên mô hình mạng được dành cho Chương 5.

Nội dung được sắp xếp theo chuỗi sử dụng của hệ thống: khởi tạo ứng dụng, quản lý thiết bị, tự động hóa cấu hình, thu thập dữ liệu, triển khai chính sách bảo mật và sử dụng các tiện ích hỗ trợ. Cách trình bày này giữ liên kết giữa yêu cầu ở Chương 3 với bằng chứng kiểm thử ở chương tiếp theo.

== Môi trường phát triển và tổ chức mã nguồn

CAMS được thiết kế và đóng gói dưới dạng phần mềm máy tính để bàn (desktop) để cài đặt và vận hành cục bộ trên máy tính người dùng. Phần mềm được phát triển chủ yếu bằng Python, sử dụng Qt Quick/QML và PyQt6 cho giao diện, SQLite để lưu trữ, Jinja2 để tạo lệnh, Netmiko/Paramiko để kết nối thiết bị và Dulwich để quản lý lịch sử cấu hình. Automation Engine được xây dựng bằng Go, còn bộ thu Syslog sử dụng C++ để hoạt động độc lập với giao diện. Sự kết hợp này đáp ứng ba nhu cầu chính của đề tài: tương tác trực quan, xử lý nghiệp vụ mạng và tiếp nhận dữ liệu vận hành.

Phần mềm được tổ chức thành các nhóm trách nhiệm gồm giao diện, xử lý nghiệp vụ, lưu trữ dữ liệu và giao tiếp với thiết bị. Mỗi nhóm chức năng như quản lý thiết bị, cấu hình, giám sát hay bảo vệ dự án sử dụng chung các dịch vụ nền tảng nhưng vẫn tách biệt về nghiệp vụ. Cấu trúc mã nguồn chi tiết được trình bày trong phụ lục; chương này tập trung vào các chức năng đã xây dựng.

== Khởi tạo và kết nối giao diện với nghiệp vụ

Khi khởi tạo, ứng dụng chuẩn bị cơ sở dữ liệu, không gian làm việc, các phiên kết nối và những dịch vụ hỗ trợ như SFTP, Syslog và Automation Engine. Sau đó, giao diện chính được liên kết với phần xử lý nghiệp vụ để người dùng có thể thao tác trên cùng một không gian làm việc.

Giao diện tiếp nhận thao tác và chuyển yêu cầu tới tầng nghiệp vụ. Dữ liệu được kiểm tra trước khi thực hiện; tiến trình và kết quả sau đó được trả về để cập nhật trạng thái hoặc hiển thị lỗi. Các thao tác mạng và lưu gói dự án được thực hiện ở chế độ nền để không làm gián đoạn giao diện. @fig-cams-workspace minh họa không gian làm việc sau khi quá trình khởi tạo hoàn tất.

#figure(
  image("/00_book/figures/gui/chapter-03/01-workspace-overview.png", width: 88%),
  caption: [Không gian làm việc tập trung của CAMS],
) <fig-cams-workspace>

== Hiện thực quản lý tập trung

=== Danh mục thiết bị và phiên kết nối

Giao diện *Inventory* lưu mã định danh, địa chỉ quản trị, tham số kết nối và vai trò bộ định tuyến, bộ chuyển mạch Lớp 2 hoặc bộ chuyển mạch Lớp 3. Người dùng có thể thêm từng thiết bị hoặc nhập danh sách từ JSON/Excel, tìm kiếm và chọn các thiết bị cần thao tác. Danh mục này liên kết phiên làm việc với dữ liệu cấu hình và thông tin thu thập của từng thiết bị.

Các phiên kết nối đang hoạt động được quản lý tập trung và có thể tái sử dụng cho nhiều thao tác liên tiếp. Hệ thống xử lý tuần tự những yêu cầu cùng truy cập một thiết bị, đồng thời cho phép thực hiện trên nhiều thiết bị độc lập và ghi nhận kết quả riêng cho từng thiết bị. Cách tổ chức này hạn chế lệnh bị đan xen trên cùng một phiên CLI và giúp xác định rõ thiết bị gặp lỗi trong tác vụ hàng loạt.

=== Đồng bộ và lịch sử cấu hình

Chức năng đồng bộ thu thập `running-config`, lưu bản sao, phân tích các phần được hỗ trợ rồi cập nhật cơ sở dữ liệu. Dulwich quản lý lịch sử các bản sao trong kho Git cục bộ. Người quản trị có thể xem từng phiên bản và phần khác biệt để truy vết thay đổi, như @fig-cams-config-diff.

#figure(
  image("/00_book/figures/gui/chapter-12/12-running-config-diff.png", width: 100%),
  caption: [So sánh hai phiên bản cấu hình đã lưu],
) <fig-cams-config-diff>

Lịch sử này cung cấp dữ liệu tham chiếu khi kiểm tra sự cố. Việc khôi phục cấu hình thiết bị vẫn cần lựa chọn nội dung phù hợp, triển khai và xác minh lại, thay vì chỉ mở phiên bản cũ trong ứng dụng.

== Hiện thực tự động hóa cấu hình và chính sách

=== Quy trình *View & Push* dùng chung

Các chức năng thực hiện cùng một quy trình: kiểm tra dữ liệu biểu mẫu, lưu cấu hình chờ, tạo lệnh theo mẫu và mở cửa sổ xem trước. Khi người dùng chọn *Push*, hệ thống gửi lệnh qua phiên thiết bị ở chế độ nền, xử lý phản hồi và cập nhật kết quả. Với nội dung chờ xóa, phần mềm tạo lệnh gỡ bỏ tương ứng.

#figure(
  image("/00_book/figures/gui/chapter-05/07-view-push-preview.png", width: 100%),
  caption: [Kiểm duyệt lệnh cấu hình cổng mạng trước khi triển khai],
) <fig-cams-view-push>

@fig-cams-view-push cho thấy bước kiểm duyệt nằm giữa thao tác lưu dữ liệu và triển khai lên thiết bị. Quy trình này được dùng chung cho các nhóm nghiệp vụ, giúp thống nhất thao tác và cách trình bày trạng thái. Khi thực thi gặp lỗi, người dùng cần xem phản hồi và đồng bộ lại trước khi quyết định gửi lại lệnh.

=== Quản lý cổng mạng, DHCP và định tuyến

Chức năng *Interfaces* quản lý địa chỉ IPv4, mô tả và trạng thái cổng; đồng thời hỗ trợ các cổng logic như Loopback, cổng con. Cổng vật lý được lấy từ thiết bị để chỉnh sửa thông số; các cổng logic được tạo hoặc gỡ theo nghiệp vụ tương ứng.

DHCP quản lý vùng cấp phát, dải địa chỉ loại trừ và tác nhân chuyển tiếp. Định tuyến cung cấp tuyến tĩnh, tuyến mặc định, OSPFv2 và EIGRP. Các nhóm biểu mẫu phản ánh quan hệ giữa tiến trình, mạng quảng bá và tham số cổng. Chức năng *Routing Group* hỗ trợ chuẩn bị cấu hình cho nhóm bộ định tuyến nhằm giảm thao tác nhập lặp; kết quả vẫn cần được kiểm tra trên từng thiết bị.

Các biểu mẫu FHRP hỗ trợ khai báo cổng mặc định dự phòng và tham số thành viên cho HSRP, VRRP, GLBP. Việc đánh giá chuyển đổi cổng mặc định thuộc kịch bản thử nghiệm, không được suy ra chỉ từ việc sinh đúng lệnh cấu hình.

=== ACL và NAT/PAT

Chức năng ACL cung cấp biểu mẫu cho ACL chuẩn, mở rộng, động, phản xạ và ACL theo địa chỉ MAC, tùy theo khả năng của thiết bị. Quy tắc được quản lý theo thứ tự, kèm cổng và chiều áp dụng.

Khi tạo lệnh ACL, CAMS bổ sung tùy chọn ghi nhật ký cho những quy tắc được hỗ trợ. Nhờ đó, khi lưu lượng khớp với danh sách kiểm soát, thiết bị có thể gửi sự kiện Syslog về CAMS mà người dùng không phải thêm tùy chọn này cho từng quy tắc. Sau khi triển khai, người quản trị vẫn phải kiểm tra thứ tự khớp luật và thử cả lưu lượng được phép lẫn lưu lượng bị chặn.

NAT/PAT quản lý ánh xạ tĩnh, vùng địa chỉ động, chế độ quá tải, vai trò phía trong hoặc phía ngoài của cổng và điều kiện chọn lưu lượng. Dữ liệu từ bảng chuyển đổi địa chỉ giúp đối chiếu cấu hình với các phiên thực tế. NAT là chức năng chuyển đổi địa chỉ, không thay thế cơ chế lọc truy cập.

=== Chuyển mạch và cập nhật chính sách Lớp 2

Chức năng chuyển mạch quản lý VLAN, cổng truy cập, đường trung kế, EtherChannel, STP và VTP. Trên bộ chuyển mạch Lớp 3, SVI và định tuyến liên VLAN được cấu hình theo vai trò thiết bị. Mẫu lệnh giữ quan hệ giữa VLAN, cổng vật lý và cổng logic, đồng thời dùng chung bước xem trước để người quản trị kiểm tra phạm vi tác động.

Port Security, DHCP Snooping và DAI được trình bày trong nhóm bảo mật ở phần sau. Các chính sách này cũng được triển khai qua *View & Push* để duy trì cùng cơ chế kiểm duyệt và ghi nhận kết quả.

== Hiện thực giám sát và thu thập nhật ký

Chức năng Syslog gồm hai phần: cấu hình đích gửi trên thiết bị và vận hành bộ nhận trong System Logs. Địa chỉ, cổng và giao thức hai phía phải khớp nhau. Cấu hình hiện tại dùng cổng 5514 theo mặc định và cho phép thay đổi theo môi trường.

Bộ thu nhận hoạt động độc lập với giao diện, tiếp nhận bản tin qua UDP/TCP, phân tích các trường Syslog và lưu vào cơ sở dữ liệu. Giao diện được cập nhật khi có dữ liệu mới nhưng không phải chờ quá trình tiếp nhận hoàn tất. Hệ thống lưu cả nội dung gốc và dữ liệu đã phân tích theo @rfc5424; đồng thời theo dõi số bản tin đã nhận và số bản tin bị loại bỏ để đánh giá khả năng tiếp nhận khi lưu lượng tăng.

#figure(
  image("/00_book/figures/gui/chapter-13/01-system-logs-overview.png", width: 100%),
  caption: [System Logs tập trung nhật ký từ thiết bị mạng],
) <fig-cams-system-logs>

Giao diện tại @fig-cams-system-logs hỗ trợ lọc theo thiết bị, mức độ nghiêm trọng, giao thức, khoảng thời gian và nội dung. Chức năng *Smart Filter* kết hợp điều kiện theo nhóm nguồn Syslog, mã sự kiện và từ khóa; cửa sổ chi tiết cho phép đối chiếu thời gian nhận với thời gian trên thiết bị và đọc bản tin gốc. Chức năng *Export Excel* xuất các dòng sau khi lọc để phục vụ phân tích.

Sau khi bản tin được lưu, hệ thống kiểm tra xem sự kiện có đáp ứng điều kiện gửi cảnh báo qua Email hoặc Telegram hay không. Người dùng có thể chọn mức độ nghiêm trọng, khoảng thời gian hạn chế gửi trùng và cách gom nhiều bản tin liên tiếp. Việc gửi cảnh báo được xử lý riêng với quá trình thu nhận, vì vậy thời gian kết nối tới dịch vụ bên ngoài không làm gián đoạn luồng nhật ký.

Màn hình *Email Alerts* cho phép khai báo máy chủ SMTP, tài khoản gửi, danh sách người nhận, mức Syslog cần cảnh báo và khoảng thời gian hạn chế gửi trùng. Nội dung thư được trình bày theo mức độ nghiêm trọng, kèm thông tin sự kiện và khuyến nghị xử lý. Thông tin xác thực được mã hóa khi lưu và chỉ hiển thị dưới dạng che khuất trên giao diện.

Màn hình *Telegram Alerts* cho phép bật dịch vụ, chọn mức Syslog, khai báo thông tin bot, đặt thời gian hạn chế gửi lặp và khoảng gom bản tin. Nội dung được rút gọn khi vượt giới hạn của Telegram nhưng vẫn giữ những thông tin chính phục vụ xử lý sự cố. Bot Token được mã hóa khi lưu và được che khỏi các thông báo lỗi hiển thị cho người dùng.

=== Phân tích sự kiện và phản ứng tự động bằng Automation Engine

Automation Engine là thành phần giúp CAMS chuyển từ giám sát thụ động sang phản ứng tự động trước các sự kiện an ninh. Từ nhật ký Syslog, hệ thống nhận biết những dấu hiệu cần chú ý như lưu lượng ICMP bất thường, số lần bị ACL từ chối tăng cao hoặc vi phạm DHCP Snooping, DAI và Port Security. Mỗi sự kiện được gắn với thiết bị và thông tin liên quan để phục vụ bước xử lý tiếp theo.

Khi có sự kiện mới, Automation Engine đối chiếu sự kiện đó với các quy tắc tự động hóa do người quản trị thiết lập. Nếu sự kiện đáp ứng điều kiện của một quy tắc, hệ thống xác định phản ứng phù hợp, tạo các lệnh cấu hình cần thiết và gửi tới đúng thiết bị thông qua kết nối đang hoạt động. Sau khi thực hiện, CAMS kiểm tra kết quả và lưu lại trạng thái xử lý để người quản trị theo dõi.

Nhờ cơ chế này, CAMS có thể thực hiện các phản ứng như cô lập cổng liên quan đến sự cố, bổ sung cấu hình hạn chế nguồn lưu lượng bất thường hoặc khôi phục cấu hình theo quy tắc đã định trước. Người quản trị có thể xem lại sự kiện, hành động đã thực hiện và kết quả kiểm tra trên cùng hệ thống. Các dữ liệu như thống kê ACL, bảng liên kết DHCP, bộ đếm cổng và bảng MAC cũng hỗ trợ đối chiếu trạng thái thiết bị sau khi phản ứng được áp dụng.

== Hiện thực chính sách bảo mật và liên kết sự kiện

Nhóm chức năng này kết hợp hai phần đã tách trong thiết kế: thiết bị mạng thực thi chính sách, còn CAMS chuẩn bị cấu hình và khai thác sự kiện do thiết bị phát sinh. Vì vậy, luồng triển khai tiếp tục sử dụng *View & Push* ở Mục 4.4, trong khi luồng quan sát sử dụng bộ thu Syslog ở Mục 4.5.

=== Triển khai chính sách trên thiết bị

CAMS cung cấp biểu mẫu Port Security để đặt giới hạn địa chỉ MAC, chế độ học và hành động khi vi phạm. Với DHCP Snooping và DAI, người dùng chọn VLAN áp dụng cùng cổng tin cậy theo mô hình mạng. Các thay đổi được lưu ở trạng thái chờ và kiểm duyệt trước khi gửi, như @fig-cams-l2-security.

#figure(
  image("/00_book/figures/gui/chapter-16/04-l2-security-view-push.png", width: 100%),
  caption: [Xem trước chính sách bảo vệ Lớp 2 trước khi áp dụng],
) <fig-cams-l2-security>

Thiết bị mạng thực thi chính sách và có thể phát sinh nhật ký tùy theo tính năng, chế độ cùng cấu hình ghi nhật ký. Vì vậy, việc kiểm chứng cảnh báo cần một tình huống phù hợp với cơ chế đã bật, đồng thời phải bảo đảm đường truyền nhật ký đến CAMS hoạt động.

=== Liên kết chính sách với sự kiện giám sát

Sau khi thiết bị áp dụng chính sách, System Logs cung cấp điểm đối chiếu sự kiện theo nguồn, mức độ nghiêm trọng, mã phân hệ và nội dung. @fig-cams-critical-log minh họa kết quả lọc các mức 0, 1, 2 và 3. Kết quả lọc chứng minh khả năng truy vấn nhật ký, nhưng không tự chứng minh phần mềm đã phát hiện một cuộc tấn công.

#figure(
  image("/00_book/figures/gui/chapter-13/05-critical-filter-result.png", width: 100%),
  caption: [Lọc các bản tin có mức độ nghiêm trọng từ 0 đến 3 trên System Logs],
) <fig-cams-critical-log>

Ngưỡng gửi trên thiết bị và bộ lọc hiển thị có ý nghĩa khác nhau: ngưỡng gửi thường bao gồm mức đã chọn cùng các mức nghiêm trọng hơn, còn bộ lọc trong CAMS chọn các mức cụ thể. Khi điều tra, người dùng cần đọc nội dung, nguồn và chuỗi thời gian thay vì kết luận chỉ dựa trên màu hoặc mức độ nghiêm trọng.

Trong phạm vi hiện tại, CAMS hỗ trợ khoanh vùng dấu hiệu bất thường qua nhật ký, đối chiếu chính sách và gửi cảnh báo thư điện tử. Hệ thống chưa có bộ tương quan sự kiện hoàn chỉnh, chưa phát hiện xâm nhập bằng phân tích gói tin và chưa hỗ trợ cảnh báo qua SMS.

== Hiện thực tiện ích vận hành và bảo vệ dữ liệu dự án

=== Truyền tệp và đầu cuối

Không gian truyền tệp gồm hai vùng cục bộ và từ xa, danh sách kết nối đã lưu, hàng đợi truyền và nhật ký thao tác. CAMS hỗ trợ cả SFTP và giao thức sao chép an toàn (Secure Copy Protocol – SCP); quá trình truyền chạy ở chế độ nền để giao diện tiếp tục phản hồi. Khi kết nối đến máy chủ chưa được nhận diện, ứng dụng hiển thị loại khóa và dấu vân tay để người dùng xác nhận trước khi ghi nhớ máy chủ đó.

Đầu cuối tích hợp phục vụ chẩn đoán hoặc thao tác CLI trực tiếp ngay trong không gian làm việc của CAMS. Những thay đổi thực hiện tại đây không đi qua dữ liệu chờ và cửa sổ *View & Push*; vì vậy, người quản trị cần đồng bộ lại sau khi cấu hình thủ công để dữ liệu trong ứng dụng phản ánh đúng trạng thái mới của thiết bị.

=== Đóng gói không gian làm việc và điểm khôi phục

Chức năng quản lý không gian làm việc hỗ trợ tạo, mở, lưu và đóng dự án. Gói `.ntp` tập hợp thông tin mô tả, dữ liệu cấu hình, dữ liệu quan sát, các bản sao cấu hình và những điểm khôi phục cần thiết. Số điểm khôi phục tự động được giới hạn theo chính sách lưu giữ để tránh làm kích thước gói tăng không kiểm soát.

Khi khôi phục, hệ thống kiểm tra điểm đã chọn, tạo bản sao an toàn của trạng thái hiện tại rồi phục hồi dữ liệu dự án. Thao tác này chỉ tác động đến không gian làm việc và không tự gửi lệnh hoàn tác xuống thiết bị. Phần mở rộng `.ntp` là định dạng dự án của CAMS, không liên quan đến giao thức đồng bộ thời gian NTP.

=== Bảo vệ thông tin xác thực

CAMS mã hóa mật khẩu thiết bị bằng AES-256-GCM và liên kết dữ liệu mã hóa với đúng thiết bị, đúng mục đích sử dụng. Khi dự án có mật khẩu, khóa bảo vệ được dẫn xuất bằng Argon2id; nếu không, hệ thống sử dụng khóa cục bộ với mức bảo vệ thấp hơn @rfc9106 @nistSp80038d.

Mật khẩu dùng cho dịch vụ thư điện tử cũng được bảo vệ theo cùng nguyên tắc. Cơ chế này giúp hạn chế việc đọc trực tiếp các trường nhạy cảm trong tệp dữ liệu, nhưng khác với mã hóa toàn bộ gói dự án được trình bày ở mục tiếp theo.

=== Bảo vệ toàn bộ gói dự án

Khi người dùng đặt mật khẩu dự án, toàn bộ nội dung gói `.ntp` được mã hóa bằng AES-256-GCM với khóa dẫn xuất từ mật khẩu bằng Argon2id. Hệ thống lưu kèm thông tin cần thiết để nhận diện định dạng và kiểm tra tính toàn vẹn khi mở gói, nhưng không lưu trực tiếp mật khẩu hoặc khóa đã tạo. Dự án không có mật khẩu vẫn được đóng gói, song toàn bộ gói không được mã hóa.

#figure(
  image("/00_book/figures/report/misc/xxd-ntp.png", width: 100%),
  caption: [Phần đầu tệp dự án được bảo vệ, quan sát bằng công cụ xxd],
) <fig-cams-encrypted-project>

@fig-cams-encrypted-project minh họa phần nhận diện của một gói dự án đã được bảo vệ. Hình này cho thấy định dạng lưu trữ đã được tạo, nhưng chưa thay thế cho các phép thử mở gói bằng mật khẩu đúng, từ chối mật khẩu sai hoặc phát hiện nội dung bị sửa. Các cơ chế này chưa có kịch bản kiểm thử riêng trong Chương 5.
#pagebreak(weak: true)
== Website hướng dẫn sử dụng

Nhóm xây dựng website hướng dẫn sử dụng CAMS để người dùng tra cứu theo từng chức năng, tìm kiếm nội dung và mở nhanh các phần liên quan trong quá trình thực hành. Nội dung website gồm các phần cài đặt, điều hướng, quản lý thiết bị, cấu hình Router, cấu hình Switch và các công cụ vận hành.

#grid(
  columns: (1fr, 38mm),
  gutter: 8mm,
  align: top,
  [
    #set par(justify: false)
    *Tài liệu hướng dẫn sử dụng:*

    #link("https://viet15t12.github.io/CAMS/")[#raw("https://viet15t12.github.io/CAMS/")]

    *Kho mã nguồn CAMS:*

    #link("https://github.com/viet15t12/CAMS.git")[#raw("https://github.com/viet15t12/CAMS.git")]

    Người đọc có thể mở trực tiếp các đường dẫn hoặc quét mã QR trong @fig-cams-online-manual. Vì nội dung trực tuyến có thể được cập nhật sau khi báo cáo được in, ngày truy cập và phiên bản phần mềm vẫn cần được ghi nhận khi dùng tài liệu làm căn cứ đối chiếu.
  ],
  [
    #set text(size: 9pt)
    #figure(
      image("/00_report/figures/qr-tai-lieu-huong-dan-cams.svg", width: 28mm),
      caption: [Tài liệu hướng dẫn CAMS trực tuyến],
    ) <fig-cams-online-manual>
  ],
)
