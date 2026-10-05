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

Phần kiểm thử kiểm tra ARP động (Dynamic ARP Inspection, DAI) đánh giá ba kết quả: lưu lượng hợp lệ được duy trì; ARP có ánh xạ IP–MAC không khớp cơ sở dữ liệu DHCP Snooping bị loại bỏ; nhật ký từ thiết bị được CAMS tiếp nhận và phân tích. DAI kiểm tra ARP đi vào cổng untrusted dựa trên binding hợp lệ; ARP đi vào cổng DAI trusted được bỏ qua bước kiểm tra này @ciscoDaiGuide. Bài thử tạo sai lệch bằng cách đổi IP của R2 trên CAMS, sau đó khôi phục DHCP để kiểm tra khả năng kết nối trở lại.

Mô hình sử dụng nhánh R1–SW1–R2 trong @fig-k1-topology. R1 giữ vai trò DHCP server và gateway `192.168.10.1`; R2 kết nối tới SW1 qua Gi0/2. Chính sách được đưa về trạng thái trust cổng nối R1, với DAI bật trên VLAN 10. Trạng thái thực tế trong @fig-k1-dai-baseline xác nhận Gi0/1 là DAI Trusted và Gi0/2 là Untrusted. Cổng nối R1 dùng DAI trust do gateway có IP tĩnh; cổng R2 giữ untrusted để ARP từ máy khách được kiểm tra.

#figure(
  stack(dir: ttb, spacing: 7pt,
    evidence-crop("baseline-binding-trust", 2560, 0, 108, 1100, 435),
    evidence-crop("baseline-binding-trust", 2560, 0, 1040, 1100, 485),
  ),
  caption: [DAI hoạt động trên VLAN 10, chưa có ARP bị loại bỏ; SW1 có binding hợp lệ của R2 (trích hai vùng cùng ảnh).],
) <fig-k1-dai-baseline>

Binding ban đầu ghi nhận IP `192.168.10.4`, MAC `50:00:00:03:00:02`, VLAN 10 và cổng `GigabitEthernet0/2`. Các giá trị `Dropped = 0`, `DHCP Drops = 0` và `DHCP Permits = 4` là mốc đối chiếu trước thử nghiệm. Trường `DHCP Logging: Deny` nằm trong kết quả lệnh DAI và biểu thị chế độ ghi nhật ký ARP bị từ chối theo kiểm tra binding. Đây không phải trạng thái vô hiệu hóa dịch vụ DHCP.

==== Thay đổi IP trên CAMS và đối chiếu kết nối

Khi R2 dùng địa chỉ DHCP hợp lệ, lệnh `clear arp-cache` được thực hiện trước phép ping gateway để buộc thiết bị phân giải ARP lại. Kết quả ban đầu là 5/5 phản hồi với IP nguồn `192.168.10.4`. Tiếp theo, người quản trị mở *R2 → Physical → GigabitEthernet0/2* trên CAMS, nhập IP tĩnh `192.168.10.250` với mặt nạ `255.255.255.0`, rồi áp dụng qua *Update Interface* và *View & Push*. Chính sách DAI và trạng thái trust của hai cổng được giữ trong suốt phép thử.

#figure(
  evidence-crop("cams-static-ip-input", 2560, 480, 350, 2050, 445),
  caption: [Nhập IP tĩnh 192.168.10.250 cho Gi0/2 của R2 trên CAMS (trích vùng biểu mẫu).],
) <fig-k1-dai-input>

Trong @fig-k1-dai-input, danh sách bên trái vẫn hiển thị `192.168.10.4`, còn ô nhập bên phải là `192.168.10.250`. Ảnh ghi lại bước chuẩn bị thay đổi: giá trị đang nhập chưa phải bằng chứng thiết bị đã áp dụng. IP nguồn trong lần ping tiếp theo tại @fig-k1-dai-ping mới xác nhận R2 đã sử dụng địa chỉ `.250`.

#figure(
  evidence-crop("ping-before-after", 2560, 0, 290, 1130, 450),
  caption: [R2 ping thành công 5/5 với IP DHCP .4 và thất bại 0/5 sau khi đổi sang IP tĩnh .250.],
) <fig-k1-dai-ping>

