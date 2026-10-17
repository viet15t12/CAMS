# Hướng dẫn Automation Rule `.rule.cams`

Tài liệu này mô tả định dạng CAMS Automation Rule phiên bản 1 và 2 đang được ứng dụng và Go sidecar hỗ trợ. Các file mẫu có thể import trực tiếp nằm trong thư mục [`demo`](demo/).

## 1. Cách hoạt động

Luồng xử lý hiện tại:

1. Syslog được phân tích thành security event, ví dụ `ICMP_FLOOD`.
2. CAMS Automation Engine đọc các file `*.rule.cams` đang bật.
3. Go sidecar đối chiếu `match`, `cooldown_seconds` và `max_actions_per_hour`.
4. Với `policy.mode = "auto"`, Go tạo một action đã validate ở trạng thái `ready`.
5. Python executor dùng **phiên SSH đang mở trong CAMS** để gửi lệnh cho thiết bị.
6. Executor chạy verification phù hợp rồi ghi kết quả vào Action History.

Automation Engine được tự khởi động cùng ứng dụng. Thanh trạng thái phía trên mọi trang Automation hiển thị `RUNNING`, `STOPPED` hoặc `ERROR`.

> Rule auto không tự mở kết nối mới. Thiết bị đích phải có một phiên SSH đang hoạt động trong CAMS.

## 2. Bảng cấu trúc file

| Nhóm | Trường | Kiểu/giới hạn | Ý nghĩa |
|---|---|---|---|
| Gốc | `version` | số nguyên `1` hoặc `2` | Phiên bản schema; v1 dùng typed action, v2 dùng SSH CLI action |
| `metadata` | `id` | chữ thường, số, `.`, `_`, `-`; tối đa 96 ký tự | ID duy nhất, đồng thời tạo tên file |
| `metadata` | `name` | chuỗi 1–200 ký tự | Tên hiển thị |
| `metadata` | `description` | chuỗi tối đa 2000 ký tự | Mô tả rule |
| `metadata` | `enabled` | boolean | `true` mới tham gia đánh giá event |
| `schedule` | `interval_seconds` | `1..3600` | Chu kỳ đánh giá rule |
| `match` | `event_type` | chuỗi không rỗng | Loại security event cần bắt |
| `match` | `network` | địa chỉ mạng IPv4, tùy chọn | Chỉ bắt event từ `device_host` thuộc mạng này; phải đi cùng `subnet_mask` |
| `match` | `subnet_mask` | subnet mask IPv4, tùy chọn | Mặt nạ mạng dạng chấm thập phân, ví dụ `255.255.255.0` |
| `match` | `require_attributes` | mảng tên thuộc tính | Event phải có đủ các thuộc tính này |
| `match` | `attributes` | object chuỗi–chuỗi | Các điều kiện bằng chính xác, ví dụ `protocol = icmp` |
| `policy` | `mode` | `dry-run` hoặc `auto` | Mô phỏng hoặc thực thi |
| `policy` | `cooldown_seconds` | `0..86400` | Chờ trước khi cùng rule/đối tượng được chạy lại |
| `policy` | `max_actions_per_hour` | `1..1000` | Giới hạn số action trong một giờ |
| `action` | `type` | xem bảng action | V1 dùng typed action; v2 chỉ nhận `ssh.cli` có giới hạn |
| `action` | `ttl_seconds` | `0..86400` | Auto SSH hiện bắt buộc bằng `0` |

Schema là strict: viết sai tên trường hoặc thêm trường lạ sẽ bị từ chối khi import/save.

`network` và `subnet_mask` là một cặp tùy chọn dùng chung cho cả version 1 và 2. Nếu khai báo một trường thì phải khai báo trường còn lại. `network` phải là địa chỉ đầu mạng chuẩn, ví dụ `192.168.122.0` với mask `255.255.255.0`; không dùng địa chỉ host như `192.168.122.101` với mask `/24`. CAMS đối chiếu subnet này với trường `device_host` của security event. Muốn chỉ nhận đúng một thiết bị, dùng địa chỉ host đó với mask `255.255.255.255`, ví dụ `192.168.122.101/32`. Khi bỏ cả hai trường, rule tiếp tục nhận event từ mọi thiết bị như trước. Tên trường đúng là `subnet_mask` (không phải `subnetmazk`).

## 3. Action đang hỗ trợ

| `action.type` | Mode | Có thay đổi thiết bị? | Các trường chính |
|---|---|---:|---|
| `interface.admin-state` | `auto` | Có, qua SSH | `transport: "ssh"`, `interface`, `enabled`, `ttl_seconds: 0` |
| `interface.admin-state` | `dry-run` | Không | `interface` hoặc `interface_from`, `enabled` |
| `acl.deny-protocol-source` | `dry-run` | Không | `protocol`, `source_from`, `interface_from`, `ttl_seconds` |
| `ssh.cli` (v2) | `auto` | Có, qua SSH | `mode`, `commands`, `verify_commands`, `ttl_seconds: 0` |
| `ssh.cli` (v2) | `dry-run` | Không | Lưu kế hoạch command nhưng không gửi thiết bị |

