# gocore RESTCONF: thiết kế triển khai phù hợp với CAMS

> Trạng thái: **đang triển khai nền tảng `dry-run`**
>
> Đối chiếu mã nguồn: **2026-10-11**
>
> Phạm vi: tự động phản ứng sự kiện an ninh từ Syslog bằng RESTCONF trên Cisco
> IOS XE. Tài liệu này không khẳng định CAMS hiện đã hỗ trợ luồng đó end-to-end.

## 1. Kết luận kiến trúc

Không triển khai theo mô hình “mỗi rule là một timer, Go tự đọc Syslog thô, tự
viết regex phát hiện rồi lấy mật khẩu trực tiếp từ SQLite”. Mô hình đó trùng với
logic CAMS đang có, không theo được workspace `.ntp` đang mở và làm Go phải hiểu
cơ chế mã hóa credential của Python.

Hướng phù hợp nhất với mã nguồn hiện tại là:

1. **Python tiếp tục sở hữu thu nhận và phát hiện sự kiện.** Sau khi Syslog được
   ghi vào `t12_syslog_messages`, `SecurityEventDetector` phân loại và tạo một
   sự kiện có cấu trúc.
2. **SQLite là hàng đợi bền vững.** Python ghi event vào
   `t13_automation_events`; Go match rule rồi materialize action vào
   `t13_automation_actions`. Không chỉ truyền dữ liệu qua bộ nhớ.
3. **Go là execution sidecar.** Một tiến trình `gocore` duy nhất cho workspace
   đang hoạt động nhận action đã chuẩn hóa, kiểm tra policy, gọi RESTCONF, xác
   minh kết quả, quản lý idempotency và ghi audit/rollback.
4. **Python giữ quyền với credential và vòng đời workspace.** Python giải mã
   credential bằng cơ chế hiện có rồi chuyển bí mật tạm thời cho tiến trình con;
   Go không đọc cột `password` và không nhận khóa `CAMS_CREDENTIAL_KEY`.
5. **Chưa bật `auto` trong bản đầu.** Bản đầu chỉ `dry-run`, sau đó
   `approve`. Chỉ cho phép `auto` khi listener, hàng đợi, worker và bộ lập lịch
   rollback đều chạy bền vững ngoài vòng đời cửa sổ Qt.

### Trạng thái triển khai hiện tại

Nhánh triển khai: `feature/gocore-restconf-foundation`.

Đã có trong lát cắt nền tảng đầu tiên:

- schema `t13_automation_events` và `t13_automation_actions` trong
  `info_collected.db`;
- event DTO version 1, ID/fingerprint tất định và persistence nguyên tử giữa
  event máy đọc với cảnh báo `%CAMS-*`;
- `SecurityEventDetector.process_detections()` giữ nguyên API cảnh báo cũ nhưng
  đồng thời trả event có cấu trúc;
- module Go `gocore` chỉ dùng standard library, có `doctor`, `validate-event` và
  JSON Lines sidecar `serve --stdio`;
- handshake sidecar chỉ chấp nhận `mode: dry-run`; binary hiện không có code
  gửi request mạng;
- `install.sh` đóng gói source Go, chạy Go test/build và cài lệnh `gocore`.

Chưa có trong lát cắt này:

- rule loader/matcher và materialize `t13_automation_actions`;
- Python process manager để tự khởi động sidecar theo workspace;
- RESTCONF profile, TLS probe, action driver, approve/rollback và UI;
- mọi chế độ có mutation mạng (`approve`, `auto`).

Luồng mục tiêu:

```text
Router/Switch
    │ Syslog UDP/TCP
    ▼
CAMS Syslog receiver
    │ parse + resolve source_ip → device_host
    ▼
t12_syslog_messages
    │ SecurityEventDetector (Python, logic duy nhất để phát hiện)
    ├──────────────► cảnh báo %CAMS-* + email/UI
    │
    ▼ transaction
t13_automation_events ──► t13_automation_actions
                               │ claim/lease
                               ▼
                        gocore sidecar (Go)
                               │ GET → PATCH/PUT/DELETE → GET verify
                               ▼
                            RESTCONF
```

