#import "../config/tables.typ": report-table, table-code
#import "../config/commands.typ": step-title

=== Kịch bản 2: Triển khai OSPF một vùng trên năm bộ định tuyến bằng Routing Group

==== Mục tiêu và quy hoạch địa chỉ IP

Kịch bản kiểm tra khả năng cấu hình OSPFv2 theo nhóm trên năm bộ định tuyến bằng CAMS, thiết lập quan hệ láng giềng, học tuyến tới các mạng LAN và truyền thông hai chiều giữa các máy trạm. Toàn bộ mạng nghiệp vụ tham gia vùng OSPF 0; mạng quản trị được loại khỏi các khai báo OSPF. Các mạng LAN và Loopback được quảng bá bằng lệnh `network`; kịch bản này không sử dụng tái phân phối tuyến.

#figure(
  image("/00_book/figures/report/diagrams/ospf-lab2-five-routers/topology-redrawn.svg", width: 100%),
  caption: [Mô hình thử nghiệm OSPF một vùng gồm năm bộ định tuyến, hai bộ chuyển mạch và bốn máy trạm (vẽ lại từ topology EVE-NG)],
) <fig-topo-scenario-2>

Trong @fig-topo-scenario-2, `R1`, `R2` và `R3` nối vào một mạng trung chuyển chung qua `SW1`. `R3` nối `R4`, còn `R4` nối `R5`. `VPC8` và `VPC9` nối trực tiếp tới các cổng LAN của `R1` và `R2`; `VPC10` và `VPC11` thuộc cùng LAN phía sau `R5`, kết nối qua `SW2`. Các đám mây mạng trong sơ đồ cung cấp kết nối quản trị tới CAMS, không được tính là liên kết chuyển tiếp lưu lượng giữa các LAN của bài thử.

#report-table(
  columns: (13%, 26%, 29%, 32%),
  text-size: 9pt,
  cell-inset: (x: 4pt, y: 5pt),
  header: ([Thiết bị], [Cổng], [Địa chỉ], [Vai trò]),
  rows: (
    ([R1], [Gi0/1], [10.1.123.1/24], [Mạng trung chuyển qua SW1]),
    ([R1], [Gi0/2], [192.168.10.1/24], [Cổng mặc định của VPC8]),
    ([R2], [Gi0/1], [10.1.123.2/24], [Mạng trung chuyển qua SW1]),
    ([R2], [Gi0/2], [192.168.20.1/24], [Cổng mặc định của VPC9]),
    ([R3], [Gi0/1], [10.1.123.3/24], [Mạng trung chuyển qua SW1]),
    ([R3], [Gi0/2], [10.1.34.1/24], [Nối R4 Gi0/1]),
    ([R4], [Gi0/1], [10.1.34.2/24], [Nối R3 Gi0/2]),
    ([R4], [Gi0/2], [10.1.45.1/24], [Nối R5 Gi0/2]),
    ([R5], [Gi0/2], [10.1.45.2/24], [Nối R4 Gi0/2]),
    ([R5], [Gi0/1], [192.168.50.1/24], [Cổng mặc định của VPC10/VPC11 qua SW2]),
    ([R1–R5], [Loopback0], [1.1.1.1/32 đến 5.5.5.5/32], [Địa chỉ theo số bộ định tuyến]),
    ([R1–R5], [Gi0/0], [192.168.122.101–105/24], [Quản trị; không tham gia OSPF]),
    ([SW1/SW2], [Địa chỉ quản trị], [192.168.122.106/107], [Kết nối CAMS]),
  ),
  caption: [Địa chỉ và vai trò cổng bộ định tuyến trong kịch bản 2],
) <tab-ip-planning-lab2>

Các liên kết `10.1.34.0` và `10.1.45.0` sử dụng tiền tố `/24` theo cấu hình thử nghiệm. Địa chỉ máy trạm và cổng mặc định được trình bày trong @tab-k2-vpcs; `VPC10` và `VPC11` thuộc cùng mạng con nên phép thử ICMP giữa hai máy này không được dùng làm bằng chứng định tuyến OSPF.

