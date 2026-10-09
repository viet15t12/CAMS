#import "../config/tables.typ": report-table, table-code
#import "../config/commands.typ": report-note, step-title

#pagebreak(weak: true)
= Thử nghiệm và đánh giá

== Mục tiêu và môi trường thử nghiệm

Chương này đánh giá CAMS qua năm kịch bản mạng trên EVE-NG: bảo vệ Lớp 2, định tuyến, dịch vụ Lớp 3, Syslog và chính sách ACL. Bằng chứng gồm ảnh giao diện, cấu hình đang chạy, kết quả lệnh kiểm tra và phép thử lưu lượng. Các cơ chế phân quyền, mã hóa và SFTP được mô tả theo mã nguồn ở Chương 3–4; năm kịch bản dưới đây không thay thế kiểm thử riêng cho các cơ chế đó.

=== Môi trường thử nghiệm phần mềm và phần cứng

Các kịch bản được thực hiện trên hai môi trường độc lập. Kịch bản 1, 2 và 5 do Nguyễn Phan Kiên thực hiện; kịch bản 3 và 4 do Nguyễn Quốc Việt thực hiện trên máy trạm và máy EVE-NG khác. Việc dùng cùng dải quản trị hoặc cùng tên bộ định tuyến không có nghĩa các kịch bản dùng chung thiết bị hay tài nguyên máy chủ.

#report-table(
  columns: (22%, 42%, 36%),
  header: ([Thành phần], [Kịch bản 1, 2 và 5], [Kịch bản 3 và 4]),
  rows: (
    ([Nguồn thực nghiệm], [Nguyễn Phan Kiên], [Nguyễn Quốc Việt]),
    ([Máy trạm CAMS], [Fedora Linux 44 Workstation; Intel Core i7-14650HX; 16 lõi, 24 luồng; RAM 16 GB danh nghĩa.], [Máy trạm riêng; chưa có thông tin xác nhận hệ điều hành, CPU và RAM.]),
    ([Môi trường Python/Qt], [Python 3.14.7; PyQt 6.10.2; Qt 6.10.0 trong môi trường hiện tại.], [Chưa xác nhận phiên bản thực tế của từng lần chạy.]),
    ([Máy EVE-NG], [Địa chỉ truy cập 192.168.122.64 trong ảnh; chưa xác nhận phiên bản, bản Community/Professional và vCPU/RAM cấp cho máy ảo.], [Máy EVE-NG khác; chưa xác nhận phiên bản, địa chỉ truy cập và vCPU/RAM.]),
    ([Thiết bị Cisco], [Bộ định tuyến và bộ chuyển mạch Cisco IOS ảo; `running-config` của kịch bản 2 ghi phiên bản 15.5.], [Thiết bị Cisco IOS ảo theo cấu hình và ảnh thử nghiệm; chưa xác nhận đầy đủ phiên bản IOS.]),
  ),
  text-size: 9.5pt,
  caption: [Môi trường thử nghiệm theo nguồn của từng nhóm kịch bản],
) <tab-lab-environments>

Thông số máy trạm và phiên bản Python/Qt ở cột kịch bản 1, 2 và 5 được đối chiếu trên máy hiện tại ngày 06/10/2026. Đây là thông tin môi trường khi biên tập, không chứng minh mọi ảnh chụp trước đó sử dụng đúng các phiên bản này. Tài nguyên máy trạm không được xem là tài nguyên đã cấp cho máy EVE-NG. Trường `version 15.5` trong `running-config` cũng không thay thế kết quả `show version` để xác định ảnh hệ thống và bản dựng IOS.

Các kịch bản sử dụng mạng quản trị `192.168.122.0/24` để CAMS kết nối SSH hoặc Telnet với thiết bị. Báo cáo gọi đây là mạng quản trị riêng; chưa có minh chứng về VRF hoặc cách ly đường định tuyến để khẳng định quản trị ngoại băng hoàn toàn. Bảng địa chỉ trong từng kịch bản là nguồn đối chiếu chính: chẳng hạn R1 của kịch bản 2 có địa chỉ IP quản trị `.101`, còn R1 của kịch bản 5 có địa chỉ `.104`.

#report-table(
  columns: (12%, 45%, 43%),
  header: ([Kịch bản], [Nội dung], [Quy mô và phạm vi minh chứng]),
  rows: (
    ([1], [DHCP Snooping và DAI], [Ba bộ định tuyến, gồm máy khách R2 và thiết bị FAKE_DHCP, cùng một bộ chuyển mạch; kiểm tra nguồn cấp DHCP và bản tin ARP không khớp bảng liên kết.]),
    ([2], [OSPF một vùng], [Năm bộ định tuyến, hai bộ chuyển mạch và bốn VPC; kết quả lệnh trên cả năm bộ định tuyến cùng sáu loạt kiểm tra ICMP hai chiều.]),
    ([3], [GLBP, DHCP và NAT/PAT], [Sơ đồ có bốn bộ định tuyến và một bộ chuyển mạch; bằng chứng gồm kết quả DHCP, truy vết đường đi trên PC1 và cấu hình GLBP, PAT trên bộ định tuyến.]),
    ([4], [Syslog và cảnh báo thư điện tử], [Ba bộ định tuyến và một bộ chuyển mạch; ảnh bộ nhận ghi nhận 245 bản tin tại một thời điểm cùng hai mẫu thư cảnh báo.]),
    ([5], [ACL và nhật ký an ninh], [Ba bộ định tuyến và ba bộ chuyển mạch; phép thử chính sách trên VPC7, VPC8 và VPC9.]),
  ),
  text-size: 9.5pt,
  caption: [Tổng quan năm kịch bản thực nghiệm độc lập],
) <tab-lab-scope>

== Kịch bản kiểm thử trong phòng thực hành

Phần thử nghiệm gồm năm kịch bản: DHCP Snooping và DAI trong bảo mật Lớp 2; định tuyến OSPF một vùng trên năm bộ định tuyến; phối hợp GLBP–DHCP–NAT/PAT; thu thập và phân tích nhật ký Syslog; kiểm chứng chính sách ACL cùng nhật ký an ninh tập trung. Mỗi kịch bản được thực hiện theo ba giai đoạn:

1. *Thiết lập và xem trước trên giao diện:* người dùng nhập tham số trên biểu mẫu nghiệp vụ. Dữ liệu được lưu ở trạng thái mong muốn và chuyển thành tập lệnh CLI để kiểm tra trong cửa sổ *View & Push*.
2. *Triển khai cấu hình bằng tác vụ nền:* tác vụ lấy thông tin truy cập, áp dụng khóa theo thiết bị (`Host Lock`) để tránh tranh chấp luồng lệnh, sau đó gửi tập lệnh qua giao thức SSH hoặc Telnet của phiên thiết bị.
3. *Xác minh trạng thái:* người quản trị đối chiếu phản hồi của hệ thống, kiểm tra trực tiếp bằng đầu cuối tích hợp và đánh giá lưu lượng thực tế.

#include "09_kich_ban_1_snooping.typ"
#include "09_kich_ban_1_dai.typ"

#include "09_kich_ban_2_ospf.typ"

=== Kịch bản 3: Tích hợp cổng dự phòng GLBP, cấp phát DHCP và chuyển đổi địa chỉ NAT/PAT

==== Mục tiêu và quy hoạch thiết bị

Kịch bản 3 xây dựng mạng LAN có khả năng cấp phát địa chỉ IP tự động, sử dụng GLBP để cung cấp cổng mặc định dự phòng và cân bằng tải, đồng thời triển khai NAT/PAT cho lưu lượng đi ra mạng ngoài. Kịch bản nhằm kiểm tra khả năng phối hợp nhiều chức năng Lớp 3 trong cùng một quy trình cấu hình bằng CAMS và xác minh trực tiếp trên thiết bị.

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/fhrp-nat-dhcp-report.png", width: 95%),
  caption: [Sơ đồ Kịch bản 3: Tích hợp GLBP, DHCP và NAT/PAT cho mạng LAN],
) <fig-topo-scenario-3>

