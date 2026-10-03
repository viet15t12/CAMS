# QUY TẮC VĂN PHONG VÀ CÁCH XƯNG HÔ TRONG BÁO CÁO

## 1. Mục đích và phạm vi áp dụng

Tài liệu này thống nhất cách viết cho toàn bộ báo cáo nghiên cứu về CAMS, gồm phần mở đầu, các chương nội dung, chú thích hình và bảng, kết luận, phụ lục và tài liệu hướng dẫn đi kèm.

Mục tiêu là tạo văn phong khoa học, mạch lạc, nhất quán; ưu tiên tiếng Việt; phân biệt rõ kết quả đã kiểm chứng với nhận định, kế hoạch hoặc hướng phát triển.

## 2. Cách xưng hô

### 2.1. Nguyên tắc chung

- Ưu tiên lối viết khách quan với chủ thể cụ thể: **đề tài**, **nghiên cứu**, **hệ thống**, **phần mềm CAMS**, **kết quả thử nghiệm**, **người quản trị** hoặc tên phân hệ.
- Chỉ dùng **nhóm tác giả** khi cần nói đến hành động hoặc quyết định của những người thực hiện mà không thể thay bằng chủ thể khách quan.
- Không dùng xen kẽ các cách xưng hô **chúng tôi**, **nhóm**, **nhóm nghiên cứu** và **nhóm tác giả**. Cách gọi thống nhất là **nhóm tác giả**.
- Không dùng đại từ ngôi thứ nhất số ít như **tôi**, **em** trong báo cáo.

### 2.2. Cách viết ưu tiên

| Trường hợp | Cách viết ưu tiên | Cách viết cần tránh |
|---|---|---|
| Mô tả chức năng | “CAMS lưu kết quả theo từng thiết bị.” | “Chúng tôi cho CAMS lưu kết quả.” |
| Mô tả phương pháp | “Nghiên cứu sử dụng mô hình quản lý theo trạng thái.” | “Nhóm em sử dụng mô hình…” |
| Nêu phạm vi | “Đề tài tập trung vào thiết bị Cisco IOS.” | “Bọn em chỉ làm Cisco IOS.” |
| Nêu quyết định của tác giả | “Nhóm tác giả lựa chọn cổng 5514 để tiến trình không cần quyền quản trị.” | “Chúng tôi chọn port 5514 cho dễ chạy.” |
| Nêu kết quả | “Kết quả thử nghiệm cho thấy…” | “Nhóm tác giả thấy rằng…” |

## 3. Giọng văn khoa học

- Viết câu ngắn, mỗi câu tập trung vào một ý chính. Khi một câu có quá ba mệnh đề, nên tách thành hai câu.
- Nêu chủ thể và hành động rõ ràng. Tránh các câu không xác định như “có thể thấy rằng”, “như đã biết”, “rõ ràng là” hoặc “về cơ bản”.
- Dùng quan hệ lập luận trực tiếp: nguyên nhân, cách thực hiện, kết quả và giới hạn.
- Không dùng từ cường điệu như **tuyệt đối**, **hoàn hảo**, **toàn diện**, **triệt để**, **vượt trội** nếu không có tiêu chí và số liệu chứng minh.
- Không nhân hóa phần mềm. Viết “hệ thống kiểm tra dữ liệu” thay cho “hệ thống hiểu dữ liệu”; viết “hệ thống ghi nhận lỗi” thay cho “hệ thống biết thiết bị bị lỗi”.
- Không lặp câu rào đón ở nhiều mục. Giới hạn của chức năng được trình bày một lần tại nơi phù hợp và được dẫn chiếu khi cần.

## 4. Thì và mức độ khẳng định

### 4.1. Thì của câu

- Dùng hiện tại để mô tả kiến thức nền, cấu trúc và chức năng đang có: “OSPF là giao thức trạng thái liên kết”; “CAMS lưu dữ liệu trong SQLite”.
- Dùng quá khứ hoặc cụm “trong thử nghiệm” để mô tả thao tác đã thực hiện: “Trong thử nghiệm, hệ thống triển khai cấu hình trên sáu bộ định tuyến”.
- Chỉ dùng tương lai trong mục hướng phát triển: “Hệ thống sẽ bổ sung hỗ trợ NETCONF”.
- Không dùng tương lai để mô tả sản phẩm đã hoàn thành. Viết “Hệ thống gồm bốn phân hệ”, không viết “Hệ thống sẽ gồm bốn phân hệ”.

### 4.2. Phân biệt trạng thái của nội dung

- **Đã hiện thực:** dùng động từ dứt khoát như “hỗ trợ”, “lưu”, “thu thập”, “triển khai”, kèm phạm vi cụ thể.
- **Đã kiểm chứng:** nêu phép thử, điều kiện và kết quả đo được.
- **Chưa kiểm chứng:** viết “chưa được đánh giá trong phạm vi thử nghiệm”, không suy rộng thành kết luận.
- **Hướng phát triển:** dùng “đề xuất”, “dự kiến”, “có thể xem xét”; không trình bày như chức năng hiện có.

