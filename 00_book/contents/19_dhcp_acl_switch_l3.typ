#import "../config/commands.typ": report-note
// Nguồn nội dung: DOC/19_dhcp_acl_switch_l3.md
#import "../config/images.typ": insert-image
#import "../config/tables.typ": report-table

= DHCP và ACL trên Switch Layer 3 <ch19>

Role *SW3* có nhóm *Services* gồm *DHCP Server* và *DHCP Relay*, đồng thời bổ sung *ACL* trong nhóm Security. Quy trình chung là chọn đúng SW3 → nhập dữ liệu → *Add Locally/Save* → mở *View & Push* của đúng controller → đọc lệnh → Push → đồng bộ và kiểm tra lại.

#report-note[DHCP Server và DHCP Relay cùng thuộc controller DHCP nhưng được trình bày thành hai quy trình riêng. ACL có View & Push độc lập; không Push ACL qua cửa sổ DHCP.]

== DHCP Server trên SW3

Mở *Services → DHCP Server → Pool*. Mỗi pool phục vụ một subnet; Default Router thường là địa chỉ SVI của chính VLAN đó.

#insert-image("figures/gui/chapter-19/01-dhcp-pool-form.png",
  caption: [Các tham số DHCP Pool cho VLAN 10.], width: 58.0%) <fig:ch19-01-dhcp-pool-form>

