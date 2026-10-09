# Checklist quay video CAMS — 4 lab

Dùng để mở bên cạnh màn hình rồi làm theo từng bước. Đây là kịch bản quay, không phải lời thuyết trình. Quay riêng từng lab; mỗi lab có thể chia thành vài đoạn. Thời lượng 100/65/55/65 giây là mục tiêu cho bản cắt trình chiếu, không phải thời gian thực hiện thực tế.

Thứ tự theo PPTX: Lab 1 DHCP Snooping + DAI; Lab 2 OSPF; Lab 3 Syslog + email (kịch bản 4 trong báo cáo); Lab 4 ACL (kịch bản 5 trong báo cáo).

## Chuẩn bị chung — làm trước khi bấm Record

1. Mở sẵn topology EVE-NG, CAMS và terminal của những thiết bị cần kiểm tra. Đóng cửa sổ phụ, tăng cỡ chữ.
2. Lưu cấu hình/snapshot hiện tại để có trạng thái phục hồi. Chỉ sửa cổng nghiệp vụ; giữ kết nối quản trị CAMS.
3. Chạy thử kịch bản một lần. Không cần quay lại phần tạo lab, đặt IP, VLAN, SSH và NAT nền.
4. Khi CAMS báo SYNC nhưng thiết bị chưa thay đổi, kiểm tra lại View & Push và lệnh show. Save chỉ lưu dữ liệu mong muốn.
5. Mỗi màn hình nhập liệu, preview và kết quả: giữ yên 2–3 giây. Với terminal, chờ lệnh kết thúc rồi giữ thêm 3 giây.
6. Nếu cấu hình đã có sẵn, chọn bản ghi và mở phần sửa để quay thao tác. Không tạo thêm bản ghi trùng. Chỉ nói “triển khai mới” nếu đã quay từ trạng thái chưa có cấu hình đó.
7. Quay nguyên bản trước, cắt đoạn chờ sau. Bộ đếm và địa chỉ DHCP có thể khác ảnh cũ: giữ kết quả mới thực tế, không ép về .4, .5 hoặc đúng 9 gói.

## LAB 1 — DHCP Snooping + DAI

### Chuẩn bị ngoài video

R1 nối SW1 Gi0/1, R2 nối SW1 Gi0/2, FAKE_DHCP nối SW1 Gi0/3. Ba cổng dữ liệu ở VLAN 10. R1 cấp 192.168.10.0/24, gateway 192.168.10.1; FAKE_DHCP cấp 192.168.66.0/24. Gi0/2 của R2 là cổng nhận DHCP.

DAI tắt trong phần so sánh DHCP. Gi0/2 của SW1 luôn không tin cậy. Tắt Option 82 theo cấu hình lab hiện tại. Chuẩn bị Syslog của SW1 tới bộ nhận CAMS và Start Listener trước phần DAI.

### Đoạn 1A — DHCP từ máy chủ hợp lệ

1. Bắt đầu Record. Hiện topology khoảng 3 giây.
2. CAMS → chọn **SW1** → mở **Layer 2 Security** → **VLAN Protection**.
3. Chọn **VLAN 10** → bật **Enable DHCP Snooping** → để **Enable DAI** tắt → **Save Policy**.
4. **Trusted Uplinks** → chọn **GigabitEthernet0/1** → tick **Trust DHCP Snooping**, chưa tick **Trust ARP Inspection** → **Add Trust Port**. Nếu đã có dòng Gi0/1 thì kiểm tra bản ghi hiện có; không thêm trùng.
5. Kiểm tra Gi0/2 và Gi0/3 không có DHCP trust.
6. **View & Push** → giữ preview 3 giây → **Push** → đợi kết quả thực thi.
7. R2 terminal: yêu cầu nhận DHCP lại nếu đang giữ lease cũ. Có thể dùng chuỗi cấu hình dưới đây trên console R2; đây là thao tác máy khách để kiểm thử, còn chính sách switch được triển khai qua CAMS:

```text
configure terminal
interface GigabitEthernet0/2
 shutdown
 no ip address
 ip address dhcp
 no shutdown
end
```

8. Chờ cấp IP rồi chạy:

```text
show ip interface brief | include GigabitEthernet0/2
```

9. Giữ kết quả: IP thuộc **192.168.10.0/24**, phương thức DHCP, cổng up/up. Địa chỉ cuối không nhất thiết là .4.
10. SW1 terminal:

```text
show ip dhcp snooping
show ip dhcp snooping binding
```

11. Giữ hình VLAN 10 hoạt động, Gi0/1 trusted, binding R2 nằm ở Gi0/2.

