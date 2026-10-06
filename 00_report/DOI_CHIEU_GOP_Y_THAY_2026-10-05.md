# Đối chiếu báo cáo CAMS với góp ý của giảng viên

Ngày kiểm tra: 05/10/2026.

Nguồn: `main.pdf` hiện tại (116 trang), `Góp ý chỉnh sửa báo cáo_nhóm Kiên.pdf` (7 trang), `nhan_xet.md` và các tệp Typst được `main.typ` đưa vào báo cáo. Không dùng `mainv2.pdf` hay các bản Markdown cũ làm bản hiện tại. Không sửa nội dung báo cáo trong lần kiểm tra này.

Số trang dưới đây là số **in ở chân trang báo cáo**; từ trang nội dung 1 trở đi, vị trí trong trình đọc PDF bằng số trang in + 17.

## Kết luận

Bản hiện tại đã xử lý nhiều góp ý về tổng quan, tính mới, tài liệu tham khảo và kiểm chứng an ninh. Những phần còn thiếu quan trọng nhất là đánh giá định lượng, thử lỗi, kiểm chứng GLBP/NAT/DHCP, và sự nhất quán giữa mô tả, ảnh bằng chứng, thiết kế dữ liệu và kết luận. Chưa có cơ sở kết luận đã hoàn tất toàn bộ góp ý.

## A. Việc cần ưu tiên trước khi nộp

### 1. Lọc tuyến OSPF chưa đáp ứng chính tuyên bố trong báo cáo

- Vị trí: mục 5.2.2.2, Bước 3; trang 51-53; `contents/09_thu_nghiem_danh_gia.typ`, dòng 126-160.
- Báo cáo viết rằng chỉ bốn mạng LAN được quảng bá và mạng quản trị `192.168.122.0/24` bị loại.
- Lệnh minh họa `ip prefix-list LAN_NETS permit 192.168.0.0/16 le 24` vẫn khớp `192.168.122.0/24`, đồng thời khớp nhiều mạng ngoài bốn LAN đã liệt kê. Thêm route-map chưa đủ nếu prefix-list quá rộng.
- Cần dùng các prefix chính xác cho bốn LAN hoặc `network` cùng `passive-interface`; triển khai và lưu lại cấu hình cùng kết quả kiểm tra thực tế.
- Hình 5.16 vẫn hiển thị `redistribute connected subnets` không có route-map, trong khi khối lệnh ngay dưới được giới thiệu là nội dung của cửa sổ này lại có `LAN_ONLY`. Phải thay ảnh bằng kết quả đã sửa hoặc ghi rõ đó là hai phiên bản khác nhau; không gọi khối lệnh mới là bản chép từ ảnh cũ.
- Bảng định tuyến R1 có mạng quản trị dạng connected. Sự vắng mặt của một dòng OSPF cho cùng prefix trên chính R1 không đủ chứng minh mạng quản trị chưa bị quảng bá. Cần kiểm tra cấu hình ASBR, external LSA hoặc router không có tuyến connected cùng prefix.

### 2. Chưa có đánh giá định lượng theo yêu cầu của thầy

- Vị trí: mục 1.4, 5.3 và 6.1.
- Có mục tiêu 6 thiết bị trong tối đa 30 giây, sinh lệnh đúng 100%, phân tích đúng ít nhất 99%; chưa có kết quả đo tương ứng.
- Số gói ping thành công và bộ đếm bản tin Syslog là số liệu quan sát chức năng, chưa phải đánh giá hiệu quả tự động hóa hay hiệu năng bộ thu.
- Cần bảng CLI/CAMS về thời gian, số lệnh/thao tác, số lỗi nhập liệu; thời gian Push cho 1/3/6 thiết bị, tuần tự/song song; thử tải Syslog với tổng gửi/nhận/lưu/bị loại, tốc độ và khoảng đo.
- Ghi máy thử cụ thể, phiên bản, trạng thái kết nối ban đầu, số lệnh và số lần lặp. Mục 5.1.1 hiện ghi hệ điều hành và CPU bằng các lựa chọn “hoặc”, chưa xác định cấu hình máy thực sự dùng.

### 3. Chưa có thử lỗi của quy trình CAMS

