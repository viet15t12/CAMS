#import "../config/tables.typ": report-table, table-code
#import "../config/commands.typ": report-note, step-title

#pagebreak(weak: true)
= Thử nghiệm và đánh giá

== Mục tiêu và môi trường thử nghiệm

Chương này đánh giá CAMS qua năm kịch bản triển khai mạng trên EVE-NG và thực nghiệm an ninh hệ thống. Các kịch bản tập trung xác minh quy trình cấu hình, phản hồi của thiết bị, cơ chế phân quyền, an toàn mật mã dữ liệu và giám sát nhật ký an ninh trong điều kiện phòng lab.

=== Môi trường thử nghiệm phần mềm và phần cứng

Quá trình đo đạc, kiểm thử và thực nghiệm được tiến hành trong môi trường gồm ba nhóm thành phần:

- *Máy trạm chạy ứng dụng CAMS (Host):*
  - Hệ điều hành: Linux (Fedora 44 hoặc Ubuntu 24.04 LTS).
  - Phần cứng: CPU AMD Ryzen 7 hoặc Intel Core i7, RAM 16 GB.
  - Nền tảng phần mềm: Python 3.11+, PyQt 6.10, Qt 6.10 và SQLite 3 nhúng.
  - Công cụ quản lý phụ thuộc và môi trường thực thi: `uv`.
- *Hạ tầng ảo hóa mạng (Virtual Lab):*
  - Máy chủ ảo hóa: EVE-NG Professional phiên bản 5.0.
  - Bộ định tuyến: Cisco vIOS-L3, Cisco IOS Software phiên bản 15.9(3)M.
  - Thiết bị chuyển mạch: Cisco vIOS-L2, Cisco IOS Software phiên bản 15.2.
- *Mạng quản trị ngoại băng (Out-of-band Management Network):* Các cổng quản trị của router và switch được kết nối vào phân mạng `192.168.122.0/24` (có thể thay đổi tùy theo cấu hình của người thực hành). CAMS sử dụng SSH hoặc Telnet trên mạng này để thu thập trạng thái và đẩy cấu hình xuống thiết bị.

== Kịch bản kiểm thử thực nghiệm trong phòng lab

Phần thực nghiệm gồm năm kịch bản: DHCP Snooping và DAI trong bảo mật Lớp 2; định tuyến OSPF đa vùng; phối hợp GLBP–DHCP–NAT/PAT; thu thập và phân tích nhật ký Syslog; và kiểm thử cơ chế an ninh phân quyền cùng bảo mật dữ liệu lưu trữ. Mỗi kịch bản được thực hiện theo ba giai đoạn:

1. *Thiết lập và xem trước trên giao diện:* người dùng nhập tham số trên biểu mẫu nghiệp vụ. Dữ liệu được lưu ở trạng thái mong muốn (Desired State) và chuyển thành tập lệnh CLI để kiểm tra trong cửa sổ *View & Push*.
2. *Đẩy cấu hình bất đồng bộ:* tác vụ nền lấy thông tin truy cập, áp dụng khóa thiết bị (Host Lock) để tránh tranh chấp luồng lệnh, sau đó gửi tập lệnh qua SSH.
3. *Xác minh trạng thái:* người quản trị đối chiếu phản hồi của hệ thống, kiểm tra trực tiếp bằng terminal tích hợp và đánh giá lưu lượng thực tế.

#include "09_kich_ban_1_snooping.typ"
#include "09_kich_ban_1_dai.typ"

=== Kịch bản 2: Định tuyến động đa vùng và tái phân phối tuyến liên chi nhánh (OSPF Group & Route Redistribution)

==== Mục tiêu và quy hoạch địa chỉ IP

Kịch bản 1 thiết lập OSPFv2 đa vùng để kết nối Chi nhánh A với Chi nhánh B qua đường trục ISP thuộc Backbone Area 0. Tính năng *Routing Group - OSPF* cấu hình đồng thời sáu router `R1`, `R2`, `R3`, `ISP1`, `ISP2` và `R6`; cơ chế tái phân phối đưa các mạng LAN cục bộ vào miền OSPF.

#figure(
  image("/documentation_assets/diagrams/lab-topology/routing-ospf/multi-area-branches-raster.png", width: 95%),
  caption: [Sơ đồ Kịch bản 1: Định tuyến OSPF đa vùng giữa hai chi nhánh],
) <fig-topo-scenario-2>

Mô hình được chia thành các phân vùng định tuyến và dải địa chỉ như trình bày trong bảng quy hoạch dưới đây.

#report-table(
  columns: (20%, 20%, 25%, 35%),
  header: ([Phân vùng mạng], [Thiết bị / Node], [Dải IP / Subnet], [Ghi chú kiến trúc]),
  rows: (
    ([Chi nhánh A], [VPC11 (A1_VLAN)], [192.168.10.10/24], [Gateway: 192.168.10.1 (R2 Gi0/4)]),
    ([Chi nhánh A], [VPC12 (A2_VLAN)], [192.168.20.10/24], [Gateway: 192.168.20.1 (R3 Gi0/4)]),
    ([Chi nhánh A], [R1, R2, R3], [10.1.12.0/24, 10.1.13.0/24, 10.1.23.0/24], [Miền định tuyến OSPF Area 1]),
    (
      [Đường trục ISP],
      [R1, ISP1, ISP2, R6],
      [10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24],
      [Miền đường trục OSPF Backbone Area 0],
    ),
    ([Chi nhánh B], [VPC14 (B1_VLAN)], [192.168.30.10/24], [Gateway: 192.168.30.1 (R6 Gi0/1.30)]),
    ([Chi nhánh B], [VPC15 (B2_VLAN)], [192.168.40.10/24], [Gateway: 192.168.40.1 (R6 Gi0/1.40)]),
    ([Mạng Quản trị], [Toàn bộ Router/SW], [192.168.122.101 -- 109/24], [Kênh Out-of-Band kết nối CAMS]),
  ),
  caption: [Bảng quy hoạch địa chỉ IP và phân vùng OSPF cho Kịch bản 1],
) <tab-ip-planning-lab2>

==== Quy trình triển khai trên phần mềm CAMS

#step-title[Bước 1. Cấu hình interface Lớp 3 và gán địa chỉ IP]

Trước khi triển khai định tuyến, quản trị viên mở *Interfaces* trên CAMS để thiết lập địa chỉ IP, subnet mask và đưa các cổng vật lý (`GigabitEthernet`) vào trạng thái hoạt động.

#figure(
  image("/00_book/figures/report/diagrams/routing-ospf-lab/1.png", width: 85%),
  caption: [Giao diện quản lý và cấu hình tham số Lớp 3 cho các cổng router],
) <fig-k2-interfaces>
@fig-k2-interfaces thể hiện trạng thái IP của các cổng trên `R1`. Ngăn thuộc tính cho phép khai báo địa chỉ IP, subnet mask, mô tả và trạng thái hoạt động của từng cổng.

#step-title[Bước 2. Cấu hình OSPF theo nhóm bằng Routing Group]

