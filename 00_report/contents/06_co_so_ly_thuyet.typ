#pagebreak(weak: true)
#import "../config/tables.typ": report-table

= Cơ sở lý thuyết và công nghệ nền tảng

== Tổng quan về quản lý tập trung và tự động hóa cấu hình mạng

=== Khái niệm và vai trò

Trong mạng doanh nghiệp, quản lý tập trung là cách tổ chức danh mục thiết bị, thông tin kết nối, cấu hình, trạng thái vận hành và lịch sử thay đổi tại một đầu mối thống nhất. Cách tổ chức này giúp người quản trị tra cứu dữ liệu và thực hiện cùng một quy trình trên nhiều thiết bị, thay vì duy trì các tệp rời rạc cho từng bộ định tuyến hoặc bộ chuyển mạch. Đối với CAMS, đầu mối quản lý là ứng dụng máy tính để bàn cùng không gian làm việc cục bộ; hệ thống chưa phải nền tảng máy chủ phục vụ đồng thời nhiều người dùng.

Cấu hình thủ công qua giao diện dòng lệnh đòi hỏi người quản trị đăng nhập vào từng thiết bị, nhập lệnh theo đúng chế độ và tự ghi nhận kết quả. Phương pháp này phù hợp với thao tác đơn lẻ hoặc xử lý sự cố trực tiếp, nhưng dễ phát sinh sai khác khi cùng một chính sách phải áp dụng cho nhiều thiết bị. Tự động hóa cấu hình chuyển các bước lặp lại thành quy trình phần mềm gồm tiếp nhận tham số, kiểm tra dữ liệu, tạo lệnh, kết nối, triển khai và lưu kết quả. Nhờ đó, lệnh được tạo theo cùng một mẫu, thời gian thao tác được rút ngắn và kết quả giữa các thiết bị nhất quán hơn @edelman2018automation.

#report-table(
  columns: (22%, 37%, 41%),
  header: ([Tiêu chí], [Cấu hình thủ công], [Cấu hình tự động]),
  rows: (
    ([Cách thực hiện], [Nhập lệnh trực tiếp trên từng thiết bị.], [Tạo và triển khai lệnh từ dữ liệu cùng mẫu cấu hình.]),
    ([Tính nhất quán], [Phụ thuộc vào thao tác của từng người quản trị.], [Dùng chung quy tắc kiểm tra và mẫu lệnh cho nhiều thiết bị.]),
    ([Khả năng mở rộng], [Khối lượng thao tác tăng gần tương ứng với số thiết bị.], [Có thể xử lý theo lô và thực thi đồng thời trên các thiết bị độc lập.]),
    ([Kiểm soát thay đổi], [Cần ghi chép và sao lưu riêng.], [Có thể gắn thay đổi với trạng thái, kết quả và lịch sử cấu hình.]),
    ([Rủi ro chính], [Nhập sai lệnh, bỏ sót bước hoặc cấu hình không đồng nhất.], [Dữ liệu hoặc mẫu lệnh sai có thể ảnh hưởng đồng thời đến nhiều thiết bị.]),
  ),
  caption: [So sánh cấu hình thủ công và cấu hình tự động],
)

Tự động hóa không loại bỏ vai trò kiểm soát của con người. Người quản trị vẫn phải xác định chính sách, duyệt lệnh trước khi triển khai và xác minh trạng thái sau khi thiết bị phản hồi. Vì vậy, lợi ích của tự động hóa chỉ đạt được khi hệ thống có cơ chế kiểm tra đầu vào, xem trước thay đổi và ghi nhận lỗi riêng cho từng thiết bị.

=== Các mô hình quản lý cấu hình

Mô hình quản lý theo trạng thái phân biệt *trạng thái mong muốn* (desired state) với *trạng thái quan sát* (observed state). Trạng thái mong muốn biểu diễn cấu hình mà người dùng dự kiến áp dụng; trạng thái quan sát phản ánh dữ liệu thu thập từ thiết bị tại một thời điểm. Một bản ghi vừa được lưu trong cơ sở dữ liệu mới thể hiện ý định cấu hình, chưa chứng minh thiết bị đã thay đổi.

Trong CAMS, quy trình *Xem trước và triển khai* (View & Push) gồm bốn bước: lưu dữ liệu ở trạng thái chờ, kết xuất dữ liệu thành lệnh Cisco IOS, hiển thị lệnh để kiểm duyệt, sau đó triển khai và cập nhật kết quả theo phản hồi của thiết bị. Cơ chế *Lưu chờ* (Staged Save) cho phép người dùng hoàn thiện nhiều bản ghi trước khi mở cửa sổ xem trước. Cách tổ chức này tách thao tác biên soạn khỏi thao tác gây thay đổi trên thiết bị, đồng thời tạo điểm kiểm soát trước khi thực thi.

Lưu phiên bản cấu hình hỗ trợ truy vết và so sánh thay đổi. Tuy nhiên, việc mở một bản sao cũ hoặc khôi phục tệp dự án chỉ phục hồi dữ liệu cục bộ; muốn đưa thiết bị về cấu hình trước đó, người quản trị vẫn phải tạo lệnh khôi phục, triển khai và xác minh riêng.