#report-table(
  columns: (20%, 40%, 40%),
  header: ([Máy trạm], [Địa chỉ IP], [Cổng mặc định]),
  rows: (
    ([VPC8], [192.168.10.10/24], [192.168.10.1]),
    ([VPC9], [192.168.20.10/24], [192.168.20.1]),
    ([VPC10], [192.168.50.10/24], [192.168.50.1]),
    ([VPC11], [192.168.50.11/24], [192.168.50.1]),
  ),
  caption: [Địa chỉ máy trạm dùng trong các phép thử liên LAN],
) <tab-k2-vpcs>

==== Quy trình triển khai trên CAMS

#step-title[Bước 1. Kiểm tra trạng thái ban đầu và kết nối nền]

Trước khi cấu hình mạng nghiệp vụ, kết quả `show ip interface brief` trên năm bộ định tuyến cho thấy cổng quản trị `Gi0/0` và `Loopback0` đã hoạt động, còn các cổng nghiệp vụ chưa được gán địa chỉ IP và đang ở trạng thái `shutdown`. Các lệnh `show running-config | section router ospf` và `show running-config | include ^ip route` không trả về cấu hình tương ứng; bảng định tuyến chỉ có các mạng kết nối trực tiếp và không có tuyến mặc định. Vì vậy, trạng thái ban đầu là thiết bị đã có kết nối quản trị và Loopback, nhưng chưa triển khai OSPF của bài thử.

Sau khi gán địa chỉ cho các cổng nghiệp vụ và máy trạm, cả bốn máy trạm đều nhận đủ năm hồi đáp khi kiểm tra kết nối tới cổng mặc định. Phép thử từ `VPC8` tới `10.1.34.1` trước khi triển khai OSPF nhận thông báo `Destination host unreachable` từ cổng mặc định `192.168.10.1`; sau khi triển khai, cùng đích này trả về đủ năm hồi đáp. Đây là phép đối chứng khả năng truy cập mạng ở xa trước và sau khi cấu hình định tuyến.

#step-title[Bước 2. Chọn nhóm bộ định tuyến và khai báo tiến trình]

Trong không gian làm việc `LAB_2`, quản trị viên mở *Routing → OSPF → Routing Group*, chọn `R1` đến `R5` tại các địa chỉ quản trị `.101` đến `.105`. Hai bộ chuyển mạch không tham gia nhóm định tuyến.

#figure(
  image("/00_book/figures/report/diagrams/ospf-lab2-five-routers/group-hosts.png", width: 85%),
  caption: [Chọn năm bộ định tuyến tham gia Routing Group OSPF trên CAMS],
) <fig-k2-group-hosts>

Ở bước *Identity*, *Process ID* được đặt là `1` trên cả năm bộ định tuyến; *Router ID* lần lượt là `1.1.1.1`, `2.2.2.2`, `3.3.3.3`, `4.4.4.4` và `5.5.5.5`. Mỗi bộ định tuyến có một *Router ID* riêng. Trong bài thử, các địa chỉ Loopback trùng giá trị *Router ID* cũng được chọn quảng bá dưới dạng `/32`.

#step-title[Bước 3. Chọn mạng trong vùng 0 và thiết lập cổng thụ động]

Tại bước *Networks*, các mạng trung chuyển, LAN và Loopback được chọn vào vùng 0. Mạng quản trị `192.168.122.0/24` được bỏ chọn. Cấu hình đang chạy trên cả năm bộ định tuyến được đối chiếu lại để xác nhận chỉ có các mạng nghiệp vụ và Loopback trong các lệnh `network`.

#figure(
  image("/00_book/figures/report/diagrams/ospf-lab2-five-routers/group-networks.png", width: 85%),
  caption: [Khai báo mạng của R1 và R2 trong vùng OSPF 0, loại mạng quản trị khỏi lựa chọn],
) <fig-k2-group-networks>

#report-table(
  columns: (12%, 57%, 31%),
  text-size: 9pt,
  cell-inset: (x: 4pt, y: 5pt),
  header: ([Bộ định tuyến], [Mạng tham gia vùng 0], [Cổng không thụ động]),
  rows: (
    ([R1], [10.1.123.0/24; 192.168.10.0/24; 1.1.1.1/32], [Gi0/1]),
    ([R2], [10.1.123.0/24; 192.168.20.0/24; 2.2.2.2/32], [Gi0/1]),
    ([R3], [10.1.123.0/24; 10.1.34.0/24; 3.3.3.3/32], [Gi0/1, Gi0/2]),
    ([R4], [10.1.34.0/24; 10.1.45.0/24; 4.4.4.4/32], [Gi0/1, Gi0/2]),
    ([R5], [10.1.45.0/24; 192.168.50.0/24; 5.5.5.5/32], [Gi0/2]),
  ),
  caption: [Mạng OSPF và ngoại lệ cổng thụ động trên năm bộ định tuyến],
) <tab-k2-networks>

