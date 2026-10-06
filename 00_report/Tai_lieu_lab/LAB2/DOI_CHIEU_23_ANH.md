# Đối chiếu 23 ảnh Lab 2 — ngày 06/10/2026

## Chốt minh chứng chức năng: ảnh copy 29–33

Đã xem trực tiếp đủ 5 ảnh mới, tổng 34 ảnh trong thư mục. Copy 29/30/31/32/33 lần lượt là R1/R2/R3/R4/R5, mỗi ảnh có cấu hình router ospf 1, neighbor và tuyến OSPF.

| Router | Neighbor hiển thị | Tuyến LAN xa tiêu biểu |
|---|---|---|
| R1 | R2 FULL/BDR; R3 FULL/DR | 192.168.20.0/24 qua 10.1.123.2; 192.168.50.0/24 qua 10.1.123.3, [110/4] |
| R2 | R1 FULL/DROTHER; R3 FULL/DR | 192.168.10.0/24 qua 10.1.123.1; 192.168.50.0/24 qua 10.1.123.3 |
| R3 | R1 FULL/DROTHER; R2 FULL/BDR; R4 FULL/DR | LAN 10/20 qua R1/R2; LAN 50 qua 10.1.34.2 |
| R4 | R3 FULL/BDR; R5 FULL/DR | LAN 10/20 qua 10.1.34.1; LAN 50 qua 10.1.45.2 |
| R5 | R4 FULL/BDR | LAN 10/20 qua 10.1.45.1, [110/4] |

Cả 5 cấu hình có Router ID đúng, Area 0, passive default và đúng các ngoại lệ no-passive; network quảng bá loopback /32, LAN và transit /24, không có network bao phủ mạng quản trị trong section hiển thị. Không có redistribution hay default originate trong section. Không có tuyến default trong các output; có tuyến O tới LAN xa. Reference bandwidth 100 ở preview tương ứng giá trị mặc định không hiện trong running-config; không ghi 10000 trong báo cáo này.

Kết luận: đủ bộ bằng chứng chức năng để viết thay phần OSPF Lab 2 cũ bằng lab một vùng trên 5 router. Dùng ảnh R1/R3/R5 cho phần chính; R2/R4 giữ phụ lục nếu cần. Chưa xác nhận kết quả Push theo host, VLAN thực tế, thời gian/thao tác CLI so với CAMS hoặc ca lỗi từ bộ ảnh; không suy diễn các kết quả đó. Việc thay lab chức năng không đồng nghĩa hoàn tất góp ý đánh giá định lượng Chương 5.

## Bổ sung sau lần xem đầu: ảnh copy 23–28

Đã xem trực tiếp thêm 6 ảnh, tổng 29 ảnh trong thư mục. Copy 23: PC8→PC10; copy 24: PC10→PC8; copy 25: PC9→PC11; copy 26: PC11→PC9; copy 27: PC8→PC9; copy 28: PC9→PC8. Mỗi phép thử hiển thị đủ 5 hồi đáp cho 5 gói, không thấy timeout. Copy 24 có RTT 593.906 ms và 64.161 ms; copy 28 có RTT 159.345 ms. Dùng làm bằng chứng kết nối, không kết luận độ trễ luôn thấp hay hiệu năng ổn định.

Ảnh trace trong hội thoại trước đã tới PC10 qua R1→R3→R4→R5, kết thúc bằng ICMP type 3/code 3 từ chính đích; đây là kết thúc bình thường của UDP traceroute. Chưa thấy ảnh trace riêng trong các file copy 23–28; cần lưu ảnh đó vào thư mục khi chọn hình báo cáo.

Kết luận cập nhật: phần kết nối liên LAN hai chiều đã đủ minh chứng chức năng để thay kịch bản OSPF cũ sau khi bổ sung cấu hình/neighbor/tuyến O trên router và sửa nội dung báo cáo khớp phạm vi một vùng, 5 router. Các mục thiếu bên dưới về ping hai chiều đã được đáp ứng; các mục thiếu về CLI, kết quả Push và định lượng/ca lỗi vẫn còn. Không cần mở rộng topology hoặc thêm giao thức để thay lab.

Đã xem trực tiếp đủ 23 ảnh theo thứ tự tên số: image.png → image copy.png → image copy 2.png → … → image copy 22.png. File image copy.png được tính là ảnh copy 1. Chỉ kết luận từ phần hiển thị; thứ tự tên là thứ tự thu ảnh do người dùng cung cấp, không thay thế timestamp phép đo.

