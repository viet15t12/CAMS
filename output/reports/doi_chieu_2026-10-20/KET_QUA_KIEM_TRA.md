# Kết quả kiểm tra trong lần đối chiếu

**20/10/2026 — commit 825117f. Tổng 225 kiểm thử Python được chọn, tất cả đạt.** Không phải chạy toàn bộ test suite.

## 81 kiểm thử an ninh

Chạy bằng `.venv/bin/python`, `QT_QPA_PLATFORM=offscreen`, thư mục XDG riêng trong `/tmp/cams-report-audit/`.

```bash
.venv/bin/python -m unittest \
  tests/unit/test_credential_cipher.py \
  tests/unit/test_privilege_escalation.py \
  tests/unit/test_managed_terminal.py \
  tests/compliance/test_audit_engine.py \
  tests/syslog/test_email_alerts.py \
  tests/test_acl_view_push.py \
  tests/test_dhcp_acl_persistence.py
```

Kết quả: `Ran 81 tests in 0.563s`, `OK`. Lần đầu sandbox chặn socket IPC ở 3 ca; lần chạy lại được cấp quyền ngoài sandbox đạt toàn bộ. [Log kết quả](</data/Projects/CAMS_2/output/reports/doi_chieu_2026-10-20/bang_chung/security-tests-unsandboxed.txt>).

## 144 kiểm thử bổ sung

Mỗi module chạy trong một tiến trình riêng bằng `python -m unittest <module>`, cùng thiết lập Qt offscreen và XDG tạm để tránh ảnh hưởng cấu hình người dùng.

| Module | Số ca | Kết quả / log |
|---|---:|---|
| [tests/test_view_push_batch.py](</data/Projects/CAMS_2/tests/test_view_push_batch.py>) | 8 | [PASS](</data/Projects/CAMS_2/output/reports/doi_chieu_2026-10-20/bang_chung/tests__test_view_push_batch.py.txt>) |
| [tests/test_multi_device_batch.py](</data/Projects/CAMS_2/tests/test_multi_device_batch.py>) | 1 | [PASS](</data/Projects/CAMS_2/output/reports/doi_chieu_2026-10-20/bang_chung/tests__test_multi_device_batch.py.txt>) |
| [tests/test_host_pattern.py](</data/Projects/CAMS_2/tests/test_host_pattern.py>) | 8 | [PASS](</data/Projects/CAMS_2/output/reports/doi_chieu_2026-10-20/bang_chung/tests__test_host_pattern.py.txt>) |
| [tests/test_routing_group_fhrp.py](</data/Projects/CAMS_2/tests/test_routing_group_fhrp.py>) | 27 | [PASS](</data/Projects/CAMS_2/output/reports/doi_chieu_2026-10-20/bang_chung/tests__test_routing_group_fhrp.py.txt>) |
| [tests/test_automation_rules.py](</data/Projects/CAMS_2/tests/test_automation_rules.py>) | 12 | [PASS](</data/Projects/CAMS_2/output/reports/doi_chieu_2026-10-20/bang_chung/tests__test_automation_rules.py.txt>) |
| [tests/test_automation_executor.py](</data/Projects/CAMS_2/tests/test_automation_executor.py>) | 8 | [PASS](</data/Projects/CAMS_2/output/reports/doi_chieu_2026-10-20/bang_chung/tests__test_automation_executor.py.txt>) |
| [tests/test_automation_manager.py](</data/Projects/CAMS_2/tests/test_automation_manager.py>) | 3 | [PASS](</data/Projects/CAMS_2/output/reports/doi_chieu_2026-10-20/bang_chung/tests__test_automation_manager.py.txt>) |
| [tests/syslog/test_automation_outbox.py](</data/Projects/CAMS_2/tests/syslog/test_automation_outbox.py>) | 6 | [PASS](</data/Projects/CAMS_2/output/reports/doi_chieu_2026-10-20/bang_chung/tests__syslog__test_automation_outbox.py.txt>) |
| [tests/syslog/test_telegram_alerts.py](</data/Projects/CAMS_2/tests/syslog/test_telegram_alerts.py>) | 8 | [PASS](</data/Projects/CAMS_2/output/reports/doi_chieu_2026-10-20/bang_chung/tests__syslog__test_telegram_alerts.py.txt>) |
| [tests/syslog/test_telegram_alert_manager.py](</data/Projects/CAMS_2/tests/syslog/test_telegram_alert_manager.py>) | 1 | [PASS](</data/Projects/CAMS_2/output/reports/doi_chieu_2026-10-20/bang_chung/tests__syslog__test_telegram_alert_manager.py.txt>) |
| [tests/syslog/test_security_monitoring.py](</data/Projects/CAMS_2/tests/syslog/test_security_monitoring.py>) | 11 | [PASS](</data/Projects/CAMS_2/output/reports/doi_chieu_2026-10-20/bang_chung/tests__syslog__test_security_monitoring.py.txt>) |
| [tests/test_workspace_package.py](</data/Projects/CAMS_2/tests/test_workspace_package.py>) | 31 | [PASS](</data/Projects/CAMS_2/output/reports/doi_chieu_2026-10-20/bang_chung/tests__test_workspace_package.py.txt>) |
| [tests/test_workspace_save_and_snapshots.py](</data/Projects/CAMS_2/tests/test_workspace_save_and_snapshots.py>) | 20 | [PASS](</data/Projects/CAMS_2/output/reports/doi_chieu_2026-10-20/bang_chung/tests__test_workspace_save_and_snapshots.py.txt>) |

