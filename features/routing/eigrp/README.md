# EIGRP

**partial**, đối chiếu **2026-10-10**, cho process, network, interface, passive,
redistribution, distribute/offset list và key chain. QML
`UI/qml/features/routing/eigrp/EigrpRoutingForm.qml`; DB nhóm EIGRP `t04_*`;
worker dùng `features/routing/worker.py`. Validate ASN, prefix, metric và
parent-child transaction. Routing Group preview theo host và push tối đa năm
thiết bị đồng thời, lỗi một host không dừng các host còn lại. Backlog: service
boundary riêng và kiểm tra trực tiếp các phiên bản IOS được hỗ trợ.

Save validate toàn bộ payload trước transaction; không thay đổi cấu hình thì
không đánh dấu pending. ASN là định danh theo host khi database ID bị thiếu/cũ.
Mask process bảy bit được tính ở backend, cộng dồn các lần Save chưa Push;
bit 0 không sinh lệnh set hoặc `no`. Chỉnh child không gửi lại process options.
Distribute/offset list và key chain tham gia preview, push và acknowledgement.
Key ID 0 được giữ qua QML; xóa process vẫn render các key đang pending_delete.
Preview che toàn bộ key-string, kể cả giá trị chứa khoảng trắng.
