#pagebreak(weak: true)

= Cơ sở lý thuyết và công nghệ nền tảng

== Quản lý cấu hình và tự động hóa mạng

// Trong kiến trúc tổng thể của hệ thống mạng máy tính, các thiết bị định tuyến và chuyển mạch đóng vai trò trung tâm trong việc chuyển tiếp lưu lượng, phân tách các miền mạng, thiết lập đường đi cho gói tin và thực thi các chính sách bảo mật. Để duy trì sự vận hành ổn định và liên tục của hạ tầng, người quản trị hệ thống phải gánh vác khối lượng lớn các tác vụ nghiệp vụ như khai báo địa chỉ IP, thiết lập thông số giao diện, cấu hình giao thức định tuyến, triển khai dịch vụ cấp phát địa chỉ động, kiểm soát truy cập, biên dịch địa chỉ, sao lưu cấu hình định kỳ và theo dõi trạng thái thiết bị.

// Đối với mô hình quản trị truyền thống, kỹ sư mạng thường kết nối trực tiếp đến từng thiết bị thông qua CLI. Mặc dù phương pháp này đem lại khả năng kiểm soát chi tiết ở cấp độ câu lệnh, nó bộc lộ hạn chế nghiêm trọng khi quy mô hệ thống mở rộng. Việc lặp đi lặp lại cùng một chuỗi câu lệnh trên nhiều thiết bị không chỉ làm suy giảm hiệu suất lao động mà còn gia tăng rủi ro sai sót do yếu tố con người, chẳng hạn như nhầm lẫn địa chỉ IP, khai báo sai mặt nạ mạng hoặc cấu hình nhầm giao diện. Hơn thế nữa, sự thiếu vắng một cơ sở dữ liệu quản trị tập trung khiến cấu hình thực tế trên thiết bị dễ bị phân tán và phát sinh hiện tượng sai lệch cấu hình so với thiết kế ban đầu.

// Nhằm khắc phục triệt để các bất cập trên, phương pháp quản lý tập trung hướng tới việc hợp nhất thông tin thiết bị, trạng thái kết nối, dữ liệu cấu hình và lịch sử thao tác về một phần mềm quản trị duy nhất. Trong hệ thống CAMS, danh mục quản lý được tổ chức chặt chẽ thành ba nhóm thành phần chính bao gồm: danh mục thiết bị mô tả thông tin định danh của các node mạng, lớp kết nối định nghĩa phương thức mà hệ thống giao tiếp với thiết bị, và dữ liệu cấu hình chứa các tham số nghiệp vụ người dùng muốn áp dụng. Cách phân tách trừu tượng này giúp cô lập thông tin quản trị khỏi logic truyền thông đa giao thức, tạo tiền đề vững chắc cho cấu trúc mã nguồn dạng module.

Trong kiến trúc mạng máy tính, thiết bị định tuyến và chuyển mạch giữ vai trò trung tâm: chuyển tiếp lưu lượng, phân tách miền mạng, thiết lập đường đi cho gói tin và thực thi chính sách bảo mật. Để duy trì hạ tầng ổn định, người quản trị phải đảm nhiệm nhiều tác vụ như khai báo IP, cấu hình giao diện, thiết lập giao thức định tuyến, triển khai DHCP, kiểm soát truy cập, NAT, sao lưu cấu hình và giám sát trạng thái thiết bị.

Trong mô hình truyền thống, kỹ sư mạng kết nối trực tiếp đến từng thiết bị qua CLI. Cách này cho phép kiểm soát chi tiết nhưng khó mở rộng: lặp lại cùng một chuỗi lệnh trên nhiều thiết bị làm giảm hiệu suất và tăng nguy cơ sai sót — nhầm địa chỉ IP, sai mặt nạ mạng, hoặc cấu hình sai giao diện. Việc thiếu cơ sở dữ liệu quản trị tập trung còn khiến cấu hình dễ phân tán và lệch khỏi thiết kế ban đầu.

Để khắc phục, phương pháp quản lý tập trung hợp nhất thông tin thiết bị, trạng thái kết nối, dữ liệu cấu hình và lịch sử thao tác vào một phần mềm duy nhất. Trong hệ thống CAMS, danh mục quản lý được chia thành ba nhóm: danh mục thiết bị (định danh node mạng), lớp kết nối (phương thức giao tiếp với thiết bị), và dữ liệu cấu hình (tham số nghiệp vụ cần áp dụng). Cách phân tách này cô lập thông tin quản trị khỏi logic truyền thông đa giao thức, tạo nền tảng cho cấu trúc mã nguồn dạng module.

=== Tự động hóa mạng trong hạ tầng viễn thông

=== Tự động hóa mạng trong hạ tầng viễn thông

Tự động hóa mạng đại diện cho việc ứng dụng phần mềm để hỗ trợ hoặc thực thi tự động các tác vụ quản trị vốn được tiến hành thủ công bằng tay. Mục tiêu cốt lõi của tự động hóa không phải là loại bỏ hoàn toàn vai trò của kỹ sư mạng, mà là phân giao các thao tác lặp lại mang tính quy chuẩn — như kiểm tra định dạng dữ liệu, sinh tập lệnh CLI, khởi tạo phiên kết nối, đẩy cấu hình và thu thập phản hồi — cho máy tính xử lý, trong khi quyền quyết định phê duyệt cuối cùng vẫn thuộc về con người.

#figure(
  image("/00_book/figures/report/diagrams/01_pipeline_automation.svg", width: 90%),
  caption: [Quy trình cấu hình tự động],
)