=== Các công cụ tự động hóa mạng phổ biến

Các công cụ quản lý mạng có mục tiêu và phạm vi khác nhau. Ansible tổ chức tác vụ bằng tệp mô tả và các bộ mô-đun theo nền tảng; Nornir cung cấp khung lập trình Python để xây dựng luồng xử lý theo yêu cầu. NetBox tập trung vào vai trò nguồn dữ liệu chuẩn cho quản lý địa chỉ IP và hạ tầng trung tâm dữ liệu. Oxidized và RANCID chủ yếu thu thập, lưu phiên bản và so sánh cấu hình. Ở nhóm sản phẩm thương mại, Cisco Catalyst Center, trước đây có tên Cisco DNA Center, và SolarWinds Network Configuration Manager cung cấp chức năng quản lý tập trung ở quy mô doanh nghiệp @ansibleNetworkDocs @nornirDocs @netboxDocs @oxidizedDocs @rancidDocs @ciscoCatalystCenter @solarwindsNcm.

#report-table(
  columns: (18%, 27%, 27%, 28%),
  header: ([Công cụ], [Trọng tâm], [Ưu điểm chính], [Giới hạn khi đối chiếu với CAMS]),
  rows: (
    ([Ansible], [Tự động hóa theo tệp tác vụ và bộ mô-đun.], [Hỗ trợ nhiều hãng, hệ sinh thái lớn, không cần cài tác nhân trên thiết bị mạng.], [Cần kiến thức về tệp cấu hình và quy trình dòng lệnh; không hướng riêng đến giao diện thực hành tích hợp.]),
    ([Nornir], [Khung lập trình tự động hóa bằng Python.], [Linh hoạt khi xây dựng tác vụ, quản lý danh mục và xử lý đồng thời.], [Đòi hỏi phát triển mã nguồn cho quy trình và giao diện sử dụng.]),
    ([NetBox], [Nguồn dữ liệu chuẩn cho DCIM và IPAM.], [Mô hình dữ liệu hạ tầng chặt chẽ, có giao diện lập trình ứng dụng.], [Không mặc nhiên là công cụ triển khai cấu hình xuống thiết bị.]),
    ([Oxidized, RANCID], [Sao lưu và theo dõi phiên bản cấu hình.], [Phù hợp cho kiểm kê, phát hiện sai khác và lưu lịch sử.], [Phạm vi tạo cấu hình và kiểm duyệt thay đổi còn hạn chế.]),
    ([Catalyst Center, SolarWinds NCM], [Quản trị, bảo đảm và tuân thủ ở quy mô doanh nghiệp.], [Chức năng tích hợp rộng, hỗ trợ vận hành tập trung.], [Cần đối chiếu mô hình vận hành, giấy phép và phạm vi tích hợp với nhu cầu phòng thực hành; đề tài chưa đo chi phí so sánh.]),
    ([CAMS], [Quản lý trạng thái, xem trước lệnh, triển khai và giám sát trong một ứng dụng máy tính để bàn.], [Giao diện trực quan, dữ liệu cục bộ và quy trình phù hợp môi trường nghiên cứu Cisco IOS.], [Phạm vi hãng thiết bị, giao thức quản trị và khả năng cộng tác còn hẹp.]),
  ),
  caption: [Đối chiếu phạm vi của một số công cụ quản lý và tự động hóa mạng],
)

CAMS không nhằm thay thế các nền tảng doanh nghiệp nêu trên. Đề tài tập trung kết hợp danh mục thiết bị, cấu hình theo trạng thái, bước xem trước lệnh và thu thập nhật ký trong một công cụ cục bộ phục vụ học tập, thử nghiệm và quản trị phòng thực hành.

== Giao thức quản trị từ xa và giao diện dòng lệnh

=== Giao diện dòng lệnh Cisco IOS

Giao diện dòng lệnh (Command-Line Interface – CLI) của Cisco IOS được tổ chức theo chế độ. Dấu nhắc `>` biểu thị chế độ người dùng, dấu nhắc `#` thường biểu thị chế độ đặc quyền, còn các dấu nhắc như `(config)#`, `(config-if)#` hoặc `(config-router)#` cho biết ngữ cảnh cấu hình hiện hành. Lệnh chỉ hợp lệ khi được gửi ở đúng chế độ; vì vậy, công cụ tự động hóa phải nhận diện dấu nhắc, chuyển chế độ và thoát khỏi ngữ cảnh cấu hình theo đúng thứ tự @ciscoIosCommandRef.

Phản hồi CLI chủ yếu là văn bản. CAMS phải loại bỏ phần lặp lệnh, phát hiện thông báo lỗi như lệnh không hợp lệ hoặc thiếu tham số, đồng thời phân tích kết quả của các lệnh `show` thành dữ liệu có cấu trúc. Việc gửi thành công một chuỗi ký tự không đồng nghĩa với cấu hình đã được chấp nhận; kết quả chỉ được ghi nhận sau khi phần mềm kiểm tra phản hồi tương ứng.

=== Giao thức SSH và Telnet

