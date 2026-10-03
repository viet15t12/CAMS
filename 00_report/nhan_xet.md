# BẢN NHẬN XÉT VÀ GÓP Ý CHỈNH SỬA

## I. NHẬN XÉT CHUNG

- Thiếu phần tổng quan nghiên cứu và so sánh với giải pháp hiện có (Ansible, Nornir, NetBox, Oxidized/RANCID, Cisco DNA Center/Catalyst Center, SolarWinds NCM…), nên chưa làm rõ tính mới và đóng góp khoa học.
- Phần "an ninh mạng" trong tên đề tài chưa được kiểm chứng: không có kịch bản nào thử ACL, Port Security, DHCP Snooping hay DAI; Syslog mới dừng ở thu thập và lọc, chưa phân tích hay cảnh báo.
- Chương 5 thiếu đánh giá định lượng (thời gian, số thao tác so với cấu hình CLI thủ công, tỷ lệ thành công, kịch bản lỗi), và có một số điểm sai hoặc chưa chặt về kiến thức chuyên ngành (mục III.3).
- Một số lỗi hình thức: không có trang bìa, lỗi hiển thị dấu tiếng Việt ở tiêu đề in nghiêng, nhiều ảnh chụp màn hình quá nhỏ không đọc được, tài liệu tham khảo quá ít.

## II. GÓP Ý VỀ HÌNH THỨC

| Vị trí | Vấn đề | Đề xuất chỉnh sửa |
|---|---|---|
| Đầu báo cáo | Không có trang bìa chính và bìa phụ; tài liệu mở đầu bằng Lời cam đoan. | Bổ sung bìa theo mẫu NCKH sinh viên của Học viện: tên cơ quan, tên đề tài, mã số, lĩnh vực, nhóm SV, GVHD, nơi và năm thực hiện. |
| Tiêu đề mục in nghiêng (3.4.1, 3.4.3, 4.3.2, 5.3.2…) | Font in nghiêng thiếu glyph tiếng Việt: "cơ s ", "Xem trư c và th c thi", "lịch s ", "Hạn chế th c tế". Văn bản trích xuất ra còn thành "cơ ơ sở". | Đổi font sang loại hỗ trợ đầy đủ tiếng Việt ở cả kiểu nghiêng (Times New Roman, hoặc nhúng đủ biến thể Italic/Bold-Italic trong Typst). Rà lại toàn bộ tiêu đề cấp 3–4 và chú thích hình. |
| Hình 5.6, 5.7, 5.8, 5.37, 5.39–5.42 | Ảnh terminal nền đen bị thu nhỏ (6 cửa sổ trong một hình), chữ không đọc được khi in. | Cắt sát vùng lệnh cần chứng minh, phóng to; ưu tiên chép kết quả lệnh ra khối văn bản (code block) và tô đậm dòng quan trọng. Có thể đổi terminal sang nền sáng khi chụp. |
| Chương 5 (33/58 trang) | Mất cân đối: Chương 2 chỉ 4 trang, Chương 5 có 42 hình. Nhiều hình trùng lặp (5.32–5.35, 5.39–5.42). | Gộp các hình cùng loại thành một hình có các ô (a), (b), (c), (d); chuyển ảnh thao tác từng bước sang Phụ lục hoặc tài liệu hướng dẫn sử dụng; dành dung lượng cho cơ sở lý thuyết và đánh giá. |
| Bảng ánh xạ Area ở mục 5.2.1.2 (sau Hình 5.4) | Bảng không có số và tên; chỉ liệt kê R1, R2. | Đánh số "Bảng 5.x", liệt kê đủ 6 router hoặc bỏ bảng vì đã có Bảng 5.1. |
| Danh mục từ viết tắt | Thiếu nhiều từ dùng trong bài: GLBP, VRRP, NTP, IOS, ICMP, TCP, UDP, TTL, LAN, MAC, DNS, ISP, ABR, ASBR, LSA, VPC, JSON, SHA, AES, GCM, CDP, LLDP, BGP, VRF, NETCONF, RESTCONF, YANG, TPM, HSM, ERD. Có từ không dùng (DPAPI chỉ xuất hiện 1 lần). | Rà toàn văn và bổ sung; sắp xếp theo thứ tự ABC (mục ".ntp" nên tách ra hoặc bỏ khỏi bảng vì không phải từ viết tắt). |
| Lời cam đoan | "Chúng tôi" ở Lời cam đoan nhưng "nhóm tác giả" ở các phần khác; tên đề tài viết thường, không có ngoặc kép. Bảng thành viên bị giãn chữ "Nguyễn Trần Đạt / Phú". | Thống nhất ngôi "nhóm tác giả"; ghi tên đề tài trong ngoặc kép, viết hoa chữ đầu; căn trái cột họ tên để tránh giãn chữ. |
| Mục lục | "Tài liệu tham khảo" viết thường trong khi các mục ngang cấp viết hoa; tiêu đề cấp 4 (5.2.1.1…) quá sâu. | Viết hoa "TÀI LIỆU THAM KHẢO"; giới hạn mục lục đến cấp 3. |
| Tài liệu tham khảo | Chỉ có 5 RFC; nhiều khẳng định (Syslog severity, GLBP, Netmiko, Jinja2, Qt, SQLite, Argon2id, AES-GCM) không có nguồn. Định dạng trộn ngôn ngữ ("và others", "thg."). | Bổ sung tối thiểu 15–20 tài liệu: RFC 5424 (Syslog), RFC 3164, RFC 9106 (Argon2), NIST SP 800-38D (GCM), tài liệu cấu hình Cisco IOS (GLBP, NAT, DHCP, OSPF), tài liệu Netmiko/Paramiko/Jinja2/Qt/SQLite, bài báo về network automation/intent-based networking. Dùng thống nhất một chuẩn (IEEE), "et al." hoặc "và cộng sự". |
| Thuật ngữ | Trộn Anh–Việt tùy tiện: "Push", "Save & Push", "Staged Save", "wizard", "upstream", "ping chéo", "severity". | Lần đầu xuất hiện: ghi thuật ngữ tiếng Việt kèm tiếng Anh trong ngoặc; sau đó dùng thống nhất. Tên nút trên giao diện để định dạng riêng (in đậm hoặc font mã). |
| Tóm tắt | Chưa có số liệu kết quả; chưa có Abstract tiếng Anh và từ khóa. | Thêm 1–2 câu kết quả định lượng và 4–6 từ khóa; bổ sung Abstract nếu mẫu của Học viện yêu cầu. |
| Chương 6 | Mục 6.3 lặp lại gần như nguyên văn 5.3.2. | Ở 5.3.2 chỉ nêu hạn chế quan sát được qua thực nghiệm; 6.3 tổng hợp hạn chế toàn đề tài. Bổ sung mục "Kiến nghị". |