// Quy trình cấu hình tự động được chuẩn hóa qua các bước nối tiếp nhau bao gồm tiếp nhận dữ liệu đầu vào, kiểm tra tính hợp lệ, sinh cấu hình tương ứng, khởi tạo kết nối thiết bị, triển khai tập lệnh và thu thập xác minh kết quả. So với thao tác dòng lệnh truyền thống, tự động hóa mang lại ưu thế vượt trội trong việc chuẩn hóa dữ liệu, loại bỏ tác vụ lặp, áp dụng chính sách đồng bộ cho hàng loạt thiết bị và duy trì vết vết lịch sử phục vụ công tác kiểm tra. Tuy nhiên, tự động hóa cũng đặt ra yêu cầu khắt khe về an toàn hệ thống, bởi một lỗi logic trong phần mềm có thể lan truyền và làm gián đoạn đồng thời nhiều thiết bị. Do đó, hệ thống bắt buộc phải tích hợp bộ xác thực dữ liệu, cơ chế xem trước, kiểm soát tần suất xử lý đồng thời và khả năng khoanh vùng sự cố trên từng thiết bị.
Quy trình cấu hình tự động gồm các bước: tiếp nhận dữ liệu, kiểm tra hợp lệ, sinh cấu hình, kết nối thiết bị, triển khai và xác minh kết quả. So với thao tác thủ công, tự động hóa giúp chuẩn hóa dữ liệu, loại bỏ lặp lại, đồng bộ chính sách trên nhiều thiết bị và lưu vết lịch sử để kiểm tra. Tuy nhiên, một lỗi logic có thể lan truyền và ảnh hưởng đồng thời nhiều thiết bị, nên hệ thống cần có xác thực dữ liệu, cơ chế xem trước, kiểm soát tần suất xử lý và khả năng khoanh vùng sự cố.

=== Mô hình quản lý cấu hình theo trạng thái (State-driven Configuration Management)

// Trong lý thuyết quản lý cấu hình hiện đại, điểm mấu chốt là sự phân định rõ ràng giữa trạng thái đang tồn tại thực tế trên thiết bị và trạng thái mong muốn do người quản trị thiết lập. Trạng thái hiện tại biểu diễn dữ liệu cấu hình được thu thập hoặc quan sát trực tiếp từ thiết bị tại một thời điểm nhất định. Trạng thái mong muốn  phản ánh các tham số mà người quản trị hướng tới; ví dụ, khi kỹ sư thay đổi địa chỉ IP trên giao diện phần mềm nhưng chưa thực thi xuống router, dữ liệu này mới chỉ tồn tại dưới dạng trạng thái mong muốn. Cấu hình chờ đại diện cho phần dữ liệu đã chỉnh sửa nhưng chưa được đồng bộ. Bước xem trước đảm nhận việc chuyển đổi trạng thái mong muốn thành các câu lệnh CLI tương ứng để người dùng kiểm duyệt nội dung. Quá trình đẩy cấu hình thực hiện gửi tập tập lệnh xuống thiết bị, và bước xác minh kiểm tra lại phản hồi để đảm bảo trạng thái thực tế đã phù hợp với mong muốn.

// #figure(
//   image("/00_book/figures/report/diagrams/02_state_flow.svg", width: 55%),
//   caption: [Vòng đời một thay đổi cấu hình theo trạng thái],
// )

// Sự phân tách giữa các trạng thái đảm bảo rằng thao tác chỉnh sửa trên giao diện đồ họa không lập tức can thiệp hay làm biến đổi thiết bị thật. Đây là nguyên tắc nền tảng của hệ thống CAMS, cho phép kỹ sư chuẩn bị dữ liệu cấu hình, kiểm tra kỹ lưỡng cú pháp trước khi chủ động phát lệnh triển khai. Bên cạnh đó, việc lưu trữ lịch sử cấu hình cần được phân biệt rõ ràng với cơ chế khôi phục tự động: việc duy trì các bản sao phiên bản cũ của file cấu hình cung cấp dữ liệu tham chiếu trực quan, nhưng để thực hiện rollback tự động hoàn chỉnh đòi hỏi phần mềm phải có engine sinh tập lệnh phủ định tương ứng.

Trong quản lý cấu hình hiện đại, điểm mấu chốt là phân định rõ giữa trạng thái hiện tại (dữ liệu thu thập trực tiếp từ thiết bị) và trạng thái mong muốn (tham số người quản trị hướng tới). Ví dụ, khi kỹ sư đổi IP trên giao diện phần mềm nhưng chưa thực thi xuống router, dữ liệu đó mới chỉ là trạng thái mong muốn — phần chưa đồng bộ này gọi là cấu hình chờ. Bước xem trước cấu hình là chuyển trạng thái mong muốn thành câu lệnh CLI để kiểm duyệt; bước đẩy cấu hình gửi tập lệnh xuống thiết bị; bước xác minh kiểm tra phản hồi để đảm bảo trạng thái thực tế khớp với mong muốn.

#figure(
  image("/00_book/figures/report/diagrams/02_state_flow.svg", width: 110%),
  caption: [Quy trình quản lý cấu hình dựa trên trạng thái],
)

Sự phân tách này đảm bảo thao tác trên giao diện không lập tức tác động đến thiết bị thật — nguyên tắc nền tảng của CAMS, cho phép kỹ sư chuẩn bị và kiểm tra cú pháp trước khi chủ động triển khai. Ngoài ra, lưu trữ lịch sử cấu hình cần phân biệt với cơ chế khôi phục tự động: giữ bản sao phiên bản cũ chỉ cung cấp dữ liệu tham chiếu, còn rollback tự động hoàn chỉnh đòi hỏi engine sinh tập lệnh phủ định tương ứng.

== Giao diện dòng lệnh và giao thức quản trị thiết bị

