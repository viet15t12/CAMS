// Bìa chính và bìa phụ theo bố cục Mẫu 3.2 và 3.3.
#import "config/info.typ": *

#let cover-students = (
  (name: [Nguyễn Quốc Việt], id: [N24DCVT113], gender: [Nam]),
  (name: [Nguyễn Phan Kiên], id: [N24DCVT046], gender: [Nam]),
  (name: [Nguyễn Trần Đạt Phú], id: [N24DCVT072], gender: [Nam]),
)

// Khung đơn, cách mép giấy 10 mm như mẫu.
#let cover-frame() = context {
  place(
    top + left,
    dx: 10mm,
    dy: 10mm,
    rect(
      width: page.width - 20mm,
      height: page.height - 20mm,
      stroke: 0.5pt + black,
    ),
  )
}

#let cover-page(body) = page(
  paper: "a4",
  margin: (left: 30mm, right: 25mm, top: 22mm, bottom: 36mm),
  numbering: none,
  header: none,
  footer: none,
  background: cover-frame(),
)[
  #set text(
    font: ("Times New Roman", "Liberation Serif"),
    size: 13pt,
    lang: "vi",
  )
  #set par(justify: false, first-line-indent: 0pt, leading: 0.58em, spacing: 0pt)
  #body
]

#let institution-header() = align(center)[
  #text(size: 14pt, weight: "bold")[
    #academy \
    #campus \
    #faculty
  ]
  #v(3mm)
  #text(size: 10pt, fill: luma(95))[----------------------]
]

#let report-heading(size: 18pt) = align(center)[
  #text(size: size, weight: "bold")[#report-type]
  #v(2mm)
  #text(size: 13.5pt, weight: "bold")[
    ĐỀ TÀI NGHIÊN CỨU KHOA HỌC CỦA SINH VIÊN \
    NĂM HỌC: #academic-year
  ]
]

#let project-heading(size: 15.5pt, prefix: true) = align(center)[
  #text(size: size, weight: "bold")[
    #if prefix [ĐỀ TÀI: ]#project-title
  ]
  #v(2mm)
  #text(size: 13.5pt, weight: "bold")[MÃ SỐ ĐỀ TÀI: #project-code]
]

// Bìa chính.
#cover-page[
  #institution-header()

  #v(46mm)
  #report-heading()

  #v(47mm)
  #project-heading()

  #v(1fr)
  #align(center, text(size: 12pt)[
    Thuộc nhóm ngành khoa học: #field
  ])

  #v(15mm)
  #align(center, text(size: 12pt, weight: "bold")[
    TP.HCM-10/2026
  ])
]

// Bìa phụ.
#cover-page[
  #institution-header()

  #v(17mm)
  #report-heading(size: 17pt)

  #v(38mm)
  #project-heading(size: 14.5pt, prefix: false)

  #v(15mm)
  #table(
    columns: (40mm, 1fr, 35mm),
    stroke: none,
    inset: (x: 0pt, y: 2.2pt),
    align: (left, left, left),
    [Sinh viên thực hiện:], [#cover-students.at(0).name], [Nam, Nữ: #cover-students.at(0).gender],
    [], [#cover-students.at(1).name], [Nam, Nữ: #cover-students.at(1).gender],
    [], [#cover-students.at(2).name], [Nam, Nữ: #cover-students.at(2).gender],
  )

  #v(21mm)
  #table(
    columns: (37mm, 5mm, 1fr, 23mm, 13mm),
    stroke: none,
    inset: (x: 0pt, y: 2pt),
    align: left,
    [Dân tộc], [:], [#ethnicity], [], [],
    [Lớp], [:], [#student-class], [Năm thứ:], [#study-year],
    [Khoa], [:], [Khoa Viễn thông 2], [], [],
    [Ngành học], [:], [#major], [], [],
    [Người hướng dẫn], [:], [#advisor], [], [],
  )

  #v(1fr)
  #align(center, text(size: 12pt, weight: "bold")[
    TP.HCM-10/2026
  ])
]
