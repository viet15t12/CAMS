#!/usr/bin/env python3
"""Synchronize the MkDocs chapters with the canonical Typst manual.

The converter intentionally supports only the small, controlled Typst subset
used by ``00_book/contents``.  Keeping the conversion local makes differences
between the printable manual and the website reproducible and reviewable.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TYPST_DIR = ROOT / "00_book" / "contents"
MARKDOWN_DIR = ROOT / "00_book" / "DOC"

CHAPTER_LINKS = {
    f"ch{number:02d}": next(MARKDOWN_DIR.glob(f"{number:02d}_*.md")).name
    for number in range(1, 20)
}


def matching_delimiter(text: str, start: int, opener: str, closer: str) -> int:
    """Return the matching delimiter while respecting strings and nesting."""
    depth = 0
    quoted = False
    escaped = False
    for index in range(start, len(text)):
        char = text[index]
        if quoted:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quoted = False
            continue
        if char == '"':
            quoted = True
        elif char == opener:
            depth += 1
        elif char == closer:
            depth -= 1
            if depth == 0:
                return index
    raise ValueError(f"Unclosed {opener!r} beginning at offset {start}")


def label_id(label: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_-]+", "-", label).strip("-").lower()


def inline(text: str) -> str:
    """Convert inline Typst markup to Markdown."""
    text = re.sub(
        r'#raw\("((?:[^"\\]|\\.)*)"\)',
        lambda match: "`" + match.group(1).replace(r'\"', '"') + "`",
        text,
    )

    def reference(match: re.Match[str]) -> str:
        target = match.group(1)
        if target in CHAPTER_LINKS:
            number = int(target[2:])
            return f"[Chương {number}]({CHAPTER_LINKS[target]})"
        anchor = label_id(target)
        if target.startswith("fig:"):
            return f"[hình minh họa](#{anchor})"
        if target.startswith("tab:"):
            return f"[bảng tương ứng](#{anchor})"
        return f"[nội dung liên quan](#{anchor})"

    text = re.sub(r"@([A-Za-z0-9:_-]+)", reference, text)
    text = re.sub(r"(?<!\\)\*([^*\n]+)\*", r"**\1**", text)
    text = text.replace(r"\_", "_").replace(r"\#", "#")
    return text.strip()


def extract_named_group(body: str, name: str, opener: str = "(", closer: str = ")") -> str | None:
    match = re.search(rf"\b{re.escape(name)}\s*:\s*\{opener}", body)
    if not match:
        return None
    start = match.end() - 1
    end = matching_delimiter(body, start, opener, closer)
    return body[start + 1 : end]


def bracket_items(text: str) -> list[str]:
    items: list[str] = []
    index = 0
    while index < len(text):
        if text[index] == "[":
            end = matching_delimiter(text, index, "[", "]")
            items.append(text[index + 1 : end])
            index = end + 1
        else:
            index += 1
    return items


def row_groups(rows: str) -> list[str]:
    groups: list[str] = []
    index = 0
    while index < len(rows):
        if rows[index] == "(":
            end = matching_delimiter(rows, index, "(", ")")
            groups.append(rows[index + 1 : end])
            index = end + 1
        else:
            index += 1
    return groups


def table_markdown(body: str, trailing_label: str | None) -> str:
    header_group = extract_named_group(body, "header") or ""
    rows_group = extract_named_group(body, "rows") or ""
    headers = [inline(value) for value in bracket_items(header_group)]
    rows = [[inline(value) for value in bracket_items(group)] for group in row_groups(rows_group)]
    width = max([len(headers), *(len(row) for row in rows)], default=0)
    if not width:
        return ""
    if not headers:
        headers = [f"Cột {index}" for index in range(1, width + 1)]
    headers += [""] * (width - len(headers))
    normalized_rows = [row + [""] * (width - len(row)) for row in rows]

    def cell(value: str) -> str:
        return re.sub(r"\s*\n\s*", "<br>", value).replace("|", r"\|")

    if not trailing_label:
        label_match = re.search(r"\bfigure-label\s*:\s*<([^>]+)>", body)
        if label_match:
            trailing_label = label_match.group(1)

    lines: list[str] = []
    if trailing_label:
        lines.append(f'<div id="{label_id(trailing_label)}"></div>')
        lines.append("")
    lines.append("| " + " | ".join(cell(value) for value in headers) + " |")
    lines.append("| " + " | ".join("---" for _ in headers) + " |")
    lines.extend("| " + " | ".join(cell(value) for value in row) + " |" for row in normalized_rows)

    caption_match = re.search(r"\bcaption\s*:\s*\[", body)
    if caption_match:
        start = caption_match.end() - 1
        end = matching_delimiter(body, start, "[", "]")
        lines.extend(("", f"*{inline(body[start + 1:end])}*"))
    return "\n".join(lines)


def note_markdown(body: str) -> str:
    converted = inline(body.strip())
    title = "Ghi chú"
    kind = "note"
    title_match = re.match(r"\*\*([^*]+?)\*\*:?\s*", converted)
    if title_match:
        title = title_match.group(1).rstrip(":")
        converted = converted[title_match.end() :].lstrip()
    title_key = title.casefold()
    if "cảnh báo" in title_key:
        kind = "warning"
    elif "quan trọng" in title_key or "giới hạn" in title_key:
        kind = "important"
    elif "mẹo" in title_key:
        kind = "tip"
    body_lines = converted.splitlines() or [""]
    return f'!!! {kind} "{title}"\n\n' + "\n".join(f"    {line}" for line in body_lines)


def image_markdown(body: str, trailing_label: str | None) -> str:
    path_match = re.search(r'^\s*"([^"]+)"', body)
    if not path_match:
        raise ValueError("insert-image is missing its path")
    path = "../" + path_match.group(1)
    caption = "Minh họa giao diện CAMS"
    caption_match = re.search(r"\bcaption\s*:\s*\[", body)
    if caption_match:
        start = caption_match.end() - 1
        end = matching_delimiter(body, start, "[", "]")
        caption = inline(body[start + 1 : end]).rstrip(".")
    identifier = label_id(trailing_label) if trailing_label else ""
    id_attr = f' id="{identifier}"' if identifier else ""
    return (
        f'<figure{id_attr} markdown="span">\n'
        f"  ![{caption}]({path}){{ loading=lazy }}\n"
        f"  <figcaption>{caption}.</figcaption>\n"
        "</figure>"
    )


def flow_markdown(body: str) -> str:
    nodes = [inline(item) for item in bracket_items(body)]
    return "**Quy trình làm việc:** " + " → ".join(nodes) + "."


def invocation(text: str, start: int, name: str, opener: str, closer: str) -> tuple[str, int, str | None]:
    open_at = start + len(name) + 1
    while open_at < len(text) and text[open_at].isspace():
        open_at += 1
    if text[open_at] != opener:
        raise ValueError(f"Expected {opener!r} after #{name}")
    end = matching_delimiter(text, open_at, opener, closer)
    cursor = end + 1
    while cursor < len(text) and text[cursor] in " \t":
        cursor += 1
    trailing_label = None
    if cursor < len(text) and text[cursor] == "<":
        label_end = text.find(">", cursor + 1)
        if label_end != -1:
            trailing_label = text[cursor + 1 : label_end]
            cursor = label_end + 1
    return text[open_at + 1 : end], cursor, trailing_label


def convert(source: str, source_name: str) -> str:
    output: list[str] = [
        f"<!-- Đồng bộ tự động từ ../contents/{source_name}; chạy scripts/sync_book_markdown.py để cập nhật. -->",
        "",
    ]
    index = 0
    line_start = True
    in_fence = False
    while index < len(source):
        if line_start and source.startswith("//", index):
            newline = source.find("\n", index)
            index = len(source) if newline == -1 else newline + 1
            line_start = True
            continue
        if line_start and source.startswith("#import", index):
            newline = source.find("\n", index)
            index = len(source) if newline == -1 else newline + 1
            line_start = True
            continue
        if line_start and source.startswith("```", index):
            in_fence = not in_fence
        if not in_fence and source[index] == "#":
            matched = False
            for name, opener, closer, renderer in (
                ("report-note", "[", "]", lambda body, _label: note_markdown(body)),
                ("insert-image", "(", ")", image_markdown),
                ("report-table", "(", ")", table_markdown),
                ("flow-diagram", "(", ")", lambda body, _label: flow_markdown(body)),
                ("front-heading", "[", "]", lambda body, _label: f"# {inline(body)}"),
                ("align", "(", ")", None),
            ):
                token = "#" + name
                if not source.startswith(token, index):
                    continue
                if name == "align":
                    # The only alignment call in the manual is #align(right)[...].
                    _, after_args, _ = invocation(source, index, name, opener, closer)
                    while after_args < len(source) and source[after_args].isspace():
                        after_args += 1
                    if after_args < len(source) and source[after_args] == "[":
                        end = matching_delimiter(source, after_args, "[", "]")
                        rendered = f'<div align="right">\n\n{inline(source[after_args + 1:end])}\n\n</div>'
                        cursor = end + 1
                    else:
                        rendered = ""
                        cursor = after_args
                else:
                    body, cursor, trailing_label = invocation(source, index, name, opener, closer)
                    rendered = renderer(body, trailing_label) if renderer else ""
                output.append(rendered)
                index = cursor
                line_start = False
                matched = True
                break
            if matched:
                continue
        newline = source.find("\n", index)
        if newline == -1:
            line = source[index:]
            index = len(source)
        else:
            line = source[index:newline]
            index = newline + 1
        if not in_fence:
            heading = re.match(r"^(={1,3})\s+(.+?)(?:\s+<[A-Za-z0-9:_-]+>)?$", line)
            if heading:
                line = "#" * len(heading.group(1)) + " " + inline(heading.group(2))
            elif line.startswith("+ "):
                line = "1. " + inline(line[2:])
            else:
                line = inline(line) if line.strip() else ""
        output.append(line)
        line_start = True

    result = "\n".join(output)
    result = re.sub(r"\n{3,}", "\n\n", result).strip() + "\n"
    return result


def paired_files() -> list[tuple[Path, Path]]:
    pairs: list[tuple[Path, Path]] = []
    for typst_path in sorted(TYPST_DIR.glob("*.typ")):
        number = typst_path.name[:2]
        markdown_matches = list(MARKDOWN_DIR.glob(f"{number}_*.md"))
        if len(markdown_matches) != 1:
            raise RuntimeError(f"Expected one Markdown target for {typst_path.name}")
        pairs.append((typst_path, markdown_matches[0]))
    return pairs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report stale Markdown without writing files")
    args = parser.parse_args()

    stale: list[Path] = []
    for typst_path, markdown_path in paired_files():
        expected = convert(typst_path.read_text(encoding="utf-8"), typst_path.name)
        current = markdown_path.read_text(encoding="utf-8")
        if current == expected:
            continue
        stale.append(markdown_path)
        if not args.check:
            markdown_path.write_text(expected, encoding="utf-8")

    if stale:
        action = "Cần đồng bộ" if args.check else "Đã đồng bộ"
        print(f"{action} {len(stale)} file Markdown:")
        for path in stale:
            print(path.relative_to(ROOT))
        return 1 if args.check else 0
    print("20 chương Markdown đã đồng bộ với nguồn Typst.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