=== Giao diện dòng lệnh CLI và cơ chế phân tích cú pháp (Parser)
//
// Hệ điều hành Cisco IOS và nhiều hệ điều hành mạng chuyên dụng được thiết kế dựa trên giao diện CLI cấp theo từng chế độ làm việc. Mỗi chế độ cung cấp một nhóm lệnh thực thi riêng biệt, bao gồm Chế độ người dùng (`Router>`), Chế độ đặc quyền (`Router#`), Chế độ cấu hình toàn phần (`Router(config)#`), Chế độ cấu hình Interface (`Router(config-if)#`) và Chế độ cấu hình định tuyến (`Router(config-router)#`).


// Tính phân cấp này quy định rằng một câu lệnh chỉ có hiệu lực trong đúng ngữ cảnh của nó. Ví dụ, câu lệnh khai báo địa chỉ IP `ip address` chỉ hợp lệ tại chế độ cấu hình giao diện, trong khi câu lệnh hiển thị bảng định tuyến `show ip route` chỉ được chấp nhận tại chế độ EXEC. Do đó, một phần mềm tự động hóa mạng không thể chỉ gửi chuỗi văn bản thuần túy, mà phải có khả năng nhận diện dấu nhắc dòng lệnh (prompt) và chuyển đổi linh hoạt giữa các chế độ cấu hình.

// Đặc thù của CLI là dữ liệu trả về luôn ở dạng văn bản thô không cấu trúc. Để trích xuất thông tin cấu hình đang chạy (`running-config`) hay bảng định tuyến, hệ thống phải tích hợp các bộ phân tích cú pháp (Parser) nhằm chuyển đổi luồng văn bản thành các đối tượng dữ liệu quan hệ có cấu trúc. Mặt khác, bản chất duy trì trạng thái của CLI đặt ra thách thức lớn khi xử lý đồng thời: nếu nhiều tiến trình gửi lệnh đan xen vào cùng một kênh kết nối mà không có cơ chế khóa đồng bộ, hiện tượng tranh chấp luồng lệnh (Race Condition) sẽ xảy ra, gây sai lệch nghiêm trọng trong vận hành.

Hệ điều hành Cisco IOS và nhiều hệ điều hành mạng chuyên dụng được thiết kế dựa trên giao diện CLI cấp theo từng chế độ làm việc, mỗi chế độ cung cấp nhóm lệnh riêng: Chế độ người dùng (`Router>`), Chế độ thực thi (`Router#`), Chế độ cấu hình (`Router(config)#`), Chế độ cấu hình Interface (`Router(config-if)#`) và Chế độ cấu hình định tuyến (`Router(config-router)#`).

Tính phân cấp này quy định một câu lệnh chỉ có hiệu lực trong đúng chế độ làm việc — ví dụ `ip address` chỉ hợp lệ ở chế độ cấu hình Interface, còn `show ip route` chỉ được chấp nhận ở chế độ thực thi. Do đó, hệ thống tự động hóa mạng không thể chỉ gửi chuỗi văn bản thuần túy, mà phải nhận diện chế độ làm việc hiện tại dựa vào dấu nhắc dòng và chuyển đổi linh hoạt giữa các chế độ.

Dữ liệu trả về từ CLI luôn ở dạng văn bản thô không cấu trúc, nên để trích xuất thông tin trả về như `running-config` hay bảng định tuyến, hệ thống cần bộ phân tích cú pháp, chuyển văn bản thành đối tượng dữ liệu có cấu trúc. Bên cạnh đó, bản chất duy trì trạng thái của CLI gây thách thức khi xử lý đồng thời: nếu nhiều tiến trình gửi lệnh đan xen trên cùng kênh kết nối mà không có cơ chế khóa đồng bộ, hiện tượng tranh chấp luồng lệnh sẽ xảy ra, gây sai lệch nghiêm trọng trong vận hành.

=== Các giao thức truyền thông an toàn (SSH và Telnet)

Giao thức SSH (RFC 4251) là chuẩn truyền tin mã hóa được ưu tiên hàng đầu cho quản trị từ xa, dùng phương thức mã hóa bất đối xứng và đối xứng để bảo vệ thông tin xác thực và dữ liệu trao đổi giữa phần mềm quản trị và thiết bị mạng.

#figure(
  image("/00_book/figures/report/diagrams/04_ssh_connection.svg", width: 90%),
  caption: [Kết nối từ CAMS tới thiết bị qua SSH],
)

Ngược lại, Telnet truyền dữ liệu dạng văn bản rõ, khiến tài khoản và mật khẩu dễ bị đánh cắp qua kỹ thuật bắt gói tin. Trong vận hành thực tế, Telnet bị hạn chế tối đa và SSH là tiêu chuẩn bắt buộc; tuy nhiên ở phòng lab thử nghiệm hoặc thiết bị cũ, Telnet vẫn được giữ như phương thức dự phòng.

So sánh hai giao thức cho thấy SSH vượt trội về bảo mật: mã hóa toàn bộ dữ liệu qua cổng TCP 22, trong khi Telnet dùng cổng TCP 23 không có cơ chế bảo vệ nào. Trong Python, các thư viện như Paramiko và Netmiko cung cấp lớp trừu tượng mạnh mẽ để quản lý kết nối SSH, xử lý xác thực, tự động nhận diện prompt và gửi tập lệnh an toàn xuống thiết bị.

=== Cơ chế quản lý và tái sử dụng phiên kết nối

Một phiên làm việc với thiết bị mạng qua giao thức SSH hoặc Telnet diễn ra qua chu kỳ gồm các giai đoạn nối tiếp: khởi tạo kết nối mạng, xác thực tài khoản, khởi tạo CLI session, thực thi lệnh, nhận dữ liệu phản hồi, và cuối cùng là đóng hoặc duy trì phiên làm việc.

#figure(
  image("/00_book/figures/report/diagrams/05_session_lifecycle.svg", width: 85%),
  caption: [Phiên quản trị thiết bị],
)

