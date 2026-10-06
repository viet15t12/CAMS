#import "../config/tables.typ": report-table, table-code

// Chỉ giới hạn vùng hiển thị khi dàn trang; các tệp ảnh gốc giữ nguyên.
// Tọa độ (x, y, w, h) tính theo pixel của ảnh gốc.
#let evidence-crop(name, source-width, x, y, w, h) = layout(size => {
  let scale = size.width / w
  let source-height = (
    "baseline-binding-trust": 1600,
    "cams-static-ip-input": 1600,
    "ping-before-after": 781,
    "switch-drops-syslog": 793,
    "cams-syslog-alert": 1161,
    "recovered-binding": 278,
  ).at(name)
  block(width: size.width, height: scale * h, clip: true,
    place(top + left, dx: -x * scale, dy: -y * scale,
      box(width: source-width * scale, height: source-height * scale,
        image("/00_book/figures/report/diagrams/dai-lab/" + name + ".png",
          width: 100%, height: 100%, fit: "stretch"))))
})

#pagebreak(weak: true)
==== Kiểm thử DAI: mục tiêu và trạng thái ban đầu

Phần kiểm thử DAI đánh giá ba kết quả: lưu lượng hợp lệ được duy trì; bản tin ARP có ánh xạ IP–MAC không khớp bảng liên kết DHCP Snooping bị loại bỏ; nhật ký từ thiết bị được CAMS tiếp nhận và phân tích. DAI kiểm tra bản tin ARP đi vào cổng không tin cậy dựa trên bảng liên kết hợp lệ; bản tin đi vào cổng DAI tin cậy được bỏ qua bước kiểm tra này @ciscoDaiGuide. Bài thử tạo sai lệch bằng cách đổi địa chỉ IP của R2 trên CAMS, sau đó khôi phục DHCP để kiểm tra khả năng kết nối trở lại.

Mô hình sử dụng nhánh R1–SW1–R2 trong @fig-k1-topology. R1 giữ vai trò máy chủ DHCP và cổng mặc định `192.168.10.1`; R2 kết nối tới SW1 qua Gi0/2. Cổng nối R1 được đặt ở trạng thái tin cậy và DAI được bật trên VLAN 10. Trạng thái thực tế trong @fig-k1-dai-baseline xác nhận Gi0/1 là cổng DAI tin cậy, còn Gi0/2 là cổng không tin cậy. Cổng nối R1 được tin cậy vì cổng mặc định có địa chỉ IP tĩnh; cổng nối R2 được giữ ở trạng thái không tin cậy để kiểm tra bản tin ARP từ máy khách.

#figure(
  stack(dir: ttb, spacing: 7pt,
    evidence-crop("baseline-binding-trust", 2560, 0, 108, 1100, 435),
    evidence-crop("baseline-binding-trust", 2560, 0, 1040, 1100, 485),
  ),
  caption: [DAI hoạt động trên VLAN 10, chưa có ARP bị loại bỏ; SW1 có bảng liên kết hợp lệ của R2 (trích hai vùng cùng ảnh).],
) <fig-k1-dai-baseline>

Bảng liên kết ban đầu ghi nhận địa chỉ IP `192.168.10.4`, địa chỉ MAC `50:00:00:03:00:02`, VLAN 10 và cổng `GigabitEthernet0/2`. Các giá trị `Dropped = 0`, `DHCP Drops = 0` và `DHCP Permits = 4` là mốc đối chiếu trước thử nghiệm. Trường `DHCP Logging: Deny` nằm trong kết quả lệnh DAI và biểu thị chế độ ghi nhật ký bản tin ARP bị từ chối theo kiểm tra bảng liên kết. Đây không phải trạng thái vô hiệu hóa dịch vụ DHCP.

==== Thay đổi IP trên CAMS và đối chiếu kết nối

Khi R2 dùng địa chỉ DHCP hợp lệ, lệnh `clear arp-cache` được thực hiện trước phép kiểm tra kết nối tới cổng mặc định để buộc thiết bị phân giải ARP lại. Kết quả ban đầu là 5/5 hồi đáp với địa chỉ IP nguồn `192.168.10.4`. Tiếp theo, người quản trị mở *R2 → Physical → GigabitEthernet0/2* trên CAMS, nhập địa chỉ IP tĩnh `192.168.10.250` với mặt nạ `255.255.255.0`, rồi áp dụng qua *Update Interface* và *View & Push*. Chính sách DAI và trạng thái tin cậy của hai cổng được giữ trong suốt phép thử.

#figure(
  evidence-crop("cams-static-ip-input", 2560, 480, 350, 2050, 445),
  caption: [Nhập địa chỉ IP tĩnh 192.168.10.250 cho Gi0/2 của R2 trên CAMS (trích vùng biểu mẫu).],
) <fig-k1-dai-input>