### Đoạn 1B — đổi cổng tin cậy, đổi nguồn DHCP

1. CAMS → SW1 → **Trusted Uplinks** → bỏ DHCP trust của **Gi0/1**. Nếu giao diện chỉ có nút xóa dòng trust, xóa dòng đó rồi kiểm tra preview có lệnh gỡ trust.
2. Chọn **Gi0/3** → tick **Trust DHCP Snooping** → **Add Trust Port**.
3. DAI vẫn tắt, Gi0/2 vẫn không tin cậy.
4. **View & Push → Push**.
5. R2: làm lại chuỗi yêu cầu DHCP ở đoạn 1A → chạy `show ip interface brief | include GigabitEthernet0/2`.
6. Giữ kết quả thuộc **192.168.66.0/24**. Chốt đoạn tại đây.
7. Trước phần DAI: đổi lại Gi0/1 DHCP trusted, bỏ trust Gi0/3, Push, yêu cầu R2 nhận DHCP lại từ R1. Có thể quay bước phục hồi này thành đoạn ngắn riêng.

### Đoạn 1C — thiết lập DAI và cổng tin cậy

1. CAMS → SW1 → **VLAN Protection → VLAN 10**.
2. Giữ **Enable DHCP Snooping** bật → bật **Enable DAI** → **Save Policy**.
3. **Trusted Uplinks** → chọn **Gi0/1** → tick cả **Trust DHCP Snooping** và **Trust ARP Inspection** → **Add Trust Port**. Nếu cần thay dòng Gi0/1 cũ, xóa rồi thêm lại trước khi Push.
4. Giữ hình dòng Gi0/1 có **DHCP + ARP**; Gi0/2 và Gi0/3 không được trust ARP.
5. **View & Push**: quay preview có `ip arp inspection vlan 10` và `ip arp inspection trust` dưới Gi0/1 → **Push**.
6. SW1 terminal:

```text
show ip arp inspection vlan 10
show ip arp inspection interfaces
show ip dhcp snooping binding
show ip arp inspection statistics vlan 10
```

7. Giữ hình: DAI active trên VLAN 10, Gi0/1 trusted, Gi0/2 untrusted, binding IP hiện tại của R2. Ghi nhận bộ đếm ban đầu; không cần bằng 0.
8. R2 terminal:

```text
clear arp-cache
ping 192.168.10.1 source GigabitEthernet0/2
```

9. Giữ kết quả ping hợp lệ. Nếu chưa thành công, xử lý trước khi chuyển bước đổi IP.

### Đoạn 1D — IP không khớp binding bị chặn

1. CAMS → **R2 → Interfaces → Physical → GigabitEthernet0/2**.
2. Nhập IPv4 **192.168.10.250**, mask **255.255.255.0**; cổng không ở trạng thái Administratively down.
3. **Update Interface → View & Push → Push**.
4. R2 terminal:

```text
show ip interface brief | include GigabitEthernet0/2
clear arp-cache
ping 192.168.10.1 source GigabitEthernet0/2
```

5. Giữ IP .250 và kết quả ping bị chặn.
6. SW1 terminal:

```text
show ip arp inspection statistics vlan 10
show logging | include SW_DAI
```

7. Giữ bộ đếm ARP dropped tăng và log có Gi0/2, VLAN 10, IP .250.
8. CAMS → **System Logs** → lọc `SW_DAI`/`192.168.10.250` → mở dòng mới để thấy nội dung. Nếu có cảnh báo tổng hợp `DAI_ARP_SPOOF`, giữ thêm hình đó. Nếu chưa có cảnh báo tổng hợp, giữ log gốc và chờ; không thay bằng log cũ mà gọi là mới.

### Đoạn 1E — phục hồi

1. CAMS → R2 → Physical → Gi0/2 → nhập **dhcp** vào ô IPv4. Biểu mẫu hiện tại hỗ trợ giá trị này và ẩn ô mask.
2. **Update Interface → View & Push → Push** → đợi cấp IP.
3. R2:

```text
show ip interface brief | include GigabitEthernet0/2
clear arp-cache
ping 192.168.10.1 source GigabitEthernet0/2
```

4. SW1: `show ip dhcp snooping binding`.
5. Giữ IP nhận động thuộc .10.0/24, binding mới và ping hoạt động trở lại → Stop Record.

Bản cắt khoảng 100 giây: DHCP trust + hai dải IP → bật DAI → tick ARP trust → ping hợp lệ → .250 bị chặn → bộ đếm/log → phục hồi. Đây là phép thử sai lệch IP–MAC, không gọi là đã thực hiện tấn công MITM.