## 2. Những gì mã nguồn hiện có thực sự cung cấp

| Thành phần | Hiện trạng trong mã nguồn | Hệ quả cho gocore |
| --- | --- | --- |
| Go | Đã có module `gocore`, event validator và sidecar protocol chỉ `dry-run`; chưa có RESTCONF executor | Có nền build/test an toàn nhưng chưa phải chức năng automation end-to-end |
| Syslog DB | `t12_syslog_messages` nằm trong `info_collected.db`; có `device_host`, `source_ip`, `received_at`, `cisco_facility`, `mnemonic`, `message`, `raw_message` | Không dùng schema suy đoán; `source_ip` là địa chỉ thiết bị gửi Syslog, không phải IP kẻ tấn công |
| Phát hiện an ninh | `features/syslog/application/security_events.py` đã nhận diện `ACL_DROP_FLOOD`, `DHCP_ROGUE_SERVER`, `DHCP_SNOOPING_FLOOD`, `DAI_ARP_SPOOF`, `PORT_SECURITY_REPEAT` | Tái sử dụng kết quả chuẩn hóa; không viết một bộ regex thứ hai trong Go |
| Cảnh báo tổng hợp | `SyslogManager._publish_security_alerts()` ghi lại bản tin `%CAMS-*` vào `t12_syslog_messages` và gửi email | Giữ luồng UI/email hiện có; action tự động phải có outbox riêng, không parse ngược chuỗi cảnh báo |
| Workspace | Khi mở `.ntp`, hai DB được giải nén vào thư mục tạm và toàn bộ service được chuyển sang DB đó | Không hard-code `/var/lib/cams/info_collected.db`; sidecar phải được bind vào workspace đang mở và dừng trước khi workspace bị dọn |
| Credential | `t01_devices.password` được mã hóa `ENC$v2$`; cipher phụ thuộc project/session và do Python quản lý | Go không thể và không nên tự giải mã trực tiếp từ SQLite |
| Cấu hình thiết bị | `t01_devices` chỉ có một `method` và một `portnumber` cho thiết bị | Cần profile RESTCONF riêng nếu cùng thiết bị vẫn dùng SSH/Telnet cho các module khác |
| RESTCONF hiện tại | Chỉ xuất hiện rời rạc ở Routing/DHCP/FHRP; ACL và Interface báo chưa tích hợp; nhiều request dùng `verify=False` | Không tái sử dụng nguyên trạng làm nền production; cần client chung, TLS bắt buộc, verify và rollback |
| Cài đặt Linux | CAMS cài theo user ở `$XDG_DATA_HOME/cams`, dữ liệu ở `CAMS_DATA_DIR` | MVP dùng tiến trình con do CAMS quản lý; không sinh unit dưới `/etc/systemd/system` |
| Email | `EmailAlertService` nằm trong tiến trình Qt, không phải daemon/API độc lập | Go ghi kết quả vào DB/stdout; Python phát thông báo và email |

Các nguồn sự thật chính:

- `infrastructure/database/schemas/info_collected/12_info_syslog.sql`
- `features/syslog/application/security_events.py`
- `features/syslog/qt/manager.py`
- `infrastructure/workspace/package.py` và `main.py`
- `infrastructure/security/credential_cipher.py`
- `infrastructure/database/schemas/device_network/01_core_devices.sql`
- `features/routing/worker.py`, `features/dhcp/worker.py`,
  `features/acl/worker.py`, `features/interfaces/view_push.py`
- `infrastructure/database/paths.py`, `install.sh` và
  `packaging/linux/cams-launcher`

## 3. Phạm vi và nguyên tắc an toàn

### 3.1 Trong phạm vi

- Nhận sự kiện an ninh có cấu trúc do Python phát hiện.
- `dry-run`, duyệt thủ công và thực thi action từ một catalog cố định.
- RESTCONF qua HTTPS với xác minh TLS.
- Giới hạn tốc độ, cooldown, deduplicate, lease, audit, verify và rollback.
- Cisco IOS XE đã được kiểm chứng model YANG trên đúng image lab.