Trong @fig-k1-dai-input, danh sách bên trái vẫn hiển thị `192.168.10.4`, còn ô nhập bên phải là `192.168.10.250`. Ảnh ghi lại bước chuẩn bị thay đổi: giá trị đang nhập chưa phải bằng chứng thiết bị đã áp dụng. Địa chỉ IP nguồn trong phép thử tiếp theo tại @fig-k1-dai-ping mới xác nhận R2 đã sử dụng địa chỉ `.250`.

#figure(
  evidence-crop("ping-before-after", 2560, 0, 290, 1130, 450),
  caption: [R2 nhận 5/5 hồi đáp với địa chỉ DHCP .4 và không nhận hồi đáp sau khi đổi sang địa chỉ IP tĩnh .250.],
) <fig-k1-dai-ping>

Hai phép thử ICMP cùng hướng tới `192.168.10.1`, cùng chọn Gi0/2 làm cổng nguồn và đều được thực hiện sau khi xóa bộ nhớ đệm ARP. Lần thứ hai có địa chỉ IP nguồn `192.168.10.250` và không nhận hồi đáp. Địa chỉ này không có ánh xạ hợp lệ tương ứng trong bảng liên kết dùng cho bài thử. Để xác định nguyên nhân mất kết nối, kết quả được đối chiếu tiếp với bộ đếm và nhật ký DAI trên SW1.

==== Bằng chứng ARP bị loại bỏ trên SW1

Sau phép thử, lệnh `show ip arp inspection statistics vlan 10` ghi nhận `Dropped = 9`, `DHCP Drops = 9` và `ACL Drops = 0`. Lệnh `show logging | include SW_DAI` ghi lại các ARP bị từ chối tại Gi0/2, VLAN 10, với MAC nguồn `5000.0003.0002` và IP nguồn `192.168.10.250`, như @fig-k1-dai-device-log.

#figure(
  stack(dir: ttb, spacing: 8pt,
    evidence-crop("switch-drops-syslog", 2560, 0, 0, 950, 440),
    evidence-crop("switch-drops-syslog", 2560, 0, 478, 2320, 280),
  ),
  caption: [SW1 ghi nhận 9 ARP bị DAI loại bỏ và các bản tin SW_DAI tương ứng (trích hai vùng cùng ảnh).],
) <fig-k1-dai-device-log>

Trong thống kê DAI, trường *DHCP Drops* đếm bản tin ARP bị loại bỏ khi kiểm tra theo bảng liên kết DHCP Snooping. Vì vậy, số 9 ở đây là số bản tin ARP bị chặn trong khoảng quan sát, không phải số gói DHCP hay số gói ICMP. Nhật ký có cả `Req` (yêu cầu ARP) và `Res` (phản hồi ARP); một dòng đầu ghi `2 Invalid ARPs`, các dòng còn lại ghi một bản tin ARP. Số dòng nhật ký, số bản tin ARP và số lần gửi ICMP là các đại lượng khác nhau.

Các trường quan trọng được trích lại từ nhật ký để thuận tiện đối chiếu:

#report-table(
  columns: (32%, 68%),
  header: ([Trường], [Giá trị và ý nghĩa]),
  rows: (
    ([Mã bản tin], [#table-code("%SW_DAI-4-DHCP_SNOOPING_DENY")]),
    ([Phân hệ / mức độ], [`SW_DAI` / `4`: Warning, bản tin gốc từ DAI trên bộ chuyển mạch]),
    ([Vị trí vi phạm], [Gi0/2, VLAN 10]),
    ([Địa chỉ MAC nguồn], [`5000.0003.0002`, cùng địa chỉ với `50:00:00:03:00:02` trong bảng liên kết]),
    ([Địa chỉ IP nguồn ARP], [`192.168.10.250`, khác địa chỉ DHCP hợp lệ `.4`]),
    ([Yêu cầu ARP], [Các dòng `Req` tìm địa chỉ MAC cho cổng mặc định `192.168.10.1`]),
  ),
  caption: [Diễn giải các trường trong nhật ký DAI của SW1.],
) <tab-k1-dai-log-fields>

@tab-k1-dai-log-fields làm rõ thành phần `DHCP_SNOOPING` trong mã sự kiện: bản tin thuộc DAI (`SW_DAI`) và nêu việc ARP không vượt qua kiểm tra bảng liên kết. Kết hợp với bộ đếm tăng từ 0 lên 9, nhật ký này xác nhận SW1 đã chặn ARP trong bài thử, thay vì chỉ dựa vào việc phép thử ICMP không nhận hồi đáp.

==== Tiếp nhận Syslog và cảnh báo trên CAMS

@fig-k1-dai-cams-log cho thấy các bản tin của SW1 xuất hiện trên *System Logs* với địa chỉ nguồn quản trị `192.168.122.101`, nhãn `SW_DAI / 4 Warning` và nội dung được phân loại thành *Dynamic ARP Inspection – Denied*. Địa chỉ IP quản trị xác định thiết bị gửi Syslog; địa chỉ `192.168.10.250` trong nội dung là nguồn của bản tin ARP bị chặn. Hai địa chỉ phục vụ hai vai trò khác nhau.

#figure(
  stack(dir: ttb, spacing: 7pt,
    text(size: 10pt)[(a) Nguồn gửi, mức độ và mã sự kiện],
    evidence-crop("cams-syslog-alert", 2560, 780, 470, 760, 320),
    text(size: 10pt)[(b) Nội dung các hàng tương ứng ở bên phải bảng],
    evidence-crop("cams-syslog-alert", 2560, 1540, 470, 1005, 320),
  ),
  caption: [Syslog DAI và cảnh báo CAMS: hai vùng của cùng các hàng trong bảng System Logs.],
) <fig-k1-dai-cams-log>

