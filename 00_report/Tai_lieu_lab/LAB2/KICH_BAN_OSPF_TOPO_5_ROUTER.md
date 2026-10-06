# Lab 2 — OSPF một vùng trên 5 router, 2 switch

Ngày 06/10/2026. Thay thế kịch bản ba router theo quyết định của người dùng. Đây là kế hoạch, chưa phải kết quả đo.

## 1. Topology và phạm vi

Theo ảnh: R1 Gi0/1, R2 Gi0/1 và R3 Gi0/1 cùng nối SW1 (lần lượt Gi0/1, Gi0/2, Gi0/3). R3 Gi0/2 nối R4 Gi0/1; R4 Gi0/2 nối R5 Gi0/2. R1 Gi0/2 nối VPC8; R2 Gi0/2 nối VPC9. R5 Gi0/1 nối SW2 Gi0/1; VPC10/VPC11 nối SW2 Gi0/2/Gi0/3. Gi0/0 các thiết bị nối mạng quản trị qua cloud.

Chỉ thử OSPF process 1, Area 0; không thêm DHCP, NAT, GRE, redistribution, default originate hay chia nhiều area. Hai PC sau SW2 dùng chung một LAN để giảm cấu hình. SW1 dùng một VLAN transit chung; SW2 dùng một VLAN LAN chung. Cổng quản trị của switch phải được tách VLAN với các cổng lab; xác minh SVI quản trị thực tế trước khi chỉnh VLAN. Hai cloud quản trị không được tính thành đường truyền nghiệp vụ.

Ảnh CAMS xác nhận kết nối được 7 thiết bị: R1 .101, R2 .102, R3 .103, R4 .104, R5 .105, SW1 .106, SW2 .107 trên 192.168.122.0/24. Chưa xác nhận mask/cổng/SVI từ CLI. Vì có kết nối quản trị, gọi baseline là “đã có cấu hình quản trị, chưa cấu hình OSPF của bài thử” sau khi kiểm tra, không gọi là cấu hình hoàn toàn rỗng.

## 2. Địa chỉ đề xuất — chưa áp dụng, chưa xác nhận

| Thiết bị | Cổng | IP/mask đề xuất | Vai trò |
|---|---|---|---|
| R1 | Gi0/1 | 10.1.123.1/24 | Transit chung qua SW1 |
| R2 | Gi0/1 | 10.1.123.2/24 | Transit chung qua SW1 |
| R3 | Gi0/1 | 10.1.123.3/24 | Transit chung qua SW1 |
| R3 | Gi0/2 | 10.1.34.1/30 | Nối R4 |
| R4 | Gi0/1 | 10.1.34.2/30 | Nối R3 |
| R4 | Gi0/2 | 10.1.45.1/30 | Nối R5 |
| R5 | Gi0/2 | 10.1.45.2/30 | Nối R4 |
| R1 | Gi0/2 | 192.168.10.1/24 | Gateway VPC8 |
| R2 | Gi0/2 | 192.168.20.1/24 | Gateway VPC9 |
| R5 | Gi0/1 | 192.168.50.1/24 | Gateway VPC10/VPC11 qua SW2 |
| VPC8 | eth0 | 192.168.10.10/24, GW 192.168.10.1 | LAN R1 |
| VPC9 | eth0 | 192.168.20.10/24, GW 192.168.20.1 | LAN R2 |
| VPC10 | eth0 | 192.168.50.10/24, GW 192.168.50.1 | LAN R5 |
| VPC11 | eth0 | 192.168.50.11/24, GW 192.168.50.1 | LAN R5 |

Router ID đặt trực tiếp 1.1.1.1 đến 5.5.5.5; không cần tạo loopback để giảm bước. Giữ nguyên IP quản trị và cấu hình truy cập CAMS. Nếu đã có IP nghiệp vụ, đối chiếu trước khi thay địa chỉ.

## 3. Bước A — xác nhận hiện trạng, rồi tạo nền IP/L2

Trên R1–R5 lưu output và ảnh đọc được:

```text
show ip interface brief
show running-config | section router ospf
show running-config | include ^ip route
show ip route
```

Trên SW1/SW2:

```text
show ip interface brief
show vlan brief
show interfaces switchport
```

Chụp topology sạch và danh sách 7 thiết bị CAMS. Đóng video nổi trước khi chụp. Ảnh đầu running-config hiện tại chưa đủ kết luận các cổng chưa có IP hay chưa có OSPF.

Sau khi xác nhận: cấu hình các IP theo bảng đã chốt, bật cổng lab, đặt VLAN transit riêng trên SW1 và VLAN LAN riêng trên SW2. Giữ cổng/SVI quản trị đúng VLAN hiện có. Không cần trunk/subinterface trong phương án đơn giản này.

Kiểm tra ping trực tiếp: R1↔R2/R3 qua transit chung; R3↔R4; R4↔R5; mỗi PC↔gateway. PC10↔PC11 phải liên lạc trong cùng LAN. Thử PC8→PC10 trước OSPF, ghi đúng kết quả và kiểm tra tuyến có sẵn nếu thành công. Lưu snapshot lab và bản sao dự án CAMS ở trạng thái nền đã hoạt động nhưng chưa có OSPF bài thử; dùng cùng trạng thái này cho phép đo CLI/CAMS.