Việc khởi tạo một kết nối SSH mới cho từng câu lệnh đơn lẻ sẽ làm Khoản phí thời gian cho quá trình bắt tay và xác thực rất lớn, dẫn đến độ trễ hệ thống tăng cao. Giải pháp tối ưu là duy trì và tái sử dụng phiên kết nối hiện hành. Tuy nhiên, việc tái sử dụng đòi hỏi hệ thống phải quản lý tập trung danh mục các phiên kết nối thông qua một danh sách đăng ký phiên. Danh sách đăng ký này chịu trách nhiệm ánh xạ chính xác phiên kết nối với từng host, kiểm tra tính khả dụng của kênh truyền và áp dụng cơ chế khóa tuần tự hóa để ngăn chặn sự tranh chấp giữa các tiến trình worker.


== Các nghiệp vụ mạng được hỗ trợ

=== Cổng interface và địa chỉ IPv4

Cổng interface là điểm kết nối vật lý hoặc logic của thiết bị mạng. Với giao diện Lớp 3, CAMS quản lý tên, địa chỉ IPv4, subnet, trạng thái `shutdown`/`no shutdown` và phần mô tả; các giá trị được kiểm tra trước khi sinh lệnh CLI.

Ngoài cổng vật lý, Cisco IOS còn hỗ trợ các giao diện logic như Loopback, Tunnel, Subinterface và SVI. Các giao diện này phục vụ định danh thiết bị, tạo đường hầm và định tuyến liên VLAN.

#figure(
  image("/00_book/figures/gui/chapter-05/01-router-interface-overview.png", width: 90%),
  caption: [tổng quan interface tab],
)

=== DHCP và DHCP Relay

DHCP là dịch vụ cấp địa chỉ IP tự động cho thiết bị đầu cuối. Quá trình cấp phát gồm bốn bước DORA: Discover, Offer, Request và Acknowledge.

#figure(
  image("/00_book/figures/report/diagrams/06_dhcp_dora.svg", width: 65%),
  caption: [Chuỗi trao đổi DORA giữa client và DHCP server],
)

Một DHCP Pool gồm dải mạng, Default Gateway , DNS và thời gian cấp ip. Lệnh `excluded-address` loại trừ địa chỉ tĩnh; `ip helper-address` chuyển tiếp yêu cầu khi client và server ở khác miền quảng bá. CAMS lưu các pool và helper address dưới dạng dữ liệu có cấu trúc để kiểm tra và sinh cấu hình.

=== Định tuyến tĩnh

Tuyến tĩnh xác định mạng đích cùng next-hop hoặc giao diện đầu ra. Tuyến mặc định `0.0.0.0 0.0.0.0` xử lý lưu lượng không khớp các tuyến cụ thể.

Cách định tuyến này dễ kiểm soát nhưng không tự thích ứng khi sơ đồ mạng thay đổi. CAMS cho phép nhập tham số, kiểm tra dữ liệu, xem trước lệnh và triển khai cấu hình.

=== OSPFv2

OSPFv2 là giao thức định tuyến trạng thái liên kết cho IPv4, sử dụng thuật toán Dijkstra để tính đường đi ngắn nhất.

#figure(
  image("/00_book/figures/report/diagrams/07_ospf_area.svg", width: 60%),
  caption: [Ba router cùng thuộc Area 0 trong OSPF],
)

Cấu hình OSPF gồm Process ID, Router ID, Area, network statement và `passive-interface`. CAMS phải duy trì đúng quan hệ giữa tiến trình, vùng và dải mạng, đồng thời sinh lệnh theo thứ tự phụ thuộc.

=== EIGRP

EIGRP là giao thức định tuyến vector khoảng cách nâng cao, sử dụng thuật toán DUAL để tìm đường đi không lặp và hội tụ nhanh. Các tham số chính gồm AS, dải mạng quảng bá, giao diện thụ động và metric. CAMS bảo đảm dữ liệu lưu trữ, nội dung xem trước và cấu hình triển khai luôn nhất quán.

=== Danh sách kiểm soát truy cập

ACL là tập quy tắc `permit` hoặc `deny` được xét từ trên xuống; thứ tự và sequence number quyết định kết quả lọc.

#figure(
  image("/00_book/figures/report/diagrams/08_acl_packet_flow.svg", width: 75%),
  caption: [Gói tin được đối chiếu tuần tự qua các rule trong ACL],
)

Standard ACL lọc theo địa chỉ nguồn, còn Extended ACL có thể xét giao thức, địa chỉ nguồn/đích và cổng dịch vụ. CAMS cũng hỗ trợ Dynamic ACL, Reflexive ACL và MAC ACL; mỗi ACL được lưu cùng các rule theo đúng thứ tự.

=== NAT và PAT

NAT chuyển đổi địa chỉ giữa các không gian mạng. Static NAT ánh xạ cố định một-một, Dynamic NAT lấy địa chỉ từ pool, còn PAT cho phép nhiều host dùng chung một địa chỉ công cộng thông qua số cổng.

#figure(
  image("/00_book/figures/report/diagrams/09_nat_pat.svg", width: 70%),
  caption: [Nhiều host nội bộ chia sẻ một địa chỉ global qua PAT],
)

Cấu hình NAT liên quan đến vai trò `ip nat inside`/`outside`, ACL, pool và bảng ánh xạ. CAMS kiểm tra các tham chiếu này trước khi sinh lệnh.

=== Giao thức dự phòng Default Gateway

Các giao thức FHRP như HSRP, VRRP và GLBP cho phép nhiều router cung cấp một Default Gateway ảo.

#figure(
  image("/00_book/figures/report/diagrams/10_fhrp_gateway.svg", width: 40%),
  caption: [Hai router cùng cung cấp một virtual gateway theo FHRP],
)

Khi router chính gặp sự cố, router dự phòng tiếp quản địa chỉ IP và MAC ảo. GLBP còn hỗ trợ cân bằng tải giữa các router thành viên.

