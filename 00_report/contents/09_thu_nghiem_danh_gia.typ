#import "../config/tables.typ": report-table, table-code
#import "../config/commands.typ": report-note, step-title

#pagebreak(weak: true)
= Thử nghiệm và đánh giá

== Mục tiêu và phương pháp thử nghiệm

Chương này sử dụng một bài thực hành tích hợp duy nhất để kiểm chứng chuỗi quản trị của CAMS, thay cho nhiều kịch bản tách rời. Trình tự thử nghiệm gồm: cấu hình Syslog cho toàn bộ thiết bị; đối chiếu cấu hình trước và sau khi triển khai; cấu hình OSPF và HSRP; xác minh trực tiếp bằng đầu cuối; cấu hình VTP; kiểm tra nhật ký phát sinh; chuyển cảnh báo qua Email/Telegram; và kích hoạt phản ứng tự động của Automation Engine (Go core) trước lưu lượng ICMP flood.

Bài thử tập trung vào tính liên tục của luồng dữ liệu: CAMS tạo cấu hình, thiết bị phát sinh nhật ký, bộ thu nhận lưu và phân tích bản tin, Automation Engine (Go core) đánh giá quy tắc theo chu kỳ, sau đó Python executor sử dụng phiên SSH đang mở để áp dụng hành động đã kiểm tra. Kết quả được đối chiếu bằng `running-config`, trạng thái giao thức, bản tin Syslog và lưu lượng thử. Các số đếm trong chương là giá trị quan sát tại một lần thử, không được suy rộng thành tỷ lệ thành công hoặc thông lượng dài hạn.

== Mô hình và trạng thái chuẩn bị

#figure(
  image("/00_book/figures/report/lab/so_do_mang.svg", width: 95%),
  caption: [Mô hình bài thực hành tích hợp gồm bốn bộ định tuyến, hai bộ chuyển mạch và mạng người dùng],
) <fig-lab-topology>

Bốn bộ định tuyến tạo miền OSPF vùng 0. `R3` và `R4` đồng thời làm cổng mặc định dự phòng cho VLAN 100 qua HSRP. `SW5` và `SW6` nối với nhau bằng hai đường trung kế và tham gia cùng miền VTP. Sáu thiết bị dùng cổng `GigabitEthernet0/0` trong mạng `192.168.122.0/24` để CAMS quản trị và nhận Syslog.

