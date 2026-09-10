#pagebreak(weak: true)
#import "../config/tables.typ": report-table

= Cơ sở lý thuyết và công nghệ

== Quản lý cấu hình và tự động hóa mạng

Trong hệ thống mạng máy tính, router và switch là các thành phần trực tiếp tham gia vào quá trình chuyển tiếp lưu lượng, phân tách miền mạng, định tuyến gói tin và áp dụng chính sách truy cập. Để mạng hoạt động ổn định, người quản trị phải khai báo địa chỉ IP, cấu hình giao diện, thiết lập định tuyến, cấp phát địa chỉ động, kiểm soát truy cập, chuyển đổi địa chỉ mạng, sao lưu cấu hình và theo dõi trạng thái thiết bị — đây là phần nghiệp vụ chính của một hệ thống quản lý cấu hình mạng @tanenbaum2021computer.

Trong mô hình quản trị truyền thống, kỹ sư mạng truy cập từng thiết bị bằng CLI. Phương pháp này cho phép kiểm soát chi tiết nhưng phụ thuộc nhiều vào kiến thức câu lệnh và trạng thái phiên làm việc; khi số lượng thiết bị tăng, cùng một chuỗi cấu hình phải lặp lại trên nhiều thiết bị, làm tăng thời gian triển khai và nguy cơ sai sót.

Quản lý tập trung hướng đến việc đưa thông tin thiết bị, trạng thái kết nối, dữ liệu cấu hình và lịch sử thao tác về một hệ thống thống nhất. Thay vì xem từng thiết bị như một thực thể tách biệt, phần mềm xây dựng một lớp quản lý chung để người dùng lựa chọn thiết bị, chỉnh sửa dữ liệu, kiểm tra cấu hình dự kiến và triển khai khi cần thiết. Đối với CAMS, quản lý thiết bị được xem theo ba nhóm: inventory (mô tả thiết bị đang được quản lý), kết nối (cách phần mềm giao tiếp với thiết bị) và cấu hình (dữ liệu người dùng muốn áp dụng). Cách phân chia này tách thông tin quản trị khỏi logic giao tiếp và là nền tảng cho thiết kế module ở Chương 3.

=== Tự động hóa mạng

Tự động hóa mạng là việc sử dụng phần mềm để hỗ trợ hoặc thực hiện các tác vụ quản trị vốn được tiến hành thủ công; mục tiêu không nhất thiết là loại bỏ người quản trị khỏi quy trình, mà để phần mềm đảm nhiệm các thao tác lặp như kiểm tra dữ liệu, sinh lệnh, kết nối, gửi cấu hình và thu thập kết quả, trong khi quyết định cuối cùng vẫn thuộc về con người.

#figure(
  image("diagrams/01_pipeline_automation.svg", width: 70%),
  caption: [Quy trình cấu hình tự động],
)

So với việc nhập lệnh trực tiếp, cách tiếp cận này giúp chuẩn hóa dữ liệu đầu vào, giảm thao tác lặp, áp dụng cùng một quy tắc cho nhiều thiết bị và lưu lại trạng thái để kiểm tra sau đó. Tuy nhiên, tự động hóa cũng làm tăng yêu cầu về an toàn: một lỗi phần mềm có thể ảnh hưởng đồng thời tới nhiều thiết bị, vì vậy hệ thống cần có validation, cơ chế xem trước, giới hạn xử lý đồng thời và khả năng cô lập lỗi theo từng host.

=== Quản lý cấu hình theo trạng thái

Trong quản lý cấu hình, cần phân biệt trạng thái đang tồn tại trên thiết bị và trạng thái mà người quản trị mong muốn. *Current state* là trạng thái được quan sát hoặc thu thập từ thiết bị tại một thời điểm. *Desired state* là trạng thái mà người quản trị mong muốn thiết bị đạt được — ví dụ khi người dùng chỉnh địa chỉ interface trong phần mềm nhưng chưa gửi lệnh xuống router, dữ liệu này mới chỉ phản ánh trạng thái mong muốn. *Pending configuration* là phần cấu hình đã chỉnh sửa nhưng chưa đồng bộ với thiết bị; *Preview* là bước chuyển desired state thành câu lệnh để người dùng kiểm tra trước; *Push* (hoặc *Apply*) là quá trình gửi cấu hình xuống thiết bị; và *Verify* xác nhận trạng thái thực tế đã phù hợp với kết quả mong muốn.