Ảnh A: topology; connected-devices; interface-brief mỗi router; baseline OSPF/tuyến tĩnh; VLAN từng switch; IP/gateway mỗi PC; ping liên site trước OSPF. Lưu config dạng text cùng ảnh.

## 4. Bước B — khai báo qua CAMS

Chọn nhóm R1–R5, process 1, Router ID theo số router, Area 0. Bật passive mặc định. Chỉ chọn các mạng sau; không chọn mạng quản trị 192.168.122.0/24.

| Router | Mạng quảng bá | Cổng no passive |
|---|---|---|
| R1 | 10.1.123.0/24; 192.168.10.0/24 | Gi0/1 |
| R2 | 10.1.123.0/24; 192.168.20.0/24 | Gi0/1 |
| R3 | 10.1.123.0/24; 10.1.34.0/30 | Gi0/1, Gi0/2 |
| R4 | 10.1.34.0/30; 10.1.45.0/30 | Gi0/1, Gi0/2 |
| R5 | 10.1.45.0/30; 192.168.50.0/24 | Gi0/2 |

Các cổng LAN giữ passive. Reference bandwidth nếu cấu hình phải đồng nhất trên 5 router. Không thêm tùy chọn khác trong phép thử cơ bản. Nếu CAMS yêu cầu Push riêng phần process/network và passive-interface, ghi nhận đầy đủ cả hai lần; không báo là một lần triển khai.

Ảnh B: hosts; identity/common; networks đủ 5 router; passive interfaces từng router.

## 5. Bước C — preview và Push

Chụp/lưu preview cả 5 router. So sánh IP, wildcard (/24: 0.0.0.255; /30: 0.0.0.3), Area, Router ID, passive và no-passive với bảng. Không có network bao phủ Gi0/0 quản trị, redistribute connected hay default originate. Nếu preview khác lựa chọn UI, lưu bằng chứng lỗi và sửa trước khi Push.

Ghi thời điểm bắt đầu/kết thúc Push và trạng thái từng host, kể cả lỗi. Chụp kết quả tổng và từng host cần thiết. Trạng thái SYNC của CAMS phải đi kèm xác minh CLI và ping.

## 6. Bước D — xác minh thực tế

Trên cả 5 router:

```text
show running-config | section router ospf
show ip ospf neighbor
show ip ospf interface brief
show ip route ospf
```

R1/R2/R3 có 2 neighbor trên LAN transit SW1; R3 có thêm R4, R4 có R3/R5, R5 có R4. Trên Ethernet broadcast, quan hệ giữa hai DROTHER có thể ở 2-WAY bình thường; không lấy “tất cả neighbor FULL” làm điều kiện bắt buộc. Đọc vai trò DR/BDR và trạng thái thực tế. Xác minh có tuyến O tới các LAN ở xa và không chạy OSPF trên cổng quản trị. Tuyến C/L của mạng quản trị là bình thường.

Ping có số gói cố định và lưu thống kê: PC8↔PC10, PC9↔PC11, PC8↔PC9. Ghi riêng lần làm nóng ARP nếu có; không bỏ mất gói rồi báo thành công tuyệt đối. Trace PC8→PC10 và ghi các hop thực tế. Không gọi ping PC10↔PC11 là bằng chứng OSPF vì hai PC cùng subnet.

Ảnh D: config/neighbor/interface/routes từng router; 6 chiều ping; trace. Chụp riêng từng terminal đủ lớn, giữ ảnh thô rồi chọn sau.

## 7. Bước E — lỗi và định lượng

- Thử đầu vào không hợp lệ (ví dụ Router ID 1.1.1.999), ghi đúng phản hồi CAMS; không Push cấu hình sai.
- Trên bản sao baseline, ngắt riêng đường quản trị của một router để kiểm tra Push tới host không truy cập được. Giữ console EVE để phục hồi. Ghi cấu hình thực tế trên các host còn lại, thông báo lỗi và kết quả thử lại. Phân biệt lỗi đã ngắt trước Push với lỗi xảy ra trong Push.
- Nếu thử ngắt R4–R5, mô hình này không có đường nghiệp vụ dự phòng: chỉ đánh giá mất tuyến/kết nối và phục hồi sau nối lại, không gọi là chuyển tuyến dự phòng.
- Đo CLI và CAMS từ cùng baseline IP/L2, cùng 5 router và cấu hình OSPF cuối giống nhau. Đề xuất 5 lần mỗi phương pháp; tách thời gian thao tác cấu hình, thời gian Push và thời gian kiểm tra. Ghi rõ CLI gõ tay hay dán lệnh. Đếm click/ô nhập của CAMS và lệnh CLI riêng, không trộn thành một đơn vị không định nghĩa.
- Bảng đo CSV đã tạo có thể dùng tiếp; cập nhật số thiết bị thực nghiệm thành 5 khi điền. Các bảng hiện để trống kết quả; danh sách ca kiểm thử cũ cần điều chỉnh theo topology này trước khi dùng.

## 8. Chọn ảnh đưa vào báo cáo

Thu đủ ảnh A–E trước. Khi viết báo cáo chọn khoảng 7–9 hình: topology/bảng IP, khai báo nhóm, network/passive, preview, Push, neighbor, tuyến, ping/trace và trường hợp lỗi. Kèm bảng số liệu CLI/CAMS. Không thay ảnh cũ bằng ảnh kế hoạch hoặc kết quả chưa thực hiện.
