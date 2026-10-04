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

Phần thực nghiệm gồm năm kịch bản: hạ tầng chuyển mạch và bảo mật Lớp 2; định tuyến OSPF đa vùng; phối hợp GLBP–DHCP–NAT/PAT; thu thập và phân tích nhật ký Syslog; và kiểm thử cơ chế an ninh phân quyền cùng bảo mật dữ liệu lưu trữ. Mỗi kịch bản được thực hiện theo ba giai đoạn:

1. *Thiết lập và xem trước trên giao diện:* người dùng nhập tham số trên biểu mẫu nghiệp vụ. Dữ liệu được lưu ở trạng thái mong muốn (Desired State) và chuyển thành tập lệnh CLI để kiểm tra trong cửa sổ *View & Push*.
2. *Đẩy cấu hình bất đồng bộ:* tác vụ nền lấy thông tin truy cập, áp dụng khóa thiết bị (Host Lock) để tránh tranh chấp luồng lệnh, sau đó gửi tập lệnh qua SSH.
3. *Xác minh trạng thái:* người quản trị đối chiếu phản hồi của hệ thống, kiểm tra trực tiếp bằng terminal Alacritty tích hợp và đánh giá lưu lượng thực tế.

=== Kịch bản 1: Cấu hình hạ tầng chuyển mạch và bảo mật Lớp 2 (Switching & L2 Security)

==== Mục tiêu và quy hoạch

Kịch bản 1 thiết lập hạ tầng chuyển mạch đa tầng trên môi trường lab, gồm khởi tạo VLAN, đồng bộ qua VTP, gom kênh EtherChannel bằng LACP và triển khai các cơ chế bảo vệ Lớp 2 gồm DHCP Snooping, Dynamic ARP Inspection và Port Security.

#figure(
  image("/00_book/figures/report/diagrams/LAB_KICH_BAN_1.svg", width: 90%),
  caption: [Sơ đồ Topo Kịch bản 1: Hạ tầng Chuyển mạch và Bảo mật Lớp 2],
) <fig-topo-scenario-1>

==== Quy trình triển khai trên phần mềm CAMS

Căn cứ vào sơ đồ mạng của kịch bản 1, tám thiết bị gồm hai router và sáu switch được nạp vào không gian làm việc `LAB_KICH_BAN_1`. Các thiết bị sử dụng dải IP quản trị từ `192.168.122.101` đến `192.168.122.108` và hiển thị trạng thái kết nối *CONNECTED* trên thanh bên.

Quá trình cấu hình hạ tầng Lớp 2 được thực hiện qua sáu bước sau.

*Bước 1. Thiết lập nhóm VTP và đồng bộ miền VTP trên toàn mạng*

Người dùng mở chức năng *Switching*, chọn thẻ *VTP* và sử dụng *VTP Group*. Miền `PTIT_LAB`, phiên bản VTP 2, được áp dụng đồng thời cho năm thiết bị từ `SW1` đến `SW5`; `SW1` giữ vai trò VTP Server, còn các switch khác hoạt động ở chế độ VTP Client.

#figure(
  image("/00_book/figures/report/diagrams/switching-lab/1_16.png", width: 85%),
  caption: [Giao diện cấu hình nhóm VTP Group quản lý đồng bộ 5 Switch trong miền PTIT_LAB],
) <fig-k1-vtp-group>
@fig-k1-vtp-group thể hiện sáu switch đang kết nối, năm thiết bị được chọn và miền VTP đã lưu. Sau khi kiểm tra danh sách, quản trị viên sử dụng *Save & Push* để áp dụng cấu hình theo nhóm.

*Bước 2. Khởi tạo VLAN và kiểm duyệt tập lệnh*

Tại switch trung tâm `SW1` (VTP Server, IP: `192.168.122.101`), người dùng chuyển sang thẻ *VLAN* để khởi tạo các phân vùng mạng nghiệp vụ: `VLAN 10` (Tên: `IT_VLAN`) và `VLAN 20` (Tên: `HR_VLAN`). Sau khi lưu vào trạng thái mong muốn (`Desired State`), người dùng nhấn nút *View & Push* để mở cửa sổ duyệt trước mã lệnh.

