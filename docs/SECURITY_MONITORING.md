# Giám sát an ninh mạng bằng Syslog

Cấu hình **Syslog Server riêng cho từng thiết bị**. View & Push của ACL,
DHCP Snooping, DAI và Port Security chỉ áp dụng chính sách an ninh; không tự
thêm destination Syslog hay khởi động listener.

## Thiết lập

1. Trong Settings → System Logs, chọn địa chỉ bind, cổng và transport của
   listener CAMS, rồi khởi động listener ở tính năng Syslog.
2. Trong tab **Syslog Server** của từng router/switch, thêm IP máy CAMS mà
   thiết bị truy cập được; chọn cổng/transport khớp listener và source-interface.
   Dùng **Informational (6)** hoặc Debugging (7) để nhận ACL severity 6 và các
   sự kiện mức 0–5. Mức trap là ngưỡng chung trên thiết bị IOS, không độc lập
   theo từng destination; cấu hình nhiều destination cần dùng cùng ngưỡng.
3. View & Push để xem lệnh, áp dụng và kiểm tra cấu hình trên thiết bị.
   Cấu hình Syslog có `logging on` để bật lại việc gửi log nếu trước đó bị tắt.
4. Áp dụng chính sách an ninh và tạo tình huống kiểm thử trong lab. Trong
   Syslog, chọn **Security events → All security events** hoặc từng nghiệp vụ;
   kết hợp host, severity, thời gian và transport khi cần.

Log gốc được lưu vào `info_collected.db.t12_syslog_messages`, giữ nguyên
message, severity, IP nguồn và raw message. Nhãn an ninh được tính khi đọc,
áp dụng cho cả dữ liệu cũ lẫn log mới. IP nguồn của interface L3 hoặc SVI
được ánh xạ về host thiết bị trong inventory; IP chưa biết vẫn giữ nguyên.

## Nguồn sự kiện

| Nghiệp vụ | Cách phát log / nhận diện |
| --- | --- |
| IP ACL | Rule standard/extended/dynamic hỗ trợ có `log`; rule cuối `2147483647 deny any log` hoặc `deny ip any any log` ghi nhận implicit deny. Sequence này dành cho CAMS. Facility `SEC`, mnemonic `IPACCESSLOG*` / `ACCESSLOG*`. |
| DHCP Snooping | IOS tự phát log cho các vi phạm được hỗ trợ, như server message trên cổng untrusted, MAC mismatch hoặc rate limit; facility `DHCP_SNOOPING`. Không bật debug DHCP trong production. |
| DAI | Chọn DAI logging theo VLAN: Deny only, Permit and deny (report), Permit only hoặc Disabled. CAMS giữ lựa chọn khi lưu/push/pull, cấu hình log-buffer 128 entries/10 log mỗi giây. ARP ACL logging vẫn dùng mặc định deny; facility `SW_DAI`. |
| Port Security | Chọn `restrict` hoặc `shutdown`. `protect` drop im lặng, không có Syslog nên CAMS chặn lưu/push policy đang bật chế độ này và yêu cầu chọn rõ chế độ khác. Facility `PORT_SECURITY` hoặc `PM` với `psecure`. |
| Xác thực | Nhận các sự kiện `SEC_LOGIN`, `AAA`, `AUTHMGR`, `DOT1X`, `MAB`, `SSH` mà thiết bị phát. Bộ lọc không tự bật các cơ chế xác thực. |
| Bảo vệ STP | Nhận `SPANTREE` với các mnemonic BLOCK, ROOTGUARD, LOOPGUARD, BPDU. |

Smart Filter hỗ trợ `security:all`, `security:acl`, `security:dhcp_snooping`,
`security:port_security`, `security:dai`, `security:authentication`,
`security:stp_guard`, `security:security_alert`.

CAMS cũng giữ bộ phát hiện theo ngưỡng cho ACL deny flood, rogue DHCP,
DHCP drop lặp lại, ARP invalid lặp lại và Port Security violation lặp lại.
Các cảnh báo `%CAMS-...` được lưu và hiển thị với nhãn **Security Alert**;
đây là dấu hiệu cần điều tra, không phải kết luận chắc chắn có tấn công.

Outcome Permitted/Denied/Violation/Recovered/Operational được tính từ log gốc
và hiển thị trên bảng, dialog chi tiết, Excel (cột Security feature và Outcome).
DAI permit và DHCP database operation không tăng bộ đếm vi phạm. DAI đạt ngưỡng
khi có ít nhất 5 packet invalid hoặc 5 log deny trong 60 giây; log tổng hợp
dùng số packet có trong message, không coi một dòng là một packet. Các log
PM err-disable/recovery được gắn nhóm theo `arp-inspection`, `dhcp-rate-limit`,
`bpduguard`/`rootguard`/`loopguard` hoặc `psecure`. Recovery không tăng bộ đếm.

Để làm báo cáo trên EVE-NG, xem [kịch bản lab vIOS L2](L2_SECURITY_SYSLOG_LAB.md).
Smart Filter `security:dai mnemonic:PERMIT` và `security:dai mnemonic:DENY`
giúp chụp/export từng trường hợp. Không tạo log DHCP permit giả để mô phỏng
hành vi của ACL; dùng binding và kiểm chứng DHCP thành công làm bằng chứng hợp lệ.

## Giới hạn và kiểm chứng trên thiết bị

IOS có thể gộp/rate-limit log; không bảo đảm một log cho mỗi packet. MAC ACL
và rule reflexive `reflect` / `evaluate` không hỗ trợ `log` theo cùng cú pháp,
nên CAMS không thêm lệnh không hợp lệ. Rule deny cuối vẫn ghi nhận lưu lượng
không khớp của IP ACL. Khả năng phát log phụ thuộc model/phiên bản IOS và
cấu hình thực tế; kiểm tra View & Push và tình huống vi phạm trên thiết bị.

Nguồn Cisco: [ACL logging](https://sec.cloudapps.cisco.com/security/center/resources/access_control_list_logging.html),
[DHCP Snooping](https://www.cisco.com/c/en/us/support/docs/ip/dynamic-host-configuration-protocol-dhcp-dhcpv6/217055-operate-and-troubleshoot-dhcp-snooping.html),
[DAI commands](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipaddr/command/ipaddr-xe-3se-3850-cr-book/ipaddr-xe-3se-3850-cr-book_chapter_01.html),
[Port Security](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9500/software/release/16-8/configuration_guide/sec/b_168_sec_9500_cg_chapter_0101011.pdf).
