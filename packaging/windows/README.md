# Đóng gói CAMS cho Windows 11

Quy trình này tạo ứng dụng PyInstaller dạng **one-folder** rồi đóng gói thành
bộ cài Inno Setup 64-bit. Cách này khởi động nhanh và dễ chẩn đoán hơn one-file,
đồng thời người dùng cuối không cần cài Python, `uv` hay dependency của dự án.

## Yêu cầu trên máy build

- Windows 11 x64;
- `uv`;
- MSVC Build Tools nếu muốn bật Cython acceleration (không bắt buộc);
- Inno Setup 6 hoặc 7 nếu cần tạo bộ cài;
- Rust/Cargo nếu muốn đóng gói CAMS Terminal (không bắt buộc cho app chính).

## Tạo bộ cài

Mở PowerShell tại root repository:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\packaging\windows\build.ps1
```

Hoặc dùng lệnh rút gọn `cams.bat package`.

Kết quả:

- `dist\windows\CAMS\`: bản portable để smoke-test;
- `dist\installer\CAMS-<version>-windows-x64-setup.exe`: bộ cài;
- `dist\installer\SHA256SUMS.txt`: checksum SHA-256 để phát hành.

Dùng `-SkipTests`, `-SkipCython`, `-SkipTerminal` hoặc `-SkipInstaller` cho vòng
build cục bộ nhanh hơn. Mặc định script chạy nhóm test quan trọng cho đóng gói; dùng
`-FullTests` để chạy toàn bộ test suite. Build phát hành không nên bỏ qua test.

## Hành vi cài đặt

- Cài theo user vào `%LOCALAPPDATA%\Programs\CAMS`, không cần UAC/admin;
- dữ liệu, database, backup và file tạm được giữ riêng tại
  `%LOCALAPPDATA%\NetCamsTeam\CAMS\data`;
- đăng ký Start Menu, desktop shortcut tùy chọn và liên kết file `.ntp`;
- gỡ ứng dụng không xóa dữ liệu người dùng.

Khi bật Syslog listener lần đầu, Windows Defender Firewall có thể hỏi quyền
nhận kết nối. Chỉ cho phép trên mạng Private/lab được tin cậy. Device Logs vẫn
cần Wireshark/TShark (và Npcap) được cài riêng trên máy đích.

Windows SmartScreen có thể cảnh báo bộ cài chưa ký. Bản phát hành công khai nên
ký cả `CAMS.exe` và file setup bằng chứng thư Authenticode trước khi phân phối.
Nếu chứng thư đã nằm trong certificate store của user build, truyền thumbprint
qua `-SigningThumbprint` hoặc biến môi trường `CAMS_SIGN_SHA1`; script sẽ ký
SHA-256 và timestamp cả app, terminal companion và bộ cài trước khi tạo checksum.