- Cần ca sai IP/mask, mất kết nối giữa lúc Push, và lệnh bị IOS từ chối.
- Mỗi ca cần đầu vào, lỗi mong đợi, phản hồi CAMS theo thiết bị, trạng thái Pending/Applied sau lỗi và cấu hình thực trên thiết bị.
- Các thử lưu lượng bị ACL/DAI chặn đã có, nhưng không thay cho thử lỗi của phần mềm quản lý và thực thi.

### 4. GLBP, DHCP và PAT còn thiếu minh chứng vận hành

- Vị trí: mục 5.2.3, trang 58-68.
- GLBP: hiện chủ yếu xác minh running-config. Chưa có `show glbp brief`, AVG/AVF, virtual MAC trên hai client, thử ngắt gateway và đo gián đoạn. Cấu hình priority và preempt không tự chứng minh dự phòng/cân bằng tải.
- DHCP: pool `LAN_R1` vẫn thiếu `ip dhcp excluded-address`, `dns-server`, `lease`; chưa có dự phòng server hoặc giải thích rõ DHCP chỉ chạy trên R1. Nếu thêm dải loại trừ .1-.10, phải chạy lại bài thử; kết quả client .4 cũ không còn phù hợp với cấu hình mới.
- PAT: chưa có `show ip nat translations`/`show ip nat statistics` khi phát sinh lưu lượng. Cần mô tả tuyến mặc định của R1/R2 và tuyến quay về LAN trên router NAT; running-config chứa lệnh PAT chưa chứng minh phiên chuyển đổi thực.

### 5. Diễn giải traceroute vẫn chưa được sửa

- Vị trí: mục 5.2.3.2, Bước 8; trang 68; dòng 405 trong tệp thực nghiệm.
- Vẫn suy luận `Destination port unreachable` là lý do chưa tới đích. Với traceroute UDP, ICMP Type 3 Code 3 có thể là tín hiệu kết thúc tại đích; không được xem riêng thông báo này là thất bại.
- Đối chiếu địa chỉ phản hồi, cấu hình upstream và địa chỉ đích; thêm ping `1.1.1.1` và bảng NAT. Tránh kết luận chắc chắn về đích khi chưa đối chiếu cấu hình.
- Tài liệu Cisco: https://www.cisco.com/c/en/us/support/docs/ip/ip-routed-protocols/22826-traceroute.html

### 6. Chương 6 còn kết luận cũ và mâu thuẫn bảo mật/cảnh báo

- Vị trí: Bảng 6.1 và mục 6.3-6.4; trang 90-92.
- Bảng 6.1 còn ghi hoàn thành ba kịch bản; Chương 5 hiện có năm.
- Chương 2-3 mô tả mã hóa thông tin xác thực `ENC$v2$`, nhưng 6.3-6.4 vẫn mô tả mật khẩu dạng rõ và đưa mã hóa thành việc tương lai. Cần thống nhất phạm vi phiên bản, dữ liệu cũ chưa di chuyển, dự án có/không có mật khẩu và giới hạn bảo vệ khóa.
- Email đã được hiện thực và minh chứng ở Kịch bản 4, nhưng 6.4 vẫn đưa gửi cảnh báo email vào hướng phát triển. Nên mô tả phần mở rộng chưa làm, như tương quan nâng cao/webhook.
- Bảng 6.1 ghi “Dữ liệu dự án được bảo vệ khi lưu trữ và chia sẻ” nhưng chưa có thử mở gói đúng/sai mật khẩu và sửa bản mã để xác minh từ chối.
- Cần ma trận yêu cầu - ca thử - bằng chứng - Đạt/Đạt một phần/Chưa kiểm chứng cho cả yêu cầu chức năng và phi chức năng. SFTP, EIGRP, VTP, đóng gói và các tính năng khác chưa có ca thử riêng không nên được kết luận đạt toàn bộ.

### 7. Chương 3 có hai mô tả lược đồ không nhất quán; thiếu hai sơ đồ

