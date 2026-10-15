# CAMS Automation Engine: Go planner và SSH executor

> Trạng thái: rule v1 giữ typed action `interface.admin-state`; rule v2 hỗ trợ
> chuỗi CLI `ssh.cli`. Cả hai chạy qua phiên SSH hiện tại của CAMS.
>
> Đối chiếu mã nguồn: 2026-10-15.

## Luồng thực thi

```text
Syslog → SecurityEventDetector → t13_automation_events
       → gocore schedule/match rule → action status=ready
       → CAMS claim action → active DeviceSessionRegistry SSH session
       → v1: interface <name> + shutdown/no shutdown
       → v2: config batch hoặc tuần tự EXEC commands
       → verify commands → verified/noop_verified/failed
```

Go không nhận credential và không kết nối thiết bị. Sidecar chỉ đọc rule,
schedule/match event và phát action JSON có kiểu cố định cho CAMS. Python giữ
quyền sở hữu workspace, credential, SSH session và audit database.

## Hợp đồng rule v1

Action tự động hiện được giới hạn ở dạng sau:

```json
{
  "type": "interface.admin-state",
  "transport": "ssh",
  "interface": "GigabitEthernet0/3",
  "enabled": false,
  "ttl_seconds": 0
}
```

- `transport` bắt buộc là `ssh` khi `policy.mode` là `auto`.
- CAMS chỉ dùng phiên SSH đang hoạt động; không tự mở phiên mới.
- `enabled: false` sinh `interface <name>` và `shutdown`.
- `enabled: true` sinh `interface <name>` và `no shutdown`.
- `ttl_seconds` phải bằng `0` cho tới khi có revert scheduler.
- Rule v1 không được chứa raw CLI command, URL, payload hay SQL.
- Tên interface phải qua validator allow-list trước khi lập kế hoạch và trước
  khi thực thi.

## Hợp đồng rule v2

Rule v2 giữ nguyên `metadata`, `schedule`, `match` và `policy`, nhưng định nghĩa
lại khối action:

```json
{
  "type": "ssh.cli",
  "transport": "ssh",
  "mode": "config",
  "commands": [
    "router ospf 1",
    "network 10.0.0.0 0.0.0.255 area 0"
  ],
  "verify_commands": ["show ip ospf interface brief"],
  "ttl_seconds": 0
}
```

- `mode: config` gửi một batch bằng `send_config_set`.
- `mode: exec` gửi tuần tự từng command bằng CAMS prompt handling.
- Tối đa 100 command thực thi, 20 command xác minh và 512 ký tự mỗi dòng.
- Một phần tử command không được chứa newline, carriage return hoặc NUL.
- `policy.mode: dry-run` chỉ lập kế hoạch; `auto` mới gửi SSH.
- Không ghi credential hoặc secret vào command vì rule và audit nằm trong
  workspace.

## Trạng thái action

```text
ready → claimed → applying → verified
                           ├→ noop_verified
                           └→ failed
```

Action có lease bền vững trong SQLite. Claim v1 hết hạn được trả về `ready` vì
admin-state có tính idempotent. Claim v2 hết hạn chuyển thành `failed` và không
tự replay chuỗi CLI. Cooldown và giới hạn action mỗi giờ được kiểm tra lại khi
CAMS ghi action.

V1 chỉ ghi `verified` sau khi `show interfaces <name>` trả trạng thái mong đợi.
Nếu interface đã đúng trạng thái từ trước, CAMS ghi `noop_verified`. V2 chạy
`verify_commands` sau command chính; nếu không khai báo verify, audit ghi
`verification_mode: cli-accepted`. Lỗi session, CLI hoặc verify được ghi
`failed`.

## Điều kiện chạy

1. Thiết bị tồn tại trong workspace và không ở development mode.
2. Người dùng đã mở thành công một phiên SSH trong CAMS.
3. Automation service đang chạy.
4. Rule hợp lệ, bật `metadata.enabled`, dùng `policy.mode: auto` và
   `transport: ssh`.

Nếu không có phiên SSH đang hoạt động, action thất bại đóng (`failed`) và không
tự mở kết nối hoặc chuyển sang transport khác.

## Build và kiểm tra

```bash
cd gocore
go test ./...
go build -trimpath -o /tmp/cams-automation ./cmd/gocore
/tmp/cams-automation validate-rule \
  ../templates/automation/shutdown-gigabitethernet0-3-on-icmp-flood.rule.cams
```

Các test Python cho executor dùng connector giả lập để kiểm tra apply, wait,
verify và idempotency mà không thay đổi thiết bị thật.
