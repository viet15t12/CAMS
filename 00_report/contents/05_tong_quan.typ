#pagebreak(weak: true)
#import "../config/tables.typ": report-table

= Giới thiệu đề tài

== Bối cảnh và lý do chọn đề tài

Trong quản trị mạng, cấu hình trực tiếp qua CLI cho phép kiểm soát từng thiết bị nhưng đòi hỏi nhiều thao tác lặp lại. Khi số lượng router và switch tăng, người quản trị khó theo dõi đồng thời danh mục thiết bị, cấu hình đang chạy và các sự kiện phát sinh. Việc nhập nhầm địa chỉ IP, áp dụng sai chính sách hoặc bỏ sót nhật ký có thể làm gián đoạn dịch vụ và kéo dài thời gian xác định nguyên nhân.

Đề tài *“Nghiên cứu và xây dựng hệ thống quản lý tập trung, tự động hóa cấu hình và giám sát an ninh mạng”* được thực hiện nhằm giải quyết các vấn đề trên. Sản phẩm phần mềm gọi tắt là CAMS (Centralized Automation and Monitoring System), kết hợp quản lý thiết bị, sinh và triển khai cấu hình, thu thập trạng thái và khai thác nhật ký trên một giao diện. Môi trường kiểm chứng là mạng Cisco IOS trên EVE-NG, phục vụ các bài thực hành và kịch bản kiểm thử có kiểm soát.

== Mục tiêu đề tài

Mục tiêu tổng quát là xây dựng hệ thống hỗ trợ quản lý hạ tầng tập trung, giảm thao tác cấu hình thủ công và theo dõi các sự kiện liên quan đến vận hành, an ninh mạng. Hệ thống sẽ được tổ chức thành bốn nhóm chức năng dưới đây.

#report-table(
  columns: (22%, 43%, 35%),
  header: ([Nhóm chức năng], [Nội dung triển khai], [Đầu ra cần kiểm chứng]),
  rows: (
    ([Quản lý], [Tập trung danh mục thiết bị, phiên kết nối, cấu hình và lịch sử sao lưu.], [Tra cứu thiết bị, đồng bộ và xem lại cấu hình.]),
    ([Tự động hóa], [Kiểm tra tham số, sinh lệnh, xem trước và triển khai cấu hình hoặc chính sách.], [Lệnh đúng với dữ liệu nhập; kết quả theo từng thiết bị.]),
    ([Giám sát], [Thu thập trạng thái vận hành và tiếp nhận Syslog tập trung.], [Dữ liệu có nguồn, thời điểm và nội dung để đối chiếu.]),
    ([Bảo mật], [Cấu hình ACL, bảo vệ Lớp 2 và khai thác cảnh báo do thiết bị gửi về.], [Kiểm tra chính sách và nhận diện sự kiện liên quan trên giao diện nhật ký.]),
  ),
  caption: [Mục tiêu phát triển],
) <tab-objectives>

== Đối tượng và phạm vi nghiên cứu

Đối tượng nghiên cứu gồm thiết bị Cisco IOS, quy trình tự động hóa CLI và cơ chế thu thập nhật ký tập trung. Hoạt động kiểm chứng sử dụng Cisco vIOS L2 và vIOS L3 trên EVE-NG; phần mềm được xây dựng bằng Python, PyQt6/Qt Quick và SQLite.

Đề tài hướng đến quản lý tập trung thiết bị và dịch vụ mạng. Trong phạm vi hiện thực của báo cáo, CAMS tập trung vào thiết bị mạng cùng các chức năng DHCP, định tuyến, NAT và Syslog; SFTP hỗ trợ trao đổi tệp với máy chủ có dịch vụ tương ứng. Hệ thống chưa bao gồm việc quản trị đầy đủ hệ điều hành, ứng dụng và vòng đời máy chủ.

Các nội dung chưa được đánh giá trong phạm vi kiểm chứng gồm triển khai diện rộng trong doanh nghiệp, quản trị đa hãng, phân quyền nhiều người dùng, cụm sẵn sàng cao và phát hiện tấn công bằng phân tích lưu lượng. Việc áp dụng ngoài phòng lab cần được kiểm thử bổ sung theo thiết bị và quy mô cụ thể.

== Phương pháp nghiên cứu

Đề tài kết hợp nghiên cứu tài liệu, thiết kế phần mềm và thực nghiệm. Trước hết, nhóm phân tích các thao tác quản trị thường gặp cùng cú pháp CLI Cisco IOS để xác định dữ liệu đầu vào và đầu ra. Tiếp theo, hệ thống được thiết kế theo các lớp giao diện, điều phối, nghiệp vụ và kết nối; dữ liệu cấu hình được tách khỏi dữ liệu thu thập để tránh nhầm lẫn giữa trạng thái mong muốn và trạng thái thiết bị.

Quá trình kiểm chứng kết hợp kiểm thử các thành phần xử lý dữ liệu, sinh lệnh và giao tiếp giữa các lớp với thực nghiệm trên EVE-NG. Các tiêu chí đánh giá gồm tính đúng đắn của cấu hình, kết quả thực thi, khả năng thu nhận nhật ký và phản hồi khi xảy ra lỗi. Số liệu cùng kết quả thực nghiệm được trình bày ở Chương 5.

== Sản phẩm và bố cục báo cáo

Sản phẩm của đề tài gồm phần mềm CAMS, báo cáo thuyết minh, tài liệu hướng dẫn sử dụng và các kịch bản kiểm thử. Đóng góp chính là tổ chức quy trình quản trị từ danh mục thiết bị đến cấu hình và giám sát trong một không gian làm việc: người dùng chuẩn bị thay đổi, kiểm duyệt lệnh qua View & Push, theo dõi kết quả và đối chiếu với trạng thái hoặc nhật ký thu được.

Báo cáo gồm sáu chương: giới thiệu đề tài; cơ sở lý thuyết và công nghệ; phân tích và thiết kế; xây dựng phần mềm; thử nghiệm và đánh giá; kết luận và hướng phát triển. Các thao tác chi tiết được trình bày riêng trong tài liệu hướng dẫn sử dụng.