- Vị trí: mục 3.1, 3.4.3 và 3.7; trang 18, 21, 24-25.
- Bảng 3.3 dùng `t02_interfaces`, `t03_routing_ospf`, `t04_acl_rules`, `t05_nat_pat`, `t06_syslog_events`; các tên này không có trong SQL schema hiện tại được kiểm tra.
- Bảng 3.4 ngay sau lại dùng tên thực tế như `t02_interface_name`, `t04_ospf_processes`, `t05_extended_acl_rules`, `t12_syslog_messages`. Cần bỏ/sửa bảng cũ, không giữ hai bộ tên như cùng mô tả một lược đồ thực tế.
- Có ERD (Hình 3.4) và sơ đồ tuần tự Syslog (Hình 3.3).
- Chưa có sơ đồ use case. Hình 3.2 là lưu đồ, chưa phải sơ đồ tuần tự View & Push có các đối tượng và thông điệp như thầy yêu cầu.
- Con số 93 bảng vẫn xuất hiện tại 3.7 và Bảng 6.1; cần gắn với phiên bản/lược đồ cụ thể hoặc bỏ số này nếu chưa kiểm đếm tái lập.

## B. Góp ý còn sửa một phần hoặc cần hoàn thiện

| Góp ý | Tình trạng hiện tại | Việc còn lại |
|---|---|---|
| Bìa chính, bìa phụ | Đã có cả hai | Chưa có mã số đề tài; đối chiếu mẫu Học viện và bổ sung nếu đã được cấp. Không tự đặt mã số. |
| Font tiếng Việt, lời cam đoan | Các trang mẫu kiểm tra hiển thị đúng; đã dùng “nhóm tác giả” | Kiểm tra lần cuối toàn bộ bản in; chưa tuyên bố mọi trang hoàn toàn hết lỗi. |
| Mục lục | Đã giới hạn cấp 3; TÀI LIỆU THAM KHẢO viết hoa | Đã xử lý góp ý này. |
| Tổng quan và tính mới | Có mục 1.2, 1.3 và bảng so sánh ở Chương 2 | Nên bổ sung bài báo nghiên cứu cụ thể nếu cần làm rõ tổng quan học thuật; danh mục hiện chủ yếu là tài liệu chuẩn, tài liệu công cụ và sách. |
| Tóm tắt | Có số liệu quan sát và sáu từ khóa | Chưa có Abstract tiếng Anh; bổ sung nếu mẫu Học viện yêu cầu. Cập nhật kết quả định lượng sau khi đo. |
| Tài liệu tham khảo | PDF có 53 tài liệu; dùng IEEE; có RFC/NIST và nguồn công nghệ | Vẫn có “and others” tại [16], [21]; chuẩn hóa danh sách tác giả/“et al.” theo yêu cầu. |
| Danh mục viết tắt | Đã bổ sung phần lớn các từ được thầy chỉ ra; HSRP đã sửa đúng gateway | Rà thứ tự ABC: AAD hiện trước ABR/ACL/AES. Bảng không còn đưa .ntp thành từ viết tắt. |
| Cổng R6 | Bảng 5.6 đã sửa thành Gi0/1.30 và Gi0/1.40 | Cần có running-config subinterface, encapsulation dot1Q và trunk phù hợp để chứng minh quy hoạch đã sửa đúng thực nghiệm. |
| ABR/ASBR/LSA | Đã bổ sung phân tích vai trò | Cần giải thích thêm metric E1/E2 và đồng bộ ảnh/cấu hình sau sửa route-map. |
| Bảng ánh xạ Area | Vẫn không số/tên; chỉ liệt kê R1/R2 | Trang 51: thêm caption và đầy đủ sáu router hoặc bỏ bảng nếu trùng dữ liệu. |
| Quy trình Routing Group | Vẫn viết chọn Save & Push rồi đẩy trực tiếp | Trang 51: mô tả đúng bước kiểm duyệt hoặc giải thích quy trình riêng; đối chiếu với tuyên bố View & Push bắt buộc ở 1.3. |
| Đánh số kịch bản | Tiêu đề có năm kịch bản mới | Đoạn giới thiệu còn gọi Kịch bản 5 là kiểm thử phân quyền/mật mã trong khi nội dung thực tế là ACL; phần OSPF còn gọi Kịch bản 1 và GLBP còn gọi Kịch bản 2. Sửa cả caption/bảng. |
| TTL, thuật ngữ | Một số câu góp ý cũ vẫn còn | Trang 56: “ping chéo” và diễn giải ttl=59 thiếu giả định TTL ban đầu. Định nghĩa thuật ngữ Anh-Việt lần đầu, định dạng tên nút nhất quán. |
| Mạng quản trị | Vẫn gọi “ngoại băng/Out-of-Band” ở 5.1.1 và Bảng 5.6 | Dùng “mạng quản trị riêng” nếu chưa có minh chứng tách cổng/bảng định tuyến theo kiến trúc OOB. |
| .ntp và NTP | Vẫn dùng .ntp và dấu nhận dạng NTPAES1 | Thêm giải thích đây là định dạng gói dự án, khác giao thức đồng bộ thời gian NTP; không bắt buộc đổi phần mở rộng nếu đã giải thích rõ. |
| Công nghệ C++, Alacritty, NTTP/1, SHA-256 | Đã bổ sung ở Chương 2-3 | Lý do dùng C++ chủ yếu giải thích tách tiến trình, chưa giải thích rõ lựa chọn C++ thay cho phương án Python. Clean Architecture/Lazy Loading vẫn xuất hiện như tên kết luận, nên gắn với mô hình và minh chứng cụ thể. |
| Ảnh và cân đối chương | DAI/Snooping đã cắt vùng; có ảnh terminal dựng từ văn bản | Hình 5.17 vẫn ghép sáu terminal với chữ nhỏ; Hình 5.31 còn ảnh giao diện có nhiều khoảng trống. Chương 2 hiện 13 trang, Chương 5 54 trang và 61 hình; đã cải thiện lý thuyết nhưng phần thực nghiệm vẫn nặng mô tả thao tác. Chuyển ảnh từng bước sang phụ lục/hướng dẫn, giữ chứng cứ trọng tâm. |
| Hạn chế và kiến nghị | 5.3.2 vẫn nêu hỗ trợ hãng/rollback giống 6.3 | Chuyển 5.3.2 sang hạn chế quan sát từ phép thử; 6.3 tổng hợp toàn đề tài; bổ sung mục Kiến nghị. |

