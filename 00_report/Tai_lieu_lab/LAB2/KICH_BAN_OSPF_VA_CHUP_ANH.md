# Lab 2: Triển khai OSPF một vùng trên ba router bằng CAMS

> Đã thay thế theo quyết định đổi topology ngày 06/10/2026. Dùng `KICH_BAN_OSPF_TOPO_5_ROUTER.md` cho lần thực nghiệm mới. Giữ tài liệu này để tham chiếu; không dùng bảng IP/cổng bên dưới cho topo mới.

Ngày lập: 06/10/2026. Đây là kịch bản thực hiện và thu bằng chứng, chưa phải kết quả thực nghiệm.

## 1. Phạm vi và điều kiện bắt đầu

Mô hình theo ảnh người dùng: R1 Gi0/2 nối R2 Gi0/2; R2 Gi0/3 nối R3 Gi0/3. R1 Gi0/1 nối SW1 Gi0/3; SW2 phục vụ VPC7, SW3 phục vụ VPC8/VPC9; R3 Gi0/1 nối VPC10. SW1/SW2/SW3 có các liên kết dự phòng như sơ đồ. Gi0/0 của các thiết bị dùng cho mạng quản trị.

Chỉ thử OSPF Area 0, quảng bá LAN bằng network, passive mặc định và mở đúng cổng router-router. Không dùng redistribute connected, default originate, NAT, DHCP, GRE hay GLBP trong bài này. VLAN/trunk/STP và địa chỉ IP là điều kiện nền, không tính thành kết quả do OSPF tạo ra.

Ảnh CAMS có 0 process chỉ chứng minh dữ liệu đang hiển thị chưa có tiến trình; phải kiểm tra running-config trên từng router để xác nhận baseline thực tế.

Chụp ảnh gốc theo từng mốc, không ghi đè. Đóng cửa sổ video nổi và đợi thông báo chụp màn hình biến mất trước khi chụp tiếp. Mỗi terminal cần thấy hostname, lệnh và toàn bộ kết quả quan trọng. Không ghép nhiều terminal chữ nhỏ ở giai đoạn thu ảnh.

## 2. Bảng IP và cổng

IP quản trị dưới đây lấy từ ảnh CAMS. IP nghiệp vụ dưới đây là **phương án đề xuất**, chưa được xác nhận từ hai ảnh hiện tại. Nếu đã có IP nghiệp vụ, xuất show ip interface brief và sửa bảng cho khớp trước khi chạy; không tự coi địa chỉ trong bảng là trạng thái thiết bị.

| Thiết bị | Cổng | IP đề xuất | Vai trò |
|---|---|---|---|
| R1 | Gi0/0 | 192.168.122.104/24 | Quản trị, không đưa vào OSPF |
| R1 | Gi0/2 | 10.1.12.1/24 | Nối R2, OSPF active |
| R1 | Gi0/1.10 | 192.168.10.1/24 | Gateway VLAN 10, passive |
| R1 | Gi0/1.20 | 192.168.20.1/24 | Gateway VLAN 20, passive |
| R1 | Gi0/1.30 | 192.168.30.1/24 | Gateway VLAN 30, passive |
| R1 | Loopback0 | 1.1.1.1/32 | Router ID, quảng bá passive |
| R2 | Gi0/0 | 192.168.122.105/24 | Quản trị, không đưa vào OSPF |
| R2 | Gi0/2 | 10.1.12.2/24 | Nối R1, OSPF active |
| R2 | Gi0/3 | 10.1.23.1/24 | Nối R3, OSPF active |
| R2 | Loopback0 | 2.2.2.2/32 | Router ID, quảng bá passive |
| R3 | Gi0/0 | 192.168.122.106/24 | Quản trị, không đưa vào OSPF |
| R3 | Gi0/3 | 10.1.23.2/24 | Nối R2, OSPF active |
| R3 | Gi0/1 | 192.168.40.1/24 | Gateway VPC10, passive |
| R3 | Loopback0 | 3.3.3.3/32 | Router ID, quảng bá passive |
| SW1/SW2/SW3 | Cổng/SVI quản trị hiện có | 192.168.122.101/.102/.103 | Kết nối CAMS; không tham gia nhóm OSPF |
| VPC7 | eth0 | 192.168.10.10/24, GW 192.168.10.1 | SW2 Gi1/0 access VLAN 10 |
| VPC8 | eth0 | 192.168.20.10/24, GW 192.168.20.1 | SW3 Gi1/2 access VLAN 20 |
| VPC9 | eth0 | 192.168.30.10/24, GW 192.168.30.1 | SW3 Gi1/3 access VLAN 30 |
| VPC10 | eth0 | 192.168.40.10/24, GW 192.168.40.1 | LAN của R3 |