=== Chuyển mạch ở Layer 2

VLAN là phương thức chia mạng vật lý thành các dải mạng ảo logic. Cổng Access phục vụ một VLAN, còn cổng Trunk mang nhiều VLAN bằng chuẩn 802.1Q.

#figure(
  image("/00_book/figures/report/diagrams/vlan.png", width: 65%),
  caption: [Mô hình phân chia miền Broadcast bằng VLAN],
)

SVI cung cấp định tuyến liên VLAN trên switch đa tầng. EtherChannel dùng LACP (IEEE 802.3ad) hoặc PAgP (độc quyền Cisco) để gộp nhiều cổng vật lý như một cổng logic.

#figure(
  image("/00_book/figures/report/diagrams/Etherchannel.jpg", width: 65%),
  caption: [Liên kết EtherChannel gom nhóm nhiều cổng vật lý],
)

STP cùng các biến thể PVST+ và RSTP  ngăn vòng lặp Layer 2 bằng cách bầu Root Bridge, tính đường đi ngắn nhất từ mỗi switch đến Root Bridge, rồi khóa các liên kết dự phòng chưa cần thiết — chỉ giữ chuển tiếp gói tin(forwarding) trên đường đi tốt nhất. Khi liên kết đang forwarding gặp sự cố, một cổng đang bị khoá sẽ được kích hoạt lại để khôi phục kết nối.

#figure(
  image("/00_book/figures/report/diagrams/STP.jpg", width: 60%),
  caption: [Nguyên lý hoạt động của Spanning Tree Protocol (STP)],
)

VTP đồng bộ cơ sở dữ liệu VLAN giữa các switch trong cùng miền quản trị.

#figure(
  image("/00_book/figures/report/diagrams/VTP.jpg", width: 65%),
  caption: [Cơ chế đồng bộ cơ sở dữ liệu VLAN qua VTP Domain],
)

=== Bảo mật Lớp 2

DHCP Snooping ngăn máy chủ DHCP giả mạo bằng cách phân loại cổng Trusted/Untrusted và xây dựng bảng ánh xạ IP, MAC, VLAN và cổng vật lý.

#figure(
  image("/00_book/figures/report/diagrams/dhcp-snooping.jpg", width: 65%),
  caption: [Cơ chế kiểm soát luồng cấp phát IP của DHCP Snooping],
)

Dynamic ARP Inspection đối chiếu gói ARP với bảng của DHCP Snooping. Gói có ánh xạ IP–MAC không hợp lệ sẽ bị loại bỏ, giúp hạn chế ARP Spoofing.

// == Kiến trúc cơ sở dữ liệu quan hệ và SQLite

// === Vai trò của cơ sở dữ liệu trong hệ thống Local-first

// Một phần mềm quản lý cấu hình mạng đòi hỏi khả năng lưu trữ dữ liệu bền vững vượt khỏi vòng đời của một phiên kết nối SSH. Dữ liệu hệ thống bao gồm danh mục thiết bị, thông số giao diện, bảng định tuyến, DHCP Pool, danh sách ACL, quy tắc NAT, cấu hình Switching, trạng thái Desired State và lịch sử thao tác.

// #figure(
//   image("/00_book/figures/report/diagrams/11_db_schema.svg", width: 90%),
//   caption: [Quan hệ một-nhiều giữa Device và các bảng nghiệp vụ],
// )

// Mô hình dữ liệu quan hệ tổ chức thông tin thành các bảng chuẩn hóa: khóa chính (primary key) định danh duy nhất cho từng bản ghi, và khóa ngoại (foreign key) thể hiện mối quan hệ giữa các bảng. Quan hệ một-nhiều (1-n) phản ánh chính xác thực tế một thiết bị quản lý nhiều giao diện và nhiều chính sách nghiệp vụ, giúp loại bỏ sự trùng lặp dữ liệu và đảm bảo tính toàn vẹn hệ thống.

// === Hệ quản trị cơ sở dữ liệu nhúng SQLite

// SQLite là hệ quản trị cơ sở dữ liệu quan hệ dạng nhúng (embedded database): toàn bộ dữ liệu được đóng gói trong các tệp đơn lẻ và ứng dụng truy xuất trực tiếp thông qua thư viện liên kết mà không cần triển khai một database server riêng biệt. Cấu trúc này phù hợp hoàn hảo với các ứng dụng vận hành cục bộ (local-first) như CAMS.

// SQLite hỗ trợ đầy đủ cú pháp SQL tiêu chuẩn, cơ chế giao dịch (transaction), chỉ mục (index), ràng buộc (constraint) và khóa ngoại. Tuy nhiên, do đặc thù ghi dữ liệu theo cơ chế khóa toàn bộ tệp (file locking), khi có nhiều tiến trình worker đồng thời truy cập ghi, phần mềm cần duy trì các giao dịch ngắn và giải phóng khóa ghi ngay khi hoàn tất để tránh tắc nghẽn.

// === Giao dịch ACID và tính toàn vẹn dữ liệu

// Giao dịch (Transaction) nhóm nhiều thao tác dữ liệu thành một đơn vị xử lý logic tuân theo các nguyên tắc ACID (Atomicity - Tính nguyên tố, Consistency - Tính nhất quán, Isolation - Tính cô lập, Durability - Tính bền vững). Trong nghiệp vụ mạng, một thao tác đẩy cấu hình thường đồng thời cập nhật bản ghi nghiệp vụ và cờ trạng thái đồng bộ; nếu sự cố xảy ra giữa chừng, giao dịch giúp cuộn ngược (rollback) dữ liệu về trạng thái an toàn ban đầu.