Ví dụ: “CAMS hỗ trợ SSH và Telnet cho các luồng CLI hiện có. NETCONF và RESTCONF là hướng mở rộng.”

## 5. Ưu tiên tiếng Việt và sử dụng thuật ngữ nước ngoài

### 5.1. Quy tắc giới thiệu thuật ngữ

- Ở lần xuất hiện đầu tiên, viết tên tiếng Việt trước, tên tiếng Anh và chữ viết tắt trong ngoặc: **giao diện dòng lệnh (Command-Line Interface – CLI)**.
- Sau lần giới thiệu, dùng tên tiếng Việt hoặc chữ viết tắt đã định nghĩa; không lặp lại tên tiếng Anh ở mọi lần xuất hiện.
- Giữ nguyên tên sản phẩm, thư viện, giao thức, lệnh và thành phần giao diện: Cisco IOS, PyQt6, Jinja2, `show ip route`, **View & Push**.
- Tên nút hoặc nhãn giao diện được in đậm hoặc đặt trong dấu mã để phân biệt với lời văn.
- Không dịch máy móc tên chuẩn hoặc tên riêng. Ví dụ, dùng **Syslog**, **SQLite**, **Qt Quick**, không tạo tên Việt hóa khó hiểu.

### 5.2. Từ ngữ thống nhất

| Không ưu tiên | Dùng thống nhất |
|---|---|
| push cấu hình | triển khai cấu hình; riêng tên nút dùng **Push** |
| save | lưu |
| preview | xem trước |
| pending | chờ áp dụng |
| current state | trạng thái quan sát hoặc trạng thái hiện tại, tùy ngữ cảnh |
| desired state | trạng thái mong muốn |
| rollback | khôi phục cấu hình |
| config | cấu hình |
| database | cơ sở dữ liệu |
| interface | cổng hoặc giao diện; dùng **cổng mạng** khi nói về cổng thiết bị |
| router | bộ định tuyến |
| switch | bộ chuyển mạch |
| host | máy đích hoặc thiết bị, tùy ngữ cảnh |
| thread/background thread | luồng/luồng nền |
| timeout | hết thời gian chờ |
| severity | mức độ nghiêm trọng |
| facility | nhóm nguồn Syslog; với Cisco IOS dùng **mã phân hệ** |
| upstream | mạng phía ngoài hoặc thiết bị phía trên, tùy sơ đồ |
| ping chéo | kiểm tra kết nối ICMP giữa các máy trạm |
| multi-vendor | đa hãng |
| lab | phòng thực hành hoặc môi trường thử nghiệm |

### 5.3. Thuật ngữ không được dùng lẫn nghĩa

- **Syslog facility** là nhóm nguồn được mã hóa trong PRI; **Cisco IOS facility code** như `LINEPROTO` là mã phân hệ trong chuỗi `%FACILITY-SEVERITY-MNEMONIC`.
- **HSRP, VRRP, GLBP** là giao thức dự phòng cổng mặc định, không gọi là giao thức định tuyến.
- **Mạng quản trị riêng** chỉ được gọi là **mạng quản trị ngoại băng** khi thực sự tách đường truyền và bảng định tuyến quản trị.
- **Khôi phục tệp dự án** không đồng nghĩa với **khôi phục cấu hình trên thiết bị**.
- **Gửi được lệnh** không đồng nghĩa với **thiết bị đã áp dụng thành công**.

## 6. Cấu trúc đoạn và mạch lập luận

Mỗi đoạn nên có ba thành phần theo thứ tự:

1. Câu chủ đề nêu khái niệm hoặc nhận định chính.
2. Các câu giải thích cơ chế, điều kiện hoặc bằng chứng.
3. Câu kết nối nội dung với CAMS, thử nghiệm hoặc phần tiếp theo nếu cần.

Không mở đoạn bằng lịch sử dài nếu lịch sử đó không phục vụ lập luận. Không xếp nhiều định nghĩa rời rạc trong cùng đoạn. Khi so sánh từ ba đối tượng trở lên, ưu tiên dùng bảng có tiêu chí rõ ràng.

## 7. Mô tả chức năng và thử nghiệm

- Mô tả chức năng theo chuỗi: **đầu vào → xử lý → đầu ra → điều kiện lỗi**.
- Mô tả thử nghiệm theo chuỗi: **mục tiêu → môi trường → thao tác → tiêu chí → kết quả → nhận xét**.
- Mọi nhận định “nhanh hơn”, “ổn định”, “an toàn” hoặc “hiệu quả” phải có số liệu, phép thử hoặc nguồn tham khảo.
- Gắn kết quả với đúng phạm vi. Kết quả trên sáu thiết bị thử nghiệm không được suy rộng thành khả năng vận hành ở quy mô doanh nghiệp.
- Phân biệt rõ minh chứng cấu hình và minh chứng chức năng. `show running-config` cho thấy lệnh đã tồn tại; kiểm tra lưu lượng hoặc trạng thái giao thức mới chứng minh chức năng hoạt động.

