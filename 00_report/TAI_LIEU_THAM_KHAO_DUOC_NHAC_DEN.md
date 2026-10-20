# Tổng hợp các tài liệu được trích dẫn trong báo cáo CAMS

Tệp này tổng hợp các tài liệu thực sự được trích dẫn trong các Chương 1–6 của báo cáo CAMS. Nội dung dưới đây là phần tóm tắt phục vụ tra cứu, không thay thế tài liệu gốc.

- Nguồn đối chiếu: `00_report/bibliography/networktools_references.bib`
- Phạm vi rà soát: các tệp từ `05_tong_quan.typ` đến `10_ket_luan_huong_phat_trien.typ`
- Tổng số tài liệu được trích dẫn: **19**
- Ngày tổng hợp: **20/10/2026**

## 1. Tổng quan danh mục tài liệu

| STT | Tài liệu | Nhóm nội dung | Được sử dụng trong báo cáo |
|---:|---|---|---|
| 1 | *Network Programmability and Automation* | Tự động hóa mạng | Chương 2 |
| 2 | Ansible for Network Automation | Công cụ tự động hóa | Chương 1, 2 |
| 3 | Nornir Documentation | Khung tự động hóa Python | Chương 1, 2 |
| 4 | NetBox Documentation | DCIM/IPAM và nguồn dữ liệu chuẩn | Chương 1, 2 |
| 5 | Oxidized | Sao lưu và lưu phiên bản cấu hình | Chương 1, 2 |
| 6 | Cisco Catalyst Center Platform User Guide | Quản trị mạng doanh nghiệp | Chương 1, 2 |
| 7 | RFC 9315 | Mạng dựa trên ý định | Chương 1 |
| 8 | RFC 4251 | Kiến trúc giao thức SSH | Chương 2 |
| 9 | RFC 2328 | Giao thức OSPFv2 | Chương 2 |
| 10 | RFC 3022 | NAT truyền thống | Chương 2 |
| 11 | IEEE 802.1Q-2022 | Cầu nối, VLAN và STP | Chương 2 |
| 12 | Cisco Dynamic ARP Inspection Guide | DAI và DHCP Snooping | Chương 2 |
| 13 | RFC 6241 | NETCONF | Chương 2, 6 |
| 14 | RFC 8040 | RESTCONF | Chương 2, 6 |
| 15 | RFC 7950 | Ngôn ngữ mô hình dữ liệu YANG 1.1 | Chương 2, 6 |
| 16 | RFC 5424 | Giao thức Syslog | Chương 2, 4 |
| 17 | NIST SP 800-92 | Quản lý nhật ký an toàn | Chương 2 |
| 18 | NIST SP 800-38D | AES-GCM và GMAC | Chương 2, 3, 4 |
| 19 | RFC 9106 | Argon2 | Chương 2, 3, 4 |

## 2. Tự động hóa và các nền tảng quản trị mạng

### 2.1. Network Programmability and Automation

**Thông tin tài liệu**

- Tác giả: Jason Edelman, Scott S. Lowe và Matt Oswalt.
- Tên sách: *Network Programmability and Automation: Skills for the Next-Generation Network Engineer*.
- Nhà xuất bản: O’Reilly Media, 2018.
- Khóa trích dẫn: `edelman2018automation`.

**Nội dung chính**

Tài liệu trình bày sự chuyển đổi từ quản trị mạng thủ công sang tự động hóa dựa trên phần mềm. Các chủ đề chính gồm mô hình dữ liệu, giao diện lập trình, tạo cấu hình theo mẫu, quản lý trạng thái và xây dựng quy trình có thể lặp lại. Tự động hóa giúp giảm thao tác nhập lệnh lặp lại và tăng tính nhất quán, nhưng vẫn cần kiểm tra dữ liệu, kiểm duyệt thay đổi và xác minh sau triển khai.

**Vai trò trong báo cáo**

Được sử dụng ở Chương 2 để giải thích vai trò của tự động hóa cấu hình và lưu ý rằng hiệu quả về thời gian phải được đo trong từng môi trường cụ thể.

### 2.2. Ansible for Network Automation

**Thông tin tài liệu**