Loopback /32 là đề xuất. Nếu hiện đã dùng loopback /24, ghi đúng prefix thực tế và kết quả được discovery hiển thị; không trộn /24 trong ảnh với /32 trong bảng.

Trunk từ SW1 đến R1 và đường qua các switch phải mang VLAN 10/20/30. Với liên kết switch dự phòng, giữ STP/EtherChannel đúng cấu hình đang có; không yêu cầu tất cả liên kết đều forwarding. Giữ cấu hình L2 ổn định trong toàn bộ phép đo OSPF.

## 3. Giai đoạn A — ghi baseline và xác minh mạng nền

1. Chụp sơ đồ toàn mạng, danh sách thiết bị CAMS và trang OSPF ban đầu.
2. Trên cả ba router, chạy và lưu kết quả:

```text
show ip interface brief
show running-config | section router ospf
show ip ospf neighbor
show ip route
```

3. Trên các switch khi cần xác minh VLAN/trunk:

```text
show vlan brief
show interfaces trunk
show spanning-tree vlan 10
show spanning-tree vlan 20
show spanning-tree vlan 30
show etherchannel summary
```

4. Mỗi VPCS dùng show ip và ping gateway của chính nó. R1 ping 10.1.12.2; R2 ping 10.1.23.2. Các kết nối trực tiếp phải hoạt động trước khi thử OSPF.
5. Thử VPC7 ping VPC10 trước OSPF. Ghi đúng kết quả; nếu đã thành công, tìm tuyến tĩnh/default/OSPF cũ làm đường thay thế trước khi dùng phép thử làm đối chứng.
6. Lưu snapshot baseline của lab và bản sao dự án CAMS. Baseline gồm IP, VLAN/trunk và kết nối quản trị; chưa có OSPF thử nghiệm. Chỉ gỡ cấu hình của bài thử khi đã xác định rõ nó, không xóa toàn bộ cấu hình thiết bị.

Ảnh: A01 topology; A02 connected-devices; A03 ospf-empty; A04-A06 interface-brief R1/R2/R3; A07-A09 ospf-baseline R1/R2/R3; A10-A13 IP/gateway VPC7/8/9/10; A14 ping-before. Chụp thêm L2 nếu gateway chưa hoạt động hoặc cần minh chứng nền.

## 4. Giai đoạn B — khai báo OSPF qua CAMS

1. Mở R1 → Routing → OSPF → Routing Group.
2. Hosts: chọn R1 .104, R2 .105, R3 .106; không chọn các switch.
3. Identity: Process ID 1; Router ID lần lượt 1.1.1.1, 2.2.2.2, 3.3.3.3.
4. Common: Reference bandwidth 10000 Mbps trên cả ba; bật Passive default. Tắt Default originate/Originate always và AuthenticationCFG cho bài thử cơ bản này.
5. Networks: Area 0 cho các mạng nghiệp vụ sau, bỏ chọn 192.168.122.0/24 trên cả ba router:

| Router | Mạng chọn theo bảng đề xuất |
|---|---|
| R1 | 10.1.12.0/24; 192.168.10.0/24; 192.168.20.0/24; 192.168.30.0/24; loopback thực tế |
| R2 | 10.1.12.0/24; 10.1.23.0/24; loopback thực tế |
| R3 | 10.1.23.0/24; 192.168.40.0/24; loopback thực tế |