## C. Phần an ninh đã được bổ sung, không nên tiếp tục coi là hoàn toàn thiếu

- DHCP Snooping: có mô hình hai server, thay đổi trust, địa chỉ client, binding và bộ đếm. Báo cáo đã giới hạn đúng ý nghĩa số 160 drop; chưa gán nó thành số gói rogue của riêng một server.
- DAI: có trạng thái hợp lệ - đổi IP ngoài binding - khôi phục; ping 5/5 - 0/5 - 5/5, bộ đếm 9 ARP bị chặn, Syslog SW_DAI và cảnh báo do CAMS sinh. Đây là thử sai lệch IP-MAC, không được gọi là đã thực hiện tấn công chiếm quyền lưu lượng hoàn chỉnh.
- ACL: có lưu lượng cho phép/từ chối, vị trí áp dụng, bản tin SEC và bảng ca thử.
- Syslog: có phân tích, phân biệt Syslog facility từ PRI với mã phân hệ Cisco; lý do cổng 5514; xử lý dấu thời gian chưa đồng bộ; ảnh email mức Error/Warning.
- Do đã có các thử an ninh này, Port Security là phép thử bổ sung tùy phạm vi kết luận, không phải điều kiện bắt buộc duy nhất để đáp ứng yêu cầu thêm 1-2 kịch bản của thầy.

## D. Thứ tự sửa đề nghị

1. Sửa lỗi OSPF và sự lệch giữa ảnh với khối lệnh; sửa traceroute, hai bảng schema, đánh số kịch bản và kết luận cũ.
2. Thực hiện GLBP failover/cân bằng tải, PAT translations và DHCP exclusions; lưu bằng chứng mới.
3. Đo CLI/CAMS, Push 1/3/6 thiết bị, Syslog và các ca lỗi; không điền số liệu giả định thành kết quả thực nghiệm.
4. Viết lại 5.3 và Bảng 6.1 theo ma trận yêu cầu/bằng chứng/trạng thái.
5. Bổ sung use case và sequence View & Push; thu gọn ảnh, rà thuật ngữ, tài liệu tham khảo, Abstract/mẫu bìa/kiến nghị.

Tài liệu kỹ thuật kiểm tra chéo quy tắc prefix-list: https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/command/irg-cr-book/bgp-c1.html

Giới hạn: đây là kiểm tra báo cáo và bằng chứng đã lưu, không phải chạy lại phòng lab hay xác nhận toàn bộ hoạt động phần mềm.
