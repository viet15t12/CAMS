# Câu hỏi dự phòng cho phần phản biện CAMS

Tài liệu bổ sung 40 câu từ câu 29 đến câu 68, dùng cùng bản kịch bản 45 slide đã có 28 câu đầu. Nội dung bám các luồng CAMS và bốn lab trên slide của nhóm; không bổ sung số đo hay kết quả thử nghiệm mới.

## Cách ôn trước buổi trình bày

Tập các câu có ghi Ưu tiên tập trước. Mỗi câu trả lời là một mẫu nói ngắn; hiểu ý rồi diễn đạt tự nhiên. Phần Gợi ý đối chiếu dành cho người tập, không đọc thành tiếng. Với câu về xử lý lỗi, triển khai thực tế hoặc phép đo mới, nói rõ đây là cách cần làm hoặc kế hoạch, chưa phải chức năng đã được chứng minh.

Ưu tiên nhanh trong bộ bổ sung: câu 29, 32, 34, 35, 40, 41, 44, 54, 59, 63, 64 và 68. Bộ này bổ sung chiều sâu cho bản chính; vẫn cần ôn các câu đầu về tính mới, DAI, rollback, bảo vệ thông tin xác thực và đóng góp cá nhân.

## Mục tiêu nghiên cứu và giá trị sử dụng

### Câu 29 Nếu chưa đo thời gian thì dựa vào đâu nói CAMS tiện hơn CLI?

Trả lời: Dạ, nhóm đánh giá sự thuận tiện qua cách tổ chức thao tác: chọn thiết bị trong cùng giao diện, nhập dữ liệu có cấu trúc, xem trước lệnh và theo dõi kết quả theo thiết bị. Đây là nhận xét về quy trình và giao diện, chưa phải kết luận CAMS nhanh hơn bao nhiêu phần trăm hoặc phù hợp hơn với mọi người dùng.

Gợi ý đối chiếu: Ưu tiên tập. Chỉ slide 4, 16, 19. Không dùng số click hoặc thời gian ước tính làm kết quả đo thực nghiệm.

### Câu 30 Nếu muốn so sánh công bằng với CLI thì nhóm sẽ thiết kế phép đo thế nào?

Trả lời: Dạ, hai cách phải thực hiện cùng nhiệm vụ, trên cùng cấu hình ban đầu và cùng tiêu chí hoàn thành. Nhóm sẽ định nghĩa thời điểm bắt đầu, kết thúc, ghi màn hình và nhật ký, lặp lại phép thử rồi báo cáo thời gian cùng lỗi thao tác. Cần kiểm soát mức quen thuộc của người thực hiện và đổi thứ tự thử để hạn chế ảnh hưởng của việc học.

Gợi ý đối chiếu: Đây là kế hoạch đánh giá, chưa phải phép thử đã làm. Phân biệt thời gian cấu hình với thời gian chờ giao thức hội tụ.

### Câu 31 Vì sao chọn bốn lab này, chúng đại diện được cho cả hệ thống không?

Trả lời: Dạ, bốn lab minh họa bốn nhu cầu: kiểm soát DHCP và ARP, triển khai định tuyến theo nhóm, thu thập sự kiện và cảnh báo, cùng kiểm soát lưu lượng bằng ACL. Chúng giúp kiểm chứng các luồng chính đã trình bày. Nhóm chưa dùng bốn lab để khẳng định tất cả chức năng hoặc mọi tổ hợp cấu hình đều đúng.

Gợi ý đối chiếu: Slide 21–42. Khi hỏi chức năng ngoài bốn lab, nêu đúng bằng chứng riêng nếu có; không suy từ OSPF sang BGP hay mọi giao thức khác.

### Câu 32 Nhóm gọi đây là kiểm thử hay đánh giá hiệu năng?

Trả lời: Dạ, phần demo hiện tại chủ yếu là kiểm chứng chức năng và đối chiếu hành vi thiết bị với chính sách cấu hình. Đánh giá hiệu năng cần số đo như thời gian, tải, độ trễ và tỷ lệ thành công qua nhiều lần chạy. Nhóm chưa có đủ dữ liệu để kết luận về những chỉ tiêu đó.

Gợi ý đối chiếu: Ưu tiên tập. Thành công 5 gói ping trong một cảnh không phải tỷ lệ thành công của toàn bộ CAMS.

### Câu 33 Ai là người dùng phù hợp nhất và khi nào nên dùng CLI?

