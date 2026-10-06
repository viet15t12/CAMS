# Đánh giá báo cáo CAMS và đối chiếu góp ý của giảng viên

Ngày kiểm tra: 06/10/2026.

## Phạm vi và kết luận

Đối chiếu bản `main.pdf` tạo lúc 10:56 ngày 06/10/2026 (116 trang PDF), các tệp Typst được `main.typ` đưa vào báo cáo, và toàn bộ 7 trang trong `Góp ý chỉnh sửa báo cáo_nhóm Kiên.pdf`. Kiểm tra thêm các khai báo SQL, mô-đun mã hóa thông tin xác thực và tài liệu/bảng ghi kết quả Lab 2 để xác minh một số nhận xét. Đã xem bố cục toàn bộ PDF qua ảnh tổng quan và phóng lớn các trang có vấn đề. Không chạy lại EVE-NG hoặc kiểm thử vận hành phần mềm.

Các số trang dưới đây là **số in ở chân trang báo cáo**. Ví dụ trang 56 tương ứng trang PDF thứ 72; trang 78 tương ứng trang PDF thứ 94. Phần đầu dùng số La Mã.

**Đánh giá chung:** báo cáo đã cải thiện đáng kể, đặc biệt ở kiểm chứng an ninh mạng và kịch bản OSPF mới. Tuy nhiên, chưa xử lý đầy đủ các yêu cầu quan trọng về đánh giá định lượng, thử lỗi và kết luận dựa trên bằng chứng. Đây là bản có nền tảng tốt để hoàn thiện, nhưng chưa nên coi là bản cuối để nộp lại.

Điểm mạnh hiện tại là chuỗi bằng chứng cấu hình → hành vi thiết bị → nhật ký → CAMS trong DAI và ACL. Điểm yếu lớn nhất là Chương 5 mới xác minh chức năng ở các tình huống cụ thể, trong khi Chương 6 vẫn có các kết luận rộng và thông tin cũ. Bổ sung thêm ảnh thao tác sẽ không giải quyết khoảng trống này; cần số đo và ma trận đối chiếu yêu cầu.

## 1. Đối chiếu 10 nhóm sửa mà thầy tổng hợp

| TT | Yêu cầu của thầy | Tình trạng bản hiện tại | Đánh giá và phần cần làm |
|---|---|---|---|
| 1 | Sửa font tiếng Việt; bổ sung trang bìa | Đã xử lý phần lớn | Có bìa chính, bìa phụ; các tiêu đề nghiêng và chú thích được phóng lớn hiển thị dấu tiếng Việt đầy đủ. Còn phải đối chiếu mẫu chính thức và mã số đề tài nếu được cấp. |
| 2 | Sửa cổng R6, redistribute, traceroute, facility Syslog | Xử lý một phần; đã thay bài OSPF | Bài OSPF hiện dùng 5 router, một vùng, network + passive-interface, không còn R6/redistribute của bài cũ. Traceroute OSPF đã giải thích đúng; bài GLBP–NAT vẫn còn diễn giải cũ. Facility được phân biệt ở lý thuyết và ACL nhưng đoạn chi tiết Syslog còn dùng tên mơ hồ. |
| 3 | Bằng chứng NAT, GLBP failover, DHCP excluded-address | Chưa hoàn tất | Chủ yếu có running-config và cấp phát IP. Chưa có phiên PAT, đo mất gói khi failover, đối chiếu virtual MAC; pool DHCP minh họa vẫn thiếu exclusions và chưa giải thích dự phòng server. |
| 4 | Thêm ít nhất 1–2 kịch bản an ninh | Đáp ứng phần cốt lõi | Có DHCP Snooping, DAI và ACL. DAI có trước–vi phạm–khôi phục cùng Syslog/cảnh báo; ACL có lưu lượng bị chặn và đối chứng được phép. Không còn đúng khi nhận xét rằng báo cáo hoàn toàn thiếu kiểm chứng an ninh. |
| 5 | Tổng quan nghiên cứu, so sánh công cụ, tính mới | Đáp ứng cơ bản | Có mục 1.2, 1.3 và Bảng 2.2. Đóng góp được đặt trong phạm vi tích hợp cho phòng lab. Nên bổ sung nghiên cứu học thuật cụ thể để phần tổng quan vượt khỏi mô tả sản phẩm. |
| 6 | Định lượng và kịch bản lỗi | Chưa đáp ứng đầy đủ | Có bảng ping, bộ đếm DAI và ước tính 52 dòng CLI, nhưng chưa đo CLI/CAMS, Push 1/3/6 thiết bị, thông lượng/parse rate Syslog hoặc các lỗi triển khai. |
| 7 | Use case, sequence, ERD; thống nhất công nghệ | Đáp ứng một phần | Có sequence Syslog và ERD; chưa có hình use case và sequence View & Push. Bảng 3.3 dùng tên bảng không khớp SQL; Bảng 3.4 dùng tên thực tế. Công nghệ đã giới thiệu nhiều hơn nhưng lý do chọn C++ còn sơ lược. |
| 8 | Ảnh dễ đọc, gộp hình trùng | Cải thiện một phần | OSPF đã thay ảnh ghép nhiều terminal bằng ảnh từng router; DAI được cắt vùng. Còn nhiều ảnh khai báo/preview và log lặp. Chương 5 dài 56 trang, có 59 hình. |
| 9 | Ít nhất 15 nguồn, IEEE, viết tắt | Đáp ứng phần lớn | Có 53 tài liệu, RFC/NIST/tài liệu công cụ và sách; danh mục viết tắt mở rộng. Còn “and others” ở [16], [21]; nguồn học thuật về tự động hóa còn ít. |
| 10 | Giảm rào đón, thống nhất thuật ngữ, sửa Bảng 6.1 | Chưa hoàn tất | Một số đoạn mới chặt chẽ hơn, nhưng Bảng 6.1 còn “ba kịch bản”, kết luận bảo vệ dữ liệu thiếu ca thử, Chương 6 còn mô tả mật khẩu rõ và email như việc tương lai. |

