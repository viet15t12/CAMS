# Truyền tệp bằng SFTP/SCP

Workspace **SFTP/SCP** của CAMS dùng để truyền tệp qua SSH giữa máy chạy CAMS
và máy chủ từ xa. SFTP phù hợp khi cần duyệt và quản lý thư mục remote; SCP phù
hợp khi đã biết chính xác đường dẫn nguồn hoặc đích và chỉ cần truyền dữ liệu.

Mở **SFTP/SCP** trên Activity Bar hoặc nhấn `Ctrl+Alt+F`. Cả hai giao thức dùng
SSH và thường dùng cổng 22, nhưng cách thao tác với filesystem remote khác nhau.
CAMS không cung cấp FTP không mã hóa trong workspace này.

## Chọn SFTP hay SCP

| Chế độ | Nên dùng khi | Khả năng trong CAMS |
|---|---|---|
| **SFTP** | Cần xem danh sách thư mục và thực hiện nhiều thao tác tệp. | Duyệt remote, Back/Forward/Up/Refresh, Upload, Download, tạo thư mục, đổi tên và xóa. |
| **SCP** | Đã biết đường dẫn remote và cần truyền nhanh tệp hoặc thư mục. | Upload mục local tới một đường dẫn remote hoặc Download bằng đường dẫn nhập trực tiếp; không duyệt, đổi tên hay xóa filesystem remote. |

Việc chọn SCP không làm panel remote hoạt động như SFTP. Nếu cần xem nội dung
thư mục trước khi chọn tệp, dùng SFTP.

## Tạo kết nối SFTP/SCP

Chọn nút thêm kết nối trong panel **SFTP/SCP CONNECTIONS**. CAMS mở biểu mẫu thông
tin máy chủ như hình dưới.

<figure>
<p><img src="../../figures/gui/chapter-12/01-sftp-connection-form.png"
style="width:72.0%" /></p>
<figcaption><p>Thông tin xác thực và trường Transfer mode của profile SFTP/SCP.</p></figcaption>
</figure>

| Trường | Cách nhập |
|---|---|
| **Display name** | Tên gợi nhớ hiển thị trong danh sách kết nối, ví dụ `Backup Server`. |
| **Transfer mode** | Chọn `SFTP` để duyệt remote hoặc `SCP` để truyền theo đường dẫn cụ thể. Chế độ này được lưu cùng profile. |
| **Host / IP** | Tên miền hoặc địa chỉ IP của SSH server. Phải có đường mạng từ máy CAMS đến địa chỉ này. |
| **Port** | Cổng SSH của server; thường là `22`. Nếu quản trị viên đổi cổng SSH, nhập đúng cổng đã được cấp. |
| **Username** | Tài khoản được phép đăng nhập và đọc/ghi thư mục đích. |
| **Saved password** | Mật khẩu đã lưu cho profile. Chỉ bật **Save password** khi hệ điều hành có kho bí mật an toàn và chính sách của đơn vị cho phép. |
| **Private key (optional)** | Đường dẫn khóa riêng SSH, ví dụ `/home/user/.ssh/id_ed25519`. Dùng nút **Browse** để chọn tệp, đồng thời bảo vệ quyền truy cập tệp khóa. |

Nên ưu tiên **private key** hoặc SSH agent thay cho lưu mật khẩu. Nếu CAMS báo
`Secure password storage is unavailable on this system`, tùy chọn lưu mật khẩu
sẽ bị vô hiệu hóa; người dùng cần nhập mật khẩu khi kết nối hoặc dùng khóa SSH.

Cuộn xuống phần cuối biểu mẫu để đặt thư mục mở ban đầu.

<figure>
<p><img src="../../figures/gui/chapter-12/08-sftp-connection-paths.png"
style="width:72.0%" /></p>
<figcaption><p>Đường dẫn local và remote được mở sau khi kết nối.</p></figcaption>
</figure>