## Probe bằng dữ liệu tạm

Các probe gọi hàm thật với workspace tạm và đối tượng/mock kết nối. Không sử dụng dữ liệu bí mật thật hoặc thiết bị thật. [JSON kết quả](</data/Projects/CAMS_2/output/reports/doi_chieu_2026-10-20/bang_chung/synthetic-probes.json>).

| Hành vi kiểm tra | Kết quả |
|---|---|
| Bind session ghi `.credential_key` | Có |
| Bind session xuất khóa qua biến môi trường | Có |
| Chỉ gọi clear_session_credentials vẫn để lại tệp khóa | Có; đóng WorkspaceSession có cleanup riêng |
| Cùng passphrase/project_id, không truyền salt → cùng field key | Có |
| Giải mã bằng khóa HKDF fallback thành công → được đưa lên khóa chính | Có |
| Initial privilege không đọc được cấp quyền nhưng prompt `#` → được chấp nhận | Có |
| Không có enable_password → LoginService dùng password làm secret | Có |

## Kiểm kê schema

**74 + 21 = 95** tên bảng CREATE TABLE duy nhất trong hai thư mục schema nguồn. Loại trừ bảng nội bộ SQLite và không suy ra số bảng của mọi DB runtime. [Tên bảng và số đếm](</data/Projects/CAMS_2/output/reports/doi_chieu_2026-10-20/bang_chung/schema-counts.json>).

## Chưa xác minh bằng chạy thực tế

- `go test ./...`: không thực thi được vì `go: command not found`.
- Không chạy lại EVE-NG hoặc gửi lệnh cấu hình tới thiết bị thật.
- Không xác nhận gửi SMTP/Telegram thật; test sử dụng mock.
- Không đo benchmark Argon2id/AES, thông lượng Syslog, số thiết bị đồng thời hay thời gian failover.
- Không khởi chạy và kiểm tra toàn bộ giao diện tương tác. Đường tích hợp UI được xác nhận bằng truy vết source.
- Không biên dịch lại bộ PDF/slide vì không chỉnh sửa các tài liệu nguồn trong nhiệm vụ này.

Kết quả pass xác nhận những ca kiểm thử cụ thể. Các probe cũng cho thấy có hành vi không khớp lời mô tả bảo mật dù các test hiện có đều pass.