#report-table(
  columns: (1.15fr, 2.85fr),
  header: ([Trường], [Cách nhập và tác dụng]),
  rows: (
    ([*Pool Name*], [Tên định danh trên IOS, ví dụ #raw("POOL_VLAN10"); nên viết liền, dễ nhận biết và không trùng pool khác.]),
    ([*Network*], [Địa chỉ mạng được cấp phát, ví dụ #raw("10.10.10.0"), không nhập địa chỉ host.]),
    ([*Subnet Mask*], [Dùng mask đầy đủ hoặc prefix hợp lệ, ví dụ #raw("255.255.255.0") hoặc #raw("/24").]),
    ([*Default Router*], [Gateway gửi cho client; thường là IP của SVI cùng VLAN, ví dụ #raw("10.10.10.1").]),
    ([*DNS Server*], [Một hoặc nhiều địa chỉ DNS, phân tách bằng khoảng trắng, ví dụ #raw("1.1.1.1 8.8.8.8").]),
    ([*Lease*], [Thời gian thuê theo cú pháp IOS: #raw("1") là một ngày; #raw("0 12 0") là 0 ngày 12 giờ 0 phút.]),
  ),
  caption: [DHCP Server trên SW3],
  figure-label: <tab:ch19-table-1>,
)

Chọn *Add Locally* để đưa pool vào danh sách tạm, sau đó *Save* để ghi desired state. Có thể dùng *Edit* để nạp pool vào form và *Delete* để đánh dấu loại bỏ. Network, mask, Default Router và SVI phải cùng thiết kế subnet.

=== Excluded Address

Trong *DHCP Server*, mở tab *Excluded* để loại gateway, server, access point hoặc vùng địa chỉ tĩnh khỏi pool. *Start IP* là địa chỉ đầu; *End IP* là địa chỉ cuối. Nếu chỉ loại một địa chỉ, để trống End IP. Khoảng loại trừ phải nằm trong subnet đang cấp phát và End IP không được nhỏ hơn Start IP.

=== View & Push DHCP Server

Sau khi Save Pool và Excluded Address, mở *View & Push* từ DHCP Server.

#insert-image("figures/gui/chapter-19/03-dhcp-server-view-push.png",
  caption: [Preview chỉ gồm Excluded Address và hai DHCP Pool của SW3.], width: 76.0%) <fig:ch19-03-dhcp-server-view-push>

Kiểm tra #raw("ip dhcp excluded-address"), tên từng #raw("ip dhcp pool"), network/mask, #raw("default-router"), #raw("dns-server") và #raw("lease"). Sau Push, thử client trong từng VLAN, kiểm tra địa chỉ nhận được, gateway, DNS và DHCP binding trên switch.

== DHCP Relay trên SW3

Dùng Relay khi DHCP server nằm ở mạng khác. Mở *Services → DHCP Relay*; CAMS đưa thẳng tới tab Helper. Broadcast DHCP nhận trên interface được chuyển thành unicast tới Helper IP.

#insert-image("figures/gui/chapter-19/04-dhcp-relay-form.png",
  caption: [Helper Address trên SVI Vlan99 trỏ tới DHCP server 192.0.2.50.], width: 55.0%) <fig:ch19-04-dhcp-relay-form>

#report-table(
  columns: (1.15fr, 2.85fr),
  header: ([Trường], [Cách nhập và tác dụng]),
  rows: (
    ([*Interface*], [Chọn interface Layer 3 nhận broadcast từ client, thường là SVI của VLAN client. Interface phải có IP và đang hoạt động.]),
    ([*Helper IP*], [Địa chỉ unicast của DHCP server từ xa. SW3 phải có route tới địa chỉ này và ACL không được chặn luồng DHCP.]),
  ),
  caption: [DHCP Relay trên SW3],
  figure-label: <tab:ch19-table-2>,
)

Chọn *Add Locally*, sau đó *Save*. Có thể thêm nhiều Helper IP trên cùng interface để dự phòng, mỗi server là một bản ghi riêng. Không đặt helper trên interface hướng về DHCP server nếu broadcast của client đi vào SVI khác.

=== View & Push DHCP Relay

#insert-image("figures/gui/chapter-19/05-dhcp-relay-view-push.png",
  caption: [Preview riêng của DHCP Relay với #raw("ip helper-address") dưới Vlan99.], width: 76.0%) <fig:ch19-05-dhcp-relay-view-push>

Kiểm tra #raw("interface Vlan99") và #raw("ip helper-address 192.0.2.50") nằm cùng một khối. Sau Push, kiểm tra route hai chiều giữa SW3 và server, DHCP scope cho subnet của client, gateway trong offer và ACL trên đường đi.

== ACL trên SW3

Mở *Security → ACL*. Các tab Standard, Extended, Dynamic, Reflexive và MAC dùng chung cách tạo rule đã trình bày ở @ch08. Trên SW3, điểm cần chú ý nhất là gắn IP ACL vào đúng SVI hoặc interface Layer 3 để kiểm soát lưu lượng giữa các VLAN.

#insert-image("figures/gui/chapter-19/06-acl-extended-form.png",
  caption: [Form Extended ACL USERS\_TO\_SERVERS và Rule Builder.], width: 58.0%) <fig:ch19-06-acl-extended-form>

Các trường cơ bản của Extended ACL:

#report-table(
  columns: (1.15fr, 2.85fr),
  header: ([Trường], [Cách nhập và tác dụng]),
  rows: (
    ([*ACL Name*], [Tên duy nhất, ví dụ #raw("USERS_TO_SERVERS"); nên thể hiện nguồn, đích hoặc mục đích policy.]),
    ([*Description*], [Mô tả ngắn lưu lượng được phép/chặn để người vận hành đọc lại không phải suy đoán.]),
    ([*Sequence*], [Thứ tự xử lý rule; dùng bước 10 như #raw("10"), #raw("20"), #raw("30") để còn chỗ chèn rule.]),
    ([*Action*], [#raw("Permit") cho phép hoặc #raw("Deny") chặn khi rule khớp.]),
    ([*Protocol*], [Chọn #raw("ip"), #raw("tcp"), #raw("udp"), #raw("icmp")… phù hợp lưu lượng.]),
    ([*Source / Destination*], [Nhập #raw("any"), một host hoặc địa chỉ mạng theo cú pháp form. Với mạng, nhập wildcard tương ứng.]),
    ([*Source/Destination Port*], [Dùng khi protocol là TCP/UDP, ví dụ destination port #raw("443") cho HTTPS.]),
  ),
  caption: [ACL trên SW3],
  figure-label: <tab:ch19-table-3>,
)

Thêm rule Permit cần thiết trước rule Deny rộng. ACL luôn có implicit deny ở cuối; một ACL chỉ có rule Permit chưa chắc cho phép các luồng quản trị khác.

== Gắn ACL vào SVI

Mở tab *Bindings*, chọn ACL, interface và direction rồi chọn *Add* và *Save*.

#insert-image("figures/gui/chapter-19/07-acl-bindings.png",
  caption: [ACL USERS\_TO\_SERVERS được gắn chiều IN trên Vlan10.], width: 100.0%) <fig:ch19-07-acl-bindings>

- *IN* lọc gói ngay khi đi vào SVI. Với #raw("Vlan10 IN"), policy kiểm soát lưu lượng do client VLAN 10 gửi vào quá trình định tuyến;
- *OUT* lọc gói trước khi rời interface. Chỉ chọn khi policy được thiết kế theo hướng đích;
- một binding sai direction có thể không chặn được luồng mong muốn hoặc chặn nhầm lưu lượng quản trị.

== View & Push ACL

ACL dùng nút *View & Push* riêng trong trang Access Control Lists.

#insert-image("figures/gui/chapter-19/08-acl-view-push.png",
  caption: [Preview ACL gồm rule và lệnh #raw("ip access-group") trên Vlan10.], width: 76.0%) <fig:ch19-08-acl-view-push>

Đọc theo thứ tự sequence và kiểm tra action, protocol, source, wildcard, destination, port, interface cùng direction của #raw("ip access-group"). Trước khi Push qua SSH, bảo đảm địa chỉ quản trị vẫn được Permit hoặc có console/đường dự phòng.

Sau Push, kiểm tra ACL hit counter và thử cả hai nhóm lưu lượng: luồng phải được Permit và luồng phải bị Deny. Nếu inter-VLAN routing không hoạt động, kiểm tra theo thứ tự IP Routing → trạng thái SVI → route connected → ACL binding → route upstream.
