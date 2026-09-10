# Cấu hình FHRP trên Router

FHRP (First Hop Redundancy Protocol) tạo một địa chỉ gateway ảo dùng chung cho
nhiều router. Khi router đang giữ vai trò chuyển tiếp gặp sự cố, router còn lại
có thể tiếp quản mà máy trạm không phải đổi default gateway. Tab **FHRP** của
CAMS hỗ trợ HSRP, VRRP và GLBP, đồng thời tạo cấu hình cho nhiều thiết bị trong
cùng một lần thao tác.

Trước khi bắt đầu, các router phải ở cùng miền Layer 2, interface hướng về LAN
phải có địa chỉ thuộc cùng subnet với địa chỉ gateway ảo và thiết bị phải ở trạng
thái Connected. Không dùng địa chỉ đang gán cho một host hoặc interface làm
Default Gateway IP.

## Các tham số dùng chung

Chọn **FHRP** trên Feature Bar, sau đó chọn tab **HSRP**, **VRRP** hoặc **GLBP**.
Mỗi nhóm dự phòng cần nhập các trường sau:

| Tham số | Cách nhập và ý nghĩa |
|---|---|
| **Group number / VRID** | Mã nhóm phải giống nhau trên các router. HSRPv1 dùng 0–255, HSRPv2 dùng 0–4095, VRRP dùng 1–255 và GLBP dùng 0–1023. |
| **Default Gateway IP** | IPv4 ảo mà máy trạm dùng làm gateway. Địa chỉ phải thuộc subnet của các interface tham gia và không trùng địa chỉ vật lý. |
| **Description** | Tên mô tả phục vụ vận hành, ví dụ khu vực hoặc VLAN được bảo vệ. Trường này không ảnh hưởng bầu chọn. |
| **Participating routers** | Chọn tối thiểu hai router Connected. Mỗi router phải có một interface phù hợp với subnet của gateway ảo. |
| **Authentication** | Chọn None nếu không xác thực; nếu dùng Plain, MD5 key hoặc MD5 key-chain thì mode và secret/key-chain phải giống trên mọi thành viên. |

Thực hiện theo thứ tự: nhập Group/VRID và gateway ảo, chọn router, chọn xác thực,
đặt timer chung, cấu hình priority/preempt/tracking cho từng router, sau đó **Save**.
Không chuyển sang View & Push khi một thành viên còn nhãn **NO MATCH**, vì CAMS
chưa tìm thấy interface cùng subnet với gateway ảo trên router đó.

## Cấu hình HSRP

HSRP bầu một router Active và một hoặc nhiều router Standby. Router có priority
cao hơn sẽ được ưu tiên; tùy chọn Preempt cho phép nó giành lại vai trò Active
sau khi phục hồi.

<figure>
<p><img src="../../figures/gui/chapter-09/09-hsrp-gateway-form-zoom.png"
style="width:90.0%" /></p>
<figcaption><p>Cận cảnh khối Gateway identity và danh sách router tham gia.</p></figcaption>
</figure>

Ở khối đầu tiên, nhập Group number `10`, Default Gateway IP `10.10.10.1` và mô
tả dễ nhận biết. Sau khi chọn R1 và R2, chỉ số **Gateway matches 2/2** xác nhận
cả hai router đều có interface thuộc mạng của gateway ảo.

<figure>
<p><img src="../../figures/gui/chapter-09/01-hsrp-gateway-members.png"
style="width:100.0%" /></p>
<figcaption><p>Màn hình tổng thể sau khi nhập gateway và chọn hai thành viên HSRP.</p></figcaption>
</figure>

Trong ví dụ, `10.10.10.1` là địa chỉ gateway ảo; R1 và R2 đều có interface trong
mạng `10.10.10.0/24`. Chọn đúng các router trước khi cấu hình chính sách riêng
cho từng thành viên.

<figure>
<p><img src="../../figures/gui/chapter-09/15-hsrp-auth-protocol-detail.png"
style="width:100.0%" /></p>
<figcaption><p>Cận cảnh xác thực, HSRP version và Hello/Hold timer.</p></figcaption>
</figure>

- **HSRP version**: chọn Version 1 hoặc 2 theo khả năng của thiết bị. Tất cả
  thành viên phải tương thích; Version 2 cho phép group number đến 4095.