## 2. Các phần đã sửa tốt và nên giữ

### 2.1 An ninh mạng đã có bằng chứng thực nghiệm

- **DHCP Snooping (trang 36–40):** đối chiếu hai trạng thái trust và dải IP của client. Báo cáo giới hạn đúng ý nghĩa bộ đếm 160 drop, không gán tất cả cho một server. Điểm còn yếu là một số kết quả binding/trust được mô tả bằng chữ nhiều hơn bằng chứng hiển thị; nếu giữ kết luận đó, nên trích đúng output tương ứng.
- **DAI (trang 41–46):** có binding ban đầu, đổi IP ngoài binding, ping 5/5 → 0/5 → 5/5, bộ đếm 9 ARP bị chặn, bản tin SW_DAI và cảnh báo CAMS. Việc tách số ARP, số dòng log và số gói ping là điểm tốt. Phạm vi được nêu đúng: sai lệch IP–MAC có kiểm soát, không phải chứng minh một cuộc chiếm quyền lưu lượng hoàn chỉnh.
- **ACL (trang 84–90):** có vị trí/chiều áp dụng, ba chính sách từ chối, lưu lượng đối chứng và Bảng 5.15. Phân biệt được việc mất kết nối do ACL với mất kết nối do cấu hình nền. Hình 5.59 cùng bảng ca thử là bằng chứng nên ưu tiên giữ khi thu gọn chương.
- **Syslog/email (trang 70–84):** có bản tin gốc, nguồn, severity, phân tích và minh họa email Error/Warning. Đã vượt mức chỉ thu thập và lọc. Tuy nhiên, đây chưa phải phép đo độ trễ, tỷ lệ gửi email hoặc hiệu năng khi tải cao.

Thầy đưa Port Security như một ví dụ để bổ sung kiểm chứng an ninh. Với các thử hiện có, không cần coi Port Security là điều kiện duy nhất để hoàn thành góp ý. Nếu Bảng 6.1 tuyên bố riêng Port Security đã được kiểm chứng, vẫn cần ca thử tương ứng hoặc ghi “chưa kiểm chứng”.

### 2.2 OSPF mới tốt hơn bài cũ

Mục 5.2.2, trang 47–58, chuyển sang năm router cùng Area 0. Bảng 5.6–5.8 thể hiện địa chỉ, mạng quảng bá và ngoại lệ passive. Mạng quản trị không nằm trong khai báo OSPF; cấu hình minh họa không dùng redistribute. Có running-config, neighbor, route trên R1/R3/R5, sáu phép ping hai chiều và traceroute.

