#import "../config/commands.typ": report-note
// Nguồn nội dung: DOC/16_bao_mat_switch_l2.md
#import "../config/images.typ": insert-image
#import "../config/tables.typ": report-table

= Cấu hình bảo mật trên Switch Layer 2 <ch16>

Nhóm *Security* của SW2 gồm *L2 Security* và *Port Security*. L2 Security bảo vệ DHCP/ARP theo VLAN, xác định uplink tin cậy và tạo Static MAC; Port Security giới hạn địa chỉ MAC được học trên từng access port.

Thứ tự khuyến nghị: hoàn thành VLAN và Interface → xác định uplink thật sự tin cậy → bật DHCP Snooping → bật DAI → thêm Static MAC nếu cần → cấu hình Port Security trên access port → kiểm tra hai cửa sổ View & Push riêng.

== VLAN Protection

Mở *Security → L2 Security → VLAN Protection*, chọn VLAN cần bảo vệ.

#insert-image("figures/gui/chapter-16/01-vlan-protection.png",
  caption: [DHCP Snooping và Dynamic ARP Inspection theo từng VLAN.], width: 100.0%) <fig:ch16-01-vlan-protection>

- *Enable DHCP Snooping* kiểm tra bản tin DHCP trên VLAN và tạo cơ sở dữ liệu binding IP–MAC–port. Xác định trusted uplink trước khi triển khai để không chặn phản hồi từ DHCP server hợp lệ.
- *Enable DAI* kiểm tra ARP dựa trên DHCP Snooping binding hoặc Static MAC. CAMS tự bật DHCP Snooping khi bật DAI trong workflow này, vì DAI cần nguồn binding cho client học động.
- *Save Policy* lưu hai trạng thái cho VLAN đang chọn. Có thể bật Snooping mà chưa bật DAI để triển khai theo từng giai đoạn.

Không bật đồng loạt trên VLAN production khi chưa xác định đường DHCP server, relay và client dùng IP tĩnh. Với host IP tĩnh không có DHCP binding, chuẩn bị binding phù hợp trước khi DAI có hiệu lực.

== Trusted Uplinks

Chuyển sang *Trusted Uplinks*.

#insert-image("figures/gui/chapter-16/02-trusted-uplinks.png",
  caption: [Danh sách uplink tin cậy và form chọn Layer 2 interface.], width: 100.0%) <fig:ch16-02-trusted-uplinks>

#report-table(
  columns: (1.15fr, 2.85fr),
  header: ([Thành phần], [Cách dùng]),
  rows: (
    ([*Trusted Interface*], [Port hướng tới DHCP server hợp lệ hoặc upstream switch đáng tin cậy.]),
    ([*Applied Controls*], [CAMS áp dụng DHCP trust và ARP trust cho port.]),
    ([*Layer 2 interface*], [Chọn port access/trunk đã có trong Interfaces; ưu tiên uplink theo sơ đồ mạng.]),
    ([*Add Trust Port*], [Lưu port vào desired state. Xóa biểu tượng thùng rác nếu đã chọn nhầm.]),
  ),
  caption: [Trusted Uplinks],
  figure-label: <tab:ch16-table-1>,
)

#report-note[Trust cho phép lưu lượng vượt qua kiểm tra Snooping/DAI, vì vậy *không trust port nối người dùng*. Kiểm tra description, dây nối và neighbor trước khi Save.]

== Static MAC Binding

Chuyển sang *Static MAC*, chọn *Add* hoặc Edit binding hiện có.

#insert-image("figures/gui/chapter-16/03-static-mac-form.png",
  caption: [Binding cố định MAC–VLAN–Interface cho một thiết bị.], width: 52.0%) <fig:ch16-03-static-mac-form>