Trả lời: Dạ, CAMS hướng tới người cần quản lý tập trung và thực hiện các tác vụ nằm trong phạm vi giao diện đã hỗ trợ. CLI vẫn cần cho chẩn đoán sâu, cú pháp đặc biệt và chức năng chưa có trên app. Giá trị của CAMS là giảm việc chuyển phiên và tổ chức quy trình quen thuộc; lựa chọn công cụ còn phụ thuộc nhiệm vụ và kinh nghiệm người vận hành.

Gợi ý đối chiếu: Không khẳng định GUI luôn tốt hơn CLI, cũng không khẳng định người mới có thể cấu hình an toàn mà không hiểu mạng.

## Kiến trúc và tính nhất quán của dữ liệu

### Câu 34 Lưu trên giao diện, Push và lưu startup config có giống nhau không?

Trả lời: Dạ, đây là các bước khác nhau. Lưu dữ liệu trên app là lưu ý định cấu hình. Push là gửi lệnh tới thiết bị và có thể thay đổi running config. Việc cấu hình tồn tại sau khi khởi động lại còn phụ thuộc bước lưu trên thiết bị. Nhóm phải kiểm tra luồng thực tế, không coi thông báo lưu trên app là bằng chứng startup config đã được cập nhật.

Gợi ý đối chiếu: Ưu tiên tập. Khi được hỏi app có tự lưu startup không, chỉ trả lời theo mã nguồn hoặc clip đã kiểm tra; không mặc định có.

### Câu 35 Nếu một người sửa bằng CLI sau khi CAMS đã thu thập thì dữ liệu nào đúng?

Trả lời: Dạ, dữ liệu thu thập là trạng thái tại thời điểm lấy về, còn running config có thể đã thay đổi sau đó. Trước khi triển khai tiếp cần thu thập lại, so sánh và kiểm tra phần sẽ sửa. Nhóm chưa chứng minh cơ chế tự phát hiện mọi thay đổi tức thời hoặc xử lý mọi xung đột giữa nhiều người quản trị.

Gợi ý đối chiếu: Ưu tiên tập. Slide 10–12, 18. Phân biệt trạng thái mong muốn, trạng thái quan sát và trạng thái đang chạy.

### Câu 36 Thu thập running config thành công có nghĩa mọi tính năng đều lên app đúng không?

Trả lời: Dạ, chưa đủ. Sau khi lấy cấu hình còn có bước phân tích cú pháp, ánh xạ vào dữ liệu và hiển thị. Một định dạng chưa được parser hỗ trợ có thể vẫn xuất hiện trong file cấu hình nhưng không hiện đúng trong giao diện. Vì vậy nhóm đối chiếu cả cấu hình nguồn và các lệnh show phù hợp, thay vì chỉ dựa vào trạng thái tải thành công.

Gợi ý đối chiếu: Câu hỏi tiếp nối câu 26 trong bản chính: tập trung vào cách xác minh chung, không chỉ sự cố ACL.

### Câu 37 Chia hai cơ sở dữ liệu thì làm sao tránh dữ liệu lệch nhau?

Trả lời: Dạ, việc chia dữ liệu giúp tách vai trò lưu thông tin quản lý và dữ liệu thu thập, nhưng bản thân nó không bảo đảm đồng bộ. Cần xác định nguồn của từng trường, thời điểm cập nhật và đối chiếu sau triển khai. Một số dữ liệu thu thập còn được ánh xạ trở lại bảng phục vụ cấu hình, nên nhóm không coi hai cơ sở dữ liệu là hai vùng hoàn toàn độc lập.

Gợi ý đối chiếu: Slide 15. Không nói device_network chỉ chứa desired state trong mọi trường hợp; luồng đồng bộ còn ghi dữ liệu thiết bị vào các bảng nghiệp vụ.

### Câu 38 Tại sao cần Worker khi đã có giao diện đồ họa?

Trả lời: Dạ, kết nối và thu thập qua mạng có thể phải chờ phản hồi. Worker tách phần việc này khỏi luồng giao diện để giao diện tiếp tục phản hồi và hiển thị tiến trình. Cách tổ chức này hỗ trợ trải nghiệm sử dụng, nhưng không tự làm thiết bị phản hồi nhanh hơn và không chứng minh hệ thống chịu được tải lớn.

Gợi ý đối chiếu: Slide 14, 19. Nếu hỏi tốc độ tối đa, trả lời chưa benchmark.