Các bộ định tuyến sử dụng `passive-interface default`. Quản trị viên bổ sung ngoại lệ `no passive` cho các cổng nối bộ định tuyến theo @tab-k2-networks. Các cổng LAN và Loopback giữ trạng thái thụ động: mạng vẫn được quảng bá nhưng không thiết lập quan hệ láng giềng trên các cổng này.

#step-title[Bước 4. Xem trước lệnh và áp dụng cấu hình]

Quản trị viên kiểm tra lệnh trong *View & Push* trước khi áp dụng. Phần xem trước của giai đoạn khai báo nhóm có `passive-interface default`; các ngoại lệ được bổ sung trong mục *Passive iface*. Cấu hình sau cùng phải được kiểm tra trên thiết bị, thay vì chỉ dựa vào trạng thái `SYNC` trên giao diện. Khối dưới đây được đối chiếu từ `running-config` thực tế của `R3` sau khi hoàn tất cấu hình:

```text
router ospf 1
 router-id 3.3.3.3
 passive-interface default
 no passive-interface GigabitEthernet0/1
 no passive-interface GigabitEthernet0/2
 network 3.3.3.3 0.0.0.0 area 0
 network 10.1.34.0 0.0.0.255 area 0
 network 10.1.123.0 0.0.0.255 area 0
```

==== Xác minh cấu hình và kết quả thử nghiệm

#step-title[Bước 5. Đối chiếu quan hệ láng giềng và tuyến OSPF trên bộ định tuyến]

Trên cả năm bộ định tuyến, quản trị viên chạy ba lệnh: `show running-config | section router ospf`, `show ip ospf neighbor` và `show ip route ospf`. Kết quả xác nhận tiến trình 1, vùng 0, *Router ID* và các ngoại lệ cổng thụ động đúng với bảng quy hoạch. Trong lần kiểm tra được ghi nhận, toàn bộ quan hệ láng giềng hiển thị trạng thái `FULL`.

#figure(
  image("/00_book/figures/report/diagrams/ospf-lab2-five-routers/verify-r1.png", width: 95%),
  caption: [Cấu hình, hai quan hệ láng giềng FULL và các tuyến OSPF trên R1],
) <fig-k2-verify-r1>

Trong @fig-k2-verify-r1, `R1` có láng giềng `R2` tại `10.1.123.2` và `R3` tại `10.1.123.3`. Trên mạng trung chuyển chung, kết quả thu được xác định `R3` là bộ định tuyến được chỉ định (DR) và `R2` là bộ định tuyến được chỉ định dự phòng (BDR). `R1` học LAN `192.168.20.0/24` qua `R2` với giá trị `[110/2]`, và LAN `192.168.50.0/24` qua `R3` với `[110/4]`; trong đó `110` là khoảng cách quản trị và số còn lại là chi phí OSPF của tuyến.

#figure(
  image("/00_book/figures/report/diagrams/ospf-lab2-five-routers/verify-r3.png", width: 95%),
  caption: [R3 có ba quan hệ láng giềng FULL và học các LAN ở hai phía của mô hình mạng],
) <fig-k2-verify-r3>

`R3` có hai láng giềng qua `SW1` và một láng giềng là `R4` trên `Gi0/2`. Tuyến tới LAN `192.168.50.0/24` có chặng kế tiếp `10.1.34.2`; các tuyến tới LAN `192.168.10.0/24` và `192.168.20.0/24` lần lượt đi qua `R1` và `R2`.

#figure(
  image("/00_book/figures/report/diagrams/ospf-lab2-five-routers/verify-r5.png", width: 95%),
  caption: [R5 thiết lập quan hệ láng giềng với R4 và học tuyến trở về các LAN của R1, R2],
) <fig-k2-verify-r5>