Địa chỉ và vai trò của từng thiết bị được trình bày trong bảng quy hoạch dưới đây.

#report-table(
  columns: (14%, 28%, 18%, 40%),
  text-size: 9.5pt,
  cell-inset: (x: 4pt, y: 4.5pt),
  header: ([Thiết bị], [Cổng / Địa chỉ], [Vai trò], [Ghi chú]),
  rows: (
    ([R1], [#table-code("Gi0/0 - 192.168.4.2/24")], [Thành viên cổng mặc định], [Tham gia nhóm GLBP 113, độ ưu tiên 101]),
    ([R2], [#table-code("Gi0/0 - 192.168.4.3/24")], [Thành viên cổng mặc định], [Tham gia nhóm GLBP 113, độ ưu tiên 100]),
    (
      [GLBP Virtual IP],
      [#table-code("192.168.4.1")],
      [Cổng mặc định],
      [Địa chỉ cổng mặc định cấp cho các máy trạm qua DHCP],
    ),
    ([NAT], [#table-code("Gi0/1 - 192.168.1.2/24")], [NAT Inside], [Kết nối hướng về R1]),
    ([NAT], [#table-code("Gi0/3 - 192.168.2.2/24")], [NAT Inside], [Kết nối hướng về R2]),
    ([NAT], [#table-code("Gi0/2 - 10.0.10.2/24")], [NAT Outside], [Kết nối tới mạng ISP / upstream]),
    ([PC1], [DHCP], [Máy trạm kiểm thử], [Nhận địa chỉ IP động và sử dụng cổng mặc định `192.168.4.1`]),
  ),
  caption: [Bảng quy hoạch địa chỉ và vai trò thiết bị trong Kịch bản 3],
) <tab-ip-planning-lab3>

==== Quy trình triển khai trên phần mềm CAMS

#step-title[Bước 1. Khai báo vai trò NAT Inside và NAT Outside]

Trên thiết bị `NAT` có địa chỉ quản trị `192.168.122.103`, quản trị viên mở *NAT* $arrow$ thẻ *Interfaces* để xác định hướng lưu lượng cho từng cổng. Hai cổng `GigabitEthernet0/1` và `GigabitEthernet0/3` được đánh dấu là *Inside*, trong khi `GigabitEthernet0/2` được đánh dấu là *Outside*.

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/01-nat-interfaces.png", width: 90%),
  caption: [Giao diện cấu hình vai trò phía trong và phía ngoài trên bộ định tuyến NAT],
) <fig-k3-nat-interfaces>

@fig-k3-nat-interfaces cho thấy ba cổng đã được lưu ở trạng thái mong muốn: `Gi0/1` và `Gi0/3` có vai trò `Inside`, còn `Gi0/2` có vai trò `Outside`. Thông tin này được kiểm tra trước khi CAMS sinh tập lệnh cấu hình.

#step-title[Bước 2. Tạo Access Control List cho dải địa chỉ được phép NAT]

Tại thẻ *ACL* của nhóm NAT, quản trị viên tạo ACL chuẩn có tên `NAT_demo`, hành động `permit`, áp dụng cho mạng nguồn `192.168.0.0` với wildcard mask `0.0.7.255`. Wildcard này tương ứng với prefix `192.168.0.0/21`, bao phủ LAN `192.168.4.0/24` và các mạng nội bộ `.1.0/24`, `.2.0/24`; không bao phủ mạng quản trị `192.168.122.0/24`.

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/02-nat-acl.png", width: 90%),
  caption: [Khai báo ACL NAT_demo xác định các mạng nội bộ được phép chuyển đổi địa chỉ],
) <fig-k3-nat-acl>

Sau khi lưu các tham số cổng và ACL, người dùng mở cửa sổ *View & Push* để kiểm duyệt tập lệnh trước khi gửi xuống thiết bị.

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/03-nat-config-preview.png", width: 78%),
  caption: [Cửa sổ View & Push sinh cấu hình cổng NAT và ACL cho bộ định tuyến NAT],
) <fig-k3-nat-preview>

@fig-k3-nat-preview cho thấy CAMS sinh các lệnh `ip nat inside`, `ip nat outside` trên từng cổng và khối ACL sau:
```text
ip access-list standard NAT_demo
 10 permit 192.168.0.0 0.0.7.255
```
Người dùng đối chiếu toàn bộ lệnh trước khi nhấn *Push*, theo cùng quy trình lưu tạm và kiểm duyệt đã sử dụng ở các kịch bản trước.

#step-title[Bước 3. Cấu hình PAT Overload bằng địa chỉ của cổng Outside]

Sau khi xác định phía trong, phía ngoài và ACL, quản trị viên chuyển sang thẻ *PAT*. Tại đây, ACL `NAT_demo` được chọn làm nguồn cần chuyển đổi, trường *Source Type* được đặt là *Outside Interface* và cổng `GigabitEthernet0/2` được sử dụng làm địa chỉ đại diện phía ngoài.

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/04-nat-pat.png", width: 90%),
  caption: [Giao diện cấu hình PAT Overload sử dụng cổng Outside GigabitEthernet0/2],
) <fig-k3-pat-gui>

Cửa sổ *View & Push* cho thấy lệnh PAT được sinh tự động:

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/05-nat-pat-preview.png", width: 78%),
  caption: [Cửa sổ View & Push kiểm duyệt lệnh PAT quá tải trước khi triển khai trên bộ định tuyến NAT],
) <fig-k3-pat-preview>

```text
ip nat inside source list NAT_demo interface GigabitEthernet0/2 overload
```

Lệnh trên cho phép nhiều địa chỉ IPv4 trong mạng nội bộ dùng chung địa chỉ IP của cổng `Gi0/2`; các phiên kết nối được phân biệt bằng số hiệu cổng ở tầng vận chuyển (Port Address Translation - PAT).

#step-title[Bước 4. Xác minh cấu hình NAT/PAT trên thiết bị]

Sau khi triển khai cấu hình, quản trị viên mở đầu cuối tích hợp để kiểm tra bộ định tuyến NAT. Kết quả xác nhận `Gi0/1` và `Gi0/3` đã nhận lệnh `ip nat inside`, còn `Gi0/2` đã nhận lệnh `ip nat outside`.

#figure(
  image("/00_book/figures/report/terminal-generated/nat-interfaces.png", width: 62%),
  caption: [Xác minh vai trò NAT trên ba cổng của bộ định tuyến bằng lệnh `show running-config`],
) <fig-k3-nat-interface-verify>

Tiếp tục kiểm tra cấu hình tổng thể cho thấy lệnh PAT, ACL `NAT_demo` và tuyến mặc định tới `10.0.10.1` đã tồn tại trong running-config.

#figure(
  image("/00_book/figures/report/terminal-generated/nat-config.png", width: 90%),
  caption: [Xác minh ACL, PAT quá tải và tuyến mặc định trên bộ định tuyến NAT],
) <fig-k3-nat-config-verify>

#step-title[Bước 5. Thiết lập GLBP làm cổng mặc định dự phòng]

Để tránh phụ thuộc vào một bộ định tuyến làm cổng mặc định duy nhất, quản trị viên mở *FHRP* $arrow$ *GLBP*. Hai bộ định tuyến `R1` (`192.168.122.101`) và `R2` (`192.168.122.102`) được chọn làm thành viên của nhóm `113`, sử dụng địa chỉ cổng mặc định ảo `192.168.4.1` trên mạng LAN `192.168.4.0/24`.

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/08-glbp-setup.png", width: 86%),
  caption: [Giao diện tạo GLBP Group 113 với Virtual IP 192.168.4.1 trên R1 và R2],
) <fig-k3-glbp-setup>

Tại phần *Member policy*, CAMS tự động ghép các cổng cùng mạng con với địa chỉ IP ảo. Cổng `Gi0/0` của `R1` (`192.168.4.2/24`) có mức ưu tiên `101`, còn cổng `Gi0/0` của `R2` (`192.168.4.3/24`) có mức ưu tiên `100`. Cả hai đều bật `Preempt`, sử dụng `Maximum Weighting 100` và đặt `Forwarder Preempt Delay` là `30` giây.

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/09-glbp-member-policy.png", width: 86%),
  caption: [Thiết lập chính sách thành viên GLBP cho R1 và R2],
) <fig-k3-glbp-member-policy>

Trước khi áp dụng, cửa sổ *View & Push FHRP* tổng hợp lệnh cho cả hai thiết bị trong cùng một phiên kiểm duyệt.

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/10-glbp-config-preview.png", width: 80%),
  caption: [Cửa sổ View & Push FHRP sinh đồng thời cấu hình GLBP cho R1 và R2],
) <fig-k3-glbp-preview>