Các điểm tốt:

- Có đối chứng trước/sau khi triển khai định tuyến.
- Không lấy ping giữa hai máy cùng LAN làm bằng chứng OSPF.
- Diễn giải [110/2], [110/4] và next-hop gắn với kết quả hiển thị.
- Traceroute UDP tới VPC10 được giải thích đúng khi nhận ICMP Type 3 Code 3.
- Nêu rõ sáu loạt 5/5 chỉ xác minh các lần thử đã ghi nhận; RTT 593.906 ms không được che đi hoặc dùng làm bằng chứng hiệu năng ổn định.

Các góp ý cũ về cổng R6, route-map cho redistribute, PID nguồn connected và ABR/ASBR của mô hình đa vùng không còn áp dụng trực tiếp cho **bài thực nghiệm mới**. Đây là thay đổi phạm vi kiểm chứng, không phải đã kiểm thử và sửa xong khả năng tái phân phối/OSPF đa vùng của phần mềm. Nếu báo cáo muốn kết luận hỗ trợ các khả năng đó một cách đã kiểm chứng, phải có bài thử riêng.

### 2.3 Hình thức, tổng quan và tài liệu có tiến bộ

Có bìa chính/phụ, “nhóm tác giả” và tên đề tài trong ngoặc kép ở lời cam đoan. Mục lục giới hạn đến cấp 3; tên TÀI LIỆU THAM KHẢO được viết hoa. Tóm tắt đã đồng bộ bài OSPF năm router và có sáu từ khóa.

Chương 2 hiện dài 13 trang, đã mở rộng so với nhận xét bản cũ của thầy. Phần Syslog có bảng tên RFC 5424/từ khóa Cisco IOS, phân biệt PRI với phân hệ Cisco, giải thích cổng 5514 và thời gian nhận/thời gian thiết bị. C++, Alacritty, NTTP/1 và SHA-256 cũng đã được giới thiệu.

## 3. Các vấn đề cần ưu tiên sửa

### 3.1 Chưa có đánh giá định lượng hiệu quả tự động hóa

Vị trí: mục 5.2.2.4 (trang 56–58), mục 5.3 (trang 90), Bảng 1.1 (trang 3).

Bảng 5.10 tính 52 dòng CLI theo mô hình cấu hình tương đương. Cách tính có giải thích và không đánh tráo thành số click hoặc số giây; nên giữ tính trung thực này. Tuy nhiên, nó vẫn là **ước tính quy trình**, không thay thế phép đo mà thầy yêu cầu.

Hiện chưa có bằng chứng xác định:

- CLI và CAMS mất bao nhiêu thời gian cho cùng cấu hình cuối.
- Số thao tác thực tế, số lỗi nhập liệu và tỷ lệ triển khai thành công.
- Push 1/3/6 thiết bị tuần tự và song song.
- Tỷ lệ parse đúng trên tập log có nhãn; thông lượng và số nhận/mất khi bơm tải.
- Ngưỡng 6 thiết bị trong 30 giây và parse ≥99% ở Chương 1 đã đạt hay chưa.

245 bản tin tại một thời điểm không cung cấp mẫu số bản tin gửi, khoảng đo hoặc số parse đúng; không thể suy thành thông lượng hay độ chính xác ≥99%. Ping 5/5 cũng không phải tỷ lệ thành công triển khai của CAMS.

Hai CSV trong `Tai_lieu_lab/LAB2` chưa có số đo điền vào; mẫu vẫn mô tả bài ba router và một số máy/cổng khác với bài năm router đang xuất bản. Cần cập nhật mẫu theo topology hiện tại trước khi đo, tránh ghép dữ liệu hai mô hình.

Đề nghị đo CLI/CAMS lặp tối thiểu 5 lượt mỗi cách như một kế hoạch ban đầu; giữ nguyên trạng thái nền, phạm vi cấu hình, cách đăng nhập và cách gõ/dán CLI. Ghi dữ liệu từng lượt, trung vị/trung bình, khoảng biến động, số lỗi và số thiết bị thành công. Không dùng thời gian giả định để điền kết quả. Đây là đề xuất thiết kế đo, không phải số lần thử đã được thực hiện.

