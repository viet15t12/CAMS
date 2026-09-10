# Truyền tệp bằng SFTP

Workspace **SFTP** của CAMS dùng để truyền tệp an toàn qua SSH giữa máy đang
chạy CAMS và máy chủ từ xa. Chức năng này phù hợp để tải cấu hình sao lưu lên
server, tải bản backup về máy hoặc quản lý thư mục lưu trữ mà không cần mở một
ứng dụng SFTP riêng.

Mở **SFTP** trên Activity Bar hoặc nhấn `Ctrl+Alt+F`. Chương này chỉ hướng dẫn
SFTP; không sử dụng FTP và không trình bày SCP.

## Tạo kết nối SFTP

Chọn nút thêm kết nối trong panel **SFTP CONNECTIONS**. CAMS mở biểu mẫu thông
tin máy chủ như hình dưới.

<figure>
<p><img src="../../figures/gui/chapter-12/01-sftp-connection-form.png"
style="width:72.0%" /></p>
<figcaption><p>Phần thông tin xác thực của một kết nối SFTP.</p></figcaption>
</figure>

| Trường | Cách nhập |
|---|---|
| **Display name** | Tên gợi nhớ hiển thị trong danh sách kết nối, ví dụ `Backup Server`. |
| **Host / IP** | Tên miền hoặc địa chỉ IP của SFTP server. Phải có đường mạng từ máy CAMS đến địa chỉ này. |
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
- **Initial remote directory (SFTP only)**: thư mục trên server, ví dụ
  `/network/configs`. Tài khoản đăng nhập phải có quyền truy cập thư mục này.

Chọn **Save** để lưu profile. Profile cũng được thêm vào panel kết nối sau lần
kết nối SFTP thành công. Trước khi dùng trên hệ thống thật, kiểm tra Host/IP,
username, khóa riêng và hai đường dẫn; không đưa mật khẩu hoặc khóa riêng vào
tài liệu dùng chung.

## Kết nối trực tiếp

Thanh phía trên Workspace cho phép nhập nhanh thông tin kết nối mà không cần mở
lại biểu mẫu profile.

<figure>
<p><img src="../../figures/gui/chapter-12/03-sftp-connection-bar.png"
style="width:100.0%" /></p>
<figcaption><p>Thanh kết nối nhanh bằng Host/IP, Port, Username và Private key.</p></figcaption>
</figure>

Nhập **Host/IP**, **Port**, **Username**, chọn **Private key** nếu có, rồi nhấn
**Connect**. Khi phiên đã hoạt động, nút này chuyển thành **Disconnect**. Nếu
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

Đối chiếu fingerprint với quản trị viên hoặc một kênh tin cậy khác. Chỉ chọn
**Trust and Connect** khi fingerprint trùng khớp. Nếu host key của một server đã
biết đột ngột thay đổi, dừng kết nối và xác minh nguyên nhân thay vì chấp nhận
ngay.

## Quản lý tệp local

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

## Quản lý tệp trên server

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

## Giao diện tổng thể và hàng đợi truyền tệp

Sau khi kết nối, hai panel local và remote nằm cạnh nhau để dễ đối chiếu nguồn
với đích. Danh sách profile có thể được giữ ở bên trái; không bắt buộc phải mở
rộng panel này khi thao tác tệp.

<figure>
<p><img src="../../figures/gui/chapter-12/02-sftp-workspace-overview.png"
style="width:100.0%" /></p>
<figcaption><p>Tổng thể Workspace SFTP với hai panel và hàng đợi truyền tệp.</p></figcaption>
</figure>

Mỗi lần Upload hoặc Download tạo một mục trong **FILE TRANSFER QUEUE**.

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
| `Enter` | Mở thư mục hoặc truyền mục đang chọn theo phía hiện tại. |
| `Ctrl+A` | Chọn tất cả mục trong panel. |
| `Esc` | Bỏ vùng chọn. |
| `Shift+F10` | Mở menu ngữ cảnh của tệp. |