### 3.2 Ngoài phạm vi bản đầu

- Không cho rule chứa SQL tùy ý.
- Không cho rule cung cấp URL RESTCONF hoặc JSON body tùy ý.
- Không tự lưu running-config vào startup-config.
- Không hỗ trợ đa vendor trước khi có driver và lab matrix riêng.
- Không hứa chạy tự động khi CAMS đã đóng.
- Không tắt interface dựa chỉ vào IP nguồn tìm thấy trong chuỗi log.

### 3.3 Fail closed

Một action phải bị từ chối nếu thiếu bất kỳ dữ liệu bắt buộc nào: thiết bị không
có profile RESTCONF, TLS chưa được tin cậy, model YANG chưa được chứng nhận,
interface không chuẩn hóa được, interface nằm trong deny-list, không đọc được
trạng thái trước thay đổi hoặc không tạo được kế hoạch rollback.

## 4. Ranh giới trách nhiệm

### Python

- Sở hữu listener, parser, device resolution và `SecurityEventDetector`.
- Tạo event có cấu trúc và ghi event outbox trong cùng transaction với cảnh báo dẫn
  xuất, hoặc bảo đảm có cơ chế replay theo `source_message_id`.
- Sở hữu UI rule, hàng đợi duyệt, thông báo và email.
- Sở hữu profile RESTCONF và giải mã credential.
- Khởi động/dừng sidecar cùng workspace; đóng workspace chỉ sau khi sidecar đã
  dừng và nhả DB.
- Không gửi password qua argv, file rule, stdout hay log.

### Go

- Đọc/validate rule và action envelope.
- Match event với rule và materialize action bằng `dedup_key` ổn định.
- Claim action bằng lease nguyên tử; chống chạy trùng sau crash/restart.
- Áp policy toàn cục trước policy từng rule.
- Render request bằng driver typed, không bằng template JSON tự do.
- Gọi RESTCONF, phân loại lỗi, đọc trạng thái trước/sau và xác minh.
- Ghi audit đã redaction, trạng thái action, lịch revert và kết quả revert.
- In JSON Lines có version để Python hiển thị; không in header Authorization,
  password hoặc body chứa secret.

## 5. Hợp đồng sự kiện: không parse lại `%CAMS-*`

`SecurityEventDetector` hiện tạo `SecurityEvent(rule, key, packets, target,
detail)`, sau đó chuyển nó thành câu tiếng Anh trong `SyslogMessage`. Chuỗi đó
phù hợp cho người đọc nhưng không phải API ổn định. Trước khi tích hợp Go, Python
cần giữ dữ liệu có cấu trúc và ghi một envelope như sau:

```json
{
  "schema_version": 1,
  "event_id": "01J...",
  "event_type": "PORT_SECURITY_REPEAT",
  "device_host": "192.0.2.2",
  "detected_at": "2026-10-11T08:30:00.123Z",
  "subject_key": "GigabitEthernet1/1",
  "attributes": {
    "interface": "GigabitEthernet1/1",
    "offender_mac": "1234.4567.abcd"
  },
  "evidence": {
    "events": 3,
    "packets": 3,
    "window_seconds": 60,
    "source_message_ids": [101, 105, 109]
  }
}
```

Yêu cầu hợp đồng:

- `schema_version` bắt buộc; version lạ bị từ chối.
- `device_host` là khóa inventory đã resolve, không lấy tùy ý từ template.
- IP, MAC, interface và số đếm được validate trước khi ghi outbox.
- `source_message_ids` cho phép truy ngược bằng chứng.
- Event không chứa credential hoặc JSON RESTCONF.
- Một `event_id` chỉ sinh tối đa một action cho mỗi `rule_id` và revision.

Không dùng bản phác SQL cũ để tìm `icmp ...` trong mọi bản tin `SEC`. Logic hiện
tại chỉ coi ACL log là sự kiện khi mnemonic chứa `ACCESSLOG`, action là
`denied`, và message khớp dạng đã kiểm thử. Với ACL flood, `key` là IP nguồn bị
ACL từ chối; bản tin hiện tại không bảo đảm có interface vào. Vì vậy action tắt
cổng phải bị chặn nếu event không có trường `attributes.interface` tin cậy.