@fig-k3-glbp-preview cho thấy CAMS sinh cấu hình nhóm GLBP 113 trên cả hai bộ định tuyến, gồm địa chỉ ảo, chế độ cân bằng tải, trọng số và tùy chọn giành lại vai trò (`preempt`). `R1` có mức ưu tiên 101, cao hơn `R2` với mức 100, phù hợp với chính sách đã khai báo.

#step-title[Bước 6. Tạo vùng cấp phát DHCP với địa chỉ GLBP làm cổng mặc định]

Sau khi thiết lập cổng mặc định ảo, quản trị viên chuyển sang `R1`, mở *DHCP* và tạo vùng cấp phát `LAN_R1` cho mạng `192.168.4.0/24`. Trường *Default Router* được đặt là địa chỉ IP ảo `192.168.4.1` của GLBP thay vì địa chỉ vật lý của riêng `R1` hoặc `R2`.

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/11-dhcp-pool.png", width: 88%),
  caption: [Giao diện tạo vùng cấp phát DHCP LAN_R1 với địa chỉ GLBP 192.168.4.1 làm cổng mặc định],
) <fig-k3-dhcp-pool>

Cửa sổ kiểm duyệt cho thấy cấu hình DHCP được sinh tương ứng:

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/13-dhcp-config-preview.png", width: 78%),
  caption: [Cửa sổ View & Push DHCP sinh cấu hình vùng cấp phát LAN_R1 trên R1],
) <fig-k3-dhcp-preview>

```text
ip dhcp pool LAN_R1
 network 192.168.4.0 255.255.255.0
 default-router 192.168.4.1
 exit
```

Với cấu hình này, máy trạm được cấp cổng mặc định logic `192.168.4.1` của nhóm GLBP. Khối lệnh được chụp chưa thể hiện `ip dhcp excluded-address`, `dns-server` hoặc `lease`; bộ minh chứng này chưa xác nhận cấu hình các tham số đó. Phạm vi loại trừ địa chỉ IP ảo và địa chỉ IP tĩnh của cổng mặc định cần được kiểm tra khi hoàn thiện kịch bản. Kết quả địa chỉ `.4` của máy khách dưới đây thuộc cấu hình đã chụp, chưa xác minh việc cấp phát sau khi điều chỉnh dải loại trừ.

#step-title[Bước 7. Xác minh DHCP và GLBP trên R1, R2]

Trên `R1`, lệnh `show ip dhcp pool` xác nhận vùng cấp phát `LAN_R1` đã được tạo cho mạng `192.168.4.0/24`. Đồng thời, `show running-config interface g0/0` xác nhận cổng LAN `192.168.4.2/24` đang tham gia nhóm GLBP `113`, có địa chỉ IP ảo `192.168.4.1`, độ ưu tiên `101` và bật `preempt`.

#figure(
  image("/00_book/figures/report/terminal-generated/r1-dhcp-glbp.png", width: 74%),
  caption: [Xác minh vùng cấp phát DHCP và cấu hình GLBP trên bộ định tuyến R1],
) <fig-k3-r1-verify>

Trên `R2`, cổng `Gi0/0` mang địa chỉ `192.168.4.3/24` và tham gia cùng nhóm GLBP `113` với địa chỉ IP ảo `192.168.4.1`. Kết quả này xác nhận hai bộ định tuyến đã được khai báo trong cùng nhóm cổng mặc định ảo trên một mạng LAN.

#figure(
  image("/00_book/figures/report/terminal-generated/r2-glbp.png", width: 84%),
  caption: [Xác minh cấu hình nhóm GLBP 113 trên bộ định tuyến R2],
) <fig-k3-r2-verify>

#step-title[Bước 8. Kiểm tra cấp phát DHCP và đường đi của lưu lượng]

Cuối cùng, trên máy trạm `PC1`, lệnh `ip dhcp` được sử dụng để yêu cầu cấp phát địa chỉ. Máy trạm nhận địa chỉ `192.168.4.4/24` cùng cổng mặc định `192.168.4.1`.

#figure(
  image("/00_book/figures/report/terminal-generated/pc1-dhcp-trace.png", width: 84%),
  caption: [Kiểm tra PC1 nhận DHCP và truy vết đường đi qua cổng GLBP tới bộ định tuyến NAT cùng mạng phía ngoài],
) <fig-k3-client-test>

Lệnh `trace 1.1.1.1` trong @fig-k3-client-test đi qua `192.168.4.2` (`R1`), `192.168.1.2` (bộ định tuyến NAT) rồi `10.0.10.1` (cổng phía ngoài). ICMP Type 3 Code 3 là phản hồi kết thúc bình thường của truy vết UDP khi gói thăm dò tới đích @ciscoTracerouteGuide. Tuy nhiên, địa chỉ phản hồi cuối khác `1.1.1.1`, nên cần đối chiếu địa chỉ cổng hoặc bổ sung phép thử ICMP trước khi kết luận về đích cuối.

==== Đánh giá kết quả

CAMS đã triển khai chuỗi chức năng DHCP, GLBP và NAT/PAT trên nhiều thiết bị. Máy trạm nhận địa chỉ `192.168.4.4/24` và cổng mặc định ảo `192.168.4.1`; `R1` và `R2` cùng tham gia nhóm GLBP 113; bộ định tuyến NAT nhận đúng vai trò phía trong, phía ngoài, ACL và cấu hình PAT quá tải theo cơ chế chuyển đổi địa chỉ và cổng @rfc3022. Kết quả truy vết ghi nhận lưu lượng đi từ LAN qua `R1`, bộ định tuyến NAT và tới cổng phía ngoài `10.0.10.1`.


Minh chứng hiện có xác nhận cấu hình GLBP trên R1/R2 và cấp phát DHCP trên PC1; chưa có kết quả trạng thái AVG/AVF, phép ngắt cổng mặc định hoặc kiểm tra phân bố tải. DHCP được cấu hình trên R1, chưa chứng minh khả năng dự phòng DHCP trên R2. Cấu hình PAT đã có trong `running-config`, nhưng chưa có kết quả `show ip nat translations` hoặc thống kê phiên để định lượng hoạt động chuyển đổi. Vì vậy, các ảnh cấu hình chưa đủ để kết luận đã kiểm chứng chuyển đổi dự phòng, cân bằng tải hoặc toàn bộ phiên NAT.