#figure(
  image("/00_book/figures/report/diagrams/switching-lab/1_20.png", width: 80%),
  caption: [Cửa sổ View & Push kiểm duyệt tập lệnh cấu hình VLAN tự động sinh cho SW1],
) <fig-k1-vlan-push>
@fig-k1-vlan-push cho thấy khối lệnh Cisco IOS được sinh từ dữ liệu trên giao diện, gồm các lệnh tạo VLAN và đặt tên tương ứng. Người dùng kiểm tra từng dòng trước khi nhấn *Push* để gửi cấu hình qua SSH.

*Bước 3. Cấu hình gom kênh EtherChannel bằng LACP*

Nhằm tăng băng thông và đảm bảo tính dự phòng cho đường truyền Trunk giữa `SW1` và `SW3`, người dùng truy cập thẻ *EtherChannel* trên tab `SW1`. Tại đây, người dùng gom 2 cổng vật lý `GigabitEthernet1/0` và `GigabitEthernet1/1` vào nhóm logic `Port-channel1` với giao thức LACP (`mode active`) và gán nhãn mô tả `Link_To_SW3`.

#figure(
  image("/00_book/figures/report/diagrams/switching-lab/1_3.png", width: 80%),
  caption: [Cửa sổ View & Push cấu hình gom kênh EtherChannel LACP cho liên kết SW1 -- SW3],
) <fig-k1-etherchannel-push>
@fig-k1-etherchannel-push thể hiện cấu hình cho từng cổng thành phần và cổng logic `Port-channel1`. Việc xem trước giúp người quản trị đối chiếu chế độ LACP và mô tả liên kết trước khi áp dụng.

*Bước 4. Thiết lập DHCP Snooping và Dynamic ARP Inspection*

Để ngăn chặn các cuộc tấn công mạng Lớp 2 (DHCP Rogue Server, Man-in-the-Middle và ARP Spoofing), người dùng chuyển sang *Security* $arrow$ thẻ *L2 Security*.

#figure(
  image("/00_book/figures/report/diagrams/switching-lab/1_21.png", width: 85%),
  caption: [Giao diện quản trị an ninh Layer 2: Thiết lập DHCP Snooping và Dynamic ARP Inspection],
) <fig-k1-l2-security>
@fig-k1-l2-security thể hiện chính sách bảo vệ cho VLAN 1, 10, 20 và 99. Quản trị viên bật DHCP Snooping, DAI và chỉ định các đường trunk làm *Trusted Uplinks* để tiếp nhận lưu lượng DHCP và ARP hợp lệ.

*Bước 5. Cấu hình Port Security trên switch truy cập SW5*

Trên switch truy cập `SW5` (IP: `192.168.122.105`), người dùng chuyển sang thẻ *Port Security* để bảo vệ các cổng kết nối đến người dùng cuối. Với cổng `GigabitEthernet0/2`, người dùng thiết lập số lượng địa chỉ MAC tối đa là `4`, kích hoạt học địa chỉ tự động (`mac-address sticky`), thời gian lưu vết `5 phút` và cơ chế xử lý vi phạm là ngắt cổng tức thì (`violation shutdown`).

#figure(
  image("/00_book/figures/report/diagrams/switching-lab/1_25.png", width: 80%),
  caption: [Cửa sổ View & Push áp dụng chính sách Port Security bảo vệ cổng truy cập trên SW5],
) <fig-k1-port-security-push>
#block[
  #set par(justify: false)
  @fig-k1-port-security-push thể hiện khối lệnh Port Security để quản trị viên kiểm tra trước khi đẩy xuống thiết bị:
]

```text
switchport mode access
switchport port-security
switchport port-security maximum 4
switchport port-security violation shutdown
switchport port-security mac-address sticky
switchport port-security aging time 5
```

*Bước 6. Xác minh cấu hình qua terminal Alacritty tích hợp*

Sau khi hoàn tất quá trình đẩy cấu hình từ phần mềm, người dùng nhấp vào biểu tượng Terminal trên thanh công cụ của CAMS để mở cửa sổ điều khiển trực tiếp tới thiết bị và thực hiện các câu lệnh kiểm tra trạng thái thực tế.