Kết quả trên `R5` xác nhận láng giềng `R4` tại `10.1.45.1`, đồng thời có các tuyến `O` tới `192.168.10.0/24` và `192.168.20.0/24` với `[110/4]` qua cùng chặng kế tiếp. Kết quả của `R2` và `R4` cũng được thu trong bộ bằng chứng: `R2` có hai láng giềng, còn `R4` có láng giềng `R3` và `R5`. Các LAN được học dưới dạng tuyến nội vùng `O`, phù hợp với mô hình OSPF một vùng @rfc2328.

#step-title[Bước 6. Kiểm tra truyền thông hai chiều giữa các LAN]

Sáu phép thử ICMP giữa ba cặp máy trạm được ghi nhận trong @tab-k2-ping-results. Mỗi phép thử có năm gói và hiển thị đủ năm phản hồi Echo Reply; không có gói hết thời gian chờ trong các loạt này.

#report-table(
  columns: (20%, 36%, 22%, 22%),
  header: ([Nguồn], [Đích], [Số gói thử], [Hồi đáp]),
  rows: (
    ([VPC8], [VPC10: 192.168.50.10], [5], [5/5]),
    ([VPC10], [VPC8: 192.168.10.10], [5], [5/5]),
    ([VPC9], [VPC11: 192.168.50.11], [5], [5/5]),
    ([VPC11], [VPC9: 192.168.20.10], [5], [5/5]),
    ([VPC8], [VPC9: 192.168.20.10], [5], [5/5]),
    ([VPC9], [VPC8: 192.168.10.10], [5], [5/5]),
  ),
  caption: [Kết quả các phép thử ICMP hai chiều giữa các mạng LAN trong kịch bản 2],
) <tab-k2-ping-results>

#figure(
  image("/00_book/figures/report/diagrams/ospf-lab2-five-routers/ping-pc8-pc10.png", width: 100%),
  caption: [VPC8 nhận đủ năm hồi đáp ICMP từ VPC10 ở LAN phía sau R5],
) <fig-k2-ping-pc8-pc10>

Kết quả 5/5 chỉ mô tả từng loạt thử đã ghi nhận, không được suy rộng thành tỷ lệ thành công của mọi lần triển khai. Thời gian khứ hồi (RTT) có biến động: phép thử từ `VPC10` về `VPC8` có một hồi đáp `593.906 ms`; vì vậy, bộ số liệu này được dùng để xác minh kết nối, chưa dùng để kết luận hiệu năng hoặc độ trễ ổn định của hệ thống.

#step-title[Bước 7. Xác minh đường đi bằng phép truy vết]

Lệnh `trace 192.168.50.10` trên `VPC8` ghi nhận lần lượt các địa chỉ `192.168.10.1`, `10.1.123.3`, `10.1.34.2`, `10.1.45.2` và đích `192.168.50.10`. Đường đi tương ứng là `VPC8 → R1 → R3 → R4 → R5 → VPC10`, phù hợp với mô hình mạng và các chặng kế tiếp đã đọc từ bảng định tuyến.

Các chặng được chép lại từ ảnh đầu cuối để giữ kết quả dễ đọc:

```text
VPCS> trace 192.168.50.10
1  192.168.10.1   4.058 ms  0.679 ms  0.955 ms
2  10.1.123.3     3.468 ms  2.642 ms  2.375 ms
3  10.1.34.2      5.204 ms  3.443 ms  4.013 ms
4  10.1.45.2      4.233 ms  4.458 ms  4.512 ms
5  *192.168.50.10 6.844 ms
   ICMP type:3, code:3, Destination port unreachable
```

Ở chặng cuối, chính `VPC10` trả về `ICMP type 3, code 3: Destination port unreachable`. Đây là phản hồi kết thúc bình thường của phép truy vết sử dụng UDP tới cổng không mở ở đích, xác nhận gói thăm dò đã tới máy đích; không phải lỗi thiếu tuyến @ciscoTracerouteGuide. Kết quả phản hồi ICMP Echo Reply tới cùng đích cung cấp phép kiểm tra bổ sung về kết nối.

==== So sánh thao tác CLI và CAMS

