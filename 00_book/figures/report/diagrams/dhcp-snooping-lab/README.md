# Ảnh minh chứng Lab 1 — DHCP Snooping

Nguồn: `00_report/Tai_lieu_lab/LAB1/ANH_CUA_LAB/`. Đã rà soát 37 ảnh; chọn 9 ảnh gốc, không sửa nội dung.

| Ảnh gốc | Tệp báo cáo | Mục đích |
|---|---|---|
| image copy 27.png | topology.png | Mô hình có hai DHCP server |
| image copy 19.png | vlan10-snooping.png | Snooping VLAN10, DAI disabled |
| image copy 29.png | r1-pool.png | Pool của R1 |
| image copy 31.png | trust-gi01.png | Trust Gi0/1 |
| image copy 28.png | r2-address-r1.png | R2 nhận 192.168.10.5 |
| image copy 32.png | trust-gi03.png | Trust Gi0/3 |
| image copy 33.png | r2-request-dhcp.png | Client ip address dhcp |
| image copy 34.png | r2-address-fake.png | R2 nhận 192.168.66.100 |
| image copy 26.png | show-snooping-state.png | Lệnh show trạng thái, running-config và thống kê DHCP Snooping |

Các ảnh còn lại: ảnh thiết lập/kiểm tra lặp lại, mô hình cũ chưa có server thứ hai, log DHCP client các lần trước, hoặc giai đoạn chẩn đoán DAI/debug/drop. Không dùng để suy diễn kết quả chặn OFFER hoặc Syslog Snooping. `image copy 30.png` thể hiện pool FAKE_TEST nhưng nền terminal khó đọc; thông số pool được mô tả trong bài, không thêm ảnh gây loãng.

## Sơ đồ vẽ lại ngày 08/10/2026

- `topology-redrawn.drawio`: tệp diagrams.net XML mở và chỉnh sửa bằng draw.io; thiết bị, nhãn và liên kết là các phần tử riêng, biểu tượng Cisco được nhúng dạng vector SVG.
- `topology-redrawn.svg`: sơ đồ vector nền trắng dùng trong báo cáo, sinh từ cùng quy hoạch hình học và nhãn.
- Giữ nguyên `topology.png` làm ảnh nguồn; sơ đồ vẽ lại không phải ảnh chụp trạng thái thực thi.
- Bảo toàn 7 kết nối: 3 kết nối dữ liệu vào SW1 Gi0/1, Gi0/2, Gi0/3 và 4 kết nối quản trị Gi0/0. SW1 là tên dùng trong báo cáo tương ứng thiết bị Switch trong ảnh EVE-NG.
- Các dải DHCP lấy từ phần quy hoạch của Lab 1; không tự thêm địa chỉ quản trị riêng cho từng router. Không cố định cổng trusted trên sơ đồ vì bài thử thay đổi trust giữa Gi0/1 và Gi0/3.
- Đã kiểm tra XML bằng draw.io trên trình duyệt; ảnh `topology-drawio-preview.jpg` ghi nhận sơ đồ mở thành công. SVG được kiểm tra trực quan độc lập và trong Hình 5.1, trang in 40 (trang PDF 59). Báo cáo sau thay hình giữ 126 trang.

### Nhãn cổng gắn với liên kết

Tên cổng được đặt trong khung nền trắng trên dây, gần đầu kết nối. Nhãn trong draw.io là phần tử con của dây nên di chuyển theo liên kết khi kéo thiết bị. SVG và draw.io dùng cùng vị trí. Chạy `../inline_port_labels.py` để cập nhật đồng thời hai định dạng; trình sinh Lab 2 cũng tự áp dụng bước này. Chỉ thay cách trình bày, giữ nguyên tên cổng, địa chỉ và các kết nối.