#figure(
  image("diagrams/02_state_flow.svg", width: 55%),
  caption: [Vòng đời một thay đổi cấu hình theo trạng thái],
)

Việc tách các trạng thái giúp thao tác chỉnh sửa trên giao diện không đồng nghĩa với thay đổi ngay thiết bị thật — nguyên tắc quan trọng đối với CAMS vì hệ thống hướng tới quy trình người dùng chuẩn bị cấu hình, xem trước rồi mới chủ động triển khai. Lịch sử cấu hình cũng cần được phân biệt với rollback tự động: có phiên bản cũ để tham khảo chưa đồng nghĩa hệ thống đã có cơ chế khôi phục tự động hoàn chỉnh.

== Giao diện dòng lệnh và giao thức quản trị thiết bị

=== Giao diện dòng lệnh CLI

Cisco IOS và nhiều hệ điều hành mạng thiết kế CLI theo mô hình phân cấp trạng thái, gồm một số chế độ làm việc cơ bản:

#figure(
  image("diagrams/03_cli_modes.svg", width: 75%),
  caption: [Các chế độ làm việc cơ bản của CLI trên Cisco IOS],
)

Một câu lệnh chỉ có giá trị thực thi trong một ngữ cảnh nhất định — lệnh `ip address` chỉ hợp lệ tại chế độ cấu hình giao diện, trong khi `show ip route` chỉ được chấp nhận tại chế độ EXEC. Do đó, một hệ thống tự động hóa không chỉ gửi chuỗi lệnh mà còn phải nhận diện và chuyển đổi linh hoạt giữa các trạng thái để đảm bảo tính hợp lệ của tác vụ.

Đặc thù của CLI là dữ liệu trả về luôn ở định dạng văn bản thô. Để thu thập running-config hay truy xuất bảng định tuyến, hệ thống cần tích hợp các bộ phân tích cú pháp (Parser) trích xuất thông tin từ luồng văn bản của thiết bị và chuyển đổi thành đối tượng dữ liệu có cấu trúc.

Giao tiếp qua CLI mang lại khả năng tương thích rộng với thiết bị vật lý lẫn môi trường mô phỏng, nhưng bản chất duy trì trạng thái của CLI đặt ra thách thức lớn về quản lý phiên làm việc. Nếu nhiều tiến trình gửi lệnh đồng thời qua cùng một kênh kết nối mà thiếu cơ chế khóa đồng bộ, hiện tượng xung đột và đan xen dữ liệu (Race Condition) sẽ xảy ra, dẫn đến sai lệch nghiêm trọng trong vận hành tự động.

=== SSH và Telnet

Secure Shell (SSH) là giao thức truy cập từ xa có cơ chế bảo vệ kết nối, kiến trúc được mô tả trong RFC 4251 @rfc4251. Trong quản trị mạng, SSH được sử dụng để xác thực người dùng, tạo kênh CLI và trao đổi dữ liệu giữa phần mềm quản trị với router hoặc switch.

#figure(
  image("diagrams/04_ssh_connection.svg", width: 45%),
  caption: [Kết nối từ CAMS tới thiết bị qua SSH],
)

SSH được ưu tiên vì thông tin xác thực và nội dung phiên được bảo vệ tốt hơn Telnet. Trong Python, các thư viện Paramiko và Netmiko hỗ trợ xử lý kết nối, xác thực, prompt và gửi lệnh. Telnet cũng cung cấp khả năng truy cập terminal từ xa nhưng không bảo vệ nội dung phiên; vì vậy Telnet không nên là lựa chọn mặc định trong mạng thực tế, dù vẫn có giá trị trong một số môi trường lab, thiết bị cũ hoặc mô phỏng.

#report-table(
  columns: (30%, 35%, 35%),
  header: ([Tiêu chí], [SSH], [Telnet]),
  rows: (
    ([Bảo vệ nội dung phiên], [Có (mã hóa toàn bộ phiên)], [Không (bản rõ)]),
    ([Cổng TCP mặc định], [22], [23]),
    ([Khuyến nghị trong mạng thực tế], [Ưu tiên bắt buộc], [Hạn chế tối đa]),
    ([Sử dụng trong môi trường lab], [Có (ưu tiên)], [Có (dự phòng cho thiết bị cũ)]),
  ),
  caption: [So sánh các đặc tính giữa giao thức SSH và Telnet],
) <tab-ssh-vs-telnet>

