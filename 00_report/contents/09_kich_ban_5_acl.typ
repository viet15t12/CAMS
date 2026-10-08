#import "../config/tables.typ": report-table, table-code

=== Kịch bản 5: Kiểm chứng chính sách ACL và nhật ký an ninh tập trung

==== Mục tiêu và phạm vi

Kịch bản 5 kiểm chứng chuỗi xử lý từ chính sách đến bằng chứng vận hành: CAMS tạo ACL có ghi nhật ký, triển khai ACL lên đúng cổng vào của VLAN, thiết bị cho phép hoặc từ chối lưu lượng theo từng luật, sau đó gửi sự kiện về System Logs. Kịch bản tập trung vào ba chính sách cụ thể: chặn Telnet từ VLAN 10 đến địa chỉ `192.168.12.2`, chặn HTTP từ VLAN 20 đến máy chủ `203.162.4.1`, và chặn ICMP từ VLAN 30 đến máy chủ này. Các lưu lượng không khớp luật từ chối phải tiếp tục được chuyển tiếp.

Phép thử được thiết kế theo cặp đối chứng. Mỗi chính sách có một lưu lượng cần bị chặn và một lưu lượng khác cần được phép. Cách kiểm tra này phân biệt trường hợp ACL hoạt động đúng với trường hợp mất kết nối do định tuyến, máy chủ hoặc cấu hình nền chưa hoàn tất.

==== Mô hình và quy hoạch địa chỉ

@fig-k5-topology trình bày mô hình thử nghiệm. `R1` thực hiện định tuyến giữa các VLAN theo mô hình bộ định tuyến dùng một liên kết trung kế trên `GigabitEthernet0/1`; `R2` là bộ định tuyến biên thực hiện NAT; `R3` đóng vai trò ISP và cung cấp dịch vụ HTTP trên `Loopback0`. Ba máy trạm `VPC7`, `VPC8` và `VPC9` lần lượt thuộc VLAN 10, VLAN 20 và VLAN 30. Các liên kết kép giữa ba bộ chuyển mạch được gom kênh; nội dung này tạo hạ tầng kết nối nhưng không phải đối tượng đánh giá của kịch bản ACL.

#figure(
  image("/00_report/Tai_lieu_lab/LAB5/ANH_CUA_LAB/so_do.png", width: 92%),
  caption: [Mô hình kiểm chứng ACL với R1 định tuyến liên VLAN, R2 làm NAT và R3 làm ISP],
) <fig-k5-topology>

#report-table(
  columns: (29%, 35%, 36%),
  header: ([Thành phần], [Địa chỉ], [Vai trò trong phép thử]),
  rows: (
    ([R1 `Gi0/1.10`], [`192.168.10.254/24`], [Cổng mặc định VLAN 10; nhận lưu lượng từ VPC7.]),
    ([R1 `Gi0/1.20`], [`192.168.20.254/24`], [Cổng mặc định VLAN 20; nhận lưu lượng từ VPC8.]),
    ([R1 `Gi0/1.30`], [`192.168.30.254/24`], [Cổng mặc định VLAN 30; nhận lưu lượng từ VPC9.]),
    ([R1 `Gi0/2` - R2 `Gi0/2`], [`192.168.12.2/24` - `192.168.12.1/24`], [Liên kết từ mạng doanh nghiệp đến bộ định tuyến biên.]),
    ([R2 `Gi0/3` - R3 `Gi0/3`], [`203.162.2.1/30` - `203.162.2.2/30`], [Liên kết đến ISP.]),
    ([R3 `Loopback0`], [`203.162.4.1/32`], [Đích ICMP và máy chủ HTTP thử nghiệm.]),
    ([Mạng quản trị], [`192.168.122.0/24`], [CAMS kết nối đến thiết bị; R1 dùng `192.168.122.104` trong lần thử.]),
  ),
  caption: [Quy hoạch địa chỉ liên quan đến Kịch bản 5],
) <tab-k5-address-plan>

Địa chỉ quản trị chỉ phục vụ kết nối CAMS và vận chuyển Syslog, không tham gia điều kiện khớp ACL. Vì vậy, việc R1 mang địa chỉ quản trị `192.168.122.104` trong lần thử không làm thay đổi các chính sách trên các mạng dữ liệu.

==== Chính sách ACL và vị trí áp dụng

Hai ACL mở rộng được cấu hình trên R1. ACL thứ nhất được gắn chiều vào trên `GigabitEthernet0/1.10`. Luật số 10 từ chối TCP từ VLAN 10 đến địa chỉ `192.168.12.2`, cổng đích 23; luật số 20 cho phép các lưu lượng IP còn lại. Tên `ACL_V10_NO_TELNET_R2` được giữ theo dữ liệu thử nghiệm, nhưng đích `192.168.12.2` thuộc cổng `Gi0/2` của R1 trong quy hoạch hiện tại. Do đó, kết quả được diễn giải theo địa chỉ và giao thức thực tế, không suy luận thiết bị đích từ tên ACL.