#report-table(
  columns: (1.15fr, 2.85fr),
  header: ([Trường], [Cách nhập]),
  rows: (
    ([*MAC address*], [Địa chỉ client. CAMS chuẩn hóa về dạng Cisco #raw("xxxx.xxxx.xxxx"); ví dụ #raw("0011.2233.4455").]),
    ([*VLAN*], [VLAN mà địa chỉ này hợp lệ; phải tồn tại trong VLAN Database.]),
    ([*Layer 2 interface*], [Port cố định nơi thiết bị được phép xuất hiện.]),
  ),
  caption: [Static MAC Binding],
  figure-label: <tab:ch16-table-2>,
)

Static MAC phù hợp máy in, camera, server hoặc host IP tĩnh cần binding xác định. Không tạo binding cho thiết bị thường xuyên di chuyển giữa các port.

== View & Push L2 Security

VLAN Protection, Trusted Uplinks và Static MAC dùng chung một preview *L2\_SECURITY*.

#insert-image("figures/gui/chapter-16/04-l2-security-view-push.png",
  caption: [Preview Snooping, DAI, trust port và Static MAC.], width: 76.0%) <fig:ch16-04-l2-security-view-push>

Kiểm tra theo thứ tự:

+ VLAN nào bật #raw("ip dhcp snooping") và #raw("ip arp inspection").
+ Interface nào nhận #raw("ip dhcp snooping trust") và #raw("ip arp inspection trust").
+ Static MAC có đúng địa chỉ, VLAN và interface hay không.
+ Các lệnh #raw("no") có đúng policy/binding đang xóa hay không.

Sau Push, thử DHCP trên một client hợp lệ, kiểm tra Snooping binding, DAI statistics và xác nhận client IP tĩnh vẫn hoạt động theo thiết kế.

== Port Security

Mở *Security → Port Security*, chọn access port rồi nhấn *Edit*. CAMS không cho áp dụng profile này lên routed/trunk port trong workflow SW2.

#insert-image("figures/gui/chapter-16/05-port-security-form.png",
  caption: [Port Security cho GigabitEthernet0/1.], width: 55.0%) <fig:ch16-05-port-security-form>

#report-table(
  columns: (1.15fr, 2.85fr),
  header: ([Trường], [Ý nghĩa]),
  rows: (
    ([*Enable Port Security*], [Bật chính sách giới hạn MAC trên access port.]),
    ([*Maximum MAC*], [Số địa chỉ nguồn tối đa được phép học, ví dụ #raw("2") cho PC và IP phone.]),
    ([*Violation action*], [Hành động khi vượt giới hạn hoặc gặp MAC không hợp lệ.]),
    ([*Sticky MAC learning*], [Chuyển MAC học động thành secure sticky để giữ trong cấu hình.]),
    ([*Aging type*], [#raw("absolute") tính từ lúc học; #raw("inactivity") chỉ xóa khi MAC không hoạt động đủ lâu.]),
    ([*Aging time*], [Thời gian aging theo đơn vị nền tảng IOS sử dụng; #raw("0") thường là không aging. Kiểm tra yêu cầu thiết bị trước khi đặt.]),
  ),
  caption: [Port Security],
  figure-label: <tab:ch16-table-3>,
)

Ba violation action cần phân biệt:

- *protect* bỏ frame vi phạm nhưng không tạo cảnh báo đầy đủ.
- *restrict* bỏ frame, tăng bộ đếm và thường tạo thông báo; phù hợp khi cần quan sát vi phạm mà không đóng port.
- *shutdown* đưa port vào err-disabled; bảo vệ mạnh nhất nhưng có thể gây gián đoạn và cần quy trình khôi phục.

Với port có IP phone và PC phía sau, Maximum MAC phải đủ cho số địa chỉ hợp lệ. Không bật Sticky trên port dùng chung hoặc thường xuyên đổi người dùng nếu chưa có quy trình xóa secure MAC cũ.

== View & Push Port Security

Port Security có cửa sổ push riêng, không gộp vào L2 Security hoặc Interfaces.

#insert-image("figures/gui/chapter-16/07-port-security-view-push.png",
  caption: [Preview PORT\_SECURITY cho một access port.], width: 76.0%) <fig:ch16-07-port-security-view-push>

Xác nhận đúng interface, mode access, maximum, violation, sticky và aging. Sau Push, kiểm tra secure MAC table, violation counter và trạng thái err-disabled. Chỉ thử MAC vi phạm trong môi trường lab hoặc thời gian bảo trì đã được phép.