=== Vòng đời phiên quản trị

Một phiên quản trị thường trải qua các bước kết nối, xác thực, mở CLI channel, thực thi lệnh, đọc kết quả và đóng hoặc tái sử dụng phiên.

#figure(
  image("diagrams/05_session_lifecycle.svg", width: 85%),
  caption: [Vòng đời một phiên quản trị thiết bị],
)

Mở kết nối mới cho từng câu lệnh làm tăng số lần xác thực và độ trễ; tái sử dụng session giúp giảm chi phí nhưng yêu cầu phần mềm biết session nào thuộc host nào, còn hợp lệ hay không và có worker nào đang sử dụng — đây là cơ sở cho thiết kế Session Registry và khóa CLI theo host trong Chương 3.

== Nghiệp vụ mạng thuộc phạm vi đề tài

=== Interface và địa chỉ IPv4

Interface là điểm kết nối vật lý hoặc logic của thiết bị với mạng. Với router, một interface Layer 3 thường có tên, địa chỉ IPv4, subnet mask, trạng thái administrative và description:

```text
interface GigabitEthernet0/0
description LAN
ip address 192.168.1.1 255.255.255.0
no shutdown
```

Địa chỉ IPv4 và subnet mask phải được kiểm tra trước khi tạo lệnh. Ngoài interface vật lý, hệ điều hành mạng còn hỗ trợ các interface ảo như Loopback, Tunnel, Subinterface và SVI; interface vật lý gắn với phần cứng và không thể tùy ý tạo hoặc xóa, trong khi Loopback hoặc Tunnel có thể được sinh ra bằng cấu hình.

=== DHCP

Dynamic Host Configuration Protocol (DHCP) cho phép client nhận tự động các tham số mạng, được mô tả trong RFC 2131 @rfc2131. Quá trình cấp phát thường được tóm tắt bằng chuỗi DORA:

#figure(
  image("diagrams/dhcp_dora.png", width: 65%),
  caption: [Chuỗi trao đổi DORA giữa client và DHCP server],
)

Một DHCP pool có thể gồm network, default gateway, DNS server và lease; một số địa chỉ được loại khỏi vùng cấp phát bằng excluded address. Khi client và server khác broadcast domain, router có thể dùng cơ chế relay như `ip helper-address` để chuyển yêu cầu tới DHCP server. Từ góc nhìn phần mềm, DHCP là dữ liệu có quan hệ — một thiết bị có thể có nhiều pool, mỗi pool có nhiều tùy chọn và helper address liên quan tới interface — nên backend cần lưu cấu trúc rõ ràng thay vì chỉ lưu một chuỗi lệnh tổng hợp.

=== Định tuyến tĩnh

Router sử dụng routing table để lựa chọn đường đi tới mạng đích. Static route được cấu hình thủ công bằng mạng đích và next-hop hoặc exit interface:

```text
ip route 10.10.0.0 255.255.0.0 192.168.1.2
ip route 0.0.0.0 0.0.0.0 192.168.1.1
```

Định tuyến tĩnh đơn giản, dễ kiểm soát nhưng không tự thích nghi khi topology thay đổi. Trong hệ thống quản lý cấu hình, static route phù hợp với mô hình Desired State: người dùng nhập destination và next-hop dưới dạng dữ liệu, backend kiểm tra, sinh lệnh, preview và push.

=== OSPF

Open Shortest Path First (OSPF) là giao thức định tuyến động thuộc nhóm link-state; OSPFv2 cho IPv4 được mô tả trong RFC 2328 @rfc2328. Các khái niệm quan trọng trong phạm vi đề tài gồm process, router ID, area, network, interface participation, passive-interface và cost.

#figure(
  image("diagrams/07_ospf_area.png", width: 60%),
  caption: [Ba router cùng thuộc Area 0 trong OSPF],
)

So với static route, dữ liệu OSPF có quan hệ phức tạp hơn: một process có thể có nhiều network, area và thiết lập interface, do đó phần mềm cần mô hình hóa quan hệ parent-child và sinh câu lệnh theo thứ tự phù hợp.