6. Chọn Save trước để lưu dữ liệu mong muốn. Mở Passive iface của từng router, chọn các cổng sau, bỏ dấu Passive để thêm trạng thái no passive:

| Router | Các cổng no passive |
|---|---|
| R1 | GigabitEthernet0/2 |
| R2 | GigabitEthernet0/2, GigabitEthernet0/3 |
| R3 | GigabitEthernet0/3 |

Lưu từng biểu mẫu nhưng chưa Push. Kiểm tra trạng thái chờ thực tế của phiên bản CAMS đang dùng. Nếu thao tác buộc Push theo từng router, ghi nhận đúng quy trình và thời gian của từng lần; không báo đó là một lần Push nhóm hoàn chỉnh.

Ảnh: B01 hosts; B02 identity; B03 common; B04-B06 networks từng router thấy rõ bỏ chọn quản trị; B07-B09 passive từng router; B10 trạng thái chờ.

## 5. Giai đoạn C — kiểm duyệt và Push

Mở View & Push OSPF cho ba thiết bị. Kiểm tra số thiết bị đích, Router ID, network/wildcard/area, passive mặc định và bốn dòng no passive theo bảng.

Không được có lệnh network khớp Gi0/0 quản trị, redistribute connected hoặc quảng bá default route trong cấu hình bài thử này. Nếu dữ liệu cũ tồn tại, chỉ bỏ chọn chưa chứng minh lệnh cũ đã bị gỡ: đối chiếu dữ liệu CAMS, lệnh dự kiến và running-config.

**Điểm kiểm tra bắt buộc từ video cũ:** giao diện bỏ chọn quản trị nhưng preview R1 vẫn có network 192.168.122.0. Nếu tái xuất hiện, chụp ảnh và lưu nguyên khối lệnh; không Push tiếp bản đó, không đổi thành minh chứng thành công. Cần xử lý dữ liệu/cơ chế sinh lệnh trước.

Khối tham chiếu riêng cho R2, nếu dùng loopback /32 và bảng IP đề xuất:

```text
router ospf 1
 router-id 2.2.2.2
 auto-cost reference-bandwidth 10000
 passive-interface default
 no passive-interface GigabitEthernet0/2
 no passive-interface GigabitEthernet0/3
 network 10.1.12.0 0.0.0.255 area 0
 network 10.1.23.0 0.0.0.255 area 0
 network 2.2.2.2 0.0.0.0 area 0
```

Đây là cấu hình kỳ vọng, không phải bản chép từ CAMS hay kết quả đã chạy. CAMS có thể sinh lệnh tương đương về ngữ nghĩa hoặc thêm lệnh điều phối; lưu đúng lệnh thực tế.

Nhấn Push khi đã kiểm duyệt. Ghi thời điểm bắt đầu, phản hồi cuối, từng thiết bị thành công/thất bại. Sau đó đồng bộ và chụp trạng thái mới. Nếu chỉ Push được riêng từng router, lưu đầy đủ các lần và diễn giải đúng phạm vi.

Ảnh: C01 preview tổng; C02-C04 preview đủ lệnh R1/R2/R3; C05 tiến trình; C06 kết quả từng thiết bị; C07 đồng bộ sau Push. Ưu tiên sao chép log văn bản để không phải đọc ảnh cuộn dài.

## 6. Giai đoạn D — xác minh OSPF và lưu lượng

Trên từng router:

```text
show running-config | section router ospf
show ip protocols
show ip ospf neighbor
show ip route ospf
show ip ospf interface brief
```

Kỳ vọng với đúng mô hình dây chuyền: R1 có R2 FULL; R2 có R1 và R3 FULL; R3 có R2 FULL. Không kết luận chỉ từ số lượng dòng: kiểm tra Router ID và cổng tương ứng. DR/BDR phụ thuộc loại mạng/trạng thái; không ép nhãn DR hoặc BDR cố định.

