# Kịch bản thuyết trình bốn lab CAMS

Dùng với bản PPTX 23 slide: Lab 1 DHCP Snooping/DAI, Lab 2 OSPF, Lab 3 Syslog/email, Lab 4 ACL. Lab 3 và 4 trên slide tương ứng kịch bản 4 và 5 trong báo cáo.

Phần lời dẫn dự kiến 10 phút, gồm thời gian chỉ vào ảnh và chuyển trang. Đây là thời lượng tập nói, không phải số liệu đo hiệu năng phần mềm. Ảnh là kết quả thực nghiệm đã ghi trước.

## Slide 1 · Mô hình kiểm thử DHCP Snooping

**LAB 1 · DHCP SNOOPING / DAI — 00:00–00:25 (25 giây)**

Sau đây nhóm trình bày bốn lab để kiểm chứng cấu hình và giám sát trên CAMS. Lab đầu tiên kiểm tra DHCP Snooping và DAI. Trong mô hình, R1 và FAKE_DHCP cấp hai dải địa chỉ khác nhau, SW1 thực hiện kiểm tra, còn R2 là máy khách. Nhóm thay đổi cổng tin cậy rồi đối chiếu địa chỉ thực tế mà R2 nhận được.

*Chỉ vào ảnh: Hai nguồn DHCP, SW1 và R2.*

## Slide 2 · Thao tác CAMS: chọn cổng DHCP tin cậy

**LAB 1 · DHCP SNOOPING — 00:25–00:50 (25 giây)**

Trên CAMS, nhóm chọn SW1, mở Security và L2 Security. DHCP Snooping được bật cho VLAN 10, sau đó cổng Gi0/1 nối R1 được đặt là cổng tin cậy. Cổng Gi0/2 của máy khách vẫn không tin cậy. Phần DHCP Snooping này tắt DAI để hai cơ chế được kiểm tra riêng. Nhóm gửi cấu hình rồi mới kiểm tra kết quả.

*Chỉ vào ảnh: Snooping VLANs và dòng GigabitEthernet0/1 / DHCP trust.*

## Slide 3 · Địa chỉ nhận được khi đổi cổng tin cậy

**LAB 1 · DHCP SNOOPING — 00:50–01:15 (25 giây)**

Khi tin cậy cổng nối R1, lệnh show xác nhận R2 nhận địa chỉ 192.168.10.4 bằng DHCP. Sau khi chuyển cổng tin cậy sang Gi0/3 và yêu cầu cấp lại địa chỉ, R2 nhận 192.168.66.100 từ máy chủ thứ hai. Kết quả cho thấy nguồn cấp được chấp nhận phụ thuộc vào cổng tin cậy. Tên FAKE_DHCP chỉ dùng để nhận diện thiết bị thử nghiệm.

*Chỉ vào ảnh: Dòng Gi0/2 nhận .10.4 và ảnh CAMS nhận .66.100.*

## Slide 4 · Thiết lập DAI trên VLAN 10

**LAB 1 · DAI — 01:15–01:35 (20 giây)**

Trước khi thử DAI, nhóm mở SW1, chọn Security, L2 Security và VLAN Protection. Với VLAN 10, nhóm giữ DHCP Snooping bật và bật thêm Dynamic ARP Inspection. Sau khi lưu chính sách, nhóm kiểm tra rồi áp dụng qua View & Push. Ảnh này ghi bước thiết lập; trạng thái hoạt động cần đối chiếu tiếp trên switch.

*Chỉ vào ảnh: VLAN 10 có Snooping và DAI Enabled; nút Enable DAI và Save Policy.*

## Slide 5 · Thiết lập cổng DAI tin cậy trên CAMS

**LAB 1 · DAI — 01:35–01:55 (20 giây)**

Tiếp theo, trong Trusted Uplinks, nhóm thiết lập Gi0/1 nối R1 là cổng tin cậy cho cả DHCP và ARP Inspection. Gi0/2 nối máy khách R2 vẫn không tin cậy để ARP được kiểm tra theo bảng liên kết. Dòng đã lưu trên ảnh xác nhận Gi0/1 có DHCP cộng ARP trust. Chính sách này được giữ trong phép thử vi phạm và khôi phục.

