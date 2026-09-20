#pagebreak(weak: true)
#import "../config/tables.typ": report-table

= Cơ sở lý thuyết và công nghệ nền tảng

== Quản lý tập trung và tự động hóa cấu hình

Quản lý tập trung hợp nhất danh mục thiết bị, thông số kết nối, dữ liệu cấu hình và lịch sử vận hành tại một điểm quản trị. Người dùng có thể tra cứu và thực hiện tác vụ trên nhiều thiết bị theo một quy trình thống nhất. Trong CAMS, điểm quản trị là ứng dụng desktop và không gian làm việc cục bộ; khái niệm tập trung ở đây không đồng nghĩa với kiến trúc máy chủ phục vụ đồng thời nhiều người dùng.

Tự động hóa cấu hình chuyển các thao tác lặp lại thành chuỗi xử lý phần mềm: nhận tham số, kiểm tra dữ liệu, sinh lệnh, kết nối, triển khai và ghi nhận kết quả. Việc phê duyệt thay đổi vẫn thuộc về người quản trị. Cách tiếp cận này giúp thống nhất cú pháp, nhưng một mẫu lệnh sai cũng có thể ảnh hưởng nhiều thiết bị, nên bước xem trước và theo dõi lỗi theo từng thiết bị là cần thiết.

Mô hình quản lý theo trạng thái phân biệt *trạng thái mong muốn* (Desired State), do người dùng thiết lập, với *trạng thái quan sát* (Observed State), được thu thập từ thiết bị tại một thời điểm. Dữ liệu mới lưu trong ứng dụng chưa chứng minh thiết bị đã thay đổi. CAMS sử dụng luồng View & Push để chuyển cấu hình chờ thành lệnh, cho phép kiểm duyệt trước khi thực thi và cập nhật kết quả sau khi nhận phản hồi.

Lưu bản sao cấu hình giúp truy vết thay đổi và so sánh phiên bản. Khôi phục dữ liệu dự án hoặc xem một bản cấu hình cũ không tự động đưa thiết bị mạng về trạng thái cũ; khôi phục cấu hình thiết bị cần có thao tác triển khai và xác minh riêng.

== CLI và giao thức quản trị từ xa

CLI Cisco IOS tổ chức lệnh theo ngữ cảnh, chẳng hạn chế độ EXEC đặc quyền, cấu hình toàn cục và cấu hình giao diện. Công cụ tự động hóa cần nhận diện dấu nhắc, chuyển đúng chế độ và xử lý phản hồi. Dữ liệu từ các lệnh như `show running-config` hoặc `show ip route` thường là văn bản, cần được phân tích thành các trường có cấu trúc để lưu trữ và hiển thị.

SSH cung cấp kênh quản trị có mã hóa và cơ chế xác thực theo kiến trúc mô tả trong @rfc4251. Telnet truyền dữ liệu dạng rõ nên chỉ phù hợp với tình huống thử nghiệm được kiểm soát khi cần tương thích thiết bị. CAMS có thể hỗ trợ cả hai phương thức, nhưng ưu tiên SSH cho các tác vụ quản trị.

Phiên kết nối có thể được tái sử dụng để giảm số lần bắt tay và xác thực. Vì mỗi phiên CLI duy trì ngữ cảnh lệnh, các tác vụ dùng chung phiên cần được tuần tự hóa. Đồng thời, phần mềm phải xử lý phiên mất kết nối, hết thời gian chờ hoặc thiết bị trả lỗi thay vì suy ra thành công chỉ từ việc gửi được dữ liệu.

== Nghiệp vụ mạng phục vụ tự động hóa

=== Dịch vụ và định tuyến Lớp 3

Địa chỉ IPv4 và thông số giao diện là cơ sở để các thiết bị liên lạc. Ngoài cổng vật lý, các giao diện logic như Loopback, Subinterface, Tunnel và SVI phục vụ định danh, phân chia lưu lượng hoặc định tuyến giữa các mạng. Khi sinh cấu hình, cần kiểm tra địa chỉ, mặt nạ và mối liên hệ giữa giao diện với dịch vụ sử dụng nó.