=== EIGRP

Enhanced Interior Gateway Routing Protocol (EIGRP) được mô tả trong RFC 7868 @rfc7868. Trong cấu hình cơ bản, các thành phần thường gặp gồm autonomous system, network statement, passive interface và một số tham số liên quan tới metric hoặc neighbor:

```text
router eigrp 100
network 10.0.0.0
passive-interface GigabitEthernet0/1
```

Tương tự OSPF, EIGRP cũng có mô hình process chứa nhiều network và thiết lập interface; điều quan trọng là duy trì sự nhất quán giữa dữ liệu được lưu, cấu hình preview và trạng thái thật sau khi push.

=== Access Control List

Access Control List (ACL) là tập hợp các luật cho phép hoặc từ chối lưu lượng theo điều kiện xác định; rule được xét theo thứ tự từ trên xuống nên sequence có ý nghĩa nghiệp vụ.

#figure(
  image("diagrams/08_acl_packet_flow.jpg", width: 75%),
  caption: [Gói tin được đối chiếu tuần tự qua các rule trong ACL],
)

Standard ACL phân loại lưu lượng dựa trên địa chỉ IPv4 nguồn; Extended ACL kiểm soát chi tiết hơn dựa trên giao thức, địa chỉ nguồn/đích và cổng dịch vụ. Để đáp ứng các kịch bản an ninh mạng nâng cao, Cisco IOS còn hỗ trợ:

- *Dynamic ACL (Lock-and-Key):* mở cổng truy cập tạm thời cho người dùng sau khi xác thực qua Telnet/SSH.
- *Reflexive ACL:* lọc gói tin theo phiên, tự động cho phép lưu lượng phản hồi dựa trên kết nối được khởi tạo từ bên trong.
- *MAC ACL:* hoạt động tại Lớp 2, kiểm soát lưu lượng dựa trên địa chỉ MAC thay vì địa chỉ IP.

Về thiết kế cơ sở dữ liệu, một ACL quản lý nhiều rule chi tiết theo quan hệ một-nhiều; do sequence quyết định kết quả đối chiếu và lọc gói tin, hệ thống bắt buộc lưu trữ chính xác tham số này để đảm bảo tính toàn vẹn từ khi thiết lập trên giao diện đến khi biên dịch thành tập lệnh CLI.

=== NAT và PAT

Network Address Translation (NAT) chuyển đổi địa chỉ IP giữa các không gian địa chỉ, được mô tả trong RFC 3022 @rfc3022. Static NAT ánh xạ cố định giữa địa chỉ inside local và inside global; Dynamic NAT lựa chọn địa chỉ từ một pool; Port Address Translation (PAT) cho phép nhiều host nội bộ chia sẻ một địa chỉ global bằng cách phân biệt port:

#figure(
  image("diagrams/09_nat_pat.svg", width: 70%),
  caption: [Nhiều host nội bộ chia sẻ một địa chỉ global qua PAT],
)

Cấu hình NAT còn liên quan tới vai trò inside/outside của interface, ACL và route-map, nên backend cần kiểm tra cả các tham chiếu giữa nhiều đối tượng trước khi sinh cấu hình, không chỉ từng trường riêng lẻ.

=== First Hop Redundancy Protocol (FHRP)

FHRP là nhóm cơ chế cung cấp dự phòng cổng mặc định cho thiết bị đầu cuối, với các giao thức thường gặp là HSRP, VRRP và GLBP. Nhiều router phối hợp để cung cấp một địa chỉ gateway ảo chung, nhờ đó host trong mạng LAN không mất kết nối khi một thiết bị định tuyến gặp sự cố.

#figure(
  image("diagrams/10_fhrp_gateway.svg", width: 40%),
  caption: [Hai router cùng cung cấp một virtual gateway theo FHRP],
)

=== Chuyển mạch Lớp 2

VLAN được sử dụng để phân chia hạ tầng mạng vật lý thành các miền broadcast logic độc lập. Cổng truy cập (Access port) thường gán vào một VLAN duy nhất phục vụ thiết bị đầu cuối, trong khi đường trung kế (Trunk port) mang lưu lượng của nhiều VLAN qua cơ chế gắn thẻ chuẩn 802.1Q.