Dòng màu đỏ `CAMS / 3 Error`, mã sự kiện `DAI_ARP_SPOOF`, là cảnh báo do CAMS sinh khi tổng hợp các sự kiện DAI. Nội dung tại thời điểm cảnh báo nêu *5 invalid ARP packet(s) in 4 log event(s)*. Đây là năm bản tin ARP được ghi nhận trong bốn sự kiện mà CAMS đã tổng hợp tại thời điểm đó; một sự kiện có thể chứa nhiều bản tin ARP. Giá trị này không phải tổng bộ đếm tích lũy của SW1 và không cần bằng số 9 trong ảnh thống kê thiết bị.

Nhãn `Possible ARP spoofing` biểu thị nghi vấn từ bộ phân tích. Trong phép thử này, sự kiện được tạo bằng cách gán địa chỉ IP tĩnh không khớp bảng liên kết cho R2; kết quả không được diễn giải thành bằng chứng một cuộc tấn công chiếm quyền lưu lượng đã xảy ra. Hai phần (a) và (b) của @fig-k1-dai-cams-log giữ cùng thứ tự các hàng: dòng cảnh báo CAMS nằm ở hàng dữ liệu thứ năm trong cả hai phần. Phần nội dung dài bị rút gọn ở mép phải bảng được đối chiếu với bản tin trên SW1 tại @fig-k1-dai-device-log.

==== Khôi phục DHCP và tổng hợp kết quả DAI

Sau khi ghi nhận vi phạm, Gi0/2 của R2 được cấu hình trở lại chế độ DHCP qua CAMS. @fig-k1-dai-recovery ghi nhận bảng liên kết mới: địa chỉ MAC `50:00:00:03:00:02`, địa chỉ IP `192.168.10.5`, VLAN 10 và cổng Gi0/2. R2 xóa bộ nhớ đệm ARP và kiểm tra lại kết nối tới cổng mặc định, nhận đủ 5/5 hồi đáp với địa chỉ IP nguồn `.5`. Địa chỉ được cấp lại khác `.4` ở lần đầu; tiêu chí hợp lệ là cặp IP–MAC khớp bảng liên kết hiện tại, không yêu cầu DHCP cấp lại đúng địa chỉ cũ.

#figure(
  stack(dir: ttb, spacing: 9pt,
    evidence-crop("recovered-binding", 2560, 0, 0, 1100, 260),
    image("/00_book/figures/report/diagrams/dai-lab/recovered-ping.png", width: 100%),
  ),
  caption: [Bảng liên kết được học lại với địa chỉ IP 192.168.10.5 và kết nối R2–R1 nhận đủ 5/5 hồi đáp sau khi trở lại DHCP.],
) <fig-k1-dai-recovery>

#report-table(
  columns: (25%, 23%, 17%, 35%),
  header: ([Trạng thái R2], [Địa chỉ IP nguồn], [Kết nối tới R1], [Bằng chứng đối chiếu]),
  rows: (
    ([DHCP hợp lệ], [192.168.10.4], [5/5], [Có bảng liên kết; bộ đếm DAI ban đầu bằng 0]),
    ([IP tĩnh không khớp bảng liên kết], [192.168.10.250], [0/5], [9 bản tin ARP bị loại bỏ; Syslog SW_DAI và cảnh báo CAMS]),
    ([Khôi phục DHCP], [192.168.10.5], [5/5], [Bảng liên kết mới có cùng địa chỉ MAC, VLAN 10 và Gi0/2]),
  ),
  caption: [Kết quả ba trạng thái trong bài kiểm thử DAI của kịch bản 1.],
) <tab-k1-dai-results>

Kết quả trong @tab-k1-dai-results xác nhận DAI trên SW1 cho phép kết nối khi máy khách sử dụng bảng liên kết hợp lệ và loại bỏ ARP khi địa chỉ IP nguồn không khớp bảng liên kết. CAMS hỗ trợ thao tác thay đổi cấu hình, tiếp nhận nhật ký của thiết bị và sinh cảnh báo từ các sự kiện vi phạm. Phép thử khôi phục cho thấy kết nối hoạt động trở lại khi R2 nhận DHCP và có bảng liên kết mới. Kết luận giới hạn ở các trạng thái đã ghi nhận trên mô hình vIOS-L2 trong EVE-NG.