## III. GÓP Ý VỀ NỘI DUNG

### 1. Cấu trúc và tính khoa học

- Chương 1 thiếu "Tính mới của đề tài".
- Mục tiêu (Bảng 1.1) chưa đo lường được. Nên đặt tiêu chí cụ thể, ví dụ: "triển khai OSPF cho 6 router trong ≤ X phút", "tỷ lệ bản tin Syslog phân tích thành công ≥ 99%", để Chương 5 và Bảng 6.1 có cơ sở đối chiếu.
- Chương 3 thiếu các mô hình phân tích thiết kế thường gặp: sơ đồ use case, sơ đồ tuần tự cho luồng View & Push và luồng Syslog, sơ đồ thực thể – quan hệ (ERD) hoặc ít nhất lược đồ các bảng chính. Tóm tắt đề cập "93 bảng nghiệp vụ" nhưng mục 3.6 không trình bày bảng nào.
- Tính nhất quán công nghệ: Chương 4 đề cập "bộ thu nhận C++", "terminal Alacritty", giao thức IPC "NTTP/1"; Bảng 6.1 đề cập "Clean Architecture", "Lazy Loading", "SHA-256". Các thành phần này chưa được giới thiệu ở Chương 2–3. Cần bổ sung vào Bảng 2.1 hoặc Hình 3.1 và giải thích lý do chọn C++ cho bộ thu Syslog.
- Tên gói dự án ".ntp" trùng với tên giao thức NTP (Network Time Protocol), dễ gây hiểu nhầm trong một báo cáo chuyên ngành mạng. Nên đổi phần mở rộng (ví dụ `.cams`) hoặc giải thích rõ.