- **Initial local directory**: thư mục trên máy chạy CAMS, ví dụ
  `/home/user/CAMS-Backups`.
- Với **SFTP**, **Initial remote directory** là thư mục được mở sau khi kết nối,
  ví dụ `/network/configs`.
- Với **SCP**, trường này đổi thành **Remote upload/download path**. Nhập đường
  dẫn remote cụ thể, ví dụ `/network/incoming/R1.cfg` hoặc thư mục đích được
  server cho phép.

Chọn **Save** để lưu profile. Trước khi dùng trên hệ thống thật, kiểm tra
Transfer mode, Host/IP, username, khóa riêng và hai đường dẫn; không đưa mật
khẩu hoặc khóa riêng vào tài liệu dùng chung.

## Kết nối trực tiếp

Thanh phía trên Workspace cho phép nhập nhanh thông tin kết nối mà không cần mở
lại biểu mẫu profile.

<figure>
<p><img src="../../figures/gui/chapter-12/03-sftp-connection-bar.png"
style="width:100.0%" /></p>
<figcaption><p>Thanh kết nối nhanh có thêm lựa chọn Mode SFTP hoặc SCP.</p></figcaption>
</figure>

Nhập **Host/IP**, **Port**, **Username**, chọn **Mode**, chọn **Private key** nếu
có, rồi nhấn **Connect**. Mode chỉ đổi được khi chưa kết nối. Khi phiên đã hoạt
động, nút này chuyển thành **Disconnect**. Nếu
server yêu cầu mật khẩu nhưng profile không lưu mật khẩu, CAMS sẽ yêu cầu nhập
thông tin xác thực trong quá trình kết nối.

### Xác minh host key lần đầu

Khi gặp server chưa từng được tin cậy, CAMS hiển thị fingerprint của SSH host
key trước khi tiếp tục.

<figure>
<p><img src="../../figures/gui/chapter-12/07-sftp-host-key-confirmation.png"
style="width:66.0%" /></p>
<figcaption><p>Xác nhận fingerprint của SFTP server trước lần kết nối đầu tiên.</p></figcaption>
</figure>

Hộp xác nhận này dùng cho cả SFTP và SCP. Đối chiếu fingerprint với quản trị
viên hoặc một kênh tin cậy khác. Chỉ chọn
**Trust and Connect** khi fingerprint trùng khớp. Nếu host key của một server đã
biết đột ngột thay đổi, dừng kết nối và xác minh nguyên nhân thay vì chấp nhận
ngay.

## Truyền tệp bằng SFTP

### Quản lý tệp local

Panel **LOCAL FILES** hiển thị nội dung trên máy chạy CAMS.

<figure>
<p><img src="../../figures/gui/chapter-12/04-sftp-local-files.png"
style="width:72.0%" /></p>
<figcaption><p>Panel local với đường dẫn, điều hướng và các thao tác tệp.</p></figcaption>
</figure>

- Nhập đường dẫn hoặc dùng **Back**, **Forward**, **Up**, **Refresh** để điều
  hướng.
- Nhấp đúp thư mục để mở. Chọn một hay nhiều tệp rồi nhấn **Upload** để đưa lên
  thư mục remote đang mở.
- **New folder**, **Rename** và **Delete** tác động lên phía local khi panel này
  đang được chọn. Kiểm tra kỹ mục được chọn trước thao tác xóa.

### Quản lý tệp trên server

Panel **REMOTE FILES** chỉ sẵn sàng sau khi kết nối thành công.

<figure>
<p><img src="../../figures/gui/chapter-12/05-sftp-remote-files.png"
style="width:72.0%" /></p>
<figcaption><p>Panel remote tại thư mục lưu cấu hình mạng trên SFTP server.</p></figcaption>
</figure>

- **Download** tải mục đang chọn về thư mục local đang mở.
- **New folder**, **Rename** và **Delete** thực hiện trên server và phụ thuộc
  quyền của tài khoản SFTP.
