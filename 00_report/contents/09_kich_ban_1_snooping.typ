#import "../config/tables.typ": report-table

// Chỉ cắt vùng hiển thị khi dàn trang; ảnh gốc không bị thay đổi.
#let snooping-terminal-crop(y, h) = layout(size => {
  let source-width = 2560
  let source-height = 1600
  let x = 0
  let w = 1500
  let scale = size.width / w
  block(width: size.width, height: scale * h, clip: true,
    place(top + left, dx: -x * scale, dy: -y * scale,
      box(width: source-width * scale, height: source-height * scale,
        image(
          "/00_book/figures/report/diagrams/dhcp-snooping-lab/show-snooping-state.png",
          width: 100%, height: 100%, fit: "stretch",
        ))))
})

#let client-result-crop(path) = layout(size => {
  let source-width = 2560
  let source-height = 1600
  let x = 470
  let y = 285
  let w = 700
  let h = 520
  let scale = size.width / w
  block(width: size.width, height: scale * h, clip: true,
    place(top + left, dx: -x * scale, dy: -y * scale,
      box(width: source-width * scale, height: source-height * scale,
        image(path, width: 100%, height: 100%, fit: "stretch"))))
})

=== Kịch bản 1: Kiểm thử DHCP Snooping và Dynamic ARP Inspection

==== Mô hình Lab 1 và mục tiêu kiểm thử DHCP Snooping

Kịch bản kiểm tra trực tiếp trạng thái DHCP Snooping trên SW1 và nguồn cấp địa chỉ cho R2 khi thay đổi cổng tin cậy. R1 cấp dải `192.168.10.0/24`, FAKE_DHCP cấp dải `192.168.66.0/24`, còn R2 đóng vai trò DHCP client. Tiêu chí đạt là lệnh `show` xác nhận dịch vụ hoạt động trên VLAN 10 và địa chỉ R2 nhận được thuộc dải của server nằm sau cổng DHCP trusted.

#figure(image("/00_book/figures/report/diagrams/dhcp-snooping-lab/topology.png", width: 100%), caption: [Mô hình Lab 1 với hai DHCP server, switch SW1 và client R2.]) <fig-k1-topology>

Trong @fig-k1-topology, R1 nối SW1 qua Gi0/1, R2 qua Gi0/2 và FAKE_DHCP qua Gi0/3. Gi0/2 luôn là cổng untrusted; phép thử lần lượt trust Gi0/1 rồi Gi0/3 để đối chiếu nguồn cấp phát. DAI được tắt trong toàn bộ phần này và được kiểm thử riêng ở mục kế tiếp.

#report-table(
 columns: (18%, 24%, 24%, 34%),
 header: ([Thiết bị], [Vai trò], [Cổng dữ liệu], [Địa chỉ / dải cấp phát]),
 rows: (
  ([SW1], [DHCP Snooping VLAN 10], [Gi0/1, Gi0/2, Gi0/3], [Quản trị: 192.168.122.101]),
  ([R1], [DHCP server hợp lệ], [Gi0/1 nối SW1 Gi0/1], [192.168.10.0/24]),
  ([R2], [DHCP client], [Gi0/2 nối SW1 Gi0/2], [Địa chỉ nhận động]),
  ([FAKE\_DHCP], [DHCP server thứ hai], [Gi0/1 nối SW1 Gi0/3], [192.168.66.0/24]),
 ), caption: [Thành phần của bài kiểm thử DHCP Snooping.],
) <tab-k1-topology>

==== Cấu hình tối thiểu và bộ lệnh kiểm tra

Thao tác trên CAMS được rút gọn còn ba việc: bật DHCP Snooping cho VLAN 10, giữ DAI ở trạng thái tắt và chọn đúng một cổng nối DHCP server làm trusted. Sau khi *View & Push* hoàn tất, việc đánh giá chuyển sang terminal bằng các lệnh sau:

```text
show ip dhcp snooping
show running-config interface GigabitEthernet0/1
show running-config interface GigabitEthernet0/3
show ip dhcp snooping statistics
show ip dhcp snooping binding
```

Ảnh terminal tại @fig-k1-show-baseline ghi nhận một mốc trước khi cấp trust cho cổng server. `show ip dhcp snooping` xác nhận chức năng đã được bật, VLAN 10 ở trạng thái configured và operational, đồng thời Option 82 bị tắt. Danh sách trusted trong kết quả còn trống; `show running-config interface GigabitEthernet0/1` chưa có lệnh `ip dhcp snooping trust`. Tại cùng mốc, thống kê ghi nhận 8 gói được chuyển tiếp và 160 gói bị loại bỏ từ các cổng untrusted.

#figure(
  stack(dir: ttb, spacing: 8pt,
    snooping-terminal-crop(340, 540),
    snooping-terminal-crop(1180, 135),
  ),
  caption: [Kết quả lệnh show trên SW1 trước khi cấp trust: DHCP Snooping hoạt động trên VLAN 10, chưa có cổng trusted và bộ đếm drop từ cổng untrusted đã tăng.],
) <fig-k1-show-baseline>

Số 160 là bộ đếm tích lũy tại thời điểm chụp, không đồng nhất với số lần R2 yêu cầu địa chỉ và không dùng để khẳng định từng gói đến từ server nào. Giá trị này chỉ chứng minh SW1 đã loại bỏ lưu lượng DHCP đi vào cổng untrusted. Việc xác định server được chấp nhận được thực hiện bằng hai trạng thái dưới đây.

