#pagebreak(weak: true)
#import "../config/tables.typ": report-table

= Giới thiệu đề tài

== Bối cảnh và lý do chọn đề tài

Trong quản trị mạng, cấu hình trực tiếp qua CLI cho phép kiểm soát từng thiết bị nhưng đòi hỏi nhiều thao tác lặp lại. Khi số lượng bộ định tuyến và bộ chuyển mạch tăng, người quản trị khó theo dõi đồng thời danh mục thiết bị, cấu hình đang chạy và các sự kiện phát sinh. Việc nhập nhầm địa chỉ IP, áp dụng sai chính sách hoặc bỏ sót nhật ký có thể làm gián đoạn dịch vụ và kéo dài thời gian xác định nguyên nhân.

Đề tài xây dựng hệ thống quản lý tập trung, tự động hóa cấu hình và giám sát (Centralized Automation and Monitoring System – CAMS). CAMS kết hợp quản lý thiết bị, sinh và triển khai cấu hình, thu thập trạng thái và khai thác nhật ký trên một giao diện. Hệ thống được kiểm chứng với Cisco IOS trên EVE-NG trong các kịch bản có kiểm soát.

== Tổng quan nghiên cứu và giải pháp hiện có

Các giải pháp liên quan được chia thành bốn nhóm:
- *Tự động hóa bằng mã lệnh (Ansible, Nornir):* linh hoạt và phù hợp triển khai theo lô, nhưng yêu cầu người dùng xây dựng tệp tác vụ hoặc chương trình Python @ansibleNetworkDocs @nornirDocs.
- *Nguồn dữ liệu chuẩn (NetBox):* quản lý địa chỉ IP và hạ tầng trung tâm dữ liệu, đồng thời cung cấp dữ liệu qua API @netboxDocs.
- *Sao lưu cấu hình (Oxidized):* thu thập và lưu lịch sử cấu hình để theo dõi thay đổi @oxidizedDocs.
- *Nền tảng thương mại (Cisco Catalyst Center):* cung cấp quản lý, triển khai và kiểm tra cấu hình ở quy mô tổ chức, khác với phạm vi phòng thực hành của đề tài @ciscoCatalystCenter.

== Tính mới của đề tài

Theo RFC 9315, quản trị mạng dựa trên ý định gồm diễn giải mục tiêu và bảo đảm trạng thái vận hành phù hợp với mục tiêu đó @rfc9315. CAMS mới tiếp cận một phần bài toán qua cấu hình mong muốn, bước kiểm duyệt và dữ liệu quan sát; hệ thống chưa hiện thực vòng lặp bảo đảm tự động hoàn chỉnh.

Đóng góp của đề tài là quy trình tích hợp cho phòng thực hành Cisco IOS, không phải các kỹ thuật sinh mẫu lệnh, quản lý trạng thái hay Syslog riêng lẻ. Các nội dung chính gồm:
- *Giao diện cấu hình bằng biểu mẫu:* Thay vì viết kịch bản, người quản trị khai báo thông số qua biểu mẫu. Hệ thống sinh lệnh CLI, kiểm tra phụ thuộc và triển khai cấu hình theo nhóm thiết bị.
- *Mô hình phân biệt trạng thái cấu hình:* Hệ thống phân biệt trạng thái mong muốn, tức cấu hình đang chuẩn bị, với trạng thái quan sát thu thập từ thiết bị. Quy trình *View & Push* cung cấp bước kiểm duyệt trước khi thực thi nhằm hạn chế sai sót.
- *Tích hợp vòng lặp quản trị:* Kết nối triển khai chính sách với giám sát Syslog trên cùng một giao diện để truy vết thay đổi và sự kiện.

== Mục tiêu đề tài

Mục tiêu tổng quát là xây dựng hệ thống hỗ trợ quản lý hạ tầng tập trung, giảm thao tác cấu hình thủ công và theo dõi các sự kiện liên quan đến vận hành, an ninh mạng. Hệ thống được tổ chức thành bốn nhóm chức năng dưới đây.

