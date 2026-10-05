# Lab DAI permit/deny và DHCP Snooping trên vIOS L2 / EVE-NG

Ngày cập nhật: 04/10/2026. Mã CAMS đã có tùy chọn logging và nhãn outcome;
khả năng phát message phải kiểm chứng trên đúng image vIOS L2. Các địa chỉ,
VLAN và cổng bên dưới là ví dụ, thay theo topology. Chưa có kết quả thực nghiệm
thiết bị cho lab này; không dùng fixture test làm ảnh bằng chứng switch thật.

## Chuẩn bị

Topology nhỏ trong VLAN 10:

```text
R1: DHCP/gateway hợp lệ ── Gi0/0 SW1 (trusted DHCP + ARP)
Linux client           ── Gi0/1 SW1 (untrusted)
R2: DHCP thử nghiệm    ── Gi0/2 SW1 (untrusted)

SW1 ── đường quản trị có IP/route tới máy chạy listener CAMS
```

R1 và R2 có thể dùng chức năng DHCP Server hiện có trong CAMS. Cổng client/server
thử nghiệm cùng VLAN 10. Trust chỉ đường đi server hợp lệ. Không dùng Static MAC
forwarding của CAMS để thay thế DHCP Snooping binding: hai bảng có mục đích khác nhau.

1. Khởi động listener CAMS trong tính năng Syslog. Cổng mặc định 5514; bind IP
   phải nhận được từ mạng EVE-NG. Máy/switch phải có đường IP tới nhau.
2. SW1 → **Syslog Server**: thêm IP CAMS, port/transport khớp listener,
   source-interface có IP quản trị, severity **Informational (6)**, timestamp
   và sequence. View & Push cấu hình destination. Severity là ngưỡng chung IOS.
3. SW1 → **Layer 2 Security → VLAN Protection**: chọn VLAN 10, bật DHCP
   Snooping và DAI, chọn **DAI logging → Permit and deny (report)**, Save Policy.
4. Trong **Trusted Uplinks**, trust DHCP + ARP cho đường đi R1. Gi0/1/Gi0/2
   giữ untrusted. View & Push policy và đọc kết quả từng task.
5. Kiểm tra `show version`, `show logging`, `show ip dhcp snooping`,
   `show ip arp inspection`. Nếu image từ chối lệnh, giữ output lỗi để xác định
   khả năng; không coi task thất bại là đã cấu hình logging.

Preview DAI cho chế độ báo cáo phải có:

```cisco
ip arp inspection vlan 10
no ip arp inspection vlan 10 logging acl-match
ip arp inspection vlan 10 logging dhcp-bindings all
ip arp inspection log-buffer entries 128
ip arp inspection log-buffer logs 10 interval 1
```

`all` điều khiển log khi kiểm tra DHCP binding; ARP ACL logging là policy riêng.
Buffer có thể gộp log/giới hạn tốc độ. Informational nhận cả mức 0–6, không cần
bật debug để thu các message native này.
[Cisco DAI commands](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipaddr/command/ipaddr-xe-3se-3850-cr-book/ipaddr-xe-3se-3850-cr-book_chapter_01.html).

## Ca 1: ARP hợp lệ

Cho client nhận DHCP từ R1. Ví dụ client nhận `192.0.2.10/24`, gateway
`192.0.2.1`. Kiểm tra trên SW1:

```cisco
show ip dhcp snooping binding
show ip arp inspection statistics vlan 10
```

Binding phải có IP/MAC client, VLAN 10 và cổng client. Từ client phát ARP mới
cho gateway bằng `arping` hoặc xóa ARP cache client rồi ping. Gói phải đi vào
SW1 qua cổng untrusted để DAI kiểm tra.

Ví dụ trên Linux client (thay tên interface thật):

```bash
ip -br addr
sudo arping -c 5 -I eth0 192.0.2.1
```

Nếu client không nhận DHCP vì server không xử lý Option 82 được switch thêm,
kiểm tra log/cấu hình server. Trong lab có thể chọn Global Settings → Option 82
→ Disable rồi Save/View & Push, hoặc cấu hình server xử lý Option 82 phù hợp;
không thay đổi tùy chọn này khi chưa xác định nguyên nhân.

Trong CAMS lọc `security:dai mnemonic:PERMIT`. Nếu image xuất message permit,
kỳ vọng có mnemonic `DHCP_SNOOPING_PERMIT`, outcome **Permitted**. Permit được
lưu/hiển thị nhưng không tạo cảnh báo ARP spoofing theo ngưỡng.

Chụp binding, kết quả kết nối và log permit thật. Nếu counters permitted tăng
nhưng không có syslog permit, ghi nhận giới hạn image; không thay bằng log giả.

## Ca 2: ARP sai binding

Trong mạng lab, đổi IP của chính client sang địa chỉ chưa sử dụng trong cùng
subnet, ví dụ `192.0.2.99/24`, khi binding vẫn ghi `192.0.2.10`. Không chọn IP
gateway hoặc IP của thiết bị khác. Phát ARP mới cho gateway như ca 1.