Trong phạm vi cấu hình OSPF đồng loạt trên năm bộ định tuyến của bài thử, CAMS tập trung thao tác chọn thiết bị, hiển thị mạng kết nối trực tiếp và sinh lệnh CLI từ biểu mẫu. Nhận định về sự thuận tiện chỉ dựa trên quy trình cùng ảnh thử nghiệm, chưa phải kết quả đo thời gian thao tác hoặc khảo sát người dùng.

Để làm rõ khối lượng cấu hình, phần này sử dụng *ước tính theo quy trình*. Cơ sở tính là cấu hình OSPF cuối đã xác nhận trên năm bộ định tuyến và các biểu mẫu CAMS trong bộ ảnh thử nghiệm. Phạm vi bắt đầu sau khi địa chỉ IP, kết nối quản trị và mạng nền đã hoạt động; không tính việc dựng mô hình mạng, cấu hình bộ chuyển mạch, đăng nhập, sửa lỗi hoặc xác minh kết quả. Hai phương pháp cần tạo cùng cấu hình cuối: tiến trình 1, *Router ID* riêng, vùng 0, chế độ thụ động mặc định và các ngoại lệ trên cổng nối bộ định tuyến.

Đối với CLI, mô hình ước tính giả định quản trị viên đã ở chế độ thực thi đặc quyền trên mỗi bộ định tuyến và gửi các dòng lệnh trực tiếp. Mỗi bộ định tuyến cần một lệnh `configure terminal`, một lệnh `router ospf 1`, một lệnh `router-id`, một lệnh `passive-interface default`, ba lệnh `network`, một lệnh `end` và một lệnh `write memory`. Đây là chín dòng trên mỗi bộ định tuyến, chưa tính các ngoại lệ cổng thụ động. R1, R2 và R5 có một ngoại lệ trên mỗi thiết bị; R3 và R4 có hai ngoại lệ trên mỗi thiết bị. Tổng số dòng lệnh dự kiến là:

```text
5 × 9 + (1 + 1 + 2 + 2 + 1) = 52 dòng lệnh CLI
```

Con số 52 có thể kiểm đếm từ danh sách lệnh, nhưng không đại diện cho số phím bấm hoặc thời gian thực hiện. Nếu chuẩn bị sẵn cấu hình và dán nhiều dòng cùng lúc, số lần tương tác với đầu cuối sẽ khác. Không cần lệnh `reference-bandwidth` riêng khi giữ giá trị mặc định 100 Mbps như trong cấu hình bài thử.

#report-table(
  columns: (29%, 31%, 40%),
  text-size: 9pt,
  cell-inset: (x: 5pt, y: 5pt),
  header: ([Hạng mục], [CLI: số dòng dự kiến], [CAMS: khai báo dự kiến]),
  rows: (
    ([Chọn thiết bị], [Thực hiện trên 5 đầu cuối; không tính lệnh đăng nhập], [Chọn 5 bộ định tuyến trong Routing Group]),
    ([Tiến trình và Router ID], [5 lệnh `router ospf`; 5 lệnh `router-id`], [5 giá trị Process ID và 5 giá trị Router ID; có thể giữ Process ID đã điền sẵn]),
    ([Thụ động mặc định], [5 lệnh `passive-interface default`], [Một lựa chọn chung cho nhóm]),
    ([Mạng và vùng], [15 lệnh `network`, mỗi lệnh gắn vùng 0], [15 mạng được chọn; kiểm tra vùng 0 trên mỗi mạng]),
    ([Ngoại lệ cổng thụ động], [7 lệnh `no passive-interface`], [7 mục ngoại lệ trên 5 trang thiết bị; mỗi mục cần chọn cổng, đặt *no passive* và thêm mục]),
    ([Vào/thoát chế độ và lưu], [5 lệnh `configure terminal`; 5 lệnh `end`; 5 lệnh `write memory`], [Thao tác lưu và *View & Push* trên giao diện; không quy đổi thành dòng CLI]),
  ),
  caption: [Ước tính khai báo cho cấu hình OSPF tương đương trên năm bộ định tuyến, chưa đo trực tiếp],
) <tab-k2-estimated-effort>