ACL thứ hai được gắn chiều vào trên `GigabitEthernet0/1.20` và `GigabitEthernet0/1.30`. Luật số 10 từ chối TCP/80 từ VLAN 20 đến máy chủ `203.162.4.1`; luật số 20 từ chối ICMP từ VLAN 30 đến cùng máy chủ; luật số 30 cho phép các lưu lượng IP còn lại. Mỗi luật do CAMS sinh đều có từ khóa `log`, nên Cisco IOS tạo sự kiện `%SEC-6-IPACCESSLOGP` hoặc `%SEC-6-IPACCESSLOGDP` khi có lưu lượng khớp.

#report-table(
  columns: (14%, 21%, 27%, 20%, 18%),
  text-size: 9pt,
  cell-inset: (x: 4pt, y: 4pt),
  header: ([ACL / luật], [Nguồn], [Đích và dịch vụ], [Hành động], [Vị trí]),
  rows: (
    ([V10 / 10], [#table-code("192.168.10.0/24")], [#table-code("192.168.12.2"), TCP/23], [Từ chối; ghi log], [Vào #table-code("Gi0/1.10")]),
    ([V10 / 20], [#table-code("any")], [#table-code("any"), IP], [Cho phép; ghi log], [Vào #table-code("Gi0/1.10")]),
    ([V20-V30 / 10], [#table-code("192.168.20.0/24")], [#table-code("203.162.4.1"), TCP/80], [Từ chối; ghi log], [Vào #table-code("Gi0/1.20") và #table-code("Gi0/1.30")]),
    ([V20-V30 / 20], [#table-code("192.168.30.0/24")], [#table-code("203.162.4.1"), ICMP], [Từ chối; ghi log], [Vào #table-code("Gi0/1.20") và #table-code("Gi0/1.30")]),
    ([V20-V30 / 30], [#table-code("any")], [#table-code("any"), IP], [Cho phép; ghi log], [Vào #table-code("Gi0/1.20") và #table-code("Gi0/1.30")]),
  ),
  caption: [Ma trận chính sách ACL được kiểm chứng],
) <tab-k5-acl-policy>

@fig-k5-acl-applied là bằng chứng cấu hình sau triển khai. Kết quả `show ip interface` xác nhận ACL đã được gắn chiều vào trên ba cổng con. Kết quả `show access-lists` xác nhận đúng địa chỉ nguồn, đích, giao thức, cổng dịch vụ và từ khóa `log`. Hình này thay cho chuỗi ảnh nhập biểu mẫu và thao tác *Push* vì mục tiêu của thử nghiệm là chứng minh cấu hình cuối trên thiết bị.

#figure(
  image("/00_report/Tai_lieu_lab/LAB5/ANH_CUA_LAB/1.png", width: 96%),
  caption: [ACL và vị trí áp dụng trên R1 sau khi triển khai bằng CAMS],
) <fig-k5-acl-applied>

==== Phép thử đối chứng và lưu lượng bị chặn

Trước khi tạo lưu lượng vi phạm, nhóm thử nghiệm dùng VPC7 thuộc VLAN 10 kiểm tra đường truyền tới `203.162.4.1`. ICMP nhận đủ năm phản hồi, còn phép thử TCP/80 hoàn tất các bước kết nối, gửi dữ liệu và đóng kết nối. Hai kết quả trong @fig-k5-positive-control xác nhận định tuyến, NAT và dịch vụ đích đang hoạt động; vì vậy, các kết quả bị chặn ở bước tiếp theo có thể được quy cho ACL tương ứng.

#figure(
  grid(
    columns: (1fr, 1fr),
    gutter: 8pt,
    image("/00_report/Tai_lieu_lab/LAB5/ANH_CUA_LAB/3.png", width: 100%),
    image("/00_report/Tai_lieu_lab/LAB5/ANH_CUA_LAB/4.png", width: 100%),
  ),
  caption: [Phép thử đối chứng từ VLAN 10: ICMP và TCP/80 đến máy chủ ISP đều được phép],
) <fig-k5-positive-control>

Ba phép thử âm được thực hiện từ đúng VLAN nguồn của từng luật. VPC7 gửi TCP đến `192.168.12.2:23`; VPC8 gửi TCP đến `203.162.4.1:80`; VPC9 gửi ICMP đến `203.162.4.1`. Trong cả ba trường hợp, cổng mặc định trên R1 trả về ICMP Type 3 Code 13, *Communication administratively prohibited*. Phản hồi này cho biết bộ định tuyến đã chủ động từ chối lưu lượng theo chính sách, thay vì gói tin hết thời gian chờ do mất đường truyền.

#figure(
  grid(
    columns: (1fr, 1fr),
    gutter: 8pt,
    image("/00_report/Tai_lieu_lab/LAB5/ANH_CUA_LAB/5.png", width: 100%),
    image("/00_report/Tai_lieu_lab/LAB5/ANH_CUA_LAB/6.png", width: 100%),
  ),
  caption: [R1 từ chối Telnet từ VLAN 10 và HTTP từ VLAN 20 theo hai luật ACL],
) <fig-k5-denied-tcp>

#figure(
  image("/00_report/Tai_lieu_lab/LAB5/ANH_CUA_LAB/7.png", width: 88%),
  caption: [R1 từ chối ICMP từ VLAN 30 đến máy chủ `203.162.4.1`],
) <fig-k5-denied-icmp>

Để kiểm tra ACL không chặn quá phạm vi, VPC8 vẫn nhận phản hồi ICMP từ máy chủ ISP và VPC9 vẫn thiết lập được phiên TCP/80. Đồng thời, VPC8 và VPC9 vẫn kết nối được TCP/23 đến `192.168.12.2` vì luật chặn dịch vụ này chỉ áp dụng cho VLAN 10. Các phép thử này xác nhận thứ tự luật và câu lệnh `permit ip any any` hoạt động như dự kiến.

==== Đối chiếu sự kiện trên System Logs

R1 gửi Syslog về CAMS qua mạng quản trị. Chính sách gửi phải bao gồm mức `6 - Informational` vì bản tin ACL trong phép thử có mức độ nghiêm trọng bằng 6. Tại thời điểm chụp @fig-k5-acl-syslog, bộ thu C++ đang lắng nghe trên `0.0.0.0:5514/UDP+TCP` và đã nhận 272 bản tin. Các dòng bằng chứng quan trọng gồm:

- `ACL_V10_NO_TELNET_R2 denied tcp 192.168.10.1(...) -> 192.168.12.2(23)`;
- `ACL_V20_V30_OUT denied tcp 192.168.20.1(...) -> 203.162.4.1(80)`;
- `ACL_V20_V30_OUT denied icmp 192.168.30.1 -> 203.162.4.1`;
- các dòng `permitted` tương ứng với những phép thử đối chứng không thuộc điều kiện từ chối.

#figure(
  image("/00_report/Tai_lieu_lab/LAB5/ANH_CUA_LAB/12.png", width: 100%),
  caption: [System Logs ghi nhận các sự kiện ACL được phép và bị từ chối từ R1],
) <fig-k5-acl-syslog>

Trường `SEC` trong bảng là mã phân hệ Cisco IOS; nhóm nguồn Syslog được tách từ PRI. Với PRI bằng 190 trong các bản tin minh họa, nhóm nguồn Syslog bằng 23 (`local7`) và mức độ nghiêm trọng bằng 6. Việc tách hai trường giúp tránh gọi nhầm `SEC` là nhóm nguồn theo chuẩn Syslog.

==== Đánh giá kết quả

#report-table(
  columns: (16%, 32%, 20%, 32%),
  header: ([Ca thử], [Lưu lượng], [Kết quả], [Bằng chứng]),
  rows: (
    ([ACL-01], [VLAN 10 đến `192.168.12.2`, TCP/23], [Bị từ chối], [ICMP Type 3 Code 13 và nhật ký `denied tcp`.]),
    ([ACL-02], [VLAN 20 đến `203.162.4.1`, TCP/80], [Bị từ chối], [ICMP Type 3 Code 13 và nhật ký `denied tcp`.]),
    ([ACL-03], [VLAN 30 đến `203.162.4.1`, ICMP], [Bị từ chối], [Năm phản hồi `administratively prohibited` và nhật ký `denied icmp`.]),
    ([ACL-04], [VLAN 10 đến `203.162.4.1`, ICMP và TCP/80], [Được phép], [Năm phản hồi ICMP và năm chu kỳ kết nối TCP/80.]),
    ([ACL-05], [VLAN 20/30 với lưu lượng không khớp deny], [Được phép], [ICMP, TCP/23 hoặc TCP/80 hoàn tất; System Logs có dòng `permitted`.]),
  ),
  caption: [Kết quả kiểm chứng chính sách ACL trong Kịch bản 5],
) <tab-k5-acl-results>

Kết quả cho thấy hai ACL được áp dụng đúng chiều trên ba cổng con của R1. Ba lưu lượng khớp luật từ chối đều bị R1 chặn và tạo bản tin Syslog; các lưu lượng đối chứng vẫn được chuyển tiếp. CAMS tiếp nhận, phân tích và hiển thị đúng thiết bị nguồn `192.168.122.104`, mã phân hệ `SEC`, mức độ nghiêm trọng bằng 6, mã sự kiện cùng thông tin địa chỉ và dịch vụ. Phạm vi kết luận giới hạn ở các địa chỉ, giao thức và số lần thử nêu trong bảng; kịch bản chưa đo thông lượng ghi nhật ký hoặc tỷ lệ mất bản tin khi tải cao.