## 6. Persistence và state machine

Schema có version đã được thêm tại
`infrastructure/database/schemas/info_collected/13_info_automation.sql`. Không
tạo file DB thứ ba trong workspace vì định dạng `.ntp` hiện chỉ cho phép
`device_network.db` và `info_collected.db`.

### `t13_automation_events`

Các cột tối thiểu:

- `id`, `event_id UNIQUE`, `schema_version`, `event_type`, `device_host`;
- `subject_key`, `attributes_json`, `evidence_json`;
- `source_message_id`, `detected_at`, `created_at`;
- `fingerprint UNIQUE` để chống tạo lại cùng event khi replay.

### `t13_automation_actions`

Các cột tối thiểu:

- `id`, `event_id`, `rule_id`, `rule_revision`, `mode`, `action_type`;
- `status`, `dedup_key UNIQUE`, `attempts`, `next_attempt_at`;
- `lease_owner`, `lease_until`;
- `request_redacted_json`, `before_json`, `after_json`;
- `etag_before`, `etag_after`, `http_status`, `last_error`;
- `approved_by`, `approved_at`, `applied_at`, `verified_at`;
- `revert_due_at`, `reverted_at`, `created_at`, `updated_at`.

State machine:

```text
detected
  ├─ dry-run ───────────────► simulated
  ├─ approve ───────────────► pending_approval ─► approved
  └─ auto (sau này) ────────► ready

approved/ready ─► claimed ─► applying ─► applied ─► verified
                         │          │          └─► revert_due ─► reverted
                         │          └────────────► failed
                         └───────────────────────► expired/cancelled
```

Quy tắc persistence:

- Claim bằng transaction ngắn (`BEGIN IMMEDIATE`), gán `lease_owner` và
  `lease_until`; không giữ transaction trong lúc gọi mạng.
- Bật WAL và `busy_timeout`; một tiến trình chỉ ghi theo batch nhỏ.
- Lease hết hạn cho phép worker khác thu hồi, nhưng trước khi retry phải GET để
  xác định request trước đã được áp dụng hay chưa.
- Mọi timestamp lưu UTC theo RFC 3339; query thời gian SQLite dùng
  `julianday(...)`, không so sánh chuỗi timestamp khác định dạng.
- Không xóa audit khi xóa rule. Rule revision và request đã redaction phải đủ để
  giải thích hành động cũ.

## 7. Rule v1: policy khai báo, không phải chương trình tùy ý

Rule nằm trong workspace/project và được Python kiểm tra trước khi kích hoạt.
Go kiểm tra lại bằng cùng JSON Schema. Dùng YAML cho người viết nhưng canonical
form dùng để hash/revision phải là JSON đã chuẩn hóa.

```yaml
version: 1

metadata:
  id: isolate-port-security-repeat
  description: Cô lập tạm cổng có port-security violation lặp lại
  enabled: true

match:
  event_type: PORT_SECURITY_REPEAT
  require_attributes: [interface]
  device_roles: [sw2, sw3]

policy:
  mode: dry-run                 # dry-run | approve | auto
  cooldown: 10m
  max_actions_per_hour: 3
  max_active_actions: 1

action:
  type: interface.admin-state
  interface_from: attributes.interface
  enabled: false
  ttl: 5m
```

Không đưa `target`, `path`, `method`, `body` hoặc SQL vào rule v1. Driver
`interface.admin-state` chịu trách nhiệm:

- lấy target từ `device_host` và profile inventory;
- chuẩn hóa interface;
- chọn YANG model/path đã được capability probe xác nhận;
- đọc giá trị trước khi đổi;
- dựng body JSON bằng `encoding/json`;
- xác minh giá trị sau khi đổi;
- tạo rollback từ **giá trị trước**, không mặc định luôn bật lại cổng.

Policy toàn cục có ưu tiên cao hơn rule:

- `protected_devices` và `protected_interfaces`;
- cấm interface quản lý, uplink, port-channel, SVI, loopback theo inventory và
  allow/deny-list rõ ràng; không chỉ dựa regex tên cổng;