### 2. Văn phong

Văn phong khoa học, khách quan, dùng câu ngắn. Các điểm cần điều chỉnh:

- **Lặp lại câu quá nhiều.** Các ý "chưa chứng minh…", "không thay thế…", "không đủ để kết luận…", "cần đồng bộ lại…" xuất hiện hơn 15 lần (2.1, 2.3.1, 2.4, 2.5, 2.6, 3.4.3, 3.6, 3.7, 4.3.2, 4.4.2, 4.4.3, 4.6.1, 4.6.2, 4.7…).
- **Sửa câu:** "Hệ thống sẽ được tổ chức thành bốn nhóm…" (1.2) nên đổi thành "Hệ thống được tổ chức…" vì sản phẩm đã hoàn thành.
- **Khẳng định mơ hồ:** "CAMS có thể hỗ trợ cả hai phương thức" (2.2) – phần mềm có hay không hỗ trợ Telnet? Nên viết dứt khoát.
- **Diễn đạt chưa chính xác:** "mà không phải chạy giao thức này trên switch truy cập" (5.2.1.2, Bước 3) – switch truy cập vốn không chạy OSPF; phương án thay thế thực sự là khai báo network kèm passive-interface trên router.
- **Mâu thuẫn quy trình:** Bước 2 Kịch bản 1 viết "quản trị viên nhấn Save & Push. Hệ thống sau đó đẩy cấu hình song song" – bỏ qua bước kiểm duyệt View & Push vốn được nhấn mạnh là điểm cốt lõi. Cần mô tả lại cho đúng luồng hoặc giải thích Routing Group có bước xem trước riêng.
- **Sai dữ liệu minh họa:** Hình 5.3 (Kịch bản 1) chọn router từ không gian làm việc "LAB_KICH_BAN_2". Cần chụp lại hoặc giải thích.

Bảng một số câu gợi ý viết lại:

| Câu hiện tại | Vấn đề | Gợi ý viết lại |
|---|---|---|
| "Hệ thống sẽ được tổ chức thành bốn nhóm chức năng dưới đây." (1.2) | Thì tương lai trong báo cáo kết quả | "Hệ thống được tổ chức thành bốn nhóm chức năng như Bảng 1.1." |
| "CAMS có thể hỗ trợ cả hai phương thức, nhưng ưu tiên SSH…" (2.2) | Không rõ đã hỗ trợ hay chưa | "CAMS hỗ trợ SSH (mặc định) và Telnet (chỉ dùng trong phòng lab khi thiết bị chưa bật SSH)." |
| "Quản trị viên mở terminal trên các máy trạm VPC và thực hiện ping chéo…" (Bước 6) | Khẩu ngữ | "…thực hiện kiểm tra kết nối ICMP giữa các máy trạm của hai chi nhánh." |
| "giá trị ttl=59 cho thấy gói tin đi qua năm hop định tuyến" (Bước 6) | Thiếu giả định TTL ban đầu | "Với TTL ban đầu 64 của VPCS, giá trị ttl=59 cho thấy gói tin đi qua 5 router (R2 → R1 → ISP1 → ISP2 → R6)." |

### 3. Kiến thức chuyên ngành

Phần lớn kiến thức nền (SSH, DHCP DORA, OSPF link-state, EIGRP advanced distance vector, PAT, wildcard mask, mức Syslog 0–7, logging trap) được trình bày đúng. Các điểm sai hoặc chưa chặt cần sửa:

| Vị trí | Nội dung trong báo cáo | Nhận xét | Đề xuất |
|---|---|---|---|
| Bảng 5.1 – Chi nhánh B | VPC14 (192.168.30.10, GW 192.168.30.1) và VPC15 (192.168.40.10, GW 192.168.40.1) cùng ghi "R6 Gi0/1". | Một cổng Lớp 3 không thể mang hai mạng khác nhau làm gateway chính (trừ khi dùng subinterface/secondary IP). Đây là lỗi quy hoạch hoặc lỗi ghi bảng. | Ghi đúng cổng (ví dụ Gi0/1.30 và Gi0/1.40 với 802.1Q, hoặc Gi0/1 và Gi0/2); kiểm tra lại sơ đồ Hình 5.1. |
| 5.2.1.2 Bước 3 – redistribute connected subnets | Dùng `redistribute connected` trên R2, R3, R6 mà không có route-map. | Lệnh sẽ đưa tất cả mạng kết nối trực tiếp vào OSPF, kể cả mạng quản trị 192.168.122.0/24 và các loopback chưa có trong network. Mạng quản trị OOB bị quảng bá vào miền dữ liệu là sai nguyên tắc. Ngoài ra, tuyến E2 có metric cố định 20, không phản ánh chi phí đường đi (thấy rõ ở Hình 5.8: tất cả [110/20]). | Dùng route-map/prefix-list chỉ cho phép 192.168.10/20/30/40.0/24; hoặc tốt hơn: network các mạng LAN + passive-interface. Kiểm tra bảng định tuyến xem 192.168.122.0/24 có bị quảng bá không. Thảo luận khác biệt E1/E2, vai trò ASBR. |
| Hình 5.5 – tham số Redistribute | "Tiến trình OSPF: 192.168.122.106 / PID 1", "Process ID nguồn: 1" khi nguồn là connected. | Nguồn connected không có Process ID; trường này chỉ có nghĩa khi tái phân phối từ OSPF/EIGRP khác. Ghi IP quản trị như tiến trình OSPF dễ nhầm. | Giải thích hoặc ẩn trường Process ID khi nguồn là connected/static (đồng thời là góp ý cho giao diện CAMS). |
| 5.2.1.1 – mô tả kiến trúc | Chưa nêu vai trò ABR/ASBR, loại LSA. | R1 nằm ở cả Area 0 và Area 1 → là ABR; R2, R3, R6 là ASBR (do redistribute). Tuyến 192.168.x xuất hiện trên R1 qua LSA Type 5. | Bổ sung phân tích này để thể hiện hiểu biết về OSPF đa vùng, không chỉ chụp kết quả. |
| 5.2.2 – GLBP | Mục tiêu nêu "cổng mặc định dự phòng và cân bằng tải" nhưng không thử nghiệm chuyển đổi dự phòng và cân bằng tải. | Kết quả chỉ chứng minh cấu hình được đẩy xuống, không chứng minh chức năng. Trong GLBP, priority chỉ quyết định AVG; cân bằng tải do AVG phân phối virtual MAC của các AVF. | Bổ sung: `show glbp brief` (AVG/AVF, virtual MAC), hai PC nhận 2 virtual MAC khác nhau (arp), shutdown Gi0/0 của R1 → ping liên tục đo thời gian gián đoạn. |
| 5.2.2 – DHCP | Pool LAN_R1 chỉ đặt trên R1, không có `ip dhcp excluded-address`. | DHCP chỉ trên R1 tạo điểm lỗi đơn, mâu thuẫn mục tiêu dự phòng. Không loại trừ 192.168.4.1–.3 (VIP, R1, R2) có nguy cơ cấp trùng địa chỉ (PC nhận .4 là do may mắn và cơ chế ping-check). Pool không có dns-server. | Thêm excluded-address 192.168.4.1 192.168.4.10; cấu hình pool trên R2 với dải chia đôi (hoặc giải thích chọn DHCP server riêng); bổ sung dns-server, lease. |
| 5.2.2 – NAT/PAT | Chỉ xác minh running-config; không có `show ip nat translations` / `show ip nat statistics`. | Chưa có bằng chứng PAT thực sự chuyển đổi địa chỉ. Cũng chưa trình bày định tuyến trên R1/R2 (default route về NAT) và tuyến quay về 192.168.4.0/24 trên router NAT. | Bổ sung ảnh/kết quả bảng NAT có địa chỉ inside local 192.168.4.4 → inside global 10.0.10.2:port; trình bày cấu hình định tuyến liên quan. |
| 5.2.2.2 Bước 8 – diễn giải traceroute | "Thiết bị phía ngoài trả về ICMP Destination port unreachable; vì vậy… không chứng minh kết nối hoàn chỉnh tới 1.1.1.1". | Diễn giải chưa đúng. VPCS/Cisco trace dùng gói UDP tới cổng cao; ICMP Port Unreachable (type 3, code 3) chính là tín hiệu đích đã nhận gói và trace kết thúc. Việc địa chỉ hiển thị là 10.0.10.1 cho thấy 1.1.1.1 là loopback trên router upstream, trả lời bằng IP của cổng ra. | Sửa lại diễn giải; bổ sung ping 1.1.1.1 và bảng NAT để kết luận chắc chắn. |
| 2.4 – tên các mức Syslog | "Theo quy ước của Cisco… Emergency, Alert, Critical, Error, Warning, Notice, Informational, Debug". | Đây là tên theo RFC 5424. Cisco IOS dùng: emergencies, alerts, critical, errors, warnings, notifications, informational, debugging (chính báo cáo dùng "logging trap notifications"). | Ghi đúng nguồn: bảng 2 cột RFC 5424 / từ khóa Cisco IOS, trích dẫn RFC 5424. |
| 5.2.3 – Facility | Hình 5.38 và mục 5.2.3.3 gọi LINEPROTO là "facility". | Trong bản tin `<189>`, PRI = 189 = 23×8 + 5 → facility syslog là local7 (mặc định của Cisco), severity 5. "LINEPROTO" là facility code (mã tính năng) trong định dạng `%FACILITY-SEVERITY-MNEMONIC` của Cisco. Hai khái niệm khác nhau. | Phân biệt rõ trong lý thuyết và giao diện (ví dụ cột "Syslog facility: local7" và "IOS facility: LINEPROTO"). |
| 5.2.3 – Timestamp | Bản tin có dấu "\*Aug 29 20:25:44.323". | Dấu "\*" trên Cisco IOS nghĩa là đồng hồ chưa được đồng bộ (chưa NTP). Mục 3.5 đã nêu vấn đề này nhưng thực nghiệm chưa xử lý. | Cấu hình NTP cho thiết bị trong kịch bản, hoặc nêu rõ đây là hạn chế và CAMS dùng thời gian nhận để sắp xếp. |
| 5.2.3 – Cổng 5514 | Không giải thích vì sao không dùng cổng chuẩn 514/UDP. | Cổng < 1024 trên Linux cần quyền root; đây là lý do hợp lý nhưng cần ghi ra. | Thêm 1 câu giải thích; nêu cách chuyển hướng 514→5514 nếu thiết bị chỉ hỗ trợ cổng mặc định. |
| 2.3.3 – DAI | "kiểm tra bản tin ARP dựa trên dữ liệu liên kết hoặc chính sách được cấu hình". | Diễn đạt mơ hồ. DAI đối chiếu cặp IP–MAC trong gói ARP với bảng DHCP Snooping binding hoặc ARP ACL; chỉ áp dụng trên cổng không tin cậy. | Viết lại chính xác; nêu mối phụ thuộc DAI vào DHCP Snooping. |
| Danh mục từ viết tắt – HSRP | "Giao thức định tuyến dự phòng nóng". | HSRP là giao thức dự phòng gateway, không phải giao thức định tuyến. | "Giao thức dự phòng router ở chế độ chờ nóng". |
| Mạng quản trị "ngoại băng" (5.1.1) | Gọi là out-of-band nhưng ở Kịch bản 3 cổng Gi0/0 vừa là cổng quản trị vừa có thể tham gia định tuyến; không dùng VRF quản trị. | Đúng nghĩa OOB cần tách biệt bảng định tuyến (VRF Mgmt hoặc cổng Management riêng). Nếu không, mạng quản trị có thể bị quảng bá (xem lỗi redistribute ở trên). | Mô tả đúng là "mạng quản trị riêng" hoặc cấu hình VRF quản trị. |
| 6.3 và Bảng 6.1 – bảo mật | 6.3 thừa nhận mật khẩu thiết bị lưu dạng rõ trong SQLite, trong khi 3.2 đặt yêu cầu "Bảo vệ dữ liệu" và Bảng 6.1 viết "Dữ liệu dự án được bảo vệ khi lưu trữ và chia sẻ". | Mâu thuẫn. Hình 4.7 cũng tự nêu "không thay thế kiểm thử mã hóa và giải mã", nên kết luận ở Bảng 6.1 thiếu bằng chứng. | Điều chỉnh Bảng 6.1 cho đúng phạm vi đã kiểm chứng (chỉ áp dụng khi bật bảo vệ gói .ntp); bổ sung một phép thử mã hóa/giải mã và thử mật khẩu sai. |