- Trước khi truyền, kiểm tra đúng đường dẫn ở cả hai panel, tên tệp, dung lượng
  trống và quyền đọc/ghi. Với dữ liệu quan trọng, nên dùng tên có ngày giờ hoặc
  phiên bản để tránh nhầm bản backup.

## Truyền tệp bằng SCP

Chọn Mode **SCP** trước khi Connect. Panel local vẫn cho phép chọn tệp hoặc thư
mục, nhưng panel remote chuyển thành **REMOTE SCP PATH** và không hiển thị danh
sách filesystem.

<figure>
<p><img src="../../figures/gui/chapter-12/09-scp-workspace.png"
style="width:100.0%" /></p>
<figcaption><p>Workspace SCP với đường dẫn remote nhập trực tiếp.</p></figcaption>
</figure>

Để upload, nhập thư mục hoặc đường dẫn đích ở panel phải, chọn mục ở panel local
rồi nhấn **Upload**. Để download, nhập đầy đủ đường dẫn file/thư mục remote rồi
nhấn **Download path**. Kiểm tra dấu `/`, tên tệp, quyền ghi và quy tắc đường dẫn
của server trước khi bắt đầu.

SCP không có các thao tác duyệt, Refresh, New folder, Rename hoặc Delete ở phía
remote. Nếu chưa chắc đường dẫn tồn tại, chuyển sang SFTP để kiểm tra hoặc xác
minh bằng công cụ quản trị server.

## Giao diện tổng thể và hàng đợi truyền tệp

Sau khi kết nối, hai panel local và remote nằm cạnh nhau để dễ đối chiếu nguồn
với đích. Danh sách profile có thể được giữ ở bên trái; không bắt buộc phải mở
rộng panel này khi thao tác tệp.

<figure>
<p><img src="../../figures/gui/chapter-12/02-sftp-workspace-overview.png"
style="width:100.0%" /></p>
<figcaption><p>Tổng thể Workspace SFTP với hai panel và hàng đợi truyền tệp.</p></figcaption>
</figure>

Mỗi lần Upload hoặc Download bằng SFTP hay SCP tạo một mục trong **FILE TRANSFER
QUEUE**.

<figure>
<p><img src="../../figures/gui/chapter-12/06-sftp-transfer-queue.png"
style="width:100.0%" /></p>
<figcaption><p>Tiến độ Upload, Download và trạng thái hoàn thành.</p></figcaption>
</figure>

- Biểu tượng và cột tên cho biết tệp cùng chiều **upload/download**.
- Thanh tiến độ, trạng thái và phần mô tả giúp theo dõi từng tác vụ.
- **Cancel** chỉ khả dụng khi tác vụ đang chờ hoặc đang truyền.
- **Clear finished** xóa các mục đã hoàn thành khỏi hàng đợi, không xóa tệp đã
  truyền.

Không ngắt mạng hoặc đóng CAMS khi hàng đợi vẫn còn tác vụ đang chạy. Sau khi
hoàn tất, làm mới panel đích và kiểm tra tên, kích thước tệp trước khi xem bản
sao lưu là hợp lệ.

## Lấy running-config và theo dõi đồng bộ

Lấy running-config là chức năng quản lý thiết bị, không phải thao tác Download
trong panel SFTP/SCP. Chọn thiết bị đang **Connected**, nhấn chuột phải và chọn
**Get running-config**. CAMS thu thập cấu hình đang chạy qua phiên quản lý, lưu
một snapshot theo host rồi đồng bộ những phần cấu hình được hỗ trợ vào database.

<figure>
<p><img src="../../figures/gui/chapter-04/11-device-context-connected.png"
style="width:55.0%" /></p>
<figcaption><p>Lệnh Get running-config trong menu của thiết bị Connected.</p></figcaption>
</figure>

Khi tác vụ chạy, theo dõi Status Bar và Notification Center. Không chạy lại liên
tục chỉ vì chưa thấy dữ liệu mới; quá trình thu thập, lưu snapshot và đồng bộ có
thể hoàn tất ở các thời điểm khác nhau.

