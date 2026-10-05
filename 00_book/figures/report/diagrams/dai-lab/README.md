# Chọn ảnh minh chứng DAI — Lab 1, Chương 5

Nguồn: `00_report/Tai_lieu_lab/LAB1/ANH_CUA_LAB/`, ảnh `image copy 36.png` đến `image copy 49.png` (14 ảnh).

Chọn 7 ảnh gốc, trình bày thành 6 hình: một ảnh thao tác và năm hình chứng minh trạng thái/kết quả. Tệp PNG được sao chép nguyên vẹn. Typst chỉ trích vùng hiển thị để bỏ khoảng trống hoặc dòng lặp, không sửa nội dung ảnh. Hình nhiều vùng ghi rõ trong chú thích. Các ảnh khôi phục 48–49 ghép theo chiều dọc trong cùng một hình.

| Ảnh gốc | Chọn | Tệp đích / lý do |
|---|---|---|
| image copy 36.png | Không | Thao tác bật DAI; trạng thái Enabled/Active đã có ở ảnh 40. |
| image copy 37.png | Không | Thao tác trust; ảnh 40 xác nhận trạng thái trực tiếp trên thiết bị. |
| image copy 38.png | Không | Biểu mẫu giao diện trước thử nghiệm, không thêm bằng chứng kết quả. |
| image copy 39.png | Không | View & Push ở bước chuẩn bị DHCP; không cần đưa từng thao tác. |
| image copy 40.png | Có | baseline-binding-trust.png: DAI Active, drop 0, trust Gi0/1, binding .4 ở Gi0/2. |
| image copy 41.png | Không | Ping hợp lệ đã được giữ trong ảnh so sánh 43. |
| image copy 42.png | Có | cams-static-ip-input.png: duy nhất một ảnh thao tác nhập .250; giải thích .4 bên trái là trạng thái trước cập nhật. |
| image copy 43.png | Có | ping-before-after.png: .4 đạt 5/5, .250 đạt 0/5, cùng đích và cùng cổng nguồn. |
| image copy 44.png | Có | switch-drops-syslog.png: 9 ARP bị chặn và SW_DAI log có IP/MAC/cổng/VLAN. |
| image copy 45.png | Có | cams-syslog-alert.png: Syslog thiết bị và cảnh báo CAMS; giải thích riêng hai nguồn, mức độ, số gói/số sự kiện. |
| image copy 46.png | Không | View & Push khôi phục DHCP; binding và ping 48–49 chứng minh kết quả. |
| image copy 47.png | Không | Biểu mẫu khôi phục; trùng mục đích với kết quả 48–49. |
| image copy 48.png | Có | recovered-binding.png: binding .5 cùng MAC, VLAN 10, Gi0/2. |
| image copy 49.png | Có | recovered-ping.png: ping 5/5 sau khôi phục với nguồn .5. |

## Những điểm đã giải thích trong báo cáo

- DHCP Drops trong thống kê DAI đếm ARP bị loại khi kiểm tra binding, không đếm gói DHCP.
- 9 ARP, 5 gói ping, số dòng Syslog và 5 ARP trong 4 sự kiện cảnh báo là các đại lượng khác nhau.
- SW_DAI / 4 Warning là log thiết bị; CAMS / 3 Error, DAI_ARP_SPOOF là cảnh báo tổng hợp, chỉ nêu nghi vấn.
- 5000.0003.0002 và 50:00:00:03:00:02 là cùng MAC.
- 192.168.122.101 là nguồn gửi Syslog; 192.168.10.250 là IP trong ARP bị chặn.
- Không khẳng định tấn công ARP poisoning thực tế; đây là phép đổi IP không khớp binding.
- Múi giờ, độ trễ thu thập và thời điểm chụp không được dùng để suy ra độ trễ phát hiện.
- Sau khôi phục DHCP, .5 thay cho .4 vẫn hợp lệ nhờ binding mới.
