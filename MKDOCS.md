# Vận hành website tài liệu CAMS

MkDocs lấy nội dung từ `00_book` và tạo website tĩnh trong `site`. Các file Typst vẫn được giữ làm nguồn tham khảo nhưng bị loại khỏi website khi build.

## Chạy website trên máy cá nhân

```bash
python -m pip install -r requirements-docs.txt
python scripts/validate_documentation_assets.py --manifest-only
python scripts/sync_documentation_assets.py
python scripts/validate_documentation_assets.py --check-staging
mkdocs serve
```

Mở địa chỉ được MkDocs hiển thị, mặc định là <http://127.0.0.1:8000/CAMS/>.

Kiểm tra bản build giống GitHub Actions:

```bash
python scripts/validate_documentation_assets.py --manifest-only
python scripts/sync_documentation_assets.py
python scripts/validate_documentation_assets.py --check-staging
mkdocs build --strict
```

## Thêm các chương Markdown

Đặt các file chương trong `00_book/DOC`, sau đó thêm chúng vào mục `nav` trong `mkdocs.yml` để xác định tên và thứ tự hiển thị.

Vì file chương nằm trong `00_book/DOC`, đường dẫn ảnh cần đi lên một cấp, ví dụ:

```markdown
![Tổng quan Workspace](../figures/gui/chapter-03/01-workspace-overview.png)
```

Mẫu khai báo một chương mới trong `mkdocs.yml`:

```yaml
nav:
  - Trang chủ: index.md
  - Hướng dẫn sử dụng:
      - Tổng quan: DOC/01_tong_quan.md
      - Chương mới: DOC/05_ten_chuong.md
```

## Publish bằng GitHub Pages

Workflow `.github/workflows/docs.yml` tự build và publish khi nội dung tài liệu được đẩy lên nhánh `main`. Trong repository GitHub, vào **Settings → Pages** và chọn **Source: GitHub Actions** một lần. Sau đó có thể chạy workflow thủ công từ tab **Actions** hoặc push thay đổi mới.

## Canonical assets và staging transitional

`documentation_assets/manifest.yaml` quản lý current legacy path và planned canonical path. `00_book/assets/` là generated + gitignored, sync lossless theo SHA; không chỉnh tay và không commit binary copies/ledger. Bootstrap hiện stage 178 assets từ legacy sources, chưa migrate ảnh hoặc rewrite references. Terminal assets là frozen external, không stage.

178 HTML image references đang broken được ghi riêng trong `documentation_assets/reference-baseline.json`; MkDocs strict có thể build thành công dù raw HTML image URLs hỏng. Static validator chặn lỗi mới; `--strict-references` vẫn fail với baseline này. Future migration batch sửa từng reference và xóa exception tương ứng, không mass rewrite trong infrastructure phase. Typst dùng canonical root sau migration với `--root .`; report tuyệt đối không dùng staging copies.