- Tác giả/tổ chức: Red Hat.
- Tên tài liệu: *Ansible for Network Automation: Getting Started*.
- Liên kết: <https://docs.ansible.com/projects/ansible/latest/network/getting_started/>
- Khóa trích dẫn: `ansibleNetworkDocs`.

**Nội dung chính**

Ansible tổ chức tác vụ tự động hóa bằng inventory, playbook, mô-đun và biến cấu hình. Trong quản trị mạng, công cụ có thể thu thập trạng thái, tạo cấu hình và triển khai thay đổi trên nhiều thiết bị mà không cần cài tác nhân trực tiếp lên thiết bị mạng.

**Vai trò trong báo cáo**

Được dùng ở Chương 1 và Chương 2 để đối chiếu CAMS với mô hình tự động hóa dựa trên tệp tác vụ. Ansible có hệ sinh thái lớn và hỗ trợ nhiều nền tảng, trong khi CAMS tập trung vào giao diện trực quan và quy trình thực hành tích hợp.

### 2.3. Nornir Documentation

**Thông tin tài liệu**

- Tác giả/tổ chức: Nornir Community.
- Tên tài liệu: *Nornir Documentation*.
- Liên kết: <https://nornir.readthedocs.io/>
- Khóa trích dẫn: `nornirDocs`.

**Nội dung chính**

Nornir là khung tự động hóa mạng viết bằng Python. Công cụ cung cấp inventory, mô hình tác vụ, bộ lọc thiết bị và khả năng thực thi đồng thời, cho phép lập trình viên xây dựng quy trình tự động hóa phù hợp với yêu cầu riêng.

**Vai trò trong báo cáo**

Được dùng để so sánh cách tiếp cận lập trình linh hoạt của Nornir với CAMS. Nornir phù hợp với người phát triển quy trình bằng mã nguồn, còn CAMS hướng tới người dùng thao tác qua giao diện.

### 2.4. NetBox Documentation

**Thông tin tài liệu**

- Tác giả/tổ chức: NetBox Labs.
- Tên tài liệu: *NetBox Documentation*.
- Liên kết: <https://netboxlabs.com/docs/netbox/>
- Khóa trích dẫn: `netboxDocs`.

**Nội dung chính**

NetBox cung cấp chức năng quản lý hạ tầng trung tâm dữ liệu và địa chỉ IP, thường được sử dụng như nguồn dữ liệu chuẩn cho thiết bị, kết nối, địa chỉ, VLAN và các đối tượng hạ tầng. Dữ liệu có thể được khai thác qua giao diện và API để phục vụ các hệ thống tự động hóa khác.

**Vai trò trong báo cáo**

Được dùng để làm rõ sự khác biệt giữa một nguồn dữ liệu hạ tầng chuyên dụng và CAMS. CAMS lưu dữ liệu phục vụ trực tiếp cho bài thực hành và triển khai cấu hình, nhưng không thay thế toàn bộ phạm vi DCIM/IPAM của NetBox.

### 2.5. Oxidized

**Thông tin tài liệu**

- Tác giả/tổ chức: Oxidized Community.
- Tên tài liệu: *Oxidized: Network Device Configuration Backup Tool*.
- Liên kết: <https://github.com/ytti/oxidized>
- Khóa trích dẫn: `oxidizedDocs`.

**Nội dung chính**

Oxidized là công cụ thu thập và lưu phiên bản cấu hình thiết bị mạng. Công cụ hỗ trợ nhiều loại thiết bị, tự động lấy cấu hình theo chu kỳ và lưu lịch sử thay đổi để phục vụ so sánh hoặc truy vết.

**Vai trò trong báo cáo**

Được dùng để đối chiếu với chức năng đồng bộ và lưu lịch sử cấu hình của CAMS. Oxidized chuyên về sao lưu cấu hình, còn CAMS kết hợp lịch sử với biểu mẫu cấu hình, xem trước lệnh và giám sát.

### 2.6. Cisco Catalyst Center Platform User Guide

**Thông tin tài liệu**

- Tác giả/tổ chức: Cisco Systems.
- Tên tài liệu: *Cisco Catalyst Center Platform User Guide*.
- Liên kết: <https://www.cisco.com/c/en/us/support/cloud-systems-management/dna-center/products-user-guide-list.html>
- Khóa trích dẫn: `ciscoCatalystCenter`.