=== Kịch bản 4: Thu thập, giám sát và phân tích nhật ký bằng bộ thu nhận Syslog

==== Mục tiêu và quy hoạch nguồn gửi Syslog

Kịch bản 4 kiểm tra khả năng cấu hình Syslog theo nhóm trên nhiều thiết bị Cisco, đồng thời đánh giá việc tiếp nhận, phân tích, hiển thị và gửi cảnh báo qua thư điện tử trong CAMS. Ba bộ định tuyến `R1`, `R2`, `R3` và bộ chuyển mạch `SW1` cùng gửi bản tin về máy chủ `192.168.122.1` qua cổng `5514/UDP`. Nội dung kiểm tra gồm cấu hình trên thiết bị; khả năng phân tách nguồn gửi, địa chỉ IP nguồn, nhóm nguồn Syslog, mức độ nghiêm trọng, mã sự kiện và nội dung gốc; cùng khả năng chuyển hai mức cảnh báo đã chọn qua SMTP.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/syslog-lab-topology-report.png", width: 92%),
  caption: [Sơ đồ Kịch bản 4: Thu thập Syslog tập trung],
) <fig-topo-scenario-4>

Nguồn gửi và chính sách Syslog được trình bày trong bảng quy hoạch dưới đây.

#report-table(
  columns: (11%, 24%, 27%, 38%),
  text-size: 9.5pt,
  cell-inset: (x: 4pt, y: 4.5pt),
  header: ([Thiết bị], [Địa chỉ IP quản trị], [Cổng nguồn], [Chính sách gửi Syslog]),
  rows: (
    (
      [R1],
      [#table-code("192.168.122.101")],
      [#table-code("GigabitEthernet0/0")],
      [#table-code("192.168.122.1:5514/UDP"), mức #table-code("notifications")],
    ),
    (
      [R2],
      [#table-code("192.168.122.102")],
      [#table-code("GigabitEthernet0/0")],
      [#table-code("192.168.122.1:5514/UDP"), mức #table-code("notifications")],
    ),
    (
      [R3],
      [#table-code("192.168.122.103")],
      [#table-code("GigabitEthernet0/0")],
      [#table-code("192.168.122.1:5514/UDP"), mức #table-code("notifications")],
    ),
    (
      [SW1],
      [#table-code("192.168.122.104")],
      [#table-code("Vlan1")],
      [#table-code("192.168.122.1:5514/UDP"), mức #table-code("notifications")],
    ),
  ),
  caption: [Bảng quy hoạch nguồn gửi Syslog trong Kịch bản 4],
) <tab-syslog-planning-lab4>

==== Quy trình triển khai trên phần mềm CAMS

#step-title[Bước 1. Chuẩn bị cấu hình đích nhận Syslog]

Từ thiết bị đang được quản lý, quản trị viên mở thẻ *Syslog Server*. Ban đầu, chưa có đích Syslog nào được cấu hình nên các chỉ số *Destinations*, *Applied*, *Pending apply* và *Pending removal* đều bằng `0`. Người dùng chọn *Syslog Group* để tạo một chính sách chung cho nhiều thiết bị thay vì khai báo riêng cho từng bộ định tuyến hoặc bộ chuyển mạch.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/01-syslog-configuration.png", width: 92%),
  caption: [Giao diện quản lý Syslog Server trước khi tạo chính sách gửi bản tin],
) <fig-k4-syslog-config>

@fig-k4-syslog-config thể hiện màn hình quản lý đích Syslog. Tại đây, người dùng có thể tạo cấu hình đơn lẻ, kiểm duyệt lệnh bằng *View & Push* hoặc áp dụng chính sách theo nhóm bằng *Syslog Group*.

#step-title[Bước 2. Chọn các thiết bị tham gia Syslog Group]

Tại bước *Hosts*, quản trị viên chọn cả bốn thiết bị đang kết nối gồm `R1`, `R2`, `R3` và `SW1`. Hệ thống hiển thị số lượng cổng phát hiện được trên từng thiết bị để làm dữ liệu đầu vào cho bước chọn cổng nguồn.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/02-syslog-select-hosts.png", width: 78%),
  caption: [Bước Hosts của Syslog Group: chọn bốn thiết bị cùng tham gia chính sách gửi bản tin],
) <fig-k4-syslog-hosts>

Việc nhóm nhiều thiết bị trong một quy trình giúp giảm thao tác lặp lại và duy trì thống nhất địa chỉ máy chủ, giao thức vận chuyển cùng mức độ nghiêm trọng cho toàn bộ nhóm.

#step-title[Bước 3. Chọn cổng nguồn cho từng thiết bị]

Tại bước *Interfaces*, CAMS cho phép chọn cổng nguồn riêng cho từng thiết bị. Ba bộ định tuyến sử dụng `GigabitEthernet0/0` trên mạng quản trị `192.168.122.0/24`, còn bộ chuyển mạch `SW1` sử dụng cổng logic `Vlan1`.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/03-syslog-source-interfaces.png", width: 78%),
  caption: [Lựa chọn cổng nguồn cho từng bộ định tuyến và bộ chuyển mạch trong Syslog Group],
) <fig-k4-syslog-source>

Cấu hình `logging source-interface` tạo địa chỉ nguồn ổn định cho các bản tin Syslog, nhờ đó CAMS có thể ánh xạ bản tin đến đúng thiết bị trong danh sách quản lý.

#step-title[Bước 4. Khai báo chính sách Syslog dùng chung]

Tại bước *Policy*, quản trị viên nhập địa chỉ máy chủ `192.168.122.1`, chọn giao thức `UDP`, cổng `5514` và đặt *Trap severity* là `5 - Notifications`. Hai tùy chọn *Include millisecond log timestamps* và *Include sequence numbers* được bật để hỗ trợ sắp xếp và đối chiếu sự kiện chính xác hơn. CAMS sử dụng cổng `5514` thay vì cổng Syslog chuẩn `514/UDP` để tiến trình không cần quyền quản trị khi liên kết với cổng nhỏ hơn 1024. Địa chỉ, giao thức và cổng ở phía thiết bị phải khớp với bộ nhận; số cổng này là cấu hình của kịch bản, không thay đổi cổng chuẩn của giao thức.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/04-syslog-policy.png", width: 78%),
  caption: [Thiết lập đích Syslog 192.168.122.1:5514/UDP và mức Notifications],
) <fig-k4-syslog-policy>

Với mức `notifications`, thiết bị gửi các bản tin có mức độ nghiêm trọng từ 0 đến 5 tới máy chủ Syslog. Phạm vi này phù hợp với bài thử vì bao gồm sự kiện thay đổi trạng thái cổng, thông báo cấu hình và các bản tin do người quản trị chủ động tạo.

#step-title[Bước 5. Kiểm duyệt tập lệnh trước khi đẩy cấu hình]

Sau khi hoàn tất ba bước của trình hướng dẫn, CAMS mở cửa sổ *View & Push Syslog Group* để tổng hợp cấu hình cho cả bốn thiết bị. Quản trị viên có thể xem toàn bộ lệnh trước khi nhấn *Push*.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/05-syslog-config-preview.png", width: 82%),
  caption: [Cửa sổ View & Push Syslog Group tổng hợp lệnh cho 4 thiết bị trước khi thực thi],
) <fig-k4-syslog-preview>

Với bộ định tuyến, cửa sổ trong @fig-k4-syslog-preview hiển thị các lệnh tiêu biểu:
```text
logging host 192.168.122.1 transport udp port 5514
logging trap notifications
service timestamps log datetime msec
service sequence-numbers
logging source-interface GigabitEthernet0/0
```
Đối với `SW1`, lệnh cuối sử dụng `logging source-interface Vlan1`. CAMS nhờ đó áp dụng được một chính sách chung mà vẫn giữ đúng cổng nguồn của từng bộ định tuyến và bộ chuyển mạch.

#step-title[Bước 6. Xác minh cấu hình trên R1, R2, R3 và SW1]

Sau khi CAMS báo triển khai cấu hình thành công, quản trị viên mở đầu cuối tích hợp và thực hiện lệnh `show running-config | section logging` trên từng thiết bị. Kết quả trên `R1`, `R2` và `R3` đều ghi nhận máy chủ `192.168.122.1`, giao thức UDP, cổng `5514`, mức `notifications` và cổng nguồn `GigabitEthernet0/0`.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/06-syslog-r1-verify.png", width: 88%),
  caption: [Xác minh cấu hình Syslog trên bộ định tuyến R1],
) <fig-k4-r1-verify>

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/07-syslog-r2-verify.png", width: 88%),
  caption: [Xác minh cấu hình Syslog trên bộ định tuyến R2],
) <fig-k4-r2-verify>

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/08-syslog-r3-verify.png", width: 88%),
  caption: [Xác minh cấu hình Syslog trên bộ định tuyến R3],
) <fig-k4-r3-verify>

Trên bộ chuyển mạch `SW1`, cấu hình tương tự nhưng sử dụng `Vlan1` làm cổng nguồn.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/09-syslog-sw1-verify.png", width: 88%),
  caption: [Xác minh cấu hình Syslog trên bộ chuyển mạch SW1 với cổng nguồn Vlan1],
) <fig-k4-sw1-verify>

Kết quả xác minh cho thấy cấu hình trên thiết bị khớp với nội dung đã xem trước. Qua đó, quy trình chọn *Syslog Group*, xem trước và triển khai, rồi xác minh đã hoạt động trên cả bộ định tuyến và bộ chuyển mạch.

#step-title[Bước 7. Khởi động bộ thu nhận Syslog tích hợp trong CAMS]

Tiếp theo, quản trị viên chuyển sang màn hình *System Logs*. Trước khi khởi động, trạng thái hiển thị *Listener stopped*, số bản tin nhận được bằng `0` và bảng nhật ký chưa có dữ liệu.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/10-syslog-listener-before-start.png", width: 94%),
  caption: [Màn hình System Logs trước khi khởi động bộ thu nhận Syslog],
) <fig-k4-listener-before>

Sau khi nhấn *Start Listener*, dịch vụ chuyển sang trạng thái *Listener active* và lắng nghe trên `0.0.0.0:5514/UDP+TCP`. Khi các thiết bị phát sinh sự kiện, bản tin được đưa trực tiếp vào bảng *System Logs*.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/11-syslog-listener-receiving.png", width: 94%),
  caption: [Bộ thu nhận Syslog đang hoạt động và tiếp nhận bản tin từ các thiết bị mạng],
) <fig-k4-listener-active>