### Câu 39 Khóa theo host có ngăn được hai người quản trị cùng sửa thiết bị không?

Trả lời: Dạ, khóa theo host giúp điều phối các tác vụ dùng chung thiết bị trong phạm vi cơ chế khóa của ứng dụng. Nó không tự ngăn một người ở máy khác hoặc phiên CLI ngoài CAMS thay đổi cấu hình. Muốn kiểm soát nhiều người vận hành cần thêm phân quyền và cơ chế phối hợp, là phần nhóm chưa chứng minh trong demo.

Gợi ý đối chiếu: Ưu tiên tập. Không gọi HostLock là khóa phân tán hoặc cơ chế kiểm soát truy cập trên thiết bị.

### Câu 40 Mất kết nối giữa lúc Push thì có thể kết luận thiết bị chưa đổi gì không?

Trả lời: Dạ, không thể. Một số lệnh có thể đã thực hiện trước khi kết nối bị mất, thậm chí lệnh cuối đã chạy nhưng app chưa nhận phản hồi. Cách xử lý là kết nối lại, lấy cấu hình và kiểm tra trạng thái thực tế trước khi quyết định gửi tiếp hoặc khôi phục. Không nên nhấn Push lặp lại chỉ vì app báo lỗi.

Gợi ý đối chiếu: Ưu tiên tập. Đây là cách xử lý cần áp dụng, không phải tuyên bố CAMS hiện đã tự phục hồi mọi tình huống.

### Câu 41 Push cùng một cấu hình hai lần có bảo đảm không tạo thay đổi ngoài ý muốn không?

Trả lời: Dạ, phải kiểm tra theo từng tính năng. Có lệnh đặt lại cùng một giá trị, nhưng cũng có thao tác thêm luật, tạo đối tượng hoặc thay đổi thứ tự cần xử lý riêng. Nhóm chưa chứng minh mọi mẫu lệnh đều có tính lặp lại an toàn. Phép thử phù hợp là Push lần hai rồi so sánh cấu hình và hành vi, không chỉ nhìn thông báo thành công.

Gợi ý đối chiếu: Ưu tiên tập. Không dùng từ idempotent cho toàn hệ thống khi chưa có bằng chứng cho từng luồng.

### Câu 42 Snapshot có thể thay thế rollback tự động không?

Trả lời: Dạ, snapshot cung cấp cấu hình ở một thời điểm để đối chiếu và hỗ trợ khôi phục. Rollback còn cần quy trình áp dụng lại, giữ kết nối và xác minh sau phục hồi. Do đó có snapshot không đồng nghĩa CAMS đã rollback tự động hoặc khôi phục đồng thời toàn bộ nhóm thiết bị.

Gợi ý đối chiếu: Slide 18. Đừng nhầm file backup với giao dịch nguyên tử trên nhiều router.

### Câu 43 Có xem trước lệnh rồi thì còn rủi ro nhập sai không?

Trả lời: Dạ, vẫn còn. Kiểm tra định dạng có thể phát hiện địa chỉ hoặc giá trị không hợp lệ, nhưng một địa chỉ đúng định dạng vẫn có thể sai với thiết kế mạng. Preview giúp người vận hành kiểm duyệt lệnh; sau đó vẫn cần xác minh trạng thái và lưu lượng. Nhóm không coi preview là chứng minh cấu hình chắc chắn an toàn.

Gợi ý đối chiếu: Slide 11, 16. Ví dụ mạng được khai báo đúng cú pháp nhưng nhầm subnet hoặc nhầm cổng áp dụng.

## Lab 1 về DHCP Snooping và DAI

### Câu 44 DHCP Snooping trust có tự làm cho cổng được DAI trust không?

Trả lời: Dạ, không. DHCP Snooping kiểm soát bản tin DHCP, còn DAI kiểm tra ARP; hai trạng thái trust được cấu hình riêng. Trong lab, cổng nối máy khách giữ untrusted, còn cổng nối phía tin cậy được thiết lập theo từng cơ chế. Nhóm cần chỉ ra cả cấu hình DHCP Snooping và DAI trên cổng, không suy từ một trạng thái sang trạng thái còn lại.

Gợi ý đối chiếu: Ưu tiên tập. Slide 22 và 25. Chỉ rõ lệnh ip dhcp snooping trust khác ip arp inspection trust.

### Câu 45 Máy dùng IP tĩnh hợp lệ có bị DAI chặn không?