#report-table(
  columns: (22%, 43%, 35%),
  header: ([Nhóm chức năng], [Nội dung triển khai], [Đầu ra cần kiểm chứng]),
  rows: (
    ([Quản lý], [Tập trung danh mục thiết bị, phiên kết nối, cấu hình và lịch sử sao lưu.], [Tra cứu thiết bị và đồng bộ thành công `running-config`.]),
    ([Tự động hóa], [Kiểm tra tham số, sinh lệnh, xem trước và triển khai cấu hình hoặc chính sách.], [Đối chiếu lệnh sinh với cấu hình đang chạy; kiểm tra trạng thái láng giềng, bảng định tuyến và kết nối sau khi triển khai trên năm bộ định tuyến ở kịch bản 2.]),
    ([Giám sát], [Thu thập trạng thái vận hành và tiếp nhận Syslog tập trung.], [Đối chiếu nguồn, PRI, mức độ, mã sự kiện và nội dung gốc của bản tin Syslog; kiểm tra cảnh báo thư điện tử ở kịch bản 4.]),
    ([Bảo mật], [Cấu hình ACL, bảo vệ Lớp 2 và khai thác cảnh báo do thiết bị gửi về.], [Kiểm tra chính sách chặn lưu lượng và phản hồi sự kiện trên Syslog.]),
  ),
  caption: [Mục tiêu phát triển],
) <tab-objectives>

Các tiêu chí tại @tab-objectives được đối chiếu với minh chứng ở Chương 5. Báo cáo không đặt ngưỡng thời gian hoặc tỷ lệ phân tích đúng khi chưa có tập đo tái lập. Ước tính thao tác ở kịch bản 2 được ghi riêng và không thay thế số đo; Chương 6 chỉ kết luận trong phạm vi đã kiểm chứng.

== Đối tượng và phạm vi nghiên cứu

Đối tượng nghiên cứu gồm thiết bị Cisco IOS, quy trình tự động hóa CLI và cơ chế thu thập nhật ký tập trung. Hoạt động kiểm chứng sử dụng Cisco vIOS L2 và vIOS L3 trên EVE-NG; phần mềm được xây dựng bằng Python, PyQt6/Qt Quick và SQLite.

Đề tài hướng đến quản lý tập trung thiết bị và dịch vụ mạng. Trong phạm vi hiện thực của báo cáo, CAMS tập trung vào thiết bị mạng cùng các chức năng DHCP, định tuyến, NAT và Syslog; SFTP hỗ trợ trao đổi tệp với máy chủ có dịch vụ tương ứng. Hệ thống chưa bao gồm việc quản trị đầy đủ hệ điều hành, ứng dụng và vòng đời máy chủ.

Các nội dung chưa được đánh giá trong phạm vi kiểm chứng gồm triển khai diện rộng trong doanh nghiệp, quản trị đa hãng, phân quyền nhiều người dùng, cụm sẵn sàng cao và phát hiện tấn công bằng phân tích lưu lượng. Việc áp dụng ngoài phòng thực hành cần được kiểm thử bổ sung theo thiết bị và quy mô cụ thể.

== Phương pháp nghiên cứu

Đề tài kết hợp nghiên cứu tài liệu, thiết kế phần mềm và thực nghiệm. Nhóm tác giả phân tích thao tác quản trị và cú pháp Cisco IOS, sau đó thiết kế các lớp giao diện, điều phối, nghiệp vụ và kết nối. Dữ liệu cấu hình được tách khỏi dữ liệu thu thập để phân biệt trạng thái mong muốn với trạng thái thiết bị.

Quá trình kiểm chứng kết hợp kiểm thử xử lý dữ liệu, sinh lệnh và giao tiếp giữa các lớp với thực nghiệm trên EVE-NG. Tiêu chí đánh giá gồm cấu hình cuối, kết quả thực thi, khả năng thu nhận nhật ký và phản hồi lỗi. Những chỉ tiêu chưa có dữ liệu tái lập được ghi rõ là chưa kiểm chứng.

