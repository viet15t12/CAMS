#import "config/info.typ": *

#let cover-navy = rgb("#08233d")

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
    #v(7pt)
    #text(size: 12pt, weight: "bold")[#faculty]

    #v(27mm)

    #text(size: 20pt, weight: "bold")[#report-type]
    #v(8mm)
    #text(size: 14.5pt, weight: "bold")[
      ĐỀ TÀI NGHIÊN CỨU KHOA HỌC CỦA SINH VIÊN \
      NĂM HỌC #academic-year
    ]

    #v(25mm)
    #text(size: 16.2pt, weight: "bold")[#project-title]
    #v(9mm)
    #text(size: 14.5pt, weight: "bold")[MÃ SỐ ĐỀ TÀI: #project-code]
  ]

  #v(18mm)
  #align(left, text(size: 12pt)[
    *Thuộc nhóm ngành khoa học:* #field
  ])

  #v(1fr)
  #align(center, text(size: 13pt, weight: "bold")[
    TP. HỒ CHÍ MINH, 10/2026
  ])
]