Quản trị viên sử dụng *Routing Group - OSPF* để cấu hình đồng thời sáu router `R1`, `R2`, `R3`, `ISP1`, `ISP2` và `R6`.

#figure(
  image("/00_book/figures/report/diagrams/routing-ospf-lab/10.png", width: 80%),
  caption: [Cửa sổ Routing Group - OSPF (Bước 1: Chọn sáu router tham gia cấu hình nhóm)],
) <fig-k2-group-hosts>
Trong @fig-k2-group-hosts, các router được chọn từ không gian làm việc `LAB_KICH_BAN_2`. CAMS sử dụng thông tin của các cổng và địa chỉ IP của từng thiết bị làm dữ liệu đầu vào cho các bước tiếp theo.

Tại bước *Networks*, quản trị viên gán các mạng kết nối trực tiếp vào vùng định tuyến tương ứng: Area 0 cho các liên kết đường trục ISP và Area 1 cho các liên kết nội bộ của Chi nhánh A.

#figure(
  image("/00_book/figures/report/diagrams/routing-ospf-lab/11.png", width: 80%),
  caption: [Cửa sổ Routing Group - OSPF (Bước 4: Khai báo phân vùng mạng và gán OSPF Area tương ứng)],
) <fig-k2-group-networks>
#block[
  #set par(justify: false)
  @fig-k2-group-networks thể hiện các cổng được nhóm theo từng router và ánh xạ mỗi dải mạng vào vùng OSPF tương ứng:
]

