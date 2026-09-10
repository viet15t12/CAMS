# Interface trên Switch Layer 3

Role **SW3** giữ toàn bộ chức năng switchport của SW2 và bổ sung hai tab
**Routed Ports** và **SVI**. Đây là hai cách tạo điểm định tuyến trên switch:

- **Routed Port** dùng một cổng vật lý như interface Layer 3, không còn tham gia
  chuyển mạch VLAN;
- **SVI** tạo interface logic `VlanX`, thường làm default gateway cho các máy
  trong VLAN;
- **IP Routing** cho phép switch chuyển tiếp gói giữa các mạng Layer 3 đã kết
  nối.

Các thao tác Access, Trunk, VLAN, EtherChannel, STP, VTP, L2 Security, Port
Security và Monitoring giống SW2; xem lại [Chương 14](14_interface_switch_l2.md),
[Chương 15](15_vlan_etherchannel_stp_vtp.md),
[Chương 16](16_bao_mat_switch_l2.md) và
[Chương 17](17_giam_sat_switch_l2.md).

## Cấu hình Routed Port

Mở **Interfaces → Routed Ports**, chọn cổng rồi nhấn **Edit**. Nếu cổng đang là
Access hoặc Trunk, có thể chuyển mode thành `routed` từ **Switch Ports → Port
Status**; sau khi Save, cổng xuất hiện trong danh sách Routed Ports.

<figure>
<p><img src="../../figures/gui/chapter-18/01-routed-port-form.png"
style="width:55.0%" /></p>
<figcaption><p>Form Routed Port được phóng lớn để đọc rõ từng trường.</p></figcaption>
</figure>

| Trường | Cách nhập và tác dụng |
|---|---|
| **Interface name** | Tên cổng vật lý đang chọn, ví dụ `GigabitEthernet0/1`. Khi Edit, trường này chỉ đọc để tránh đổi nhầm định danh. |
| **Description** | Ghi mục đích hoặc đầu nối phía bên kia, ví dụ `Point-to-point core uplink`. |
| **Admin status** | `up` tạo `no shutdown`; `down` đóng cổng có chủ đích. |
| **Speed** | Dùng `auto` nếu hai đầu tự thương lượng tốt; chỉ đặt `1000`, `10000`… khi phần cứng hai đầu hỗ trợ cùng tốc độ. |
| **Duplex** | Thường chọn `auto` hoặc `full`. Giá trị không khớp ở hai đầu có thể gây lỗi và suy giảm thông lượng. |
| **Mode** | Luôn là `routed`; CAMS sinh `no switchport` để bỏ hành vi switchport Layer 2. |

Form Routed Port hiện tại quản lý **mode và trạng thái link**, chưa có trường nhập
địa chỉ IPv4. Không dùng một màn hình khác để nhập địa chỉ cho cổng vật lý khi
workflow hiện tại chưa hỗ trợ. Khi cần
gateway cho VLAN, dùng SVI; khi cần địa chỉ trên chính routed port, phải bảo đảm
workflow đồng bộ interface của hệ thống đã hỗ trợ thiết bị và phiên bản IOS đang
dùng.

<figure>
<p><img src="../../figures/gui/chapter-18/02-routed-ports-overview.png"
style="width:100.0%" /></p>
<figcaption><p>Danh sách Routed Ports và trạng thái link của SW3.</p></figcaption>
</figure>

Các chỉ số phía trên cho biết tổng routed port, số link up, số Access và số
port đang admin up. Một routed port không mang Access VLAN, Voice VLAN, Native
VLAN hoặc Allowed VLANs.

### View & Push cho Routed Port

Routed Port dùng chung controller **INTERFACES** với Switch Ports. Sau khi Save,
quay lại **Switch Ports** và mở **View & Push** để kiểm tra lệnh `no switchport`
trên đúng cổng.

<figure>
<p><img src="../../figures/gui/chapter-18/03-interfaces-view-push-routed.png"
style="width:78.0%" /></p>
<figcaption><p>Preview Interfaces có lệnh chuyển GigabitEthernet0/1 thành routed port.</p></figcaption>
</figure>