<figure>
<p><img src="../../figures/gui/chapter-12/10-sync-notifications.png"
style="width:52.0%" /></p>
<figcaption><p>Thông báo lần lượt khi lấy running-config, lưu snapshot và hoàn tất đồng bộ nền.</p></figcaption>
</figure>

- Thông báo **Getting running-config…** cho biết tác vụ đã bắt đầu, chưa phải kết
  quả thành công.
- **Running-config snapshot saved…** xác nhận bản cấu hình đã được lưu vào lịch
  sử của host.
- **Background synchronization completed…** xác nhận bước cập nhật database đã
  hoàn tất.
- Nếu backup thành công nhưng sync thất bại, snapshot vẫn có thể xem được; đọc
  cảnh báo và xử lý nguyên nhân đồng bộ riêng.

## Xem lại cấu hình cũ

Mở tab thiết bị → **Information** → **Snapshot**. Danh sách **Version** chứa tối
đa 100 mốc mới nhất theo host. Chọn một mốc để đọc đúng nội dung đã lưu tại thời
điểm đó; thao tác này không checkout repository và không thay đổi cấu hình thiết
bị.

<figure>
<p><img src="../../figures/gui/chapter-12/11-running-config-history.png"
style="width:100.0%" /></p>
<figcaption><p>Snapshot mới nhất và danh sách các phiên bản running-config.</p></figcaption>
</figure>

**Copy All** sao chép phần đang hiển thị. **Export CFG** xuất snapshot được chọn
thành tệp `.cfg`; nút này chỉ hoạt động trong chế độ Snapshot, không xuất trực
tiếp nội dung Diff.

## So sánh cấu hình bằng Diff

Khi có ít nhất hai phiên bản, chọn **Compare**. Chọn **Original (older)** và
**Modified (newer)**; hai mốc không cần liền kề, vì CAMS có thể tạo diff tích lũy
cho toàn bộ khoảng phiên bản giữa chúng.

<figure>
<p><img src="../../figures/gui/chapter-12/12-running-config-diff.png"
style="width:100.0%" /></p>
<figcaption><p>Diff giữa hai phiên bản với số dòng thêm và xóa.</p></figcaption>
</figure>

- Dòng bắt đầu bằng `-` là nội dung có trong bản cũ nhưng không còn ở bản mới.
- Dòng bắt đầu bằng `+` là nội dung được thêm vào bản mới.
- Các badge `+N` và `−N` cho biết tổng số dòng thêm/xóa; số **versions** cho biết
  khoảng lịch sử đang được so sánh.
- Nếu hai endpoint có nội dung giống nhau, vùng diff báo không có khác biệt.

Diff chỉ dùng để xem và đối chiếu. Nó không tự khôi phục cấu hình cũ và không gửi
lệnh lên thiết bị. Muốn quay lại Snapshot, chọn **Snapshot** rồi chọn Version cần
xem.

## Phím tắt thường dùng

| Phím tắt | Tác dụng trên panel đang hoạt động |
|---|---|
| `Alt+Left` / `Backspace` | Quay lại thư mục trước. |
| `Alt+Right` | Đi tới thư mục kế tiếp trong lịch sử. |
| `Alt+Up` | Mở thư mục cha. |
| `F5` / `Ctrl+R` | Làm mới danh sách. |
| `Ctrl+Shift+N` | Tạo thư mục mới. |
| `F2` | Đổi tên mục đang chọn. |
| `Delete` | Xóa mục đang chọn sau bước xác nhận. |
| `Enter` | Với SFTP, mở thư mục hoặc truyền mục đang chọn; với SCP, thực hiện theo đường dẫn remote đã nhập. |
| `Ctrl+A` | Chọn tất cả mục trong panel. |
| `Esc` | Bỏ vùng chọn. |
| `Shift+F10` | Mở menu ngữ cảnh của tệp. |