#report-table(
  columns: (18%, 52%, 30%),
  header: ([Router], [Dải mạng], [Vùng OSPF]),
  rows: (
    (table.cell(rowspan: 3)[*R1*], [#table-code("10.1.12.0/24")], [Area 1]),
    ([#table-code("10.1.13.0/24")], [Area 1]),
    ([#table-code("10.0.0.0/24")], [Area 0 (Backbone)]),
    (table.cell(rowspan: 2)[*R2*], [#table-code("10.1.12.0/24")], [Area 1]),
    ([#table-code("10.1.23.0/24")], [Area 1]),
  ),
  cell-align: (center + horizon, left + horizon, center + horizon),
  width: 88%,
  text-size: 10.5pt,
  cell-inset: (x: 7pt, y: 6pt),
)

#block[
  #set par(justify: false)
  Sau khi kiểm tra các ánh xạ, quản trị viên nhấn *Save & Push*. Hệ thống sau đó đẩy cấu hình song song xuống toàn bộ router đã chọn.
]

#step-title[Bước 3. Cấu hình tái phân phối tuyến cho mạng LAN]

Để quảng bá các mạng người dùng của hai chi nhánh qua OSPF mà không làm rò rỉ mạng quản trị (Out-of-band), quản trị viên cấu hình *Redistribute Connected Subnets* kết hợp với *Route-Map* trên các router biên `R2`, `R3` và `R6`. Việc sử dụng `route-map` đảm bảo chỉ các mạng LAN (`192.168.10.0/24`, `192.168.20.0/24`, `192.168.30.0/24` và `192.168.40.0/24`) được đưa vào miền OSPF, ngăn chặn rủi ro quảng bá sai mạng quản trị `192.168.122.0/24`.

#figure(
  image("/00_book/figures/report/diagrams/routing-ospf-lab/16.png", width: 85%),
  caption: [Giao diện thiết lập tham số Tái phân phối tuyến (OSPF Redistribute) trên Router biên R6],
) <fig-k2-redistribute-gui>
Tại tab `R6`, quản trị viên mở *Routing*, chọn *OSPF* và mục *Redistribute*. Các tham số được thiết lập như sau:

- Tiến trình OSPF: `1`. (Lưu ý: Không điền Process ID cho nguồn `connected` vì mạng kết nối trực tiếp không có tiến trình định tuyến).
- Nguồn tái phân phối: `connected`.
- Route-Map áp dụng: `LAN_ONLY`.
- Tùy chọn `Subnets`: cho phép quảng bá các mạng con VLSM.

Sau khi kiểm tra tham số, người dùng chọn *+ Add Redistribute* để lưu cấu hình ở trạng thái chờ, rồi mở *View & Push* để kiểm duyệt khối lệnh trước khi gửi xuống router.

#figure(
  image("/00_book/figures/report/diagrams/routing-ospf-lab/14.png", width: 80%),
  caption: [Cửa sổ View & Push OSPF tự động sinh khối lệnh tái phân phối tuyến cho Router R2],
) <fig-k2-redistribute-push>
Cửa sổ kiểm duyệt trong @fig-k2-redistribute-push hiển thị khối lệnh Cisco IOS được sinh cho router `R2`:
```text
# Cấu hình OSPF và Redistribution sinh tự động cho R2
ip prefix-list LAN_NETS permit 192.168.0.0/16 le 24
route-map LAN_ONLY permit 10
 match ip address prefix-list LAN_NETS
 exit
router ospf 1
 router-id 2.2.2.2
 network 10.1.12.0 0.0.0.255 area 1
 network 10.1.23.0 0.0.0.255 area 1
 network 2.2.2.0 0.0.0.255 area 1
 redistribute connected subnets route-map LAN_ONLY
 exit
```
Trong kiến trúc OSPF đa vùng này, router trung tâm `R1` đóng vai trò là ABR (Area Border Router) vì nó kết nối trực tiếp Area 0 và Area 1. Các router `R2`, `R3` và `R6` đóng vai trò là ASBR (Autonomous System Boundary Router) do chúng thực hiện tái phân phối (redistribute) mạng LAN ngoại vi vào tiến trình OSPF. Các mạng LAN này sẽ xuất hiện trên bảng định tuyến của các thiết bị khác dưới dạng tuyến ngoại vi OSPF External Type 2 (`O E2`), thể hiện qua các gói tin LSA Type 5 do ASBR tạo ra.

#step-title[Bước 4. Xác minh cấu hình OSPF trên các thiết bị]

Sau khi đẩy cấu hình, quản trị viên mở các cửa sổ terminal tích hợp để kiểm tra trực tiếp cấu hình đang chạy trên cả sáu router.

#figure(
  image("/00_book/figures/report/terminal-generated/ospf-six-routers.png", width: 96%),
  caption: [Xác minh cấu hình OSPF trên sáu router qua terminal nhúng],
) <fig-k2-multi-terminal-ospf>
Kết quả lệnh `show run | section ospf` trong @fig-k2-multi-terminal-ospf xác nhận cả sáu router đã nhận tiến trình OSPF 1, router ID từ `1.1.1.1` đến `6.6.6.6` và các mạng thuộc Area 0 hoặc Area 1 theo quy hoạch.

#step-title[Bước 5. Kiểm tra bảng định tuyến OSPF]

Quản trị viên thực hiện lệnh `show ip route` trên router trung tâm `R1` để kiểm tra khả năng hội tụ của hệ thống định tuyến:

#figure(
  image("/00_book/figures/report/terminal-generated/r1-ospf-routes.png", width: 94%),
  caption: [Bảng định tuyến trên Router R1 hiển thị đầy đủ các tuyến nội vùng và tuyến ngoại vi O E2],
) <fig-k2-route-table-r1>
Theo @fig-k2-route-table-r1, bảng định tuyến của `R1` ghi nhận:
- Các tuyến nội vùng OSPF (`O`): `2.2.2.2/32`, `3.3.3.3/32`, `4.4.4.4/32`, `5.5.5.5/32`, `6.6.6.6/32` và các mạng liên kết `10.0.2.0/24`, `10.0.3.0/24`, `10.1.23.0/24`.
- Cả bốn mạng LAN của hai chi nhánh được học qua cơ chế tái phân phối tuyến ngoại vi:
  - `O E2 192.168.10.0/24 [110/20] via 10.1.12.2 (R2)`
  - `O E2 192.168.20.0/24 [110/20] via 10.1.13.2 (R3)`
  - `O E2 192.168.30.0/24 [110/20] via 10.0.0.2 (ISP1 -> R6)`
  - `O E2 192.168.40.0/24 [110/20] via 10.0.0.2 (ISP1 -> R6)`

#step-title[Bước 6. Kiểm tra truyền thông liên chi nhánh bằng ICMP]

Quản trị viên mở terminal trên các máy trạm VPC và thực hiện ping chéo giữa hai chi nhánh.

#figure(
  image("/00_book/figures/report/terminal-generated/vpc11-ping.png", width: 82%),
  caption: [Kết quả ping từ VPC11 sang VPC14 với tỷ lệ thành công 100%],
) <fig-k2-ping-vpc11-vpc14>
Kết quả trong @fig-k2-ping-vpc11-vpc14 cho thấy `VPC11` (`192.168.10.10`) gửi thành công 5/5 gói tin tới `VPC14` (`192.168.30.10`). Độ trễ trung bình là khoảng `6,9 ms`; giá trị `ttl=59` cho thấy gói tin đi qua năm hop định tuyến.

Phép thử từ `VPC15` (`192.168.40.10`, thuộc `B2_VLAN` tại Chi nhánh B) đến hai máy trạm ở Chi nhánh A cũng ghi nhận đầy đủ phản hồi:
```text
VPCS> ping 192.168.10.10
84 bytes from 192.168.10.10 icmp_seq=1 ttl=59 time=8.198 ms
84 bytes from 192.168.10.10 icmp_seq=2 ttl=59 time=12.808 ms
84 bytes from 192.168.10.10 icmp_seq=3 ttl=59 time=7.955 ms
84 bytes from 192.168.10.10 icmp_seq=4 ttl=59 time=12.856 ms
84 bytes from 192.168.10.10 icmp_seq=5 ttl=59 time=6.671 ms

VPCS> ping 192.168.20.10
84 bytes from 192.168.20.10 icmp_seq=1 ttl=59 time=9.799 ms
84 bytes from 192.168.20.10 icmp_seq=2 ttl=59 time=8.915 ms
84 bytes from 192.168.20.10 icmp_seq=3 ttl=59 time=6.835 ms
84 bytes from 192.168.20.10 icmp_seq=4 ttl=59 time=6.497 ms
84 bytes from 192.168.20.10 icmp_seq=5 ttl=59 time=10.691 ms
```

==== Đánh giá kết quả

Mô hình OSPFv2 đa vùng và cơ chế tái phân phối tuyến được triển khai đồng bộ bằng *Routing Group*. Các router nhận đúng cấu hình theo quy hoạch OSPFv2 @rfc2328, bảng định tuyến có các tuyến nội vùng và ngoại vi cần thiết, đồng thời các phép thử ICMP được ghi nhận đều thành công.



=== Kịch bản 3: Tích hợp cổng dự phòng GLBP, cấp phát DHCP và chuyển đổi địa chỉ NAT/PAT

==== Mục tiêu và quy hoạch thiết bị

Kịch bản 2 xây dựng mạng LAN có khả năng cấp phát địa chỉ IP tự động, sử dụng GLBP để cung cấp cổng mặc định dự phòng và cân bằng tải, đồng thời triển khai NAT/PAT cho lưu lượng đi ra mạng ngoài. Kịch bản nhằm kiểm tra khả năng phối hợp nhiều chức năng Lớp 3 trong cùng một quy trình cấu hình bằng CAMS và xác minh trực tiếp trên thiết bị.

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/fhrp-nat-dhcp-report.png", width: 95%),
  caption: [Sơ đồ Kịch bản 2: Tích hợp GLBP, DHCP và NAT/PAT cho mạng LAN],
) <fig-topo-scenario-3>

Địa chỉ và vai trò của từng thiết bị được trình bày trong bảng quy hoạch dưới đây.

#report-table(
  columns: (14%, 28%, 18%, 40%),
  text-size: 9.5pt,
  cell-inset: (x: 4pt, y: 4.5pt),
  header: ([Thiết bị], [Cổng / Địa chỉ], [Vai trò], [Ghi chú]),
  rows: (
    ([R1], [#table-code("Gi0/0 - 192.168.4.2/24")], [Gateway member], [Tham gia GLBP Group 113, Priority 101]),
    ([R2], [#table-code("Gi0/0 - 192.168.4.3/24")], [Gateway member], [Tham gia GLBP Group 113, Priority 100]),
    (
      [GLBP Virtual IP],
      [#table-code("192.168.4.1")],
      [Default Gateway],
      [Địa chỉ gateway cấp cho các máy trạm qua DHCP],
    ),
    ([NAT], [#table-code("Gi0/1 - 192.168.1.2/24")], [NAT Inside], [Kết nối hướng về R1]),
    ([NAT], [#table-code("Gi0/3 - 192.168.2.2/24")], [NAT Inside], [Kết nối hướng về R2]),
    ([NAT], [#table-code("Gi0/2 - 10.0.10.2/24")], [NAT Outside], [Kết nối tới mạng ISP / upstream]),
    ([PC1], [DHCP], [Máy trạm kiểm thử], [Nhận IP động và sử dụng gateway `192.168.4.1`]),
  ),
  caption: [Bảng quy hoạch địa chỉ và vai trò thiết bị trong Kịch bản 2],
) <tab-ip-planning-lab3>

==== Quy trình triển khai trên phần mềm CAMS

#step-title[Bước 1. Khai báo vai trò NAT Inside và NAT Outside]

Trên thiết bị `NAT` có địa chỉ quản trị `192.168.122.103`, quản trị viên mở *NAT* $arrow$ thẻ *Interfaces* để xác định hướng lưu lượng cho từng cổng. Hai cổng `GigabitEthernet0/1` và `GigabitEthernet0/3` được đánh dấu là *Inside*, trong khi `GigabitEthernet0/2` được đánh dấu là *Outside*.

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/01-nat-interfaces.png", width: 90%),
  caption: [Giao diện cấu hình cổng NAT Inside/Outside trên Router NAT],
) <fig-k3-nat-interfaces>

@fig-k3-nat-interfaces cho thấy ba cổng đã được lưu ở trạng thái mong muốn: `Gi0/1` và `Gi0/3` có vai trò `Inside`, còn `Gi0/2` có vai trò `Outside`. Thông tin này được kiểm tra trước khi CAMS sinh tập lệnh cấu hình.

#step-title[Bước 2. Tạo Access Control List cho dải địa chỉ được phép NAT]

Tại thẻ *ACL* của nhóm NAT, quản trị viên tạo ACL chuẩn có tên `NAT_demo`, hành động `permit`, áp dụng cho mạng nguồn `192.168.0.0` với wildcard mask `0.0.7.255`. Dải này bao phủ các mạng nội bộ được sử dụng trong mô hình thử nghiệm.

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/02-nat-acl.png", width: 90%),
  caption: [Khai báo ACL NAT_demo xác định các mạng nội bộ được phép chuyển đổi địa chỉ],
) <fig-k3-nat-acl>

Sau khi lưu các tham số cổng và ACL, người dùng mở cửa sổ *View & Push* để kiểm duyệt tập lệnh trước khi gửi xuống thiết bị.

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/03-nat-config-preview.png", width: 78%),
  caption: [Cửa sổ View & Push sinh cấu hình NAT Interface và ACL cho Router NAT],
) <fig-k3-nat-preview>

@fig-k3-nat-preview cho thấy CAMS sinh các lệnh `ip nat inside`, `ip nat outside` trên từng cổng và khối ACL sau:
```text
ip access-list standard NAT_demo
 10 permit 192.168.0.0 0.0.7.255
```
Người dùng đối chiếu toàn bộ lệnh trước khi nhấn *Push*, theo cùng quy trình lưu tạm và kiểm duyệt đã sử dụng ở các kịch bản trước.

#step-title[Bước 3. Cấu hình PAT Overload bằng địa chỉ của cổng Outside]

Sau khi xác định vùng Inside/Outside và ACL, quản trị viên chuyển sang thẻ *PAT*. Tại đây, ACL `NAT_demo` được chọn làm nguồn cần chuyển đổi, `Source Type` được đặt là *Outside Interface* và cổng `GigabitEthernet0/2` được sử dụng làm địa chỉ đại diện phía ngoài.

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/04-nat-pat.png", width: 90%),
  caption: [Giao diện cấu hình PAT Overload sử dụng cổng Outside GigabitEthernet0/2],
) <fig-k3-pat-gui>

Cửa sổ *View & Push* cho thấy lệnh PAT được sinh tự động:

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/05-nat-pat-preview.png", width: 78%),
  caption: [Cửa sổ View & Push kiểm duyệt lệnh PAT Overload trước khi đẩy xuống Router NAT],
) <fig-k3-pat-preview>

```text
ip nat inside source list NAT_demo interface GigabitEthernet0/2 overload
```

Lệnh trên cho phép nhiều địa chỉ IPv4 trong mạng nội bộ dùng chung địa chỉ IP của cổng `Gi0/2`; các phiên kết nối được phân biệt bằng số hiệu cổng ở tầng vận chuyển (Port Address Translation - PAT).

#step-title[Bước 4. Xác minh cấu hình NAT/PAT trên thiết bị]

Sau khi đẩy cấu hình, quản trị viên mở terminal tích hợp để kiểm tra router NAT. Kết quả xác nhận `Gi0/1` và `Gi0/3` đã nhận lệnh `ip nat inside`, còn `Gi0/2` đã nhận lệnh `ip nat outside`.

#figure(
  image("/00_book/figures/report/terminal-generated/nat-interfaces.png", width: 62%),
  caption: [Xác minh vai trò NAT trên ba cổng của Router NAT bằng lệnh show running-config],
) <fig-k3-nat-interface-verify>

Tiếp tục kiểm tra cấu hình tổng thể cho thấy lệnh PAT, ACL `NAT_demo` và tuyến mặc định tới `10.0.10.1` đã tồn tại trong running-config.

#figure(
  image("/00_book/figures/report/terminal-generated/nat-config.png", width: 90%),
  caption: [Xác minh ACL, PAT Overload và Default Route trên Router NAT],
) <fig-k3-nat-config-verify>

#step-title[Bước 5. Thiết lập GLBP làm cổng mặc định dự phòng]

Để tránh phụ thuộc vào một router gateway duy nhất, quản trị viên mở *FHRP* $arrow$ *GLBP*. Hai router `R1` (`192.168.122.101`) và `R2` (`192.168.122.102`) được chọn làm thành viên của nhóm `113`, sử dụng địa chỉ gateway ảo `192.168.4.1` trên mạng LAN `192.168.4.0/24`.

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

@fig-k3-glbp-preview cho thấy CAMS sinh cấu hình nhóm GLBP 113 trên cả hai router, gồm địa chỉ ảo, chế độ cân bằng tải, trọng số và thời gian chờ preempt. `R1` có mức ưu tiên 101, cao hơn `R2` với mức 100, phù hợp với chính sách đã khai báo.

#step-title[Bước 6. Tạo DHCP Pool với địa chỉ GLBP làm cổng mặc định]

Sau khi thiết lập gateway ảo, quản trị viên chuyển sang `R1`, mở *DHCP* và tạo pool `LAN_R1` cho mạng `192.168.4.0/24`. Trường *Default Router* được đặt là địa chỉ IP ảo `192.168.4.1` của GLBP thay vì địa chỉ vật lý của riêng `R1` hoặc `R2`.

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/11-dhcp-pool.png", width: 88%),
  caption: [Giao diện tạo DHCP Pool LAN_R1 với Default Gateway là GLBP Virtual IP 192.168.4.1],
) <fig-k3-dhcp-pool>

Cửa sổ kiểm duyệt cho thấy cấu hình DHCP được sinh tương ứng:

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/13-dhcp-config-preview.png", width: 78%),
  caption: [Cửa sổ View & Push DHCP sinh cấu hình pool LAN_R1 trên R1],
) <fig-k3-dhcp-preview>

```text
ip dhcp pool LAN_R1
 network 192.168.4.0 255.255.255.0
 default-router 192.168.4.1
 exit
```

Với cấu hình này, máy trạm sử dụng cổng mặc định logic `192.168.4.1` do GLBP quản lý thay vì phụ thuộc vào địa chỉ vật lý của riêng `R1` hoặc `R2`.

#step-title[Bước 7. Xác minh DHCP và GLBP trên R1, R2]

Trên `R1`, lệnh `show ip dhcp pool` xác nhận pool `LAN_R1` đã được tạo cho mạng `192.168.4.0/24`. Đồng thời, `show running-config interface g0/0` xác nhận cổng LAN `192.168.4.2/24` đang tham gia GLBP Group `113`, có Virtual IP `192.168.4.1`, Priority `101` và bật `preempt`.

#figure(
  image("/00_book/figures/report/terminal-generated/r1-dhcp-glbp.png", width: 74%),
  caption: [Xác minh DHCP Pool và cấu hình GLBP trên Router R1],
) <fig-k3-r1-verify>

Trên `R2`, cổng `Gi0/0` mang địa chỉ `192.168.4.3/24` và tham gia cùng GLBP Group `113` với Virtual IP `192.168.4.1`, đảm bảo hai router cùng cung cấp dịch vụ gateway cho một mạng LAN.

#figure(
  image("/00_book/figures/report/terminal-generated/r2-glbp.png", width: 84%),
  caption: [Xác minh cấu hình GLBP Group 113 trên Router R2],
) <fig-k3-r2-verify>

#step-title[Bước 8. Kiểm tra cấp phát DHCP và đường đi của lưu lượng]

Cuối cùng, trên máy trạm `PC1`, lệnh `ip dhcp` được sử dụng để yêu cầu cấp phát địa chỉ. Máy trạm nhận thành công địa chỉ `192.168.4.4/24` cùng default gateway `192.168.4.1`.

#figure(
  image("/00_book/figures/report/terminal-generated/pc1-dhcp-trace.png", width: 84%),
  caption: [Kiểm tra PC1 nhận DHCP và truy vết đường đi qua GLBP Gateway tới Router NAT và mạng upstream],
) <fig-k3-client-test>

