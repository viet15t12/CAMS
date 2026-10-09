# DHCP

DHCP pool, excluded address và helper address. **implemented** với QML
`UI/qml/features/dhcp/DhcpView.qml`, slots `core/dhcp_slots.py`, persistence và
worker trong `features/dhcp`. Desired state dùng `t03_*`; dữ liệu DHCP quan sát
dùng `t09_info_dhcp_*` trong database khác. Validation kiểm tra network/mask,
range, gateway, DNS và foreign key interface. View chỉ preview; Push chạy nền và
`dev = 1` không mở session thật. Parser RESTCONF thử nghiệm chưa phải đường hỗ
trợ end-to-end. Test: `test_dhcp_acl_persistence.py`, `test_dev_mode_workers.py`
và QML smoke.

Get Running Config đồng bộ IPv4 network pool vào `t03_dhcp_pool` qua
`features/devices/sync`, giữ chỉnh sửa pending trong safe mode. Bảng Saved Pools
tự đọc lại database khi lấy cấu hình thành công hoặc post-push sync hoàn tất,
nhưng giữ nguyên bản nháp đang nhập và các thay đổi chưa Save. Regression test:
`test_dhcp_pool_sync.py`, `test_dhcp_pool_ui_refresh.py`.