Trả lời: Dạ, có thể nếu cổng untrusted không có thông tin đối chiếu phù hợp cho ARP của máy. Với máy IP tĩnh phải thiết kế cơ chế xác thực phù hợp với nền tảng, chẳng hạn ARP ACL được hỗ trợ, rồi kiểm chứng. Không nên giải quyết bằng cách trust toàn bộ cổng người dùng, vì sẽ bỏ qua kiểm tra DAI tại đó.

Gợi ý đối chiếu: Trong demo, đổi sang IP tĩnh sai với binding dùng để tạo sai lệch; không kết luận mọi máy IP tĩnh đều là tấn công.

### Câu 46 Binding DHCP có còn sau khi switch khởi động lại không?

Trả lời: Dạ, không được mặc định là còn. Khả năng lưu và khôi phục binding phụ thuộc cấu hình cơ sở dữ liệu binding và nền tảng sử dụng. Sau khởi động lại cần kiểm tra bảng binding trước khi kết luận DAI hoạt động bình thường. Lab hiện tại chưa chứng minh khả năng duy trì binding qua reboot.

Gợi ý đối chiếu: Không khẳng định đã cấu hình database agent hoặc đã thử reboot nếu chưa có ảnh hay nhật ký.

### Câu 47 Nếu đặt nhầm cổng DHCP giả thành trusted thì chuyện gì xảy ra?

Trả lời: Dạ, bản tin máy chủ DHCP đi vào cổng đó có thể được phép qua theo chính sách trust. DHCP Snooping phụ thuộc việc xác định đúng cổng và nguồn tin cậy, chứ không tự biết thiết bị nào là máy chủ hợp lệ trong mọi trường hợp. Lab đổi trust nhằm thể hiện tác động của chính sách, không phải khuyến nghị trust máy chủ giả.

Gợi ý đối chiếu: Slide 22–23. Khi nói phần này, nhấn mạnh đây là phép thử có kiểm soát.

### Câu 48 DAI có chặn mọi cuộc tấn công trong mạng LAN không?

Trả lời: Dạ, không. DAI tập trung kiểm tra ARP theo chính sách và dữ liệu đối chiếu. Nó không thay thế kiểm soát dịch vụ, phân quyền hay các biện pháp phòng vệ khác. Bằng chứng của nhóm chỉ xác nhận ARP sai lệch bị chặn trong điều kiện lab và kết nối phục hồi khi cấu hình máy khách hợp lệ.

Gợi ý đối chiếu: Tránh mở rộng kết quả thành chống mọi MITM, chống IPv6 hoặc bảo vệ toàn diện mạng LAN.

## Lab 2 về OSPF

### Câu 49 Tại sao khai báo LAN vào OSPF nhưng lại để cổng đó passive?

Trả lời: Dạ, LAN vẫn cần được quảng bá để các router khác biết đường tới máy trạm. Passive trên cổng LAN ngừng gửi Hello và không hình thành láng giềng OSPF tại đó, nhưng mạng kết nối vẫn có thể được quảng bá theo cấu hình. Các cổng nối router với router phải được mở phù hợp để hình thành láng giềng.

Gợi ý đối chiếu: Slide 30–32. Phân biệt quảng bá mạng với hình thành adjacency.

### Câu 50 Process ID OSPF có bắt buộc giống nhau trên cả năm router không?

Trả lời: Dạ, process ID có ý nghĩa cục bộ trên từng router, không phải điều kiện bắt buộc giống nhau giữa các router. Nhóm dùng cùng một số để quản lý dễ hơn. Việc hình thành láng giềng còn phụ thuộc các tham số tương thích trên liên kết, như area, timer và xác thực nếu bật.

Gợi ý đối chiếu: Đừng nhầm process ID với area ID hoặc router ID.

### Câu 51 Hai router có cùng router ID thì ảnh hưởng gì?

Trả lời: Dạ, router ID cần duy nhất trong miền OSPF. Trùng router ID có thể làm hoạt động láng giềng và xử lý thông tin định tuyến gặp vấn đề. Nhóm dùng địa chỉ nhận diện khác nhau cho từng router và cần kiểm tra router ID thực tế bằng lệnh show, vì chỉ tạo loopback chưa chắc thay đổi ngay ID của tiến trình đang chạy.

Gợi ý đối chiếu: Không tuyên bố sự cố trùng ID đã được thực nghiệm trong lab hiện tại.