- giới hạn action toàn hệ thống theo phút/giờ;
- circuit breaker theo thiết bị;
- kill switch chuyển tất cả rule về `dry-run`.

## 8. Profile RESTCONF và credential

Không dùng trực tiếp `t01_devices.method/portnumber` làm profile RESTCONF lâu
dài vì một thiết bị có thể đồng thời dùng SSH và RESTCONF. Thêm repository/profile
riêng, tối thiểu gồm:

| Trường | Ý nghĩa |
| --- | --- |
| `device_host` | FK tới `t01_devices.host` |
| `base_url` hoặc `port` | Endpoint cố định từ inventory, không lấy từ event |
| `username` | Tài khoản RESTCONF ít quyền nhất |
| `password`/`secret_ref` | Mã hóa bằng credential service hiện có hoặc tham chiếu secret store |
| `tls_mode` | `system-ca`, `custom-ca`, `pinned-cert`; không có mặc định insecure |
| `ca_bundle`/`server_name` | Dữ liệu xác minh peer |
| `platform`, `software_version` | Chọn driver/model đã chứng nhận |
| `capability_fingerprint` | Hash YANG modules/capabilities đã probe |

Trong MVP app-bound:

1. Python dùng repository/credential cipher hiện có để lấy profile.
2. Python spawn `gocore serve --stdio` với environment đã loại
   `CAMS_CREDENTIAL_KEY`, rồi gửi đúng credential cần dùng qua pipe stdin riêng;
   không qua argv hoặc file rule.
3. Go giữ credential trong bộ nhớ đúng thời gian cần thiết, không ghi DB/log.
4. Khi workspace đổi hoặc đóng, Python yêu cầu drain, dừng sidecar và xóa context.

Không truyền toàn bộ `CAMS_CREDENTIAL_KEY` cho Go. Khóa đó có thể giải mã nhiều
credential trong workspace hơn quyền gocore cần dùng.

## 9. RESTCONF client production-grade

### 9.1 Preflight thiết bị

Trước khi cho phép một profile rời `dry-run`:

1. Kết nối HTTPS và xác minh chứng thư.
2. `GET` resource gốc/capability và YANG library mà image cung cấp.
3. Xác nhận model, revision và path action cần dùng.
4. `GET` đúng resource sẽ sửa bằng tài khoản thực thi.
5. Thử action vô hại trong lab, kiểm tra status, body lỗi và kết quả đọc lại.
6. Lưu `capability_fingerprint`; nếu fingerprint đổi sau nâng cấp IOS XE thì tự
   hạ profile về `dry-run` cho tới khi kiểm chứng lại.

Không sao chép payload Cisco Native giữa các phiên bản IOS XE chỉ vì tên model
giống nhau.

### 9.2 Trình tự một action

1. Resolve profile từ `device_host`; kiểm tra policy bảo vệ.
2. `GET` resource hiện tại và lưu bản snapshot tối thiểu cần rollback.
3. Nếu thiết bị trả `ETag`, gửi `If-Match` khi sửa để tránh ghi đè thay đổi đồng
   thời.
4. Nếu trạng thái đã đúng, ghi `noop_verified`; không gửi mutation.
5. Gửi `PATCH`, `PUT` hoặc `DELETE` theo contract của driver.
6. Chấp nhận mọi mã thành công phù hợp (`2xx`), không chỉ `200` hoặc `204`.
7. `GET` lại và so sánh semantic value, không so sánh chuỗi JSON.
8. Chỉ đánh dấu `verified` sau bước 7.
9. Khi revert, chỉ khôi phục nếu trạng thái hiện tại vẫn là trạng thái gocore đã
   áp dụng; nếu người vận hành đã đổi, chuyển `manual_intervention` thay vì ghi
   đè.

### 9.3 Timeout và retry

- Tách connect timeout, TLS handshake timeout và response timeout.
- Chỉ retry có backoff/jitter với lỗi kết nối tạm thời hoặc status được phép.
- Không retry mù một mutation khi không biết server đã nhận hay chưa; GET và đối
  chiếu desired state trước.
