#import "../config/tables.typ": report-table

=== Kịch bản 1: Kiểm thử DHCP Snooping và Dynamic ARP Inspection

==== Mô hình Lab 1 và mục tiêu kiểm thử DHCP Snooping

Kịch bản kiểm tra khả năng áp dụng chính sách DHCP Snooping từ CAMS xuống switch và đối chiếu nguồn cấp địa chỉ của máy khách khi thay đổi cổng tin cậy (trusted). Hai DHCP server sử dụng hai dải địa chỉ khác nhau để nhận diện nguồn cấp phát: R1 cung cấp mạng `192.168.10.0/24`, còn FAKE_DHCP cung cấp mạng `192.168.66.0/24`. R2 đóng vai trò DHCP client. Tiêu chí kiểm thử là địa chỉ R2 nhận được phải thuộc dải của server nối vào cổng được trust trong từng trạng thái.

#figure(image("/00_book/figures/report/diagrams/dhcp-snooping-lab/topology.png", width: 100%), caption: [Mô hình Lab 1 với hai DHCP server, switch SW1 và client R2.]) <fig-k1-topology>

Trong @fig-k1-topology, thiết bị có nhãn Switch tương ứng với SW1 trong CAMS. Các liên kết thử nghiệm đi qua VLAN 10; mạng ManagementM phục vụ quản trị thiết bị. Tên FAKE_DHCP được giữ theo mô hình lab. Ở trạng thái thứ hai, cổng nối thiết bị này được chủ động cấp quyền trusted để kiểm tra việc chuyển chính sách.

#report-table(
 columns: (18%, 25%, 25%, 32%),
 header: ([Thiết bị], [Vai trò], [Kết nối thử nghiệm], [Địa chỉ / dải cấp phát]),
 rows: (
  ([SW1], [DHCP Snooping trên VLAN 10], [Gi0/1, Gi0/2, Gi0/3], [Quản trị: 192.168.122.101]),
  ([R1], [DHCP server thứ nhất], [Gi0/1 nối SW1 Gi0/1], [192.168.10.0/24]),
  ([R2], [DHCP client], [Gi0/2 nối SW1 Gi0/2], [Địa chỉ nhận động]),
  ([FAKE\_DHCP], [DHCP server thứ hai], [Gi0/1 nối SW1 Gi0/3], [192.168.66.0/24]),
 ), caption: [Thành phần và kết nối của bài kiểm thử DHCP Snooping.],
) <tab-k1-topology>

==== Thiết lập chính sách và tiêu chí đối chiếu

Trên CAMS, mục *Security → L2 Security → VLAN Protection* hiển thị DHCP Snooping ở trạng thái Enabled trên VLAN 10, còn DAI ở trạng thái Disabled (@fig-k1-vlan). Giai đoạn này đánh giá DHCP Snooping với DAI tắt. Phần kiểm thử DAI trên cùng mô hình được trình bày ở các mục tiếp theo của Lab 1.

#figure(image("/00_book/figures/report/diagrams/dhcp-snooping-lab/vlan10-snooping.png", width: 100%), caption: [DHCP Snooping được bật trên VLAN 10; DAI không tham gia bài kiểm thử.]) <fig-k1-vlan>

R1 sử dụng pool VLAN10, mạng `192.168.10.0`, mặt nạ `255.255.255.0` và gateway `192.168.10.1` như @fig-k1-pool. Server FAKE_DHCP sử dụng pool FAKE_TEST thuộc mạng `192.168.66.0/24`. Hai dải địa chỉ phân biệt giúp đối chiếu kết quả cấp phát mà không phụ thuộc vào số thứ tự địa chỉ thuê trong mỗi pool.

#figure(image("/00_book/figures/report/diagrams/dhcp-snooping-lab/r1-pool.png", width: 100%), caption: [Pool DHCP trên R1 dùng làm nguồn cấp phát ở trạng thái A.]) <fig-k1-pool>

Quy trình gồm hai trạng thái liên tiếp. Ở mỗi trạng thái, chỉ một cổng nối server được đặt DHCP trust; cổng Gi0/2 nối client giữ untrusted. Sau khi áp dụng chính sách, R2 yêu cầu cấp địa chỉ DHCP và trạng thái giao diện được đối chiếu trên CAMS. Khi chuyển trạng thái, cần thực hiện lại việc xin địa chỉ, tránh dùng địa chỉ thuê cũ làm kết quả kiểm thử.

#report-table(
 columns: (14%, 24%, 24%, 38%),
 header: ([Trạng thái], [SW1 Gi0/1 → R1], [SW1 Gi0/3 → FAKE\_DHCP], [Kết quả mong đợi tại R2]),
 rows: (
  ([A], [Trusted], [Untrusted], [Địa chỉ thuộc 192.168.10.0/24]),
  ([B], [Untrusted], [Trusted], [Địa chỉ thuộc 192.168.66.0/24]),
 ), caption: [Hai trạng thái chính sách dùng để đối chiếu nguồn cấp DHCP.],
) <tab-k1-policy>

