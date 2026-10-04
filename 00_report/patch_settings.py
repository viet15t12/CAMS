import re

with open('/data/Projects/CAMS_2/00_report/config/settings.typ', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = """  show figure.where(kind: table): set figure(
    supplement: [Bảng],
    numbering: report-table-numbering,
  )
  show figure.where(kind: table): set figure.caption(position: top)
"""

content = re.sub(r'  show figure\.where\(kind: table\): set figure\(\n    supplement: \[Bảng\],\n    numbering: report-table-numbering,\n  \)', replacement, content, flags=re.MULTILINE)

with open('/data/Projects/CAMS_2/00_report/config/settings.typ', 'w', encoding='utf-8') as f:
    f.write(content)