Kiểm tra tuyến LAN R1 trên R3 và LAN R3 trên R1. Không yêu cầu metric đúng một số định sẵn; ghi số đo thực và giải thích dựa trên bandwidth/reference bandwidth.

Kiểm tra loại mạng quản trị: running-config không có khai báo OSPF khớp Gi0/0 và thông tin interface/LSA không chứa mạng quản trị của bài thử. Mạng 192.168.122.0/24 vẫn xuất hiện dạng C/L trên các router vì nối trực tiếp; không được coi việc không có dòng O cho prefix đó là bằng chứng duy nhất đã loại quảng bá. Gi0/0 không nằm trong OSPF là tiêu chí quan trọng.

Thử trên VPCS (đổi địa chỉ nếu dùng bảng thực tế khác):

```text
VPC7> ping 192.168.40.10 -c 10
VPC8> ping 192.168.40.10 -c 10
VPC9> ping 192.168.40.10 -c 10
VPC10> ping 192.168.10.10 -c 10
VPC10> ping 192.168.20.10 -c 10
VPC10> ping 192.168.30.10 -c 10
VPC7> trace 192.168.40.10
```

Kiểm tra cú pháp của VPCS đang dùng bằng help ping nếu tùy chọn -c khác. Chờ láng giềng FULL; nếu cần ping khởi động ARP, ghi đó là lượt warm-up tách riêng. Không bỏ âm thầm gói đầu bị mất hoặc chỉ chụp lượt đẹp nhất. Lưu số gửi/nhận/lỗi và độ trễ nếu có; chưa suy diễn số hop chỉ từ TTL.

Ảnh: D01-D03 running-config; D04-D06 neighbor; D07-D09 route-ospf; D10-D12 protocol/interface; D13-D18 sáu phép ping; D19 trace. Có thể chụp thêm từng tuyến quan trọng ở cỡ chữ lớn.

## 7. Giai đoạn E — ca lỗi bổ sung

### E1. Đầu vào sai

Nhập Router ID không phải IPv4, ví dụ 1.1.1.999, trong bản khai báo thử chưa Push. Chụp đầu vào và thông báo kiểm tra. Kỳ vọng ứng dụng từ chối trước khi gửi; nếu chấp nhận, ghi thất bại của tiêu chí validation. Nếu cần kiểm tra IP/mask riêng, dùng biểu mẫu Interfaces với đầu vào không hợp lệ rồi hủy thay đổi.

### E2. Thiết bị mất kết nối khi triển khai

Làm trên bản sao baseline đã lưu, có console EVE-NG để khôi phục. Chuẩn bị đúng một thay đổi OSPF có thể đối chiếu, ghi nội dung kỳ vọng. Khi CAMS đang Push, ngắt riêng kết nối quản trị Gi0/0 của R3 trong lab; không đổi IP của máy CAMS hay tắt toàn bộ mạng quản trị.

Ghi thời điểm ngắt và các phản hồi. Nếu Push kết thúc trước khi ngắt, lượt đó không chứng minh lỗi giữa Push; đánh dấu thử chưa tạo được điều kiện, không gọi là ca lỗi đạt. Có thể thực hiện thêm ca R3 mất kết nối trước Push để có lỗi tái lập, nhưng phải đặt tên riêng, không thay bằng ca giữa Push.

Chụp thông báo có host R3, kết quả R1/R2/R3, trạng thái chờ/đã áp dụng sau lỗi. Khôi phục kết nối, đọc running-config qua console/SSH và đồng bộ để xác định phần đã áp dụng. Pending là kết quả cần quan sát, không mặc định ứng dụng luôn giữ đúng.

Ảnh: E01-E02 đầu vào sai/thông báo; E03 thay đổi thử; E04 đang Push; E05 thời điểm mất kết nối; E06 lỗi theo host; E07 trạng thái dữ liệu; E08 cấu hình thực; E09 khôi phục.