## LAB 2 — OSPF trên 5 router

### Chuẩn bị ngoài video

Giữ nền IP và switch hiện tại. Báo cáo mới dùng /24 cho cả 10.1.123.0, 10.1.34.0, 10.1.45.0; không dùng /30 trong file kế hoạch cũ. Loopback0 các router lần lượt 1.1.1.1/32 đến 5.5.5.5/32.

Nếu muốn quay triển khai từ đầu: dùng bản sao/snapshot có IP nhưng chưa có OSPF, đồng thời đồng bộ CAMS về trạng thái đó. Nếu dùng lab đang chạy OSPF, quay xem/sửa và Push cấu hình hiện có; ping trước đó đã thành công thì không diễn giải thành thất bại trước OSPF.

### Đoạn 2A — khai báo nhóm và Push

1. Record → topology 3 giây.
2. CAMS → **R1 → Routing → OSPF → Routing Group**.
3. **Hosts**: chọn **R1, R2, R3, R4, R5**; không chọn switch → **Next**.
4. **Identity**: process ID **1** cho cả 5 router; router ID tương ứng **1.1.1.1 → 5.5.5.5** → **Next**.
5. **Networks**: chọn các mạng dưới bảng, area **0**. Bỏ chọn mạng quản trị **192.168.122.0/24**. Giữ hình đủ cả 5 router.

| Router | Mạng quảng bá, đều area 0 |
|---|---|
| R1 | 10.1.123.0/24; 192.168.10.0/24; 1.1.1.1/32 |
| R2 | 10.1.123.0/24; 192.168.20.0/24; 2.2.2.2/32 |
| R3 | 10.1.123.0/24; 10.1.34.0/24; 3.3.3.3/32 |
| R4 | 10.1.34.0/24; 10.1.45.0/24; 4.4.4.4/32 |
| R5 | 10.1.45.0/24; 192.168.50.0/24; 5.5.5.5/32 |

6. **Common**: bật **Passive default** theo cấu hình báo cáo; không bật default originate hoặc authentication mới. Giữ reference bandwidth đồng nhất nếu đã thiết lập.
7. **Save & Push** → xem preview từng router: process 1, router ID, network/wildcard đúng, không quảng bá mạng quản trị → **Push**.
8. Phải mở passive trên các cổng transit. Nếu preview nhóm chưa có các ngoại lệ này: lần lượt vào **Routing → OSPF → Passive iface**, chọn cổng, **bỏ tick Passive → + Add → View & Push → Push**:

| Router | Cổng cần no passive |
|---|---|
| R1 | Gi0/1 |
| R2 | Gi0/1 |
| R3 | Gi0/1, Gi0/2 |
| R4 | Gi0/1, Gi0/2 |
| R5 | Gi0/2 |

Giữ các cổng LAN và Loopback passive. Quay một router đại diện cho bước này, các router còn lại làm tương tự. Nếu đã cấu hình sẵn ngoại lệ thì kiểm tra và giữ nguyên; không bỏ sót bước này khi quay từ baseline.

### Đoạn 2B — kiểm tra cấu hình và liên lạc

1. R1 terminal:

```text
show running-config | section router ospf
show ip ospf neighbor
show ip route ospf
```

2. Giữ láng giềng và tuyến tới **192.168.50.0/24**. Có thể quay thêm R4 `show ip ospf neighbor` để thấy R3/R5.
3. VPC8 terminal:

```text
show ip
ping 192.168.20.10
ping 192.168.50.10
trace 192.168.50.10
```

4. Giữ kết quả ping và đường đi **R1 → R3 → R4 → R5 → VPC10** → Stop Record.
5. Trace kết thúc tại .50.10 với ICMP Type 3 Code 3 là phản hồi đích cho UDP traceroute. Tránh gõ nhầm `19.168.50.10`.

Bản cắt khoảng 65 giây: chọn 5 router → mạng → preview/Push → neighbor + route → ping + trace. Nếu trên mạng broadcast có 2-WAY giữa DROTHER, đối chiếu vai trò DR/BDR; không mặc định mọi 2-WAY đều là lỗi.

## LAB 3 — Syslog và cảnh báo email

### Chuẩn bị ngoài video

Lab này là kịch bản 4 của báo cáo, do Quốc Việt thực hiện. Người có môi trường lab quay phần này trên máy tương ứng. Địa chỉ bộ nhận trong báo cáo là **192.168.122.1:5514/UDP**. Chỉ dùng địa chỉ này nếu đó thật sự là máy chạy CAMS của lab; nếu đổi máy nhận, sửa cả phía thiết bị và CAMS rồi quay kết quả mới.