Hai phép ping cùng hướng tới `192.168.10.1`, cùng chọn Gi0/2 làm cổng nguồn và đều được thực hiện sau khi xóa ARP cache. Lần thứ hai có IP nguồn `192.168.10.250` và tỷ lệ thành công 0/5. IP này không có ánh xạ hợp lệ tương ứng trong binding dùng cho bài thử. Để xác định nguyên nhân mất kết nối, kết quả ping được đối chiếu tiếp với bộ đếm và nhật ký DAI trên SW1.

==== Bằng chứng ARP bị loại bỏ trên SW1

Sau phép thử, lệnh `show ip arp inspection statistics vlan 10` ghi nhận `Dropped = 9`, `DHCP Drops = 9` và `ACL Drops = 0`. Lệnh `show logging | include SW_DAI` ghi lại các ARP bị từ chối tại Gi0/2, VLAN 10, với MAC nguồn `5000.0003.0002` và IP nguồn `192.168.10.250`, như @fig-k1-dai-device-log.

#figure(
  stack(dir: ttb, spacing: 8pt,
    evidence-crop("switch-drops-syslog", 2560, 0, 0, 950, 440),
    evidence-crop("switch-drops-syslog", 2560, 0, 478, 2320, 280),
  ),
  caption: [SW1 ghi nhận 9 ARP bị DAI loại bỏ và các bản tin SW_DAI tương ứng (trích hai vùng cùng ảnh).],
) <fig-k1-dai-device-log>

Trong thống kê DAI, *DHCP Drops* đếm ARP bị loại bỏ khi kiểm tra theo DHCP Snooping binding. Vì vậy, số 9 ở đây là số ARP bị chặn trong khoảng quan sát, không phải số gói DHCP hay số gói ICMP. Nhật ký có cả `Req` (ARP Request) và `Res` (ARP Response); một dòng đầu ghi `2 Invalid ARPs`, các dòng còn lại ghi một ARP. Số dòng log, số ARP và số lần gửi ping là các đại lượng khác nhau.

Các trường quan trọng được trích lại từ nhật ký để thuận tiện đối chiếu:

#report-table(
  columns: (32%, 68%),
  header: ([Trường], [Giá trị và ý nghĩa]),
  rows: (
    ([Mã bản tin], [#table-code("%SW_DAI-4-DHCP_SNOOPING_DENY")]),
    ([Phân hệ / mức độ], [`SW_DAI` / `4`: Warning, bản tin gốc từ DAI trên switch]),
    ([Vị trí vi phạm], [Gi0/2, VLAN 10]),
    ([MAC nguồn], [`5000.0003.0002`, cùng MAC với `50:00:00:03:00:02` trong binding]),
    ([IP nguồn ARP], [`192.168.10.250`, khác địa chỉ DHCP hợp lệ `.4`]),
    ([Yêu cầu ARP], [Các dòng `Req` tìm địa chỉ MAC cho gateway `192.168.10.1`]),
  ),
  caption: [Diễn giải các trường trong nhật ký DAI của SW1.],
) <tab-k1-dai-log-fields>

@tab-k1-dai-log-fields làm rõ chữ `DHCP_SNOOPING` trong mnemonic: bản tin thuộc DAI (`SW_DAI`) và nêu việc ARP không vượt qua kiểm tra binding. Kết hợp với bộ đếm tăng từ 0 lên 9, nhật ký này xác nhận SW1 đã thực hiện chặn ARP trong bài thử, thay vì chỉ dựa vào kết quả ping thất bại.

==== Tiếp nhận Syslog và cảnh báo trên CAMS

@fig-k1-dai-cams-log cho thấy các bản tin của SW1 xuất hiện trên *System Logs* với địa chỉ nguồn quản trị `192.168.122.101`, nhãn `SW_DAI / 4 Warning` và nội dung được phân loại thành *Dynamic ARP Inspection – Denied*. IP quản trị này xác định thiết bị gửi Syslog; IP `192.168.10.250` trong nội dung là địa chỉ nguồn của ARP bị chặn. Hai địa chỉ phục vụ hai vai trò khác nhau.

#figure(
  stack(dir: ttb, spacing: 7pt,
    text(size: 10pt)[(a) Nguồn gửi, mức độ và mnemonic],
    evidence-crop("cams-syslog-alert", 2560, 780, 470, 760, 320),
    text(size: 10pt)[(b) Nội dung các hàng tương ứng ở bên phải bảng],
    evidence-crop("cams-syslog-alert", 2560, 1540, 470, 1005, 320),
  ),
  caption: [Syslog DAI và cảnh báo CAMS: hai vùng của cùng các hàng trong bảng System Logs.],
) <fig-k1-dai-cams-log>