#report-table(
 columns: (14%, 23%, 23%, 40%),
 header: ([Trạng thái], [SW1 Gi0/1 → R1], [SW1 Gi0/3 → FAKE\_DHCP], [Kết quả mong đợi tại R2]),
 rows: (
  ([A], [Trusted], [Untrusted], [Địa chỉ thuộc 192.168.10.0/24]),
  ([B], [Untrusted], [Trusted], [Địa chỉ thuộc 192.168.66.0/24]),
 ), caption: [Hai trạng thái chính sách dùng để đối chiếu nguồn cấp DHCP.],
) <tab-k1-policy>

==== Trạng thái A: Trust Gi0/1 nối R1

CAMS được dùng để đặt DHCP trust cho Gi0/1. Sau khi đẩy cấu hình, các lệnh trọng tâm là:

```text
SW1# show running-config interface GigabitEthernet0/1
SW1# show ip dhcp snooping
SW1# show ip dhcp snooping binding
R2#  show ip interface brief | include GigabitEthernet0/2
```

Kết quả cần đối chiếu theo thứ tự là: cấu hình Gi0/1 có `ip dhcp snooping trust`; VLAN 10 vẫn operational; bảng binding có bản ghi của R2 trên VLAN 10, cổng Gi0/2; và R2 có địa chỉ DHCP thuộc mạng `192.168.10.0/24`. Ảnh terminal @fig-k1-client-a ghi nhận Gi0/2 của R2 nhận `192.168.10.4`, phương thức `DHCP`, trạng thái `up/up`. Trong một lần cấp lại khác của cùng trạng thái, CAMS đồng bộ địa chỉ `192.168.10.5`; cả hai đều thuộc pool của R1, vì vậy số host cụ thể không phải tiêu chí của phép thử.

#figure(
  image("/00_book/figures/report/diagrams/dhcp-snooping-lab/r2_dhcp_success.png", width: 92%),
  caption: [Kết quả show ip interface brief trên R2: Gi0/2 nhận địa chỉ 192.168.10.4 bằng DHCP và ở trạng thái up/up.],
) <fig-k1-client-a>

Khi cần kiểm tra sâu hơn, `show ip dhcp snooping binding` phải cho thấy MAC của R2, địa chỉ cấp phát, VLAN 10 và cổng `GigabitEthernet0/2`. Đây là bằng chứng quan trọng hơn ảnh nhập liệu vì nó xác nhận switch đã học liên kết DHCP thực tế, không chỉ lưu cấu hình mong muốn trong CAMS.

==== Trạng thái B: Chuyển trust sang Gi0/3 nối FAKE_DHCP

Chính sách được đổi bằng cách bỏ trust trên Gi0/1 và đặt trust trên Gi0/3; Gi0/2 của client vẫn untrusted. R2 được yêu cầu cấp lại địa chỉ để tránh dùng lease cũ. Bộ lệnh đối chiếu không thay đổi, chỉ chuyển cổng cần kiểm tra từ Gi0/1 sang Gi0/3:

```text
SW1# show running-config interface GigabitEthernet0/1
SW1# show running-config interface GigabitEthernet0/3
SW1# show ip dhcp snooping
SW1# show ip dhcp snooping binding
R2#  show ip interface brief | include GigabitEthernet0/2
```

Kết quả đồng bộ tại @fig-k1-client-b cho thấy Gi0/2 của R2 nhận `192.168.66.100/24`. Địa chỉ này thuộc pool `FAKE_TEST` của FAKE_DHCP, phù hợp với việc Gi0/3 đã trở thành cổng trusted. Tên FAKE_DHCP chỉ dùng để nhận diện thiết bị thử nghiệm; quyết định chuyển tiếp của switch phụ thuộc vào trạng thái trust của cổng.

#figure(
  client-result-crop("/00_book/figures/report/diagrams/dhcp-snooping-lab/r2-address-fake.png"),
  caption: [Kết quả sau khi chuyển trust: Gi0/2 của R2 nhận địa chỉ 192.168.66.100/24 từ server nối Gi0/3.],
) <fig-k1-client-b>

==== Tổng hợp kết quả DHCP Snooping

#report-table(
 columns: (14%, 23%, 25%, 38%),
 header: ([Trạng thái], [Cổng DHCP trusted], [Địa chỉ R2 quan sát được], [Đối chiếu bằng lệnh show]),
 rows: (
  ([Ban đầu], [Không có], [Không dùng làm tiêu chí], [`show ip dhcp snooping`: VLAN 10 operational; 160 drop từ untrusted]),
  ([A], [Gi0/1 nối R1], [192.168.10.4; lần cấp khác .5], [IP thuộc pool R1; binding nằm ở VLAN 10, Gi0/2]),
  ([B], [Gi0/3 nối FAKE\_DHCP], [192.168.66.100], [IP thuộc pool FAKE\_TEST sau khi yêu cầu DHCP lại]),
 ), caption: [Kết quả kiểm thử DHCP Snooping theo ba mốc đối chiếu.],
) <tab-k1-results>

Chuỗi lệnh `show` tách ba lớp bằng chứng: dịch vụ trên VLAN, trạng thái trust của cổng và địa chỉ/binding của client. Khi chưa có cổng trusted, bộ đếm drop tăng; khi trust Gi0/1 hoặc Gi0/3, R2 lần lượt nhận địa chỉ thuộc dải của server nối cổng đó.

Kết luận chỉ dựa trên cấu hình, bộ đếm và địa chỉ/binding đã ghi nhận. Số 160 không được gán cho một server cụ thể và không chứng minh có Syslog rogue DHCP. Phần DAI tiếp theo giữ nguyên, được đánh giá riêng bằng ARP, bộ đếm và Syslog.