### 3.2 Thiếu negative test của phần mềm

Các thử DAI/ACL chứng minh chính sách chặn vi phạm; chúng không thay thế ca lỗi của quá trình cấu hình.

Cần ít nhất các tình huống: IP/mask không hợp lệ; sai thông tin xác thực; thiết bị mất kết nối giữa Push; IOS từ chối một lệnh. Với mỗi tình huống, lưu đầu vào, kết quả kỳ vọng, phản hồi thực tế, thiết bị gặp lỗi, trạng thái bản ghi và cấu hình thiết bị sau lỗi. Nếu khẳng định bản ghi giữ Pending thì phải có ảnh hoặc truy vấn chứng minh.

Thử quyền/mã hóa cũng chưa có mục thực nghiệm riêng, dù đoạn giới thiệu Chương 5 đang nói sẽ kiểm chứng các nội dung này. Có thể bổ sung ca thử thật, hoặc sửa giới thiệu và kết luận cho đúng phạm vi đã có.

### 3.3 Bảng 3.3 không khớp lược đồ thực tế

Vị trí: mục 3.7, trang 24; `contents/07_phan_tich_thiet_ke.typ`, dòng 128–140.

Bảng 3.3 liệt kê `t02_interfaces`, `t03_routing_ospf`, `t04_acl_rules`, `t05_nat_pat`, `t06_syslog_events`. Không tìm thấy các khai báo tên này trong các tệp SQL hiện tại. Ngay sau đó Bảng 3.4 lại dùng `t02_interface_name`, `t04_ospf_processes`, `t05_extended_acl_rules`, `t05_NAT_DB`, `t12_syslog_messages` và ERD tương ứng.

Nên bỏ Bảng 3.3 hoặc đổi nó thành mô hình khái niệm có nhãn rõ; dùng Bảng 3.4 và Hình 3.4 làm mô tả triển khai. Không trình bày hai bộ tên như cùng là schema thực tế.

**Điểm kiểm tra mới:** đếm khai báo CREATE TABLE trong các tệp SQL hiện tại cho kết quả 93 tên riêng biệt. Vì vậy, con số 93 có căn cứ ở lược đồ nguồn; không nên tiếp tục đánh giá là số không có cơ sở. Cần ghi rõ “93 bảng được khai báo trong lược đồ SQL của phiên bản khảo sát”, phân biệt với số bảng thực tế trong một workspace đã chạy/migration. Chưa mở cơ sở dữ liệu runtime để kiểm đếm.

### 3.4 Chương 6 chưa theo kịp bản sửa

Vị trí: Bảng 6.1 trang 91; mục 6.3–6.4 trang 92–93.

- Bảng 6.1 còn “hoàn thành ba kịch bản”, trong khi Chương 5 có năm kịch bản đánh số.
- Chương 2–3 mô tả mã hóa thông tin xác thực `ENC$v2$`, nhưng 6.3 nói mật khẩu/khóa vẫn lưu trực tiếp và 6.4 lại đưa việc loại mật khẩu rõ thành tương lai. Cần tách rõ phiên bản hiện tại, dữ liệu cũ chưa migration, dự án có/không có mật khẩu và hạn chế khóa/bộ nhớ.
- Bảng 6.1 nói dữ liệu được bảo vệ khi lưu trữ/chia sẻ nhưng chưa có ca mở đúng/sai mật khẩu, sửa bản mã, tráo bản mã giữa host/cột và kiểm tra từ chối.
- Email đã có phần hiện thực và minh chứng nhưng vẫn nằm trong hướng phát triển dưới dạng “gửi cảnh báo qua webhook hoặc email”. Nên đổi sang phần mở rộng cụ thể chưa làm, ví dụ tương quan nâng cao, webhook hoặc đánh giá độ tin cậy gửi thư.
- Cột “Bằng chứng kiểm chứng thực nghiệm” còn nhiều mô tả cơ chế, không có mã ca thử hoặc kết quả đo. SFTP, EIGRP, VTP, đóng gói và các tiện ích chưa có ca riêng cần phân biệt hiện thực với kiểm chứng.