Dòng màu đỏ `CAMS / 3 Error`, mnemonic `DAI_ARP_SPOOF`, là cảnh báo do CAMS sinh khi tổng hợp các sự kiện DAI. Nội dung tại thời điểm cảnh báo nêu *5 invalid ARP packet(s) in 4 log event(s)*. Đây là năm ARP được ghi nhận trong bốn sự kiện mà CAMS đã tổng hợp tại thời điểm đó; một sự kiện có thể chứa nhiều ARP. Giá trị này không phải tổng bộ đếm tích lũy của SW1 và không cần bằng số 9 trong ảnh thống kê thiết bị.

Nhãn `Possible ARP spoofing` biểu thị nghi vấn từ bộ phân tích. Trong phép thử này, sự kiện được tạo bằng cách gán IP tĩnh không khớp binding cho R2; kết quả không được diễn giải thành bằng chứng một cuộc tấn công chiếm quyền lưu lượng đã xảy ra. Hai phần (a) và (b) của @fig-k1-dai-cams-log giữ cùng thứ tự các hàng: dòng cảnh báo CAMS nằm ở hàng dữ liệu thứ năm trong cả hai phần. Phần nội dung dài bị rút gọn ở mép phải bảng được đối chiếu với bản tin trên SW1 tại @fig-k1-dai-device-log.

==== Khôi phục DHCP và tổng hợp kết quả DAI

Sau khi ghi nhận vi phạm, Gi0/2 của R2 được cấu hình trở lại chế độ DHCP qua CAMS. @fig-k1-dai-recovery ghi nhận binding mới: MAC `50:00:00:03:00:02`, IP `192.168.10.5`, VLAN 10 và cổng Gi0/2. R2 xóa ARP cache và ping lại gateway, đạt 5/5 phản hồi với IP nguồn `.5`. Địa chỉ cấp lại khác `.4` ở lần đầu; tiêu chí hợp lệ là IP–MAC khớp binding hiện tại, không yêu cầu DHCP cấp lại đúng địa chỉ cũ.

#figure(
  stack(dir: ttb, spacing: 9pt,
    evidence-crop("recovered-binding", 2560, 0, 0, 1100, 260),
    image("/00_book/figures/report/diagrams/dai-lab/recovered-ping.png", width: 100%),
  ),
  caption: [Binding được học lại với IP 192.168.10.5 và kết nối R2–R1 phục hồi 5/5 sau khi trở lại DHCP.],
) <fig-k1-dai-recovery>

#report-table(
  columns: (25%, 23%, 17%, 35%),
  header: ([Trạng thái R2], [IP nguồn], [Ping R1], [Bằng chứng đối chiếu]),
  rows: (
    ([DHCP hợp lệ], [192.168.10.4], [5/5], [Có binding; bộ đếm DAI drop ban đầu bằng 0]),
    ([IP tĩnh không khớp binding], [192.168.10.250], [0/5], [9 ARP bị loại bỏ; Syslog SW_DAI và cảnh báo CAMS]),
    ([Khôi phục DHCP], [192.168.10.5], [5/5], [Binding mới cùng MAC, VLAN 10, Gi0/2]),
  ),
  caption: [Kết quả ba trạng thái trong bài kiểm thử DAI của Lab 1.],
) <tab-k1-dai-results>

Kết quả trong @tab-k1-dai-results xác nhận DAI trên SW1 cho phép kết nối khi máy khách sử dụng binding hợp lệ và loại bỏ ARP khi IP nguồn bị thay đổi ngoài binding. CAMS hỗ trợ thao tác thay đổi cấu hình, tiếp nhận nhật ký của thiết bị và sinh cảnh báo từ các sự kiện vi phạm. Phép thử khôi phục cho thấy kết nối hoạt động trở lại khi R2 nhận DHCP và có binding mới. Kết luận giới hạn ở các trạng thái đã ghi nhận trên mô hình vIOS-L2 trong EVE-NG.
