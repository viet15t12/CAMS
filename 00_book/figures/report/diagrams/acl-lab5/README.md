# Topology Lab 5 - ACL

- Ảnh gốc: `00_report/Tai_lieu_lab/LAB5/ANH_CUA_LAB/so_do.png`, giữ nguyên.
- `topology-redrawn.drawio`: sơ đồ mở và chỉnh sửa bằng draw.io; thiết bị, nhãn và liên kết là các phần tử riêng, biểu tượng nhúng dạng vector.
- `topology-redrawn.svg`: bản vector nền trắng dùng trong báo cáo.
- `topology-redrawn.png`: ảnh xem trước độ phân giải cao.
- `generate_topology.py`: sinh SVG và draw.io từ cùng dữ liệu hình học và nhãn; sử dụng bộ biểu tượng của Lab 1.

## Đối chiếu ảnh nguồn

Giữ nguyên 3 router, 3 switch, 4 máy trạm và 2 đám mây quản trị. Có 18 kết nối vật lý: 12 kết nối dữ liệu và 6 kết nối quản trị.

| Kết nối dữ liệu | Cổng thứ nhất | Cổng thứ hai |
|---|---|---|
| R1 - R2 | R1 Gi0/2 | R2 Gi0/2 |
| R2 - R3 | R2 Gi0/3 | R3 Gi0/3 |
| R1 - SW1 | R1 Gi0/1 | SW1 Gi0/3 |
| R3 - VPC10 | R3 Gi0/1 | VPC10 eth0 |
| SW1 - SW2, đường thứ nhất | SW1 Gi0/1 | SW2 Gi0/1 |
| SW1 - SW2, đường thứ hai | SW1 Gi0/2 | SW2 Gi0/2 |
| SW1 - SW3, đường thứ nhất | SW1 Gi1/1 | SW3 Gi1/1 |
| SW1 - SW3, đường thứ hai | SW1 Gi1/0 | SW3 Gi1/0 |
| SW2 - SW3 | SW2 Gi0/3 | SW3 Gi0/3 |
| SW2 - VPC7 | SW2 Gi1/0 | VPC7 eth0 |
| SW3 - VPC8 | SW3 Gi1/2 | VPC8 eth0 |
| SW3 - VPC9 | SW3 Gi1/3 | VPC9 eth0 |

Management nối R1, SW1, SW2; ManagementMa nối R2, R3, SW3. Tất cả dùng cổng quản trị Gi0/0. Đường quản trị được biểu diễn bằng nét đứt; không dùng để minh họa đường đi của các phép thử ACL.

Địa chỉ mạng R1-R2, R2-R3, Loopback0 trên R3, mạng quản trị và VLAN lấy từ mục Kịch bản 5 trong `00_report/contents/09_thu_nghiem_danh_gia.typ`. Địa chỉ nguồn VPC7/VPC8/VPC9 đối chiếu từ ảnh System Logs `12.png`, phù hợp với các mạng /24 trong quy hoạch. VPC10 giữ nguyên kết nối của ảnh nguồn, không tự gán địa chỉ chưa có bằng chứng. Loopback0 là giao diện logic trên R3, không vẽ thêm máy chủ vật lý.

Switch1/Switch2/Switch3 trong ảnh nguồn được ghi SW1/SW2/SW3 để thống nhất với báo cáo. Giữ từng đường nối kép, không suy diễn số hiệu Port-channel. Sơ đồ vẽ lại mô tả cấu trúc mạng; ảnh lệnh show, kiểm thử và System Logs vẫn là bằng chứng kết quả thực thi.

Tên cổng được đặt trực tiếp trên liên kết dưới dạng nhãn nền trắng có viền mảnh. Các nhãn trên dây chéo xoay theo hướng dây; nhãn trên dây dọc giữ chiều chữ ngang để đọc rõ. Trong draw.io, cả 30 nhãn cổng là phần tử con của liên kết tương ứng, dùng vị trí tương đối thay cho tọa độ rời trên trang. Bản SVG tính vị trí từ cùng khoảng cách dọc dây. Đường quản trị vào SW1 được bố trí lại cho nhãn không chồng nhau; thiết bị và tên cổng giữ nguyên.

Đã kiểm tra sơ đồ mở thành công trên draw.io; `topology-drawio-preview.jpg` là ảnh chụp trình duyệt. Bản vector đã kiểm tra trong Hình 5.54, trang in 90 (trang PDF 109), và trang kế tiếp. Báo cáo giữ 126 trang. Cột địa chỉ nguồn của Bảng 5.16 được chỉnh rộng và dùng `table-code` để tránh tràn sang cột đích; giá trị và chính sách được giữ nguyên.
