# Kịch bản kiểm thử riêng chức năng ACL

## 1. Mục tiêu

Kiểm tra hai chính sách ACL trong mô hình Lab 3.1:

1. **Standard ACL:** từ chối Telnet từ VLAN 10 đến R2, nhưng vẫn cho phép các VLAN khác truy cập Telnet đến R2.
2. **Extended ACL:** từ chối lưu lượng HTTP từ VLAN 20 ra máy chủ Internet `203.162.4.1`, từ chối ICMP từ VLAN 30 ra Internet, đồng thời không làm ảnh hưởng đến lưu lượng được phép của VLAN 10.

Kịch bản này chỉ kiểm tra điều kiện lọc và bản tin Syslog của ACL. Không dùng kết quả của NAT, DHCP, VTP, STP hoặc định tuyến để kết luận ACL đã đạt.

## 2. Điều kiện đầu vào

| Thành phần | Giá trị dùng trong phép thử |
|---|---|
| VLAN 10 | Mạng `192.168.10.0/24`, máy kiểm thử dùng nguồn `192.168.10.1` hoặc địa chỉ thực tế được cấp trong lab |
| VLAN 20 | Mạng `192.168.20.0/24`, dùng một địa chỉ nguồn thuộc dải này |
| VLAN 30 | Mạng `192.168.30.0/24`, dùng một địa chỉ nguồn thuộc dải này |
| R2 | Địa chỉ quản trị/đích Telnet `192.168.12.2` |
| Máy chủ Internet | `203.162.4.1`, bật HTTP bằng `ip http server` trên ISP |
| ACL Standard | Tên đề xuất `ACL_V10_NO_TELNET_R2` |
| ACL Extended | Tên đề xuất `ACL_V20_V30_OUT` |

Nếu địa chỉ máy trạm trong sơ đồ thực tế khác các giá trị trên, giữ nguyên mạng nguồn và thay địa chỉ kiểm thử bằng địa chỉ đang được ghi trong bảng địa chỉ của lab.

## 3. Cấu hình chính sách

### 3.1. Standard ACL chặn Telnet từ VLAN 10

Standard ACL chỉ lọc theo địa chỉ nguồn. Vì mục tiêu là bảo vệ đường truy cập vào mặt phẳng quản trị của R2, áp ACL vào **VTY của R2** bằng `access-class`, không đặt ACL Standard lên cổng giao tiếp. Cấu hình mẫu:

```text
R2(config)# ip access-list standard ACL_V10_NO_TELNET_R2
R2(config-std-nacl)# 10 deny 192.168.10.0 0.0.0.255 log
R2(config-std-nacl)# 20 permit any
R2(config-std-nacl)# exit
R2(config)# line vty 0 4
R2(config-line)# access-class ACL_V10_NO_TELNET_R2 in
R2(config-line)# transport input telnet
```

`permit any` là bắt buộc trong phép thử này để các nguồn khác không bị rơi vào implicit deny. Nếu VTY đang dùng SSH, giữ phương thức quản trị theo cấu hình lab và kiểm tra đúng giao thức được yêu cầu; không dùng một phiên SSH thành công để kết luận Telnet đã được kiểm tra.

### 3.2. Extended ACL chặn HTTP của VLAN 20 và ICMP của VLAN 30

Extended ACL nên đặt **inbound trên các subinterface của R2 nhận lưu lượng từ VLAN 20 và VLAN 30**. Cách đặt này lọc gần nguồn và không chặn nhầm lưu lượng của VLAN 10. Cấu hình mẫu, với tên subinterface cần thay theo sơ đồ:

```text
R2(config)# ip access-list extended ACL_V20_V30_OUT
R2(config-ext-nacl)# 10 deny tcp 192.168.20.0 0.0.0.255 host 203.162.4.1 eq 80 log
R2(config-ext-nacl)# 20 deny icmp 192.168.30.0 0.0.0.255 host 203.162.4.1 log
R2(config-ext-nacl)# 30 permit ip any any
R2(config-ext-nacl)# exit
R2(config)# interface FastEthernet0/0.20
R2(config-subif)# ip access-group ACL_V20_V30_OUT in
R2(config-subif)# exit
R2(config)# interface FastEthernet0/0.30
R2(config-subif)# ip access-group ACL_V20_V30_OUT in
R2(config-subif)# exit
```