- Giới hạn số lần retry và mở circuit breaker theo thiết bị.
- Parse `ietf-restconf:errors` để lưu `error-tag`, `error-path`, `error-message`
  đã redaction.

### 9.4 TLS

- Production cấm `InsecureSkipVerify`/`verify=False`.
- Lab có thể dùng `tls_mode: insecure-lab` nhưng phải cần hai cờ rõ ràng:
  cấu hình toàn cục cho phép và profile đánh dấu lab; UI luôn hiển thị cảnh báo.
- Không cho rule thay đổi CA, hostname hay TLS mode.

RESTCONF chuẩn hóa việc dùng HTTPS/YANG và cho phép điều kiện `If-Match` với
`ETag`; Cisco IOS XE cũng yêu cầu payload/path khớp đúng model được image hỗ
trợ. Vì vậy preflight và verify là một phần của action, không phải bước thử tay
tùy chọn.

## 10. Lựa chọn action theo loại cảnh báo

| Event hiện có | Dữ liệu đáng tin hiện có | Mặc định an toàn |
| --- | --- | --- |
| `ACL_DROP_FLOOD` | IP nguồn bị deny, đích/port nếu parse được; thường không có ingress interface | Notify/dry-run. Không shutdown port. Chỉ tạo ACL action sau khi có driver và attachment đã kiểm chứng |
| `DHCP_ROGUE_SERVER` | MAC hoặc interface untrusted tùy message | Approve; chỉ cô lập khi interface tồn tại và không thuộc protected list |
| `DHCP_SNOOPING_FLOOD` | MAC/interface | Dry-run rồi approve |
| `DAI_ARP_SPOOF` | MAC/interface và packet count | Dry-run rồi approve |
| `PORT_SECURITY_REPEAT` | Interface, đôi khi MAC | Ứng viên tốt nhất cho action `interface.admin-state` trong lab |

Ưu tiên action hẹp nhất. Không tạo ACL `GOCORE-BLOCK` rồi giả định ACL đó đã
được gắn đúng chiều và có `permit ip any any`; attachment và thứ tự ACE phải là
một phần của driver/preflight, nếu không action bị từ chối.

## 11. Vòng đời tiến trình

### 11.1 Giai đoạn 1 — app-bound sidecar

Python quản lý một tiến trình `gocore serve --stdio` cho workspace đang mở:

- truyền `project_id`, đường dẫn DB và protocol version qua handshake;
- theo dõi heartbeat và restart có giới hạn;
- sidecar claim action trong DB của workspace đó;
- đổi workspace: ngừng nhận action, chờ request đang chạy, đóng SQLite, dừng
  sidecar rồi mới xóa workspace tạm;
- đóng app: không nhận action mới và cảnh báo nếu còn action cần revert.

Ở giai đoạn này chỉ hỗ trợ `dry-run` và `approve`. Nếu action có TTL mà không có
daemon bền vững, CAMS phải từ chối đóng hoặc yêu cầu revert/acknowledge rõ ràng;
không được âm thầm hứa sẽ revert sau khi tiến trình đã dừng.

### 11.2 Giai đoạn 2 — unattended service

Chỉ triển khai khi cần `auto` hoạt động lúc GUI đóng. Đây không đơn thuần là
thêm timer cho gocore; phải tách cả đường ingest Syslog, deployment config,
secret và rollback state khỏi workspace tạm.

Thiết kế production:

- một `cams-automation.service`, không phải một timer cho mỗi rule;
- một deployment đã “publish” vào thư mục bền vững dưới XDG state/data hoặc
  `/var/lib/cams` nếu cài system-wide;
- listener/collector bền vững ghi vào deployment DB;
- secret qua systemd credentials hoặc secret store, không qua environment file
  chứa password thô;
- `Restart=on-failure`, hardening sandbox, giới hạn filesystem/network;
- worker tự quản lịch `revert_due_at`; systemd chỉ giám sát process.