**Nội dung chính**

Cisco Catalyst Center là nền tảng quản trị mạng doanh nghiệp, cung cấp các khả năng khám phá thiết bị, quản lý tập trung, tự động hóa triển khai, bảo đảm dịch vụ và quan sát trạng thái mạng trong hệ sinh thái Cisco.

**Vai trò trong báo cáo**

Được dùng làm đối tượng so sánh về phạm vi. Catalyst Center hướng tới môi trường doanh nghiệp và có hệ thống chức năng rộng, trong khi CAMS là ứng dụng cục bộ dành cho đào tạo, thử nghiệm và phòng thực hành.

### 2.7. RFC 9315 – Intent-Based Networking

**Thông tin tài liệu**

- Tác giả: A. Clemm, L. Ciavaglia, L. Z. Granville và J. Tantsura.
- Tên tài liệu: *Intent-Based Networking – Concepts and Definitions*.
- Cơ quan ban hành: IRTF, 2022.
- Liên kết: <https://www.rfc-editor.org/rfc/rfc9315.html>
- Khóa trích dẫn: `rfc9315`.

**Nội dung chính**

RFC 9315 mô tả các khái niệm của quản trị mạng dựa trên ý định. Người dùng diễn đạt mục tiêu mong muốn ở mức cao; hệ thống diễn giải mục tiêu, triển khai cấu hình và liên tục đánh giá trạng thái thực tế để bảo đảm ý định được duy trì.

**Vai trò trong báo cáo**

Được dùng ở Chương 1 để xác định mức độ tiếp cận của CAMS. CAMS có cấu hình mong muốn, bước kiểm duyệt và dữ liệu quan sát, nhưng chưa phải một hệ thống bảo đảm ý định tự động hoàn chỉnh.

## 3. Giao thức và nghiệp vụ mạng

### 3.1. RFC 4251 – Kiến trúc giao thức SSH

**Thông tin tài liệu**

- Tác giả: T. Ylonen và C. Lonvick.
- Tên tài liệu: *The Secure Shell (SSH) Protocol Architecture*.
- Cơ quan ban hành: IETF, 2006.
- Liên kết: <https://www.rfc-editor.org/rfc/rfc4251.html>
- Khóa trích dẫn: `rfc4251`.

**Nội dung chính**

RFC 4251 mô tả kiến trúc tổng thể của SSH, gồm lớp truyền tải bảo mật, xác thực người dùng và cơ chế mở các kênh logic trong một phiên. SSH cung cấp tính bí mật, toàn vẹn và xác thực cho hoạt động quản trị từ xa.

**Vai trò trong báo cáo**

Được sử dụng ở Chương 2 để giải thích lý do SSH là lựa chọn mặc định cho kết nối quản trị thiết bị, trong khi Telnet chỉ phù hợp với môi trường thực hành cô lập hoặc thiết bị cũ.

### 3.2. RFC 2328 – OSPF Version 2

**Thông tin tài liệu**

- Tác giả: J. Moy.
- Tên tài liệu: *OSPF Version 2*.
- Cơ quan ban hành: IETF, 1998.
- Liên kết: <https://www.rfc-editor.org/rfc/rfc2328.html>
- Khóa trích dẫn: `rfc2328`.

**Nội dung chính**

RFC 2328 định nghĩa OSPFv2 cho IPv4. Các bộ định tuyến hình thành quan hệ láng giềng, trao đổi quảng bá trạng thái liên kết, xây dựng cơ sở dữ liệu chung và tính đường đi ngắn nhất theo chi phí. Tài liệu cũng mô tả vùng OSPF, các loại bộ định tuyến và quá trình hội tụ.

**Vai trò trong báo cáo**

Được dùng ở Chương 2 làm cơ sở lý thuyết cho OSPF và cho các khái niệm LSA, ABR, ASBR cùng mô hình nhiều vùng.

### 3.3. RFC 3022 – Traditional NAT

**Thông tin tài liệu**