#report-table(
  columns: (14%, 24%, 25%, 37%),
  text-size: 9pt,
  header: ([Thiết bị], [Địa chỉ quản trị], [Loopback / mạng người dùng], [Vai trò trong bài thử]),
  rows: (
    ([R1], [#table-code("192.168.122.11/24", size: 8.3pt)], [#table-code("1.1.1.1/32", size: 8.3pt)], [OSPF; kết nối R2, R3 và R4.]),
    ([R2], [#table-code("192.168.122.12/24", size: 8.3pt)], [#table-code("2.2.2.2/32", size: 8.3pt)], [OSPF; kết nối R1, R3 và R4.]),
    ([R3], [#table-code("192.168.122.13/24", size: 8.3pt)], [#table-code("3.3.3.3/32; 192.168.100.253/24", size: 8.3pt)], [OSPF và HSRP Active trên #table-code("Gi0/3.100", size: 8.3pt).]),
    ([R4], [#table-code("192.168.122.14/24", size: 8.3pt)], [#table-code("4.4.4.4/32; 192.168.100.254/24", size: 8.3pt)], [OSPF, HSRP Standby và điểm áp dụng phản ứng tự động.]),
    ([SW5], [#table-code("192.168.122.15/24", size: 8.3pt)], [VLAN 100], [VTP Server; đường trung kế tới SW6 và R3.]),
    ([SW6], [#table-code("192.168.122.16/24", size: 8.3pt)], [VLAN 100], [VTP Client; đường trung kế tới SW5 và R4.]),
  ),
  caption: [Thiết bị và vai trò trong bài thực hành tích hợp],
) <tab-lab-devices>

Năm liên kết định tuyến dùng các mạng `/30`: `10.0.12.0`, `10.0.13.0`, `10.0.14.0`, `10.0.23.0` và `10.0.24.0`. VLAN 100 dùng mạng `192.168.100.0/24`; địa chỉ HSRP ảo là `192.168.100.128`. Máy CAMS nhận Syslog tại `192.168.122.1:5514` bằng UDP và TCP. Tài khoản quản trị trên thiết bị có đặc quyền 15; các bước xác minh và phản ứng tự động sử dụng phiên SSH đang hoạt động.

== Triển khai và kiểm chứng bài thực hành tích hợp

=== Cấu hình Syslog theo nhóm và so sánh cấu hình

#step-title[Bước 1. Chọn thiết bị và cổng nguồn]

Trong *Syslog Group*, người quản trị chọn cả sáu thiết bị. CAMS lấy danh sách cổng của từng thiết bị và gán `GigabitEthernet0/0` làm cổng nguồn, nhờ đó địa chỉ nguồn của bản tin thuộc mạng quản trị và có thể đối chiếu trực tiếp với danh mục thiết bị. Trước chuỗi cấu hình, System Logs hiển thị `0 received`; giá trị này được dùng làm mốc phân biệt nhật ký nền với sự kiện của bài thử.

#figure(
  image("/00_book/figures/report/lab/Screenshot From 2026-10-19 19-34-14.png", width: 78%),
  caption: [Chọn sáu thiết bị tham gia chính sách Syslog theo nhóm],
) <fig-lab-syslog-hosts>

#step-title[Bước 2. Khai báo đích nhận và mức gửi]

Đích nhận được đặt là `192.168.122.1`, giao thức UDP, cổng `5514`. Ngưỡng `6 - Informational` cho phép chuyển các bản tin mức 0 đến 6, bao gồm thay đổi cấu hình, trạng thái OSPF, HSRP và VTP trong các bước tiếp theo. Chính sách đồng thời bật dấu thời gian đến mili giây và số thứ tự bản tin.

#figure(
  image("/00_book/figures/report/lab/Screenshot From 2026-10-19 19-37-16.png", width: 78%),
  caption: [Khai báo máy chủ Syslog, cổng 5514/UDP và ngưỡng Informational],
) <fig-lab-syslog-policy>

Cửa sổ *View & Push* sinh cùng một khối lệnh cho sáu thiết bị, chỉ thay địa chỉ thiết bị đích. Khối chính được kiểm duyệt trước khi gửi như sau:

```text
logging host 192.168.122.1 transport udp port 5514
logging on
logging trap informational
service timestamps log datetime msec
service sequence-numbers
logging source-interface GigabitEthernet0/0
```

#step-title[Bước 3. Đối chiếu phiên bản cấu hình]

Sau khi đồng bộ lại `running-config`, trang *Compare* của SW5 ghi nhận năm dòng thêm và hai dòng thay đổi. Phần khác biệt quan trọng gồm `service sequence-numbers`, `logging source-interface GigabitEthernet0/0` và `logging host 192.168.122.1 transport udp port 5514`. So sánh này xác nhận cấu hình trên thiết bị đã thay đổi đúng phạm vi, thay vì chỉ dựa vào thông báo hoàn thành của cửa sổ triển khai.

#pagebreak(weak: true)
=== Cấu hình OSPF trên bốn bộ định tuyến

Phần OSPF giữ đầy đủ các thao tác chính vì đây là nội dung cấu hình theo nhóm quan trọng nhất của bài thử.

#step-title[Bước 4. Chọn thành viên Routing Group]

Người quản trị chọn `R1` đến `R4` tại các địa chỉ quản trị `.11` đến `.14`. Hai bộ chuyển mạch không tham gia nhóm định tuyến.

#figure(
  image("/00_book/figures/report/lab/Screenshot From 2026-10-19 19-39-21.png", width: 82%),
  caption: [Chọn bốn bộ định tuyến trong Routing Group OSPF],
) <fig-lab-ospf-hosts>

#step-title[Bước 5. Khai báo Process ID và Router ID]

Tiến trình OSPF được đặt là `2` trên cả bốn thiết bị. Router ID lần lượt là `1.1.1.1`, `1.1.1.2`, `1.1.1.3` và `1.1.1.4`. Các giá trị này là định danh tiến trình, không được suy ra từ địa chỉ quản trị.

#figure(
  image("/00_book/figures/report/lab/Screenshot From 2026-10-19 19-39-32.png", width: 82%),
  caption: [Khai báo Process ID 2 và Router ID riêng cho R1 đến R4],
) <fig-lab-ospf-identity>

#step-title[Bước 6. Chọn mạng tham gia vùng 0]

Bộ lọc `10.0.0.0/8` hỗ trợ chọn nhanh năm liên kết `/30`. Người quản trị bổ sung bốn Loopback và mạng người dùng `192.168.100.0/24`, đặt toàn bộ vào vùng 0; mạng quản trị `192.168.122.0/24` được bỏ chọn.

#figure(
  image("/00_book/figures/report/lab/Screenshot From 2026-10-19 19-39-48.png", width: 82%),
  caption: [Lọc và chọn các liên kết point-to-point cho vùng OSPF 0],
) <fig-lab-ospf-networks-a>

#figure(
  image("/00_book/figures/report/lab/Screenshot From 2026-10-19 19-40-00.png", width: 82%),
  caption: [Bổ sung Loopback và mạng VLAN 100, đồng thời loại mạng quản trị],
) <fig-lab-ospf-networks-b>

#report-table(
  columns: (14%, 66%, 20%),
  text-size: 9pt,
  header: ([Thiết bị], [Các mạng được quảng bá], [Vùng]),
  rows: (
    ([R1], [#table-code("1.1.1.1/32; 10.0.12.0/30; 10.0.13.0/30; 10.0.14.0/30", size: 8.4pt)], [0]),
    ([R2], [#table-code("2.2.2.2/32; 10.0.12.0/30; 10.0.23.0/30; 10.0.24.0/30", size: 8.4pt)], [0]),
    ([R3], [#table-code("3.3.3.3/32; 10.0.13.0/30; 10.0.23.0/30; 192.168.100.0/24", size: 8.4pt)], [0]),
    ([R4], [#table-code("4.4.4.4/32; 10.0.14.0/30; 10.0.24.0/30; 192.168.100.0/24", size: 8.4pt)], [0]),
  ),
  caption: [Phạm vi mạng OSPF sau khi hoàn tất lựa chọn],
) <tab-lab-ospf-networks>

#step-title[Bước 7. Kiểm duyệt lệnh và triển khai]

Cửa sổ *View & Push OSPF* tổng hợp lệnh cho bốn thiết bị. Ngoài `router-id` và các lệnh `network`, phần xem trước chứa các giá trị mặc định đã chọn ở bước *Common*, như `auto-cost reference-bandwidth 100`, không bật vùng stub/NSSA và không phát tán tuyến mặc định.

#figure(
  image("/00_book/figures/report/lab/Screenshot From 2026-10-19 19-40-06.png", width: 82%),
  caption: [Kiểm duyệt cấu hình OSPF của bốn thiết bị trước khi Push],
) <fig-lab-ospf-preview>

#pagebreak(weak: true)
#step-title[Bước 8. Xác minh trên đầu cuối]

Sau khi triển khai, lệnh `show running-config | section router ospf` được chạy trên cả bốn bộ định tuyến. Các ảnh đầu cuối dưới đây được tái tạo bằng `term2png.py` từ đúng nội dung trong ảnh chụp gốc để loại phần banner IOS và giữ chữ dễ đọc khi in.

#figure(
  grid(
    columns: 1,
    row-gutter: 6pt,
    image("/00_book/figures/report/lab/terminal-generated/ospf-r1.png", width: 100%),
    image("/00_book/figures/report/lab/terminal-generated/ospf-r2.png", width: 100%),
  ),
  caption: [Cấu hình OSPF thực tế trên R1 và R2 sau khi triển khai],
) <fig-lab-ospf-terminals-a>

#figure(
  grid(
    columns: 1,
    row-gutter: 6pt,
    image("/00_book/figures/report/lab/terminal-generated/ospf-r3.png", width: 100%),
    image("/00_book/figures/report/lab/terminal-generated/ospf-r4.png", width: 100%),
  ),
  caption: [Cấu hình OSPF thực tế trên R3 và R4 sau khi triển khai],
) <fig-lab-ospf-terminals-b>

Kết quả xác nhận tiến trình 2, Router ID và các lệnh `network` nhất quán với @tab-lab-ospf-networks. Nhật ký thu ở bước sau còn ghi nhận sự kiện `OSPF-5-ADJCHG` với trạng thái `LOADING to FULL`, cung cấp bằng chứng bổ sung rằng ít nhất quan hệ láng giềng được hiển thị đã hoàn tất trao đổi cơ sở dữ liệu. Bộ ảnh không có kết quả đầy đủ của `show ip ospf neighbor` và `show ip route ospf` trên cả bốn thiết bị, vì vậy chương này không suy rộng thành phép đo hội tụ hoặc kiểm chứng toàn bộ bảng định tuyến.

#pagebreak(weak: true)
=== Cấu hình HSRP và xác minh trạng thái Active/Standby

#step-title[Bước 9. Tạo nhóm cổng mặc định dự phòng]

`R3` và `R4` được chọn vào HSRP group 1, phiên bản 2, trên cổng con `GigabitEthernet0/3.100`. Địa chỉ IP ảo là `192.168.100.128`. `R3` có độ ưu tiên `101`, `R4` giữ giá trị `100`; cả hai bật `preempt`.

#figure(
  image("/00_book/figures/report/lab/Screenshot From 2026-10-19 19-44-37.png", width: 82%),
  caption: [Chính sách thành viên HSRP trên R3 và R4],
) <fig-lab-hsrp-policy>

Cửa sổ xem trước sinh `standby version 2`, `standby 1 ip 192.168.100.128`, độ ưu tiên và `standby 1 preempt` cho từng bộ định tuyến. Sau khi Push, lệnh `show standby all` xác nhận `R3` ở trạng thái Active và `R4` ở trạng thái Standby.

#figure(
  grid(
    columns: 1,
    row-gutter: 7pt,
    image("/00_book/figures/report/lab/terminal-generated/hsrp-r3.png", width: 100%),
    image("/00_book/figures/report/lab/terminal-generated/hsrp-r4.png", width: 100%),
  ),
  caption: [Xác minh HSRP group 1 trên R3 và R4 bằng đầu cuối tích hợp],
) <fig-lab-hsrp-terminals>

Địa chỉ Active vật lý là `192.168.100.253`; bộ định tuyến dự phòng là `192.168.100.254`. Kết quả truy vết từ máy trạm dùng gateway `192.168.100.128` ghi nhận chặng đầu tiên là `192.168.100.253`, phù hợp với vai trò Active của R3. Bài thử chưa ngắt R3 để đo thời gian chuyển đổi sang R4.

=== Cấu hình VTP trên hai bộ chuyển mạch

#step-title[Bước 10. Khai báo miền VTP và vai trò thành viên]

`SW5` và `SW6` tham gia miền `cams.local`, VTP version 2. `SW5` được đặt ở chế độ Server, `SW6` ở chế độ Client; pruning không được bật. Xác thực VTP nằm ngoài luồng nhóm không tương tác này và không được cấu hình trong bài thử.

#figure(
  image("/00_book/figures/report/lab/Screenshot From 2026-10-19 19-47-36.png", width: 70%),
  caption: [Khai báo miền cams.local và vai trò Server/Client cho SW5, SW6],
) <fig-lab-vtp-policy>

Khối lệnh được kiểm duyệt trước khi gửi gồm:

```text
! SW5
vtp domain cams.local
vtp version 2
vtp mode server
no vtp pruning

! SW6
vtp domain cams.local
vtp version 2
vtp mode client
```

#pagebreak(weak: true)
#step-title[Bước 11. Xác minh trạng thái VTP]

Lệnh `show vtp status` xác nhận hai thiết bị cùng miền, cùng version 2, cùng revision 2 và đều có sáu VLAN tại thời điểm quan sát. Vai trò vận hành lần lượt là Server và Client.

#figure(
  grid(
    columns: 1,
    row-gutter: 7pt,
    image("/00_book/figures/report/lab/terminal-generated/vtp-sw5.png", width: 100%),
    image("/00_book/figures/report/lab/terminal-generated/vtp-sw6.png", width: 100%),
  ),
  caption: [Xác minh VTP version 2, domain cams.local và revision 2 trên SW5, SW6],
) <fig-lab-vtp-terminals>

#pagebreak(weak: true)
=== Đối chiếu nhật ký sau các thay đổi cấu hình

#step-title[Bước 12. Kiểm tra System Logs]

Sau chuỗi cấu hình, bộ thu nhận hiển thị `55 received`. Các dòng nhật ký liên kết trực tiếp với thao tác vừa thực hiện: `CONFIG_I` và `CONFIG_WRITTEN` cho thay đổi cấu hình; `OSPF-5-ADJCHG` cho quan hệ láng giềng; `HSRP-5-STATECHANGE` cho trạng thái Active/Standby; và `SW_VLAN-6-VTP_DOMAIN_NAME_CHG` cho thay đổi miền VTP.

#figure(
  image("/00_book/figures/report/lab/Screenshot From 2026-10-19 19-49-27.png", width: 100%),
  caption: [Màn hình System Logs sau khi hoàn tất cấu hình OSPF, HSRP và VTP],
) <fig-lab-system-logs-overview>

Màn hình tại @fig-lab-system-logs-overview cho thấy bộ thu C++ đang hoạt động trên cổng `5514/UDP+TCP`, bộ đếm đạt 55 bản tin và danh sách có thể lọc theo thiết bị, mức độ, giao thức, thời gian cùng loại sự kiện an ninh. Bảng dưới đây chỉ rút gọn các dòng dùng để đối chiếu trực tiếp với thao tác cấu hình.

#report-table(
  columns: (21%, 18%, 25%, 36%),
  text-size: 8.8pt,
  header: ([Nguồn], [Mức], [Cisco facility / mnemonic], [Nội dung đối chiếu]),
  rows: (
    ([R1-R4], [5 - Notice], [#table-code("SYS / CONFIG_I", size: 8.2pt)], [Cấu hình được áp dụng từ phiên VTY của tài khoản quản trị.]),
    ([R1, R4], [5 - Notice], [#table-code("OSPF / ADJCHG", size: 8.2pt)], [Quan hệ láng giềng chuyển từ LOADING sang FULL.]),
    ([R3], [5 - Notice], [#table-code("HSRP / STATECHANGE", size: 8.2pt)], [#table-code("Gi0/3.100", size: 8.2pt) chuyển từ Standby sang Active.]),
    ([R4], [5 - Notice], [#table-code("HSRP / STATECHANGE", size: 8.2pt)], [#table-code("Gi0/3.100", size: 8.2pt) chuyển từ Speak sang Standby.]),
    ([SW6], [6 - Informational], [#table-code("SW_VLAN / VTP_DOMAIN_NAME_CHG", size: 8.2pt)], [Miền VTP đổi thành #table-code("cams.local", size: 8.2pt).]),
  ),
  caption: [Các nhóm sự kiện ghi nhận sau khi cấu hình OSPF, HSRP và VTP],
) <tab-lab-syslog-events>

#figure(
  image("/00_book/figures/report/lab/Screenshot From 2026-10-19 19-49-55.png", width: 68%),
  caption: [Chi tiết bản tin đổi miền VTP được phân tích và lưu cùng nội dung gốc],
) <fig-lab-vtp-syslog-detail>

Trong @fig-lab-vtp-syslog-detail, PRI bằng `190` được tách thành Syslog facility 23 (`local7`) và severity 6. Chuỗi `SW_VLAN` là mã phân hệ Cisco trong định dạng `%FACILITY-SEVERITY-MNEMONIC`, không phải facility được mã hóa trong PRI. Trường `Sequence / Clock` cho thấy số thứ tự 47 và đồng hồ đã đồng bộ.

=== Chuyển cảnh báo qua Email và Telegram

#step-title[Bước 13. Kiểm tra kênh cảnh báo ngoài ứng dụng]

Dịch vụ Email nhận các bản ghi đã lưu, lọc theo mức được chọn, chống gửi trùng và gom nhiều bản tin trước khi gửi qua SMTP. Hộp thư trong lần thử ghi nhận bốn đợt với tiêu đề lần lượt là `5 new alerts`, `2 new alerts`, `4 new alerts` và `16 new alerts`; mức cao nhất trong các thư được hiển thị là `LEVEL 5 NOTICE`.

#figure(
  image("/00_book/figures/report/lab/Screenshot From 2026-10-19 19-51-30.png", width: 100%),
  caption: [Các thư cảnh báo Syslog được CAMS gửi tới hộp thư thử nghiệm],
) <fig-lab-email-alerts>

Email chi tiết giữ nguồn `192.168.122.16`, thời gian nhận, số thứ tự, mã `%SYS-5-CONFIG_I`, PRI/facility và nội dung gốc. Điều này cho phép người nhận đối chiếu cảnh báo ngoài ứng dụng với bản ghi trong System Logs.

#figure(
  image("/00_book/figures/report/lab/telegram-syslog-alert.jpg", width: 40%),
  caption: [Cảnh báo Syslog mức Notice được giao tới Telegram],
) <fig-lab-telegram-alerts>

CAMS gửi Telegram bằng `TelegramAlertService`: bản ghi sau khi lưu được đưa vào hàng đợi riêng, áp dụng cùng nguyên tắc chọn severity, chống gửi lặp và gom đợt, rồi chuyển qua Telegram Bot API. Bot Token được mã hóa khi lưu và không được ghi vào nhật ký. @fig-lab-telegram-alerts xác nhận bot `cams.syslog.alert` đã nhận các bản tin mức `LEVEL 5 - NOTICE`, giữ địa chỉ thiết bị, địa chỉ nguồn, thời gian nhận, mã Cisco và nội dung sự kiện.

#pagebreak(weak: true)
=== Giám sát theo chu kỳ và phản ứng tự động bằng Automation Engine (Go core)

#step-title[Bước 14. Chuẩn bị sự kiện ICMP flood trên R4]

ACL `DETECT-PING` được gắn chiều vào trên `GigabitEthernet0/3.100`. Luật đầu ghi nhật ký ICMP Echo bằng `log-input`; luật sau cho phép các lưu lượng IP còn lại. EEM applet `DETECT-DOS` theo dõi bốn bản tin `IPACCESSLOGDP` phù hợp trong 30 giây, trích địa chỉ nguồn và cổng, rồi phát bản tin mức Alert có định dạng ổn định để CAMS phân tích.

#block(breakable: false)[
```text
ip access-list extended DETECT-PING
 permit icmp any any echo log-input
 permit ip any any
ip access-list log-update threshold 500

event manager applet DETECT-DOS
 event syslog occurs 4 pattern "IPACCESSLOGDP.*DETECT-PING.*icmp" \
   period 30 maxrun 20 ratelimit 60
 action 1.0 regexp "icmp (([0-9.]+) \\(([A-Za-z0-9/.]+)" \
   "$_syslog_msg" full srcip intf
 action 2.0 syslog priority alerts msg \
   "NGHI DOS: ICMP flood vao R4 tu IP $srcip tai cong $intf"
```
]

#pagebreak(weak: true)
#step-title[Bước 15. Nạp và bật Automation Rule version 3]

Quy tắc `demo-dynamic-syslog-variables-v3` dùng lịch đánh giá `5` giây, chỉ khớp sự kiện `ICMP_FLOOD` của thiết bị thuộc mạng quản trị `192.168.122.0/24` và thuộc tính `protocol = icmp`. Hai biến được lấy từ chính bản tin Syslog đã lưu trong SQLite: `interface` có kiểu `interface`, còn `offender_ip` có kiểu IPv4. Automation Engine (Go core) chỉ kết xuất lệnh khi biểu thức chính quy khớp và giá trị qua kiểm tra kiểu.

```text
interface {{ variables.interface }}
description CAMS_AUTO_ICMP_FLOOD_{{ variables.offender_ip }}
shutdown
```

Chính sách chạy ở chế độ `auto`, có thời gian chống lặp 600 giây và giới hạn một hành động mỗi giờ. Tệp demo trong kho tài liệu mặc định đặt `enabled: false`; trong không gian làm việc thử nghiệm, bản sao được bật sau khi kiểm tra lệnh và bảo đảm phiên SSH tới R4 đang hoạt động.

#figure(
  image("/00_book/figures/report/lab/Screenshot From 2026-10-19 20-00-11.png", width: 100%),
  caption: [Automation Engine (Go core) đang chạy với một quy tắc v3 SSH được bật],
) <fig-lab-automation-rule>

`AutomationManager` dùng bộ định thời một giây để truy vấn các sự kiện chờ. Automation Engine (Go core) áp dụng `schedule.interval_seconds = 5` cho quy tắc, kiểm tra phạm vi thiết bị, thuộc tính, chống lặp và giới hạn tần suất. Hành động hợp lệ được tạo ở trạng thái `ready`; Python executor nhận hành động, dùng phiên SSH đang mở, gửi lệnh trong configuration mode và chạy lệnh xác minh. Cách tách này giữ phần đánh giá quy tắc và kết xuất biến trong tiến trình Go, còn việc điều khiển phiên thiết bị tiếp tục dùng hạ tầng SSH của CAMS.

#pagebreak(weak: true)
#step-title[Bước 16. Mô phỏng ICMP flood và quan sát phản ứng]

Máy thử phát ICMP Echo liên tục tới địa chỉ thật của R4 bằng lệnh `ping -f -w 60 192.168.100.254`; tham số `-w 60` đặt giới hạn thời gian tối đa 60 giây. Kết quả ghi nhận 5.787 gói gửi, 2.421 gói nhận, 5 lỗi và tỷ lệ mất 58,1649% trong lần chạy.

#figure(
  image("/00_book/figures/report/lab/terminal-generated/icmp-flood.png", width: 100%),
  caption: [Kết quả mô phỏng ICMP flood tới địa chỉ 192.168.100.254 của R4],
) <fig-lab-icmp-flood>

Chuỗi sự kiện trong System Logs cho thấy ACL ghi nhận các đợt ICMP, EEM phát cảnh báo, CAMS chuẩn hóa thành `ICMP_FLOOD`, sau đó cổng con chuyển xuống. Thời gian dưới đây là thời gian nhận do CAMS lưu; không dùng để suy ra độ trễ tuyệt đối khi chưa đối chiếu đồng hồ của mọi thành phần.

#figure(
  image("/00_book/figures/report/lab/Screenshot From 2026-10-19 20-02-14.png", width: 100%),
  caption: [Màn hình System Logs trên R4 từ lúc OSPF lên FULL đến khi ICMP_FLOOD kích hoạt phản ứng],
) <fig-lab-icmp-system-logs>

@fig-lab-icmp-system-logs hiển thị trực tiếp các dòng `SEC`, `HA_EM`, `CAMS`, HSRP, OSPF và `CONFIG_I`. Bảng thời gian sau chuẩn hóa lại cùng chuỗi sự kiện để tránh phải suy luận từ phần nội dung bị rút gọn theo chiều rộng của giao diện.

#report-table(
  columns: (20%, 25%, 55%),
  text-size: 8.8pt,
  header: ([Thời gian nhận], [Sự kiện], [Nội dung]),
  rows: (
    ([13:01:43.073Z đến 13:01:46.436Z], [#table-code("SEC-6-IPACCESSLOGDP", size: 8.1pt)], [ACL `DETECT-PING` ghi các đợt ICMP, có dòng tổng hợp 500 gói.]),
    ([13:01:45.286Z], [#table-code("HA_EM-1-LOG", size: 8.1pt)], [EEM báo ICMP flood từ `192.168.100.1` tại `GigabitEthernet0/3.100`.]),
    ([13:01:45.294Z], [#table-code("CAMS-1-ICMP_FLOOD", size: 8.1pt)], [Bộ phân tích tạo security event sẵn sàng cho đánh giá chính sách.]),
    ([13:01:47.467Z], [#table-code("HSRP-5-STATECHANGE", size: 8.1pt)], [R4 chuyển từ Standby sang Init do cổng con bị hạ.]),
    ([13:01:47.469Z], [#table-code("OSPF-5-ADJCHG", size: 8.1pt)], [Láng giềng trên `Gi0/3.100` chuyển từ FULL xuống DOWN.]),
    ([13:01:49.688Z], [#table-code("SYS-5-CONFIG_I", size: 8.1pt)], [Thiết bị ghi nhận thay đổi cấu hình qua phiên VTY.]),
  ),
  caption: [Chuỗi sự kiện từ lưu lượng ICMP đến thay đổi trạng thái trên R4],
) <tab-lab-automation-timeline>

#step-title[Bước 17. Xác minh cấu hình sau hành động tự động]

So sánh `running-config` của R4 cho thấy mô tả cũ `EMPLOYEE_VLAN100` được thay bằng `CAMS_AUTO_ICMP_FLOOD_192.168.100.1` và xuất hiện lệnh `shutdown`. Kết quả dưới đây được tái tạo từ phần cấu hình đã đối chiếu để giữ chữ rõ khi in.

#figure(
  image("/00_book/figures/report/lab/terminal-generated/r4-after-automation.png", width: 88%),
  caption: [Cấu hình Gi0/3.100 của R4 sau khi Automation Engine (Go core) xử lý ICMP_FLOOD],
) <fig-lab-r4-automation-result>

#block(breakable: false)[
Kết quả xác nhận chuỗi phản ứng khép kín trong lab: bộ thu nhận lưu bản tin, bộ phân tích tạo sự kiện, Automation Engine (Go core) khớp rule và biến, còn executor áp dụng và xác minh lệnh qua SSH. Lệnh `shutdown` cô lập toàn bộ cổng con, làm mất láng giềng OSPF và đưa HSRP của R4 về Init; vì vậy chính sách chỉ dùng để minh họa trong môi trường kiểm soát, không phải mặc định cho mạng vận hành.
]

== Đánh giá kết quả

#report-table(
  columns: (22%, 43%, 35%),
  text-size: 9pt,
  header: ([Hạng mục], [Kết quả quan sát], [Giới hạn kết luận]),
  rows: (
    ([Syslog Group], [Sáu thiết bị nhận cùng đích #table-code("192.168.122.1:5514/UDP", size: 8.6pt), ngưỡng Informational và cổng nguồn #table-code("Gi0/0", size: 8.6pt); cấu hình mới xuất hiện trong phần so sánh.], [Chưa đo tỷ lệ mất bản tin hoặc thông lượng.]),
    ([OSPF], [CAMS tạo tiến trình 2 và các mạng vùng 0 trên R1-R4; terminal xác nhận cấu hình, Syslog có láng giềng chuyển lên FULL.], [Chưa thu đủ bảng láng giềng, bảng tuyến và thời gian hội tụ trên cả bốn thiết bị.]),
    ([HSRP], [R3 Active, R4 Standby, cùng VIP #table-code("192.168.100.128", size: 8.6pt); máy trạm đi qua địa chỉ thật của R3.], [Chưa thử ngắt R3 để đo chuyển đổi dự phòng.]),
    ([VTP], [SW5 Server, SW6 Client, cùng domain #table-code("cams.local", size: 8.6pt), version 2, revision 2 và sáu VLAN.], [Chưa kiểm thử xác thực VTP hoặc sai miền.]),
    ([Cảnh báo ngoài ứng dụng], [Email chứa các đợt Syslog; Telegram hiển thị các bản tin Notice cùng nguồn, thời gian và mã Cisco.], [Chưa đo độ trễ giao tin, tỷ lệ gửi lại hoặc hành vi khi mất mạng.]),
    ([Phản ứng tự động], [ICMP flood tạo #table-code("ICMP_FLOOD", size: 8.6pt); rule v3 lấy đúng cổng và IP nguồn, thêm mô tả rồi shutdown #table-code("Gi0/3.100", size: 8.6pt) của R4.], [Chính sách cô lập cả cổng; chưa đánh giá dương tính giả, hoàn tác hoặc ảnh hưởng dịch vụ dài hạn.]),
  ),
  caption: [Tổng hợp kết quả của bài thực hành tích hợp],
) <tab-lab-summary>

So với cấu trúc năm kịch bản trước, một bài thực hành tích hợp làm rõ quan hệ giữa cấu hình và giám sát: cùng các thay đổi OSPF, HSRP và VTP tạo dữ liệu cho System Logs; cùng dữ liệu này được chuyển thành cảnh báo và đầu vào cho phản ứng tự động. Các ảnh nhập liệu lặp lại được lược bỏ, trong khi toàn bộ thao tác OSPF và các kết quả đầu cuối quan trọng được giữ lại.