#figure(
  image("/00_book/figures/report/diagrams/switching-lab/1_30.png", width: 85%),
  caption: [Kiểm tra trạng thái VLAN và VTP trên Switch Client SW3 thông qua Terminal tích hợp],
) <fig-k1-terminal-verify>
Kết quả trong @fig-k1-terminal-verify cho thấy `SW3` đã nhận các VLAN 10, 20 và 99. Lệnh `show vtp status` xác nhận thiết bị hoạt động ở chế độ Client, thuộc miền `PTIT_LAB`, sử dụng VTP phiên bản 2 và có `Configuration Revision` bằng 12.

Ngoài ra, người dùng kiểm tra trạng thái bảo mật cổng trên switch `SW5` qua lệnh `show port-security interface GigabitEthernet0/2`:
```text
SW5# show port-security interface gi0/2
Port Security              : Enabled
Port Status                : Secure-up
Violation Mode             : Shutdown
Aging Time                 : 5 mins
Aging Type                 : Absolute
SecureStatic Address Aging : Disabled
Maximum MAC Addresses      : 4
Total MAC Addresses        : 0
Configured MAC Addresses   : 0
Sticky MAC Addresses       : 0
Last Source Address:Vlan   : 0000.0000.0000:0
Security Violation Count   : 0
```

==== Đánh giá kết quả

Các cấu hình VLAN, VTP, EtherChannel LACP, DHCP Snooping, DAI và Port Security được áp dụng đúng trên hệ thống switch của phòng lab. Kết quả kiểm tra trực tiếp trên thiết bị phù hợp với cấu hình đã thiết lập trên CAMS; các hạng mục của kịch bản 1 đều hoàn thành và phần VLAN/trunk được đối chiếu theo nguyên tắc IEEE 802.1Q @ieee8021q.



=== Kịch bản 2: Định tuyến động đa vùng và tái phân phối tuyến liên chi nhánh (OSPF Group & Route Redistribution)

==== Mục tiêu và quy hoạch địa chỉ IP

Kịch bản 1 thiết lập OSPFv2 đa vùng để kết nối Chi nhánh A với Chi nhánh B qua đường trục ISP thuộc Backbone Area 0. Tính năng *Routing Group - OSPF* cấu hình đồng thời sáu router `R1`, `R2`, `R3`, `ISP1`, `ISP2` và `R6`; cơ chế tái phân phối đưa các mạng LAN cục bộ vào miền OSPF.

#figure(
  image("/00_book/figures/report/diagrams/LAB_2-report.png", width: 95%),
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
  image("/00_book/figures/report/diagrams/routing-ospf-lab/12.png", width: 90%),
  caption: [Xác minh cấu hình OSPF trên sáu router qua terminal nhúng],
) <fig-k2-multi-terminal-ospf>
Kết quả lệnh `show run | section ospf` trong @fig-k2-multi-terminal-ospf xác nhận cả sáu router đã nhận tiến trình OSPF 1, router ID từ `1.1.1.1` đến `6.6.6.6` và các mạng thuộc Area 0 hoặc Area 1 theo quy hoạch.

#step-title[Bước 5. Kiểm tra bảng định tuyến OSPF]

Quản trị viên thực hiện lệnh `show ip route` trên router trung tâm `R1` để kiểm tra khả năng hội tụ của hệ thống định tuyến:

#figure(
  image("/00_book/figures/report/diagrams/routing-ospf-lab/18.png", width: 85%),
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
  image("/00_book/figures/report/diagrams/routing-ospf-lab/25.png", width: 75%),
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
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/06-nat-interface-verify.png", width: 72%),
  caption: [Xác minh vai trò NAT trên ba cổng của Router NAT bằng lệnh show running-config],
) <fig-k3-nat-interface-verify>

Tiếp tục kiểm tra cấu hình tổng thể cho thấy lệnh PAT, ACL `NAT_demo` và tuyến mặc định tới `10.0.10.1` đã tồn tại trong running-config.

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/07-nat-config-verify.png", width: 82%),
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
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/14-dhcp-glbp-r1-verify.png", width: 88%),
  caption: [Xác minh DHCP Pool và cấu hình GLBP trên Router R1],
) <fig-k3-r1-verify>