Kết quả lệnh `trace 1.1.1.1` trong @fig-k3-client-test ghi nhận chặng đầu tiên là `192.168.4.2` (`R1`), tiếp theo là `192.168.1.2` (router NAT) và `10.0.10.1` (gateway phía ngoài). Thiết bị phía ngoài trả về ICMP `Destination port unreachable`; vì vậy, phép thử chỉ xác minh đường đi từ mạng LAN tới biên ngoài của mô hình lab, không chứng minh kết nối hoàn chỉnh tới `1.1.1.1`.

==== Đánh giá kết quả

CAMS đã triển khai chuỗi chức năng DHCP, GLBP và NAT/PAT trên nhiều thiết bị. Máy trạm nhận địa chỉ `192.168.4.4/24` và cổng mặc định ảo `192.168.4.1`; `R1` và `R2` cùng tham gia GLBP Group 113; router NAT nhận đúng vai trò Inside/Outside, ACL và cấu hình PAT Overload theo cơ chế chuyển đổi địa chỉ và cổng @rfc3022. Kết quả truy vết xác nhận lưu lượng đi từ LAN qua `R1`, router NAT và tới gateway upstream `10.0.10.1`.


=== Kịch bản 4: Thu thập, giám sát và phân tích nhật ký tập trung bằng Syslog Server

