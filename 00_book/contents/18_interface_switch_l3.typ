#import "../config/commands.typ": report-note
// Nguồn nội dung: DOC/18_interface_switch_l3.md
#import "../config/images.typ": insert-image
#import "../config/tables.typ": report-table

= Interface trên Switch Layer 3 <ch18>

Role *SW3* giữ toàn bộ chức năng switchport của SW2 và bổ sung hai tab *Routed Ports* và *SVI*. Đây là hai cách tạo điểm định tuyến trên switch:

- *Routed Port* dùng một cổng vật lý như interface Layer 3, không còn tham gia chuyển mạch VLAN;
- *SVI* tạo interface logic #raw("VlanX"), thường làm default gateway cho các máy trong VLAN;
- *IP Routing* cho phép switch chuyển tiếp gói giữa các mạng Layer 3 đã kết nối.

Các thao tác Access, Trunk, VLAN, EtherChannel, STP, VTP, L2 Security, Port Security và Monitoring giống SW2; xem lại @ch14, @ch15, @ch16 và @ch17.

== Cấu hình Routed Port

Mở *Interfaces → Routed Ports*, chọn cổng rồi nhấn *Edit*. Nếu cổng đang là Access hoặc Trunk, có thể chuyển mode thành #raw("routed") từ *Switch Ports → Port Status*; sau khi Save, cổng xuất hiện trong danh sách Routed Ports.

#insert-image("figures/gui/chapter-18/01-routed-port-form.png",
  caption: [Các trường mode và trạng thái liên kết của Routed Port.], width: 55.0%) <fig:ch18-01-routed-port-form>

