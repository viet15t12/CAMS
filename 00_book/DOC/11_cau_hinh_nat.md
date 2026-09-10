# Cấu hình NAT trên Router

Tab **NAT** của CAMS hỗ trợ gán vai trò interface, tạo NAT ACL, Static NAT,
Dynamic NAT, PAT và Route Map. Chương này trình bày ảnh cận cảnh form nhập trước,
sau đó mới đưa ảnh tổng thể để dễ đối chiếu danh sách cấu hình đã lưu.

Một cấu hình NAT thông thường đi theo thứ tự: **Interfaces → ACL → Static,
Dynamic hoặc PAT → Route Map nếu cần → Save → View & Push NAT**. Tab Info hiện
chưa có quy trình cấu hình nên không sử dụng trong chương này.

## Quick PAT Setup

Nếu mục tiêu là cho nhiều máy trong LAN dùng chung địa chỉ của interface Internet,
chọn **Quick setup**. CAMS sẽ tạo đồng thời vai trò Inside/Outside, NAT ACL và
PAT overload.

<figure>
<p><img src="../../figures/gui/chapter-11/01-quick-pat-setup.png"
style="width:78.0%" /></p>
<figcaption><p>Quick PAT Setup với hai interface và mạng LAN cần dịch địa chỉ.</p></figcaption>
</figure>

| Trường | Giá trị cần nhập |
|---|---|
| **Inside interface** | Cổng nối về mạng nội bộ, ví dụ `GigabitEthernet0/0`. |
| **Outside interface** | Cổng đi Internet hoặc mạng upstream, ví dụ `GigabitEthernet0/1`. Không chọn trùng cổng Inside. |
| **LAN network** | Địa chỉ mạng nội bộ, ví dụ `192.168.10.0`. |
| **Wildcard** | Wildcard của LAN, ví dụ mạng `/24` dùng `0.0.0.255`. |
| **ACL name** | Tên không có khoảng trắng, dễ nhận biết như `NAT_INSIDE`. |

Chọn **Create PAT policy** khi đã kiểm tra đúng hai interface. Quick setup phù
hợp cấu hình Internet sharing cơ bản; khi cần pool hoặc policy phức tạp, cấu hình
từng tab bên dưới.

## Bước 1 — Gán NAT Interfaces

Mỗi đường dịch NAT cần ít nhất một interface **Inside** và một interface
**Outside**.

<figure>
<p><img src="../../figures/gui/chapter-11/02-interfaces-form-zoom.png"
style="width:62.0%" /></p>
<figcaption><p>Form gán interface LAN vào vai trò Inside.</p></figcaption>
</figure>

- **Interface Name**: chọn interface routed đã có trên router.
- **NAT Role**: Inside cho phía địa chỉ riêng; Outside cho phía public/upstream.

Chọn **Add Locally** cho từng interface, sau đó kiểm tra danh sách tổng thể.

<figure>
<p><img src="../../figures/gui/chapter-11/03-interfaces-overview.png"
style="width:100.0%" /></p>
<figcaption><p>Tổng thể hai interface NAT: G0/0 Inside và G0/1 Outside.</p></figcaption>
</figure>

## Bước 2 — Tạo NAT ACL

NAT ACL xác định địa chỉ nguồn nào được phép đi vào quy trình dịch địa chỉ.

<figure>
<p><img src="../../figures/gui/chapter-11/04-acl-form-zoom.png"
style="width:62.0%" /></p>
<figcaption><p>Form NAT ACL cho mạng 192.168.10.0/24.</p></figcaption>
</figure>

| Trường | Ý nghĩa cơ bản |
|---|---|
| **NAT ACL Name** | Chọn ACL có sẵn hoặc Create new NAT ACL. |
| **New NAT ACL Name** | Tên ACL mới, ví dụ `NAT_INSIDE`. |
| **Action** | Permit đưa nguồn khớp vào NAT; Deny loại nguồn khớp khỏi rule NAT này. |
| **Source Type** | Network cho một mạng, Host cho một máy, Any cho mọi nguồn. |
| **Source Network/Host** | Địa chỉ nguồn cần khớp. |
| **Wildcard Mask** | Wildcard khi Source Type là Network; `/24` tương ứng `0.0.0.255`. |

Rule ACL được xét theo thứ tự. Nên tạo rule cụ thể trước rule rộng và kiểm tra kỹ
Permit/Deny trước khi Save.

<figure>
<p><img src="../../figures/gui/chapter-11/05-acl-overview.png"
style="width:100.0%" /></p>
<figcaption><p>Tổng thể form và NAT ACL Entry đã thêm cục bộ.</p></figcaption>
</figure>

## Static NAT

Static NAT ánh xạ cố định một địa chỉ Inside Local sang một địa chỉ Inside
Global. Có thể chọn TCP/UDP để chỉ ánh xạ một port.

<figure>
<p><img src="../../figures/gui/chapter-11/06-static-form-zoom.png"
style="width:62.0%" /></p>
<figcaption><p>Form Static NAT ánh xạ TCP/443 nội bộ sang TCP/8443 bên ngoài.</p></figcaption>
</figure>