- Tác giả: P. Srisuresh và K. Egevang.
- Tên tài liệu: *Traditional IP Network Address Translator (Traditional NAT)*.
- Cơ quan ban hành: IETF, 2001.
- Liên kết: <https://www.rfc-editor.org/rfc/rfc3022.html>
- Khóa trích dẫn: `rfc3022`.

**Nội dung chính**

RFC 3022 trình bày cơ chế NAT truyền thống, bao gồm ánh xạ địa chỉ một-một và ánh xạ nhiều luồng qua địa chỉ cùng số cổng. Tài liệu giải thích vai trò phía trong, phía ngoài và các giới hạn khi địa chỉ bị thay đổi trên đường truyền.

**Vai trò trong báo cáo**

Được sử dụng ở Chương 2 để giải thích NAT/PAT và nhấn mạnh rằng chuyển đổi địa chỉ không thay thế chức năng kiểm soát truy cập.

### 3.4. IEEE 802.1Q-2022

**Thông tin tài liệu**

- Tổ chức ban hành: IEEE Standards Association.
- Tên tiêu chuẩn: *IEEE Standard for Local and Metropolitan Area Networks—Bridges and Bridged Networks*.
- Số hiệu: IEEE 802.1Q-2022.
- Khóa trích dẫn: `ieee8021q`.

**Nội dung chính**

Tiêu chuẩn mô tả hoạt động của cầu nối và mạng LAN ảo, bao gồm gắn thẻ VLAN, cổng truy cập, đường liên kết trung kế, xử lý VLAN gốc và các cơ chế cây bao trùm nhằm ngăn vòng lặp Lớp 2.

**Vai trò trong báo cáo**

Được dùng ở Chương 2 làm cơ sở cho phần VLAN, trunk 802.1Q, STP, RSTP và MSTP.

### 3.5. Cisco Dynamic ARP Inspection Guide

**Thông tin tài liệu**

- Tác giả/tổ chức: Cisco Systems.
- Tên tài liệu: *Security Configuration Guide, Cisco IOS XE 17.14.x: Configuring Dynamic ARP Inspection*.
- Liên kết: <https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9600/software/release/17-14/configuration_guide/sec/b_1714_sec_9600_cg/configuring_dynamic_arp_inspection.html>
- Khóa trích dẫn: `ciscoDaiGuide`.

**Nội dung chính**

Tài liệu giải thích cách Dynamic ARP Inspection kiểm tra bản tin ARP trên cổng không tin cậy. Việc kiểm tra thường dựa trên bảng liên kết do DHCP Snooping tạo ra hoặc các ACL ARP được cấu hình trước. Cổng tin cậy và dữ liệu liên kết phải được xác định đúng để tránh chặn nhầm lưu lượng hợp lệ.

**Vai trò trong báo cáo**

Được dùng ở Chương 2 làm cơ sở cho quan hệ giữa DHCP Snooping, bảng liên kết IP–MAC và DAI.

### 3.6. RFC 6241 – NETCONF

**Thông tin tài liệu**

- Tác giả: R. Enns và các cộng sự.
- Tên tài liệu: *Network Configuration Protocol (NETCONF)*.
- Cơ quan ban hành: IETF, 2011.
- Liên kết: <https://www.rfc-editor.org/rfc/rfc6241.html>
- Khóa trích dẫn: `rfc6241`.

**Nội dung chính**

NETCONF là giao thức quản lý cấu hình sử dụng dữ liệu có cấu trúc và các thao tác như lấy cấu hình, chỉnh sửa, khóa kho dữ liệu và xác nhận thay đổi. Giao thức thường sử dụng XML và vận hành trên một kênh truyền bảo mật.

**Vai trò trong báo cáo**

Được giới thiệu ở Chương 2 như một hướng quản trị có cấu trúc và được đề xuất ở Chương 6 để giảm sự phụ thuộc của CAMS vào việc phân tích văn bản CLI.

### 3.7. RFC 8040 – RESTCONF

**Thông tin tài liệu**

- Tác giả: A. Bierman, M. Björklund và K. Watsen.
- Tên tài liệu: *RESTCONF Protocol*.
- Cơ quan ban hành: IETF, 2017.
- Liên kết: <https://www.rfc-editor.org/rfc/rfc8040.html>
- Khóa trích dẫn: `rfc8040`.