## 8. Giai đoạn F — đo CLI/CAMS

Thực hiện sau khi bài chức năng đã đạt. Dùng snapshot có cùng IP/VLAN/kết nối, chưa có OSPF; khôi phục cả trạng thái thiết bị và dữ liệu CAMS giữa các lượt. Không tính thời gian reset vào thời gian triển khai; không giữ cache/trạng thái Applied của lượt trước mà gọi là cùng baseline.

Thử cùng cấu hình OSPF đủ network và passive trên ba router, 5 lần mỗi phương pháp:

- CLI: bắt đầu khi mở phiên cấu hình từ trạng thái đã quy định, kết thúc khi đã cấu hình đủ ba router. Nếu dùng copy/paste lệnh soạn sẵn, ghi rõ; không gọi là gõ tay từng lệnh.
- CAMS: bắt đầu ở cùng điều kiện phiên, từ thao tác khai báo đầu tiên; kết thúc khi tất cả Push cần thiết hoàn tất. Tính cả bước khai báo no passive nếu phải làm riêng. Ghi riêng thời gian nhập/xem trước và thời gian thực thi.
- Đo thêm thời gian từ bắt đầu xác minh đến khi đầy đủ neighbor/tuyến/ping đạt. Tổng thời gian tới vận hành đạt = cấu hình + xác minh theo cùng quy tắc cho hai phương pháp.
- Tách loại thao tác: lần nhấp/chọn, trường nhập, lần gửi lệnh CLI và số dòng cấu hình. Không cộng chúng thành một đại lượng không định nghĩa; lệnh IOS sinh ra không mặc nhiên là thao tác người dùng.
- Ghi lỗi phải sửa, số thiết bị thành công, số lệnh, cấu hình máy CAMS/EVE-NG và phiên bản thật. Video tổng dài bao nhiêu không thay cho thời gian Push.

Nếu muốn bảng quy mô, dùng 1/2/3 router (mô hình hiện chỉ có 3 router). Đo Push cùng quy tắc, khối lượng lệnh được ghi rõ. Nhóm 1/2 thiết bị chưa tạo đủ mạng ba router nên chỉ đánh giá thực thi nhóm, không kết luận ping toàn mô hình. Routing Group hiện có ràng buộc số host; một router có thể cần View & Push đơn, phải ghi đúng luồng đó. Không cần thêm 6 router chỉ để giữ tiêu chí cũ.

Điền bằng chứng mỗi lượt trong nhat_ky_do_ospf.csv; ô trống là chưa đo. Lưu video không cắt hoặc log có dấu thời gian nếu dùng để tính thời gian.

## 9. Lọc ảnh sau khi đã thu đủ

Ưu tiên 6-8 hình/nhóm hình trong báo cáo: topology; bảng quy hoạch; lựa chọn mạng và passive; preview; kết quả Push; neighbor; tuyến quan trọng; ping. Bảng định lượng và ca lỗi trình bày riêng. Các ảnh từng thao tác còn lại chuyển phụ lục/hướng dẫn hoặc giữ trong kho bằng chứng.

Thư mục thu ảnh gợi ý: ANH_THUC_NGHIEM/{A_baseline,B_khai_bao,C_push,D_xac_minh,E_loi,F_do_luong}. Có thể tạo khi bắt đầu lưu ảnh. Đặt tên như D05_R2_neighbor_20261006_003000.png. Ảnh ban đầu có video nổi/thông báo vẫn giữ làm nguồn, chụp bản sạch để dùng trong báo cáo.

Thứ tự hiện tại: hoàn tất **A** và chốt IP thực tế trước, sau đó B/C/D; E/F làm sau khi cấu hình thành công. Không cần chụp mọi giai đoạn trong một lượt duy nhất.

Nguồn giải thích passive-interface (mạng vẫn có thể được quảng bá dù interface passive): https://www.cisco.com/c/en/us/td/docs/routers/ios-xe/ip-routing/b-ip-routing/m_iri-default-passive-interface.html