DHCP cung cấp tham số IP cho máy trạm; chuỗi trao đổi cấp phát điển hình gồm Discover, Offer, Request và Acknowledge. DHCP Relay chuyển tiếp yêu cầu giữa các miền quảng bá. Các dữ liệu cần quản lý gồm mạng cấp phát, gateway, DNS, thời gian thuê và dải địa chỉ loại trừ @rfc2131.

Định tuyến tĩnh khai báo mạng đích và đường đi do người quản trị lựa chọn. OSPFv2 trao đổi thông tin trạng thái liên kết và tính đường đi theo chi phí; EIGRP sử dụng cơ chế định tuyến vector khoảng cách nâng cao. Các tham số mạng quảng bá, định danh tiến trình, vùng hoặc hệ tự trị cần được cấu hình nhất quán giữa các thiết bị tham gia @rfc2328 @rfc7868.

NAT thực hiện ánh xạ địa chỉ; PAT cho phép nhiều luồng dùng chung một địa chỉ thông qua thông tin cổng. Việc triển khai cần xác định đúng phía trong, phía ngoài và điều kiện áp dụng. NAT phục vụ chuyển đổi địa chỉ, không thay thế chính sách kiểm soát truy cập @rfc3022. Các giao thức dự phòng gateway như HSRP, VRRP và GLBP phục vụ duy trì đường ra cho mạng nội bộ khi gateway thay đổi trạng thái.

=== Chuyển mạch Lớp 2

VLAN phân chia miền quảng bá; cổng access phục vụ một VLAN dữ liệu, còn trunk mang lưu lượng của nhiều VLAN. EtherChannel kết hợp các liên kết vật lý thành một liên kết logic. STP giúp kiểm soát vòng lặp khi tồn tại các đường kết nối dự phòng; VTP hỗ trợ quản lý thông tin VLAN giữa các switch theo chế độ và phiên bản sử dụng.

Trong tự động hóa, các tham số này có quan hệ phụ thuộc. Ví dụ, VLAN cần tồn tại trước khi gán cổng, còn các cổng thành viên EtherChannel cần cấu hình tương thích. Vì vậy, mẫu lệnh phải xét cả thứ tự triển khai và điều kiện áp dụng trên từng loại thiết bị.

=== Chính sách kiểm soát truy cập và bảo vệ Lớp 2

ACL quyết định cho phép hoặc từ chối lưu lượng dựa trên các điều kiện và thứ tự quy tắc. Phần mềm cần giữ đúng thứ tự, hướng áp dụng và giao diện đích. Một ACL có cú pháp hợp lệ vẫn có thể chặn nhầm lưu lượng nếu đặt sai vị trí hoặc thiếu quy tắc cho phép cần thiết.

Port Security giới hạn địa chỉ MAC được sử dụng trên cổng. DHCP Snooping kiểm tra luồng DHCP theo vai trò cổng tin cậy; Dynamic ARP Inspection hỗ trợ kiểm tra bản tin ARP dựa trên dữ liệu liên kết hoặc chính sách được cấu hình. Hiệu quả của các cơ chế này phụ thuộc topology, dữ liệu kiểm tra và khả năng của thiết bị. CAMS cung cấp phương tiện cấu hình và theo dõi; việc thực thi chính sách diễn ra trên router hoặc switch.

== Giám sát tập trung và khai thác cảnh báo

Giám sát sử dụng hai nguồn dữ liệu bổ sung cho nhau: trạng thái lấy bằng lệnh truy vấn và sự kiện do thiết bị gửi về qua Syslog. Trạng thái phản ánh kết quả tại thời điểm thu thập, trong khi nhật ký ghi nhận diễn biến như thay đổi giao diện, thay đổi cấu hình hoặc vi phạm chính sách. Cả hai cần được gắn với thiết bị nguồn và thời điểm để phục vụ đối chiếu.

Một luồng Syslog tập trung gồm thiết bị phát log, bộ nhận, bộ phân tích, nơi lưu trữ và giao diện truy vấn. CAMS giữ các trường đã phân tích và bản tin gốc để có thể kiểm tra lại khi dữ liệu thiếu hoặc không đúng định dạng. Địa chỉ đích, cổng và giao thức trên thiết bị phải khớp cấu hình của bộ nhận.