==== Mục tiêu và quy hoạch nguồn gửi Syslog

Kịch bản 4 kiểm tra khả năng cấu hình Syslog theo nhóm trên nhiều thiết bị Cisco, đồng thời đánh giá việc tiếp nhận, phân tích, hiển thị và gửi cảnh báo qua email trong CAMS. Ba router `R1`, `R2`, `R3` và switch `SW1` cùng gửi log về máy chủ `192.168.122.1` qua cổng `5514/UDP`. Nội dung kiểm tra gồm cấu hình trên thiết bị; khả năng phân tách nguồn gửi, địa chỉ IP nguồn, facility, severity, mnemonic và nội dung gốc; cùng khả năng chuyển hai mức cảnh báo đã chọn qua SMTP.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/syslog-lab-topology-report.png", width: 92%),
  caption: [Sơ đồ Kịch bản 4: Thu thập Syslog tập trung],
) <fig-topo-scenario-4>

Nguồn gửi và chính sách Syslog được trình bày trong bảng quy hoạch dưới đây.

#report-table(
  columns: (11%, 24%, 27%, 38%),
  text-size: 9.5pt,
  cell-inset: (x: 4pt, y: 4.5pt),
  header: ([Thiết bị], [IP quản trị], [Source Interface], [Chính sách gửi Syslog]),
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

Từ thiết bị đang được quản lý, quản trị viên mở thẻ *Syslog Server*. Ban đầu, chưa có đích Syslog nào được cấu hình nên các chỉ số `Destinations`, `Applied`, `Pending apply` và `Pending removal` đều bằng `0`. Người dùng chọn *Syslog Group* để tạo một chính sách chung cho nhiều thiết bị thay vì khai báo riêng cho từng router hoặc switch.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/01-syslog-configuration.png", width: 92%),
  caption: [Giao diện quản lý Syslog Server trước khi tạo chính sách gửi log],
) <fig-k4-syslog-config>

@fig-k4-syslog-config thể hiện màn hình quản lý đích Syslog. Tại đây, người dùng có thể tạo cấu hình đơn lẻ, kiểm duyệt lệnh bằng *View & Push* hoặc áp dụng chính sách theo nhóm bằng *Syslog Group*.

#step-title[Bước 2. Chọn các thiết bị tham gia Syslog Group]

Tại bước *Hosts*, quản trị viên chọn cả bốn thiết bị đang kết nối gồm `R1`, `R2`, `R3` và `SW1`. Hệ thống hiển thị số lượng cổng phát hiện được trên từng thiết bị để làm dữ liệu đầu vào cho bước lựa chọn Source Interface.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/02-syslog-select-hosts.png", width: 78%),
  caption: [Bước Hosts của Syslog Group: chọn 4 thiết bị cùng tham gia chính sách gửi log],
) <fig-k4-syslog-hosts>

Việc nhóm nhiều thiết bị trong một quy trình giúp giảm thao tác lặp lại và duy trì thống nhất địa chỉ máy chủ, giao thức vận chuyển cùng mức độ nghiêm trọng cho toàn bộ nhóm.

#step-title[Bước 3. Chọn Source Interface cho từng thiết bị]

Tại bước *Interfaces*, CAMS cho phép chọn cổng nguồn riêng cho từng thiết bị. Ba router sử dụng `GigabitEthernet0/0` trên mạng quản trị `192.168.122.0/24`, còn switch `SW1` sử dụng cổng logic `Vlan1`.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/03-syslog-source-interfaces.png", width: 78%),
  caption: [Lựa chọn Source Interface cho từng Router và Switch trong Syslog Group],
) <fig-k4-syslog-source>

Cấu hình `logging source-interface` tạo địa chỉ nguồn ổn định cho các bản tin Syslog, nhờ đó CAMS có thể ánh xạ bản tin đến đúng thiết bị trong danh sách quản lý.

#step-title[Bước 4. Khai báo chính sách Syslog dùng chung]

Tại bước *Policy*, quản trị viên nhập địa chỉ máy chủ `192.168.122.1`, chọn giao thức `UDP`, cổng `5514` và đặt *Trap severity* là `5 - Notifications`. Hai tùy chọn *Include millisecond log timestamps* và *Include sequence numbers* được bật để hỗ trợ sắp xếp và đối chiếu sự kiện chính xác hơn. CAMS sử dụng cổng `5514` thay vì cổng Syslog chuẩn `514/UDP` vì trên Linux, các cổng dưới 1024 yêu cầu quyền root để lắng nghe; cổng 5514 cho phép dịch vụ chạy ở quyền người dùng thông thường mà không cần cấu hình đặc biệt.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/04-syslog-policy.png", width: 78%),
  caption: [Thiết lập đích Syslog 192.168.122.1:5514/UDP và mức severity Notifications],
) <fig-k4-syslog-policy>

Với mức `notifications`, thiết bị gửi các bản tin có severity từ 0 đến 5 tới máy chủ Syslog. Phạm vi này phù hợp với bài thử vì bao gồm sự kiện thay đổi trạng thái cổng, thông báo cấu hình và các bản tin do người quản trị chủ động tạo.

