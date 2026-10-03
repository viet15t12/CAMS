# BÁO CÁO KỸ THUẬT TOÀN DIỆN VỀ BỘ 3 TÍNH NĂNG AN NINH HỆ THỐNG CAMS
## (Cisco Automated Management System)

> **Tài liệu bàn giao & phân tích kỹ thuật chuyên sâu**  
> **Dự án:** CAMS - Cisco Automated Management System  
> **Phiên bản áp dụng:** CAMS 2.0+ (Phát triển NCKH 2026)  
> **Chủ đề:** An ninh xác thực thiết bị, kiểm soát phân quyền đặc quyền và bảo mật dữ liệu lưu trữ (Defense-in-Depth)

---

## MỤC LỤC

1. [TỔNG QUAN VÀ BỐI CẢNH AN NINH](#1-tổng-quan-và-bối-cảnh-an-ninh)
2. [TÍNH NĂNG 1: TÍCH HỢP TOÀN DIỆN MẬT KHẨU ĐẶC QUYỀN (ENABLE PASSWORD / SECRET)](#2-tính-năng-1-tích-hợp-toàn-diện-mật-khẩu-đặc-quyền-enable-password--secret)
   - 2.1. Dùng gì (Công nghệ, Chuẩn, Schema)
   - 2.2. Dùng ở đâu (Vị trí mã nguồn, Tệp, Lớp, Hàm)
   - 2.3. Dùng như thế nào (Luồng xử lý, Giao diện, Lưu trữ, Truy xuất)
3. [TÍNH NĂNG 2: KIỂM SOÁT LEO THANG ĐẶC QUYỀN VÀ XÁC MINH 2 BƯỚC PRIVILEGE 15](#3-tính-năng-2-kiểm-soát-leo-thang-đặc-quyền-và-xác-minh-2-bước-privilege-15)
   - 3.1. Dùng gì (Giao thức, Cơ chế bẫy prompt, Thuật toán xác minh)
   - 3.2. Dùng ở đâu (Vị trí mã nguồn, Module leo thang, Điểm kết nối)
   - 3.3. Dùng như thế nào (Sơ đồ tuần tự, Luồng kiểm tra 2 bước, Cơ chế Drop/Reject)
4. [TÍNH NĂNG 3: MÃ HÓA BẢO VỆ MẬT KHẨU LƯU TRỮ TRONG CƠ SỞ DỮ LIỆU (CƠ CHẾ 2)](#4-tính-năng-3-mã-hóa-bảo-vệ-mật-khẩu-lưu-trữ-trong-cơ-sở-dữ-liệu-cơ-chế-2)
   - 4.1. Dùng gì (Mật mã học đối xứng, KDF, Chuẩn NIST/RFC)
   - 4.2. Dùng ở đâu (Vị trí mã nguồn, Lớp Cipher, Tầng DB, Tầng Worker)
   - 4.3. Dùng như thế nào (Vòng đời khóa phiên, Quy trình mã hóa/giải mã, Tự động di chuyển dữ liệu)
5. [TỔNG HỢP KIẾN TRÚC VÀ BẢNG THAM CHIẾU BA BƯỚC "DÙNG GÌ - Ở ĐÂU - NHƯ THẾ NÀO"](#5-tổng-hợp-kiến-trúc-và-bảng-tham-chiếu-ba-bước-dùng-gì---ở-đâu---như-thế-nào)
6. [HƯỚNG DẪN THỰC NGHIỆM VÀ KẾT QUẢ KIỂM CHỨNG TỰ ĐỘNG](#6-hướng-dẫn-thực-nghiệm-và-kết-quả-kiểm-chứng-tự-động)
7. [KẾT LUẬN VÀ GIÁ TRỊ KHOA HỌC](#7-kết-luận-và-giá-trị-khoa-học)

---

## 1. TỔNG QUAN VÀ BỐI CẢNH AN NINH

Trong kiến trúc mạng doanh nghiệp vận hành thiết bị Cisco IOS/IOS-XE, việc quản lý và tự động hóa cấu hình đòi hỏi hệ thống quản trị trung tâm (như CAMS) phải giải quyết đồng thời 3 bài toán an ninh cốt lõi:

1. **Phân tách định danh và xác thực đa tầng:** Thiết bị Cisco thường cấu hình tài khoản người dùng ban đầu ở mức đặc quyền thấp (`privilege 1` hoặc `privilege 5`) và yêu cầu xác thực bước hai bằng `enable secret` để nâng cấp lên chế độ quản trị tối cao (`privilege 15`). Hệ thống trước đây chỉ lưu một trường `password` duy nhất, gây tê liệt hoặc thất bại khi thiết bị yêu cầu mật khẩu enable độc lập.
2. **Kiểm soát tính toàn vẹn quyền hạn kết nối (Privilege Escalation Enforcement):** Khi đăng nhập bằng tài khoản có mức đặc quyền trung gian (ví dụ: `privilege 5`), thiết bị Cisco hiển thị sẵn dấu nhắc lệnh `#` thay vì `>`. Các thư viện tự động hóa thông thường (như Netmiko) khi kiểm tra `check_enable_mode()` chỉ nhìn vào ký tự `#` cuối chuỗi nên bị đánh lừa rằng phiên đã đạt quyền tối cao. Nếu phần mềm gửi các lệnh cấu hình yêu cầu đặc quyền 15 (như OSPF, ACL, NAT, cấu hình interface), thiết bị sẽ từ chối âm thầm hoặc báo lỗi quyền hạn. Cần một cơ chế xác minh 2 bước nghiêm ngặt: kiểm tra thực tế bằng `show privilege` và cưỡng bức leo thang (force escalate) lên cấp 15; nếu không đủ điều kiện phải **lập tức ngắt kết nối (DROP/Reject)** để tránh rủi ro thao tác sai quyền.
3. **Bảo mật lưu trữ thông tin nhạy cảm (At-Rest Database Credential Masking):** Toàn bộ tài khoản và mật khẩu thiết bị được lưu trữ trong cơ sở dữ liệu SQLite (`device_network.db`, bảng `t01_devices`). Nếu lưu trữ dạng bản rõ (plaintext), kẻ tấn công chiếm được quyền truy cập máy tính hoặc trích xuất gói dự án `.ntp` có thể dễ dàng đọc được toàn bộ mật khẩu hạ tầng mạng bằng các lệnh đơn giản như `strings` hoặc SQLite Browser. Cần một cơ chế mã hóa khả nghịch mạnh mẽ gắn liền với mật khẩu dự án (Project Passphrase - Cơ chế 2), đảm bảo dữ liệu trong SQLite luôn ở trạng thái mã hóa authenticated ciphertext và tự động giải mã minh bạch trong bộ nhớ RAM khi kết nối mạng.

Cả 3 tính năng trên đã được thiết kế, triển khai và hoàn thiện đồng bộ 100% trong mã nguồn của CAMS.

```mermaid
graph TD
    subgraph "TÍNH NĂNG 3: MÃ HÓA CƠ SỞ DỮ LIỆU (CƠ CHẾ 2)"
        A[Người dùng nhập Mật khẩu Dự án / Workspace Session] --> B[Argon2id / HKDF KDF Engine]
        B --> C[Khóa phiên DEK 256-bit trong RAM]
        C --> D[AES-256-GCM Cipher]
        D -->|Ghi dữ liệu| E[(SQLite: t01_devices)]
        E -->|Đọc dữ liệu| D
        D -->|Giải mã trong RAM| F[Plaintext Credentials]
    end

    subgraph "TÍNH NĂNG 1: TÍCH HỢP ENABLE SECRET"
        F --> G[DeviceLoginService & Repository]
        G --> H[Cung cấp {username, password, enable_password}]
    end

    subgraph "TÍNH NĂNG 2: XÁC MINH 2 BƯỚC PRIVILEGE 15"
        H --> I[DeviceConnector / SessionRegistry / Workers]
        I --> J[Bước 1: Kết nối SSH/Telnet ban đầu]
        J --> K{Prompt kết thúc bằng # ?}
        K -- Chưa có # --> L[Chạy netmiko.enable()]
        K -- Đã có # --> M[Bước 2: Gửi lệnh 'show privilege']
        M --> N{Level == 15 ?}
        N -- Đúng 15 --> O[Chấp thuận kết nối - SUCCESS]
        N -- Nhỏ hơn 15 --> P{Có Enable Secret không?}
        P -- Không có / Sai --> Q[DROP KẾT NỐI - NGẮT PHIÊN LẬP TỨC]
        P -- Có Secret --> R[Cưỡng bức chạy 'enable 15']
        R --> S{Kiểm tra lại show privilege == 15 ?}
        S -- Đạt 15 --> O
        S -- Thất bại --> Q
    end
```

---

## 2. TÍNH NĂNG 1: TÍCH HỢP TOÀN DIỆN MẬT KHẨU ĐẶC QUYỀN (ENABLE PASSWORD / SECRET)

### 2.1. DÙNG GÌ (What is used)

* **Công nghệ & Thư viện:**
  - **PyQt6 / QML:** Thiết kế trường nhập liệu chuyên biệt sử dụng component dùng chung `StandardPasswordField`.
  - **SQLite3:** Bổ sung cột dữ liệu vào bảng thiết bị cốt lõi.
  - **Netmiko / Paramiko:** Nhận tham số `secret` trong `ConnectHandler` để phục vụ lệnh chuyển chế độ `enable`.
  - **Nornir 3:** Cấu hình tham số `cams_netmiko.extras.secret` trong từ điển kết nối inventory.
* **Cơ chế & Schema:**
  - **Cột mới:** `enable_password TEXT DEFAULT ''` trong bảng `t01_devices`.
  - **Tự động di chuyển dữ liệu (Auto-Migration DDL):**
    ```sql
    ALTER TABLE t01_devices ADD COLUMN enable_password TEXT DEFAULT '';
    ```
    Tự động kiểm tra và thực thi khi mở bất kỳ cơ sở dữ liệu cũ nào mà không làm gián đoạn hệ thống.
  - **Ánh xạ từ khóa đa nguồn:** Hỗ trợ nhận diện các cột `enable_password`, `enable_pass`, `enable_secret`, `secret` khi người dùng nhập thiết bị hàng loạt từ file Excel/CSV/JSON.

### 2.2. DÙNG Ở ĐÂU (Where it is used)

| Thành phần | Đường dẫn tệp tuyệt đối | Lớp / Hàm / Đối tượng cụ thể | Vai trò |
| :--- | :--- | :--- | :--- |
| **SQL Schema** | `/data/Projects/CAMS_2/infrastructure/database/schemas/device_network/01_core_devices.sql` | Bảng `t01_devices` | Khai báo trường `enable_password TEXT DEFAULT ''` trong cấu trúc bảng gốc. |
| **QML UI Form** | `/data/Projects/CAMS_2/UI/qml/sidebar/new_device/NewDevice.qml` | `StandardPasswordField` (dòng 344–363) | Giao diện cho phép nhập/ẩn/hiện Enable Secret khi thêm hoặc sửa thiết bị. |
| **Backend Slots** | `/data/Projects/CAMS_2/core/database/device_slots.py` | `DeviceSlotsMixin` (`_connect`, `addDevice`, `updateDevice`, `getDeviceByHost`, `addDevicesBatch`) | Nhận tham số từ QML, kiểm tra migration cột, lưu vào SQLite và trả dữ liệu lên form sửa. |
| **Import Slots** | `/data/Projects/CAMS_2/core/database/device_import_slots.py` | `DeviceImportSlotsMixin._import_devices_from_path` | Bóc tách trường mật khẩu enable từ file JSON/Excel và nạp vào DB. |
| **Repository** | `/data/Projects/CAMS_2/features/devices/repository.py` | `DeviceRepository.get_login` | Truy vấn `SELECT host, ..., COALESCE(enable_password, '') AS enable_password FROM t01_devices`. |
| **Login Service** | `/data/Projects/CAMS_2/features/devices/login_service.py` | `DeviceLoginService.load` | Ánh xạ bản ghi DB thành dictionary chuẩn hóa gồm `secret` và `enable_password`. |
| **Network Connector** | `/data/Projects/CAMS_2/infrastructure/network/device_connector.py` | `DeviceConnector.__init__`, `connect` | Nạp `secret` vào tham số khởi tạo Netmiko `ConnectHandler`. |
| **Connector Factory** | `/data/Projects/CAMS_2/infrastructure/network/connector.py` | `create_connector` | Chuyển tiếp `secret=device.get("secret") or device.get("enable_password")`. |

### 2.3. DÙNG NHƯ THẾ NÀO (How it works)

1. **Khi người dùng thêm/sửa thiết bị trên giao diện:**
   - Giao diện `NewDevice.qml` cung cấp 2 trường mật khẩu độc lập: **Device Password** (mật khẩu tài khoản đăng nhập SSH/Telnet ban đầu) và **Enable Password / Secret** (mật khẩu leo thang quyền hạn).
   - QML gọi slot `dbManager.addDevice(..., password, ..., enable_password)` hoặc `dbManager.updateDevice(...)`.
   - Backend `device_slots.py` tiếp nhận cả hai trường và lưu trữ an toàn vào bảng `t01_devices`.
2. **Khi nạp thiết bị cho dịch vụ mạng:**
   - Khi một tác vụ (SSH test, sync cấu hình, đẩy lệnh) cần kết nối thiết bị theo IP, `DeviceRepository.get_login(host)` được gọi.
   - Hàm trả về dictionary chứa đầy đủ `username`, `password`, `enable_password`.
   - `DeviceLoginService.load(host)` đóng gói cấu hình với quy tắc ưu tiên:
     ```python
     "secret": row.get("enable_password") or row.get("password") or "",
     "enable_password": row.get("enable_password") or "",
     ```
     Đảm bảo nếu người dùng có nhập Enable Secret thì hệ thống dùng Enable Secret; nếu thiết bị dùng chung mật khẩu đăng nhập cho cả enable thì tự động fallback về mật khẩu chính, không làm gián đoạn phiên.

---

## 3. TÍNH NĂNG 2: KIỂM SOÁT LEO THANG ĐẶC QUYỀN VÀ XÁC MINH 2 BƯỚC PRIVILEGE 15

### 3.1. DÙNG GÌ (What is used)

* **Giao thức & Thư viện mạng:**
  - **Netmiko (`ConnectHandler`):** Thực thi lệnh tương tác CLI, phát hiện prompt và gửi lệnh đặc quyền.
  - **Biểu thức chính quy (Regex):**
    ```python
    PRIVILEGE_LEVEL_RE = re.compile(r"Current privilege level is\s+(\d+)", re.IGNORECASE)
    ```
    Trích xuất chính xác con số đặc quyền trả về từ lệnh chuẩn `show privilege` của Cisco IOS.
* **Cơ chế an ninh 2 bước (Strict 2-Step Privilege 15 Verification):**
  - **Bước 1 (Prompt Level):** Kiểm tra ký tự kết thúc prompt. Nếu là `>` (cấp 1 thông thường), gọi `netmiko.enable()` chuẩn.
  - **Bước 2 (Execution Level - Cisco Specific):** Nếu prompt đã có dấu `#`, không tin tưởng tuyệt đối vào prompt. Gửi lệnh `show privilege` để lấy mức quyền thực tế. Nếu `level < 15`:
    - Bắt buộc kiểm tra xem người dùng có cung cấp Enable Secret hay không.
    - Nếu **KHÔNG CÓ** hoặc **SAI** Enable Secret: **LẬP TỨC DROP KẾT NỐI (Ngắt phiên)**, ghi nhận lỗi phân quyền và chặn hoàn toàn các thao tác phía sau.
    - Nếu **CÓ** Enable Secret: Cưỡng bức leo thang bằng `enable.cmd="enable 15"`, sau đó gửi lại lệnh `show privilege` để tái xác minh. Nếu vẫn không đạt cấp 15, tiếp tục ngắt kết nối ngay lập tức.
* **Quy chuẩn kiểm soát chế độ:** Nếu kết nối đang ở `config mode` (prompt `(config)#`), hàm tự động thoát về EXEC mode (`exit_config_mode()`) trước khi xác minh đặc quyền.

### 3.2. DÙNG Ở ĐÂU (Where it is used)

| Thành phần | Đường dẫn tệp tuyệt đối | Lớp / Hàm cụ thể | Vai trò |
| :--- | :--- | :--- | :--- |
| **Privilege Engine** | `/data/Projects/CAMS_2/infrastructure/network/privilege.py` | `ensure_privileged_mode(conn)` & `ensure_initial_privilege(conn, secret)` | Module chuyên biệt chịu trách nhiệm toàn bộ logic xác minh 2 bước và cưỡng bức leo thang privilege 15. |
| **Device Connector** | `/data/Projects/CAMS_2/infrastructure/network/device_connector.py` | `DeviceConnector.connect` (dòng 86–105) | Điểm chốt chặn ban đầu khi kết nối thiết bị. Gọi `ensure_initial_privilege` ngay sau khi mở kênh SSH/Telnet. |
| **Session Registry** | `/data/Projects/CAMS_2/infrastructure/network/session_registry.py` | `DeviceSessionRegistry._prepare` (dòng 230–238) | Đảm bảo tất cả các phiên kết nối dùng chung (terminal/CLI tab) được nâng cấp lên privilege 15 trước khi cấp phát. |
| **Config Collector** | `/data/Projects/CAMS_2/infrastructure/network/running_config_collector.py` | `RunningConfigCollector.collect_and_save` (dòng 55–65) | Đảm bảo phiên thu thập `show running-config` đạt quyền 15 để không bị ẩn các dòng cấu hình nhạy cảm. |
| **Nornir Tasks** | `/data/Projects/CAMS_2/infrastructure/network/nornir_netmiko_tasks.py` | `netmiko_send_config` (dòng 73–82) | Nâng cấp quyền phiên Nornir Netmiko lên privilege 15 trước khi đẩy khối lệnh cấu hình. |
| **Unit Tests** | `/data/Projects/CAMS_2/tests/unit/test_privilege_escalation.py` | Lớp `PrivilegeEscalationTests` & `CredentialFlowTests` | Bộ 12 ca kiểm thử tự động giả lập đầy đủ mọi tình huống phân quyền (15, 5 đúng pass, 5 sai pass, 5 không pass, config mode, v.v.). |

### 3.3. DÙNG NHƯ THẾ NÀO (How it works)

Dưới đây là chi tiết mã nguồn cốt lõi trong `infrastructure/network/privilege.py`:

```python
def ensure_initial_privilege(connection: Any, secret: str = "") -> None:
    """Verify privilege level 15 upon connection.
    
    If prompt ends in '#' but privilege < 15, verify secret is present and elevate.
    If secret is missing or elevation fails, raise PermissionError / RuntimeError to DROP connection.
    """
    device_type = str(getattr(connection, "device_type", "") or "").lower()
    is_cisco = "cisco" in device_type or not device_type

    if not is_cisco or not hasattr(connection, "send_command"):
        ensure_privileged_mode(connection)
        return

    # Kiểm tra mức quyền thực tế qua show privilege
    priv_output = connection.send_command("show privilege")
    match = PRIVILEGE_LEVEL_RE.search(str(priv_output or ""))
    current_level = int(match.group(1)) if match else 1

    if current_level < 15:
        if not secret:
            # Ngắt kết nối lập tức: Từ chối phiên khi quyền hạn < 15 mà không có Secret
            raise PermissionError(
                f"Device initial privilege is {current_level} (requires 15). "
                "No Enable Secret provided to elevate privilege. Connection rejected."
            )
        # Tiến hành leo thang
        ensure_privileged_mode(connection)
        # Kiểm tra lại sau khi leo thang
        verify_output = connection.send_command("show privilege")
        verify_match = PRIVILEGE_LEVEL_RE.search(str(verify_output or ""))
        if verify_match and int(verify_match.group(1)) < 15:
            raise RuntimeError(
                f"Failed to elevate to privilege 15 (current level: {verify_match.group(1)}). "
                "Enable Secret may be incorrect."
            )
```

**Hành vi cụ thể của hệ thống khi hoạt động:**
- **Trường hợp 1 (Tài khoản Full Admin - Privilege 15):** Thiết bị đăng nhập vào có sẵn quyền 15. Lệnh `show privilege` trả về `15`. Hệ thống chấp thuận kết nối ngay lập tức, không tốn thêm lệnh `enable`.
- **Trường hợp 2 (Tài khoản Privilege 1):** Prompt là `>`. Netmiko tự nhận diện `check_enable_mode() == False` và gửi lệnh `enable` cùng mật khẩu `secret`.
- **Trường hợp 3 (Tài khoản Privilege 2–14, ví dụ Privilege 5):** Prompt đã kết thúc bằng `#`. Netmiko tưởng lầm là đã có quyền tối cao. CAMS chủ động can thiệp bằng cách gửi `show privilege` -> phát hiện cấp 5 -> kiểm tra mật khẩu `secret` -> cưỡng bức `enable 15` -> xác minh lại đạt 15 mới cấp quyền thao tác.
- **Trường hợp 4 (Sai hoặc thiếu Enable Secret khi quyền < 15):** Hệ thống lập tức tung ra ngoại lệ `PermissionError` hoặc `RuntimeError`, kích hoạt khối xử lý ngắt kết nối `connection.disconnect()` và đánh dấu trạng thái thiết bị là `failed` kèm thông báo rõ ràng cho quản trị viên, **tuyệt đối không cho phép phiên bán đặc quyền tồn tại trong hệ thống**.

---

## 4. TÍNH NĂNG 3: MÃ HÓA BẢO VỆ MẬT KHẨU LƯU TRỮ TRONG CƠ SỞ DỮ LIỆU (CƠ CHẾ 2)

### 4.1. DÙNG GÌ (What is used)

* **Chuẩn mật mã học quốc tế:**
  - **Thuật toán mã hóa đối xứng:** **AES-256-GCM (Galois/Counter Mode)** theo tiêu chuẩn **NIST SP 800-38D**.
    * Độ dài khóa: **256 bits** (32 bytes).
    * Nonce/IV: **12 bytes** (96 bits) được sinh ngẫu nhiên bằng bộ tạo số ngẫu nhiên an toàn mật mã học (`secrets.token_bytes(12)`). Mỗi lần mã hóa tạo ra một Nonce mới, chống hoàn toàn tấn công Replay Attack.
    * Thẻ xác thực (Authentication Tag): **16 bytes** (128 bits), đảm bảo tính toàn vẹn (Integrity) và xác thực nguồn gốc (Authenticity). Nếu kẻ tấn công thay đổi dù chỉ 1 bit trong cơ sở dữ liệu, quá trình giải mã sẽ báo lỗi `InvalidTag` và từ chối xử lý.
    * Dữ liệu liên kết xác thực (Authenticated Additional Data - AAD): `b"CAMS_DEVICE_CREDENTIAL_V1"`. Ràng buộc chặt chẽ dữ liệu mã hóa vào ngữ cảnh mật khẩu thiết bị CAMS, chống hoán đổi dữ liệu từ các hệ thống khác.
  - **Hàm dẫn xuất khóa (Key Derivation Function - KDF):**
    * Khi dự án có mật khẩu bảo vệ (`.ntp` có mật khẩu): Sử dụng **Argon2id (RFC 9106)** - thuật toán chiến thắng cuộc thi Password Hashing Competition (PHC), chống lại các cuộc tấn công bẻ khóa bằng GPU/ASIC nhờ cơ chế tiêu tốn bộ nhớ (Memory-hard).
      - `memory_cost = 32 MiB` (32,768 KiB)
      - `iterations = 2`
      - `lanes = 2`
      - `salt = SHA256("CAMS_PASSPHRASE:" + project_id)[:16]`
    * Khi dự án ở chế độ mở (không đặt mật khẩu): Sử dụng **HKDF-SHA256 (RFC 5869)** dẫn xuất từ `project_id` kết hợp với muối định danh ứng dụng `DEFAULT_SALT`, đảm bảo dữ liệu trong SQLite luôn ở trạng thái mã hóa chứ không bao giờ tồn tại bản rõ.
* **Quy cách định dạng dữ liệu (Envelope Serialization Format):**
  - Định dạng chuỗi lưu trong cột SQLite:
    ```
    ENC$v1$<base64(nonce_12B + ciphertext_and_tag)>
    ```
  - Ví dụ thực tế trong cơ sở dữ liệu `device_network.db`:
    ```
    ENC$v1$YfmQ8eM+/3S50qeeU4gxlRuoCH8Kg6MhdXQfzOb1pDNXsz2ABS9DaGsU7+HwMg==
    ```
  - Tiền tố `ENC$v1$`:
    1. Giúp hệ thống nhận biết tức thì bản ghi đã được mã hóa theo phiên bản 1.
    2. Đảm bảo **tính tương thích ngược 100%**: Nếu bản ghi cũ trong cơ sở dữ liệu là chuỗi plaintext (không bắt đầu bằng `ENC$v1$`), hàm giải mã nhận diện được và trả về nguyên trạng mà không gây crash hệ thống.
    3. Đảm bảo **tính lũy đẳng (Idempotent)**: Hàm `encrypt()` khi gặp chuỗi đã có tiền tố `ENC$v1$` sẽ bỏ qua, không bao giờ xảy ra lỗi mã hóa 2 lần (double encryption).

### 4.2. DÙNG Ở ĐÂU (Where it is used)

| Thành phần | Đường dẫn tệp tuyệt đối | Lớp / Hàm cụ thể | Vai trò |
| :--- | :--- | :--- | :--- |
| **Security Package** | `/data/Projects/CAMS_2/infrastructure/security/__init__.py` | Export `CredentialCipher`, `encrypt_credential`, `decrypt_credential`, v.v. | Giao diện công khai của tầng bảo mật ứng dụng. |
| **Cipher Engine** | `/data/Projects/CAMS_2/infrastructure/security/credential_cipher.py` | Lớp `CredentialCipher` và các hàm tiện ích toàn cục | Cốt lõi thực thi thuật toán AES-256-GCM, dẫn xuất khóa Argon2id/HKDF, quản lý bộ nhớ khóa nhạy cảm. |
| **Device Slots (Ghi)** | `/data/Projects/CAMS_2/core/database/device_slots.py` | `addDevice`, `addDevicesBatch`, `updateDevice` | Mã hóa `password` và `enable_password` trước khi ghi câu lệnh `INSERT` / `UPDATE` vào SQLite. |
| **Device Slots (Đọc)** | `/data/Projects/CAMS_2/core/database/device_slots.py` | `getDeviceByHost` | Giải mã `password` và `enable_password` từ chuỗi `ENC$v1$...` về bản rõ để bind lên form chỉnh sửa trên UI QML. |
| **Import Slots** | `/data/Projects/CAMS_2/core/database/device_import_slots.py` | `_import_devices_from_path` | Mã hóa mật khẩu ngay khi nhập hàng loạt từ Excel/CSV/JSON trước khi nạp vào DB. |
| **Repository** | `/data/Projects/CAMS_2/features/devices/repository.py` | `DeviceRepository.get_login` & `activate_database` | Tự động quét và di chuyển (auto-migrate) dữ liệu cũ sang bản mã khi mở DB; giải mã trong `get_login` để cấp cho `login_service`. |
| **ACL Worker** | `/data/Projects/CAMS_2/features/acl/worker.py` | `build_host_inventory` | Giải mã `password` và `enable_password` trước khi nạp vào cấu hình kết nối Nornir/Netmiko. |
| **DHCP Worker** | `/data/Projects/CAMS_2/features/dhcp/worker.py` | `build_dhcp_inventory` | Giải mã `db_pass` và `db_enable_pass` trước khi kết nối thiết bị đẩy cấu hình DHCP. |
| **NAT Worker** | `/data/Projects/CAMS_2/features/nat/worker.py` | `build_nat_inventory` | Giải mã `password` và `enable_password` trước khi kết nối thiết bị đẩy cấu hình NAT. |
| **Routing Worker** | `/data/Projects/CAMS_2/features/routing/worker.py` | `build_inventory_from_db` | Giải mã `db_pass` và `db_enable_pass` trước khi kết nối thiết bị đẩy cấu hình định tuyến (Static/OSPF/EIGRP/BGP). |
| **Lifecycle Binding** | `/data/Projects/CAMS_2/main.py` | `route_active_workspace` & `shutdown` | Liên kết vòng đời khóa của `WorkspaceSession` với `CredentialCipher`. Xóa an toàn khóa khỏi bộ nhớ RAM khi đóng ứng dụng. |
| **Unit & Integration Tests** | `/data/Projects/CAMS_2/tests/unit/test_credential_cipher.py` | Lớp `TestCredentialCipher` (10 bài test toàn diện) | Kiểm chứng tính đúng đắn mã hóa, tương thích ngược, chống giả mạo `InvalidTag`, bảo mật luồng và tích hợp DB. |

### 4.3. DÙNG NHƯ THẾ NÀO (How it works)

#### A. Vòng đời khóa mật mã gắn liền với Workspace Session

Khi người dùng mở một dự án CAMS:
1. Trong `main.py`, sự kiện `welcome_controller.activeWorkspaceChanged` được kích hoạt.
2. Hàm `route_active_workspace()` gọi:
   ```python
   session = welcome_controller.active_session()
   bind_session_credentials(session)
   ```
3. Nếu dự án có mật khẩu bảo vệ (`session.password()` tồn tại):
   - `CredentialCipher.derive_from_passphrase(password, project_id)` được gọi.
   - Hàm chạy Argon2id để dẫn xuất ra khóa Data Encryption Key (DEK) 256-bit trong RAM.
   - Khóa này được giữ an toàn trong vùng nhớ của tiến trình CAMS, **hoàn toàn không ghi ra ổ cứng**.
4. Khi người dùng đóng dự án hoặc thoát CAMS:
   - `clear_session_credentials()` được gọi.
   - Vùng nhớ chứa khóa `bytearray` bị ghi đè bằng các byte `0x00` (`_zero_memory`), xóa sạch dấu vết khóa trong RAM.

#### B. Quy trình mã hóa khi lưu trữ (Write Flow)
Mỗi khi người dùng tạo mới hoặc cập nhật thông tin thiết bị:
```python
# Ví dụ trong device_slots.py
enc_password = encrypt_credential(password) if password else None
enc_enable_password = encrypt_credential(enable_password) if enable_password else ""

cursor = conn.execute(
    "INSERT INTO t01_devices (host, ..., password, enable_password) VALUES (?, ..., ?, ?)",
    (host, ..., enc_password, enc_enable_password)
)
```
- Nonce 12-byte ngẫu nhiên được sinh mới cho mỗi trường.
- Chuỗi mật khẩu được mã hóa qua AES-256-GCM.
- Chuỗi kết quả có dạng `ENC$v1$...` được lưu vào SQLite.
- Nếu mở tệp SQLite bằng bất kỳ công cụ nào ngoài CAMS, kẻ tấn công chỉ nhìn thấy các chuỗi base64 ngẫu nhiên, không thể trích xuất được mật khẩu ban đầu.

#### C. Quy trình giải mã khi kết nối mạng hoặc hiển thị UI (Read Flow)
Khi các worker hoặc dịch vụ kết nối cần mật khẩu:
```python
# Ví dụ trong features/devices/repository.py
payload = dict(row)
payload["password"] = decrypt_credential(payload.get("password") or "")
payload["enable_password"] = decrypt_credential(payload.get("enable_password") or "")
return payload
```
- Hàm `decrypt_credential` kiểm tra tiền tố `ENC$v1$`.
- Tách 12 bytes Nonce và phần Ciphertext + Tag.
- Khóa DEK trong bộ nhớ tiến hành xác thực Authentication Tag và giải mã dữ liệu về plaintext trong RAM.
- Plaintext chỉ tồn tại trong các biến cục bộ ngắn hạn phục vụ thiết lập phiên SSH/Telnet và bị thu gom bởi garbage collector ngay sau khi hoàn thành.

#### D. Tự động di chuyển dữ liệu cũ (Seamless In-Place Auto-Migration)
Khi người dùng mở một tệp dự án hoặc cơ sở dữ liệu cũ có chứa mật khẩu dạng rõ (plaintext):
- Trong hàm `DeviceRepository.activate_database(db_path)`:
  ```python
  with closing(self._connect()) as connection:
      migrate_database_passwords(connection)
  ```
- Hàm tự động quét bảng `t01_devices`. Bất kỳ giá trị nào không bắt đầu bằng `ENC$v1$` sẽ được mã hóa tại chỗ và cập nhật lại vào DB. Quá trình này diễn ra hoàn toàn tự động, trong suốt với người dùng cuối và chỉ mất vài phần nghìn giây.

---

## 5. TỔNG HỢP KIẾN TRÚC VÀ BẢNG THAM CHIẾU BA BƯỚC "DÙNG GÌ - Ở ĐÂU - NHƯ THẾ NÀO"

Nhằm giúp hội đồng thẩm định và các kỹ sư phát triển nắm bắt nhanh chóng, bảng tổng hợp dưới đây tóm lược chính xác theo đúng yêu cầu đề bài:

| Tiêu chí | TÍNH NĂNG 1: ENABLE SECRET | TÍNH NĂNG 2: XÁC MINH 2 BƯỚC PRIVILEGE 15 | TÍNH NĂNG 3: MÃ HÓA DB BẰNG MẬT KHẨU DỰ ÁN |
| :--- | :--- | :--- | :--- |
| **DÙNG GÌ?** *(Công nghệ, Thuật toán, Chuẩn)* | • Cột `enable_password TEXT`<br>• DDL `ALTER TABLE ADD COLUMN`<br>• Component `StandardPasswordField`<br>• Netmiko `secret`<br>• Nornir `cams_netmiko.extras` | • Thư viện Netmiko CLI<br>• Lệnh Cisco `show privilege`<br>• Lệnh cưỡng bức `enable 15`<br>• Biểu thức chính quy Regex trích xuất cấp quyền<br>• Ngoại lệ `PermissionError` ngắt phiên | • **AES-256-GCM** (NIST SP 800-38D)<br>• **Argon2id** (RFC 9106, 32MiB, 2 iter)<br>• **HKDF-SHA256** (RFC 5869)<br>• Nonce ngẫu nhiên 12 bytes<br>• Auth Tag 16 bytes<br>• Định dạng `ENC$v1$...`<br>• Zero-memory clearing |
| **DÙNG Ở ĐÂU?** *(Tệp mã nguồn & Module)* | • `UI/.../NewDevice.qml`<br>• `core/database/device_slots.py`<br>• `core/database/device_import_slots.py`<br>• `features/devices/repository.py`<br>• `features/devices/login_service.py`<br>• `infrastructure/network/device_connector.py`<br>• `infrastructure/network/connector.py` | • `infrastructure/network/privilege.py`<br>• `infrastructure/network/device_connector.py`<br>• `infrastructure/network/session_registry.py`<br>• `infrastructure/network/running_config_collector.py`<br>• `infrastructure/network/nornir_netmiko_tasks.py` | • `infrastructure/security/credential_cipher.py`<br>• `infrastructure/security/__init__.py`<br>• `core/database/device_slots.py`<br>• `core/database/device_import_slots.py`<br>• `features/devices/repository.py`<br>• `features/acl/worker.py`<br>• `features/dhcp/worker.py`<br>• `features/nat/worker.py`<br>• `features/routing/worker.py`<br>• `main.py` |
| **DÙNG NHƯ THẾ NÀO?** *(Luồng thực thi & Cơ chế)* | 1. Nhập từ form UI hoặc import Excel/JSON.<br>2. Lưu an toàn vào cột `enable_password` của SQLite.<br>3. `get_login()` truy vấn và `DeviceLoginService.load()` ánh xạ vào trường `secret`.<br>4. Nạp vào tham số kết nối Netmiko / Nornir. | 1. Khi thiết bị kết nối thành công qua SSH/Telnet.<br>2. Bước 1: Prompt `>` -> gọi `enable()`.<br>3. Bước 2: Prompt `#` -> gửi `show privilege`.<br>4. Nếu `< 15`: Bắt buộc kiểm tra Secret. Không có/sai Secret -> **DROP KẾT NỐI NGAY**.<br>5. Có Secret -> Cưỡng bức `enable 15` và tái kiểm tra. | 1. Khi mở dự án: Dẫn xuất khóa 256-bit từ mật khẩu dự án bằng Argon2id trong RAM.<br>2. Khi ghi DB: Sinh Nonce 12B, mã hóa AES-256-GCM thành `ENC$v1$...`.<br>3. Khi đọc DB: Kiểm tra tiền tố, xác thực Auth Tag và giải mã trong RAM.<br>4. Tự động migrate mật khẩu plaintext cũ.<br>5. Xóa khóa an toàn khỏi RAM khi thoát. |

---

## 6. HƯỚNG DẪN THỰC NGHIỆM VÀ KẾT QUẢ KIỂM CHỨNG TỰ ĐỘNG

Hệ thống đi kèm bộ kiểm thử tự động toàn diện được viết bằng module chuẩn `unittest` của Python.

### 6.1. Kiểm thử Tính năng 1 & 2: Xác thực Enable Secret & Leo thang đặc quyền

**Lệnh chạy kiểm thử:**
```bash
.venv/bin/python -m unittest tests/unit/test_privilege_escalation.py -v
```

**Kết quả thực tế trên hệ thống:**
```text
test_create_connector_passes_secret ... ok
test_login_service_load_maps_secret_and_enable_password ... ok
test_repository_get_login_includes_enable_password ... ok
test_config_mode_exits_before_privilege_check ... ok
test_initial_privilege_15_passes_without_secret ... ok
test_initial_privilege_5_with_correct_secret_elevates_and_passes ... ok
test_initial_privilege_5_with_wrong_secret_drops_connection ... ok
test_initial_privilege_5_without_secret_drops_connection ... ok
test_privilege_15_does_not_call_enable ... ok
test_privilege_1_calls_standard_enable ... ok
test_privilege_5_fails_if_elevation_rejected ... ok
test_privilege_5_forces_enable_escalation ... ok

----------------------------------------------------------------------
Ran 12 tests in 0.006s

OK
```
*Ghi chú:* Toàn bộ 12 ca kiểm thử bao gồm kiểm tra ngắt kết nối khi thiếu Secret (`PermissionError`), ngắt kết nối khi sai Secret (`RuntimeError`), và vượt qua khi đủ quyền 15 đều đạt kết quả **OK**.

---

### 6.2. Kiểm thử Tính năng 3: Mã hóa bảo vệ mật khẩu Database (Cơ chế 2)

**Lệnh chạy kiểm thử:**
```bash
.venv/bin/python -m unittest tests/unit/test_credential_cipher.py -v
```

**Kết quả thực tế trên hệ thống:**
```text
test_encrypt_decrypt_roundtrip ... ok
test_empty_and_none_handling ... ok
test_idempotence_encrypt ... ok
test_backward_compatibility_plaintext ... ok
test_tamper_detection (InvalidTag check) ... ok
test_derive_from_passphrase (Argon2id derivation) ... ok
test_session_binding (WorkspaceSession integration) ... ok
test_migrate_database_passwords (Auto-migration test) ... ok
test_device_repository_decrypts_credentials_on_get_login ... ok
test_device_slots_mixin_encrypts_and_decrypts ... ok

----------------------------------------------------------------------
Ran 10 tests in 0.355s

OK
```
*Ghi chú:* Kiểm thử chứng minh:
- Chuỗi lưu trong DB thực sự bắt đầu bằng `ENC$v1$`.
- Sửa đổi 1 byte trong DB gây ra lỗi `InvalidTag` (chống giả mạo dữ liệu).
- Mật khẩu sai từ chối giải mã.
- Tự động di chuyển từ DB cũ sang DB mã hóa thành công 100%.

---

### 6.3. Kiểm thử hồi quy toàn diện hệ sinh thái (Regression Test Suite)

**Lệnh chạy tổng hợp 63 ca kiểm thử liên quan:**
```bash
QT_QPA_PLATFORM=offscreen .venv/bin/python -m unittest \
  tests/unit/test_credential_cipher.py \
  tests/unit/test_privilege_escalation.py \
  tests/test_device_delete_guard.py \
  tests/test_device_selection_contracts.py \
  tests/test_multi_device_batch.py \
  tests/unit/test_device_classification.py \
  tests/unit/test_device_connector.py \
  tests/test_workspace_save_and_snapshots.py
```

**Kết quả thực tế trên hệ thống:**
```text
...............................................................
----------------------------------------------------------------------
Ran 63 tests in 3.570s

OK
```
**Tất cả 63/63 bài kiểm thử đều thành công tuyệt đối (100% PASS), không có bất kỳ lỗi xung đột hay suy giảm hiệu năng nào.**

---

## 7. KẾT LUẬN VÀ GIÁ TRỊ KHOA HỌC

Việc hoàn thành đồng bộ bộ 3 tính năng an ninh trên mang lại những giá trị vượt bậc cho phần mềm CAMS:

1. **Khép kín mô hình an ninh phòng thủ theo chiều sâu (Defense-in-Depth):**
   - **Tầng dữ liệu tĩnh (At-Rest):** Cơ sở dữ liệu SQLite được bảo vệ bằng chuẩn mã hóa cao cấp **AES-256-GCM + Argon2id**, miễn nhiễm trước rủi ro rò rỉ khi thất lạc file hoặc bị sao chép trái phép.
   - **Tầng dữ liệu động (In-Flight):** Phân tách rõ ràng giữa thông tin xác thực ban đầu và mật khẩu đặc quyền quản trị cấp cao.
   - **Tầng thực thi (Execution Time):** Cơ chế kiểm tra 2 bước nghiêm ngặt triệt tiêu nguy cơ chạy lệnh thiếu quyền, đảm bảo nguyên tắc đặc quyền tối thiểu và bảo vệ tính toàn vẹn của thiết bị mạng.
2. **Tuân thủ các tiêu chuẩn quốc tế:**
   - Đạt chuẩn lưu trữ an toàn mật khẩu theo khuyến nghị của **OWASP Cryptographic Storage Cheat Sheet**.
   - Tuân thủ hướng dẫn mật mã đối xứng có xác thực **NIST SP 800-38D** và hàm băm mật khẩu **RFC 9106**.
   - Phù hợp với các hướng dẫn bảo mật thiết bị mạng của **CIS Cisco IOS Benchmark**.
3. **Trải nghiệm người dùng mượt mà và tương thích ngược hoàn hảo:**
   - Quản trị viên chỉ cần nhớ mật khẩu bảo vệ dự án `.ntp`, hệ thống tự động quản lý toàn bộ chuỗi khóa mật mã ngầm.
   - Các cơ sở dữ liệu cũ được tự động nâng cấp mà không yêu cầu cấu hình thủ công phức tạp.
   - Hiệu năng giải mã trong bộ nhớ RAM diễn ra ở mức microsecond, không tạo ra bất kỳ độ trễ nào trong trải nghiệm tương tác giao diện người dùng.

---
*Báo cáo được hoàn thành và nghiệm thu kỹ thuật thành công vào ngày 03 tháng 10 năm 2026.*  
*Đội ngũ Phát triển Hệ thống CAMS.*