Timer theo rule không phù hợp với phản ứng gần thời gian thực và tạo nhiều điểm
race. Nếu vẫn dùng timer cho tác vụ bảo trì, `OnUnitInactiveSec` phù hợp hơn khi
muốn đợi từ lúc lần chạy trước kết thúc; `AccuracySec` phải được đặt theo độ trễ
thực sự chấp nhận được, không mặc định tùy tiện là `1s`.

## 12. Cấu trúc module Go đề xuất

```text
gocore/
├── cmd/gocore/              # serve, validate-rules, probe, doctor
├── internal/protocol/       # JSONL handshake/event/result, versioned
├── internal/rules/          # schema, canonicalization, revision hash
├── internal/store/          # SQLite outbox, lease, audit, migrations
├── internal/policy/         # protected target, quotas, cooldown, kill switch
├── internal/catalog/        # typed action interfaces
├── internal/drivers/iosxe/  # YANG path/body/semantic verify theo capability
├── internal/restconf/       # HTTPS, TLS, auth, ETag, error parsing, retry
├── internal/executor/       # state machine và idempotency
└── internal/redact/         # structured logging không lộ secret
```

Interface quan trọng nên nhỏ và kiểm thử được:

```go
type ActionDriver interface {
    Preflight(ctx context.Context, device DeviceContext, action Action) error
    Read(ctx context.Context, client RESTCONFClient, action Action) (Snapshot, error)
    Apply(ctx context.Context, client RESTCONFClient, action Action, before Snapshot) (Snapshot, error)
    Verify(ctx context.Context, client RESTCONFClient, action Action, expected Snapshot) error
    Revert(ctx context.Context, client RESTCONFClient, action Action, before, applied Snapshot) error
}
```

Không đăng ký `regex_extract` trong Go ở thiết kế chính. Nếu cần truy vấn chẩn
đoán Syslog, dùng query tham số hóa và parser/test vector dùng chung; phát hiện
production vẫn có một authority là Python.

## 13. Lộ trình triển khai

Ký hiệu: ✅ hoàn thành trong foundation; 🟡 đang làm/hoàn thành một phần; ⬜ chưa
bắt đầu.

### Pha 0 — chốt dữ liệu lab ⬜

- Thu 20–30 Syslog thật cho từng loại event trên đúng IOS XE/image.
- Ghi nhận dòng nào có interface, MAC, source/destination IP và packet count.
- Probe YANG library, `GET` resource interface/ACL và lưu fixture đã loại secret.
- Chọn một action lab đầu tiên: `PORT_SECURITY_REPEAT` trên access port chuyên
  dụng; chưa chọn ACL flood làm action tự động đầu tiên.

**Xong khi:** fixture parser và RESTCONF response đủ để tái hiện offline.

### Pha 1 — event contract và outbox Python 🟡

- ✅ Tách kết quả detector thành event DTO có cấu trúc.
- ✅ Thêm schema/migration `t13_automation_*` và repository transaction.
- ✅ Giữ việc tạo `%CAMS-*`/email hiện có từ cùng DTO.
- Thêm UI xem event và kill switch; chưa gọi router.

**Xong khi:** restart app không làm mất action, replay không tạo trùng, đổi
workspace không trộn event.

### Pha 2 — gocore dry-run 🟡

- ✅ Tạo module Go, protocol JSONL và event validator.
- ⬜ Thêm rule validator, store lease và audit.
- Match event, tạo action idempotent và hiển thị action trong UI.
- ⬜ Implement catalog/action typed nhưng RESTCONF client dùng fake server.
- ⬜ Tích hợp lifecycle sidecar vào Python.

**Xong khi:** toàn bộ action chỉ thành `simulated`, không có network mutation;
crash/restart không thực thi trùng.

### Pha 3 — RESTCONF lab và approve ⬜

- Thêm RESTCONF profile, TLS trust, capability fingerprint.
- Implement driver `interface.admin-state` cho đúng IOS XE lab.
- GET-before, mutation, GET-verify và compare-and-revert.
- UI duyệt/từ chối và hiển thị audit đã redaction.

**Xong khi:** test lab chứng minh apply, verify, revert, concurrent human change,
timeout mơ hồ và certificate failure đều cho trạng thái đúng.

### Pha 4 — hardening ⬜