Giao thức vỏ bảo mật (Secure Shell – SSH) cung cấp cơ chế xác thực, bảo mật kênh truyền và kiểm tra tính toàn vẹn. Kiến trúc SSH tách giao thức truyền tải, giao thức xác thực người dùng và giao thức kết nối thành các lớp chức năng @rfc4251 @rfc4252 @rfc4253. Paramiko hiện thực máy khách SSH ở mức thư viện, trong khi Netmiko bổ sung cách xử lý dấu nhắc và chế độ lệnh cho nhiều hệ điều hành mạng @paramikoDocs @netmikoDocs.

Telnet truyền nội dung phiên quản trị dưới dạng không mã hóa, nên thông tin xác thực và lệnh có thể bị quan sát trên đường truyền. CAMS hỗ trợ SSH và Telnet cho các luồng CLI hiện có; SSH là lựa chọn mặc định, còn Telnet chỉ phù hợp với phòng thực hành cô lập hoặc thiết bị cũ chưa hỗ trợ SSH.

Phiên kết nối được tái sử dụng nhằm giảm số lần bắt tay và xác thực. Do mỗi phiên CLI duy trì một ngữ cảnh riêng, các tác vụ dùng chung phiên phải được tuần tự hóa. Phần mềm cũng phải xử lý trường hợp mất kết nối, hết thời gian chờ hoặc thiết bị từ chối lệnh, thay vì suy ra thành công chỉ từ việc đã gửi dữ liệu.

=== Giao thức quản lý theo mô hình dữ liệu

NETCONF cung cấp các thao tác quản lý cấu hình trên dữ liệu có cấu trúc và thường dùng XML để mã hóa nội dung. RESTCONF biểu diễn tài nguyên quản lý qua HTTP bảo mật và hỗ trợ dữ liệu XML hoặc JSON. Cả hai giao thức đều có thể sử dụng mô hình YANG để mô tả cấu trúc, kiểu dữ liệu và ràng buộc của thông tin quản lý @rfc6241 @rfc8040 @rfc7950.

So với việc phân tích văn bản CLI, giao thức theo mô hình dữ liệu giúp chương trình nhận biết trường dữ liệu và lỗi theo cấu trúc rõ ràng hơn. Đổi lại, thiết bị phải hỗ trợ giao thức, mô hình YANG và cơ chế xác thực tương ứng. Phiên bản CAMS trong phạm vi báo cáo mới triển khai đầy đủ các luồng cấu hình chính qua SSH hoặc Telnet; NETCONF và RESTCONF là hướng mở rộng, không được xem là chức năng đã hoàn thiện.

== Nghiệp vụ mạng phục vụ tự động hóa

=== Dịch vụ và định tuyến Lớp 3

*Địa chỉ IPv4 và cấu trúc mạng.* Địa chỉ IPv4 gồm phần mạng và phần máy, được xác định bằng độ dài tiền tố hoặc mặt nạ mạng. Ký pháp CIDR biểu diễn mạng dưới dạng địa chỉ kèm độ dài tiền tố, chẳng hạn `192.168.10.0/24`. Trong một số lệnh Cisco IOS, mặt nạ ký tự đại diện (wildcard mask) được dùng để chọn các bit cần so khớp; giá trị này thường là phần đảo bit của mặt nạ mạng. CAMS phải kiểm tra địa chỉ, tiền tố và quan hệ mạng trước khi tạo lệnh. Bên cạnh cổng vật lý, hệ thống quản lý các cổng logic như Loopback, cổng con (subinterface), cổng VLAN ảo (SVI) và đường hầm (tunnel).

*Cấp phát địa chỉ động.* Giao thức cấu hình máy chủ động (Dynamic Host Configuration Protocol – DHCP) cấp địa chỉ và tham số mạng cho máy trạm. Chuỗi trao đổi điển hình gồm các bản tin Discover, Offer, Request và Acknowledge. Khi máy khách và máy chủ ở hai miền quảng bá khác nhau, tác nhân chuyển tiếp DHCP chuyển yêu cầu đến máy chủ. Một vùng cấp phát cần xác định mạng, cổng mặc định, máy chủ DNS, thời gian thuê và dải địa chỉ loại trừ để tránh cấp trùng cho thiết bị hạ tầng @rfc2131.

*Định tuyến động.* OSPFv2 là giao thức trạng thái liên kết. Các bộ định tuyến trao đổi quảng bá trạng thái liên kết (Link-State Advertisement – LSA), xây dựng cơ sở dữ liệu trạng thái liên kết và tính đường đi theo chi phí. Mạng OSPF có thể được chia thành nhiều vùng; bộ định tuyến biên vùng (Area Border Router – ABR) nối vùng xương sống với vùng khác, còn bộ định tuyến biên hệ tự trị (Autonomous System Boundary Router – ASBR) đưa tuyến từ nguồn bên ngoài vào miền OSPF @rfc2328.