## Nội dung theo thứ tự

| File | Nội dung và kết luận |
|---|---|
| image.png | Baseline R1: Gi0/0 quản trị .101 up/up; Loopback0 1.1.1.1 có tuyến /32; Gi0/1, Gi0/2 chưa có IP và shutdown. Không thấy cấu hình OSPF/tuyến tĩnh; không có default route. |
| image copy.png | Topology sạch: 5 router, 2 switch, 4 PC; các cổng khớp kịch bản mới. |
| image copy 2.png | Baseline R2: quản trị .102 và loopback 2.2.2.2; chưa có IP nghiệp vụ/OSPF/tuyến tĩnh/default route trong output. |
| image copy 3.png | Baseline R3 tương tự: .103, loopback 3.3.3.3. |
| image copy 4.png | Baseline R4 tương tự: .104, loopback 4.4.4.4. |
| image copy 5.png | Baseline R5 tương tự: .105, loopback 5.5.5.5. |
| image copy 6.png | PC11 192.168.50.11/24, GW .50.1; ping gateway nhận đủ 5 hồi đáp. |
| image copy 7.png | PC10 192.168.50.10/24, GW .50.1; ping gateway nhận đủ 5 hồi đáp. |
| image copy 8.png | PC8 192.168.10.10/24, GW .10.1; ping gateway nhận đủ 5 hồi đáp. |
| image copy 9.png | PC9 192.168.20.10/24, GW .20.1; ping gateway nhận đủ 5 hồi đáp. Một hồi đáp 230.573 ms; không dùng loạt nhỏ này suy ra hiệu năng CAMS. |
| image copy 10.png | PC8 ping gateway thành công; ping 10.1.34.1 nhận 5 thông báo Destination host unreachable từ gateway .10.1, không phải Echo Reply từ đích. Dùng làm đối chứng trước triển khai. |
| image copy 11.png | Routing Group chọn đúng 5 router .101–.105, không chọn switch. |
| image copy 12.png | Process ID 1; Router ID duy nhất 1.1.1.1 đến 5.5.5.5. |
| image copy 13.png | Networks R1/R2 Area 0: transit 10.1.123.0/24, LAN riêng và loopback /32; bỏ mạng quản trị. Phần R3 chưa hiển thị đủ. |
| image copy 14.png | Networks R4/R5 Area 0: liên kết 10.1.34.0 và 10.1.45.0 đang /24; loopback /32 được chọn; quản trị bỏ chọn. Chỉ thấy loopback của R3 ở đầu ảnh. |
| image copy 15.png | Preview cho 5 target, chưa phải kết quả Push. R2: reference-bandwidth 100, passive default, network transit/LAN/loopback, không default originate. Phần R3 thấy network 10.1.34.0 wildcard /24. Không thấy no-passive của R2 trong block này; phù hợp giai đoạn khai báo trước khi cấu hình ngoại lệ passive. |
| image copy 16.png | CAMS R5 có ngoại lệ no passive Gi0/2. Gi0/3 trong ô chọn chưa được thêm, không phải cấu hình đã áp dụng. |
| image copy 17.png | CAMS R4 có no passive Gi0/1 và Gi0/2. |
| image copy 18.png | CAMS R3 có no passive Gi0/1 và Gi0/2. |
| image copy 19.png | CAMS R2 có no passive Gi0/1. |
| image copy 20.png | CAMS R1 có no passive Gi0/1. |
| image copy 21.png | Syslog có ADJCHG LOADING→FULL cho các cặp R1–R2, R1–R3, R2–R3, R3–R4, R4–R5. Đây là bằng chứng các adjacency đã lên tại thời điểm log; cần CLI để xác minh trạng thái hiện tại. Không phải bảng kết quả Push 5/5. |
| image copy 22.png | PC8 ping 10.1.34.1: giữ cả lần trước bị unreachable và lần sau nhận đủ 5 hồi đáp từ đích. Bằng chứng kết nối tới cổng R3 đã thay đổi sau triển khai; chưa chứng minh LAN bên R5 thông suốt. |

## Đã làm được