*Chỉ vào ảnh: Dòng đã lưu Gi0/1: DHCP + ARP trust; lựa chọn Trust ARP Inspection.*

## Slide 6 · Thao tác CAMS: tạo IP không khớp bảng liên kết

**LAB 1 · DAI — 01:55–02:15 (20 giây)**

Tiếp theo là phép thử DAI. Khi bảng liên kết DHCP đã học địa chỉ hợp lệ của R2, nhóm dùng CAMS đổi địa chỉ Gi0/2 sang 192.168.10.250. Địa chỉ mới không khớp bảng liên kết. Đây là cách tạo một trường hợp vi phạm có kiểm soát để kiểm tra khả năng loại bỏ ARP.

*Chỉ vào ảnh: Ô IPv4 address 192.168.10.250.*

## Slide 7 · Đối chứng: DHCP hợp lệ và IP không khớp binding

**LAB 1 · DAI — 02:15–02:45 (30 giây)**

Ảnh này đối chiếu hai lần ping tới cùng R1 từ cùng cổng của R2. Với địa chỉ DHCP hợp lệ là .4, R2 nhận đủ năm hồi đáp. Khi dùng địa chỉ tĩnh .250 không khớp bảng liên kết, không có hồi đáp nào. Để xác định nguyên nhân, nhóm tiếp tục kiểm tra bộ đếm DAI và nhật ký trên switch, thay vì chỉ dựa vào ping thất bại.

*Chỉ vào ảnh: Hai dòng Success rate và hai địa chỉ nguồn .4, .250.*

## Slide 8 · Bộ đếm vi phạm và cảnh báo trên CAMS

**LAB 1 · DAI — 02:45–03:15 (30 giây)**

Bộ đếm DAI trên SW1 ghi nhận chín bản tin ARP bị loại bỏ. Đây là số ARP, không phải số gói ping. Bên dưới, CAMS nhận các bản tin SW_DAI và sinh cảnh báo DAI_ARP_SPOOF. Như vậy, phép thử có cả hành vi mất kết nối và nhật ký tương ứng. Cảnh báo được tổng hợp từ bản tin của thiết bị; số sự kiện trong cảnh báo không cần bằng bộ đếm ARP.

*Chỉ vào ảnh: Dropped = 9 và dòng DAI_ARP_SPOOF.*

## Slide 9 · Khôi phục DHCP và kiểm tra lại kết nối

**LAB 1 · DAI — 03:15–03:35 (20 giây)**

Sau khi khôi phục DHCP, R2 nhận địa chỉ .5 và ping tới R1 lại thành công năm trên năm. Chuỗi đối chứng gồm trạng thái hợp lệ, trạng thái vi phạm và trạng thái khôi phục. Qua đó, nhóm kiểm chứng việc xử lý ARP sai lệch với bảng liên kết, trong phạm vi phép thử đã thực hiện.

*Chỉ vào ảnh: Nguồn 192.168.10.5 và kết quả 5/5.*

## Slide 10 · Mô hình OSPF trên 5 router

**LAB 2 · OSPF — 03:35–04:00 (25 giây)**

Lab thứ hai kiểm tra OSPF trên năm router. R1, R2 và R3 dùng chung mạng trung chuyển qua SW1; R3 nối R4 và R4 nối R5. Các máy trạm nằm trong ba LAN phía R1, R2 và R5. Mạng quản trị 192.168.122.0/24 chỉ dùng kết nối CAMS và được loại khỏi phần quảng bá OSPF.

*Chỉ vào ảnh: R1–R3 qua SW1, R3–R4–R5 và ba LAN.*

## Slide 11 · Khai báo nhóm và chọn mạng trên CAMS

**LAB 2 · OSPF — 04:00–04:30 (30 giây)**