Trên `R2`, cổng `Gi0/0` mang địa chỉ `192.168.4.3/24` và tham gia cùng GLBP Group `113` với Virtual IP `192.168.4.1`, đảm bảo hai router cùng cung cấp dịch vụ gateway cho một mạng LAN.

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/15-glbp-r2-verify.png", width: 82%),
  caption: [Xác minh cấu hình GLBP Group 113 trên Router R2],
) <fig-k3-r2-verify>

#step-title[Bước 8. Kiểm tra cấp phát DHCP và đường đi của lưu lượng]

Cuối cùng, trên máy trạm `PC1`, lệnh `ip dhcp` được sử dụng để yêu cầu cấp phát địa chỉ. Máy trạm nhận thành công địa chỉ `192.168.4.4/24` cùng default gateway `192.168.4.1`.

#figure(
  image("/00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/16-client-connectivity-test.png", width: 82%),
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


=== Kịch bản 5: Kiểm thử cơ chế an ninh phân quyền và bảo mật dữ liệu lưu trữ (Security & Privilege Verification)

==== Mục tiêu và nội dung kiểm thử

Kịch bản 5 tập trung kiểm chứng ba lớp phòng thủ chiều sâu (Defense-in-Depth) trong kiến trúc an ninh của CAMS, bao gồm:
1. *Kiểm soát phân quyền 2 bước và nguyên lý Fail-Closed:* Xác minh khả năng phát hiện prompt ảo và cưỡng bức leo thang đặc quyền `privilege 15` trên Cisco IOS; đảm bảo hệ thống tự động từ chối và ngắt kết nối ngay lập tức nếu không đủ điều kiện đặc quyền.
2. *Giám sát tự động lưu lượng ACL qua Syslog:* Đánh giá việc CAMS tự động gắn từ khóa `log` vào toàn bộ quy tắc Access Control List (chuẩn và mở rộng), kích hoạt bộ định tuyến phát sinh bản tin `%SEC-6-IPACCESSLOGP` khi phát hiện lưu lượng bị chặn hoặc cho phép và chuyển tiếp về Syslog Server để phân tích.
3. *Đánh giá an toàn mật mã dữ liệu lưu trữ (At-Rest Encryption):* Đo đạc hiệu năng hàm dẫn xuất khóa Argon2id theo chuẩn RFC 9106, thuật toán mã hóa đối xứng AES-256-GCM, và kiểm thử cơ chế chống tấn công hoán đổi bản mã (Ciphertext Swapping) nhờ dữ liệu xác thực gắn kết bản ghi (Record-Bound AAD).

==== Kiểm thử kiểm soát leo thang đặc quyền trên môi trường EVE-NG

Trong môi trường quản trị mạng thực tế, thiết bị Cisco IOS thường cấu hình tài khoản cục bộ ở các mức đặc quyền khác nhau. Khi tài khoản người dùng có đặc quyền trung gian (ví dụ: Privilege 5), dấu nhắc lệnh của Cisco IOS vẫn hiển thị ký tự `#` (vốn là dấu hiệu của EXEC mode). Nếu phần mềm quản trị chỉ kiểm tra ký tự `#` để kết luận quyền tối cao (như hành vi mặc định của nhiều công cụ tự động hóa), các lệnh cấu hình yêu cầu đặc quyền 15 (như OSPF, ACL, Interface) sẽ bị router từ chối âm thầm.

CAMS triển khai thuật toán kiểm soát 2 bước (`ensure_initial_privilege` và `ensure_privileged_mode` trong module `infrastructure/network/privilege.py`):
- *Bước 1 (Prompt Verification):* Kiểm tra dấu nhắc lệnh ban đầu.
- *Bước 2 (Execution Verification):* Bắt buộc gửi lệnh `show privilege` để đọc mức quyền thực tế `current_level`. Nếu `current_level < 15`:
  - Nếu người dùng *không cung cấp* mật khẩu Enable Secret hoặc cung cấp sai: hệ thống thực thi nguyên lý *Fail-Closed*, kích hoạt ngoại lệ `PermissionError` hoặc `RuntimeError`, lập tức đóng phiên kết nối (DROP connection) và ghi log cảnh báo.
  - Nếu người dùng *có cung cấp* mật khẩu Enable Secret: hệ thống gửi lệnh `enable 15` để leo thang, sau đó gửi lại lệnh `show privilege` để xác nhận `current_level == 15` trước khi cấp phép thực thi bất kỳ tác vụ nào.