#report-table(
  columns: (1.15fr, 2.85fr),
  header: ([Trường], [Cách nhập và tác dụng]),
  rows: (
    ([*Interface name*], [Tên cổng vật lý đang chọn, ví dụ #raw("GigabitEthernet0/1"). Khi Edit, trường này chỉ đọc để tránh đổi nhầm định danh.]),
    ([*Description*], [Ghi mục đích hoặc đầu nối phía bên kia, ví dụ #raw("Point-to-point core uplink").]),
    ([*Admin status*], [#raw("up") tạo #raw("no shutdown"); #raw("down") đóng cổng có chủ đích.]),
    ([*Speed*], [Dùng #raw("auto") nếu hai đầu tự thương lượng tốt; chỉ đặt #raw("1000"), #raw("10000")… khi phần cứng hai đầu hỗ trợ cùng tốc độ.]),
    ([*Duplex*], [Thường chọn #raw("auto") hoặc #raw("full"). Giá trị không khớp ở hai đầu có thể gây lỗi và suy giảm thông lượng.]),
    ([*Mode*], [Luôn là #raw("routed"); CAMS sinh #raw("no switchport") để bỏ hành vi switchport Layer 2.]),
  ),
  caption: [Cấu hình Routed Port],
  figure-label: <tab:ch18-table-1>,
)

#report-note[Form Routed Port hiện tại quản lý *mode và trạng thái link*, chưa có trường nhập địa chỉ IPv4. Không dùng một màn hình khác để nhập địa chỉ cho cổng vật lý khi workflow hiện tại chưa hỗ trợ. Khi cần gateway cho VLAN, dùng SVI; khi cần địa chỉ trên chính routed port, phải bảo đảm workflow đồng bộ interface của hệ thống đã hỗ trợ thiết bị và phiên bản IOS đang dùng.]

Các chỉ số phía trên cho biết tổng routed port, số link up, số Access và số port đang admin up. Một routed port không mang Access VLAN, Voice VLAN, Native VLAN hoặc Allowed VLANs.

=== View & Push cho Routed Port

Routed Port dùng chung controller *INTERFACES* với Switch Ports. Sau khi Save, quay lại *Switch Ports* và mở *View & Push* để kiểm tra lệnh #raw("no switchport") trên đúng cổng.

#insert-image("figures/gui/chapter-18/03-interfaces-view-push-routed.png",
  caption: [Preview Interfaces có lệnh chuyển GigabitEthernet0/1 thành routed port.], width: 78.0%) <fig:ch18-03-interfaces-view-push-routed>

Trước khi Push, kiểm tra tên interface, description, speed, duplex, #raw("no switchport") và #raw("no shutdown"). Việc chuyển một trunk hoặc access port sang routed port sẽ loại bỏ VLAN forwarding trên cổng đó; nên có đường quản trị dự phòng nếu cổng đang mang lưu lượng quản trị.

== Cấu hình SVI

SVI là interface logic gắn với một VLAN đã tồn tại. Mở *Interfaces → SVI*, nhấn *Add* để tạo mới hoặc chọn một hàng rồi nhấn *Edit*.

#insert-image("figures/gui/chapter-18/04-svi-form.png",
  caption: [Form SVI với VLAN ID, địa chỉ gateway, subnet mask và trạng thái quản trị.], width: 52.0%) <fig:ch18-04-svi-form>

#report-table(
  columns: (1.15fr, 2.85fr),
  header: ([Trường], [Cách nhập và tác dụng]),
  rows: (
    ([*VLAN ID*], [Nhập #raw("1–4094"). VLAN phải được tạo và ở trạng thái active trong tab VLAN trước khi tạo SVI. Khi Edit, VLAN ID chỉ đọc.]),
    ([*IP address*], [Địa chỉ Layer 3 của SVI, thường là default gateway của client, ví dụ #raw("10.10.10.1"). Không dùng trùng địa chỉ của SVI khác.]),
    ([*Subnet mask*], [Chấp nhận dạng đầy đủ như #raw("255.255.255.0") hoặc CIDR như #raw("/24"). Phải nhập cùng IP address.]),
    ([*Administratively enabled*], [Bật để sinh #raw("no shutdown"); tắt để giữ SVI trong trạng thái shutdown.]),
  ),
  caption: [Cấu hình SVI],
  figure-label: <tab:ch18-table-2>,
)

Địa chỉ SVI phải thuộc đúng subnet của VLAN. Ví dụ VLAN 10 dùng mạng #raw("10.10.10.0/24") thì có thể đặt SVI là #raw("10.10.10.1/24") và dùng địa chỉ này làm Default Router trong DHCP Pool của VLAN 10.

SVI chỉ có thể hoạt động khi VLAN tồn tại và có ít nhất một port thuộc VLAN đang hoạt động, tùy hành vi của nền tảng. #raw("Administratively enabled") không bảo đảm trạng thái line protocol đã up.

== Bật IP Routing

Nút *IP Routing* nằm trên thanh tiêu đề của tab SVI (xem @fig:ch18-05-svi-overview-ip-routing). Bật tùy chọn này khi SW3 cần định tuyến giữa các SVI hoặc giữa SVI và routed port. Nếu chỉ dùng switch như thiết bị Layer 2, có thể để tắt.

#insert-image("figures/gui/chapter-18/05-svi-overview-ip-routing.png",
  caption: [Ba SVI đã có địa chỉ và trạng thái IP Routing đang On.], width: 100.0%) <fig:ch18-05-svi-overview-ip-routing>

Không bật IP Routing chỉ vì đã tạo SVI. Trước hết cần kiểm tra sơ đồ địa chỉ, VLAN membership, default gateway của client, route mặc định/upstream và ACL áp dụng trên các SVI.

== View & Push SVI

SVI có nút *View & Push* riêng. Nút này dựng lệnh IP Routing và toàn bộ SVI đang chờ, không trộn với View & Push Interfaces hoặc VLAN.

#insert-image("figures/gui/chapter-18/06-svi-view-push.png",
  caption: [Preview riêng của SVI gồm #raw("ip routing") và từng #raw("interface Vlan").], width: 78.0%) <fig:ch18-06-svi-view-push>

Kiểm tra các điểm sau trước khi Push:

- #raw("ip routing") chỉ xuất hiện khi thật sự cần định tuyến Layer 3;
- mỗi #raw("interface VlanX") khớp đúng VLAN đã tạo;
- IP address và subnet mask không chồng lấn với interface khác;
- #raw("shutdown") hoặc #raw("no shutdown") đúng chủ đích;
- không có lệnh #raw("no") xóa SVI hoặc tắt IP Routing ngoài dự kiến.

Sau Push, đồng bộ lại thiết bị và kiểm tra trạng thái SVI, bảng route connected, ping giữa các gateway, ping từ client tới gateway và lưu lượng liên VLAN theo đúng ACL.
