# Routing

Đối chiếu: **2026-10-10**.

Routing Group thay thế workflow Clone trong QML. Popup bốn bước chọn từ hai đến
năm host đang connected, nhập Process ID/AS Number và Router ID riêng cho từng host,
nhập tham số chung, sau đó chọn network/area. `group_repository.py` tính network
từ IP/mask của `t02_interface_name`; backend kiểm tra lại ownership để QML không
thể lưu network không thuộc host. Save & Push lưu từng host độc lập, giữ kết quả
partial và mở batch preview trước khi gửi lệnh. Backend batch push tối đa năm
host đồng thời, cô lập lỗi/kết quả theo host và giữ nguyên pending state của host
thất bại. File kết quả cũ được xóa trước mỗi lần chạy để không tái sử dụng kết
quả stale. Retry cùng local draft `pending_apply` là idempotent cho cả OSPF và
EIGRP; process đã đồng bộ không bị ghi đè ngầm.

`clone_service.py` và các clone slot chỉ còn là compatibility API cho automation
cũ; không còn được export/khởi tạo bởi QML runtime mới.

OSPF Process có `AuthenticationCFG`: bật tùy chọn này áp dụng
message-digest authentication cho các area của process (tạo area 0 nếu chưa có
area). OSPF Router Interface được chia lại thành identity, adjacency và
authentication; payload hỗ trợ priority, plain/message-digest và auth key.

Feature điều phối Static, OSPF, EIGRP và routing information. Trạng thái
**partial**: CRUD/preview/push đã ở namespace feature; Routing Group đã có
service/repository riêng, các protocol đơn host vẫn còn adapter cần tách tiếp.
QML entry `UI/qml/features/routing/RoutingView.qml`; DB `t04_*`. Preview không kết
nối, push dùng session registry. Xem README thư mục con.

`features/routing/view_push.py` sở hữu preview/push riêng của routing;
`core/view_push.py` chỉ giữ base/shared controller và composition factory.

Sau Get Running Config, các tab Static, Default, OSPF và EIGRP đã được tạo sẽ
nạp lại dữ liệu của đúng host; tab có thay đổi chưa Save giữ nguyên draft.
Load OSPF/EIGRP dùng revision để callback của host cũ không ghi đè host mới.
Xóa process chỉ thay đổi local editor; Cancel Changes nạp lại dữ liệu đã lưu.

Lưu payload không thay đổi không tạo thêm pending work. Các bit cấu hình process
chưa Push được giữ qua nhiều lần Save, rồi reset sau Push thành công. Static/
Default validate toàn bộ payload và rollback cùng transaction khi một dòng lỗi.
Worker nhận diện CLI từ chối lệnh; host thất bại giữ pending state để kiểm tra/retry.

Regression coverage: `tests/test_routing_regressions.py` kiểm tra running-config,
Save/preview và acknowledgement bằng session giả; `tests/test_routing_ui_regressions.py`
chạy QML thật với SQLite tạm, kiểm tra xóa/hủy, đổi host và refresh tab đã cache.
Các suite Routing Group, clone compatibility, database contract và View & Push
kiểm tra luồng nhóm. BGP hiện chưa có editor/worker và tab vẫn bị vô hiệu hóa.