// Các ràng buộc cấp CSDL như `NOT NULL`, `UNIQUE`, `CHECK` và `FOREIGN KEY` bảo vệ dữ liệu ở tầng lưu trữ. Tuy nhiên, chúng không thể thay thế hoàn toàn bộ xác thực nghiệp vụ (Service Validation) ở tầng ứng dụng — ví dụ, một chuỗi ký tự có thể đúng kiểu dữ liệu text nhưng lại không phải là địa chỉ IPv4 hay mặt nạ mạng hợp lệ. Do đó, hệ thống bắt buộc phải kết hợp kiểm tra logic tại tầng service trước khi ghi xuống cơ sở dữ liệu.


// == Nền tảng phát triển Python, Qt Quick và PyQt6

// === Ngôn ngữ Python trong kiến trúc tự động hóa phân lớp

// Python sở hữu hệ sinh thái thư viện phong phú phục vụ truyền thông SSH, xử lý dữ liệu, render template và thao tác cơ sở dữ liệu. Trong kiến trúc CAMS, Python đảm nhận vai trò xử lý logic nghiệp vụ, tương tác với SQLite, sinh mã cấu hình, điều phối luồng worker và cung cấp cầu nối dữ liệu cho giao diện đồ họa.

// Để xây dựng một phần mềm dễ bảo trì và mở rộng, mã nguồn Python phải tuân thủ kiến trúc phân lớp Clean Architecture. Tầng giao diện không được phép truy vấn SQL hoặc mở socket kết nối SSH trực tiếp; thay vào đó, hệ thống phân chia trách nhiệm rõ ràng thành các tầng Service (nghiệp vụ), Repository (truy xuất dữ liệu), Worker (thực thi mạng) và Infrastructure (hạ tầng kỹ thuật).

// === Công nghệ giao diện khai báo Qt Quick và QML

// Qt Quick cung cấp môi trường xây dựng giao diện người dùng hiện đại dựa trên ngôn ngữ khai báo QML. Thay vì khởi tạo giao diện bằng các câu lệnh thủ tục lặp đi lặp lại, QML cho phép mô tả cấu trúc component, thuộc tính (property), ràng buộc dữ liệu (binding) và phản hồi sự kiện (signal) một cách trực quan.

// #figure(
//   image("/00_book/figures/report/diagrams/13_qtquick_tree.svg", width: 80%),
//   caption: [Cây component chính trong giao diện Qt Quick],
// )

// Kiến trúc component hóa giúp tái sử dụng linh hoạt các thành phần UI như Button, Dialog, Form Control và Table View. Cơ chế property binding tự động cập nhật hiển thị trên giao diện ngay khi giá trị thuộc tính ở backend thay đổi, giảm thiểu đáng kể mã nguồn quản lý trạng thái giao diện.

// === PyQt6 và cơ chế kết nối tín hiệu Signal/Slot

// PyQt6 đóng vai trò là thư viện liên kết cho phép mã nguồn Python tương tác với framework Qt 6. Lớp `QObject` đóng vai trò là cầu nối trung tâm giữa logic xử lý Python và giao diện khai báo QML.

// #figure(
//   image("/00_book/figures/report/diagrams/14_qml_signal_slot.svg", width: 45%),
//   caption: [QObject làm cầu nối giữa QML và tầng Service/Backend],
// )

// Tầng backend Python định nghĩa các slot (thông qua decorator `@pyqtSlot`) để QML gọi thực thi các hàm nghiệp vụ, đồng thời phát các tín hiệu (thông qua `pyqtSignal`) để thông báo cho QML cập nhật giao diện. Sự phối hợp giữa `pyqtSlot`, `pyqtSignal` và `Q_PROPERTY` tạo thành một hợp đồng giao tiếp (Contract) chặt chẽ giữa hai tầng phần mềm.


// == Các thư viện tự động hóa và quản lý phiên bản chuyên dụng

// === Thư viện kết nối CLI Netmiko và Paramiko

// Paramiko là thư viện Python thuần túy triển khai giao thức SSHv2, quản lý các kết nối mã hóa cấp thấp. Netmiko được phát triển dựa trên Paramiko, nâng cấp thành một lớp hỗ trợ chuyên dụng cho các thiết bị mạng bằng cách tự động xử lý dấu nhắc dòng lệnh (prompt), chuyển đổi giữa các mode cấu hình và quản lý thời gian chờ (timeout).

// #figure(
//   image("/00_book/figures/report/diagrams/12_netmiko_stack.svg", width: 40%),
//   caption: [Netmiko và Paramiko trong chuỗi kết nối tới Cisco IOS],
// )

// Trong thiết kế phần mềm CAMS, Netmiko và Paramiko được ẩn đằng sau lớp Adapter/Connector. Tầng dịch vụ nghiệp vụ chỉ gửi yêu cầu thực thi tập lệnh mà không cần quan tâm đến chi tiết kết nối cấp thấp, giúp dễ dàng thay thế bằng các Fake Connector phục vụ kiểm thử tự động (Unit Test).

// === Engine kết xuất mẫu cấu hình Jinja2

// Jinja2 là một template engine mạnh mẽ giúp tách biệt hoàn toàn dữ liệu cấu hình khỏi cú pháp CLI. Các mẫu cấu hình (`.j2`) định nghĩa cấu trúc lệnh Cisco IOS chuẩn với các biến dữ liệu được đặt trong thẻ `{{ variable }}`.

// Khi truyền các đối tượng dữ liệu cụ thể vào template, Jinja2 biên dịch và kết xuất ra khối lệnh CLI hoàn chỉnh. Ưu điểm vượt trội của Jinja2 là giúp tập trung toàn bộ cú pháp CLI tại hệ thống template, trong khi logic kiểm tra dữ liệu được đảm nhiệm ở tầng service.

// === Mô hình thực thi đa thiết bị Nornir