Syslog sử dụng tám mức severity từ 0 đến 7; số nhỏ hơn biểu thị mức nghiêm trọng cao hơn. Tên mức lần lượt là Emergency, Alert, Critical, Error, Warning, Notice, Informational và Debug. Severity giúp sắp xếp ưu tiên xem xét, nhưng riêng mức độ này chưa đủ để kết luận có tấn công. Cần kết hợp nguồn, mã sự kiện, nội dung và bối cảnh vận hành.

Phát hiện vi phạm trên thiết bị, chuyển log về CAMS và hiển thị kết quả lọc là ba bước riêng biệt. Nếu thiết bị không phát sinh hoặc không gửi bản tin tương ứng, bộ nhận không thể suy ra đầy đủ sự kiện. Trong phạm vi đề tài, phân tích cảnh báo dựa trên nhật ký tập trung; tương quan nhiều sự kiện và gửi thông báo chủ động là các khả năng cần đánh giá riêng trước khi khẳng định đã hỗ trợ.

== Công nghệ lưu trữ và xây dựng giao diện

SQLite là cơ sở dữ liệu nhúng phù hợp với ứng dụng desktop: dữ liệu được lưu trong tệp và truy cập trực tiếp từ chương trình. CAMS tách dữ liệu cấu hình và dữ liệu thu thập thành hai cơ sở dữ liệu, sử dụng quan hệ giữa thiết bị với giao diện, dịch vụ và chính sách. Ràng buộc dữ liệu cần kết hợp với kiểm tra nghiệp vụ, vì đúng kiểu chuỗi chưa có nghĩa là đúng địa chỉ IP.

Các thao tác ghi cần giữ giao dịch ngắn để hạn chế tranh chấp. Với log, ghi theo lô giảm số lần ghi riêng lẻ; tuy nhiên, khả năng tiếp nhận vẫn phụ thuộc hàng đợi và tài nguyên. Giao dịch SQLite bảo vệ tính nhất quán dữ liệu cục bộ, không tạo ra giao dịch nguyên tử trên thiết bị mạng ở xa.

Qt Quick/QML mô tả giao diện theo thành phần và thuộc tính. PyQt6 kết nối giao diện với logic Python qua đối tượng `QObject`, các phương thức gọi và tín hiệu cập nhật. Giao diện tiếp nhận thao tác và trình bày kết quả; nghiệp vụ kiểm tra dữ liệu, truy cập cơ sở dữ liệu và kết nối mạng được xử lý ở các lớp phía sau.

== Thư viện và cơ chế thực thi

#report-table(
  columns: (29%, 71%),
  header: ([Thành phần], [Vai trò trong CAMS]),
  rows: (
    ([Netmiko, Paramiko], [Kết nối thiết bị qua SSH, xử lý phiên CLI và hỗ trợ truyền tệp.]),
    ([Jinja2], [Kết xuất dữ liệu đã kiểm tra thành mẫu lệnh Cisco IOS.]),
    ([Dulwich], [Lưu phiên bản cấu hình trong kho Git cục bộ, hỗ trợ lịch sử và so sánh.]),
    ([Argon2id, AES-256-GCM], [Dẫn xuất khóa từ mật khẩu và mã hóa có xác thực cho gói dự án khi bật bảo vệ.]),
  ),
  caption: [Các thành phần công nghệ phục vụ quy trình quản trị],
)

Tác vụ mạng được chuyển sang luồng nền để không giữ vòng lặp giao diện trong lúc chờ thiết bị. Cơ chế Host Lock tuần tự hóa các tác vụ cùng dùng một phiên thiết bị; bộ điều phối Batch Executor tổ chức thực thi trên nhiều thiết bị và ghi nhận kết quả riêng. Khóa trong ứng dụng không ngăn được một quản trị viên khác thay đổi thiết bị qua phiên bên ngoài, nên vẫn cần đồng bộ và kiểm tra trạng thái thực tế.

Các cơ sở trên dẫn tới thiết kế ở Chương 3: quản lý dữ liệu tập trung, xem trước thay đổi, kiểm soát truy cập phiên và khai thác nhật ký có nguồn gốc rõ ràng.