Nhóm mở Routing Group trên CAMS và chọn R1 đến R5. Tiếp theo chọn những mạng cần quảng bá cho từng router. Ảnh bên phải cho thấy mạng quản trị không được chọn, còn mạng trung chuyển, LAN và Loopback được chọn. Sau khi rà soát, nhóm gửi cấu hình theo nhóm. Những cổng nối router có ngoại lệ no passive để hình thành láng giềng.

*Chỉ vào ảnh: Năm router được chọn; mạng quản trị không được chọn.*

## Slide 12 · Xác minh láng giềng và tuyến học được trên R1

**LAB 2 · OSPF — 04:30–05:00 (30 giây)**

Sau triển khai, nhóm dùng lệnh show trên thiết bị để kiểm chứng. R1 có quan hệ láng giềng FULL với R2 và R3. Bảng định tuyến có các tuyến OSPF tới LAN phía R2 và R5. Đây là bằng chứng thiết bị đã hình thành quan hệ định tuyến và học tuyến ở xa. Nhóm cũng có ảnh xác minh trên các router còn lại trong báo cáo.

*Chỉ vào ảnh: FULL/BDR, FULL/DR và hai tuyến LAN ở xa.*

## Slide 13 · Ping và trace từ VPC8 tới VPC10

**LAB 2 · OSPF — 05:00–05:30 (30 giây)**

Từ VPC8, nhóm ping tới VPC10 và nhận đủ năm hồi đáp. Phép trace cho thấy lưu lượng đi qua R1, R3, R4, R5 rồi tới máy đích, phù hợp với mô hình và tuyến học được. Thông báo port unreachable ở chặng cuối là phản hồi của máy đích đối với UDP trace. Bộ thử xác nhận kết nối liên LAN, chưa đo thời gian hội tụ khi liên kết bị mất.

*Chỉ vào ảnh: Năm hồi đáp và năm chặng của trace.*

## Slide 14 · Mô hình thu thập Syslog tập trung

**LAB 3 · SYSLOG / EMAIL — 05:30–05:50 (20 giây)**

Lab thứ ba là thu thập Syslog và gửi email cảnh báo. Ba router cùng một switch kết nối qua mạng quản trị và gửi nhật ký về CAMS tại 192.168.122.1, cổng 5514 UDP. Trong phần trình bày này, Lab 3 tương ứng với kịch bản Syslog số 4 trong báo cáo.

*Chỉ vào ảnh: Ba router, switch và nhánh Management.*

## Slide 15 · Thao tác CAMS: khai báo chính sách Syslog

**LAB 3 · SYSLOG / EMAIL — 05:50–06:15 (25 giây)**

Trên CAMS, nhóm khai báo một chính sách Syslog chung cho bốn thiết bị. Các tham số gồm địa chỉ máy nhận, giao thức UDP, cổng 5514 và mức Notifications. Nhóm bật dấu thời gian mili giây và số thứ tự để hỗ trợ đối chiếu sự kiện. Việc khai báo theo nhóm tập trung những tham số chung trong một biểu mẫu.

*Chỉ vào ảnh: Server IP, UDP, 5514 và Notifications.*

## Slide 16 · Thao tác CAMS: kiểm tra lệnh trước khi gửi

**LAB 3 · SYSLOG / EMAIL — 06:15–06:40 (25 giây)**

Trước khi gửi, CAMS hiển thị tập lệnh sinh ra cho bốn thiết bị. Nhóm kiểm tra đích nhận, mức log và cổng nguồn. Switch sử dụng Vlan1, còn các router sử dụng Gi0/0 làm nguồn gửi. Màn hình này cho phép rà soát tập lệnh trước khi Push; kết quả nhận nhật ký ở trang sau là bước xác minh tiếp theo.

*Chỉ vào ảnh: Bốn target devices, logging host và source-interface.*

## Slide 17 · CAMS nhận và phân tích nhật ký tập trung

**LAB 3 · SYSLOG / EMAIL — 06:40–07:10 (30 giây)**