#figure(
  image("diagrams/vlan.png", width: 65%),
  caption: [Mô hình phân chia miền Broadcast bằng VLAN],
)

Trên switch đa tầng, SVI cung cấp giao diện định tuyến Lớp 3 liên kết giữa các VLAN. Để tối ưu băng thông và dự phòng đường truyền giữa các switch, EtherChannel (dùng LACP hoặc PAgP) gom nhiều cổng vật lý thành một cổng logic duy nhất.

#figure(
  image("diagrams/Etherchannel.jpg", width: 65%),
  caption: [Liên kết EtherChannel gom nhóm nhiều cổng vật lý],
)

Spanning Tree Protocol (STP) được triển khai để ngăn chặn vòng lặp ở Lớp 2 bằng cách khóa các đường truyền dự phòng chưa cần thiết.

#figure(
  image("diagrams/STP.jpg", width: 60%),
  caption: [Nguyên lý hoạt động của Spanning Tree Protocol (STP)],
)

VLAN Trunking Protocol (VTP) đồng bộ hóa cơ sở dữ liệu VLAN xuyên suốt một miền quản trị (VTP Domain) từ một switch đóng vai trò VTP Server trung tâm, giảm rủi ro sai sót do cấu hình thủ công phân tán trên từng switch.

#figure(
  image("diagrams/VTP.jpg", width: 65%),
  caption: [Cơ chế đồng bộ cơ sở dữ liệu VLAN qua VTP Domain],
)

=== Bảo mật Lớp 2

Hạ tầng chuyển mạch thường đối mặt với các rủi ro tấn công nội bộ như giả mạo máy chủ cấp phát IP hay đầu độc bộ nhớ cache ARP. Để bảo vệ tính toàn vẹn của luồng dữ liệu, hệ thống quản trị cần tích hợp cấu hình các cơ chế phòng vệ chuyên sâu:

- *DHCP Snooping:* kiểm soát luồng cấp phát IP tại tầng truy cập bằng cách phân loại cổng thành `Trusted` (kết nối DHCP Server hợp pháp) và `Untrusted`, đồng thời xây dựng bảng ràng buộc (`Binding Database`) ánh xạ giữa IP, MAC và cổng vật lý để loại bỏ phản hồi từ DHCP Server giả mạo.

#figure(
  image("diagrams/dhcp-snooping.jpg", width: 65%),
  caption: [Cơ chế kiểm soát luồng cấp phát IP của DHCP Snooping],
)

- *Dynamic ARP Inspection (DAI):* kế thừa dữ liệu từ bảng ràng buộc của DHCP Snooping để đối chiếu tính hợp lệ của gói tin ARP; gói tin có sai lệch giữa IP và MAC bị hủy bỏ, ngăn chặn tấn công trung gian dựa trên ARP Spoofing.

== Cơ sở dữ liệu và SQLite

=== Vai trò của cơ sở dữ liệu

Một hệ thống quản lý cấu hình cần lưu dữ liệu lâu hơn vòng đời của một phiên SSH — các nhóm dữ liệu tiêu biểu gồm inventory, interface, routing, DHCP, ACL, NAT, FHRP, switching, desired state, trạng thái đồng bộ, dữ liệu thu thập và lịch sử cấu hình. Mô hình dữ liệu quan hệ tổ chức thông tin thành bảng: primary key định danh record, foreign key biểu diễn quan hệ giữa các bảng.

#figure(
  image("diagrams/11_db_schema.svg", width: 90%),
  caption: [Quan hệ một-nhiều giữa Device và các bảng nghiệp vụ],
)

Quan hệ một-nhiều phù hợp với thực tế một thiết bị có nhiều interface hoặc nhiều cấu hình nghiệp vụ; việc chuẩn hóa giúp giảm lặp dữ liệu và hạn chế bất nhất.

=== SQLite

SQLite là hệ quản trị cơ sở dữ liệu quan hệ nhúng: dữ liệu được lưu trong file và ứng dụng truy cập trực tiếp qua thư viện, không cần triển khai database server riêng — phù hợp với hệ thống vận hành cục bộ (local-first) như CAMS. SQLite hỗ trợ SQL, transaction, index, constraint và foreign key; tuy nhiên khả năng ghi đồng thời khác với các hệ quản trị cơ sở dữ liệu server chuyên dụng, nên khi nhiều worker cập nhật gần như cùng lúc, backend cần giữ transaction ngắn và hạn chế giữ write lock không cần thiết.