// Nornir là framework tự động hóa mạng thuần Python cung cấp cơ chế quản lý danh mục (Inventory) và thực thi tác vụ song song trên nhiều host. Ý tưởng cốt lõi kế thừa từ Nornir là việc triển khai các tác vụ độc lập đồng thời trên nhiều thiết bị, nhưng có giới hạn số lượng worker tối đa (concurrency limit). Mô hình Batch Executor phải cô lập lỗi độc lập theo từng host, đảm bảo sự cố trên một thiết bị không làm ảnh hưởng đến tiến trình thực thi của các thiết bị còn lại.

// === Quản lý lịch sử và kiểm soát phiên bản bằng Dulwich

// Dulwich là thư viện triển khai giao thức Git thuần túy bằng Python, cho phép phần mềm khởi tạo và quản lý các kho lưu trữ Git cục bộ mà không cần cài đặt công cụ Git client trên hệ điều hành. CAMS ứng dụng Dulwich để tự động lưu trữ cấu hình `running-config` thu thập từ thiết bị thành các bản commit theo thời gian, hỗ trợ người dùng xem lại lịch sử và so sánh sự khác biệt cấu hình (Unified Diff) một cách trực quan.


== Kiến trúc cơ sở dữ liệu quan hệ và SQLite

=== Vai trò của cơ sở dữ liệu trong hệ thống Local-first

Hệ thống cần một môi trường quản lý cấu hình mạng và lưu trữ dữ liệu ngoài một phiên làm việc SSH: danh mục thiết bị, thông số cổn, bảng dữ liệu, các cấu hình: Routing, DHCP , ACL, NAT, cấu hình Switching, trạng thái làm việc ngoài hoặc trong phiên SSH.

#figure(
  image("/00_book/figures/report/diagrams/11_db_schema.svg", width: 90%),
  caption: [Quan hệ một-nhiều giữa Device và các bảng nghiệp vụ],
)

Mô hình quan hệ tổ chức dữ liệu thành các bảng chuẩn hóa, sử dụng khóa chính và khóa ngoại để liên kết. Quan hệ một-nhiều (1-n) phản ánh đúng thực tế: một thiết bị có thể sở hữu nhiều cổng kết nối và nhiều chính sách cấu hình, nhờ đó loại bỏ trùng lặp dữ liệu và đảm bảo tính toàn vẹn hệ thống.

=== Hệ quản trị cơ sở dữ liệu nhúng SQLite

SQLite là hệ quản trị cơ sở dữ liệu quan hệ dạng nhúng (embedded database), trong đó toàn bộ dữ liệu được đóng gói trong một tệp duy nhất và được hệ thống truy xuất trực tiếp thông qua thư viện liên kết mà không cần triển khai một máy chủ cơ sở dữ liệu riêng biệt; đặc điểm này khiến SQLite trở nên phù hợp với các hệ thống vận hành cục bộ như CAMS. Về mặt kỹ thuật, SQLite hỗ trợ đầy đủ cú pháp SQL chuẩn cùng các cơ chế giao tiếp, chỉ mục, ràng buộc và khóa ngoại, đảm bảo tính nhất quán và toàn vẹn của dữ liệu lưu trữ. Tuy nhiên, do sử dụng cơ chế khóa toàn tệp trong quá trình ghi, khi có nhiều tiến trình worker truy cập đồng thời, hệ thống cần duy trì các giao tiếp có phạm vi ngắn và giải phóng thanh ghi ngay sau khi hoàn tất thao tác, nhằm tránh hiện tượng tắc nghẽn tài nguyên.


== Nền tảng phát triển Python, Qt Quick và PyQt6

=== Python trong kiến trúc tự động hóa phân lớp

Python sở hữu hệ sinh thái thư viện phong phú, đáp ứng tốt các nhu cầu về cấu hình qua SSH, xử lý dữ liệu, kết xuất template và thao tác với cơ sở dữ liệu. Trong kiến trúc CAMS, Python đảm nhận vai trò xử lý logic nghiệp vụ, tương tác với SQLite, sinh mã cấu hình, điều phối các luồng worker và cung cấp cầu nối dữ liệu cho giao diện đồ họa. Để đảm bảo khả năng bảo trì và mở rộng, mã nguồn Python tuân thủ nguyên tắc Clean Architecture, theo đó tầng UI không được phép truy vấn SQL hay mở kết nối SSH một cách trực tiếp, mà trách nhiệm được phân chia rõ ràng thành các tầng Service, Repository, Worker và Infrastructure.

=== Qt Quick và QML

Qt Quick xây dựng giao diện khai báo qua QML: mô tả component, property, binding và signal trực quan thay vì mã thủ tục.

#figure(
  image("/00_book/figures/report/diagrams/13_qtquick_tree.svg", width: 80%),
  caption: [Cây component chính trong giao diện Qt Quick],
)

Component hóa giúp tái sử dụng Button, Dialog, Form Control, Table View. Property binding tự động cập nhật giao diện khi backend thay đổi, giảm mã quản lý trạng thái UI.

=== PyQt6 và Signal/Slot

PyQt6 là cầu nối Python–Qt 6. `QObject` là cầu nối trung tâm giữa logic Python và QML.

#figure(
  image("/00_book/figures/report/diagrams/14_qml_signal_slot.svg", width: 45%),
  caption: [QObject làm cầu nối giữa QML và tầng Service/Backend],
)

Backend định nghĩa slot (`@pyqtSlot`) để QML gọi, và phát signal (`pyqtSignal`) để QML cập nhật giao diện. `pyqtSlot`, `pyqtSignal`, `Q_PROPERTY` tạo thành hợp đồng giao tiếp chặt chẽ giữa hai tầng.


== Các thư viện tự động hóa và quản lý phiên bản chuyên dụng

=== Netmiko và Paramiko