**Nội dung chính**

RESTCONF cung cấp giao diện HTTP bảo mật để truy cập dữ liệu cấu hình và trạng thái được mô hình hóa bằng YANG. Tài nguyên có thể được biểu diễn bằng XML hoặc JSON và được thao tác theo các phương thức của HTTP.

**Vai trò trong báo cáo**

Được dùng cùng NETCONF ở Chương 2 và Chương 6 như hướng phát triển cho quản trị mạng dựa trên mô hình dữ liệu.

### 3.8. RFC 7950 – YANG 1.1

**Thông tin tài liệu**

- Tác giả: M. Björklund.
- Tên tài liệu: *The YANG 1.1 Data Modeling Language*.
- Cơ quan ban hành: IETF, 2016.
- Liên kết: <https://www.rfc-editor.org/rfc/rfc7950.html>
- Khóa trích dẫn: `rfc7950`.

**Nội dung chính**

YANG là ngôn ngữ dùng để mô tả cấu trúc dữ liệu cấu hình, dữ liệu trạng thái, thao tác và thông báo của thiết bị mạng. Mô hình YANG định nghĩa kiểu dữ liệu, quan hệ, điều kiện và ràng buộc để các hệ thống quản trị trao đổi dữ liệu nhất quán.

**Vai trò trong báo cáo**

Được dùng để giải thích nền tảng mô hình dữ liệu của NETCONF/RESTCONF và là một hướng phát triển giúp CAMS hỗ trợ dữ liệu có cấu trúc.

## 4. Thu thập và quản lý nhật ký

### 4.1. RFC 5424 – The Syslog Protocol

**Thông tin tài liệu**

- Tác giả: R. Gerhards.
- Tên tài liệu: *The Syslog Protocol*.
- Cơ quan ban hành: IETF, 2009.
- Liên kết: <https://www.rfc-editor.org/rfc/rfc5424.html>
- Khóa trích dẫn: `rfc5424`.

**Nội dung chính**

RFC 5424 định nghĩa cấu trúc bản tin Syslog, bao gồm giá trị ưu tiên PRI, phiên bản, dấu thời gian, tên máy, ứng dụng, mã tiến trình, mã bản tin, dữ liệu có cấu trúc và nội dung sự kiện. PRI kết hợp nhóm nguồn với mức độ nghiêm trọng để hỗ trợ phân loại và xử lý nhật ký.

**Vai trò trong báo cáo**

Được sử dụng ở Chương 2 để trình bày cấu trúc và mức độ Syslog, đồng thời làm cơ sở cho cách CAMS lưu nội dung gốc và dữ liệu đã phân tích ở Chương 4.

### 4.2. NIST SP 800-92 – Guide to Computer Security Log Management

**Thông tin tài liệu**

- Tác giả: Karen Kent và Murugiah Souppaya.
- Tên tài liệu: *Guide to Computer Security Log Management*.
- Cơ quan ban hành: National Institute of Standards and Technology, 2006.
- Số hiệu: NIST Special Publication 800-92.
- Liên kết: <https://csrc.nist.gov/pubs/sp/800/92/final>
- Khóa trích dẫn: `nistSp80092`.

**Nội dung chính**

Tài liệu trình bày quy trình quản lý nhật ký an toàn, từ xây dựng hạ tầng, xác định nguồn nhật ký, thu thập và lưu giữ đến rà soát, phân tích và ứng phó. Việc thu thập chỉ có giá trị khi gắn với chính sách lưu giữ, trách nhiệm kiểm tra và quy trình xử lý sự kiện.

**Vai trò trong báo cáo**

Được sử dụng ở Chương 2 để khẳng định rằng CAMS không chỉ cần lưu bản tin, mà còn phải hỗ trợ lọc, đối chiếu và khai thác nhật ký trong quy trình giám sát.

## 5. Bảo vệ dữ liệu và dẫn xuất khóa

### 5.1. NIST SP 800-38D – GCM and GMAC

**Thông tin tài liệu**