=== Transaction và tính toàn vẹn

Transaction nhóm nhiều thao tác thành một đơn vị logic theo các tính chất ACID (Atomicity, Consistency, Isolation, Durability). Trong bài toán cấu hình mạng, một thao tác có thể đồng thời cập nhật object nghiệp vụ và trạng thái đồng bộ; nếu lỗi xảy ra giữa quá trình, transaction giúp tránh trạng thái chỉ được lưu một phần. Constraint như `NOT NULL`, `UNIQUE`, `CHECK` và foreign key bảo vệ dữ liệu ở tầng persistence, nhưng không thay thế validation nghiệp vụ — một chuỗi có thể đúng kiểu dữ liệu nhưng vẫn không phải địa chỉ IP hoặc prefix phù hợp, nên hệ thống cần kết hợp kiểm tra ở service và ràng buộc ở database.

== Python, Qt Quick và PyQt6

=== Python trong tự động hóa mạng

Python có hệ sinh thái thư viện mạnh cho SSH, template, database và automation. Trong CAMS, Python đảm nhiệm xử lý nghiệp vụ, truy cập SQLite, sinh cấu hình, điều phối worker và cung cấp object cho giao diện Qt. Việc sử dụng Python không tự động tạo ra kiến trúc tốt — nếu UI trực tiếp truy cập SQL hoặc gửi SSH, mã nguồn vẫn khó bảo trì, nên Python cần được tổ chức theo các lớp có trách nhiệm rõ ràng như service, repository, worker và infrastructure.

=== Qt Quick và QML

Qt là framework đa nền tảng; Qt Quick cung cấp mô hình xây dựng giao diện khai báo bằng QML. Thay vì tạo giao diện hoàn toàn bằng lệnh thủ tục, QML mô tả component, property, binding, signal và trạng thái.

#figure(
  image("diagrams/13_qtquick_tree.svg", width: 80%),
  caption: [Cây component chính trong giao diện Qt Quick],
)

Component hóa giúp tái sử dụng button, dialog, panel và form control; property binding giúp UI tự phản ánh giá trị mới, trong khi signal được dùng để thông báo sự kiện giữa các component.

=== PyQt6 và cơ chế signal/slot

PyQt6 cho phép Python sử dụng Qt 6; `QObject` đóng vai trò cầu nối giữa backend và QML.

#figure(
  image("diagrams/14_qml_signal_slot.svg", width: 45%),
  caption: [QObject làm cầu nối giữa QML và tầng Service/Backend],
)

Backend có thể phát signal hoặc thay đổi property để giao diện cập nhật; `pyqtSlot`, `pyqtSignal` và property tạo thành contract giữa QML và Python. Contract này cần được duy trì nhất quán — nếu QML gọi một slot đã đổi tên hoặc thay đổi tham số, lỗi có thể xuất hiện ở runtime, nên QML smoke test và contract test có giá trị khi ứng dụng được refactor.

== Các thư viện phục vụ tự động hóa

=== Netmiko và Paramiko

Paramiko cung cấp implementation SSH cho Python; Netmiko xây dựng lớp hỗ trợ ở mức thiết bị mạng cao hơn, giúp xử lý prompt, device type, show command và configuration mode.

#figure(
  image("diagrams/12_netmiko_stack.svg", width: 40%),
  caption: [Netmiko và Paramiko trong chuỗi kết nối tới Cisco IOS],
)

Trong kiến trúc phần mềm, các thư viện này nên được đặt sau một connector hoặc adapter: service nghiệp vụ chỉ yêu cầu thực thi tác vụ, còn infrastructure chịu trách nhiệm kết nối, gửi lệnh và trả kết quả — cách tách này cũng cho phép thay connector thật bằng fake connector khi kiểm thử.

=== Jinja2

Jinja2 là template engine dùng để tách dữ liệu cấu hình khỏi cú pháp CLI:

```jinja2
interface {{ interface }}
ip address {{ address }} {{ mask }}
no shutdown
```

