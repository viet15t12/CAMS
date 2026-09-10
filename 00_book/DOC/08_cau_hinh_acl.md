# Cấu hình ACL trên Router

Chương này trình bày các loại Access Control List trong tab **ACL** của CAMS:
Standard, Extended, Dynamic, Reflexive, MAC và Bindings. ACL có cửa sổ **View &
Push ACL** riêng, độc lập với DHCP và Routing.

ACL được xử lý từ sequence nhỏ đến lớn, dừng tại rule khớp đầu tiên và có
implicit deny ở cuối. Một rule sai có thể làm mất kết nối quản trị; luôn xem
preview và bảo đảm có đường khôi phục trước khi Push.

## Mở tab ACL

Chọn router rồi chọn **ACL** trên Feature Bar. Chọn loại ACL trên thanh tab con.
Khung bên trái hiển thị thông tin ACL và Rule Builder; khung bên phải hiển thị
ACL đã lưu cùng danh sách rule. **View** mở nội dung ở chế độ chỉ đọc, **Edit**
cho phép thay đổi và **Delete** chỉ đánh dấu xóa cho đến khi Save.

## Standard ACL

Standard ACL lọc chủ yếu theo địa chỉ nguồn. Dùng wildcard để khớp một mạng hoặc
dùng `any` khi rule áp dụng cho mọi nguồn.

<figure>
<p><img src="../../figures/gui/chapter-08/01-acl-standard.png"
style="width:100.0%" /></p>
<figcaption><p>Standard ACL cho phép mạng tin cậy rồi từ chối các nguồn còn lại.</p></figcaption>
</figure>

Nên đặt Standard ACL gần đích để tránh chặn cùng một nguồn trên quá nhiều luồng
không liên quan. Kiểm tra thứ tự Permit/Deny và implicit deny trước khi áp dụng.

## Extended ACL

Extended ACL có thể lọc theo protocol, địa chỉ nguồn, địa chỉ đích, wildcard và
port. Nó phù hợp với chính sách chi tiết như chỉ cho phép HTTPS tới một server.

<figure>
<p><img src="../../figures/gui/chapter-08/02-acl-extended.png"
style="width:100.0%" /></p>
<figcaption><p>Extended ACL cho phép TCP/443 tới application server.</p></figcaption>
</figure>

Với TCP/UDP, port được chuẩn hóa sang cú pháp Cisco như `eq 443`. Với ICMP, dùng
tên hoặc số ICMP type phù hợp. Extended ACL thường được đặt gần nguồn để loại bỏ
lưu lượng không mong muốn sớm hơn.

## Dynamic ACL

Dynamic ACL tạo quyền truy cập tạm thời sau quá trình xác thực. Ngoài các trường
của Extended ACL, rule có **Dynamic Name** và timeout tính theo phút.

<figure>
<p><img src="../../figures/gui/chapter-08/03-acl-dynamic.png"
style="width:100.0%" /></p>
<figcaption><p>Dynamic ACL cấp quyền SSH tạm thời cho người dùng từ xa.</p></figcaption>
</figure>

Tên dynamic phải rõ ràng và timeout đủ ngắn để giảm thời gian phơi bày nhưng vẫn
phù hợp phiên làm việc. Chức năng này cần được kiểm chứng với phiên bản IOS và
cơ chế xác thực thực tế.

## Reflexive ACL

Reflexive ACL theo dõi session khởi tạo từ phía được tin cậy và tạo entry tạm
cho lưu lượng phản hồi. Rule có **Reflect Name** và timeout tính theo giây.

<figure>
<p><img src="../../figures/gui/chapter-08/04-acl-reflexive.png"
style="width:100.0%" /></p>
<figcaption><p>Reflexive ACL theo dõi các session TCP đi ra từ mạng LAN.</p></figcaption>
</figure>

Reflect Name phải khớp với thiết kế ACL đánh giá lưu lượng quay về. Đây không
phải stateful firewall đầy đủ; cần kiểm tra giới hạn của platform trước khi dùng.

## MAC ACL

MAC ACL lọc ở Layer 2 theo MAC nguồn, MAC đích, mask và EtherType. Địa chỉ MAC
dùng định dạng Cisco `xxxx.xxxx.xxxx`.

<figure>
<p><img src="../../figures/gui/chapter-08/05-acl-mac.png"
style="width:100.0%" /></p>
<figcaption><p>MAC ACL cho phép một dải địa chỉ MAC tin cậy.</p></figcaption>
</figure>

MAC ACL chỉ phù hợp trên interface và platform hỗ trợ. Không xem MAC filtering
là cơ chế xác thực mạnh vì địa chỉ MAC có thể bị giả mạo.

## Interface Bindings

ACL chưa ảnh hưởng lưu lượng cho tới khi được gắn vào interface và direction
phù hợp. Tab **Bindings** cho phép một ACL có nhiều binding IN/OUT.

<figure>
<p><img src="../../figures/gui/chapter-08/06-acl-bindings.png"
style="width:100.0%" /></p>
<figcaption><p>Standard ACL được gắn chiều IN trên GigabitEthernet0/0.</p></figcaption>
</figure>

**In** lọc gói ngay khi đi vào interface; **Out** lọc trước khi gói rời interface.
Không gắn cùng một policy ở cả hai chiều nếu đó không phải chủ đích. Với ACL bảo
vệ truy cập quản trị, phải bảo đảm địa chỉ của phiên quản trị hiện tại được Permit.

## Save và View & Push ACL

Trong Rule Builder, nhập ACL Name, Description và từng rule rồi chọn **+ Add
Rule**. Sau khi kiểm tra thứ tự, chọn **Create ACL** hoặc **Change ACL** để lưu.
Binding được lưu riêng trong tab Bindings nhưng cùng thuộc desired state ACL.

<figure>
<p><img src="../../figures/gui/chapter-08/07-acl-view-push.png"
style="width:75.0%" /></p>
<figcaption><p>View & Push ACL tổng hợp năm ACL và interface binding đang chờ.</p></figcaption>
</figure>

Cửa sổ này chỉ xử lý controller ACL. Kiểm tra từng khối ACL, sequence, Permit/
Deny, protocol, source, destination, port và lệnh `ip access-group`. Đặc biệt rà
soát các lệnh `no` khi sửa hoặc xóa rule. Chỉ nhấn **Push** khi tiêu đề là **View
& Push ACL** và host đúng với router cần cấu hình.

Sau Push, kiểm tra running-config, ACL hit counter và thử cả lưu lượng được phép
lẫn lưu lượng phải bị chặn. Nếu thay đổi ACL qua phiên SSH, nên có console hoặc
đường quản trị dự phòng.

## Tóm tắt chương

ACL trong CAMS hỗ trợ năm kiểu rule và một tab Bindings. Mỗi ACL được xây dựng,
lưu vào database, gắn với interface rồi kiểm tra trong View & Push ACL riêng.
Thứ tự rule, implicit deny và direction của binding là ba điểm phải kiểm tra trước
khi triển khai.