System Logs đã nhận bản tin từ cả ba router và switch. CAMS phân tách địa chỉ nguồn, nhóm nguồn Syslog, mức độ nghiêm trọng, mã sự kiện và nội dung. Ví dụ, dòng của SW1 có IP nguồn 192.168.122.104 và mức Error. Khi cần kiểm tra chi tiết, người quản trị có thể đối chiếu các trường này với bản tin gốc.

*Chỉ vào ảnh: Các IP nguồn và dòng SW1 / LINK / 3 Error.*

## Slide 18 · Thư cảnh báo chứa sự kiện từ thiết bị

**LAB 3 · SYSLOG / EMAIL — 07:10–07:35 (25 giây)**

Đây là email cảnh báo cho sự kiện của SW1. Thư giữ lại tên thiết bị, IP nguồn, mã LINK-3-UPDOWN, nội dung cổng Gi1/3 chuyển trạng thái và bản tin gốc. Các trường khớp với sự kiện nhận trong CAMS. Kết quả xác nhận chuỗi tiếp nhận, phân tích và gửi cảnh báo; nhóm chưa dùng phép thử này để kết luận về độ trễ email hay tải Syslog lớn.

*Chỉ vào ảnh: SW1, LINK-3-UPDOWN, Gi1/3 và bản gốc.*

## Slide 19 · Mô hình phân tách chính sách theo VLAN

**LAB 4 · ACL — 07:35–08:00 (25 giây)**

Lab thứ tư kiểm tra ACL, tương ứng với kịch bản số 5 trong báo cáo. R1 định tuyến giữa ba VLAN, R2 thực hiện NAT và R3 cung cấp đích thử 203.162.4.1. VLAN 10 bị chặn TCP cổng 23 tới 192.168.12.2; VLAN 20 bị chặn TCP cổng 80 tới máy chủ; VLAN 30 bị chặn ICMP tới cùng máy chủ.

*Chỉ vào ảnh: Ba VLAN phía R1, R2 NAT và R3 làm đích thử.*

## Slide 20 · Thao tác CAMS: khai báo và xem luật ACL

**LAB 4 · ACL — 08:00–08:30 (30 giây)**

Trên CAMS, nhóm khai báo hai ACL mở rộng. Ảnh cho thấy danh sách ACL đã lưu và các luật có thứ tự xử lý. Với VLAN 10, luật deny chọn đúng giao thức, mạng nguồn, địa chỉ đích và cổng 23; luật permit cho phép phần lưu lượng còn lại. ACL thứ hai xử lý hai điều kiện của VLAN 20 và VLAN 30.

*Chỉ vào ảnh: Hai ACL được lưu và hai luật deny / permit.*

## Slide 21 · Xác minh luật ACL và chiều áp dụng trên R1

**LAB 4 · ACL — 08:30–08:55 (25 giây)**

Nhóm xác minh trên R1 bằng lệnh show ip interface và show access-lists. Các ACL được gắn chiều vào trên ba cổng con của từng VLAN. Danh sách luật thể hiện đúng các điều kiện deny và permit đã khai báo. Từ khóa log cho phép đối chiếu lưu lượng thử với nhật ký. Tên ACL có chữ R2, nhưng đích 192.168.12.2 trong mô hình này thuộc R1.

*Chỉ vào ảnh: Inbound access list trên ba cổng con và các luật log.*

## Slide 22 · Kết quả lưu lượng bị từ chối theo chính sách

**LAB 4 · ACL — 08:55–09:25 (30 giây)**

Khi VPC8 thuộc VLAN 20 thử TCP cổng 80 tới máy chủ, router trả ICMP Type 3 Code 13, tức bị từ chối theo chính sách. Tương tự, VPC9 thuộc VLAN 30 ping tới máy chủ cũng bị từ chối. Đây là hai lưu lượng trùng điều kiện deny. Để tránh nhầm với lỗi mất kết nối toàn bộ, nhóm đối chiếu thêm những lưu lượng được phép trong nhật ký.

*Chỉ vào ảnh: TCP/80 từ VLAN 20 và ICMP từ VLAN 30 đều có Code 13.*

## Slide 23 · Đối chiếu denied và permitted trong System Logs

**LAB 4 · ACL — 09:25–10:00 (35 giây)**