- **Hello timer (ms)**: chu kỳ gửi bản tin Hello. Giá trị nhỏ giúp phát hiện nhanh
  hơn nhưng làm tăng lưu lượng điều khiển.
- **Hold timer (ms)**: thời gian chờ trước khi coi peer không còn hoạt động. Hold
  phải lớn hơn Hello và nên đồng nhất trên các router.
- **Authentication secret / Key-chain name**: giá trị dùng chung của nhóm. CAMS
  che nội dung nhạy cảm trong cửa sổ preview.

Trong cấu hình minh họa, HSRPv2 dùng Hello `1000 ms` và Hold `3000 ms`. Nếu đổi
timer, phải nhập cùng giá trị trên R1 và R2; chỉ một router khác timer có thể làm
nhóm hoạt động không ổn định.

<figure>
<p><img src="../../figures/gui/chapter-09/11-hsrp-primary-member-zoom.png"
style="width:90.0%" /></p>
<figcaption><p>R1 được đặt priority 120, bật Preempt và theo dõi object 1.</p></figcaption>
</figure>

R1 là router ưu tiên. Khi object 1 lỗi, priority giảm `30`, từ 120 còn 90; lúc
đó R2 với priority 100 có thể tiếp quản. Minimum delay `10 giây` tránh tranh vai
trò ngay khi đường vừa phục hồi; reload delay `30 giây` cho router ổn định sau
khi khởi động.

<figure>
<p><img src="../../figures/gui/chapter-09/12-hsrp-secondary-member-zoom.png"
style="width:90.0%" /></p>
<figcaption><p>R2 dùng cùng interface LAN nhưng có priority và delay riêng.</p></figcaption>
</figure>

R2 được đặt priority 100 để giữ vai trò Standby. Không nhập cùng priority cho
hai router nếu muốn vai trò Active được dự đoán rõ ràng. Mỗi router có thể dùng
delay và mức decrement khác nhau, nhưng phải cùng group, gateway, version,
authentication và timer.

<figure>
<p><img src="../../figures/gui/chapter-09/03-hsrp-member-policy.png"
style="width:100.0%" /></p>
<figcaption><p>Màn hình tổng thể chính sách của hai thành viên trước khi Save.</p></figcaption>
</figure>

Với từng router, chọn **Gateway-facing interface** là cổng nối vào LAN chứa
gateway ảo. Nhập **Priority** cao hơn cho router muốn làm Active. Bật **Preempt**
nếu router đó cần lấy lại vai trò sau khi phục hồi; **Preempt minimum delay** cho
mạng ổn định trước khi tranh vai trò, còn **Preempt reload delay** trì hoãn sau
khi thiết bị khởi động lại.

Trong **Tracking objects**, nhập interface hoặc object ID cần giám sát và
**Decrement** là lượng priority bị trừ khi đối tượng lỗi. Giá trị giảm phải đủ để
router còn khỏe trở thành Active, nếu không tracking sẽ không tạo ra failover
mong muốn.

## Cấu hình VRRP

VRRP dùng thuật ngữ Master/Backup và VRID thay cho group number. Quy trình Cisco
IOS trong CAMS dùng cú pháp VRRPv2.

<figure>
<p><img src="../../figures/gui/chapter-09/13-vrrp-options-member-zoom.png"
style="width:90.0%" /></p>
<figcaption><p>Cận cảnh VRRPv2, advertisement timer và chính sách Master/Backup.</p></figcaption>
</figure>

Nhập VRID và gateway ở phần trên tương tự HSRP. Ở phần cận cảnh, kiểm tra
Advertisement interval trước, sau đó chọn interface, priority, Preempt và
tracking cho từng router.

<figure>
<p><img src="../../figures/gui/chapter-09/04-vrrp-configuration.png"
style="width:100.0%" /></p>
<figcaption><p>Màn hình tổng thể nhóm VRRP 20 với hai router.</p></figcaption>
</figure>

- **VRID**: số từ 1 đến 255, giống nhau trên mọi router của nhóm.
- **Advertisement interval (ms)**: chu kỳ Master gửi thông báo. Các thành viên
  phải dùng giá trị tương thích; giảm timer cần được thử nghiệm trước khi triển khai.
- **Priority**: router có giá trị cao hơn được ưu tiên làm Master. CAMS không dùng
  priority 255 cho address owner trong quy trình này.