- Tác giả: Morris Dworkin.
- Tên tài liệu: *Recommendation for Block Cipher Modes of Operation: Galois/Counter Mode (GCM) and GMAC*.
- Cơ quan ban hành: National Institute of Standards and Technology, 2007.
- Số hiệu: NIST Special Publication 800-38D.
- Liên kết: <https://csrc.nist.gov/pubs/sp/800/38/d/final>
- Khóa trích dẫn: `nistSp80038d`.

**Nội dung chính**

NIST SP 800-38D định nghĩa Galois/Counter Mode, một chế độ mã hóa có xác thực. GCM bảo vệ tính bí mật của nội dung và tạo thẻ xác thực để phát hiện dữ liệu bị sửa đổi. Tài liệu cũng quy định yêu cầu đối với khóa, giá trị dùng một lần và dữ liệu xác thực bổ sung.

**Vai trò trong báo cáo**

Được sử dụng ở Chương 2–4 làm cơ sở cho lựa chọn AES-256-GCM để bảo vệ thông tin xác thực và gói dự án của CAMS.

### 5.2. RFC 9106 – Argon2

**Thông tin tài liệu**

- Tác giả: A. Biryukov, D. Dinu, D. Khovratovich và S. Josefsson.
- Tên tài liệu: *Argon2 Memory-Hard Function for Password Hashing and Proof-of-Work Applications*.
- Cơ quan ban hành: IRTF, 2021.
- Liên kết: <https://www.rfc-editor.org/rfc/rfc9106.html>
- Khóa trích dẫn: `rfc9106`.

**Nội dung chính**

RFC 9106 mô tả Argon2 và các biến thể Argon2d, Argon2i, Argon2id. Argon2id được thiết kế để dẫn xuất khóa hoặc lưu mật khẩu với chi phí bộ nhớ, qua đó làm tăng chi phí của hoạt động dò mật khẩu hàng loạt. Các tham số quan trọng gồm muối, dung lượng bộ nhớ, số lượt xử lý, mức song song và độ dài đầu ra.

**Vai trò trong báo cáo**

Được sử dụng ở Chương 2–4 làm cơ sở cho việc dẫn xuất khóa từ mật khẩu dự án trước khi mã hóa dữ liệu bằng AES-256-GCM.

## 6. Quan hệ giữa tài liệu và cấu trúc báo cáo

| Chương | Nhóm tài liệu hỗ trợ |
|---|---|
| Chương 1 – Giới thiệu đề tài | Ansible, Nornir, NetBox, Oxidized, Cisco Catalyst Center và RFC 9315 |
| Chương 2 – Cơ sở lý thuyết | Tự động hóa mạng, SSH, OSPF, NAT, VLAN/STP, DAI, NETCONF/RESTCONF/YANG, Syslog, quản lý nhật ký và mật mã |
| Chương 3 – Phân tích và thiết kế | RFC 9106 và NIST SP 800-38D cho thiết kế bảo vệ dữ liệu |
| Chương 4 – Xây dựng phần mềm | RFC 5424 cho Syslog; RFC 9106 và NIST SP 800-38D cho bảo vệ dữ liệu |
| Chương 5 – Thử nghiệm và đánh giá | Sử dụng các cơ sở lý thuyết đã trình bày; không phát sinh khóa trích dẫn mới trong tệp chương chính |
| Chương 6 – Kết luận và hướng phát triển | RFC 6241, RFC 8040 và RFC 7950 cho định hướng NETCONF/RESTCONF/YANG |

## 7. Ghi chú sử dụng

- Khi đưa nội dung vào báo cáo, nên giữ nguyên khóa trích dẫn trong tệp Typst để hệ thống tạo danh mục tài liệu tham khảo tự động.
- Các bản RFC và tài liệu NIST nên được ưu tiên khi cần giải thích tiêu chuẩn hoặc thuật toán.
- Tài liệu của Cisco được dùng cho hành vi và cấu hình đặc thù của Cisco IOS.
- Tài liệu Ansible, Nornir, NetBox, Oxidized và Catalyst Center chủ yếu phục vụ phần so sánh giải pháp.
- Phần tóm tắt trong tệp này chỉ diễn giải nội dung liên quan trực tiếp đến CAMS; để sử dụng chi tiết kỹ thuật hoặc trích dẫn nguyên văn, cần kiểm tra lại tài liệu gốc.