EIGRP sử dụng thuật toán cập nhật khuếch tán để lựa chọn đường đi và duy trì tuyến dự phòng khả thi. Các thiết bị tham gia phải thống nhất số hiệu hệ tự trị và các mạng được quảng bá @rfc7868. Khi tái phân phối tuyến giữa giao thức hoặc từ tuyến kết nối trực tiếp, cần giới hạn đúng tập tiền tố bằng danh sách tiền tố và bản đồ tuyến. Tái phân phối không có bộ lọc có thể làm lộ mạng quản trị hoặc đưa các tuyến không mong muốn vào miền định tuyến.

*Chuyển đổi địa chỉ.* Chuyển đổi địa chỉ mạng (Network Address Translation – NAT) ánh xạ địa chỉ giữa hai miền. Chuyển đổi địa chỉ theo cổng (Port Address Translation – PAT) phân biệt nhiều luồng dùng chung một địa chỉ bằng số cổng. Cấu hình phải xác định đúng phía trong, phía ngoài, kiểu ánh xạ tĩnh hoặc động và điều kiện chọn lưu lượng. NAT thay đổi thông tin địa chỉ, không thay thế danh sách kiểm soát truy cập @rfc3022.

*Dự phòng cổng mặc định.* Nhóm giao thức dự phòng bộ định tuyến đầu tiên (First-Hop Redundancy Protocol – FHRP) cung cấp địa chỉ cổng mặc định ảo cho máy trạm. HSRP tổ chức thiết bị theo vai trò chủ động và dự phòng; VRRP thực hiện bầu chọn thiết bị chủ động theo chuẩn IETF; GLBP bổ sung cơ chế phân phối máy trạm cho nhiều thiết bị chuyển tiếp ảo thông qua vai trò AVG và AVF @rfc9568 @ciscoFhrpGuide. Với GLBP, độ ưu tiên quyết định thiết bị quản lý cổng ảo, còn cân bằng tải được thực hiện bằng cách phân phối các địa chỉ MAC ảo cho máy trạm.

=== Chuyển mạch Lớp 2

*VLAN và đường liên kết trung kế.* Mạng cục bộ ảo (Virtual Local Area Network – VLAN) chia một hạ tầng chuyển mạch thành các miền quảng bá logic. Cổng truy cập mang lưu lượng của một VLAN dữ liệu; đường liên kết trung kế có thể mang nhiều VLAN bằng thẻ IEEE 802.1Q. VLAN gốc trên đường trung kế phải được cấu hình thống nhất ở hai đầu để tránh sai lệch cách xử lý khung không gắn thẻ @ieee8021q.

*Ghép kênh liên kết.* EtherChannel kết hợp nhiều liên kết vật lý tương thích thành một liên kết logic nhằm tăng băng thông và duy trì kết nối khi một thành viên gặp sự cố. LACP là giao thức thương lượng được chuẩn hóa trong IEEE 802.1AX, còn PAgP là cơ chế riêng của Cisco. Các cổng thành viên phải thống nhất tốc độ, chế độ song công, chế độ truy cập hoặc trung kế và danh sách VLAN @ieee8021ax.

*Ngăn vòng lặp.* Giao thức cây bao trùm (Spanning Tree Protocol – STP) chọn cầu gốc, tính chi phí đường đi và đặt một số cổng vào trạng thái không chuyển tiếp để loại bỏ vòng lặp Lớp 2. RSTP rút ngắn thời gian hội tụ; MSTP ánh xạ nhiều VLAN vào các thực thể cây bao trùm nhằm giảm số lượng trạng thái cần duy trì @ieee8021q.

*Đồng bộ thông tin VLAN.* Giao thức trung kế VLAN (VLAN Trunking Protocol – VTP) phân phối thông tin VLAN giữa các bộ chuyển mạch Cisco trong cùng miền. Các chế độ máy chủ, máy khách và trong suốt có quyền tạo hoặc tiếp nhận thay đổi khác nhau. Số hiệu phiên bản cấu hình VTP phải được kiểm tra trước khi đưa thiết bị vào miền, vì cơ sở dữ liệu có số hiệu cao hơn có thể làm thay đổi thông tin VLAN hiện hành @ciscoVtpGuide.

Trong quy trình tự động hóa, các đối tượng Lớp 2 có quan hệ phụ thuộc. VLAN phải tồn tại trước khi gán cổng; các thành viên EtherChannel phải có cấu hình tương thích; chính sách STP và VTP phải phù hợp với vai trò của thiết bị. Mẫu lệnh vì thế phải xét cả thứ tự triển khai và điều kiện áp dụng.

=== Chính sách kiểm soát truy cập và bảo vệ Lớp 2

*Danh sách kiểm soát truy cập.* Danh sách kiểm soát truy cập (Access Control List – ACL) đánh giá lưu lượng theo thứ tự các quy tắc và dừng tại quy tắc khớp đầu tiên. ACL chuẩn chủ yếu so khớp địa chỉ nguồn; ACL mở rộng có thể xét địa chỉ nguồn, địa chỉ đích, giao thức và cổng vận chuyển. Khi triển khai, cần xác định đúng cổng, chiều vào hoặc ra và quy tắc từ chối ngầm ở cuối danh sách @ciscoAclGuide.

