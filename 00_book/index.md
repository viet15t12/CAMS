# Tài liệu hướng dẫn CAMS

CAMS là ứng dụng desktop hỗ trợ quản lý, cấu hình và giám sát thiết bị mạng trong một không gian làm việc tập trung. Tài liệu này hướng dẫn từ bước chuẩn bị môi trường, quản lý thiết bị đến cấu hình các chức năng trong Workspace.

!!! warning "Phạm vi sử dụng"
    CAMS đang được phát triển và kiểm chứng trong môi trường nghiên cứu. Hãy xem trước cấu hình, kiểm tra đúng thiết bị và sao lưu dữ liệu trước khi áp dụng thay đổi trên hệ thống thực tế.

## Đọc tài liệu

<div class="chapter-grid" markdown>

[**Lời mở đầu**
<span>Bối cảnh xây dựng tài liệu và lời cảm ơn của nhóm tác giả.</span>](DOC/00_loi_mo_dau.md)

[**Chương 1 · Tổng quan**
<span>Mục tiêu, đối tượng sử dụng, chức năng chính và các khái niệm nền tảng của CAMS.</span>](DOC/01_tong_quan.md)

[**Chương 2 · Cài đặt và bắt đầu sử dụng**
<span>Chuẩn bị Python, uv, khởi chạy CAMS, tạo Project và quản lý Snapshot.</span>](DOC/02_cai_dat_su_dung.md)

[**Chương 3 · Giao diện và điều hướng**
<span>Làm quen với Workspace, Sidebar, Device Tabs, Feature Bar và các phím tắt.</span>](DOC/03_giao_dien_dieu_huong.md)

[**Chương 4 · Quản lý thiết bị**
<span>Thêm, nhập, tìm kiếm, kết nối, đồng bộ, chỉnh sửa và xóa thiết bị.</span>](DOC/04_quan_ly_thiet_bi.md)

[**Chương 5 · Interface trên Router**
<span>Xem interface đã đồng bộ, cấu hình Physical, Loopback, Tunnel, Subinterface và kiểm tra View & Push.</span>](DOC/05_cau_hinh_interface_router.md)

[**Chương 6 · Routing trên Router**
<span>Cấu hình Static, Default, OSPF, EIGRP; thực hiện Routing Group OSPF và View & Push riêng cho từng module.</span>](DOC/06_cau_hinh_routing.md)

[**Chương 7 · DHCP trên Router**
<span>Cấu hình DHCP Pool, Excluded Address, Helper Address và kiểm tra bằng View & Push DHCP riêng.</span>](DOC/07_cau_hinh_dhcp.md)

[**Chương 8 · ACL trên Router**
<span>Cấu hình Standard, Extended, Dynamic, Reflexive, MAC ACL, Interface Bindings và View & Push ACL riêng.</span>](DOC/08_cau_hinh_acl.md)

[**Chương 9 · FHRP trên Router**
<span>Cấu hình HSRP, VRRP, GLBP, chính sách từng thành viên và View & Push FHRP theo giao thức.</span>](DOC/09_cau_hinh_fhrp.md)

[**Chương 10 · Syslog Server trên Router**
<span>Cấu hình destination, source interface, severity, Syslog Group và View & Push SYSLOG riêng.</span>](DOC/10_cau_hinh_syslog_server.md)

[**Chương 11 · NAT trên Router**
<span>Cấu hình Quick PAT, Interfaces, NAT ACL, Static, Dynamic, PAT, Route Map và View & Push NAT riêng.</span>](DOC/11_cau_hinh_nat.md)

[**Chương 12 · Truyền tệp bằng SFTP**
<span>Tạo kết nối an toàn, xác minh host key, quản lý tệp local/remote và theo dõi hàng đợi truyền tệp.</span>](DOC/12_truyen_tep_sftp.md)

[**Chương 13 · Xem log trên System Logs**
<span>Vận hành listener, hiểu tám mức severity Cisco 0–7, lọc, đọc chi tiết và xuất log.</span>](DOC/13_xem_system_logs.md)

[**Chương 14 · Interface trên Switch Layer 2**
<span>Cấu hình Access, Trunk, VLAN membership, link settings, loop protection và View & Push Interfaces.</span>](DOC/14_interface_switch_l2.md)

[**Chương 15 · Switching trên SW2**
<span>Cấu hình VLAN, EtherChannel thủ công/Quick Link, STP, VTP Group và từng View & Push riêng.</span>](DOC/15_vlan_etherchannel_stp_vtp.md)

[**Chương 16 · Bảo mật Switch Layer 2**
<span>Cấu hình DHCP Snooping, DAI, trusted uplink, Static MAC và Port Security.</span>](DOC/16_bao_mat_switch_l2.md)

[**Chương 17 · Giám sát Switch Layer 2**
<span>Đọc Port Counters, lỗi/discard, link flap và MAC Address Table.</span>](DOC/17_giam_sat_switch_l2.md)

[**Chương 18 · Interface trên Switch Layer 3**
<span>Cấu hình Routed Port, SVI, IP Routing và kiểm tra từng View & Push phù hợp.</span>](DOC/18_interface_switch_l3.md)

[**Chương 19 · DHCP và ACL trên Switch Layer 3**
<span>Cấu hình DHCP Server, DHCP Relay, ACL trên SVI và từng View & Push riêng.</span>](DOC/19_dhcp_acl_switch_l3.md)

</div>

## Bắt đầu nhanh

Nếu đây là lần đầu sử dụng CAMS, hãy đọc [Chương 2 · Cài đặt và bắt đầu sử dụng](DOC/02_cai_dat_su_dung.md). Sau khi mở được Workspace, tiếp tục với [Chương 3 · Giao diện và điều hướng](DOC/03_giao_dien_dieu_huong.md) và [Chương 4 · Quản lý thiết bị](DOC/04_quan_ly_thiet_bi.md). Với router, bắt đầu tại [Chương 5 · Interface trên Router](DOC/05_cau_hinh_interface_router.md). Với switch SW2, đọc lần lượt [Chương 14 · Interface trên Switch Layer 2](DOC/14_interface_switch_l2.md), [Chương 15 · Switching trên SW2](DOC/15_vlan_etherchannel_stp_vtp.md), [Chương 16 · Bảo mật Switch Layer 2](DOC/16_bao_mat_switch_l2.md) và [Chương 17 · Giám sát Switch Layer 2](DOC/17_giam_sat_switch_l2.md). Với switch SW3, đọc tiếp [Chương 18 · Interface trên Switch Layer 3](DOC/18_interface_switch_l3.md) và [Chương 19 · DHCP và ACL trên Switch Layer 3](DOC/19_dhcp_acl_switch_l3.md); các chức năng switching chung vẫn dùng Chương 14–17. Dùng [Chương 12 · SFTP](DOC/12_truyen_tep_sftp.md) để quản lý backup và [Chương 13 · System Logs](DOC/13_xem_system_logs.md) để nhận, lọc, phân tích log.

Mã nguồn và lịch sử phát triển được lưu tại [viet15t12/CAMS](https://github.com/viet15t12/CAMS).