#step-title[Bước 5. Kiểm duyệt tập lệnh trước khi đẩy cấu hình]

Sau khi hoàn tất ba bước của wizard, CAMS mở cửa sổ *View & Push Syslog Group* để tổng hợp cấu hình cho cả bốn thiết bị. Quản trị viên có thể xem toàn bộ lệnh trước khi nhấn *Push*.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/05-syslog-config-preview.png", width: 82%),
  caption: [Cửa sổ View & Push Syslog Group tổng hợp lệnh cho 4 thiết bị trước khi thực thi],
) <fig-k4-syslog-preview>

Với router, cửa sổ trong @fig-k4-syslog-preview hiển thị các lệnh tiêu biểu:
```text
logging host 192.168.122.1 transport udp port 5514
logging trap notifications
service timestamps log datetime msec
service sequence-numbers
logging source-interface GigabitEthernet0/0
```
Đối với `SW1`, lệnh cuối sử dụng `logging source-interface Vlan1`. CAMS nhờ đó áp dụng được một chính sách chung mà vẫn giữ đúng cổng nguồn của từng router và switch.

#step-title[Bước 6. Xác minh cấu hình trên R1, R2, R3 và SW1]

Sau khi đẩy cấu hình thành công, quản trị viên mở terminal tích hợp và thực hiện lệnh `show running-config | section logging` trên từng thiết bị. Kết quả trên `R1`, `R2` và `R3` đều ghi nhận máy chủ `192.168.122.1`, giao thức UDP, cổng `5514`, mức `notifications` và cổng nguồn `GigabitEthernet0/0`.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/06-syslog-r1-verify.png", width: 88%),
  caption: [Xác minh cấu hình Syslog trên Router R1],
) <fig-k4-r1-verify>

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/07-syslog-r2-verify.png", width: 88%),
  caption: [Xác minh cấu hình Syslog trên Router R2],
) <fig-k4-r2-verify>

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/08-syslog-r3-verify.png", width: 88%),
  caption: [Xác minh cấu hình Syslog trên Router R3],
) <fig-k4-r3-verify>

Trên switch `SW1`, cấu hình tương tự nhưng sử dụng `Vlan1` làm cổng nguồn.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/09-syslog-sw1-verify.png", width: 88%),
  caption: [Xác minh cấu hình Syslog trên Switch SW1 với Source Interface Vlan1],
) <fig-k4-sw1-verify>

Kết quả xác minh cho thấy cấu hình trên thiết bị khớp với nội dung đã xem trước. Qua đó, quy trình *Syslog Group $arrow$ View & Push $arrow$ Verify* được xác nhận hoạt động trên cả router và switch.

#step-title[Bước 7. Khởi động Syslog Listener tích hợp trong CAMS]

Tiếp theo, quản trị viên chuyển sang màn hình *System Logs*. Trước khi khởi động, trạng thái hiển thị *Listener stopped*, số bản tin nhận được bằng `0` và bảng log chưa có dữ liệu.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/10-syslog-listener-before-start.png", width: 94%),
  caption: [Màn hình System Logs trước khi khởi động Syslog Listener],
) <fig-k4-listener-before>

Sau khi nhấn *Start Listener*, dịch vụ chuyển sang trạng thái *Listener active* và lắng nghe trên `0.0.0.0:5514/UDP+TCP`. Khi các thiết bị phát sinh sự kiện, các bản tin được đưa trực tiếp vào bảng System Logs theo thời gian thực.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/11-syslog-listener-receiving.png", width: 94%),
  caption: [Syslog Listener đang hoạt động và tiếp nhận bản tin từ các thiết bị mạng],
) <fig-k4-listener-active>

Tại thời điểm ghi nhận trong @fig-k4-listener-active, hệ thống đã tiếp nhận `245` bản tin. Mỗi bản tin được phân tách thành các trường `Time`, `Host`, `Source IP`, `Facility/Severity`, `Mnemonic` và `Message`. Các sự kiện `LINK`, `LINEPROTO` và `SYS` được phân loại theo nguồn gửi và mã sự kiện.

#step-title[Bước 8. Kiểm tra khả năng phân tích một bản tin Syslog]

Khi chọn một dòng log, CAMS mở cửa sổ *System Log Message* để hiển thị dữ liệu đã phân tích cùng bản tin nguyên gốc. Với mẫu từ `192.168.122.101`, hệ thống nhận dạng giao thức `UDP`, facility `LINEPROTO`, severity `5`, mnemonic `UPDOWN`, số thứ tự `104` và trạng thái phân tích `parsed`.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/12-syslog-message-detail.png", width: 68%),
  caption: [Cửa sổ chi tiết một bản tin Syslog sau khi được phân tích],
) <fig-k4-message-detail>

Phần *Raw message* vẫn được giữ nguyên để phục vụ đối chiếu khi cần:
```text
<189>104: *Aug 29 20:25:44.323: %LINEPROTO-5-UPDOWN:
Line protocol on Interface Loopback99, changed state to down
```
Việc lưu đồng thời các trường đã chuẩn hóa và nội dung gốc hỗ trợ cả giám sát lẫn đối chiếu dữ liệu.

#step-title[Bước 9. Tạo sự kiện kiểm thử và đối chiếu với Syslog Server]

Để tạo lượng log đủ lớn và có thể lặp lại, CAMS lần lượt thay đổi trạng thái `Loopback99` trên các router và trạng thái cổng `GigabitEthernet1/3` trên switch. Các thiết bị phát sinh những bản tin thuộc nhóm `USERLOG_WARNING`, `USERLOG_NOTICE`, `LINK`, `LINEPROTO` và `CONFIG_I`.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/13-syslog-r1-device-logs.png", width: 94%),
  caption: [Nhật ký sự kiện kiểm thử phát sinh trực tiếp trên Router R1],
) <fig-k4-r1-device-logs>

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/14-syslog-r2-device-logs.png", width: 94%),
  caption: [Nhật ký sự kiện kiểm thử phát sinh trực tiếp trên Router R2],
) <fig-k4-r2-device-logs>

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/15-syslog-r3-device-logs.png", width: 94%),
  caption: [Nhật ký sự kiện kiểm thử phát sinh trực tiếp trên Router R3],
) <fig-k4-r3-device-logs>

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/16-syslog-sw1-device-logs.png", width: 94%),
  caption: [Nhật ký sự kiện kiểm thử phát sinh trực tiếp trên Switch SW1],
) <fig-k4-sw1-device-logs>

Từ @fig-k4-r1-device-logs đến @fig-k4-sw1-device-logs trình bày chuỗi sự kiện ghi nhận trên bốn thiết bị. Khi thực hiện `shutdown` hoặc `no shutdown`, Cisco IOS phát sinh thông báo về trạng thái liên kết và giao thức đường truyền; các bản tin `USERLOG_*` đánh dấu từng chu kỳ thử nghiệm. Những sự kiện tương ứng xuất hiện trên *System Logs* và được gắn đúng nguồn gửi.