*Bảo mật cổng.* Port Security giới hạn địa chỉ MAC được phép xuất hiện trên cổng truy cập. Địa chỉ có thể được khai báo tĩnh hoặc học theo chế độ cố định (sticky). Khi vi phạm, thiết bị có thể loại bỏ khung, ghi nhận vi phạm hoặc đặt cổng vào trạng thái vô hiệu hóa, tương ứng với chế độ `protect`, `restrict` và `shutdown` @ciscoPortSecurityGuide.

*DHCP Snooping và kiểm tra ARP động.* DHCP Snooping phân loại cổng tin cậy và không tin cậy, chỉ cho phép phản hồi DHCP từ hướng máy chủ hợp lệ và xây dựng bảng liên kết gồm VLAN, địa chỉ IP, địa chỉ MAC, cổng và thời hạn thuê. Kiểm tra ARP động (Dynamic ARP Inspection – DAI) đối chiếu cặp IP–MAC trong gói ARP với bảng liên kết DHCP Snooping hoặc ACL ARP; việc kiểm tra được áp dụng trên cổng không tin cậy. Vì vậy, DAI phụ thuộc vào nguồn dữ liệu liên kết chính xác, đặc biệt đối với máy dùng địa chỉ tĩnh @ciscoDhcpSnoopingGuide @ciscoDaiGuide.

Các cơ chế trên được thực thi trên thiết bị mạng. CAMS tạo và triển khai cấu hình, đồng thời thu nhận nhật ký liên quan; hiệu quả bảo vệ phải được xác minh bằng lưu lượng thử nghiệm và trạng thái thực tế của thiết bị.

== Giám sát tập trung và khai thác cảnh báo

=== Giao thức Syslog

Một hệ thống Syslog tập trung gồm thiết bị phát bản tin, bộ thu nhận, bộ phân tích, nơi lưu trữ và giao diện truy vấn. Thiết bị mạng gửi sự kiện về một địa chỉ tập trung; bộ thu nhận tiếp nhận bản tin, bộ phân tích tách các trường, sau đó lưu cả dữ liệu đã chuẩn hóa và nội dung gốc. Cách lưu này hỗ trợ truy vấn nhanh mà vẫn giữ bằng chứng để kiểm tra khi bộ phân tích gặp định dạng chưa biết.

RFC 3164 mô tả định dạng Syslog truyền thống, thường gặp trong nhật ký thiết bị cũ @rfc3164. Theo RFC 5424, bản tin Syslog có phần đầu chứa mức ưu tiên PRI, phiên bản, dấu thời gian, tên máy, tên ứng dụng, mã tiến trình và mã bản tin; sau đó là dữ liệu có cấu trúc và nội dung sự kiện. PRI được tính theo công thức `facility × 8 + severity`. Trong đó, *facility* của Syslog biểu thị nhóm nguồn phát theo chuẩn, còn *severity* biểu thị mức độ nghiêm trọng @rfc5424.

#report-table(
  columns: (10%, 24%, 29%, 37%),
  header: ([Mức], [Tên trong RFC 5424], [Từ khóa Cisco IOS], [Ý nghĩa]),
  rows: (
    ([0], [Emergency], [`emergencies`], [Hệ thống không thể sử dụng.]),
    ([1], [Alert], [`alerts`], [Cần xử lý ngay.]),
    ([2], [Critical], [`critical`], [Điều kiện tới hạn.]),
    ([3], [Error], [`errors`], [Đã xảy ra lỗi.]),
    ([4], [Warning], [`warnings`], [Có dấu hiệu cần chú ý.]),
    ([5], [Notice], [`notifications`], [Sự kiện bình thường nhưng đáng lưu ý.]),
    ([6], [Informational], [`informational`], [Thông tin về hoạt động của hệ thống.]),
    ([7], [Debug], [`debugging`], [Thông tin chi tiết phục vụ gỡ lỗi.]),
  ),
  caption: [Mức độ nghiêm trọng của Syslog và từ khóa tương ứng trên Cisco IOS],
)

Tên theo RFC và từ khóa Cisco IOS không hoàn toàn giống nhau. Ví dụ, mức 5 có tên *Notice* trong RFC 5424 nhưng dùng từ khóa `notifications` trong lệnh `logging trap` của Cisco IOS. Mức số càng nhỏ thể hiện sự kiện càng nghiêm trọng; tuy nhiên, mức độ này chỉ hỗ trợ ưu tiên xử lý, không tự nó chứng minh đã xảy ra tấn công.

=== Cơ chế thu thập và phân tích

Syslog thường sử dụng cổng 514 cho UDP; một số triển khai cũng hỗ trợ truyền qua TCP, còn Syslog bảo mật bằng TLS thường dùng cổng 6514 @rfc5426 @rfc6587 @rfc5425. CAMS cho phép bộ thu nhận lắng nghe trên cổng 5514 để tiến trình thông thường trên Linux không phải yêu cầu quyền quản trị đối với cổng nhỏ hơn 1024. Nếu thiết bị chỉ gửi được đến cổng mặc định, hệ điều hành hoặc thiết bị trung gian có thể chuyển tiếp lưu lượng từ 514 sang 5514.