### Câu 52 Lệnh network trong OSPF có tạo địa chỉ IP cho cổng không?

Trả lời: Dạ, không. Địa chỉ IP và trạng thái cổng phải được cấu hình riêng. Lệnh network chọn các cổng theo địa chỉ và wildcard để đưa vào tiến trình, area tương ứng. Nhóm tách bước cấu hình IP với bước triển khai OSPF, rồi xác minh neighbor, route và lưu lượng.

Gợi ý đối chiếu: Slide 30–33. Đây là câu phân biệt cấu hình nền với cấu hình giao thức.

### Câu 53 Nhìn thấy route OSPF đã đủ kết luận hai máy liên lạc được chưa?

Trả lời: Dạ, chưa đủ. Tuyến chỉ chứng minh router có thông tin chuyển tiếp theo bảng định tuyến tại thời điểm kiểm tra. Liên lạc còn phụ thuộc đường về, gateway máy trạm và chính sách lọc. Vì vậy nhóm bổ sung ping và trace giữa các máy, thay vì chỉ đưa ảnh show ip route.

Gợi ý đối chiếu: Slide 32–33. Không dùng một ảnh route để khẳng định toàn bộ các cặp máy đã được thử.

## Lab 3 về Syslog và cảnh báo

### Câu 54 UDP Syslog có bảo đảm mọi bản tin đều đến không?

Trả lời: Dạ, UDP không có cơ chế xác nhận và truyền lại ở tầng vận chuyển. Lab chứng minh CAMS nhận được các bản tin đã tạo trong cảnh quay, chưa chứng minh không mất log khi nghẽn hoặc tải cao. Nếu cần độ tin cậy cao hơn phải đánh giá giải pháp vận chuyển phù hợp và khả năng hỗ trợ của nguồn gửi.

Gợi ý đối chiếu: Ưu tiên tập. Không khẳng định CAMS hiện hỗ trợ TCP hoặc TLS Syslog nếu chưa kiểm tra triển khai.

### Câu 55 Máy lạ có thể gửi Syslog giả tới CAMS không?

Trả lời: Dạ, nếu nguồn gửi không được xác thực và luồng UDP tới bộ thu được cho phép thì có nguy cơ nhận bản tin giả. Việc nhìn thấy IP nguồn không đủ để xác nhận nội dung là thật. Cần hạn chế nguồn gửi, bảo vệ mạng quản trị và cân nhắc cơ chế xác thực phù hợp. Demo hiện chưa chứng minh khả năng chống giả mạo Syslog.

Gợi ý đối chiếu: Không nói bộ thu hiện đã có whitelist hoặc xác thực chỉ vì đây là biện pháp nên bổ sung.

### Câu 56 Đồng hồ các máy lệch nhau thì xếp thứ tự sự kiện thế nào?

Trả lời: Dạ, phải phân biệt thời gian thiết bị ghi trong bản tin và thời gian CAMS tiếp nhận. Nếu chưa đồng bộ thì không thể suy ra độ trễ chính xác hoặc thứ tự tuyệt đối giữa nhiều nguồn. Nhóm cần đồng bộ thời gian và ghi rõ trường thời gian dùng khi đánh giá; ảnh hiện tại chủ yếu chứng minh chuỗi chức năng.

Gợi ý đối chiếu: Không lấy chênh lệch giờ trong ảnh Syslog và email làm độ trễ đã đo.

### Câu 57 Severity cao có đồng nghĩa sự kiện nguy hiểm hơn cho hệ thống không?

Trả lời: Dạ, severity là mức do nguồn log cung cấp, còn mức ảnh hưởng thực tế phụ thuộc ngữ cảnh. Một cổng down có thể là lỗi nghiêm trọng hoặc chỉ là thao tác kiểm thử. Nhóm dùng severity để lọc và ưu tiên quan sát, chưa dùng nó làm kết luận tự động rằng có tấn công.

Gợi ý đối chiếu: Nhớ số severity càng nhỏ càng nghiêm trọng. Cần kết hợp nguồn, nội dung và bối cảnh.

### Câu 58 Nếu email không gửi được thì có nghĩa thiết bị không phát log không?

Trả lời: Dạ, không thể suy như vậy. Chuỗi gồm thiết bị phát, CAMS nhận, điều kiện cảnh báo được khớp và dịch vụ email gửi thành công. Khi email thiếu cần kiểm tra lần lượt từng bước, cùng ngưỡng severity và thời gian hạn chế gửi lặp. Lab hiện có bằng chứng email nhận được trong các tình huống minh họa, chưa bao phủ mọi lỗi SMTP.