Nên thay mục 5.3/Bảng 6.1 bằng ma trận: **Yêu cầu → tiêu chí → ca thử → bằng chứng → kết quả → Đạt / Đạt một phần / Chưa kiểm chứng**. Chỉ kết luận đạt trên phạm vi và tiêu chí có bằng chứng.

### 3.5 Bài GLBP–DHCP–NAT vẫn chưa đáp ứng góp ý kỹ thuật

Vị trí: mục 5.2.3, trang 58–69; tệp `09_thu_nghiem_danh_gia.typ`.

- **GLBP:** mới chứng minh cấu hình tham gia nhóm. Cần show glbp brief, AVG/AVF và virtual MAC; đối chiếu ARP của ít nhất hai client; gây mất gateway/link và ghi số gói mất, thời gian gián đoạn/phục hồi. Priority/preempt trong running-config không tự chứng minh cân bằng tải hoặc failover.
- **DHCP:** khối cấu hình pool chỉ có network/default-router. Chưa thể hiện excluded-address cho VIP và IP router; thiếu dns-server/lease trong phần minh họa và chưa giải thích DHCP chỉ trên R1. Cần thêm exclusions phù hợp bài thật, xác minh phạm vi cấp phát và chạy lại client. Nếu loại .1–.10 thì kết quả client .4 cũ không còn khớp cấu hình mới.
- **PAT:** chưa có show ip nat translations/statistics khi phát sinh lưu lượng. Cần thể hiện inside local → inside global và giải thích tuyến đi/tuyến về của R1/R2/NAT. Running-config có lệnh overload chưa đủ chứng minh chuyển đổi phiên thực tế.
- **Traceroute:** dòng 223 vẫn suy từ ICMP Destination port unreachable sang “không chứng minh kết nối hoàn chỉnh”. Với traceroute UDP, Type 3 Code 3 có thể là dấu hiệu đã tới host đích. Phải đối chiếu cấu hình upstream/loopback, địa chỉ trả lời và ping 1.1.1.1; không suy thất bại chỉ từ thông báo này. Nguồn kiểm tra: [tài liệu Cisco về traceroute](https://www.cisco.com/c/en/us/support/docs/ip/ip-routed-protocols/22826-traceroute.html).

Đáng chú ý, bài OSPF mới đã giải thích đúng cùng loại phản hồi, còn bài GLBP giữ cách giải thích cũ; cần thống nhất.

### 3.6 Syslog còn một ảnh/đoạn mô tả chưa thống nhất

Vị trí: Hình 5.46, trang 78; `09_thu_nghiem_danh_gia.typ`, dòng 392 trở đi.

- Đoạn văn gọi `LINEPROTO` là “facility” mà chưa ghi “mã phân hệ Cisco”; trong chính ảnh, giao diện đã tách `PRI / Syslog facility = 189 / 23` và `Cisco facility = LINEPROTO`. Nên viết rõ Syslog facility 23 (local7), Cisco facility LINEPROTO, severity 5.
- Ảnh có dấu `*` trước thời gian Cisco nhưng trường `Sequence / Clock` lại hiển thị `104 / synchronized`. Điều này chưa thống nhất với lý thuyết về trạng thái đồng hồ chưa đồng bộ và phần email mới. Cần kiểm tra phiên bản tạo ảnh/logic hiện hành rồi chụp lại hoặc giải thích ảnh cũ; chưa đủ cơ sở từ ảnh để kết luận parser hiện tại vẫn có lỗi.
- Khối được gọi là “Raw message vẫn được giữ nguyên” đã bỏ đoạn `000108:` có trong ảnh. Nếu chủ ý rút gọn thì ghi “trích phần nội dung”; nếu gọi nguyên gốc thì chép đủ, tránh sai khác bằng chứng.

### 3.7 Chưa có hai hình phân tích được yêu cầu

Chương 3 đã có ERD và sequence Syslog. Tuy nhiên:

- Mục 3.1 mới mô tả tác nhân/ca sử dụng bằng chữ; chưa có sơ đồ use case.
- Hình 3.2 là lưu đồ trạng thái, chưa phải sequence View & Push với người dùng, QML/controller, nghiệp vụ, SQLite, executor và thiết bị.

Cần bổ sung hai hình và nhánh lỗi/giữ Pending trong sequence. Có thể giữ lưu đồ hiện tại vì nó trả lời một câu hỏi khác.

## 4. Các chỉnh sửa nhẹ hơn

| Nội dung | Hiện trạng và đề xuất |
|---|---|
| Giới thiệu Chương 5 | Vẫn nói thực nghiệm phân quyền, an toàn mật mã và gọi kịch bản cuối là kiểm thử phân quyền/bảo mật dữ liệu; thực tế kịch bản 5 là ACL. Sửa theo phạm vi thực hoặc bổ sung đúng bài thử. |
| Đánh số kịch bản | Tiêu đề là Kịch bản 3 GLBP nhưng phần mô tả, Hình 5.18 và Bảng 5.11 vẫn gọi Kịch bản 2. Rà cả danh mục hình/bảng. |
| Môi trường đo | “Fedora 44 hoặc Ubuntu 24.04”, “Ryzen 7 hoặc Core i7” là mô tả lựa chọn, không phải cấu hình máy đã dùng. Ghi OS, CPU, RAM, phiên bản và tài nguyên EVE-NG cụ thể của từng phép đo. |
| Mạng quản trị | Vẫn gọi OOB tại 5.1.1. Không nên kết luận kiến trúc OOB chỉ từ việc có subnet quản trị khác. Nêu rõ cách tách đường quản trị/bảng định tuyến; nếu bài hiện chỉ chứng minh subnet riêng thì dùng “mạng quản trị riêng”. |
| Phần mở rộng .ntp | Thêm một câu định nghĩa định dạng gói CAMS và phân biệt với Network Time Protocol. Không cần đổi định dạng chỉ để hoàn thành góp ý nếu giải thích đủ rõ. |
| Lý do dùng C++ | Hiện chủ yếu giải thích tách tiến trình. Nêu thêm yêu cầu kỹ thuật và lý do chọn ngôn ngữ; không khẳng định nhanh hơn Python nếu chưa đo. |
| Văn phong OSPF | Phần so sánh dài khoảng 3 trang, lặp nhiều lần việc chưa đo. Gộp giới hạn thành một đoạn; giữ bảng, định nghĩa phép đếm và lợi ích cụ thể. Có thể thay “thuận tiện hơn” bằng mô tả thao tác mà giao diện hỗ trợ khi chưa khảo sát người dùng. |
| Hạn chế 5.3.2/6.3 | Còn lặp phạm vi hãng và rollback. 5.3.2 nên nêu hạn chế của thực nghiệm: mẫu nhỏ, thiếu đo tải/failover/negative test; 6.3 tổng hợp hạn chế sản phẩm và toàn đề tài. |
| Kiến nghị | Chưa có mục riêng như thầy đề xuất. Có thể thêm điều kiện triển khai, nhu cầu thử nghiệm bổ sung và ưu tiên hoàn thiện. |
| Tóm tắt/Abstract | Có số liệu quan sát và sáu từ khóa; chưa có Abstract tiếng Anh. Bổ sung nếu mẫu Học viện yêu cầu. Nên đưa kết quả DAI/ACL tiêu biểu vào tóm tắt thay vì chỉ nhấn bộ đếm 245 log. |
| Tài liệu tham khảo | Đã đủ số lượng. Sửa [16], [21] “and others”; chuẩn hóa tác giả và thông tin tài liệu web. Nên đối chiếu tài liệu IOS XE 17.14 dùng trong lý thuyết với vIOS-L2/L3 của lab khi nói về hành vi/cú pháp cụ thể. |
| Danh mục viết tắt | Mở rộng tốt; HSRP đã sửa sang dự phòng gateway; .ntp không còn là một mục viết tắt. AAD đứng trước ABR/ACL/AES là đúng ABC, không cần sửa theo nhận xét cũ về điểm này. |

## 5. Bố cục và chất lượng ảnh

Cấu trúc số trang hiện tại:

| Chương | Trang in | Dung lượng |
|---|---|---|
| 1 | 1–4 | 4 trang |
| 2 | 5–17 | 13 trang |
| 3 | 18–25 | 8 trang |
| 4 | 26–34 | 9 trang |
| 5 | 35–90 | 56 trang |
| 6 | 91–93 | 3 trang |

Chương 5 chiếm khoảng 60% phần sáu chương và có 59 hình. Số trang nhiều không tự là lỗi, nhưng phần này vẫn dành nhiều chỗ cho khai báo/preview lặp thay vì bảng kết quả và đánh giá. Nên chuyển chuỗi thao tác NAT, GLBP và Syslog Group sang hướng dẫn hoặc phụ lục; giữ topology, cấu hình trọng tâm, phép đối chứng và kết quả.

Các quan sát hình thức cụ thể:

- Các trang phóng lớn kiểm tra không tái hiện lỗi mất dấu ở tiêu đề/chú thích nghiêng. Chưa tuyên bố mọi glyph trong mọi ảnh đều đã kiểm tra ở kích thước in.
- Hình OSPF 5.14–5.16 đọc được khi phóng lớn, tốt hơn ảnh ghép cũ; vẫn có thể bỏ phần legend dài của show ip route và trích dòng quan trọng để giảm dung lượng.
- Hình log nhiều dòng 5.47–5.50 và bảng System Logs 5.59 cần cắt/trích nội dung cần đối chiếu để đọc thuận tiện trên bản in.
- Trang 56 giãn rất rộng dòng “Ở hop cuối, chính VPC10 trả về” vì cụm inline code dài không ngắt dòng. Nên đưa phản hồi ICMP vào khối riêng hoặc cho ngắt hợp lý.
- Danh mục viết tắt chiếm bốn trang, trang cuối chỉ có YANG. Có thể tinh chỉnh khoảng cách/cỡ chữ hợp lý để tránh trang gần trống.

## 6. Thứ tự hoàn thiện đề nghị

1. **Sửa tính nhất quán ngay:** Bảng 3.3; mô tả mã hóa/email và số kịch bản ở Chương 6; giới thiệu Chương 5; số kịch bản GLBP; đoạn Syslog/clock/raw message; diễn giải traceroute GLBP.
2. **Bổ sung số đo và thử lỗi:** CLI/CAMS cùng bài OSPF, Push theo quy mô, Syslog có tập nhãn/tải, các ca lỗi đầu vào/kết nối/IOS. Ghi dữ liệu gốc và điều kiện đo.
3. **Hoàn thiện lab GLBP–DHCP–PAT:** exclusions và phạm vi dự phòng DHCP; bảng NAT; virtual MAC và failover đo được. Cập nhật ảnh/client sau mỗi đổi cấu hình.
4. **Viết ma trận yêu cầu và kết luận:** cho từng mục tiêu/yêu cầu chức năng/phi chức năng trạng thái đạt, một phần hoặc chưa kiểm chứng, kèm mã ca thử và nguồn bằng chứng. Các ngưỡng 30 giây/99% cần trạng thái riêng.
5. **Bổ sung hình và biên tập:** use case, sequence View & Push; thu gọn ảnh lặp, chuẩn hóa thuật ngữ/tài liệu, thêm kiến nghị/Abstract theo mẫu.

## 7. Khác biệt cần lưu ý so với bản đối chiếu ngày 05/10

- Không tiếp tục coi lỗi R6/redistribute/ABR-ASBR của topology cũ là lỗi của bài OSPF năm router hiện tại.
- Bài OSPF mới đã có bảng mạng đủ năm router, preview, ping hai chiều và giải thích traceroute; các nhận xét cũ về bảng Area thiếu số/tên và TTL của bài cũ không còn đúng tại phần này.
- Hình 5.17 hiện là ping VPC8–VPC10, không phải ảnh ghép sáu terminal như mô tả trong đánh giá cũ.
- Đếm SQL xác nhận 93 khai báo tên bảng riêng biệt; cần ghi phạm vi đếm, không gọi con số này là vô căn cứ.
- AAD đứng trước ABR là đúng ABC.
- Những vấn đề định lượng, GLBP/DHCP/PAT, Bảng 3.3, Chương 6 và thiếu use case/sequence View & Push vẫn còn.

Đánh giá này phản ánh báo cáo và bằng chứng được lưu tại thời điểm kiểm tra. Một chức năng đã có mã nguồn nhưng chưa có ca thực nghiệm trong báo cáo được xem là “đã hiện thực, chưa đủ bằng chứng kiểm chứng”, không tự suy thành chức năng không hoạt động.