- Quota toàn cục, circuit breaker, protected inventory, metrics và doctor.
- Soak test Syslog burst/SQLite contention.
- Test nâng cấp schema, workspace save/open/close và process crash.
- Security review log, DB, core dump, argv/env và file permission.

**Xong khi:** không có secret trong log/artifact; không mất outbox; không ghi đè
thay đổi thủ công; mọi mutation đều có bằng chứng verify.

### Pha 5 — unattended/auto (tùy chọn) ⬜

- Tách listener và worker thành service bền vững.
- Publish deployment và secret theo mô hình service.
- Bảo đảm revert vẫn chạy khi GUI đóng, user logout hoặc host reboot.
- Chỉ sau đó cho phép `mode: auto`.

## 14. Ma trận kiểm thử bắt buộc

| Lớp | Trường hợp tối thiểu |
| --- | --- |
| Detector | Fixture thật, permit/recovery không kích hoạt, counter/window/cooldown, reset workspace |
| Outbox | Transaction failure, replay, unique dedup, WAL busy, lease expiry, crash sau claim |
| Rule | Schema sai, version lạ, field thiếu, protected target, quota, revision hash |
| Protocol | Handshake lệch version, malformed JSON, stdout redaction, sidecar chết |
| RESTCONF | TLS CA/pin, 401/403/404/409/412/429/5xx, timeout trước/sau mutation, error body |
| Driver | Model/revision khác, GET-before, noop, verify mismatch, human change trước revert |
| Workspace | Open/save/save-as/close, project mã hóa, đổi project khi action đang chạy |
| End-to-end lab | Syslog thật → event → approve → apply → verify → revert → audit/email |

Không dùng unit test mock HTTP làm bằng chứng IOS XE hỗ trợ payload. Mỗi driver
phải có fixture capability và bài kiểm tra trên thiết bị/image được ghi rõ phiên
bản.

## 15. Tiêu chí cho phép production

Chỉ chuyển một rule khỏi `dry-run` khi tất cả điều sau đều đúng:

- Event contract có trường đủ cho action, không suy ra từ chuỗi hiển thị.
- Target và interface được đối chiếu inventory/protected policy.
- Profile RESTCONF dùng TLS xác minh được và tài khoản ít quyền nhất.
- YANG model/revision đã probe và fingerprint chưa đổi.
- GET-before, verify và rollback đều qua test trên thiết bị thật.
- Outbox, lease, dedup và crash recovery đã được kiểm thử.
- Audit không lộ secret và truy ngược được source Syslog.
- Với `auto`, listener và rollback scheduler vẫn sống khi GUI đóng.

Nếu thiếu một điều, giữ `dry-run` hoặc `approve`; không dùng cờ “tạm bỏ qua” để
mở production.

## 16. Tài liệu chuẩn cần đối chiếu khi hiện thực

- [RFC 8040 — RESTCONF Protocol](https://www.rfc-editor.org/rfc/rfc8040)
- [RFC 8072 — YANG Patch Media Type](https://www.rfc-editor.org/rfc/rfc8072)
- [Cisco IOS XE Programmability Configuration Guide — RESTCONF](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/prog/configuration/1714/b_1714_programmability_cg/m_1714_prog_restconf.html)
- [systemd.timer](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html)

Các ví dụ Cisco chỉ là điểm bắt đầu. Path và payload cuối cùng phải lấy từ YANG
library và `GET` trên đúng thiết bị lab của dự án.

## 17. Build và kiểm tra foundation

Trong source checkout:

```bash
cd gocore
go test ./...
go build -trimpath -o /tmp/gocore ./cmd/gocore
/tmp/gocore doctor --json
```

`install.sh` yêu cầu Go 1.23 trở lên khi không đặt
`CAMS_INSTALL_SKIP_SETUP=1`. Bản cài chuẩn build binary vào
`$CAMS_INSTALL_BASE/app/bin/gocore` và tạo symlink `~/.local/bin/gocore` (hoặc
`CAMS_BIN_DIR/gocore`). Lệnh `doctor` phải báo `mode=dry-run` và
`network_mutation=false` ở foundation này.