Dấu thời gian do thiết bị tạo cần đi kèm múi giờ hoặc được chuẩn hóa trước khi đối chiếu. Trên Cisco IOS, dấu `*` đứng trước thời gian cho biết đồng hồ chưa được xác thực; khi đó CAMS cần giữ cả thời gian trong bản tin và thời gian nhận. Số thứ tự cùng độ chính xác mili giây hỗ trợ sắp xếp các sự kiện xảy ra gần nhau, nhưng không thay thế việc đồng bộ NTP trên thiết bị @ciscoSyslogGuide.

Định dạng sự kiện Cisco IOS thường chứa chuỗi `%FACILITY-SEVERITY-MNEMONIC`. Thành phần `FACILITY` trong chuỗi này, chẳng hạn `LINEPROTO`, là mã phân hệ của Cisco IOS, không phải giá trị *facility* được mã hóa trong PRI của Syslog. Bộ phân tích và giao diện phải đặt tên hai trường riêng để tránh nhầm lẫn.

Trong CAMS, bộ thu nhận viết bằng C++ tiếp nhận bản tin UDP và TCP ở tiến trình riêng, sau đó chuyển dữ liệu đã phân tích vào `info_collected.db`. Lựa chọn C++ giảm phụ thuộc vào vòng lặp giao diện Python khi lưu lượng nhật ký tăng; hiệu quả thực tế vẫn phải được xác định bằng phép đo thông lượng, độ trễ và số bản tin bị loại bỏ.

=== Khai thác cảnh báo

Nhật ký tập trung có thể được lọc theo thiết bị, khoảng thời gian, mức độ nghiêm trọng, mã phân hệ và từ khóa. Việc kết hợp nhiều trường giúp người quản trị nhận biết các sự kiện như cổng thay đổi trạng thái, cấu hình bị sửa hoặc Port Security phát hiện địa chỉ MAC vi phạm. Theo hướng dẫn quản lý nhật ký của NIST, quá trình khai thác cần gắn với chính sách lưu giữ, rà soát và ứng phó, thay vì chỉ thu thập dữ liệu @nistSp80092.

Tương quan sự kiện là quá trình liên kết nhiều bản tin theo thời gian, nguồn và ngữ cảnh để tìm mẫu bất thường. CAMS hiện có thu nhận, phân tích trường, lọc nhật ký, gửi cảnh báo qua email và bộ phát hiện sự kiện theo ngưỡng trong cửa sổ thời gian. Các quy tắc này nhận diện dấu hiệu trong nhật ký, chưa tương đương một hệ thống phát hiện xâm nhập dựa trên phân tích lưu lượng. Nếu thiết bị không phát sinh hoặc không chuyển bản tin về bộ thu nhận, CAMS không thể tự suy ra toàn bộ sự kiện đã xảy ra.

== Cơ sở dữ liệu và hệ thống lưu trữ

=== SQLite

SQLite là hệ quản trị cơ sở dữ liệu quan hệ nhúng. Dữ liệu được lưu trong tệp và thư viện truy cập trực tiếp, không cần vận hành một tiến trình máy chủ cơ sở dữ liệu riêng. Đặc điểm này phù hợp với CAMS vì ứng dụng chạy trên máy tính cá nhân, cần cài đặt gọn và có khả năng đóng gói không gian làm việc @sqliteDocs.

SQLite hỗ trợ giao dịch, khóa và nhật ký ghi trước. Các thao tác ghi nên được giữ ngắn; dữ liệu nhật ký nên ghi theo lô để giảm số giao dịch. Giao dịch chỉ bảo đảm tính nhất quán của dữ liệu cục bộ, không tạo ra một giao dịch nguyên tử bao trùm cả cơ sở dữ liệu và thiết bị mạng ở xa.

=== Thiết kế cơ sở dữ liệu cho CAMS

CAMS tách dữ liệu thành hai tệp chính. `device_network.db` lưu danh mục thiết bị, thông tin kết nối và trạng thái cấu hình do người dùng thiết lập. `info_collected.db` lưu dữ liệu quan sát như bảng định tuyến, bảng liên kết DHCP, phiên NAT và bản tin Syslog. Việc tách này giúp dữ liệu cấu hình không bị trộn với dữ liệu thu thập trong quá trình vận hành.

Mô hình dữ liệu duy trì quan hệ giữa thiết bị với cổng, dịch vụ và chính sách. Khóa ngoại bảo vệ tính toàn vẹn tham chiếu, còn kiểm tra nghiệp vụ xác nhận các điều kiện mà kiểu dữ liệu không thể diễn đạt, chẳng hạn địa chỉ có thuộc đúng mạng hay không. Bản ghi cấu hình được gắn trạng thái như chờ áp dụng, đã đồng bộ hoặc chờ xóa để hỗ trợ quy trình xem trước và triển khai @elmasri2016database.

== Xây dựng giao diện người dùng

=== Qt Quick và QML

Qt Quick cung cấp ngôn ngữ QML để mô tả giao diện theo thành phần, thuộc tính và liên kết dữ liệu. Cách khai báo này phù hợp với giao diện có nhiều bảng, biểu mẫu và trạng thái tương tác. Thành phần có thể tái sử dụng giúp CAMS thống nhất màu sắc, khoảng cách, cách kiểm tra dữ liệu và thông báo lỗi giữa các phân hệ @qtQuickDocs.

