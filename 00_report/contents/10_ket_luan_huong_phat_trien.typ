#import "../config/tables.typ": report-table

#pagebreak(weak: true)
= Kết luận và hướng phát triển

== Kết quả đạt được

Đề tài đã xây dựng CAMS theo định hướng quản lý tập trung, tự động hóa cấu hình và giám sát thiết bị mạng trong môi trường thực hành. Hệ thống không chỉ cung cấp các biểu mẫu cấu hình, mà còn tổ chức một quy trình thống nhất từ khai báo thiết bị, chuẩn bị và kiểm duyệt lệnh, triển khai cấu hình, thu thập trạng thái đến tiếp nhận nhật ký và phản ứng trước sự kiện an ninh.

Kết quả thực nghiệm ở Chương 5 cho thấy các thành phần chính có thể phối hợp trong một bài thực hành tích hợp. CAMS đã triển khai cấu hình trên nhiều thiết bị, thu nhận các bản tin phát sinh, chuyển cảnh báo ra ngoài ứng dụng và thực hiện phản ứng tự động theo quy tắc. Mức độ đạt được của từng nhóm mục tiêu được tổng hợp tại @tab-project-results-summary.

#report-table(
  columns: (22%, 43%, 35%),
  header: ([Nhóm kết quả], [Kết quả chính], [Phạm vi đã kiểm chứng]),
  rows: (
    ([Quản lý tập trung], [Quản lý danh mục, phiên kết nối, không gian làm việc, đồng bộ và lịch sử cấu hình trên cùng ứng dụng.], [Đã sử dụng xuyên suốt bài thực hành; chưa đánh giá môi trường nhiều người dùng hoặc quy mô lớn.]),
    ([Tự động hóa cấu hình], [Kiểm tra dữ liệu, tạo lệnh theo mẫu, xem trước thay đổi và ghi nhận kết quả riêng cho từng thiết bị.], [Đã xác nhận OSPF trên R1–R4, HSRP trên R3/R4 và VTP trên SW5/SW6; chưa kiểm thử toàn bộ chức năng mà phần mềm hỗ trợ.]),
    ([Giám sát và cảnh báo], [Thu nhận, lưu trữ, lọc và xuất Syslog; chuyển cảnh báo qua Email và Telegram.], [Đã quan sát được nhật ký và cảnh báo có đủ nguồn, thời gian, mức độ và nội dung; chưa đo tải hoặc độ trễ giao tin.]),
    ([Phản ứng tự động], [Chuyển nhật ký thành sự kiện an ninh, đối chiếu quy tắc và thực hiện hành động trên thiết bị.], [Kịch bản ICMP flood đã tạo sự kiện và cô lập cổng con của R4; kết quả chỉ đại diện cho môi trường thử nghiệm có kiểm soát.]),
    ([Hỗ trợ vận hành và bảo vệ dữ liệu], [Cung cấp truyền tệp, đầu cuối tích hợp, lịch sử cấu hình, gói dự án và cơ chế bảo vệ thông tin xác thực.], [Các chức năng đã được trình bày và sử dụng ở mức cần thiết; chưa có bộ thử chuyên biệt về an toàn mật mã, phục hồi và truyền tệp.]),
    ([Tài liệu hướng dẫn], [Xây dựng website tra cứu quy trình sử dụng theo từng nhóm chức năng.], [Đường dẫn và mã QR được tích hợp trong báo cáo để hỗ trợ học tập và thực hành.]),
  ),
  text-size: 9.5pt,
  cell-inset: (x: 5pt, y: 6pt),
  caption: [Kết quả của đề tài và phạm vi kiểm chứng tương ứng],
) <tab-project-results-summary>

Nhìn chung, đề tài đã hoàn thành mục tiêu xây dựng một công cụ tích hợp cho quản lý, cấu hình và giám sát mạng trong phòng thực hành. Tuy nhiên, kết quả hiện tại chủ yếu chứng minh tính khả thi và sự liên kết giữa các chức năng; chưa đủ dữ liệu để kết luận về hiệu năng, độ ổn định dài hạn hoặc khả năng triển khai ở quy mô doanh nghiệp.

== Ý nghĩa khoa học và thực tiễn

=== Ý nghĩa khoa học

