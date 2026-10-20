#import "../config/commands.typ": appendix-heading, appendix-section

#counter(figure.where(kind: image)).update(0)
#counter(figure.where(kind: table)).update(0)
#show figure.where(kind: image): set figure(numbering: number => [A.#number])
#show figure.where(kind: table): set figure(numbering: number => [A.#number])

#appendix-heading[PHỤ LỤC A. CẤU TRÚC DỰ ÁN VÀ TÀI NGUYÊN TRỰC TUYẾN]
#metadata("appendix-a-start") <appendix-a-start>

#appendix-section[A.1.][Sơ đồ cấu trúc thư mục mã nguồn ứng dụng]

Mã nguồn ứng dụng CAMS được tổ chức tại thư mục gốc của kho mã nguồn theo kiến trúc phân lớp. Sơ đồ dưới đây thể hiện các lớp chính, nhóm mô-đun và trách nhiệm tương ứng.

#figure(
  image("/00_book/figures/report/appendix/project-structure.svg", width: 90%),
  caption: [Cấu trúc thư mục mã nguồn ứng dụng CAMS],
) <fig-appendix-project-structure>

#set par(justify: false)
Các tài nguyên trực tuyến của dự án:

- *Tài liệu hướng dẫn sử dụng:* #link("https://viet15t12.github.io/CAMS/")[#raw("https://viet15t12.github.io/CAMS/")]
- *Kho mã nguồn:* #link("https://github.com/viet15t12/CAMS.git")[#raw("https://github.com/viet15t12/CAMS.git")]