### 4. Thực nghiệm và đánh giá (Chương 5)

- **Bổ sung kịch bản an ninh mạng** để tương xứng tên đề tài, ví dụ:
  1. Bật Port Security trên SW1, cắm thêm MAC lạ → bản tin `%PORT_SECURITY-2-PSECURE_VIOLATION` về System Logs;
  2. DHCP Snooping + rogue DHCP server;
  3. DAI chặn ARP spoofing;
  4. ACL Extended kiểm tra cả lưu lượng được phép và bị chặn (như chính mục 4.4.3 đề ra).

  Mỗi kịch bản trình bày: tấn công/vi phạm → thiết bị phản ứng → CAMS ghi nhận và lọc được.
- **Bổ sung đánh giá định lượng:** bảng so sánh cấu hình thủ công qua CLI và bằng CAMS cho từng kịch bản (số lệnh, thời gian hoàn thành, số lỗi nhập liệu); thời gian Push cho 1, 3, 6 thiết bị (tuần tự và song song); thông lượng Syslog listener (bản tin/giây, chỉ số received/dropped khi bơm tải bằng công cụ như `logger` hoặc `loggen`).
- **Bổ sung kịch bản lỗi (negative test):** nhập sai IP/mask, thiết bị mất kết nối giữa lúc Push, lệnh bị IOS từ chối – kiểm tra CAMS có báo lỗi đúng thiết bị, giữ bản ghi Pending như mô tả ở 3.4.3 và 3.7 hay không.
- **Mục 5.3 "Đánh giá tổng hợp"** cần dựa trên số liệu, đối chiếu từng yêu cầu chức năng (Bảng 3.1) và phi chức năng (3.2) với kết quả: Đạt / Đạt một phần / Chưa kiểm chứng. Các chức năng SFTP, đóng gói dự án, EIGRP, chuyển mạch, VTP chưa có thử nghiệm thì không nên ghi là đã đạt trong Bảng 6.1.