#step-title[Bước 10. Cấu hình cảnh báo Syslog qua email]

Quản trị viên mở *Settings → Email Alerts* và bật tùy chọn gửi cảnh báo. Cấu hình thử nghiệm sử dụng máy chủ `smtp.gmail.com`, cổng `465`, tài khoản gửi `cams.syslog.alert@gmail.com` và địa chỉ nhận `nguyenquocviet15t12@gmail.com`. Các mức từ `0` đến `4` được chọn để bao phủ nhóm khẩn cấp, nghiêm trọng, lỗi và cảnh báo. Khoảng chống gửi trùng được đặt là `300` giây; cửa sổ gom bản tin là `10` giây.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/17-email-alert-settings.png", width: 96%),
  caption: [Cấu hình mức cảnh báo, tài khoản SMTP và người nhận trên Email Alerts],
) <fig-k4-email-settings>

@fig-k4-email-settings cho thấy App Password chỉ xuất hiện dưới dạng ký tự che khuất. CAMS lưu giá trị này ở dạng mã hóa và không trả nội dung bí mật về giao diện. Nút *Send test email* cho phép kiểm tra cấu hình trước khi bật luồng cảnh báo thực tế.

#step-title[Bước 11. Minh họa email cảnh báo do CAMS tự động gửi]

Sau khi hoàn tất cấu hình tại @fig-k4-email-settings và bật chức năng gửi cảnh báo, CAMS tự động theo dõi các bản tin do Syslog Listener tiếp nhận. Mỗi bản tin sau khi được phân tích và lưu trữ sẽ được đối chiếu với các mức cảnh báo đã chọn. Sự kiện phù hợp được đưa vào hàng đợi gửi thư; ứng dụng tạo đồng thời nội dung văn bản thuần và HTML, sau đó gửi qua máy chủ `smtp.gmail.com:465` tới địa chỉ nhận đã cấu hình. Luồng SMTP chạy tách biệt với bộ thu nhận nên không làm gián đoạn quá trình tiếp nhận Syslog.

Để minh họa kết quả của chức năng này, báo cáo lựa chọn hai email đại diện gắn với các sự kiện đã trình bày ở Bước 9: `%LINK-3-UPDOWN` mức `3 - Error` của `SW1` và `%SYS-4-USERLOG_WARNING` mức `4 - Warning` của `R1`. Email mức Error tại @fig-k4-email-error cho thấy cách CAMS trình bày địa chỉ nguồn `192.168.122.104`, số thứ tự `110`, PRI `187`, Syslog facility `23` (`local7`) và mã Cisco `%LINK-3-UPDOWN`.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/lv3.png", width: 88%),
  caption: [Minh họa email cảnh báo mức Error cho sự kiện `%LINK-3-UPDOWN` trên SW1],
) <fig-k4-email-error>

Thư mức Warning tại @fig-k4-email-warning giữ cùng cấu trúc nhưng sử dụng dữ liệu của `R1`: địa chỉ nguồn `192.168.122.101`, số thứ tự `98`, PRI `188`, Syslog facility `23` và mã Cisco `%SYS-4-USERLOG_WARNING`. Nội dung `DEMO-R1 CYCLE=5/5 Loopback99=DOWN` trùng với dấu mốc xuất hiện trong ảnh terminal của `R1`. Dấu `*` trước thời gian thiết bị được giữ trong bản tin gốc và được biểu diễn thành trạng thái *Chưa đồng bộ* trong phần chi tiết.

#figure(
  image("/00_book/figures/report/diagrams/syslog-lab/lv4.png", width: 88%),
  caption: [Minh họa email cảnh báo mức Warning cho sự kiện `%SYS-4-USERLOG_WARNING` trên R1],
) <fig-k4-email-warning>

Hai hình minh họa cho thấy email cảnh báo giữ được mối liên hệ với bản tin Syslog nguồn, đồng thời thay đổi nhãn, màu sắc và khuyến nghị theo severity. Việc đánh giá số lượng thư nhận được, độ trễ, giới hạn lưu lượng hoặc tỷ lệ chuyển thư ở quy mô lớn chưa thuộc phạm vi kịch bản này.

==== Đánh giá kết quả

CAMS đã cấu hình Syslog theo nhóm cho bốn thiết bị. Ba router sử dụng `GigabitEthernet0/0`, còn switch sử dụng `Vlan1` làm cổng nguồn. Syslog Listener tiếp nhận bản tin từ các địa chỉ `192.168.122.101` đến `192.168.122.104`, phân tích được Syslog facility, severity, mã phân hệ Cisco và mnemonic, đồng thời giữ nguyên nội dung gốc theo cấu trúc Syslog @rfc5424. Các sự kiện thay đổi trạng thái cổng và thông báo cấu hình xuất hiện nhất quán giữa terminal thiết bị với bảng *System Logs*. Phần cảnh báo email cho phép chọn mức cần gửi, bảo vệ App Password và tách thao tác SMTP khỏi bộ nhận. Hai email Error và Warning được chọn làm ví dụ minh họa, sử dụng dữ liệu liên kết trực tiếp với các sự kiện của bài lab; cách lưu và rà soát này phù hợp với nguyên tắc quản lý nhật ký tập trung @nistSp80092.


=== Kịch bản 5: Kiểm chứng chính sách ACL và nhật ký an ninh tập trung

==== Mục tiêu và phạm vi

Kịch bản 5 kiểm chứng chuỗi xử lý từ chính sách đến bằng chứng vận hành: CAMS tạo ACL có ghi nhật ký, triển khai ACL lên đúng cổng vào của VLAN, thiết bị cho phép hoặc từ chối lưu lượng theo từng luật, sau đó gửi sự kiện về System Logs. Kịch bản tập trung vào ba chính sách cụ thể: chặn Telnet từ VLAN 10 đến địa chỉ `192.168.12.2`, chặn HTTP từ VLAN 20 đến máy chủ `203.162.4.1`, và chặn ICMP từ VLAN 30 đến máy chủ này. Các lưu lượng không khớp luật từ chối phải tiếp tục được chuyển tiếp.

Phép thử được thiết kế theo cặp đối chứng. Mỗi chính sách có một lưu lượng cần bị chặn và một lưu lượng khác cần được phép. Cách kiểm tra này phân biệt trường hợp ACL hoạt động đúng với trường hợp mất kết nối do định tuyến, máy chủ hoặc cấu hình nền chưa hoàn tất.

==== Mô hình và quy hoạch địa chỉ

@fig-k5-topology trình bày mô hình thực nghiệm. `R1` thực hiện định tuyến giữa VLAN theo mô hình router-on-a-stick trên `GigabitEthernet0/1`; `R2` là bộ định tuyến biên thực hiện NAT; `R3` đóng vai trò ISP và cung cấp dịch vụ HTTP trên `Loopback0`. Ba máy trạm `VPC7`, `VPC8` và `VPC9` lần lượt thuộc VLAN 10, VLAN 20 và VLAN 30. Các liên kết kép giữa ba bộ chuyển mạch được gom kênh; nội dung này tạo hạ tầng kết nối nhưng không phải đối tượng đánh giá của kịch bản ACL.

