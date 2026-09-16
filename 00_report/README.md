# CAMS – Typst report

Bộ báo cáo NCKH đã được chuyển từ cấu trúc LaTeX modular sang Typst.

## Cấu trúc

```text
docs/research/report/
├── appendix/ ------------------------- Phụ lục
├── bibliography ---------------------- Trích dẫn
├── chapters/ ------------------------- Chương
├── config/ --------------------------- Cấu hình chung
├── cover/ ---------------------------- Trang bìa
├── md/ ------------------------------- Bản Markdown của các chương
├── DETAILED_OUTLINE.md --------------- Đề cương Báo cáo Nghiên cứu khoa học
└── main.typ  
```

## Kho ảnh dùng chung

Toàn bộ ảnh của sách hướng dẫn và báo cáo được quản lý tập trung trong
`../00_book/figures/`. Không tạo thêm bản sao ảnh trong `00_report`.

- Ảnh giao diện CAMS: `../00_book/figures/gui/`
- Sơ đồ và ảnh thử nghiệm của báo cáo: `../00_book/figures/report/diagrams/`
- Ảnh phụ lục của báo cáo: `../00_book/figures/report/appendix/`

Ví dụ một ảnh giao diện dùng chung:

```text
../00_book/figures/gui/chapter-03/01-workspace-overview.png
```

## Bảng trong báo cáo

Dùng helper `report-table` để các bảng có chú thích ở phía trên, giữ đường kẻ dọc và chỉ dùng các đường kẻ ngang cần thiết ở đầu bảng, sau hàng tiêu đề và cuối bảng:

```typst
#import "config/tables.typ": report-table

#report-table(
  columns: (1fr, 2fr),
  header: ([Cột 1], [Cột 2]),
  rows: (
    ([Nội dung hàng 1], [Nội dung cột 2]),
    ([Nội dung hàng 2], [Nội dung cột 2]),
  ),
  caption: [Bảng mẫu ví dụ],
) <tab-test-results>
```

Có thể bỏ `caption` cho bảng không cần đánh số, hoặc thêm `note: [...]` để đặt ghi chú ngay dưới bảng.

Trong file `.typ`:

```typst
#insert-image(
  "/00_book/figures/gui/chapter-03/01-workspace-overview.png",
  width: 80%,
  caption: [Giao diện chính của CAMS],
) <fig-main-window>
```

Tham chiếu:

```typst
Xem @fig-main-window.
```

Đường dẫn bắt đầu bằng `/00_book/` được tính từ gốc dự án. Vì vậy, dựng báo cáo
từ thư mục chứa `00_book` và `00_report` bằng lệnh:

```bash
typst compile --root . 00_report/main.typ 00_report/main.pdf
```

## Tài liệu tham khảo

Typst đọc trực tiếp BibLaTeX/BibTeX `.bib`:

```typst
Theo @tanenbaum2021computer, ...
```

Nếu project LaTeX gốc đã có `cams_references.bib`, hãy chép đè file mẫu trong project này để giữ toàn bộ nguồn cũ.

## Lưu ý

- `packages.tex` và `latexmkrc` không còn cần thiết.
- Các chapter và appendix đã được tạo dựa trên đề cương hiện tại.
- Các vị trí `TODO` cần cập nhật bằng thông tin, ảnh, test và số đo thực tế trước khi nộp.