Chuyển động và hiệu ứng chỉ được dùng để phản hồi thao tác hoặc làm rõ trạng thái; chúng không được che khuất nội dung kỹ thuật. Bố cục cần thích ứng với kích thước cửa sổ nhưng vẫn ưu tiên khả năng đọc của bảng, lệnh cấu hình và nhật ký.

=== PyQt6

PyQt6 tạo cầu nối giữa QML và logic Python. Các lớp kế thừa `QObject` công bố thuộc tính, phương thức và tín hiệu để giao diện gọi nghiệp vụ hoặc nhận kết quả bất đồng bộ. Giao diện chịu trách nhiệm tiếp nhận thao tác và trình bày trạng thái; kiểm tra dữ liệu, truy cập cơ sở dữ liệu và kết nối mạng được xử lý ở lớp nghiệp vụ phía sau @pyqt6Docs.

Việc tách giao diện khỏi logic giúp kiểm thử nghiệp vụ mà không cần mở toàn bộ cửa sổ ứng dụng. Đồng thời, tác vụ mạng không được chạy trực tiếp trên luồng giao diện vì thời gian chờ thiết bị có thể làm cửa sổ ngừng phản hồi.

== Thư viện và cơ chế thực thi

#report-table(
  columns: (29%, 71%),
  header: ([Thành phần], [Vai trò trong CAMS]),
  rows: (
    ([Netmiko, Paramiko], [Kết nối thiết bị qua SSH, xử lý phiên CLI và hỗ trợ truyền tệp.]),
    ([Jinja2], [Kết xuất dữ liệu đã kiểm tra thành mẫu lệnh Cisco IOS @jinja2Docs.]),
    ([Dulwich], [Lưu phiên bản cấu hình trong kho Git cục bộ, hỗ trợ lịch sử và so sánh @dulwichDocs.]),
    ([Argon2id, AES-256-GCM], [Dẫn xuất khóa từ mật khẩu và mã hóa có xác thực cho gói dự án khi bật bảo vệ.]),
    ([C++ / POSIX sockets], [Bộ thu Syslog dùng socket và vòng lặp poll ở tiến trình riêng; lưu SQLite và phát sự kiện JSON Lines.]),
    ([Alacritty], [Terminal giả lập nhúng trực tiếp, hỗ trợ thao tác dòng lệnh nhanh qua SSH/Telnet.]),
    ([IPC NTTP/1], [Giao thức nội bộ giữa ứng dụng và terminal đồng hành Alacritty; độc lập với kênh sự kiện của bộ thu Syslog.]),
  ),
  caption: [Các thành phần công nghệ phục vụ quy trình quản trị],
)

Tác vụ mạng được chuyển sang luồng nền để vòng lặp giao diện tiếp tục xử lý thao tác người dùng. *Khóa theo thiết bị* (Host Lock) tuần tự hóa các tác vụ cùng sử dụng một phiên CLI; *bộ thực thi theo lô* (Batch Executor) cho phép xử lý đồng thời trên các thiết bị độc lập. Cách tổ chức này hạn chế lệnh bị xen kẽ trên cùng một phiên mà vẫn tận dụng khả năng xử lý song song @pythonThreadingDocs.

Mỗi tác vụ phải có thời gian chờ và kết quả gắn với thiết bị cụ thể. Việc hủy tác vụ hoặc mất kết nối không đồng nghĩa với hoàn tác các lệnh đã gửi; sau sự cố, hệ thống cần thu thập lại trạng thái để xác định phần cấu hình thực tế đã được áp dụng.

=== Các thành phần hỗ trợ vận hành

Bên cạnh các thư viện Python, CAMS sử dụng bộ thu nhận Syslog viết bằng C++ để tách luồng tiếp nhận nhật ký khỏi tiến trình giao diện. Trình giả lập đầu cuối Alacritty được nhúng dưới dạng tiến trình đồng hành, phục vụ thao tác CLI trực tiếp khi người quản trị cần kiểm tra ngoài luồng tự động @alacrittyDocs. Giao thức nội bộ NTTP/1 trao đổi thông điệp điều khiển giữa ứng dụng và tiến trình đầu cuối; đây là giao thức riêng của đề tài, không phải một giao thức quản trị mạng chuẩn.

== Bảo mật và mã hóa

=== Bảo vệ dữ liệu dự án

*Thư viện cryptography.* CAMS sử dụng gói `cryptography` để gọi các nguyên thủy mật mã Argon2id và AES-GCM thay vì tự hiện thực thuật toán. Thư viện cung cấp giao diện dẫn xuất khóa, mã hóa có xác thực và ngoại lệ `InvalidTag` khi khóa, giá trị dùng một lần (nonce), dữ liệu xác thực bổ sung hoặc bản mã không hợp lệ. Việc dùng thư viện đã được duy trì giúp giảm lỗi hiện thực, nhưng an toàn của hệ thống vẫn phụ thuộc vào cách sinh số ngẫu nhiên, quản lý khóa và lựa chọn tham số @cryptographyKdfDocs @cryptographyAeadDocs.