## 8. Hình, bảng, lệnh và số liệu

- Mỗi hình và bảng phải có số, tên và được nhắc đến trong phần nội dung trước hoặc ngay sau vị trí xuất hiện.
- Tên hình, bảng mô tả thông tin được chứng minh, không chỉ mô tả thao tác chụp màn hình.
- Hình phải đủ lớn để đọc khi in. Ưu tiên trích kết quả lệnh quan trọng thành khối mã thay vì ghép nhiều cửa sổ đầu cuối nhỏ.
- Lệnh, tên tệp, tên bảng cơ sở dữ liệu, địa chỉ và giá trị cấu hình đặt trong dấu mã: `show glbp brief`, `device_network.db`.
- Khi diễn giải số liệu, nêu điều kiện và đơn vị. Ví dụ: “Với TTL ban đầu bằng 64, giá trị nhận được bằng 59 tương ứng năm chặng định tuyến”.
- Không dùng phần trăm hoặc số thập phân có độ chính xác cao hơn dữ liệu đo cho phép.

## 9. Trích dẫn và tài liệu tham khảo

- Trích dẫn ngay sau khẳng định được nguồn hỗ trợ, không gom toàn bộ trích dẫn ở cuối một mục dài.
- Ưu tiên tiêu chuẩn, RFC, tài liệu chính thức của nhà cung cấp, sách chuyên ngành và bài báo khoa học.
- Không dùng một tài liệu để hỗ trợ nội dung nằm ngoài phạm vi của tài liệu đó.
- Dùng thống nhất kiểu IEEE trong toàn báo cáo.
- Tên tài liệu giữ nguyên ngôn ngữ gốc trong danh mục tham khảo; phần diễn giải trong nội dung vẫn viết bằng tiếng Việt.
- Với tài liệu trực tuyến, ghi tổ chức, tên trang, đường dẫn và ngày truy cập.

## 10. Dấu câu và trình bày

- Dùng dấu phẩy để tách thành phần ngắn; dùng dấu chấm phẩy khi các vế liệt kê đã có dấu phẩy.
- Không đặt khoảng trắng trước dấu chấm, dấu phẩy, dấu chấm phẩy hoặc dấu hai chấm.
- Dùng gạch nối trong tên ghép theo chuẩn; dùng gạch ngang dài “–” để nối thuật ngữ song ngữ hoặc khoảng ý nghĩa.
- Viết hoa tên chương, tiêu đề và tên riêng theo quy tắc tiếng Việt; không viết hoa toàn bộ thuật ngữ thông thường trong câu.
- Chữ viết tắt phải được giải thích ở lần xuất hiện đầu tiên và bổ sung vào danh mục từ viết tắt nếu được dùng nhiều lần.

## 11. Mẫu sửa câu

| Câu chưa phù hợp | Câu đề xuất |
|---|---|
| “Hệ thống sẽ được tổ chức thành bốn nhóm chức năng.” | “Hệ thống gồm bốn nhóm chức năng.” |
| “CAMS có thể hỗ trợ cả SSH và Telnet.” | “CAMS hỗ trợ SSH và Telnet cho các luồng CLI hiện có; SSH là lựa chọn mặc định.” |
| “User nhấn Save & Push để push config.” | “Người quản trị chọn **Save & Push** để lưu và triển khai cấu hình.” |
| “Sau đó ping chéo để check network.” | “Sau đó, nhóm thử nghiệm kiểm tra kết nối ICMP giữa các máy trạm.” |
| “Kết quả cho thấy hệ thống cực kỳ ổn định.” | “Trong 30 lần thử, 30 lần triển khai hoàn tất và không ghi nhận lỗi kết nối.” |
| “LINEPROTO là facility của Syslog.” | “`LINEPROTO` là mã phân hệ Cisco IOS; nhóm nguồn Syslog được xác định từ trường PRI.” |

## 12. Danh sách kiểm tra trước khi hoàn tất một mục

- [ ] Chủ thể của mỗi câu đã rõ ràng.
- [ ] Không còn cách xưng hô “tôi”, “em”, “chúng tôi” hoặc “nhóm em”.
- [ ] Thuật ngữ tiếng Anh đã có tên tiếng Việt hoặc được giữ lại vì là tên riêng, lệnh hay nhãn giao diện.
- [ ] Chức năng hiện có và hướng phát triển đã được phân biệt.
- [ ] Khẳng định kỹ thuật quan trọng có nguồn trích dẫn.
- [ ] Kết luận về hiệu quả có số liệu hoặc bằng chứng.
- [ ] Hình và bảng đều có tên, số và lời dẫn.
- [ ] Từ viết tắt mới đã được giải thích và bổ sung vào danh mục.
- [ ] Không có câu dài, ý lặp hoặc từ cường điệu thiếu căn cứ.
- [ ] Tên chức năng, tệp, bảng dữ liệu và thuật ngữ được dùng nhất quán với các chương khác.