- **Inside Local IP**: địa chỉ riêng của server trong LAN.
- **Inside Global IP**: địa chỉ public đại diện cho server.
- **Protocol**: Any để dịch toàn bộ IP; TCP hoặc UDP để dịch theo port.
- **Inside Local Port / Global Port**: port thật trên server và port được công bố
  ra ngoài. Hai trường chỉ xuất hiện khi chọn TCP hoặc UDP.

<figure>
<p><img src="../../figures/gui/chapter-11/07-static-overview.png"
style="width:100.0%" /></p>
<figcaption><p>Tổng thể Static NAT Entry đang chờ Save và Push.</p></figcaption>
</figure>

## Dynamic NAT

Dynamic NAT lấy một địa chỉ từ public pool cho mỗi translation đang hoạt động.
Số địa chỉ trong pool phải đáp ứng số phiên cần dùng đồng thời.

<figure>
<p><img src="../../figures/gui/chapter-11/08-dynamic-form-zoom.png"
style="width:62.0%" /></p>
<figcaption><p>Form Dynamic NAT Pool và ACL được liên kết.</p></figcaption>
</figure>

- **Pool Name**: tên duy nhất, ví dụ `PUBLIC_POOL`.
- **Start IP / End IP**: địa chỉ public đầu và cuối của pool, tính cả hai đầu.
- **Netmask**: netmask hoặc prefix của mạng public; pool phải thuộc subnet hợp lệ.
- **NAT ACL Name**: ACL xác định các inside host được sử dụng pool.

<figure>
<p><img src="../../figures/gui/chapter-11/09-dynamic-overview.png"
style="width:100.0%" /></p>
<figcaption><p>Tổng thể Dynamic NAT Pool từ 203.0.113.8 đến 203.0.113.12.</p></figcaption>
</figure>

## PAT (Overload)

PAT cho nhiều inside host dùng chung một địa chỉ public bằng cách phân biệt port.
Đây là kiểu thường dùng cho truy cập Internet từ LAN.

<figure>
<p><img src="../../figures/gui/chapter-11/10-pat-form-zoom.png"
style="width:62.0%" /></p>
<figcaption><p>Form PAT dùng địa chỉ của Outside Interface.</p></figcaption>
</figure>

- **NAT ACL Name**: chọn ACL của mạng bên trong.
- **Source Type**: chọn Outside Interface để dùng IP của cổng WAN, hoặc Pool để
  overload trên public pool đã tạo ở tab Dynamic.
- **Outside Interface / Pool Name**: chọn đúng nguồn public tương ứng với Source
  Type. Form chỉ liệt kê interface Outside hoặc pool đã Save.

<figure>
<p><img src="../../figures/gui/chapter-11/11-pat-overview.png"
style="width:100.0%" /></p>
<figcaption><p>Tổng thể PAT rule dùng NAT_INSIDE và GigabitEthernet0/1.</p></figcaption>
</figure>

## Route Map cho NAT

Route Map là phần tùy chọn, dùng khi cần policy NAT có nhiều sequence hoặc cần
liên kết điều kiện ACL rõ ràng hơn.

<figure>
<p><img src="../../figures/gui/chapter-11/12-route-map-form-zoom.png"
style="width:62.0%" /></p>
<figcaption><p>Form Route Map Entry với sequence 10 và NAT ACL.</p></figcaption>
</figure>

| Trường | Ý nghĩa cơ bản |
|---|---|
| **Route Map Name** | Chọn route map có sẵn hoặc tạo tên mới như `NAT_POLICY`. |
| **Description** | Ghi ngắn mục đích của sequence. |
| **Sequence** | Thứ tự xét từ 1–65535; số nhỏ chạy trước. Nên dùng 10, 20, 30 để dễ chèn thêm rule. |
| **Action** | Permit chấp nhận khi điều kiện khớp; Deny loại trường hợp khớp. |
| **NAT ACL Name** | ACL làm điều kiện match; chọn No ACL nếu sequence không cần ACL. |

<figure>
<p><img src="../../figures/gui/chapter-11/13-route-map-overview.png"
style="width:100.0%" /></p>
<figcaption><p>Tổng thể Route Map NAT_POLICY sau khi thêm entry.</p></figcaption>
</figure>

## Add Locally, Save và View & Push NAT

**Add Locally** hoặc **Apply Edit** chỉ đưa thay đổi vào danh sách tạm trên tab.
Chọn **Save** ở cuối màn hình để lưu desired state. Sau đó mở **View & Push**;
NAT có cửa sổ push riêng, không trộn với ACL, DHCP, FHRP hay Syslog.

<figure>
<p><img src="../../figures/gui/chapter-11/14-nat-view-push.png"
style="width:78.0%" /></p>
<figcaption><p>View & Push NAT tổng hợp interface role, ACL, Static, Dynamic, PAT và Route Map.</p></figcaption>
</figure>

Trước khi Push, kiểm tra đúng host và đọc lệnh theo thứ tự: `ip nat inside/outside`,
ACL, public pool, Static NAT, PAT overload và route-map. Đặc biệt kiểm tra địa chỉ
public không trùng interface hoặc thiết bị khác, ACL không chọn nhầm mạng và
Inside/Outside không bị đảo. Sau Push, kiểm tra bảng translation và thử kết nối
từ cả phía trong lẫn phía ngoài theo đúng mục tiêu cấu hình.