Gợi ý đối chiếu: Slide 35–37. Không coi cooldown là mất log; cũng không mặc định mọi log đều phải sinh email.

## Lab 4 về ACL

### Câu 59 Đổi vị trí hai dòng deny và permit thì có ảnh hưởng không?

Trả lời: Dạ, ACL được xét theo thứ tự và dừng tại luật đầu tiên khớp. Nếu đặt permit ip any any lên trước thì các deny phía sau không còn được xét cho lưu lượng IP đó. Vì vậy nhóm phải kiểm tra cả nội dung luật lẫn sequence, không chỉ xem danh sách có đủ chữ deny hay permit.

Gợi ý đối chiếu: Ưu tiên tập. Slide 39. Có thể minh họa bằng hai dòng deny cụ thể và permit toàn bộ.

### Câu 60 Có ACL trong running config nhưng chưa binding thì có chặn được lưu lượng này không?

Trả lời: Dạ, chỉ tạo ACL chưa đủ. ACL phải được tham chiếu vào đúng cơ chế áp dụng; trong lab này là gắn vào interface theo chiều phù hợp. Vì vậy nhóm trình bày cả danh sách luật và binding, rồi tạo lưu lượng đối chứng.

Gợi ý đối chiếu: Slide 39–40. ACL có thể được tham chiếu vào chức năng khác; không khẳng định mọi ACL chỉ hoạt động qua ip access-group.

### Câu 61 IN và OUT được tính theo phía người dùng hay theo router?

Trả lời: Dạ, theo chiều gói tin qua interface của router. IN là gói đi vào interface, OUT là gói đi ra interface. Trong lab, lưu lượng từ VLAN người dùng vào R1 nên áp dụng IN trên subinterface tương ứng, bất kể tên ACL có chữ OUT hay không.

Gợi ý đối chiếu: Nếu bị hỏi tiếp, dùng mũi tên PC → cổng VLAN của R1 → phía mạng đích để giải thích.

### Câu 62 Permit ip any any có khiến luật chặn phía trên mất tác dụng không?

Trả lời: Dạ, không. Gói khớp deny phía trên đã bị xử lý và không xuống permit phía sau. Permit ip any any chỉ cho phép những gói còn lại trong phạm vi ACL này. Nó cũng không bảo đảm dịch vụ truy cập được, vì vẫn còn định tuyến và các cơ chế khác trên đường đi.

Gợi ý đối chiếu: Đừng diễn đạt permit any là mọi lưu lượng đều được cho qua bất kể luật trước đó.

### Câu 63 Probe TCP cổng 80 có chứng minh web hoạt động đầy đủ không?

Trả lời: Dạ, chưa đủ. Probe đó giúp kiểm tra hành vi đối với lưu lượng TCP và cổng đích tương ứng, nhưng không chứng minh tải trang hay nội dung HTTP thành công. Nếu kết luận truy cập web hoàn chỉnh thì phải bổ sung máy khách HTTP và bằng chứng phản hồi ứng dụng. Trong demo nhóm giới hạn kết luận ở phép thử đã thực hiện.

Gợi ý đối chiếu: Ưu tiên tập. Tương tự, thử cổng 23 chưa phải bằng chứng đăng nhập Telnet thành công.

### Câu 64 Vì sao có luật log mà CAMS vẫn có thể không nhận được log ACL?

Trả lời: Dạ, còn phụ thuộc gói có thực sự khớp luật đó, cấu hình Syslog, mức trap và đường truyền tới bộ thu. Log ACL trong tình huống IOS này ở mức informational 6, nên ngưỡng chỉ tới notifications 5 sẽ không chuyển tiếp bản tin mức 6. Cũng không mặc định một gói tương ứng một bản tin riêng vì thiết bị có thể tổng hợp hoặc hạn chế log.

Gợi ý đối chiếu: Ưu tiên tập. Lab Syslog và lab ACL có thể dùng ngưỡng khác nhau. Không nói cứ thêm log là CAMS tự có cảnh báo.

## Triển khai thực tế và câu hỏi kết thúc

### Câu 65 Nếu app bị tắt thì OSPF và ACL trên router có ngừng hoạt động không?

