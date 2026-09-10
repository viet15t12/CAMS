# Xem và cấu hình Interface trên Router

Chương này tiếp tục từ phần quản lý thiết bị: R1 đã có trong Workspace và dữ
liệu interface vật lý đã được lấy từ thiết bị bằng **Connect**, **Sync** hoặc
**Get running-config**. Mục tiêu là xem danh sách interface, sửa interface vật
lý, tạo interface ảo và kiểm tra lệnh trước khi Push.

Các hình được chụp từ giao diện CAMS thật với dữ liệu lab cố định. Ví dụ dùng
R1 (`192.0.2.1`, Cisco IOS); địa chỉ cấu hình bên trong form chỉ là địa chỉ mẫu
dành cho tài liệu.

## Mở tab Router Interface

Trong **Devices Sidebar**, chọn R1 để mở tab thiết bị. Trên **Feature Bar**,
chọn biểu tượng **Interface**. Màn hình **Router Interfaces** mở ở tab con
**Physical**.

<figure>
<p><img src="../../figures/gui/chapter-05/01-router-interface-overview.png"
style="width:100.0%" /></p>
<figcaption><p>Tổng quan tab Physical của Router Interface.</p></figcaption>
</figure>

Màn hình gồm ba phần cần nhận biết:

- Thanh tab con **Physical**, **Loopback**, **Tunnel** và **Subinterface** dùng
  để chọn loại interface.
- Danh sách bên trái hiển thị các interface đã lưu trong Workspace.
- Form bên phải dùng để xem hoặc chỉnh cấu hình của interface đang chọn.

Nút **Reload UI** chỉ đọc lại dữ liệu từ database của CAMS. Nó không tự lấy
running-config mới từ router. Khi danh sách Physical trống, hãy quay về
Devices Sidebar, bảo đảm thiết bị đã kết nối rồi thực hiện **Sync** hoặc
**Get running-config**.

## Xem interface vật lý đã đồng bộ

Tên interface Physical do dữ liệu đồng bộ từ thiết bị cung cấp. CAMS không cho
gõ tên mới hoặc xóa một cổng vật lý từ màn hình này. Chọn biểu tượng sửa bên
phải `GigabitEthernet0/0` để nạp dữ liệu vào form.

<figure>
<p><img src="../../figures/gui/chapter-05/02-edit-physical-interface.png"
style="width:100.0%" /></p>
<figcaption><p>Cấu hình đã lưu của GigabitEthernet0/0 được nạp vào form.</p></figcaption>
</figure>

Phần **Identity and addressing** hiển thị tên interface, profile, địa chỉ IPv4,
subnet mask, mô tả và trạng thái administratively down. Với interface vật lý,
profile **L3** cung cấp thêm các tùy chọn Layer 3; profile **WAN** dùng cho các
tham số PPP, PPPoE, HDLC hoặc Frame Relay.

## Chỉnh cấu hình Physical

Trong ví dụ dưới đây, `GigabitEthernet0/0` được đổi thành địa chỉ
`10.10.10.1/24`, mô tả `Uplink to distribution router` và bandwidth
`100000`. Kiểm tra lại địa chỉ, mask và cổng đích trước khi lưu.

<figure>
<p><img src="../../figures/gui/chapter-05/03-physical-interface-configured.png"
style="width:100.0%" /></p>
<figcaption><p>Các giá trị chuẩn bị lưu cho interface vật lý.</p></figcaption>
</figure>

Chọn **Update Interface** để lưu desired state vào Workspace. Bước này chưa gửi
lệnh xuống router. Những trường đã thay đổi được CAMS đánh dấu nội bộ để dùng
khi tạo preview.

Các tùy chọn cần chú ý:

| Trường | Ý nghĩa |
|---|---|
| Secondary IP / mask | Địa chỉ IPv4 bổ sung trên cùng interface. |
| MTU | Kích thước gói Layer 3 tối đa; giá trị Ethernet thường gặp là 1500. |
| Bandwidth | Giá trị bandwidth IOS tính theo Kbps, dùng cho metric; không phải lệnh đặt tốc độ vật lý. |
| Speed / Duplex / Negotiation | Tham số liên kết vật lý; phải tương thích với đầu bên kia. |
| Proxy ARP / Unreachables / Directed broadcast | Các hành vi IPv4 cần cân nhắc theo thiết kế và chính sách an toàn. |

## Tạo Loopback

Chọn tab **Loopback**, nhập hậu tố số rồi chọn **Create Loopback**. CAMS sinh
tên canonical, ví dụ số `0` tạo `Loopback0`; người dùng không gõ tên interface
tự do. Sau đó nhập địa chỉ, mask và mô tả rồi chọn **Save Interface**.

<figure>
<p><img src="../../figures/gui/chapter-05/04-loopback-interface.png"
style="width:100.0%" /></p>
<figcaption><p>Loopback0 dùng địa chỉ /32 làm Router ID mẫu.</p></figcaption>
</figure>