Không áp nguyên ACL này vào `FastEthernet0/0` vật lý nếu các VLAN dùng subinterface: khi đó vị trí lọc không thể hiện rõ nguồn VLAN và dễ làm sai phạm vi kiểm thử. Nếu thiết bị trong lab dùng một cổng L3 riêng cho từng VLAN, áp ACL inbound vào đúng cổng tương ứng.

## 4. Trình tự thực hiện

### Bước 1 – Kiểm tra trạng thái trước khi áp ACL

Trên R2 ghi lại cấu hình và bộ đếm ban đầu:

```text
show access-lists
show running-config | section access-list
show running-config | section line vty
show ip interface FastEthernet0/0.20
show ip interface FastEthernet0/0.30
```

Xác nhận các subinterface đang `up/up`, đã có địa chỉ IP, và máy chủ `203.162.4.1` có thể được dùng làm đích thử. Nếu điều kiện kết nối nền chưa đạt, dừng phép thử ACL và ghi nhận lỗi môi trường riêng.

### Bước 2 – Triển khai qua CAMS

1. Mở chức năng **ACL** và tạo hai ACL với đúng tên, loại và thứ tự luật.
2. Chọn đúng thiết bị R2, cổng VTY hoặc subinterface tương ứng và chiều áp dụng.
3. Chọn **Save** để lưu trạng thái mong muốn.
4. Mở **View & Push**, kiểm tra từng dòng lệnh, đặc biệt là `deny`, wildcard, giao thức, cổng `80`, từ khóa `log`, `permit ip any any` và chiều `in`.
5. Chọn **Push** sau khi lệnh đã được duyệt.
6. Ghi lại kết quả theo từng thiết bị; không coi thao tác gửi lệnh thành công là bằng chứng lưu lượng đã bị lọc.

### Bước 3 – Kiểm tra Standard ACL

Từ một máy thuộc VLAN 10:

```text
telnet 192.168.12.2
```

Kết quả đạt: phiên bị từ chối hoặc không tạo được phiên Telnet đến R2.

Từ một máy thuộc VLAN 20 hoặc VLAN 30:

```text
telnet 192.168.12.2
```

Kết quả đạt: phiên đến bước yêu cầu xác thực hoặc hiển thị dấu nhắc R2, tùy cấu hình tài khoản. Không cần đăng nhập thành công để chứng minh ACL; chỉ cần phân biệt được kết nối bị ACL chặn với kết nối đã tới dịch vụ Telnet.

Trên R2 kiểm tra:

```text
show access-lists ACL_V10_NO_TELNET_R2
show running-config | section line vty
```

Bộ đếm dòng `deny` phải tăng sau lần thử từ VLAN 10; bộ đếm `permit` không được tăng do chính lần thử bị chặn. Dòng `log` phải tạo bản tin ACL nếu logging đã được cấu hình.

### Bước 4 – Kiểm tra Extended ACL

Từ VLAN 10, tạo đường chuẩn để chứng minh lưu lượng được phép:

```text
ping 203.162.4.1 source 192.168.10.1
telnet 203.162.4.1 80 /source-interface f0/0.10
```

Kết quả đạt: ICMP có phản hồi theo điều kiện lab; kết nối TCP đến cổng 80 tới máy chủ HTTP được thiết lập. Nếu Telnet tới cổng 80 chỉ trả `HTTP/1.1 400 Bad Request`, điều đó vẫn chứng minh TCP đã tới được dịch vụ HTTP.

Từ VLAN 20:

```text
telnet 203.162.4.1 80 /source-interface f0/0.20
```

