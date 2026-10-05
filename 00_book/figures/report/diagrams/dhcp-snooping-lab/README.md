# Ảnh minh chứng Lab 1 — DHCP Snooping

Nguồn: `00_report/Tai_lieu_lab/LAB1/ANH_CUA_LAB/`. Đã rà soát 37 ảnh; chọn 8 ảnh gốc, không sửa nội dung.

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

Các ảnh còn lại: ảnh thiết lập/kiểm tra lặp lại, mô hình cũ chưa có server thứ hai, log DHCP client các lần trước, hoặc giai đoạn chẩn đoán DAI/debug/drop. Không dùng để suy diễn kết quả chặn OFFER hoặc Syslog Snooping. `image copy 30.png` thể hiện pool FAKE_TEST nhưng nền terminal khó đọc; thông số pool được mô tả trong bài, không thêm ảnh gây loãng.