Tại thời điểm ghi nhận trong @fig-k4-listener-active, hệ thống đã tiếp nhận `245` bản tin. Mỗi bản tin được phân tách thành các trường *Time*, *Host*, *Source IP*, *Facility/Severity*, *Mnemonic* và *Message*. Các sự kiện `LINK`, `LINEPROTO` và `SYS` được phân loại theo nguồn gửi và mã sự kiện.

#step-title[Bước 8. Kiểm tra khả năng phân tích một bản tin Syslog]

Khi chọn một dòng nhật ký, CAMS mở cửa sổ *System Log Message* để hiển thị dữ liệu đã phân tích cùng bản tin nguyên gốc. Mẫu từ `192.168.122.101` sử dụng giao thức UDP, có PRI bằng `189`, nhóm nguồn Syslog bằng `23` (`local7`), mã phân hệ Cisco IOS là `LINEPROTO`, mức độ nghiêm trọng bằng `5` và mã sự kiện `UPDOWN`. Nhóm nguồn Syslog được tính từ PRI, còn mã `LINEPROTO` xác định phân hệ sinh sự kiện trên Cisco IOS. Ảnh giao diện ghi số thứ tự `104` và trạng thái *parsed*; bản tin gốc còn có tiền tố `000108` nên phải giữ đủ nội dung khi đối chiếu.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/12-syslog-message-detail.png", width: 68%),
  caption: [Cửa sổ chi tiết một bản tin Syslog sau khi được phân tích],
) <fig-k4-message-detail>

Phần bản tin gốc (*Raw message*) vẫn được giữ nguyên để phục vụ đối chiếu khi cần:
```text
<189>104: 000108: *Aug 29 20:25:44.323: %LINEPROTO-5-UPDOWN:
Line protocol on Interface Loopback99, changed state to down
```
Dấu `*` trước thời gian Cisco cho biết đồng hồ chưa được đồng bộ. @fig-k4-message-detail lại hiển thị *synchronized*, không nhất quán với bản tin gốc và không được dùng làm bằng chứng đồng bộ. Sai lệch này cho thấy cần giữ bản tin gốc để kiểm tra kết quả phân tích.

#step-title[Bước 9. Tạo sự kiện kiểm thử và đối chiếu với bộ thu nhận Syslog]

Để tạo lượng nhật ký có thể quan sát và lặp lại, nhóm thử nghiệm lần lượt thay đổi trạng thái `Loopback99` trên các bộ định tuyến và trạng thái cổng `GigabitEthernet1/3` trên bộ chuyển mạch. Các thiết bị phát sinh những bản tin thuộc nhóm `USERLOG_WARNING`, `USERLOG_NOTICE`, `LINK`, `LINEPROTO` và `CONFIG_I`.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/13-syslog-r1-device-logs.png", width: 94%),
  caption: [Nhật ký sự kiện kiểm thử phát sinh trực tiếp trên bộ định tuyến R1],
) <fig-k4-r1-device-logs>

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/14-syslog-r2-device-logs.png", width: 94%),
  caption: [Nhật ký sự kiện kiểm thử phát sinh trực tiếp trên bộ định tuyến R2],
) <fig-k4-r2-device-logs>

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/15-syslog-r3-device-logs.png", width: 94%),
  caption: [Nhật ký sự kiện kiểm thử phát sinh trực tiếp trên bộ định tuyến R3],
) <fig-k4-r3-device-logs>

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/16-syslog-sw1-device-logs.png", width: 94%),
  caption: [Nhật ký sự kiện kiểm thử phát sinh trực tiếp trên bộ chuyển mạch SW1],
) <fig-k4-sw1-device-logs>

Từ @fig-k4-r1-device-logs đến @fig-k4-sw1-device-logs trình bày chuỗi sự kiện ghi nhận trên bốn thiết bị. Khi thực hiện `shutdown` hoặc `no shutdown`, Cisco IOS phát sinh thông báo về trạng thái liên kết và giao thức đường truyền; các bản tin `USERLOG_*` đánh dấu từng chu kỳ thử nghiệm. Những sự kiện tương ứng xuất hiện trên *System Logs* và được gắn đúng nguồn gửi.

#step-title[Bước 10. Cấu hình cảnh báo Syslog qua thư điện tử]

Quản trị viên mở *Settings → Email Alerts* và bật tùy chọn gửi cảnh báo. Cấu hình thử nghiệm sử dụng máy chủ `smtp.gmail.com`, cổng `465`, tài khoản gửi `cams.syslog.alert@gmail.com` và địa chỉ nhận `nguyenquocviet15t12@gmail.com`. Các mức từ `0` đến `4` được chọn để bao phủ nhóm khẩn cấp, nghiêm trọng, lỗi và cảnh báo. Khoảng chống gửi trùng được đặt là `300` giây; cửa sổ gom bản tin là `10` giây.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/17-email-alert-settings.png", width: 96%),
  caption: [Cấu hình mức cảnh báo, tài khoản SMTP và người nhận trên Email Alerts],
) <fig-k4-email-settings>