Kết quả đạt: kết nối bị từ chối hoặc không tới được máy chủ; không được ghi nhận `Open`.

Từ VLAN 30:

```text
ping 203.162.4.1 source 192.168.30.1
```

Kết quả đạt: tỷ lệ thành công `0/5` hoặc toàn bộ gói bị timeout.

Sau mỗi nhóm thử:

```text
show access-lists ACL_V20_V30_OUT
show ip interface FastEthernet0/0.20
show ip interface FastEthernet0/0.30
```

Bộ đếm dòng `deny tcp ... eq 80` phải tăng sau phép thử VLAN 20; bộ đếm dòng `deny icmp ...` phải tăng sau phép thử VLAN 30; dòng `permit ip any any` phải tăng khi kiểm tra lưu lượng được phép từ VLAN 10.

### Bước 5 – Kiểm tra Syslog ACL trong CAMS

Nếu đã cấu hình đích Syslog trên R2, mở **System Logs** trong CAMS và lọc theo:

- `cisco_facility = SEC`;
- `mnemonic = IPACCESSLOGP`;
- thiết bị nguồn là R2;
- nội dung chứa `ACL_V10_NO_TELNET_R2` hoặc `ACL_V20_V30_OUT`.

Log tối thiểu cần đối chiếu gồm hành động `denied`, giao thức, địa chỉ nguồn, địa chỉ đích, cổng đích và số gói. Ví dụ hợp lệ:

```text
%SEC-6-IPACCESSLOGP: list ACL_V20_V30_OUT denied tcp 192.168.20.10(...) -> 203.162.4.1(80), 1 packet
```

Không dùng tên `LINEPROTO` làm Syslog facility của bản tin này: đó là mã phân hệ Cisco IOS; facility Syslog được lấy từ trường PRI.

## 5. Ma trận kết quả

| ID | Nguồn | Thao tác | Kết quả mong đợi | Bằng chứng bắt buộc |
|---|---|---|---|---|
| ACL-01 | VLAN 10 | Telnet đến `192.168.12.2` | Bị chặn | Kết quả Telnet + counter dòng deny Standard |
| ACL-02 | VLAN 20 | TCP/80 đến `203.162.4.1` | Bị chặn | Kết quả kết nối + counter deny TCP |
| ACL-03 | VLAN 30 | ICMP đến `203.162.4.1` | Bị chặn | Ping `0/5` + counter deny ICMP |
| ACL-04 | VLAN 10 | ICMP và TCP/80 đến `203.162.4.1` | Được phép theo điều kiện lab | Kết quả lưu lượng + counter permit |
| ACL-05 | VLAN 20/30 | Telnet đến R2 | Không bị Standard ACL chặn do nguồn không thuộc VLAN 10 | Kết quả tới bước xác thực + counter permit/không tăng deny VLAN 10 |
| ACL-06 | R2 → CAMS | Lọc Syslog ACL | Nhận đúng nguồn, mã sự kiện, hành động và địa chỉ | Ảnh hoặc bản xuất System Logs |

## 6. Tiêu chí kết luận

Kịch bản **Đạt** khi ACL-01 đến ACL-04 đúng, các bộ đếm tăng đúng dòng luật, và ACL-06 có bản tin khớp nguồn cùng hành động. Kịch bản **Đạt một phần** nếu lọc lưu lượng đúng nhưng chưa thu được Syslog hoặc chưa chứng minh được chiều áp dụng. Kịch bản **Chưa đạt** nếu VLAN 10 vẫn Telnet được vào R2, VLAN 20 vẫn mở được TCP/80, VLAN 30 vẫn ping được Internet, hoặc lưu lượng VLAN 10 bị chặn nhầm.

Sau khi hoàn tất, lưu bốn loại bằng chứng: lệnh đã xem trước trong CAMS, running-config sau Push, kết quả kiểm tra lưu lượng và bộ đếm/log ACL. Không kết luận ACL đạt chỉ từ ảnh giao diện CAMS hoặc trạng thái `Push successful`.