Với `interface.admin-state`:

- `enabled: false` tạo chuỗi cấu hình `interface <tên>` rồi `shutdown`.
- `enabled: true` tạo chuỗi cấu hình `interface <tên>` rồi `no shutdown`.
- Auto mode bắt buộc `transport: "ssh"` và một interface cố định.
- Executor luôn kiểm tra trạng thái trước và sau khi cấu hình.

### Action version 2 `ssh.cli`

| Trường | Giá trị | Ý nghĩa |
|---|---|---|
| `type` | luôn là `ssh.cli` | Chọn executor CLI phiên bản 2 |
| `transport` | luôn là `ssh` | Chỉ dùng phiên SSH đang mở trong CAMS |
| `mode` | `config` | Gửi toàn bộ `commands` bằng `send_config_set` trong configuration mode |
| `mode` | `exec` | Gửi lần lượt từng command ở privileged EXEC mode |
| `commands` | mảng 1–100 chuỗi | Danh sách lệnh thực thi; mỗi phần tử phải là đúng một dòng |
| `verify_commands` | mảng 0–20 chuỗi | Lệnh `show ...` chạy sau cùng để lưu bằng chứng |
| `ttl_seconds` | luôn là `0` | V2 chưa có rollback theo TTL |

Mỗi command tối đa 512 ký tự và tổng `commands` tối đa 16 KiB. Không đặt `\n`, `\r` hoặc NUL trong một phần tử. Không đặt mật khẩu, community string, private key hoặc token vào rule vì rule và action audit được lưu trong workspace.

## 4. Ví dụ shutdown cố định `GigabitEthernet0/3`

```json
{
  "version": 1,
  "metadata": {
    "id": "shutdown-gi0-3-on-icmp-flood",
    "name": "Shutdown Gi0/3 on ICMP flood",
    "description": "Close the fixed interface when CAMS receives an ICMP_FLOOD event.",
    "enabled": true
  },
  "schedule": {
    "interval_seconds": 1
  },
  "match": {
    "event_type": "ICMP_FLOOD",
    "network": "192.168.122.0",
    "subnet_mask": "255.255.255.0",
    "require_attributes": [],
    "attributes": {
      "protocol": "icmp"
    }
  },
  "policy": {
    "mode": "auto",
    "cooldown_seconds": 300,
    "max_actions_per_hour": 2
  },
  "action": {
    "type": "interface.admin-state",
    "transport": "ssh",
    "interface": "GigabitEthernet0/3",
    "enabled": false,
    "ttl_seconds": 0
  }
}
```

## 5. Tạo rule bằng giao diện

1. Mở **Automation → Rule Editor**.
2. Chọn **Quick Builder**.
3. Nhập Rule ID, tên, `event_type`, interface và giới hạn chạy. Có thể nhập thêm `Device network` và `Subnet mask`; phải nhập đủ cả hai trường.
4. Chọn **Shutdown** hoặc **No shutdown**.
5. Bấm **Build & Save Rule**.
6. Kiểm tra thanh trạng thái phải báo **Automation Engine active**.
7. Giữ phiên SSH của thiết bị đang mở trong CAMS.
8. Theo dõi kết quả trong **Automation → Action History**.

Nút **Generate JSON Preview** chuyển sang Advanced JSON để xem payload chính xác trước khi lưu.

Khi sửa một rule và đổi `metadata.id`, CAMS đổi tên file tương ứng thay vì để lại file cũ. Nếu ID mới đã tồn tại, thao tác bị từ chối để không ghi đè rule khác. Quick Builder chỉ mở các rule v1 mà nó có thể giữ nguyên đầy đủ; rule v2 hoặc rule có điều kiện nâng cao được giữ ở Advanced JSON để tránh làm mất field khi lưu.

Trang **Rule Files** có hai thao tác khác nhau: **Reload** chỉ đọc lại danh sách file trên giao diện, còn **Sync engine** yêu cầu Automation Engine kiểm tra và nạp ngay revision hiện tại. Sau thao tác Save, Import, Enable/Disable hoặc Delete, CAMS cũng tự yêu cầu engine refresh nếu dịch vụ đang chạy.

Để tạo chuỗi CLI v2, bấm **CLI v2 Example**, sửa danh sách command trong **Advanced JSON**, giữ `metadata.enabled: false` khi kiểm tra, rồi mới bật rule trong Rule Files.

## 6. Gửi một loạt lệnh phức tạp bằng version 2

`.rule.cams` v1 vẫn **không hỗ trợ** `commands`. Muốn gửi một chuỗi CLI, đổi sang version 2 và định nghĩa lại riêng khối `action`:

```json
{
  "version": 2,
  "metadata": {
    "id": "multi-command-icmp-response-v2",
    "name": "Multi-command ICMP flood response",
    "description": "Push a configuration sequence after an ICMP flood event.",
    "enabled": false
  },
  "schedule": {
    "interval_seconds": 5
  },
  "match": {
    "event_type": "ICMP_FLOOD",
    "network": "192.168.122.0",
    "subnet_mask": "255.255.255.0",
    "require_attributes": [],
    "attributes": {
      "protocol": "icmp"
    }
  },
  "policy": {
    "mode": "auto",
    "cooldown_seconds": 600,
    "max_actions_per_hour": 1
  },
  "action": {
    "type": "ssh.cli",
    "transport": "ssh",
    "mode": "config",
    "commands": [
      "interface GigabitEthernet0/3",
      "description CAMS_AUTO_ICMP_FLOOD",
      "shutdown"
    ],
    "verify_commands": [
      "show interfaces GigabitEthernet0/3"
    ],
    "ttl_seconds": 0
  }
}
```

Với `mode: "config"`, không thêm `configure terminal` hoặc `end`; Netmiko tự vào/thoát configuration mode. Các lệnh con như `interface ...`, `router ospf ...`, `network ...`, `exit` vẫn có thể đặt theo đúng thứ tự trong mảng. Chỉ dùng command không yêu cầu trả lời prompt tương tác.

Với các workflow cần tham số động lấy từ event, rollback tự động hoặc kiểm tra trạng thái theo cấu trúc, nên tạo một **typed action mới**, ví dụ `ospf.ensure-network`, rồi bổ sung đồng thời:

| Thành phần cần mở rộng | Trách nhiệm |
|---|---|
| Python schema | Chỉ nhận đúng tham số có kiểu và giới hạn giá trị |
| Go schema/engine | Validate giống Python, match event, tạo action đã che dữ liệu nhạy cảm |
| Python executor | Sinh danh sách lệnh cho action đó, khóa phiên SSH và phát hiện CLI error |
| Verification | Chạy lệnh `show ...` để chứng minh trạng thái sau cùng |
| Tests | Kiểm tra validate, dedup/cooldown, command generation và lỗi thiết bị |

V2 cố ý cho phép CLI nên chỉ import rule từ nguồn tin cậy, đọc toàn bộ `commands`, để rule ở trạng thái tắt khi thử nghiệm và dùng `verify_commands` để lưu bằng chứng sau khi push.

Nếu cần action mới, hãy cung cấp các thông tin sau để triển khai:

- Tên action mong muốn.
- Loại event kích hoạt và ví dụ event thực tế.
- Các tham số được phép nhập.
- Cấu hình Cisco IOS cần tạo.
- Lệnh `show` dùng để xác minh.
- Cách rollback khi một bước thất bại.

## 7. Trạng thái Action History

| Trạng thái | Ý nghĩa |
|---|---|
| `simulated` | Dry-run; không gửi cấu hình |
| `ready` | Go đã tạo auto action, đang chờ Python executor |
| `claimed` | Executor đã giữ lease và nhận action |
| `applying` | Executor đang gửi cấu hình và xác minh |
| `verified` | Đã đổi cấu hình và xác minh thành công |
| `noop_verified` | Thiết bị đã ở đúng trạng thái nên không cần đổi |
| `failed` | Không có SSH session, CLI bị từ chối hoặc xác minh thất bại |

Các event bị cooldown, rate limit hoặc dedup chặn sẽ tăng bộ đếm `suppressed`; chúng không tạo thêm một action history có trạng thái riêng.

## 8. Xử lý lỗi thường gặp

| Thông báo | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| `Automation requires an active SSH session` | Chưa mở CLI SSH cho host phát event | Mở phiên SSH trong CAMS và giữ kết nối hoạt động |
| `Device returned no state for interface ...` | Tên interface sai hoặc prompt/output không đúng | Thử `show interfaces <interface>` trong chính phiên CAMS |
| `Device did not recognize interface ...` | IOS không trả dòng chứa đúng tên interface | Kiểm tra tên đầy đủ, ví dụ `GigabitEthernet0/3` |
| `Cisco CLI rejected ...` | Thiết bị trả `% Invalid input`, thiếu quyền hoặc sai mode | Kiểm tra privilege và loại thiết bị |
| Rule hiện `INVALID` | JSON sai hoặc có field ngoài schema | Mở Advanced JSON, sửa theo bảng schema rồi Save |
| `match.network and match.subnet_mask must be provided together` | Rule chỉ khai báo một nửa cặp subnet | Thêm trường còn thiếu hoặc xóa cả hai trường |
| `canonical IPv4 network` | `network` chứa bit host hoặc subnet mask không hợp lệ | Dùng địa chỉ đầu mạng, ví dụ `192.168.122.0` + `255.255.255.0` |
| Engine `ERROR` | Go binary không chạy hoặc giao thức lỗi | Chạy `./cams.sh automation-check`, sau đó Start lại engine |

## 9. Kiểm tra file demo

Các file trong `demo/` đều được đặt `metadata.enabled: false` để tránh tự động thay đổi thiết bị ngay khi import. Sau khi sửa host/interface phù hợp, bật rule bằng checkbox trong trang Rule Files.

```bash
./cams.sh automation-check
.venv/bin/python -m unittest tests.test_automation_rules tests.test_automation_executor
```