Đề tài góp phần minh họa cách áp dụng mô hình quản lý cấu hình theo trạng thái vào một hệ thống quản trị mạng cục bộ. Cấu hình dự kiến, trạng thái quan sát và kết quả thực thi được phân biệt rõ, nhờ đó việc lưu dữ liệu không bị đồng nhất với việc thiết bị đã thay đổi thành công. Quy trình xem trước và xác minh cũng cho thấy vai trò của con người vẫn cần được duy trì trong tự động hóa mạng.

Một kết quả khác là mô hình liên kết giữa cấu hình, giám sát và phản ứng. Thay đổi trên thiết bị tạo ra dữ liệu vận hành; dữ liệu này được thu thập, phân tích thành sự kiện, sau đó có thể kích hoạt cảnh báo hoặc hành động theo quy tắc. Bài thực hành tích hợp cung cấp một cách kiểm chứng theo chuỗi thay vì đánh giá từng chức năng hoàn toàn tách rời.

Đóng góp của đề tài nằm ở việc tích hợp và kiểm chứng quy trình trong phạm vi phòng thực hành, không phải đề xuất một thuật toán định tuyến, giao thức bảo mật hoặc phương pháp phát hiện xâm nhập mới. Cách xác định phạm vi này giúp các kết luận phù hợp với bằng chứng đã thu thập.

=== Ý nghĩa thực tiễn

CAMS hỗ trợ người học và người quản trị phòng thực hành chuẩn bị cấu hình cho nhiều thiết bị theo một quy trình thống nhất. Người dùng có thể kiểm tra lệnh trước khi triển khai, theo dõi kết quả theo từng thiết bị và đối chiếu thay đổi bằng lịch sử cấu hình. Điều này giúp giảm thao tác nhập lặp lại và tạo thói quen kiểm duyệt thay đổi trước khi thực hiện.

Việc tập trung Syslog, Email, Telegram và phản ứng theo quy tắc trên cùng không gian làm việc giúp người dùng quan sát mối liên hệ giữa cấu hình với trạng thái vận hành. Gói dự án và website hướng dẫn cũng hỗ trợ lưu trữ, chia sẻ và tái sử dụng bài thực hành. Đây là cơ sở để CAMS tiếp tục được hoàn thiện thành công cụ hỗ trợ đào tạo và thử nghiệm tự động hóa mạng.

== Hạn chế của đề tài

Các kết quả đạt được cần được xem xét trong những giới hạn sau:

+ *Phạm vi thiết bị và môi trường:* CAMS hiện tập trung vào Cisco IOS và được kiểm chứng trên mô hình EVE-NG. Khả năng tương thích với thiết bị vật lý, phiên bản hệ điều hành khác và sản phẩm của nhà sản xuất khác chưa được đánh giá đầy đủ.
+ *Phạm vi thực nghiệm:* Chương 5 kiểm chứng một số chức năng tiêu biểu trong một bài thực hành tích hợp. Đề tài chưa thực hiện nhiều lần lặp với cùng điều kiện để tính tỷ lệ thành công, thời gian thao tác hoặc mức độ ổn định dài hạn.
+ *Thu thập trạng thái:* Một số dữ liệu vẫn được trích từ kết quả văn bản của lệnh CLI. Khi phiên bản thiết bị thay đổi cách trình bày, bộ phân tích có thể cần được điều chỉnh.
+ *Đánh giá định lượng:* Các chỉ số như thời gian hội tụ OSPF, thời gian chuyển đổi HSRP, thông lượng Syslog, tỷ lệ mất bản tin, độ trễ cảnh báo và khả năng xử lý đồng thời chưa được đo theo một quy trình tái lập.
+ *Giám sát và phản ứng:* CAMS phụ thuộc vào nhật ký do thiết bị cung cấp, chưa thay thế hệ thống phát hiện xâm nhập dựa trên phân tích lưu lượng. Hành động cô lập trong kịch bản ICMP flood tác động đến toàn bộ cổng con; đề tài chưa đánh giá đầy đủ dương tính giả, cơ chế phê duyệt nhiều cấp, thời gian duy trì hành động hoặc ảnh hưởng dịch vụ lâu dài.
+ *Khôi phục và bảo vệ dữ liệu:* Lịch sử cấu hình và điểm khôi phục mới bảo vệ dữ liệu dự án, chưa tự tạo quy trình hoàn tác đầy đủ trên thiết bị khi một phần lệnh thất bại. Các cơ chế mã hóa và quản lý thông tin xác thực cũng chưa được đánh giá bằng một kịch bản an toàn chuyên biệt.