@fig-k4-email-settings cho thấy mật khẩu ứng dụng chỉ xuất hiện dưới dạng ký tự che khuất. CAMS lưu giá trị này ở dạng mã hóa và không trả nội dung bí mật về giao diện. Nút *Send test email* cho phép kiểm tra cấu hình trước khi bật luồng cảnh báo thực tế.

#step-title[Bước 11. Minh họa thư cảnh báo do CAMS tự động gửi]

Sau khi hoàn tất cấu hình tại @fig-k4-email-settings và bật chức năng gửi cảnh báo, CAMS theo dõi các bản tin do bộ thu nhận Syslog tiếp nhận. Mỗi bản tin sau khi được phân tích và lưu trữ được đối chiếu với các mức cảnh báo đã chọn. Sự kiện phù hợp được đưa vào hàng đợi gửi thư; ứng dụng tạo đồng thời nội dung văn bản thuần và HTML, sau đó gửi qua máy chủ `smtp.gmail.com:465` tới địa chỉ nhận đã cấu hình. Luồng SMTP chạy tách biệt với bộ thu nhận nên không làm gián đoạn quá trình tiếp nhận Syslog.

Để minh họa kết quả của chức năng này, báo cáo lựa chọn hai thư đại diện gắn với các sự kiện đã trình bày ở Bước 9: `%LINK-3-UPDOWN` mức `3 - Error` của `SW1` và `%SYS-4-USERLOG_WARNING` mức `4 - Warning` của `R1`. Thư mức Error tại @fig-k4-email-error cho thấy cách CAMS trình bày địa chỉ nguồn `192.168.122.104`, số thứ tự `110`, PRI `187`, nhóm nguồn Syslog `23` (`local7`) và mã Cisco `%LINK-3-UPDOWN`.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/lv3.png", width: 88%),
  caption: [Minh họa thư cảnh báo mức Error cho sự kiện `%LINK-3-UPDOWN` trên SW1],
) <fig-k4-email-error>

Thư mức Warning tại @fig-k4-email-warning giữ cùng cấu trúc nhưng sử dụng dữ liệu của `R1`: địa chỉ nguồn `192.168.122.101`, số thứ tự `98`, PRI `188`, nhóm nguồn Syslog `23` và mã Cisco `%SYS-4-USERLOG_WARNING`. Nội dung `DEMO-R1 CYCLE=5/5 Loopback99=DOWN` trùng với dấu mốc xuất hiện trong ảnh đầu cuối của `R1`. Dấu `*` trước thời gian thiết bị được giữ trong bản tin gốc và được biểu diễn thành trạng thái *Chưa đồng bộ* trong phần chi tiết.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/lv4.png", width: 88%),
  caption: [Minh họa thư cảnh báo mức Warning cho sự kiện `%SYS-4-USERLOG_WARNING` trên R1],
) <fig-k4-email-warning>

Hai hình minh họa cho thấy thư cảnh báo giữ được mối liên hệ với bản tin Syslog nguồn, đồng thời thay đổi nhãn, màu sắc và khuyến nghị theo mức độ nghiêm trọng. Việc đánh giá số lượng thư nhận được, độ trễ, giới hạn lưu lượng hoặc tỷ lệ chuyển thư ở quy mô lớn chưa thuộc phạm vi kịch bản này.

==== Đánh giá kết quả

CAMS đã cấu hình Syslog cho bốn thiết bị và nhận bản tin từ `192.168.122.101` đến `192.168.122.104`. Hệ thống tách nhóm nguồn, mức độ, mã Cisco và nội dung gốc theo cấu trúc Syslog @rfc5424; các sự kiện khớp giữa đầu cuối thiết bị và *System Logs*. Cảnh báo thư điện tử dùng các sự kiện Error và Warning đã ghi nhận, đồng thời tách luồng SMTP khỏi bộ nhận. Quy trình lưu và đối chiếu phù hợp với nguyên tắc quản lý nhật ký tập trung @nistSp80092.


=== Kịch bản 5: Kiểm chứng chính sách ACL và nhật ký an ninh tập trung

==== Mục tiêu và phạm vi

Kịch bản 5 kiểm chứng chuỗi xử lý từ chính sách đến bằng chứng vận hành: CAMS tạo ACL có ghi nhật ký, triển khai ACL lên đúng cổng vào của VLAN, thiết bị cho phép hoặc từ chối lưu lượng theo từng luật, sau đó gửi sự kiện về System Logs. Kịch bản tập trung vào ba chính sách cụ thể: chặn Telnet từ VLAN 10 đến địa chỉ `192.168.12.2`, chặn HTTP từ VLAN 20 đến máy chủ `203.162.4.1`, và chặn ICMP từ VLAN 30 đến máy chủ này. Các lưu lượng không khớp luật từ chối phải tiếp tục được chuyển tiếp.

Phép thử được thiết kế theo cặp đối chứng. Mỗi chính sách có một lưu lượng cần bị chặn và một lưu lượng khác cần được phép. Cách kiểm tra này phân biệt trường hợp ACL hoạt động đúng với trường hợp mất kết nối do định tuyến, máy chủ hoặc cấu hình nền chưa hoàn tất.

==== Mô hình và quy hoạch địa chỉ

@fig-k5-topology trình bày mô hình thử nghiệm. `R1` thực hiện định tuyến giữa các VLAN theo mô hình bộ định tuyến dùng một liên kết trung kế trên `GigabitEthernet0/1`; `R2` là bộ định tuyến biên thực hiện NAT; `R3` đóng vai trò ISP và cung cấp dịch vụ HTTP trên `Loopback0`. Ba máy trạm `VPC7`, `VPC8` và `VPC9` lần lượt thuộc VLAN 10, VLAN 20 và VLAN 30. Sơ đồ thể hiện các liên kết kép giữa ba bộ chuyển mạch; phần thử nghiệm ACL không cung cấp kết quả lệnh xác minh EtherChannel, nên không kết luận trạng thái gom kênh chỉ từ sơ đồ.

#figure(
  image("/00_book/figures/report/diagrams/acl-lab5/topology-redrawn.svg", width: 100%),
  caption: [Mô hình kiểm chứng ACL với R1 định tuyến liên VLAN, R2 làm NAT và R3 làm ISP (vẽ lại từ topology EVE-NG)],
) <fig-k5-topology>

#report-table(
  columns: (29%, 35%, 36%),
  header: ([Thành phần], [Địa chỉ], [Vai trò trong phép thử]),
  rows: (
    ([R1 `Gi0/1.10`], [`192.168.10.254/24`], [Cổng mặc định VLAN 10; nhận lưu lượng từ VPC7.]),
    ([R1 `Gi0/1.20`], [`192.168.20.254/24`], [Cổng mặc định VLAN 20; nhận lưu lượng từ VPC8.]),
    ([R1 `Gi0/1.30`], [`192.168.30.254/24`], [Cổng mặc định VLAN 30; nhận lưu lượng từ VPC9.]),
    ([R1 `Gi0/2` - R2 `Gi0/2`], [`192.168.12.2/24` - `192.168.12.1/24`], [Liên kết từ mạng doanh nghiệp đến bộ định tuyến biên.]),
    ([R2 `Gi0/3` - R3 `Gi0/3`], [`203.162.2.1/30` - `203.162.2.2/30`], [Liên kết đến ISP.]),
    ([R3 `Loopback0`], [`203.162.4.1/32`], [Đích ICMP và máy chủ HTTP thử nghiệm.]),
    ([Mạng quản trị], [`192.168.122.0/24`], [CAMS kết nối đến thiết bị; R1 dùng `192.168.122.104` trong lần thử.]),
  ),
  caption: [Quy hoạch địa chỉ liên quan đến Kịch bản 5],
) <tab-k5-address-plan>

