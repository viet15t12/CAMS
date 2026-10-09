# ACL

Standard/extended/dynamic/reflexive/MAC ACL và interface bindings. **implemented**
cho các dạng editor biểu diễn được, đối chiếu **2026-10-10**. QML
`UI/qml/features/acl/AclView.qml`; slots `core/acl_slots.py`; persistence/validation
trong `acl_db.py`, `rules.py`, `bindings.py`; View & Push trong `collector.py`,
`dispatcher.py`, `worker.py` và `templates/`.

Preview gom row `sync_status = pending_apply/pending_delete`, render ACL cùng
`ip access-group` mà không kết nối. Push chạy nền qua session SSH/Telnet hiện có
hoặc Nornir fallback; `dev = 1` mô phỏng fail-closed. Chỉ kết quả thiết bị thành
công mới chuyển row sang `synchronized` hoặc xóa row `pending_delete`. RESTCONF
chưa được backend ACL hỗ trợ.

Get Running Config dùng `features/devices/sync/acl.py` để nhập named/numbered IPv4
ACL, rule Dynamic/Reflexive/MAC và `ip/mac access-group` theo interface. Các row
quan sát dùng `synchronized`; chỉ thu thập không tạo pending Push. Import lại giữ
ACL ID và các rule/binding ID không đổi. Safe mode giữ ACL đang pending của host;
preview không ghi, force thay bằng snapshot thiết bị. ACL biến mất được xóa ở DB,
không tạo lệnh xóa ngược lên thiết bị. Switch cũng nhập ACL khi không có output
operational hoặc khi commit running-config không đổi.

Các form đã mở nạp lại sau signal collection/reconciliation của đúng host và giữ
draft/xóa tạm chưa Save. QML chuyển nested rule data thành plain object trước slot
Python; số nguyên QML dạng float được validate mà không cho phép số lẻ. Save không
đổi dữ liệu là no-op; rename giữ lệnh xóa ACL cũ, edit rồi delete không làm mất
tác vụ xóa ACL đã có trên thiết bị. Binding được validate theo ownership/direction.

Dynamic timeout lưu bằng giây, gửi IOS bằng phút nguyên; không khai báo absolute
timeout thì giữ NULL và bỏ keyword timeout. Mixed Dynamic/normal entries được giữ.
Reflexive evaluate lưu bằng `protocol='evaluate', action='permit'` và chỉ render
thành `evaluate NAME`, không thành permit/log. MAC bindings render `mac access-group`.
Sequence hỗ trợ 1..2147483647. Với IP ACL hoàn toàn không có sequence/remark, bit1
`action_Cfg` yêu cầu `ip access-list resequence NAME 10 10` trước khi sửa rule.
Layout thiếu sequence trộn với sequence/remark dùng bit2: vẫn View/Bindings nhưng
rules chỉ đọc cho tới khi có snapshot xác định sequence. Bit0 vẫn là description;
acknowledgement chỉ xóa những bit đã thực thi. Rule có qualifier chưa biểu diễn
được (ví dụ established, time-range, object-group) báo tên/reason, giữ nguyên ACL
cũ thay vì nhập một phần. Logging khi chỉnh rule vẫn theo policy của editor/template.

Lệnh và giới hạn đối chiếu [Cisco sequence numbering](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/sec_data_acl/configuration/15-e/sec-data-acl-15-e-book/sec-acl-seq-num.html)
và [Cisco MAC access-group](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/lanswitch/command/lsw-cr-book/lsw-m1.html).

Test: `test_acl_sync_regressions.py`, `test_acl_ui_refresh.py`, `test_acl_view_push.py`,
`test_dhcp_acl_persistence.py`. Bao gồm mẫu hai ACL từ screenshot, đủ năm loại,
backend/QML CRUD, collection sau commit không đổi, host isolation, safe/preview/force,
sequence và fake session nhiều ACL với success/rejected CLI. Chưa kiểm thử IOS thật.
Backlog: model dùng chung có kiểm soát với NAT ACL và các qualifier nâng cao.