- **Preempt**: cho phép router ưu tiên cao hơn giành lại vai trò Master.
- **Authentication**: giao diện VRRP hỗ trợ None hoặc Plain; nếu bật, secret phải
  giống nhau trên toàn nhóm.

Gateway-facing interface và tracking được nhập theo nguyên tắc giống HSRP.

## Cấu hình GLBP

GLBP vừa dự phòng gateway vừa có thể phân phối máy trạm qua nhiều Active Virtual
Forwarder (AVF). Priority bầu Active Virtual Gateway (AVG), còn weighting ảnh
hưởng khả năng chuyển tiếp của từng AVF.

<figure>
<p><img src="../../figures/gui/chapter-09/14-glbp-weighting-zoom.png"
style="width:90.0%" /></p>
<figcaption><p>Cận cảnh weighting, threshold, forwarder preempt và tracking của GLBP.</p></figcaption>
</figure>

Tính trước giá trị sau khi tracking bị trừ. Ví dụ maximum weighting 120, lower
threshold 80 và decrement 50 sẽ còn 70 khi object lỗi; 70 thấp hơn lower
threshold nên thành viên ngừng vai trò AVF. Khi weighting phục hồi tới upper
threshold 100, thành viên mới đủ điều kiện tham gia chuyển tiếp trở lại.

<figure>
<p><img src="../../figures/gui/chapter-09/05-glbp-configuration.png"
style="width:100.0%" /></p>
<figcaption><p>Màn hình tổng thể GLBP group 30 sau khi nhập chính sách thành viên.</p></figcaption>
</figure>

- **Hello/Hold timer (ms)**: điều khiển phát hiện peer; Hold phải lớn hơn Hello.
- **Load balancing**: Round robin phân phối luân phiên; Weighted phân phối theo
  trọng số; Host dependent giữ một host gắn với cùng virtual forwarder.
- **Priority**: giá trị cao hơn được ưu tiên làm AVG.
- **Maximum weighting**: trọng số hoạt động tối đa của thành viên, từ 1 đến 254.
- **Lower threshold**: khi weighting giảm xuống dưới ngưỡng này, AVF mất quyền
  chuyển tiếp; `0` nghĩa là không đặt ngưỡng.
- **Upper threshold**: mức weighting phải phục hồi để AVF tham gia lại; `0` nghĩa
  là không đặt ngưỡng. Khi dùng cả hai, Upper nên lớn hơn Lower.
- **Forwarder preempt** và **delay**: cho phép AVF ưu tiên lấy lại vai trò sau
  thời gian chờ đã nhập.
- **Tracking object / Decrement**: sự cố của đường được theo dõi làm giảm
  weighting, nhờ đó thành viên không còn đường tốt sẽ ngừng chuyển tiếp.

## Save và View & Push FHRP

Sau khi hoàn tất, chọn **Save** để lưu desired state nhưng chưa cấu hình thiết bị.
Mở đúng tab giao thức rồi chọn **View & Push** để CAMS dựng lệnh cho tất cả thành
viên của nhóm. FHRP có cửa sổ push riêng, không trộn với Routing, DHCP, ACL hoặc
Syslog.

<figure>
<p><img src="../../figures/gui/chapter-09/06-hsrp-view-push.png"
style="width:75.0%" /></p>
<figcaption><p>View & Push FHRP của nhóm HSRP trên R1 và R2.</p></figcaption>
</figure>

<figure>
<p><img src="../../figures/gui/chapter-09/07-vrrp-view-push.png"
style="width:75.0%" /></p>
<figcaption><p>Preview riêng của VRRP trước khi đẩy cấu hình.</p></figcaption>
</figure>

<figure>
<p><img src="../../figures/gui/chapter-09/08-glbp-view-push.png"
style="width:75.0%" /></p>
<figcaption><p>Preview riêng của GLBP với lệnh cho từng thành viên.</p></figcaption>
</figure>

Trước khi nhấn **Push**, kiểm tra host, interface, địa chỉ ảo, group/VRID, version,
timer, authentication, priority, preempt và tracking. Secret được hiển thị dưới
dạng che để tránh lộ dữ liệu. Sau Push, kiểm tra vai trò Active/Standby,
Master/Backup hoặc AVG/AVF trên thiết bị và thử ngắt đường uplink đã theo dõi để
xác nhận failover thực sự hoạt động.