Trước khi Push, kiểm tra tên interface, description, speed, duplex, `no
switchport` và `no shutdown`. Việc chuyển một trunk hoặc access port sang routed
port sẽ loại bỏ VLAN forwarding trên cổng đó; nên có đường quản trị dự phòng nếu
cổng đang mang lưu lượng quản trị.

## Cấu hình SVI

SVI là interface logic gắn với một VLAN đã tồn tại. Mở **Interfaces → SVI**, nhấn
**Add** để tạo mới hoặc chọn một hàng rồi nhấn **Edit**.

<figure>
<p><img src="../../figures/gui/chapter-18/04-svi-form.png"
style="width:52.0%" /></p>
<figcaption><p>Form SVI với VLAN ID, địa chỉ gateway, subnet mask và trạng thái quản trị.</p></figcaption>
</figure>

| Trường | Cách nhập và tác dụng |
|---|---|
| **VLAN ID** | Nhập `1–4094`. VLAN phải được tạo và ở trạng thái active trong tab VLAN trước khi tạo SVI. Khi Edit, VLAN ID chỉ đọc. |
| **IP address** | Địa chỉ Layer 3 của SVI, thường là default gateway của client, ví dụ `10.10.10.1`. Không dùng trùng địa chỉ của SVI khác. |
| **Subnet mask** | Chấp nhận dạng đầy đủ như `255.255.255.0` hoặc CIDR như `/24`. Phải nhập cùng IP address. |
| **Administratively enabled** | Bật để sinh `no shutdown`; tắt để giữ SVI trong trạng thái shutdown. |

Địa chỉ SVI phải thuộc đúng subnet của VLAN. Ví dụ VLAN 10 dùng mạng
`10.10.10.0/24` thì có thể đặt SVI là `10.10.10.1/24` và dùng địa chỉ này làm
Default Router trong DHCP Pool của VLAN 10.

SVI chỉ có thể hoạt động khi VLAN tồn tại và có ít nhất một port thuộc VLAN đang
hoạt động, tùy hành vi của nền tảng. `Administratively enabled` không bảo đảm
trạng thái line protocol đã up.

## Bật IP Routing

Nút **IP Routing** nằm trên thanh tiêu đề của tab SVI. Bật tùy chọn này khi SW3
cần định tuyến giữa các SVI hoặc giữa SVI và routed port. Nếu chỉ dùng switch
như thiết bị Layer 2, có thể để tắt.

<figure>
<p><img src="../../figures/gui/chapter-18/05-svi-overview-ip-routing.png"
style="width:100.0%" /></p>
<figcaption><p>Ba SVI đã có địa chỉ và trạng thái IP Routing đang On.</p></figcaption>
</figure>

Không bật IP Routing chỉ vì đã tạo SVI. Trước hết cần kiểm tra sơ đồ địa chỉ,
VLAN membership, default gateway của client, route mặc định/upstream và ACL áp
dụng trên các SVI.

## View & Push SVI

SVI có nút **View & Push** riêng. Nút này dựng lệnh IP Routing và toàn bộ SVI đang
chờ, không trộn với View & Push Interfaces hoặc VLAN.

<figure>
<p><img src="../../figures/gui/chapter-18/06-svi-view-push.png"
style="width:78.0%" /></p>
<figcaption><p>Preview riêng của SVI gồm `ip routing` và từng `interface Vlan`.</p></figcaption>
</figure>

Kiểm tra các điểm sau trước khi Push:

- `ip routing` chỉ xuất hiện khi thật sự cần định tuyến Layer 3;
- mỗi `interface VlanX` khớp đúng VLAN đã tạo;
- IP address và subnet mask không chồng lấn với interface khác;
- `shutdown` hoặc `no shutdown` đúng chủ đích;
- không có lệnh `no` xóa SVI hoặc tắt IP Routing ngoài dự kiến.

Sau Push, đồng bộ lại thiết bị và kiểm tra trạng thái SVI, bảng route connected,
ping giữa các gateway, ping từ client tới gateway và lưu lượng liên VLAN theo
đúng ACL.