#figure(
  image("/00_report/Tai_lieu_lab/LAB5/ANH_CUA_LAB/so_do.png", width: 92%),
  caption: [Mô hình kiểm chứng ACL với R1 định tuyến liên VLAN, R2 làm NAT và R3 làm ISP],
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
  columns: (15%, 18%, 29%, 21%, 17%),
  text-size: 9.5pt,
  header: ([ACL / luật], [Nguồn], [Đích và dịch vụ], [Hành động], [Vị trí]),
  rows: (
    ([V10 / 10], [`192.168.10.0/24`], [`192.168.12.2`, TCP/23], [Từ chối, ghi log], [`Gi0/1.10` in]),
    ([V10 / 20], [`any`], [`any`, IP], [Cho phép, ghi log], [`Gi0/1.10` in]),
    ([V20-V30 / 10], [`192.168.20.0/24`], [`203.162.4.1`, TCP/80], [Từ chối, ghi log], [`Gi0/1.20` in]),
    ([V20-V30 / 20], [`192.168.30.0/24`], [`203.162.4.1`, ICMP], [Từ chối, ghi log], [`Gi0/1.30` in]),
    ([V20-V30 / 30], [`any`], [`any`, IP], [Cho phép, ghi log], [`Gi0/1.20`, `.30` in]),
  ),
  caption: [Ma trận chính sách ACL được kiểm chứng],
) <tab-k5-acl-policy>

@fig-k5-acl-applied là bằng chứng cấu hình sau triển khai. Kết quả `show ip interface` xác nhận ACL đã được gắn chiều vào trên ba subinterface. Kết quả `show access-lists` xác nhận đúng địa chỉ nguồn, đích, giao thức, cổng dịch vụ và từ khóa `log`. Hình này thay cho chuỗi ảnh nhập biểu mẫu và thao tác Push vì mục tiêu của thực nghiệm là chứng minh cấu hình cuối trên thiết bị.

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

R1 gửi Syslog về CAMS qua mạng quản trị. Chính sách gửi phải bao gồm mức `6 - Informational` vì bản tin ACL trong phép thử mang severity 6. Tại thời điểm chụp @fig-k5-acl-syslog, bộ thu C++ đang lắng nghe trên `0.0.0.0:5514/UDP+TCP` và đã nhận 272 bản tin. Các dòng bằng chứng quan trọng gồm:

- `ACL_V10_NO_TELNET_R2 denied tcp 192.168.10.1(...) -> 192.168.12.2(23)`;
- `ACL_V20_V30_OUT denied tcp 192.168.20.1(...) -> 203.162.4.1(80)`;
- `ACL_V20_V30_OUT denied icmp 192.168.30.1 -> 203.162.4.1`;
- các dòng `permitted` tương ứng với những phép thử đối chứng không thuộc điều kiện từ chối.

#figure(
  image("/00_report/Tai_lieu_lab/LAB5/ANH_CUA_LAB/12.png", width: 100%),
  caption: [System Logs ghi nhận các sự kiện ACL được phép và bị từ chối từ R1],
) <fig-k5-acl-syslog>

Trường `SEC` trong bảng là mã phân hệ Cisco IOS; Syslog facility được tách từ PRI. Với PRI bằng 190 trong các bản tin minh họa, Syslog facility bằng 23 (`local7`) và severity bằng 6. Việc tách hai trường giúp tránh gọi nhầm `SEC` là facility theo chuẩn Syslog.

==== Đánh giá kết quả

#report-table(
  columns: (16%, 32%, 20%, 32%),
  header: ([Ca thử], [Lưu lượng], [Kết quả], [Bằng chứng]),
  rows: (
    ([ACL-01], [VLAN 10 đến `192.168.12.2`, TCP/23], [Bị từ chối], [ICMP Type 3 Code 13 và log `denied tcp`.]),
    ([ACL-02], [VLAN 20 đến `203.162.4.1`, TCP/80], [Bị từ chối], [ICMP Type 3 Code 13 và log `denied tcp`.]),
    ([ACL-03], [VLAN 30 đến `203.162.4.1`, ICMP], [Bị từ chối], [Năm phản hồi administratively prohibited và log `denied icmp`.]),
    ([ACL-04], [VLAN 10 đến `203.162.4.1`, ICMP và TCP/80], [Được phép], [Năm phản hồi ICMP và năm chu kỳ kết nối TCP/80.]),
    ([ACL-05], [VLAN 20/30 với lưu lượng không khớp deny], [Được phép], [ICMP, TCP/23 hoặc TCP/80 hoàn tất; System Logs có dòng `permitted`.]),
  ),
  caption: [Kết quả kiểm chứng chính sách ACL trong Kịch bản 5],
) <tab-k5-acl-results>

Kết quả cho thấy hai ACL được áp dụng đúng chiều trên ba subinterface của R1. Ba lưu lượng khớp luật từ chối đều bị R1 chặn và tạo bản tin Syslog; các lưu lượng đối chứng vẫn được chuyển tiếp. CAMS tiếp nhận, phân tích và hiển thị đúng thiết bị nguồn `192.168.122.104`, mã phân hệ `SEC`, severity 6, mnemonic cùng thông tin địa chỉ và dịch vụ. Phạm vi kết luận giới hạn ở các địa chỉ, giao thức và số lần thử nêu trong bảng; kịch bản chưa đo thông lượng ghi log hoặc tỷ lệ mất bản tin khi tải cao.



== Đánh giá tổng hợp

=== Ưu điểm nổi bật

- *Giao diện quản lý tập trung:* CAMS cung cấp một không gian làm việc thống nhất cho các chức năng mạng Lớp 2 và Lớp 3, qua đó giảm số thao tác CLI trực tiếp trên từng thiết bị.
- *Quy trình kiểm duyệt trước khi thực thi:* Mô hình Staged Save tách trạng thái mong muốn (`Desired State`) khỏi trạng thái đã áp dụng (`Applied`). Cửa sổ *View & Push* cho phép kiểm tra tập lệnh trước khi gửi xuống thiết bị.
- *Khả năng xử lý nhiều thiết bị:* `Host Lock` tuần tự hóa các lệnh trên cùng một thiết bị, trong khi `BatchExecutor` cho phép xử lý song song các thiết bị độc lập.
- *Các tiện ích hỗ trợ vận hành:* Hệ thống tích hợp sao lưu phiên bản bằng Dulwich, Syslog Server, cảnh báo Syslog qua email, SFTP và terminal nhúng.

=== Hạn chế thực tế cần cải tiến

- *Phạm vi thiết bị:* Hệ thống hiện được tối ưu cho các thiết bị chạy Cisco IOS; chưa hỗ trợ đầy đủ thiết bị của các hãng khác như Juniper, MikroTik và Arista.

- *Cơ chế hoàn tác tự động:* Khi quá trình thực thi chỉ thành công một phần, hệ thống giữ cấu hình ở trạng thái `Pending` để người dùng xử lý thủ công; chưa có cơ chế tự động sinh lệnh phủ định (`no ...`) để hoàn tác.