*Argon2id.* Argon2id là hàm dẫn xuất khóa từ mật khẩu có chi phí bộ nhớ. Biến thể này kết hợp cách truy cập bộ nhớ của Argon2i và Argon2d để cân bằng khả năng hạn chế rò rỉ qua kênh kề với khả năng chống đánh đổi thời gian–bộ nhớ. Các tham số chính gồm muối, dung lượng bộ nhớ, số lượt xử lý, số làn song song và độ dài khóa đầu ra. Muối không cần giữ bí mật nhưng phải đủ dài và khác nhau giữa các lần tạo gói để cùng một mật khẩu không luôn sinh cùng kết quả @rfc9106.

Khi bảo vệ gói dự án, CAMS sinh ngẫu nhiên muối 16 byte và dùng Argon2id với 64 MiB bộ nhớ, ba lượt xử lý, bốn làn song song để tạo khóa 32 byte. Cấu hình này tương ứng phương án thứ hai được RFC 9106 khuyến nghị cho môi trường hạn chế bộ nhớ. Các tham số và muối được ghi trong phần đầu của gói để có thể dẫn xuất lại khóa khi mở tệp; mật khẩu và khóa dẫn xuất không được ghi vào gói.

*AES-256-GCM.* AES-256-GCM sử dụng AES với khóa 256 bit trong chế độ Galois/Counter Mode. Đây là cơ chế mã hóa có xác thực với dữ liệu bổ sung: nội dung được bảo mật thành bản mã, đồng thời thẻ xác thực bảo vệ cả bản mã và phần dữ liệu bổ sung không mã hóa. Nếu mật khẩu sai hoặc tệp bị sửa, bước xác minh thẻ thất bại và dữ liệu rõ không được chấp nhận @nistSp80038d.

CAMS sinh ngẫu nhiên giá trị dùng một lần 12 byte cho mỗi gói và tạo thẻ xác thực 16 byte. Phần đầu chứa phiên bản định dạng, thuật toán, tham số Argon2id, muối, giá trị dùng một lần và độ dài nội dung được đưa vào dữ liệu xác thực bổ sung. Khi giải mã, hệ thống ghi vào tệp tạm và chỉ thay thế tệp đích sau khi xác minh thẻ thành công. Giá trị dùng một lần không được tái sử dụng với cùng một khóa vì sự lặp lại có thể phá vỡ các bảo đảm bảo mật của GCM @cryptographyAeadDocs.

Quy trình bảo vệ được thực hiện theo chuỗi: mật khẩu và muối đi qua Argon2id để tạo khóa 256 bit; khóa cùng giá trị dùng một lần được chuyển cho AES-GCM để mã hóa gói ZIP; thẻ xác thực được ghi cuối gói. Argon2id làm tăng chi phí thử mật khẩu, còn AES-GCM bảo vệ tính bí mật và phát hiện sửa đổi. Hai thành phần giải quyết các mục tiêu khác nhau và phải được dùng kết hợp đúng tham số.

SHA-256 được dùng để tạo giá trị kiểm tra tính toàn vẹn cho tệp trong gói dự án. Giá trị băm giúp phát hiện thay đổi ngoài dự kiến nhưng không thay thế thẻ xác thực của AES-GCM và cũng không chứng minh danh tính người tạo tệp nếu không có cơ chế chữ ký số @nistFips1804.

=== Quản lý thông tin xác thực

Thông tin đăng nhập thiết bị là dữ liệu nhạy cảm vì phần mềm cần khôi phục giá trị gốc khi thiết lập phiên SSH hoặc Telnet. Phiên bản CAMS hiện tại mã hóa các trường thông tin xác thực trong SQLite bằng AES-256-GCM. Khi dự án có mật khẩu, khóa được dẫn xuất bằng Argon2id; khi dự án không có mật khẩu, khóa dẫn xuất từ dữ liệu cục bộ chỉ làm giảm nguy cơ đọc trực tiếp và không cung cấp mức bảo vệ tương đương một bí mật do người dùng nắm giữ.

Khóa và mật khẩu sau giải mã vẫn phải xuất hiện trong bộ nhớ trong thời gian ngắn để thiết lập kết nối. Hướng hoàn thiện là tích hợp kho thông tin xác thực của hệ điều hành, chẳng hạn Windows Data Protection API hoặc Secret Service trên Linux, đồng thời giới hạn thời gian tồn tại của dữ liệu rõ và che thông tin nhạy cảm trong nhật ký @microsoftDpapi @secretServiceSpec.

Cơ chế ghi đè chỉ tác động lên vùng khóa dạng mảng byte do ứng dụng quản lý. Python và thư viện kết nối có thể tạo bản sao chuỗi hoặc byte; vì vậy, thao tác này không bảo đảm xóa mọi bản sao bí mật khỏi bộ nhớ. Các bản ghi cũ cũng cần được di chuyển và kiểm tra trước khi khẳng định toàn bộ dữ liệu xác thực đã mã hóa.

Các cơ sở lý thuyết và công nghệ trên là căn cứ cho mô hình phân tích, thiết kế và quy trình xử lý được trình bày ở Chương 3.
