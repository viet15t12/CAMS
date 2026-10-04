// Bìa chính và bìa phụ; giữ thông tin đã có, không tự đặt mã số đề tài.
#import "../config/info.typ": *
#let report-cover(subtitle) = page(
  paper: "a4",
  margin: (left: 3cm, right: 2cm, top: 2.5cm, bottom: 2.5cm),
  numbering: none,
)[
  #set text(font: "Liberation Serif", size: 13pt, lang: "vi")
  #set par(justify: false, first-line-indent: 0pt, leading: 0.65em, spacing: 10pt)
  #align(center)[
    #text(weight: "bold")[#ministry \ #academy \ #campus]

    #faculty
    #v(8pt)
    #line(length: 100%, stroke: 0.5pt)
    #v(26pt)
    #report-type
    #v(20pt)
    #text(size: 16pt, weight: "bold")[#project-title]
    #v(8pt)
    #emph[Tên sản phẩm: #product-name]
    #v(8pt)
    #subtitle
  ]
  #v(24pt)
  #table(
    columns: (37%, 63%), stroke: none, inset: (x: 0pt, y: 7pt), align: left,
    [*Lĩnh vực:*], [Mạng máy tính, tự động hóa mạng, phần mềm máy tính để bàn],
    [*Giảng viên hướng dẫn:*], [#advisor],
    [*Sinh viên thực hiện:*], [Nguyễn Quốc Việt – N24DCVT113 \ Nguyễn Phan Kiên – N24DCVT046 \ Nguyễn Trần Đạt Phú – N24DCVT072],
    [*Lớp:*], [#student-class],
  )
  #v(1fr)
  #align(center)[#place-year]
]
#report-cover([])
#report-cover([BẢN THUYẾT MINH ĐỀ TÀI])
