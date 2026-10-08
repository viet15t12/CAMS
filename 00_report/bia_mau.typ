#import "config/info.typ": *

#let cover-navy = rgb("#08233d")
#let cover-logo = "logo.png"

#let cover-students = (
  (name: [Nguyễn Quốc Việt], id: [N24DCVT113]),
  (name: [Nguyễn Phan Kiên], id: [N24DCVT046]),
  (name: [Nguyễn Trần Đạt Phú], id: [N24DCVT072]),
)

#let cover-frame() = context {
  let w = page.width
  let h = page.height

  let A = (w - 15mm, 20mm)
  let B = (25mm, 20mm)
  let C = (25mm, h - 20mm)
  let D = (w - 15mm, h - 20mm)

  let off(c, sx, sy, m) = (c.at(0) + sx * m, c.at(1) - sy * m)
  let path(m, pts) = polygon(
    stroke: 0.4pt + cover-navy,
    ..pts.map(((c, sx, sy)) => off(c, sx, sy, m)),
  )

  place(top + left, polygon(stroke: 4pt + cover-navy, A, B, C, D))

  place(top + left, path(5mm, (
    (A, -1, +1), (B, +1, +1), (B, +1, -1), (B, -1, -1),
    (C, -1, +1), (C, +1, +1), (C, +1, -1), (D, -1, -1),
    (D, -1, +1), (D, +1, +1), (A, +1, -1), (A, -1, -1),
  )))

  place(top + left, path(3mm, (
    (A, +1, -1), (B, -1, -1), (B, -1, +1), (B, +1, +1),
    (C, +1, -1), (C, -1, -1), (C, -1, +1), (D, +1, +1),
    (D, +1, -1), (D, -1, -1), (A, -1, +1), (A, +1, +1),
  )))
}

#page(
  paper: "a4",
  margin: (left: 30mm, right: 20mm, top: 28mm, bottom: 25mm),
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
  #set par(justify: false, first-line-indent: 0pt, leading: 0.62em, spacing: 0pt)

  #align(center)[
    #text(size: 15.5pt, weight: "bold")[
      #academy \
      #campus
    ]
    #v(9pt)
    #text(size: 12pt, weight: "bold")[#faculty]

    #v(8mm)
    #image(cover-logo, width: 7cm)
    #v(6mm)

    #text(size: 15pt, weight: "bold", fill: cover-navy)[#report-type]
    #v(6mm)

    #line(length: 84%, stroke: 0.8pt + cover-navy)
    #v(4mm)
    #text(size: 13pt, weight: "bold")[ĐỀ TÀI:]
    #v(3mm)
    #text(size: 16.2pt, weight: "bold")[#project-title]
    #v(4mm)
    #line(length: 84%, stroke: 0.8pt + cover-navy)
  ]

  #v(6mm)

  #align(center, block(width: 84%, table(
    columns: (38%, 62%),
    stroke: none,
    inset: (x: 0pt, y: 3.5pt),
    align: (left, left),
    [*Giảng viên hướng dẫn:*], [#advisor],
    [*Sinh viên thực hiện:*], [
      #for (index, student) in cover-students.enumerate() {
        student.name
        text(" - ")
        student.id
        if index < cover-students.len() - 1 { linebreak() }
      }
    ],
  )))

  #v(6.5cm)
  #align(center, text(size: 13pt, weight: "bold")[
    TP. HỒ CHÍ MINH, THÁNG 10 NĂM 2026
  ])
]