Kết nối sẵn R1/R2/R3/SW1. SMTP và tài khoản nhận phải thử thành công trước. Có thể mở trang Email Alerts với mật khẩu che khuất, không quay lúc gõ mật khẩu. Kiểm tra SW1 Gi1/3 là cổng dữ liệu thử nghiệm, không phải cổng quản trị; muốn có LINK up/down cần đầu bên kia hoạt động.

### Đoạn 3A — cấu hình nguồn và bộ nhận

1. Record → topology 3 giây.
2. CAMS → thiết bị → **Syslog Server → Syslog Group**.
3. **Hosts**: chọn **R1, R2, R3, SW1** → **Next**.
4. Chọn source interface: router **GigabitEthernet0/0**, SW1 **Vlan1** → **Next**.
5. **Policy**: host **192.168.122.1**, protocol **UDP**, port **5514**, Trap severity **5 - Notifications**. Bật millisecond timestamps và sequence numbers.
6. Lưu/đến cửa sổ **View & Push Syslog Group** → giữ preview host, port, source interface → **Push**.
7. R1 terminal: `show running-config | include logging`.
8. CAMS → **System Logs → Start Listener** nếu chưa chạy; giữ trạng thái **Listener active**. Nếu đã active thì giữ nguyên.
9. **Settings → Email Alerts** → cho thấy gửi cảnh báo đã bật, mức **3 - Error** nằm trong danh sách chọn → trở lại System Logs. SMTP đã chuẩn bị ngoài video.

### Đoạn 3B — tạo sự kiện, thấy log, nhận email

1. SW1 terminal, thay đổi cổng dữ liệu thử nghiệm:

```text
configure terminal
interface GigabitEthernet1/3
 shutdown
end
```

2. Chờ thông báo trạng thái, rồi bật lại:

```text
configure terminal
interface GigabitEthernet1/3
 no shutdown
end
```

3. CAMS → System Logs → lọc **SW1** hoặc **LINK** → chọn dòng **LINK / 3 / UPDOWN** vừa tạo.
4. Giữ cửa sổ chi tiết: thiết bị nguồn, cổng Gi1/3, mức Error và nội dung down/up.
5. Mở hộp thư → thư cảnh báo mới → giữ nguồn SW1, mức LV3 và cùng cổng/nội dung với log.
6. Chờ gửi thư thực tế rồi mới kết thúc. Có thể cắt đoạn chờ; không khẳng định email được gửi tức thì. Cấu hình báo cáo có cửa sổ gom 10 giây và chống trùng 300 giây, nên chạy thử ngay trước quay có thể khiến thư lặp bị hạn chế.
7. Nếu chỉ nhận CONFIG_I nhưng không có LINK mức 3, kiểm tra cổng/đầu bên kia; CONFIG_I mức 5 không phù hợp để chứng minh email chỉ chọn mức 0–4.

Bản cắt khoảng 55 giây: chọn nguồn + policy → preview/Push → Listener active → shutdown/no shutdown → log mới → email tương ứng.

## LAB 4 — ACL và nhật ký tập trung

### Chuẩn bị ngoài video

Đây là kịch bản 5 của báo cáo. Giữ nền VLAN, trunk/subinterface, định tuyến và NAT hiện tại. R1 gateway VLAN 10/20/30 lần lượt **192.168.10.254 / .20.254 / .30.254**. VPC7=.10.1, VPC8=.20.1, VPC9=.30.1; đích thử **203.162.4.1**.

R1 gửi Syslog về bộ nhận đang active. Trap severity phải gồm **6 - Informational** để nhận log ACL; mức 5 của Lab Syslog không đủ cho bản tin SEC-6. Đích Telnet **192.168.12.2 thuộc R1** trong lab này, dù tên ACL có chữ R2.

Không cần xóa ACL đang chạy để quay. Có thể mở sửa luật hiện có, xác nhận binding rồi View & Push; quay đúng đây là rà soát/áp dụng cấu hình.

### Đoạn 4A — xem luật, binding và Push

1. Record → topology 3 giây.
2. CAMS → **R1 → ACL** → chọn **ACL_V10_NO_TELNET_R2** → mở sửa/xem luật.
3. Cho thấy hai luật theo đúng thứ tự:

| Sequence | Action/protocol | Source | Destination | Port | Log |
|---|---|---|---|---|---|
| 10 | deny tcp | 192.168.10.0, wildcard 0.0.0.255 | host 192.168.12.2 | destination eq 23 | Bật |
| 20 | permit ip | any | any | — | Bật |

