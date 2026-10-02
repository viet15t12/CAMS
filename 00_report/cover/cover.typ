// Trang bìa chính báo cáo NCKH sinh viên – PTIT cơ sở TP.HCM

#import "../config/commands.typ": cover-institution, cover-report-label, cover-project-title, cover-metadata
#import "../config/info.typ": *

// Bìa chính
#page(
  paper: "a4",
  margin: (left: 3cm, right: 2cm, top: 2.5cm, bottom: 2.5cm),
  numbering: none,
)[
  #set text(font: "Times New Roman", lang: "vi")
  #set align(center)

  // Tên trường / cơ sở
  #cover-institution[#ministry]
  #v(2pt)
  #cover-institution[#academy]
  #v(2pt)
  #cover-institution[#campus]
  #v(4pt)
  #text(size: 13pt)[#faculty]

  #v(10pt)
  #line(length: 100%, stroke: 0.5pt)
  #v(30pt)

  // Loại báo cáo
  #cover-report-label[#report-type]
  #v(24pt)

  // Tên đề tài
  #cover-project-title[#project-title]
  #v(8pt)
  #text(size: 14pt, style: "italic")[Tên sản phẩm: #product-name]

  #v(36pt)

  // Thông tin chi tiết
  #set align(left)
  #pad(left: 4cm)[
    #set text(size: 13pt)
    #set par(leading: 1.5em, spacing: 0pt)
    *Lĩnh vực:* #field \
    *Giảng viên hướng dẫn:* #advisor \
    *Sinh viên thực hiện:*
    #pad(left: 1cm)[
      #members
    ]
    *Lớp:* #student-class
  ]

  #v(1fr)

  // Nơi và năm thực hiện
  #set align(center)
  #cover-metadata[#place-year]
]

// Trang bìa phụ (bìa lót)
#pagebreak()
#page(
  paper: "a4",
  margin: (left: 3cm, right: 2cm, top: 2.5cm, bottom: 2.5cm),
  numbering: none,
)[
  #set text(font: "Times New Roman", lang: "vi")
  #set align(center)

  #cover-institution[#ministry]
  #v(2pt)
  #cover-institution[#academy]
  #v(2pt)
  #cover-institution[#campus]
  #v(4pt)
  #text(size: 13pt)[#faculty]

  #v(10pt)
  #line(length: 100%, stroke: 0.5pt)
  #v(30pt)

  #cover-report-label[#report-type]
  #v(24pt)

  #cover-project-title[#project-title]
  #v(8pt)
  #text(size: 14pt, style: "italic")[Tên sản phẩm: #product-name]

  #v(36pt)

  #set align(left)
  #pad(left: 4cm)[
    #set text(size: 13pt)
    #set par(leading: 1.5em, spacing: 0pt)
    *Lĩnh vực:* #field \
    *Giảng viên hướng dẫn:* #advisor \
    *Sinh viên thực hiện:*
    #pad(left: 1cm)[
      #members
    ]
    *Lớp:* #student-class
  ]

  #v(1fr)

  #set align(center)
  #cover-metadata[#place-year]
]