== Lộ trình phát triển ưu tiên

Hướng phát triển của CAMS được đề xuất theo ba mức ưu tiên.

*Thứ nhất, củng cố độ tin cậy và an toàn.* Hệ thống cần có bộ kiểm thử lặp lại cho các luồng chính, ghi nhận đầy đủ trạng thái trước và sau mỗi thay đổi, đồng thời tạo lệnh hoàn tác để người quản trị kiểm duyệt khi cần khôi phục. Phản ứng tự động nên bổ sung bước phê duyệt, thời hạn hiệu lực và giới hạn phạm vi tác động. Thông tin xác thực cần được tích hợp với kho bí mật của hệ điều hành và quản lý vòng đời khóa chặt chẽ hơn.

*Thứ hai, mở rộng khả năng quản trị.* CAMS có thể sử dụng CDP/LLDP để khám phá liên kết và trực quan hóa mô hình mạng; hoàn thiện các chức năng BGP, VRF và hỗ trợ nhiều nhà sản xuất. Việc tích hợp NETCONF/RESTCONF cùng mô hình YANG hoặc OpenConfig sẽ giảm phụ thuộc vào việc phân tích văn bản CLI và tạo nền tảng cho quản trị dữ liệu có cấu trúc @rfc6241 @rfc8040 @rfc7950.

*Thứ ba, nâng cao giám sát và đánh giá.* Hệ thống cần hoàn thiện tương quan sự kiện, bổ sung webhook và mở rộng quy tắc cảnh báo. Các phép thử tiếp theo nên đo thông lượng, độ trễ, tỷ lệ lỗi, khả năng phục hồi sau mất kết nối và mức độ chính xác của phản ứng tự động trước nhiều loại sự kiện.

== Kiến nghị triển khai và đánh giá tiếp theo

Đối với nghiên cứu tiếp theo, cần xây dựng bộ kịch bản có thể lặp lại và ghi rõ phiên bản thiết bị, trạng thái ban đầu, dữ liệu đầu vào, lệnh dự kiến, kết quả quan sát và thời gian thực hiện. Mỗi phép thử nên được lặp nhiều lần; các trường hợp mất kết nối, lệnh bị từ chối hoặc cấu hình chỉ thành công một phần cần được đánh giá riêng. Cách làm này cho phép chuyển từ minh chứng chức năng sang kết quả định lượng có thể so sánh.

Trong giảng dạy, quy trình khuyến nghị là chuẩn bị cấu hình, đọc bản xem trước, dự đoán tác động, triển khai rồi đối chiếu bằng lệnh kiểm tra và lưu lượng thử. Nhật ký và cảnh báo nên được sử dụng như bằng chứng bổ sung, không thay thế việc xác minh trực tiếp trạng thái thiết bị.

Nếu thí điểm ngoài phòng thực hành, CAMS nên được triển khai trước trên nhóm thiết bị không giữ vai trò trọng yếu. Người vận hành cần sử dụng mẫu lệnh đã kiểm chứng, đồng thời chuẩn bị bản sao cấu hình, quyền truy cập dự phòng và phương án khôi phục trước khi áp dụng thay đổi hoặc bật phản ứng tự động.

== Kết luận chung

Đề tài đã xây dựng CAMS thành một hệ thống quản trị mạng tập trung, hỗ trợ quản lý thiết bị, triển khai cấu hình, thu thập Syslog, gửi cảnh báo và phản ứng theo quy tắc. Bài thực hành tích hợp đã chứng minh tính khả thi của mô hình trong môi trường đào tạo đối với các chức năng định tuyến, dự phòng, chuyển mạch và giám sát. Để mở rộng phạm vi sử dụng, CAMS cần ưu tiên kiểm thử định lượng, hoàn tác an toàn, bảo vệ thông tin xác thực và kiểm soát phản ứng tự động.