4. Nếu nhập mới, chọn **+ Add Rule** sau mỗi luật rồi **Create ACL**; nếu đang sửa, **Change ACL**. Binding: **Gi0/1.10**, direction **IN**.
5. Chọn **ACL_V20_V30_OUT** → cho thấy:

| Sequence | Action/protocol | Source | Destination | Port | Log |
|---|---|---|---|---|---|
| 10 | deny tcp | 192.168.20.0, wildcard 0.0.0.255 | host 203.162.4.1 | destination eq 80 | Bật |
| 20 | deny icmp | 192.168.30.0, wildcard 0.0.0.255 | host 203.162.4.1 | — | Bật |
| 30 | permit ip | any | any | — | Bật |

6. Binding ACL thứ hai: **Gi0/1.20 IN**, **Gi0/1.30 IN**. Trong editor binding, chọn interface và direction → **Add** từng dòng → **Save** theo màn hình hiện tại.
7. **View & Push** → giữ preview các luật và `ip access-group ... in` đúng cổng → **Push**.
8. R1 terminal:

```text
show ip interface GigabitEthernet0/1.10 | include access list
show ip interface GigabitEthernet0/1.20 | include access list
show ip interface GigabitEthernet0/1.30 | include access list
show access-lists
```

9. Giữ kết quả inbound ACL và thứ tự luật.

### Đoạn 4B — phép thử cho phép và bị chặn

1. **VPC7 / VLAN 10**, kiểm tra đường truyền và HTTP hoạt động:

```text
ping 203.162.4.1
ping 203.162.4.1 -3 -p 80
```

2. Vẫn **VPC7**, thử TCP/23 thuộc luật chặn:

```text
ping 192.168.12.2 -3 -p 23
```

3. **VPC8 / VLAN 20**, HTTP bị chặn, ICMP được phép:

```text
ping 203.162.4.1 -3 -p 80
ping 203.162.4.1
```

4. **VPC9 / VLAN 30**, ICMP bị chặn, HTTP được phép:

```text
ping 203.162.4.1
ping 203.162.4.1 -3 -p 80
```

5. Giữ rõ Type 3 Code 13 / **Communication administratively prohibited** ở phép thử bị chặn; phép đối chứng thành công nằm ngay sau/trước đó.
6. Các lệnh `ping ... -3 -p ...` là phép thử TCP của VPCS, đúng cú pháp đã dùng trong ảnh báo cáo. Chúng không phải tải nội dung trang web hoặc đăng nhập Telnet.
7. R1: `show access-lists` → quay counter luật deny/permit tăng tương ứng.
8. CAMS → **System Logs** → lọc **SEC** hoặc tên ACL → mở dòng mới. Giữ tên ACL, denied/permit, IP nguồn, IP đích, cổng 80/23 hoặc ICMP → Stop Record.

Bản cắt khoảng 65 giây: luật + binding → preview/Push → phép đối chứng VLAN 10 → VLAN 20 HTTP deny → VLAN 30 ICMP deny → một phép đối chứng bổ sung → log. Giữ TCP/23 và các phép thử còn lại trong bản đầy đủ để dùng khi hội đồng hỏi.

## Thứ tự quay và chọn đoạn trình chiếu

1. Quay Lab 1 thành 5 đoạn A–E; đây là phần nhiều thay đổi trạng thái nhất.
2. Quay Lab 2 thành 2 đoạn khai báo và xác minh.
3. Quốc Việt quay Lab 3 trên môi trường Syslog của bạn ấy.
4. Quay Lab 4 thành 2 đoạn luật/binding và kiểm thử.
5. Lưu bản đầy đủ riêng: `LAB1_GOC`, `LAB2_GOC`, `LAB3_GOC`, `LAB4_GOC`. Chọn đoạn làm bản chiếu sau khi xác nhận kết quả.
6. Bản chiếu mục tiêu: Lab 1 100 giây + Lab 2 65 giây + Lab 3 55 giây + Lab 4 65 giây = 4 phút 45 giây, dành 15 giây chuyển phần. Nếu thao tác thực tế dài hơn, cắt hoặc tua nhanh đoạn chờ và ghi rõ; không dùng thời lượng bản dựng để so tốc độ CAMS với CLI.
7. Nếu một phép thử không đúng, dừng quay và sửa nguyên nhân rồi quay lại đoạn đó. Giữ ảnh PPTX và bản đầy đủ để đối chiếu khi hỏi đáp.