Baseline trước cấu hình nghiệp vụ; topology; IP/gateway 4 PC; chọn nhóm và ID; chọn mạng có loại quản trị ở các router hiển thị; ngoại lệ passive đúng cổng; log adjacency toàn bộ các cặp nối router; một phép ping trước/sau tới R3.

Giữ loopback có sẵn và quảng bá /32 là hợp lệ. Không cần xóa để khớp phương án tối giản ban đầu.

Hai liên kết R3–R4/R4–R5 dùng /24 thay vì /30 đề xuất. /24 không phải lỗi bắt buộc sửa nếu cả hai đầu cùng mask và subnet riêng biệt; log adjacency đã lên hỗ trợ khả năng cấu hình tương thích tại thời điểm đó. Cần đọc config cổng để xác nhận. Có thể giữ /24, cập nhật bảng IP và lệnh trong báo cáo theo cấu hình thực tế để tránh làm lại ảnh. Không trộn ảnh /24 với bảng /30.

## Bằng chứng còn thiếu

1. IP/mask/cổng sau cấu hình của cả 5 router (show ip interface brief không hiển thị mask; dùng thêm show running-config interface Gi0/1 và Gi0/2).
2. VLAN/cổng lab và SVI/cổng quản trị của SW1/SW2. Ping gateway PC10/PC11 hỗ trợ LAN SW2 hoạt động, chưa chứng minh VLAN quản trị được tách. Log adjacency R1/R2/R3 hỗ trợ transit SW1 hoạt động, chưa chứng minh cách tách VLAN.
3. Trang Common; phần Networks R3 đầy đủ; preview cuối sau khi thêm no-passive; kết quả Push theo host. Không suy ra “5/5 Push thành công” từ SYNC hoặc Syslog.
4. Trên 5 router: show running-config | section router ospf; show ip ospf neighbor; show ip ospf interface brief; show ip route ospf. Xác minh quản trị không tham gia OSPF và các LAN ở xa có tuyến O. Reference bandwidth 100 đã thấy trên R2/R3 preview; kiểm tra đồng nhất cả 5.
5. Ping hai chiều PC8↔PC10, PC9↔PC11, PC8↔PC9; trace PC8→PC10. Ping tới 10.1.34.1 chưa đi qua R4/R5. PC10↔PC11 cùng LAN không chứng minh OSPF.
6. Bảng thời gian/thao tác CLI so với CAMS từ cùng baseline; trường hợp lỗi có kết quả thực tế. 23 ảnh hiện tại chưa giải quyết đầy đủ góp ý định lượng ở Chương 5.

## Việc tiếp theo

Giữ lab đang chạy, thu CLI và ping end-to-end trước. Không cấu hình lại switch khi chưa thấy lỗi; kiểm tra VLAN/cổng hiện tại. Chụp bổ sung và giữ thứ tự số tăng tiếp từ copy 23. Các ảnh preview/Push còn thiếu chỉ thu từ thao tác thực tế tiếp theo hoặc chạy lại có ghi rõ; không tạo kết quả giả cho lần trước. Khi đo CLI/CAMS phải dùng bản sao baseline có IP/L2 và chưa có OSPF, không reset toàn bộ cấu hình quản trị.

Ảnh phù hợp cho báo cáo: topology copy 1; một baseline đại diện (các router còn lại giữ phụ lục); hosts/identity copy 11–12; networks copy 13–14 kèm bổ sung R3; một passive đại diện; log copy 21; ping trước/sau copy 22. Bổ sung neighbor/routes và ping liên LAN trước khi chốt bộ hình.

## Đã cập nhật báo cáo

Đã thay phần Kịch bản 2 bằng `contents/09_kich_ban_2_ospf.typ`, cập nhật phần giới thiệu Chương 5 và đoạn tóm tắt liên quan. PDF `main.pdf` biên dịch thành công; Lab 2 ở trang in 47–56 (trang PDF 63–72). Chọn 7 ảnh thực nghiệm cho nội dung chính, 4 bảng và output traceroute chép đúng từ ảnh. Ảnh gốc giữ nguyên; các ảnh chọn được đưa vào kho ảnh dùng chung `00_book/figures/report/diagrams/ospf-lab2-five-routers`. Bản PDF trước khi sửa được giữ tại `/tmp/cams-report-before-lab2.pdf`. Phần định lượng và ca lỗi chưa thực hiện theo yêu cầu để xử lý sau.