Paramiko triển khai SSHv2 thuần Python. Netmiko xây trên Paramiko, tự động xử lý prompt, chuyển mode cấu hình và quản lý timeout cho thiết bị mạng.

#figure(
  image("/00_book/figures/report/diagrams/12_netmiko_stack.svg", width: 40%),
  caption: [Netmiko và Paramiko trong chuỗi kết nối tới Cisco IOS],
)

Trong CAMS, Netmiko/Paramiko được ẩn sau lớp Adapter/Connector, giúp tầng service không cần quan tâm chi tiết kết nối và dễ thay bằng Fake Connector khi unit test.

=== Jinja2

Jinja2 tách dữ liệu cấu hình khỏi cú pháp CLI. Template `.j2` định nghĩa lệnh Cisco IOS với biến `{{ variable }}`; Jinja2 kết xuất thành khối lệnh hoàn chỉnh, tập trung cú pháp CLI vào template trong khi logic kiểm tra dữ liệu nằm ở tầng service.

=== Nornir

Nornir là framework tự động hóa mạng thuần Python, quản lý Inventory và thực thi song song trên nhiều host với giới hạn concurrency. Batch Executor phải cô lập lỗi theo từng host để sự cố trên một thiết bị không ảnh hưởng các thiết bị khác.

=== Dulwich

Dulwich triển khai Git thuần Python, cho phép quản lý repo cục bộ mà không cần cài Git client. CAMS dùng Dulwich để tự động commit `running-config` theo thời gian, hỗ trợ xem lịch sử và so sánh Unified Diff.

== Cơ chế xử lý đồng thời và mô hình tác vụ nền

=== Phân tách luồng mạng khỏi luồng giao diện chính (UI Thread)

Các tác vụ giao tiếp mạng qua SSH thường mất nhiều thời gian do độ trễ đường truyền và tốc độ phản hồi của thiết bị. Nếu các lệnh kết nối và đẩy cấu hình được thực thi trực tiếp trên luồng giao diện chính (UI Thread), vòng lặp sự kiện (Event Loop) sẽ bị ngắt quãng, dẫn đến hiện tượng giao diện bị treo đứng (Freeze/Not Responding).

#figure(
  image("/00_book/figures/report/diagrams/15_ui_thread_workers.svg", width: 60%),
  caption: [UI thread giao việc dài cho các worker riêng biệt],
)

Giải pháp kiến trúc bắt buộc là đẩy toàn bộ các tác vụ mạng dài hạn sang các luồng xử lý nền (Worker Threads). Luồng UI Thread chỉ gửi yêu cầu kích hoạt và tiếp nhận kết quả phản hồi thông qua tín hiệu bất đồng bộ, giữ cho giao diện người dùng luôn phản hồi mượt mà.

=== Nguyên tắc khóa thiết bị (Host Lock) và điều phối song song

Khi xử lý đa nhiệm, các thiết bị mạng độc lập có thể được kết nối song song, nhưng đối với từng thiết bị đơn lẻ, việc nhiều worker đồng thời gửi lệnh vào cùng một phiên CLI sẽ gây ra tranh chấp nghiêm trọng.

#figure(
  image("/00_book/figures/report/diagrams/16_host_lock.svg", width: 55%),
  caption: [Nhiều worker cùng tranh chấp một CLI session của một host],
)

Cơ chế khóa theo thiết bị (Host Lock) áp dụng một khóa tuần tự hóa (`operation_lock`) trên từng host. Khóa này bảo đảm rằng tại một thời điểm chỉ có duy nhất một tác vụ được quyền sử dụng kênh CLI của thiết bị đó, trong khi tác vụ trên các thiết bị khác vẫn vận hành song song — tuân thủ triệt để nguyên tắc: tuần tự hóa trên cùng một host, song song giữa các host khác nhau.

#figure(
  image("/00_book/figures/report/diagrams/17_serialize_parallel.svg", width: 75%),
  caption: [Serialize trên cùng host, parallel giữa các host],
)


== Hệ thống giám sát Syslog, SFTP và các tiện ích đồng hành

Syslog là một giao thức tiêu chuẩn được sử dụng rộng rãi, cho phép các thiết bị mạng gửi tin theo thời gian thực về một máy chủ thu nhận tập trung. tác vụ của Syslog trong hệ thống thường bao gồm nhiều thành phần phối hợp với nhau: thiết bị phát sinh gửi gói tin, bộ tiếp nhận đảm nhận việc lắng nghe và thu thập gói tin, bộ bóc tách chịu trách nhiệm phân tích cú pháp gói tin thô thành dữ liệu có cấu trúc, bộ ghi dữ liệu theo lô thực hiện việc lưu trữ, và cuối cùng là giao diện truy vấn phục vụ người quản trị khai thác dữ liệu. Trong đó, cơ chế ghi theo lô đóng vai trò quan trọng: bằng cách gộp nhiều bản tin thành một giao diện ghi duy nhất, hệ thống giảm đáng kể tần suất cật nhật giao diện với cơ sở dữ liệu, qua đó hạn chế tình trạng nghẽn I/O — vốn là điểm yếu cố hữu của SQLite khi phải xử lý một khối lượng lớn thao tác ghi rời rạc trong thời gian ngắn.

#figure(
  image("/00_book/figures/gui/chapter-13/01-system-logs-overview.png", width: 90%),
  caption: [system logs tabs overview],
)

Bên cạnh Syslog, hệ thống còn có tích hợp SSH file transfer client với 2 phương thức chính là SFTP và SCP, giúp người quản trị có thể đi sâu vào vùng nhớ thết bị mạng và trao đổi tiệp hoặc sửa tiệp của thiết bị.

#figure(
  image("/00_book/figures/gui/chapter-12/02-sftp-workspace-overview.png", width: 90%),
  caption: [SSH file transfer client overview],
)