Trong System Logs, cùng nguồn VLAN 20 có ICMP được phép nhưng TCP cổng 80 bị từ chối. Lưu lượng TCP cổng 80 từ VLAN 30 cũng được phép. Như vậy, chính sách phân biệt đúng nguồn và dịch vụ, đồng thời có nhật ký đối chứng. Qua bốn lab, nhóm cho thấy CAMS hỗ trợ khai báo tập trung, triển khai và kiểm tra bằng trạng thái thiết bị, lưu lượng thực tế cùng sự kiện tương ứng.

*Chỉ vào ảnh: Dòng permitted ICMP từ .20.1 và denied TCP tới cổng 80.*

## Phần demo bằng ảnh trong 5 phút

Nếu phần trình bày tổng quan dùng bộ slide chung của nhóm, có thể dùng bản PPTX này cho riêng 5 phút demo và nói theo bản rút gọn dưới đây. Không đọc lại toàn bộ lời dẫn 10 phút.

**00:00–01:30 · Lab 1 — slide 2, 3, 4, 5, 7, 8, 9**

“Trên CAMS, nhóm chọn cổng DHCP tin cậy. Khi tin cậy Gi0/1, R2 nhận .10.4; khi chuyển sang Gi0/3 và cấp lại DHCP, R2 nhận .66.100. Với DAI, nhóm bật bảo vệ VLAN 10 và đặt Gi0/1 là cổng ARP tin cậy; Gi0/2 phía máy khách vẫn không tin cậy. IP hợp lệ ping được, còn IP .250 không khớp binding thì không có hồi đáp. Bộ đếm ghi chín ARP bị loại bỏ và CAMS có cảnh báo tương ứng. Khi khôi phục DHCP, kết nối trở về 5/5.” Chỉ vào từng kết quả, dừng ngắn ở dòng bộ đếm và cảnh báo.

**01:30–02:40 · Lab 2 — slide 11, 12, 13**

“Nhóm chọn năm router và các mạng nghiệp vụ trên Routing Group, loại mạng quản trị. Sau triển khai, lệnh show xác nhận láng giềng FULL và tuyến OSPF tới LAN ở xa. VPC8 ping VPC10 nhận năm hồi đáp; trace đi qua R1, R3, R4, R5 rồi đến máy đích.” Chỉ vào ô chọn mạng quản trị, trạng thái FULL và các chặng trace.

**02:40–03:40 · Lab 3 — slide 15, 16, 17, 18**

“Chính sách Syslog khai báo đích 192.168.122.1:5514/UDP. CAMS cho kiểm tra lệnh trước khi gửi cho bốn thiết bị. Các sự kiện xuất hiện trong System Logs. Email của SW1 giữ cùng IP nguồn, mã LINK-3-UPDOWN, nội dung cổng và bản tin gốc.” Chỉ vào một dòng SW1 và đối chiếu ngay với email.

**03:40–05:00 · Lab 4 — slide 20, 21, 22, 23**

“Nhóm khai báo luật ACL trên CAMS, sau đó kiểm tra chiều áp dụng và luật thật trên R1. TCP/80 từ VLAN 20 và ICMP từ VLAN 30 bị từ chối theo chính sách. Trong nhật ký, ICMP từ VLAN 20 và TCP/80 từ VLAN 30 vẫn được phép. Kết quả cho thấy chính sách lọc đúng phạm vi và có bằng chứng để đối chiếu.” Dừng ở cặp denied/permitted trước khi kết thúc.

## Ghi nhớ khi trình bày

Không đọc từng dòng lệnh. Nêu mục tiêu, thao tác và kết quả; dùng con trỏ chỉ vào đúng dòng ảnh. Gọi phần này là demo qua ảnh thực nghiệm đã ghi nhận. Không khẳng định CAMS nhanh hơn CLI theo số giây, không dùng 5/5 ping làm tỷ lệ triển khai thành công và không dùng bộ đếm log làm thông lượng. Nếu thầy hỏi sâu, quay lại ảnh show hoặc bản tin gốc trong báo cáo.