Với dữ liệu cụ thể, template tạo ra tập lệnh IOS tương ứng; ưu điểm là syntax được tập trung trong template, trong khi validation và nghiệp vụ được xử lý ở service. Template không tự xác nhận dữ liệu hợp lệ, nên pipeline đúng phải kiểm tra dữ liệu trước khi render, sau đó mới tạo preview và triển khai.

=== Nornir và thực thi nhiều host

Nornir là framework automation Python hỗ trợ khái niệm inventory, host và task. Với bài toán nhiều thiết bị, ý tưởng quan trọng là cho phép thực hiện các tác vụ độc lập song song nhưng giới hạn số worker đang chạy. Một batch executor cần giữ kết quả riêng theo host, không để lỗi của một host làm mất toàn bộ batch, và giới hạn concurrency để tránh tạo quá nhiều kết nối cùng lúc — nền tảng của cơ chế xử lý đa thiết bị trong Chương 3.

=== Dulwich

Dulwich là implementation Git bằng Python, có thể dùng để lưu lịch sử running-config dưới dạng các phiên bản text, giúp theo dõi thay đổi theo thời gian và hỗ trợ so sánh. Tuy nhiên, lịch sử phiên bản cần được phân biệt với rollback tự động.

== Xử lý đồng thời và tác vụ nền

=== Tách tác vụ mạng khỏi UI thread

Tác vụ SSH có thể mất nhiều thời gian hơn thao tác giao diện thông thường. Nếu kết nối và gửi lệnh được thực hiện trực tiếp trên UI thread, event loop không thể xử lý repaint và tương tác trong thời gian chờ, khiến cửa sổ có biểu hiện không phản hồi. Giải pháp là đưa tác vụ dài sang worker hoặc executor:

#figure(
  image("diagrams/15_ui_thread_workers.svg", width: 60%),
  caption: [UI thread giao việc dài cho các worker riêng biệt],
)

UI chỉ khởi tạo yêu cầu và nhận kết quả qua signal hoặc cơ chế đồng bộ phù hợp, giúp giao diện duy trì khả năng phản hồi.

=== Song song giữa host và tuần tự trên cùng host

Các thiết bị độc lập có thể được xử lý song song, nhưng nhiều worker không nên đồng thời ghi vào một CLI session của cùng host — nếu lệnh xen kẽ, trạng thái CLI có thể bị thay đổi ngoài dự kiến và output có thể bị đọc nhầm.

#figure(
  image("diagrams/16_host_lock.svg", width: 55%),
  caption: [Nhiều worker cùng tranh chấp một CLI session của một host],
)

Cơ chế lock theo host bảo đảm chỉ một chuỗi thao tác được sử dụng CLI channel tại một thời điểm, trong khi các host khác vẫn chạy song song — nguyên tắc *serialize trên cùng host, parallel giữa các host*.

#figure(
  image("diagrams/17_serialize_parallel.svg", width: 75%),
  caption: [Serialize trên cùng host, parallel giữa các host],
)

Bên cạnh đó, batch executor cần cô lập lỗi, duy trì trạng thái riêng cho từng thiết bị và có cơ chế xử lý yêu cầu hủy ở điểm an toàn.

== Syslog, SFTP và các chức năng hỗ trợ

Syslog là cơ chế phổ biến để thiết bị gửi thông điệp sự kiện tới hệ thống thu thập log, với pipeline cơ bản gồm thiết bị gửi message, receiver tiếp nhận, parser chuẩn hóa, writer lưu dữ liệu và giao diện truy vấn. Với lượng log lớn, ghi theo batch giúp giảm số transaction và hạn chế contention trên SQLite.

#figure(
  image("diagrams/18_syslog_pipeline.svg", width: 90%),
  caption: [Pipeline thu thập log Syslog cơ bản],
)

SFTP cung cấp khả năng truyền file trên kênh bảo mật dựa trên SSH; trong CAMS, thao tác truyền file có thể kéo dài nên cần được thực hiện dưới dạng tác vụ nền và báo tiến độ về giao diện. Hai chức năng này mở rộng CAMS từ công cụ cấu hình sang hướng quản lý tập trung hơn, đóng vai trò hỗ trợ cho các nghiệp vụ cấu hình cốt lõi như interface, routing, DHCP, ACL và NAT.

