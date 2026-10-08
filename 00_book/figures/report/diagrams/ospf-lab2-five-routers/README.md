# Topology Lab 2 - OSPF trên năm router

- `topology.png`: ảnh topology EVE-NG gốc, giữ nguyên để đối chiếu.
- `topology-redrawn.drawio`: sơ đồ chỉnh sửa bằng draw.io; thiết bị, nhãn và liên kết là các phần tử riêng. Biểu tượng được nhúng dạng vector SVG.
- `topology-redrawn.svg`: bản vector nền trắng dùng trong báo cáo.
- `topology-redrawn.png`: bản xem trước độ phân giải cao.
- `generate_topology.py`: sinh draw.io và SVG từ cùng dữ liệu nhãn, tọa độ và liên kết; dùng bộ biểu tượng của sơ đồ Lab 1.

## Đối chiếu kết nối

Sơ đồ gồm 5 router, 2 switch, 4 máy trạm và 2 đám mây quản trị. Giữ đủ 17 kết nối trong ảnh nguồn: 10 kết nối dữ liệu và 7 kết nối quản trị.

| Kết nối dữ liệu | Cổng thứ nhất | Cổng thứ hai |
|---|---|---|
| R1 - SW1 | R1 Gi0/1 | SW1 Gi0/1 |
| R2 - SW1 | R2 Gi0/1 | SW1 Gi0/2 |
| R3 - SW1 | R3 Gi0/1 | SW1 Gi0/3 |
| R3 - R4 | R3 Gi0/2 | R4 Gi0/1 |
| R4 - R5 | R4 Gi0/2 | R5 Gi0/2 |
| R5 - SW2 | R5 Gi0/1 | SW2 Gi0/1 |
| R1 - VPC8 | R1 Gi0/2 | VPC8 eth0 |
| R2 - VPC9 | R2 Gi0/2 | VPC9 eth0 |
| SW2 - VPC10 | SW2 Gi0/2 | VPC10 eth0 |
| SW2 - VPC11 | SW2 Gi0/3 | VPC11 eth0 |

ManagementM nối R1, R3 và SW1; ManagementMA nối R2, R4, R5 và SW2. Cổng quản trị đều là Gi0/0; đường quản trị dùng nét đứt, không thuộc vùng OSPF. Hai đám mây cùng thuộc mạng quản trị 192.168.122.0/24 theo bảng quy hoạch của báo cáo.

Địa chỉ LAN, mạng trung chuyển, Router ID và địa chỉ máy trạm được đối chiếu từ `00_report/contents/09_kich_ban_2_ospf.typ`. Switch1/Switch2 trong ảnh nguồn được ghi SW1/SW2 để thống nhất với báo cáo. Nhãn RID là Router ID; không vẽ thêm kết nối vật lý cho Loopback.

Sơ đồ vẽ lại dùng để mô tả cấu trúc mạng, không thay thế ảnh chụp lệnh show, ping hoặc trace làm bằng chứng thử nghiệm.

Đã mở và kiểm tra sơ đồ trên draw.io; `topology-drawio-preview.jpg` là ảnh chụp trình duyệt. Bản SVG đã kiểm tra trực quan trong Hình 5.11, trang in 52 (trang PDF 71), cùng các trang kế tiếp. Báo cáo sau thay hình giữ 126 trang.

### Nhãn cổng gắn với liên kết

Tên cổng được đặt trong khung nền trắng trên dây, gần đầu kết nối. Nhãn trong draw.io là phần tử con của dây nên di chuyển theo liên kết khi kéo thiết bị. SVG và draw.io dùng cùng vị trí. Chạy `../inline_port_labels.py` để cập nhật đồng thời hai định dạng; trình sinh Lab 2 cũng tự áp dụng bước này. Chỉ thay cách trình bày, giữ nguyên tên cổng, địa chỉ và các kết nối.