## IV. DANH SÁCH CÁC CHỖ CẦN SỬA

| TT | Nội dung |
|---|---|
| 1 | Sửa lỗi font tiếng Việt in nghiêng; thêm trang bìa |
| 2 | Sửa Bảng 5.1 (cổng R6), redistribute có route-map, diễn giải traceroute, facility Syslog |
| 3 | Bổ sung minh chứng NAT (bảng NAT), GLBP failover, DHCP excluded-address |
| 4 | Thêm ít nhất 1–2 kịch bản an ninh (Port Security / DHCP Snooping / DAI / ACL) |
| 5 | Thêm tổng quan nghiên cứu, bảng so sánh công cụ, tính mới |
| 6 | Thêm đánh giá định lượng và kịch bản lỗi |
| 7 | Thêm use case, sơ đồ tuần tự, ERD; thống nhất danh mục công nghệ (C++, Alacritty, NTTP/1) |
| 8 | Làm lại ảnh chụp màn hình; gộp hình trùng lặp |
| 9 | Bổ sung tài liệu tham khảo (≥ 15), chuẩn IEEE; bổ sung danh mục viết tắt |
| 10 | Giảm câu rào đón lặp lại; thống nhất thuật ngữ; sửa Bảng 6.1 cho khớp minh chứng |

## V. KẾT LUẬN

Đề tài có mô phỏng, khối lượng lập trình đáng kể và phương pháp trình bày thực nghiệm rõ ràng, phù hợp với một công trình NCKH sinh viên. Để báo cáo hoàn chỉnh nhóm cần thực hiện:

1. Khắc phục các lỗi kỹ thuật trong Kịch bản 1 và 2;
2. Bổ sung kịch bản kiểm chứng an ninh mạng và số liệu định lượng;
3. Bổ sung tổng quan nghiên cứu (tính mới), tài liệu tham khảo;
4. Sửa lỗi font và chất lượng hình ảnh.