Địa chỉ quản trị chỉ phục vụ kết nối CAMS và vận chuyển Syslog, không tham gia điều kiện khớp ACL. Vì vậy, việc R1 mang địa chỉ quản trị `192.168.122.104` trong lần thử không làm thay đổi các chính sách trên các mạng dữ liệu.

==== Chính sách ACL và vị trí áp dụng

Hai ACL mở rộng được cấu hình trên R1. ACL thứ nhất được gắn chiều vào trên `GigabitEthernet0/1.10`. Luật số 10 từ chối TCP từ VLAN 10 đến địa chỉ `192.168.12.2`, cổng đích 23; luật số 20 cho phép các lưu lượng IP còn lại. Tên `ACL_V10_NO_TELNET_R2` được giữ theo dữ liệu thử nghiệm, nhưng đích `192.168.12.2` thuộc cổng `Gi0/2` của R1 trong quy hoạch hiện tại. Do đó, kết quả được diễn giải theo địa chỉ và giao thức thực tế, không suy luận thiết bị đích từ tên ACL.

ACL thứ hai được gắn chiều vào trên `GigabitEthernet0/1.20` và `GigabitEthernet0/1.30`. Luật số 10 từ chối TCP/80 từ VLAN 20 đến máy chủ `203.162.4.1`; luật số 20 từ chối ICMP từ VLAN 30 đến cùng máy chủ; luật số 30 cho phép các lưu lượng IP còn lại. Mỗi luật do CAMS sinh đều có từ khóa `log`, nên Cisco IOS tạo sự kiện `%SEC-6-IPACCESSLOGP` hoặc `%SEC-6-IPACCESSLOGDP` khi có lưu lượng khớp.

#report-table(
  columns: (15%, 21%, 26%, 21%, 17%),
  text-size: 9.5pt,
  header: ([ACL / luật], [Nguồn], [Đích và dịch vụ], [Hành động], [Vị trí]),
  rows: (
    ([V10 / 10], [#table-code("192.168.10.0/24")], [`192.168.12.2`, TCP/23], [Từ chối, ghi nhật ký], [Chiều vào `Gi0/1.10`]),
    ([V10 / 20], [`any`], [`any`, IP], [Cho phép, ghi nhật ký], [Chiều vào `Gi0/1.10`]),
    ([V20-V30 / 10], [#table-code("192.168.20.0/24")], [`203.162.4.1`, TCP/80], [Từ chối, ghi nhật ký], [Chiều vào `Gi0/1.20`]),
    ([V20-V30 / 20], [#table-code("192.168.30.0/24")], [`203.162.4.1`, ICMP], [Từ chối, ghi nhật ký], [Chiều vào `Gi0/1.30`]),
    ([V20-V30 / 30], [`any`], [`any`, IP], [Cho phép, ghi nhật ký], [Chiều vào `Gi0/1.20` và `.30`]),
  ),
  caption: [Ma trận chính sách ACL được kiểm chứng],
) <tab-k5-acl-policy>

@fig-k5-acl-applied là bằng chứng cấu hình sau triển khai. Kết quả `show ip interface` xác nhận ACL đã được gắn chiều vào trên ba cổng con. Kết quả `show access-lists` xác nhận đúng địa chỉ nguồn, đích, giao thức, cổng dịch vụ và từ khóa `log`. Hình này thay cho chuỗi ảnh nhập biểu mẫu và thao tác *Push* vì mục tiêu của thử nghiệm là chứng minh cấu hình cuối trên thiết bị.

#figure(
  image("/00_report/Tai_lieu_lab/LAB5/ANH_CUA_LAB/1.png", width: 96%),
  caption: [ACL và vị trí áp dụng trên R1 sau khi triển khai bằng CAMS],
) <fig-k5-acl-applied>

==== Phép thử đối chứng và lưu lượng bị chặn

Trước khi tạo lưu lượng vi phạm, nhóm thử nghiệm dùng VPC7 thuộc VLAN 10 kiểm tra đường truyền tới `203.162.4.1`. ICMP nhận đủ năm phản hồi, còn phép thử TCP/80 hoàn tất các bước kết nối, gửi dữ liệu và đóng kết nối. Hai kết quả trong @fig-k5-positive-control xác nhận định tuyến, NAT và dịch vụ đích đang hoạt động; vì vậy, các kết quả bị chặn ở bước tiếp theo có thể được quy cho ACL tương ứng.

#figure(
  grid(
    columns: (1fr, 1fr),
    gutter: 8pt,
    image("/00_report/Tai_lieu_lab/LAB5/ANH_CUA_LAB/3.png", width: 100%),
    image("/00_report/Tai_lieu_lab/LAB5/ANH_CUA_LAB/4.png", width: 100%),
  ),
  caption: [Phép thử đối chứng từ VLAN 10: ICMP và TCP/80 đến máy chủ ISP đều được phép],
) <fig-k5-positive-control>

Ba phép thử âm được thực hiện từ đúng VLAN nguồn của từng luật. VPC7 gửi TCP đến `192.168.12.2:23`; VPC8 gửi TCP đến `203.162.4.1:80`; VPC9 gửi ICMP đến `203.162.4.1`. Trong cả ba trường hợp, cổng mặc định trên R1 trả về ICMP Type 3 Code 13, *Communication administratively prohibited*. Phản hồi này cho biết bộ định tuyến đã chủ động từ chối lưu lượng theo chính sách, thay vì gói tin hết thời gian chờ do mất đường truyền.

#figure(
  grid(
    columns: (1fr, 1fr),
    gutter: 8pt,
    image("/00_report/Tai_lieu_lab/LAB5/ANH_CUA_LAB/5.png", width: 100%),
    image("/00_report/Tai_lieu_lab/LAB5/ANH_CUA_LAB/6.png", width: 100%),
  ),
  caption: [R1 từ chối Telnet từ VLAN 10 và HTTP từ VLAN 20 theo hai luật ACL],
) <fig-k5-denied-tcp>

#figure(
  image("/00_report/Tai_lieu_lab/LAB5/ANH_CUA_LAB/7.png", width: 88%),
  caption: [R1 từ chối ICMP từ VLAN 30 đến máy chủ `203.162.4.1`],
) <fig-k5-denied-icmp>

Để kiểm tra ACL không chặn quá phạm vi, VPC8 vẫn nhận phản hồi ICMP từ máy chủ ISP và VPC9 vẫn thiết lập được phiên TCP/80. Đồng thời, VPC8 và VPC9 vẫn kết nối được TCP/23 đến `192.168.12.2` vì luật chặn dịch vụ này chỉ áp dụng cho VLAN 10. Các phép thử này xác nhận thứ tự luật và câu lệnh `permit ip any any` hoạt động như dự kiến.

==== Đối chiếu sự kiện trên System Logs

R1 gửi Syslog về CAMS qua mạng quản trị. Chính sách gửi phải bao gồm mức `6 - Informational` vì bản tin ACL trong phép thử có mức độ nghiêm trọng bằng 6. Tại thời điểm chụp @fig-k5-acl-syslog, bộ thu C++ đang lắng nghe trên `0.0.0.0:5514/UDP+TCP` và đã nhận 272 bản tin. Các dòng bằng chứng quan trọng gồm:

- `ACL_V10_NO_TELNET_R2 denied tcp 192.168.10.1(...) -> 192.168.12.2(23)`;
- `ACL_V20_V30_OUT denied tcp 192.168.20.1(...) -> 203.162.4.1(80)`;
- `ACL_V20_V30_OUT denied icmp 192.168.30.1 -> 203.162.4.1`;
- các dòng `permitted` tương ứng với những phép thử đối chứng không thuộc điều kiện từ chối.

#figure(
  image("/00_report/Tai_lieu_lab/LAB5/ANH_CUA_LAB/12.png", width: 100%),
  caption: [System Logs ghi nhận các sự kiện ACL được phép và bị từ chối từ R1],
) <fig-k5-acl-syslog>

