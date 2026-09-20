#pagebreak(weak: true)
#import "../config/tables.typ": report-table

= Giới thiệu đề tài

== Bối cảnh và lý do chọn đề tài

Trong quản trị mạng, cấu hình trực tiếp qua giao diện dòng lệnh (CLI) cho phép kiểm soát từng thiết bị nhưng đòi hỏi lặp lại nhiều thao tác. Khi số lượng router và switch tăng, người quản trị khó theo dõi đồng thời danh mục thiết bị, cấu hình đang chạy và các sự kiện phát sinh. Việc nhập nhầm địa chỉ IP, áp dụng sai chính sách hoặc bỏ sót nhật ký có thể làm gián đoạn dịch vụ và kéo dài thời gian xác định nguyên nhân.

Đề tài *“Nghiên cứu và xây dựng hệ thống quản lý tập trung, tự động hóa cấu hình và giám sát an ninh mạng”* được thực hiện nhằm giải quyết các vấn đề trên. Sản phẩm phần mềm mang tên CAMS (Centralized Automation and Monitoring System), kết hợp quản lý thiết bị, sinh và triển khai cấu hình, thu thập trạng thái và khai thác nhật ký trên một giao diện. Môi trường thực nghiệm là mạng Cisco IOS trên EVE-NG, phục vụ các bài thực hành và kịch bản kiểm thử có kiểm soát.

== Mục tiêu đề tài

Mục tiêu tổng quát là xây dựng hệ thống hỗ trợ quản lý hạ tầng tập trung, giảm thao tác cấu hình thủ công và theo dõi các sự kiện liên quan đến vận hành, an ninh mạng. Theo phiếu đăng ký đề tài, hệ thống được tổ chức thành bốn nhóm chức năng dưới đây.

#report-table(
  columns: (22%, 43%, 35%),
  header: ([Nhóm chức năng], [Nội dung triển khai], [Đầu ra cần kiểm chứng]),
  rows: (
    ([Quản lý], [Tập trung danh mục thiết bị, phiên kết nối, cấu hình và lịch sử sao lưu.], [Tra cứu thiết bị, đồng bộ và xem lại cấu hình.]),
    ([Tự động hóa], [Kiểm tra tham số, sinh lệnh, xem trước và triển khai cấu hình hoặc chính sách.], [Lệnh đúng với dữ liệu nhập; kết quả theo từng thiết bị.]),
    ([Giám sát], [Thu thập trạng thái vận hành và tiếp nhận Syslog tập trung.], [Dữ liệu có nguồn, thời điểm và nội dung để đối chiếu.]),
    ([Bảo mật], [Cấu hình ACL, bảo vệ Lớp 2 và khai thác cảnh báo do thiết bị gửi về.], [Kiểm tra chính sách và nhận diện sự kiện liên quan trên giao diện log.]),
  ),
  caption: [Liên hệ giữa mục tiêu đăng ký và các nhóm chức năng CAMS],
) <tab-objectives>

Đối với mục tiêu phát hiện và cảnh báo, phiên bản được trình bày hỗ trợ tập trung, phân loại và lọc sự kiện theo mức độ, nguồn và nội dung. Việc phát hiện vi phạm phụ thuộc cơ chế trên thiết bị và bản tin thiết bị phát ra; người quản trị sử dụng CAMS để xem và phân tích. Chức năng này chưa được xem là hệ thống phát hiện xâm nhập hay tương quan sự kiện tự động hoàn chỉnh.

== Đối tượng và phạm vi nghiên cứu

Đối tượng nghiên cứu gồm quản trị Cisco IOS, tự động hóa CLI và thu thập nhật ký tập trung. Thực nghiệm sử dụng Cisco vIOS L2, vIOS L3 trên EVE-NG. Ứng dụng sử dụng Python, PyQt6/Qt Quick và SQLite.

Phiếu đăng ký đặt mục tiêu quản lý tập trung máy chủ và dịch vụ mạng. Trong phạm vi hiện thực của báo cáo, CAMS tập trung vào thiết bị mạng và các dịch vụ DHCP, định tuyến, NAT, Syslog; SFTP hỗ trợ trao đổi tệp với máy chủ có dịch vụ tương ứng. Phạm vi này chưa bao gồm quản trị đầy đủ hệ điều hành, ứng dụng và vòng đời máy chủ.

Các nội dung chưa được đánh giá trong phạm vi thực nghiệm gồm triển khai diện rộng trong doanh nghiệp, quản trị đa hãng, phân quyền nhiều người dùng, cụm sẵn sàng cao và phát hiện tấn công bằng phân tích lưu lượng. Việc áp dụng ngoài phòng lab cần được kiểm thử bổ sung theo thiết bị và quy mô cụ thể.

== Phương pháp nghiên cứu

Đề tài kết hợp nghiên cứu tài liệu, thiết kế phần mềm và thực nghiệm. Trước hết, nhóm phân tích các thao tác quản trị thường gặp cùng cú pháp CLI Cisco IOS để xác định dữ liệu đầu vào và đầu ra. Tiếp theo, hệ thống được thiết kế theo các lớp giao diện, điều phối, nghiệp vụ và kết nối; dữ liệu cấu hình được tách khỏi dữ liệu thu thập để tránh nhầm lẫn giữa trạng thái mong muốn và trạng thái thiết bị.

Quá trình kiểm chứng gồm kiểm thử các thành phần xử lý dữ liệu, sinh lệnh và giao tiếp giữa các lớp, kết hợp thực nghiệm trên EVE-NG. Các tiêu chí cần đánh giá là tính đúng đắn của cấu hình, kết quả thực thi, khả năng thu nhận log, phản hồi khi có lỗi và thời gian hoàn thành tác vụ. Số liệu và kết quả thực nghiệm được trình bày ở Chương 5.

== Sản phẩm và bố cục báo cáo

Sản phẩm của đề tài gồm phần mềm CAMS, báo cáo thuyết minh, tài liệu hướng dẫn sử dụng và các kịch bản kiểm thử. Đóng góp chính là tổ chức quy trình quản trị từ danh mục thiết bị đến cấu hình và giám sát trong một không gian làm việc: người dùng chuẩn bị thay đổi, kiểm duyệt lệnh qua View & Push, theo dõi kết quả và đối chiếu với trạng thái hoặc nhật ký thu được.

Báo cáo gồm sáu chương: giới thiệu đề tài; cơ sở lý thuyết và công nghệ; phân tích và thiết kế; xây dựng phần mềm; thử nghiệm và đánh giá; kết luận và hướng phát triển. Các thao tác chi tiết được trình bày riêng trong tài liệu hướng dẫn sử dụng.