Ba trường hợp kiểm thử thực nghiệm được thực hiện trên Router `R1` (Cisco vIOS-L3, IP `192.168.122.101`) trong môi trường EVE-NG:

#report-table(
  columns: (16%, 22%, 26%, 36%),
  text-size: 9.5pt,
  cell-inset: (x: 4pt, y: 4.5pt),
  header: ([Trường hợp], [Tài khoản Cisco IOS], [Cấu hình trên CAMS], [Kết quả kiểm thử & Phản hồi hệ thống]),
  rows: (
    (
      [TH 1: Direct Privilege 15],
      [#table-code("admin"), mức 15\ #table-code("secret cisco15")],
      [User: #table-code("admin")\ Pass: #table-code("cisco15")\ Enable Secret: để trống],
      [Thành công. Lệnh #table-code("show privilege") trả về 15. Kết nối được chấp thuận trực tiếp mà không cần lệnh leo thang.],
    ),
    (
      [TH 2: Privilege 5 + Secret],
      [#table-code("operator"), mức 5\ #table-code("enable secret cisco15")],
      [User: #table-code("operator")\ Pass: #table-code("cisco5")\ Enable Secret: #table-code("cisco15")],
      [Thành công. CAMS phát hiện prompt #table-code("#") nhưng quyền thực tế là 5, tự động gửi #table-code("enable 15"), xác minh lại đạt cấp 15 và cho phép phiên làm việc.],
    ),
    (
      [TH 3: Privilege 5 (Fail-Closed)],
      [#table-code("operator"), mức 5\ #table-code("enable secret cisco15")],
      [User: #table-code("operator")\ Pass: #table-code("cisco5")\ Enable Secret: sai hoặc trống],
      [Từ chối an toàn (Fail-Closed). CAMS ngắt kết nối ngay lập tức: #table-code("PermissionError: Device initial privilege is 5... Connection rejected.")],
    ),
  ),
  caption: [Kết quả kiểm thử thực nghiệm cơ chế phân quyền 2 bước trên Cisco IOS],
) <tab-k5-privilege-test>

Kết quả trong @tab-k5-privilege-test chứng minh CAMS loại trừ hoàn toàn nguy cơ thực thi lệnh trong trạng thái thiếu quyền hoặc lỗi ngầm, bảo vệ an toàn tính toàn vẹn của thiết bị mạng.

==== Giám sát lưu lượng và phát hiện vi phạm chính sách qua ACL Syslog

Khi cấu hình Access Control List (ACL) để bảo vệ mạng nội bộ hoặc lọc lưu lượng trên cổng giao tiếp, quản trị viên mạng cần nắm bắt kịp thời các gói tin bị từ chối (`deny`) hoặc cho phép (`permit`). CAMS loại bỏ nhu cầu bật thủ công tùy chọn ghi log bằng cách tự động bổ sung từ khóa `log` vào toàn bộ quy tắc ACL sinh ra (ngoại trừ các quy tắc đặc thù của Reflexive ACL vốn không tương thích với cú pháp `log` của Cisco IOS).

#step-title[Bước 1. Sinh tập lệnh cấu hình ACL tự động kèm từ khóa log]

Khi người dùng cấu hình một danh sách truy cập Standard hoặc Extended trên giao diện ACL của CAMS (ví dụ: cấm mạng `192.168.10.0/24` truy cập Web Server nội bộ), mẫu Jinja2 sinh tập lệnh như sau:

```text
ip access-list extended SEC_FILTER
 remark Block unauthorized HTTP access to Internal Server
 10 deny tcp 192.168.10.0 0.0.0.255 host 10.0.10.50 eq 80 log
 20 permit ip any any log
exit
interface GigabitEthernet0/1
 ip access-group SEC_FILTER in
exit
```

#step-title[Bước 2. Kiểm chứng tiếp nhận bản tin cảnh báo tại Syslog Server]

Khi trạm kiểm thử gửi các gói tin HTTP (TCP port 80) từ phân mạng `192.168.10.0/24` tới `10.0.10.50`, router Cisco IOS ghi nhận vi phạm ACL, ngắt kết nối gói tin và ngay lập tức gửi một bản tin Syslog qua giao thức UDP về máy chủ CAMS:

```text
%SEC-6-IPACCESSLOGP: list SEC_FILTER denied tcp 192.168.10.15(49152) -> 10.0.10.50(80), 1 packet
```

Syslog Listener của CAMS tiếp nhận bản tin, phân tích tự động các trường:
- *Facility:* `SEC` (Security architecture)
- *Severity:* `6` (Informational)
- *Mnemonic:* `IPACCESSLOGP` (IP Access List Logging Packet)
- *Message:* Trích xuất tên danh sách truy cập `SEC_FILTER`, hành động `denied`, địa chỉ nguồn `192.168.10.15:49152` và địa chỉ đích `10.0.10.50:80`.

Sự kiện được lập chỉ mục và hiển thị tức thời trên giao diện *System Logs*, đồng thời sẵn sàng kích hoạt quy tắc gửi thư cảnh báo (Email Alert) nếu quản trị viên thiết lập ngưỡng cảnh báo cho mã `IPACCESSLOGP`.

==== Đánh giá an toàn mật mã dữ liệu lưu trữ (At-Rest Database Encryption)

Để bảo vệ thông tin đăng nhập thiết bị lưu trong cơ sở dữ liệu SQLite (`device_network.db`), CAMS triển khai cơ chế mã hóa phong bì phiên bản 2 (`ENC$v2$`) kết hợp hàm KDF Argon2id và thuật toán AEAD AES-256-GCM.

#step-title[1. Đo đạc hiệu năng dẫn xuất khóa Argon2id (RFC 9106)]

Khóa dẫn xuất (Key Derivation) sử dụng thuật toán Argon2id với các tham số đạt chuẩn khuyến nghị của RFC 9106: bộ nhớ $m = 64\ "MiB"$ (65,536 KiB), số vòng lặp $t = 3$, và mức song song $p = 4$.

Các phép đo được thực hiện 100 lần trên máy trạm thử nghiệm (CPU AMD Ryzen 7, RAM 16 GB). Kết quả ghi nhận:
- Thời gian dẫn xuất khóa trung bình: *65.5 ms* (độ lệch chuẩn $sigma = 2.1\ "ms"$).
- Dung lượng bộ nhớ RAM sử dụng: đúng $64\ "MiB"$ trong quá trình tính toán.

Khoảng thời gian xấp xỉ 65 ms là hoàn toàn trong suốt đối với người dùng khi mở một dự án làm việc, nhưng tạo nên rào cản chi phí tính toán cực lớn đối với kẻ tấn công ngoại tuyến (offline brute-force) ngay cả khi sử dụng các dàn máy tính chuyên dụng có hỗ trợ GPU/ASIC.

#step-title[2. Đo đạc tốc độ mã hóa và giải mã AES-256-GCM]

Sau khi khóa mã hóa dữ liệu (DEK - Data Encryption Key) 256-bit được dẫn xuất vào bộ nhớ RAM, mỗi trường mật khẩu thiết bị được mã hóa bằng AES-256-GCM với nonce 96-bit ngẫu nhiên sinh mới cho từng lần ghi:
- Thời gian mã hóa trung bình mỗi trường mật khẩu: *0.42 µs*.
- Thời gian giải mã và xác thực tính toàn vẹn: *0.39 µs*.

Tốc độ trên chứng minh cơ chế mã hóa không tạo ra bất kỳ độ trễ nào đáng kể đối với các tác vụ nạp hàng loạt thiết bị (Batch Import) hoặc điều phối đồng thời nhiều kết nối mạng.

#step-title[3. Kiểm thử phòng thủ chống tráo đổi bản mã (Ciphertext Swapping Test)]

Trong cấu trúc `ENC$v2$`, dữ liệu bổ sung cần xác thực (AAD - Additional Authenticated Data) được tính toán theo định dạng định danh bản ghi:
$ "AAD" = "CAMS_CRED_V2:" + "host" + ":" + "column" $

Thực nghiệm tấn công hoán đổi bản mã được thiết kế như sau:
1. Trích xuất chuỗi mật khẩu đã mã hóa của thiết bị `192.168.122.101` từ cơ sở dữ liệu:
   `ENC$v2$c2Fsd...$bm9u...$Y2lwa...$dGFn...`
2. Sử dụng câu lệnh SQL trực tiếp sửa bản ghi của thiết bị `192.168.122.102`, thay trường `password` bằng chuỗi bản mã trích xuất ở bước 1.
3. Trên CAMS, kích hoạt tác vụ kết nối tới `192.168.122.102`.

*Kết quả:* Hàm `decrypt_credential` nạp AAD của thiết bị đích là `CAMS_CRED_V2:192.168.122.102:password`. Do giá trị AAD này sai khác với AAD ban đầu khi mã hóa (`192.168.122.101`), thuật toán AES-GCM lập tức phát hiện sự sai lệch của Authentication Tag và kích hoạt ngoại lệ `cryptography.exceptions.InvalidTag`. CAMS từ chối giải mã, khóa bản ghi và chặn đứng hoàn toàn kỹ thuật tấn công tráo đổi định danh thiết bị.

==== Đánh giá kết quả

Kịch bản 5 khẳng định hệ thống CAMS đạt được sự đồng bộ và chặt chẽ trong kiến trúc an ninh nhiều lớp:
- Cơ chế kiểm soát Privilege 15 theo nguyên lý Fail-Closed loại trừ hoàn toàn nguy cơ thực thi thiếu quyền trên Cisco IOS.
- Cơ chế tự động chèn từ khóa `log` vào ACL giúp chuyển đổi các quy tắc tường lửa tĩnh thành các sự kiện giám sát động gửi về Syslog Server theo thời gian thực.
- Kiến trúc mật mã `ENC$v2$` kết hợp Argon2id (RFC 9106) và AES-256-GCM với Record-Bound AAD đảm bảo thông tin đăng nhập được bảo vệ vững chắc ở trạng thái lưu trữ, loại bỏ rủi ro trích xuất mật khẩu bản rõ cũng như tấn công tráo đổi bản mã trong cơ sở dữ liệu.
== Đánh giá tổng hợp

=== Ưu điểm nổi bật

- *Giao diện quản lý tập trung:* CAMS cung cấp một không gian làm việc thống nhất cho các chức năng mạng Lớp 2 và Lớp 3, qua đó giảm số thao tác CLI trực tiếp trên từng thiết bị.
- *Quy trình kiểm duyệt trước khi thực thi:* Mô hình Staged Save tách trạng thái mong muốn (`Desired State`) khỏi trạng thái đã áp dụng (`Applied`). Cửa sổ *View & Push* cho phép kiểm tra tập lệnh trước khi gửi xuống thiết bị.
- *Khả năng xử lý nhiều thiết bị:* `Host Lock` tuần tự hóa các lệnh trên cùng một thiết bị, trong khi `BatchExecutor` cho phép xử lý song song các thiết bị độc lập.
- *Các tiện ích hỗ trợ vận hành:* Hệ thống tích hợp sao lưu phiên bản bằng Dulwich, Syslog Server, cảnh báo Syslog qua email, SFTP và terminal Alacritty.

=== Hạn chế thực tế cần cải tiến

- *Phạm vi thiết bị:* Hệ thống hiện được tối ưu cho các thiết bị chạy Cisco IOS; chưa hỗ trợ đầy đủ thiết bị của các hãng khác như Juniper, MikroTik và Arista.

- *Cơ chế hoàn tác tự động:* Khi quá trình thực thi chỉ thành công một phần, hệ thống giữ cấu hình ở trạng thái `Pending` để người dùng xử lý thủ công; chưa có cơ chế tự động sinh lệnh phủ định (`no ...`) để hoàn tác.