Trường `SEC` trong bảng là mã phân hệ Cisco IOS; nhóm nguồn Syslog được tách từ PRI. Với PRI bằng 190 trong các bản tin minh họa, nhóm nguồn Syslog bằng 23 (`local7`) và mức độ nghiêm trọng bằng 6. Việc tách hai trường giúp tránh gọi nhầm `SEC` là nhóm nguồn theo chuẩn Syslog.

==== Đánh giá kết quả

#report-table(
  columns: (16%, 32%, 20%, 32%),
  header: ([Ca thử], [Lưu lượng], [Kết quả], [Bằng chứng]),
  rows: (
    ([ACL-01], [VLAN 10 đến `192.168.12.2`, TCP/23], [Bị từ chối], [ICMP Type 3 Code 13 và nhật ký `denied tcp`.]),
    ([ACL-02], [VLAN 20 đến `203.162.4.1`, TCP/80], [Bị từ chối], [ICMP Type 3 Code 13 và nhật ký `denied tcp`.]),
    ([ACL-03], [VLAN 30 đến `203.162.4.1`, ICMP], [Bị từ chối], [Năm phản hồi `administratively prohibited` và nhật ký `denied icmp`.]),
    ([ACL-04], [VLAN 10 đến `203.162.4.1`, ICMP và TCP/80], [Được phép], [Năm phản hồi ICMP và năm chu kỳ kết nối TCP/80.]),
    ([ACL-05], [VLAN 20/30 với lưu lượng không khớp deny], [Được phép], [ICMP, TCP/23 hoặc TCP/80 hoàn tất; System Logs có dòng `permitted`.]),
  ),
  caption: [Kết quả kiểm chứng chính sách ACL trong Kịch bản 5],
) <tab-k5-acl-results>

Kết quả cho thấy hai ACL được áp dụng đúng chiều trên ba cổng con của R1. Ba lưu lượng khớp luật từ chối đều bị R1 chặn và tạo bản tin Syslog; các lưu lượng đối chứng vẫn được chuyển tiếp. CAMS tiếp nhận, phân tích và hiển thị đúng thiết bị nguồn `192.168.122.104`, mã phân hệ `SEC`, mức độ nghiêm trọng bằng 6, mã sự kiện cùng thông tin địa chỉ và dịch vụ. Phạm vi kết luận giới hạn ở các địa chỉ, giao thức và số lần thử nêu trong bảng; kịch bản chưa đo thông lượng ghi nhật ký hoặc tỷ lệ mất bản tin khi tải cao.



== Đánh giá tổng hợp

=== Phạm vi kết quả đã kiểm chứng

#report-table(
  columns: (12%, 48%, 40%),
  header: ([Kịch bản], [Kết quả có bằng chứng], [Giới hạn của kết luận]),
  rows: (
    ([1], [Nguồn cấp DHCP thay đổi theo cổng tin cậy; DAI ghi nhận bản tin ARP không khớp bảng liên kết bị chặn.], [Không đánh giá Port Security hay mọi hình thức tấn công Lớp 2.]),
    ([2], [Cấu hình OSPF trên năm bộ định tuyến; trạng thái láng giềng FULL, tuyến nội vùng; sáu loạt kiểm tra ICMP đều nhận đủ 5/5 hồi đáp và truy vết tới VPC10.], [Không phải tỷ lệ thành công triển khai; chưa đo thời gian thao tác giữa CLI và CAMS hoặc thời gian hội tụ khi mất liên kết.]),
    ([3], [PC1 nhận địa chỉ 192.168.4.4/24 và cổng mặc định 192.168.4.1; xác nhận cấu hình GLBP, PAT và đường đi qua NAT.], [Chưa thử chuyển đổi dự phòng; chưa có bảng phiên NAT.]),
    ([4], [Ảnh bộ nhận ghi nhận 245 bản tin; hai mẫu thư cảnh báo ở mức Error và Warning.], [Bộ đếm là ảnh tại một thời điểm; một trường đồng hồ trong ảnh cũ không nhất quán; chưa đo tỷ lệ mất bản tin hay độ trễ thư cảnh báo.]),
    ([5], [Ba loại lưu lượng bị ACL chặn, có lưu lượng đối chứng được phép và nhật ký tương ứng.], [Chưa đo thông lượng, tải cao hoặc tỷ lệ mất bản tin.]),
  ),
  text-size: 9.5pt,
  caption: [Tổng hợp kết quả và giới hạn kiểm chứng của năm kịch bản],
) <tab-all-lab-results>

Các số bộ đếm ở từng kịch bản là những lần quan sát độc lập. Không cộng số bản tin Syslog thành thông lượng và không dùng số gói ICMP làm số lần triển khai. So sánh thao tác ở kịch bản 2 là ước tính theo cấu hình; nhận xét về tính thuận tiện dựa trên các bước và thông tin hiển thị, chưa phải kết quả đo thời gian hay khảo sát người dùng.

=== Ưu điểm nổi bật

- *Giao diện quản lý tập trung:* CAMS cung cấp một không gian làm việc thống nhất cho các chức năng mạng Lớp 2 và Lớp 3, qua đó giảm số thao tác CLI trực tiếp trên từng thiết bị.
- *Quy trình kiểm duyệt trước khi thực thi:* Cơ chế lưu chờ tách trạng thái mong muốn khỏi trạng thái đã áp dụng. Cửa sổ *View & Push* cho phép kiểm tra tập lệnh trước khi gửi xuống thiết bị.
- *Khả năng xử lý nhiều thiết bị:* cơ chế khóa theo thiết bị (`Host Lock`) tuần tự hóa các lệnh trên cùng một thiết bị, trong khi `BatchExecutor` cho phép xử lý song song các thiết bị độc lập.
- *Các tiện ích hỗ trợ vận hành:* hệ thống tích hợp sao lưu phiên bản bằng Dulwich, bộ thu nhận Syslog, cảnh báo qua thư điện tử, SFTP và đầu cuối nhúng.

=== Hạn chế của thực nghiệm

- *Mẫu thử và điều kiện chạy:* các kết quả được lấy từ những loạt thử cụ thể trên hai môi trường độc lập. Phiên bản IOS đầy đủ và tài nguyên EVE-NG chưa được ghi nhận cho mọi kịch bản; các kết quả này không được dùng để so sánh hiệu năng giữa hai máy.
- *Đánh giá thời gian và khả năng chịu tải:* chưa có phép đo tái lập thời gian thao tác giữa CLI và CAMS, thời gian hội tụ, thông lượng Syslog, tỷ lệ mất bản tin hoặc độ trễ cảnh báo qua thư điện tử. RTT biến động trong kịch bản 2 nên không được dùng để kết luận độ trễ ổn định.
- *Kịch bản sự cố:* DAI và ACL đã có lưu lượng vi phạm cùng đối chứng. Chưa có ca thử mất kết nối khi triển khai, sai thông tin xác thực, thay đổi cấu hình một phần hay ngắt cổng GLBP. Khi lỗi thực thi xảy ra, cần đối chiếu phản hồi và đồng bộ lại; hủy tác vụ không tự hoàn tác lệnh đã gửi. Hạn chế sản phẩm và hướng phát triển được tổng hợp ở Chương 6.
