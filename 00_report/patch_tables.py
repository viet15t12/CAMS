import re

with open('/data/Projects/CAMS_2/00_report/config/tables.typ', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = """  if caption == none {
    table-content
  } else {
    figure(
      table-content,
      kind: table,
      caption: caption,
    )
  }"""

content = re.sub(r'  if caption == none \{\n    table-content\n  \} else \{\n    set figure\.caption\(position: top\)\n    show figure: set block\(breakable: false\)\n\n    figure\(\n      table-content,\n      kind: table,\n      caption: caption,\n    \)\n  \}', replacement, content, flags=re.MULTILINE)

with open('/data/Projects/CAMS_2/00_report/config/tables.typ', 'w', encoding='utf-8') as f:
    f.write(content)