Trên SW1 kiểm tra:

```cisco
show ip arp inspection statistics vlan 10
show ip arp inspection log
show logging
```

Trong CAMS lọc `security:dai mnemonic:DENY`. Kỳ vọng message native như
`SW_DAI / DHCP_SNOOPING_DENY`, outcome **Denied**, thông tin IP/MAC/port/VLAN
tùy image. Log tổng hợp có số invalid ARP; CAMS đọc số đó để đếm packet. Với
ít nhất 5 invalid packet hoặc 5 log deny trong 60 giây có thể tạo cảnh báo CAMS,
có cooldown 300 giây. Chỉ phát một lượng nhỏ ARP, không cần flood.

Chụp bộ đếm trước/sau, log deny và dialog raw message; thêm ảnh Security Alert
nếu ngưỡng đạt. Trả client về DHCP hợp lệ sau ca thử.

## Ca 3: DHCP server trên cổng untrusted

Để cô lập nguyên nhân, tắt DAI cho VLAN thử nghiệm trong ca DHCP rồi Save/View
& Push; giữ Snooping và DHCP trust của R1. Bật DHCP server thử nghiệm R2 ở Gi0/2
untrusted. Cho client yêu cầu DHCP mới và capture link R2–SW1 trong EVE-NG để
chứng minh DHCPOFFER/ACK từ R2 đã đi đến switch.

```cisco
show ip dhcp snooping
show ip dhcp snooping statistics
show ip dhcp snooping binding
show logging
```

Trong CAMS lọc `security:dhcp_snooping`. Native message điển hình là
`DHCP_SNOOPING_UNTRUSTED_PORT`, chứa loại DHCP message và MAC nguồn; một số
image không kèm cổng/VLAN. CAMS gắn **Denied**; 3 log server drop cùng nguồn
trong 60 giây có thể tạo **DHCP_ROGUE_SERVER**. Native log vẫn xuất hiện ngay
khi nhận, không phải đợi đủ ngưỡng cảnh báo.

Chụp cấu hình trust, offer của R2 trên link capture, statistics/log vi phạm và
binding hoặc lease client nhận từ R1. Không coi log DHCP cấp IP trên R1 là log
vi phạm Snooping trên SW1.
[Cisco ví dụ native DHCP/DAI logs](https://www.cisco.com/c/en/us/support/docs/switches/lan-switch-software/222274-troubleshoot-dynamic-arp-inspection-dai.html).

## Khi không thấy log trên CAMS

- **Switch có log trong `show logging`, CAMS không có:** kiểm tra destination,
  source-interface/route, listener, firewall, severity và transport; tạm bỏ
  bộ lọc CAMS để kiểm tra raw log. Counter tăng chưa chứng minh switch đã gửi syslog.
- **Switch chặn packet, counters tăng nhưng `show logging` không có:** xác minh
  per-VLAN logging, trust và buffer; thử lượng nhỏ packet, chờ ít nhất một chu kỳ
  log-buffer. Nếu vẫn thiếu thì ghi rõ phiên bản image và message/counter thực tế.
- **Chỉ thấy debug trong lab:** có thể khảo sát debug Snooping tạm thời trên
  đúng image rồi tắt bằng `undebug all`. CAMS hiện không tự cài EEM/debug, không
  tự chuyển raw debug thành log vi phạm native. EEM/polling bổ sung cần bước riêng
  sau khi xác định nguồn quan sát. Tránh bật debug thường trực.
- **Cổng bị err-disable:** kiểm tra nguyên nhân thực tế; rate-limit là một ca
  khác với ARP sai binding hoặc rogue DHCP, không trộn bằng chứng giữa các ca.

Cisco liệt kê DAI/Snooping trong IOSvL2 nhưng không bảo đảm message trên mọi
image EVE-NG. IOSvL2 không hỗ trợ SPAN theo guide; dùng capture link EVE-NG.
[Cisco IOSvL2](https://developer.cisco.com/docs/modeling-labs/iosvl2/).

## Bộ ảnh và dữ liệu báo cáo

1. Topology + `show version` + cấu hình destination.
2. Policy VLAN 10 với **Permit and deny**, preview/push thành công.
3. Binding hợp lệ + log **Permitted** nếu image hỗ trợ.
4. Bộ đếm drop tăng + log **Denied** + raw message chỉ IP/MAC/port/VLAN có thật.
5. Ca rogue DHCP + trust + log/drop counters + lease hợp lệ.
6. **Export Excel** sau khi lọc host/thời gian, giữ raw message, Security feature
   và Outcome. Excel chứa đúng tập log đang hiển thị.

Sau lab đổi DAI logging về **Deny only (default)** nếu không cần ghi permit,
Save/View & Push; tắt DHCP server thử nghiệm và phục hồi policy DAI mong muốn.