Loopback và các interface ảo có biểu tượng xóa trong danh sách. Xóa một
interface ảo đã tồn tại trên thiết bị sẽ tạo desired state tương ứng với lệnh
`no interface`; thao tác vẫn cần được kiểm tra trong View & Push.

## Tạo Tunnel

Chọn tab **Tunnel**, nhập số tunnel và chọn **Create Tunnel**. Cần có source và
destination trước khi lưu. CAMS hiện hỗ trợ các lựa chọn mode GRE, IP-in-IP,
IPsec và GRE-IPsec trong form; việc thiết bị thực tế chấp nhận cấu hình còn phụ
thuộc phiên bản IOS và cấu hình liên quan.

<figure>
<p><img src="../../figures/gui/chapter-05/05-tunnel-interface.png"
style="width:100.0%" /></p>
<figcaption><p>Tunnel10 với source, destination, key và keepalive mẫu.</p></figcaption>
</figure>

Trong ví dụ, Tunnel10 dùng `GigabitEthernet0/0` làm source,
`198.51.100.2` làm destination, key `10` và keepalive `10 3`. Source có thể là
địa chỉ cục bộ hoặc tên interface phù hợp với IOS.

## Tạo 802.1Q Subinterface

Chọn tab **Subinterface**. Chọn parent từ danh sách interface Physical đã đồng
bộ, nhập Subinterface ID rồi chọn **Create Subinterface**. Với parent
`GigabitEthernet0/0` và ID `20`, CAMS sinh tên
`GigabitEthernet0/0.20`.

<figure>
<p><img src="../../figures/gui/chapter-05/06-subinterface.png"
style="width:100.0%" /></p>
<figcaption><p>Subinterface .20 làm gateway cho VLAN 20.</p></figcaption>
</figure>

Nhập VLAN ID, địa chỉ IPv4, mask và mô tả. Chỉ bật **Native VLAN** khi thiết kế
trunk yêu cầu và hai đầu liên kết dùng cùng quy ước. Subinterface thuộc Router
Interface; SVI trên switch được quản lý trong phần Switching.

## Xem lệnh trước khi Push

Sau khi lưu các thay đổi cục bộ, chọn **View & Push**. CAMS dựng lệnh Cisco IOS
từ những bản ghi đang chờ và hiển thị host cùng từng interface trong preview.

<figure>
<p><img src="../../figures/gui/chapter-05/07-view-push-preview.png"
style="width:75.0%" /></p>
<figcaption><p>Preview tổng hợp các tác vụ Router Interface đang chờ.</p></figcaption>
</figure>

Đọc preview từ trên xuống và kiểm tra tối thiểu:

1. Host đích đúng là router cần cấu hình.
2. Tên interface, địa chỉ IP và subnet mask đúng với thiết kế.
3. Lệnh `shutdown` hoặc `no shutdown` đúng với trạng thái mong muốn.
4. VLAN ID, tunnel source/destination và các lệnh xóa không gây ảnh hưởng ngoài
   phạm vi dự kiến.

Chọn **Refresh** nếu đã sửa desired state sau khi mở hộp preview. Chỉ chọn
**Push** khi đã có bản sao running-config phù hợp và phiên SSH/Telnet tới thiết
bị đang sẵn sàng. Push hiện hỗ trợ Router Interface trên Cisco IOS qua
SSH/Telnet; RESTCONF/NETCONF, IPv6, verify sau Push và rollback tự động chưa
được tích hợp đầy đủ.

## Bài thực hành ngắn

1. Kết nối hoặc Sync R1, sau đó mở **Interface → Physical**.
2. Chọn một interface vật lý và đối chiếu tên, IP, mask với running-config.
3. Thay đổi một mô tả an toàn trong môi trường lab và chọn **Update Interface**.
4. Tạo `Loopback0` với một địa chỉ /32 dành cho lab.
5. Nếu topology có trunk router-on-a-stick, tạo một Subinterface với VLAN ID
   phù hợp; nếu không, bỏ qua bước này.
6. Mở **View & Push**, đọc toàn bộ lệnh và đóng hộp thoại mà chưa Push.
7. Chỉ trong môi trường lab được phép thay đổi, mở lại preview và Push; sau đó
   lấy running-config mới để xác minh.

## Tóm tắt chương

Physical được lấy từ dữ liệu thiết bị và chỉ cho sửa; Loopback, Tunnel và
Subinterface được CAMS sinh tên và cho phép tạo/xóa. **Save/Update Interface**
chỉ lưu cấu hình mong muốn trong Workspace. **View & Push** là bước kiểm tra và
triển khai riêng, vì vậy luôn xem preview, xác nhận đúng host và sao lưu cấu
hình trước khi Push.