Các số lượng phía CAMS là số thiết bị, giá trị, mạng và mục cấu hình cần xử lý theo quy trình; không phải tổng số lần nhấp đã quan sát. Chọn một mạng và gửi một dòng CLI là hai loại tương tác khác nhau nên bảng không quy đổi chúng thành phần trăm giảm thao tác. Đối với các ô đã có giá trị mặc định, người dùng có thể kiểm tra và giữ nguyên.

CAMS có ba lợi ích trực tiếp trong quy trình này. Thứ nhất, danh sách năm bộ định tuyến và các mạng kết nối trực tiếp được hiển thị trong cùng biểu mẫu nhóm, giúp quản trị viên kiểm tra phạm vi cấu hình mà ít phải chuyển qua từng đầu cuối. Thứ hai, tại bước *Networks*, tên cổng, tiền tố và vùng OSPF được trình bày cùng nhau; người dùng có thể bỏ chọn mạng quản trị `192.168.122.0/24` trước khi áp dụng. Thứ ba, phần mềm sinh cú pháp `network`, mặt nạ ký tự đại diện và các lệnh OSPF từ dữ liệu khai báo, giảm phần cú pháp mà người dùng phải tự soạn và ghi nhớ. Cửa sổ *View & Push* cho phép kiểm tra lệnh được sinh trước khi gửi xuống thiết bị. Những đặc điểm này hỗ trợ việc rà soát và giảm công việc nhập lặp; bộ thử hiện tại chưa đo tỷ lệ lỗi để kết luận mức giảm sai sót thực tế.

CLI có ưu thế về tính linh hoạt: quản trị viên thành thạo có thể dùng khối cấu hình đã chuẩn bị để dán vào đầu cuối, chỉnh các tùy chọn ngoài biểu mẫu và thực hiện lệnh chẩn đoán chi tiết. Trong chính bài thử, các lệnh `show` vẫn được dùng để xác minh kết quả của CAMS. Vì vậy, lợi thế của CAMS rõ hơn ở bước khai báo cấu hình theo nhóm; CLI tiếp tục phù hợp với việc kiểm tra và xử lý chuyên sâu.

Các ngoại lệ cổng thụ động trên CAMS vẫn cần xử lý trên từng bộ định tuyến. Bộ ảnh ghi nhận khai báo nhóm và ngoại lệ ở các bước riêng, nên chưa có cơ sở coi toàn bộ cấu hình hoàn thành bằng một lần *Push*. Số dòng CLI dự kiến và số mục khai báo trên giao diện cũng chưa đủ để xác định phương pháp nào hoàn thành nhanh hơn; điều này còn phụ thuộc vào việc gõ hay dán lệnh, mức độ thành thạo và thời gian phản hồi của thiết bị.

==== Đánh giá kết quả

Kịch bản xác minh CAMS hỗ trợ khai báo OSPF theo nhóm trên năm bộ định tuyến, chọn mạng tham gia vùng 0 và thiết lập ngoại lệ cổng thụ động. Cấu hình đang chạy, quan hệ láng giềng và bảng định tuyến trên thiết bị nhất quán với quy hoạch mạng nghiệp vụ; các LAN ở xa được học bằng OSPF và sáu phép thử ICMP hai chiều đều nhận đủ năm hồi đáp trong mỗi loạt. Phép truy vết xác nhận đường đi qua chuỗi bộ định tuyến theo mô hình thử nghiệm.

Về thao tác quản trị, CAMS tập trung thông tin thiết bị và mạng, hỗ trợ chọn phạm vi quảng bá trực quan và sinh cú pháp cấu hình. Các chức năng này giảm phần cú pháp người dùng phải ghi nhớ và hỗ trợ rà soát tham số trên nhiều bộ định tuyến. CLI có lợi thế khi cần tùy chỉnh linh hoạt hoặc chẩn đoán chuyên sâu, đồng thời vẫn đóng vai trò xác minh trạng thái thiết bị sau triển khai.

Kết luận về sự thuận tiện được giới hạn ở quy trình của bài thử, không đồng nghĩa CAMS luôn nhanh hơn CLI. Bảng ước tính cung cấp cơ sở kiểm đếm cấu hình, còn mức tiết kiệm thời gian, tỷ lệ giảm lỗi và khả năng phục hồi cần phép đo riêng. Kịch bản hiện tại chưa đo thời gian cấu hình hoặc hội tụ, và chưa kiểm thử lỗi triển khai.