==== Trạng thái A: Trust cổng nối R1

Danh sách *Trusted Uplinks* sau đồng bộ trong @fig-k1-trust-a chỉ có `GigabitEthernet0/1` với điều khiển *DHCP trust*. Bộ đếm DAI VLANs bằng 0. Đây là cấu hình cho phép nguồn DHCP phía R1 tham gia cấp phát trong bài kiểm thử.

#figure(image("/00_book/figures/report/diagrams/dhcp-snooping-lab/trust-gi01.png", width: 100%), caption: [Trạng thái A: SW1 chỉ trust DHCP trên Gi0/1 nối R1.]) <fig-k1-trust-a>

Kết quả trên giao diện R2 cho thấy `GigabitEthernet0/2` có địa chỉ `192.168.10.5` (@fig-k1-address-a), thuộc dải cấp phát của R1. Địa chỉ quản trị `192.168.122.103` vẫn nằm trên Gi0/0 và được phân biệt với địa chỉ dùng trong thử nghiệm.

#figure(image("/00_book/figures/report/diagrams/dhcp-snooping-lab/r2-address-r1.png", width: 100%), caption: [R2 nhận địa chỉ 192.168.10.5 khi cổng nối R1 được trust.]) <fig-k1-address-a>

==== Trạng thái B: Chuyển trust sang cổng nối FAKE_DHCP

Chính sách được thay đổi bằng cách bỏ DHCP trust trên Gi0/1 và đặt DHCP trust trên Gi0/3. @fig-k1-trust-b hiển thị duy nhất `GigabitEthernet0/3` trong danh sách trusted, đồng thời thông báo đã áp dụng hai tác vụ switching. Việc chuyển quyền được thực hiện theo cổng; tên thiết bị FAKE_DHCP không quyết định quyền cấp phát.

#figure(image("/00_book/figures/report/diagrams/dhcp-snooping-lab/trust-gi03.png", width: 100%), caption: [Trạng thái B: chuyển DHCP trust từ Gi0/1 sang Gi0/3.]) <fig-k1-trust-b>

Trên R2, cửa sổ *View & Push* trong @fig-k1-request hiển thị lệnh `ip address dhcp` cho `GigabitEthernet0/2`. Ảnh này ghi nhận bước cấu hình client; kết quả cấp phát được đối chiếu riêng ở @fig-k1-address-b.

#figure(image("/00_book/figures/report/diagrams/dhcp-snooping-lab/r2-request-dhcp.png", width: 100%), caption: [CAMS chuẩn bị cấu hình DHCP client trên Gi0/2 của R2 sau khi chuyển trust.]) <fig-k1-request>

Sau lần yêu cầu DHCP tiếp theo, giao diện Gi0/2 của R2 hiển thị `192.168.66.100`. Địa chỉ này thuộc dải của FAKE_DHCP, khác dải `192.168.10.0/24` ở trạng thái A. Kết quả phù hợp với việc cổng Gi0/3 đã được chuyển sang trusted.

#figure(image("/00_book/figures/report/diagrams/dhcp-snooping-lab/r2-address-fake.png", width: 100%), caption: [R2 nhận địa chỉ 192.168.66.100 sau khi trust cổng nối FAKE_DHCP.]) <fig-k1-address-b>

==== Tổng hợp kết quả DHCP Snooping

#report-table(
 columns: (15%, 24%, 27%, 34%),
 header: ([Trạng thái], [Cổng DHCP trusted], [Địa chỉ R2 quan sát được], [Đối chiếu]),
 rows: (
  ([A], [Gi0/1 nối R1], [192.168.10.5], [Thuộc pool của R1; phù hợp tiêu chí]),
  ([B], [Gi0/3 nối FAKE\_DHCP], [192.168.66.100], [Thuộc pool của FAKE\_DHCP; phù hợp tiêu chí]),
 ), caption: [Kết quả kiểm thử chuyển đổi cổng DHCP trusted trong Lab 1.],
) <tab-k1-results>

Hai trạng thái quan sát cho thấy nguồn cấp địa chỉ cho R2 thay đổi tương ứng với cổng được cấp DHCP trust trên SW1. Kết quả hỗ trợ đánh giá chức năng cấu hình DHCP Snooping của CAMS theo chuỗi thao tác thiết lập chính sách, áp dụng xuống thiết bị và đối chiếu trạng thái client. Trong hai lần kiểm thử được ghi nhận, địa chỉ nhận được đều thuộc dải của server ở phía cổng trusted.

Phạm vi kết luận là kết quả cấp phát khi chuyển chính sách giữa hai cổng. Các ảnh trên không xác định từng gói DHCP bị loại bỏ và không được dùng làm bằng chứng đã nhận Syslog cảnh báo DHCP server giả mạo. Kết quả DAI được đánh giá riêng bằng binding, lưu lượng ARP, bộ đếm loại bỏ và Syslog trong phần tiếp theo.
