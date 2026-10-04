# VTP Group và đồng bộ VLAN

## Luồng áp dụng

Save group chỉ ghi cấu hình chờ áp dụng. View & Push cấu hình domain, version
và mode trên từng switch; CAMS đọc `show vtp status` để xác minh trước khi
đánh dấu synchronized. Pruning chỉ sinh lệnh trên server. Khi Push `all`,
task VTP chạy trước task VLAN để switch đã ở đúng mode khi nhận lệnh VLAN.

Sau Push VLAN hoặc VTP trên server, CAMS cập nhật snapshot server, rồi đọc
`show vtp status` và `show vlan brief` trên các client synchronized cùng domain.
CAMS thử lại tối đa 6 lần, cách nhau 1 giây, để chờ VLAN ID/name/state khớp
server; đồng thời kiểm tra domain, mode client và version. Client nhận VLAN
qua VTP trên trunk thực tế, không qua lệnh tạo VLAN cục bộ trên client.

Chỉ snapshot client đã kiểm chứng mới được ghi vào DB và phát tín hiệu cho
UI tải lại. Trang VLAN tự cập nhật; nếu đang sửa dữ liệu, bản nháp được giữ
và snapshot mới được hiển thị khi thoát editor. Trang VTP cập nhật danh sách
group mà không thay bản nháp chưa lưu. Cấu hình VLAN đã lưu nhưng chưa Push
trên client không bị tự động ghi đè.

Nếu client chưa nhận đúng VLAN hoặc không truy cập được, kết quả báo warning
với host/lý do cụ thể. Lệnh đã áp dụng trên server không bị rollback. Kiểm tra
trunk, domain/version, authentication và revision bằng các lệnh show trên
server/client trước khi thử lại. Bộ kiểm thử dùng connector giả và QML thật;
không thay thế kiểm thử trên thiết bị lab.

## Detach và xóa group

Detach/xóa group stage member thành `pending_delete`. Push gửi
`vtp mode transparent`, xác minh switch đã ở mode transparent, rồi mới xóa
membership; domain DB chỉ được dọn khi không còn member. Nếu CLI báo lỗi hoặc
mode không đổi, member vẫn chờ xóa để thử lại.

Switch transparent có thể vẫn giữ tên domain. Bước đọc lại không tự tạo
membership cho switch transparent/off không còn được CAMS quản lý, nên group
đã xóa không xuất hiện trở lại chỉ vì tên domain vẫn còn trên thiết bị.
Luồng này không gửi lệnh xóa VLAN hay xóa `vlan.dat`.

Transparent ngừng tham gia đồng bộ VLAN nhưng có thể vẫn chuyển tiếp VTP
advertisements, tùy phiên bản; đây không phải chế độ chặn toàn bộ VTP traffic.
VTPv3 primary/MST và authentication vẫn cần workflow riêng hiện có.
Tham khảo [Cisco — Understand VTP](https://www.cisco.com/c/en/us/support/docs/lan-switching/vtp/10558-21.html).