Trả lời: Dạ, cấu hình đã áp dụng trên thiết bị vẫn được thiết bị thực thi theo trạng thái của nó. CAMS không phải thành phần chuyển tiếp gói hay tiến trình OSPF của router. Tuy nhiên, khi app hoặc dịch vụ liên quan ngừng thì việc thu thập, hiển thị và cảnh báo phụ thuộc vào thành phần đó có thể bị gián đoạn.

Gợi ý đối chiếu: Phân biệt mặt phẳng quản trị của CAMS với hoạt động chuyển tiếp và giao thức trên thiết bị.

### Câu 66 Có thể đưa thẳng sản phẩm này vào mạng doanh nghiệp không?

Trả lời: Dạ, kết quả hiện tại hỗ trợ đánh giá nguyên mẫu trong phạm vi đã thử. Trước khi triển khai cần kiểm tra trên thiết bị và phiên bản thực tế, sao lưu, quyền truy cập, khả năng phục hồi cùng tải vận hành. Nhóm chưa tuyên bố sản phẩm đã đạt điều kiện thay thế một hệ thống quản trị doanh nghiệp.

Gợi ý đối chiếu: Ưu tiên tập. Không biến hướng phát triển thành tính năng đã hoàn thành.

### Câu 67 Nếu chỉ được chọn một việc làm tiếp thì nhóm ưu tiên gì?

Trả lời: Dạ, nhóm sẽ ưu tiên làm chắc chuỗi triển khai và xác minh: kiểm tra dữ liệu trước Push, đối chiếu cấu hình sau Push và xử lý lỗi có kiểm soát. Điều này trực tiếp giảm nguy cơ app báo một trạng thái nhưng thiết bị đang ở trạng thái khác. Sau đó mới mở rộng phạm vi thiết bị và các chức năng mới.

Gợi ý đối chiếu: Đây là lựa chọn ưu tiên đề xuất khi phản biện, không phải cam kết đã hoàn thành hay quyết định chung nếu nhóm chưa thống nhất.

### Câu 68 Hội đồng bảo đề tài nhiều chức năng nhưng chưa kiểm chứng sâu thì trả lời sao?

Trả lời: Dạ, nhóm tiếp thu nhận xét này. Phần trình bày tập trung vào bốn chuỗi bằng chứng có trong lab, còn danh sách tính năng thể hiện phạm vi phần mềm đã xây dựng, không đồng nghĩa mọi tính năng được đánh giá sâu ngang nhau. Nhóm sẽ làm rõ ranh giới đó và ưu tiên bổ sung phép thử lỗi, lặp lại và số đo cho các luồng chính.

Gợi ý đối chiếu: Ưu tiên tập. Không tranh luận rằng nhiều ảnh là đủ cho mọi kết luận; chỉ rõ phần đã có và phần chưa có.

## Cách trả lời khi bị hỏi liên tiếp

Dừng một nhịp để xác định ý chính, trả lời kết luận trước rồi chỉ bằng chứng. Nếu thầy hỏi thêm, đi vào điều kiện hoặc giới hạn của kết luận đó. Không dùng câu giới hạn để né câu hỏi: sau khi nói chưa đo hoặc chưa thử, chỉ rõ nhóm đã kiểm chứng phần nào.

Khi câu hỏi chứa một kết luận sai, có thể nói: “Dạ, em xin làm rõ điểm này: …” rồi giải thích bằng cấu hình hoặc đường đi gói tin. Khi nhận xét đúng, nói: “Dạ, nhận xét đó đúng với giới hạn hiện tại; phần nhóm đã có bằng chứng là …”.

Nếu bị yêu cầu một con số chưa có, nói: “Nhóm chưa có số đo tái lập cho chỉ tiêu này, nên em chưa đưa ra con số. Để đánh giá, nhóm cần thực hiện phép thử …”. Nếu bị hỏi tính năng chưa xác minh trong mã nguồn, không đoán rằng hệ thống đã hỗ trợ.

## Ghi chú về bằng chứng

Số slide theo bản CAMS 45 trang nhóm cung cấp. Các câu về thử lặp, lỗi giữa chừng, reboot, tải, xác thực Syslog và triển khai doanh nghiệp là câu hỏi dự phòng; tài liệu không xác nhận nhóm đã thực hiện các phép thử đó. Video chưa được kiểm tra trong lần bổ sung này. Khi clip mới khác ảnh slide, dùng cấu hình và kết quả thực tế trong clip để trả lời.
