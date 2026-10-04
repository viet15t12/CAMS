#!/usr/bin/env python3
"""term2png.py - Xuất nội dung terminal (kiểu GNOME Console) thành ảnh PNG sắc nét.

Giao diện: thanh tiêu đề GNOME (nút "+", tiêu đề + phụ đề ở giữa, nút lưới/menu/
thu nhỏ/phóng to/đóng bên phải), nền tối, con trỏ khối trắng.
Hỗ trợ nội dung Cisco IOS: ký tự backspace (\\x08) và \\r của "--More--" được xử lý
đúng như terminal thật, nên log copy/ghi lại từ console không bị rác.

Cách dùng (CLI):
    python3 term2png.py -i output.txt -t "Terminal" -o ketqua.png
    cat output.txt | python3 term2png.py -t "R1 - console" --subtitle "~" -o r1.png
    ls --color=always -l | python3 term2png.py -o ls.png

Cách dùng (import):
    from term2png import render_terminal
    render_terminal(text, "Terminal", "out.png", subtitle="~", scale=3)

Cài đặt: pip install pillow
"""
import argparse
import os
import re
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SS = 2  # siêu lấy mẫu: vẽ gấp SS lần rồi thu nhỏ cho mịn cạnh

THEMES = {
    "dark": dict(body=(28, 28, 31), fg=(255, 255, 255), header=(46, 46, 50),
                 btn=(66, 66, 70), icon=(255, 255, 255), title=(255, 255, 255),
                 subtitle=(160, 160, 166), edge=(20, 20, 23), cursor=(255, 255, 255)),
    "light": dict(body=(255, 255, 255), fg=(23, 20, 33), header=(235, 235, 237),
                  btn=(220, 220, 224), icon=(46, 52, 54), title=(46, 52, 54),
                  subtitle=(110, 110, 116), edge=(205, 205, 210), cursor=(23, 20, 33)),
}

# Bảng màu GNOME
ANSI16 = [
    (23, 20, 33), (192, 28, 40), (38, 162, 105), (162, 115, 76),
    (18, 72, 139), (163, 71, 186), (42, 161, 179), (208, 207, 204),
    (94, 92, 100), (246, 97, 81), (51, 218, 122), (233, 173, 12),
    (42, 123, 222), (192, 97, 203), (51, 199, 222), (255, 255, 255),
]

MONO_FAMILIES = ["DejaVu Sans Mono", "Liberation Mono", "Noto Sans Mono", "Source Code Pro"]
SANS_FAMILIES = ["Adwaita Sans", "Cantarell", "Inter", "Noto Sans", "DejaVu Sans"]
FALLBACK = {
    ("mono", False): ["/usr/share/fonts/dejavu-sans-mono-fonts/DejaVuSansMono.ttf",
                      "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
                      "/usr/share/fonts/TTF/DejaVuSansMono.ttf"],
    ("mono", True): ["/usr/share/fonts/dejavu-sans-mono-fonts/DejaVuSansMono-Bold.ttf",
                     "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf",
                     "/usr/share/fonts/TTF/DejaVuSansMono-Bold.ttf"],
    ("sans", False): ["/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf",
                      "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
                      "/usr/share/fonts/TTF/DejaVuSans.ttf"],
    ("sans", True): ["/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf",
                     "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                     "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"],
}


def _fc(pattern):
    try:
        out = subprocess.run(["fc-match", "-f", "%{family}|%{file}", pattern],
                             capture_output=True, text=True, timeout=5).stdout.strip()
        fam, _, path = out.partition("|")
        return fam, path
    except Exception:
        return "", ""


def find_font(kind, bold, families):
    for fam in families:
        got, path = _fc(f"{fam}:bold" if bold else fam)
        if path and fam.lower() in got.lower() and os.path.exists(path):
            return path
    for path in FALLBACK[(kind, bold)]:
        if os.path.exists(path):
            return path
    return None


def load_font(path, size):
    size = int(size)
    if path:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            pass
    try:
        return ImageFont.load_default(size)
    except TypeError:
        return ImageFont.load_default()


def color256(n):
    if n < 16:
        return ANSI16[n]
    if n < 232:
        n -= 16
        lv = [0, 95, 135, 175, 215, 255]
        return lv[n // 36], lv[(n // 6) % 6], lv[n % 6]
    g = 8 + (n - 232) * 10
    return g, g, g


ESC_RE = re.compile(r"\x1b\[([0-9;?]*)([A-Za-z])|\x1b\].*?(?:\x07|\x1b\\)|\x1b[()][A-Za-z0-9]")
BLANK = (" ", None, None, False, False)


def parse_ansi(text, default_fg):
    """Mô phỏng terminal: trả về list dòng, mỗi dòng là list ô (ký tự, fg, bg, bold, reverse).

    Xử lý \\n, \\r, \\b (backspace), tab, và các mã ANSI SGR/K/C/D/G thường gặp.
    """
    text = text.replace("\r\n", "\n")
    state = dict(fg=default_fg, bg=None, bold=False, rev=False)
    lines, cur, col = [], [], 0

    def put(ch):
        nonlocal col
        cell = (ch, state["fg"], state["bg"], state["bold"], state["rev"])
        while len(cur) < col:
            cur.append(BLANK)
        if col < len(cur):
            cur[col] = cell
        else:
            cur.append(cell)
        col += 1

    def feed(chunk):
        nonlocal cur, col
        for ch in chunk:
            if ch == "\n":
                lines.append(cur)
                cur, col = [], 0
            elif ch == "\r":
                col = 0
            elif ch == "\b":
                col = max(0, col - 1)
            elif ch == "\t":
                put(" ")
                while col % 8:
                    put(" ")
            elif ch < " " or ch == "\x7f":
                continue
            else:
                put(ch)

    def sgr(codes):
        i = 0
        while i < len(codes):
            c = codes[i]
            if c == 0:
                state.update(fg=default_fg, bg=None, bold=False, rev=False)
            elif c == 1:
                state["bold"] = True
            elif c == 22:
                state["bold"] = False
            elif c == 7:
                state["rev"] = True
            elif c == 27:
                state["rev"] = False
            elif 30 <= c <= 37:
                state["fg"] = ANSI16[c - 30]
            elif 90 <= c <= 97:
                state["fg"] = ANSI16[c - 90 + 8]
            elif c == 39:
                state["fg"] = default_fg
            elif 40 <= c <= 47:
                state["bg"] = ANSI16[c - 40]
            elif 100 <= c <= 107:
                state["bg"] = ANSI16[c - 100 + 8]
            elif c == 49:
                state["bg"] = None
            elif c in (38, 48) and i + 1 < len(codes):
                colr = None
                if codes[i + 1] == 5 and i + 2 < len(codes):
                    colr = color256(codes[i + 2])
                    i += 2
                elif codes[i + 1] == 2 and i + 4 < len(codes):
                    colr = tuple(codes[i + 2:i + 5])
                    i += 4
                if colr:
                    state["fg" if c == 38 else "bg"] = colr
            i += 1

    pos = 0
    for m in ESC_RE.finditer(text):
        feed(text[pos:m.start()])
        pos = m.end()
        final = m.group(2)
        if not final:
            continue
        params = [int(p) if p.isdigit() else 0 for p in (m.group(1) or "").split(";")]
        n = params[0] if params and params[0] else 1
        if final == "m":
            sgr(params or [0])
        elif final == "K":
            mode = params[0] if params else 0
            if mode == 0:
                del cur[col:]
            elif mode == 1:
                for j in range(min(col, len(cur))):
                    cur[j] = BLANK
            else:
                cur.clear()
        elif final == "C":
            col += n
        elif final == "D":
            col = max(0, col - n)
        elif final == "G":
            col = max(0, n - 1)
    feed(text[pos:])
    lines.append(cur)

    for ln in lines:  # bỏ khoảng trắng thừa cuối dòng
        while ln and ln[-1][0] == " " and ln[-1][2] is None and not ln[-1][4]:
            ln.pop()
    while len(lines) > 1 and not lines[-1] and not lines[-2]:
        lines.pop()
    return lines


def _up(v, m=SS):
    return int(-(-v // m) * m)


def _lerp(a, b, f):
    return tuple(int(a[i] + (b[i] - a[i]) * f) for i in range(3))


def render_terminal(text, title="Terminal", out="terminal.png", subtitle="~",
                    scale=3, font_size=15, theme="dark", shadow=False,
                    cursor=True, max_cols=None, cols=None, font=None):
    t = THEMES[theme]
    u = scale * SS  # 1 "đơn vị" giao diện tính bằng pixel

    mono_path = font if (font and os.path.exists(font)) else (
        find_font("mono", False, [font] + MONO_FAMILIES if font else MONO_FAMILIES))
    bold_path = find_font("mono", True, MONO_FAMILIES) if not font else (
        find_font("mono", True, [font] + MONO_FAMILIES))
    mono = load_font(mono_path, font_size * u)
    bmono = load_font(bold_path or mono_path, font_size * u)
    tfont = load_font(find_font("sans", True, SANS_FAMILIES), 15 * u)
    sfont = load_font(find_font("sans", False, SANS_FAMILIES), 11 * u)

    lines = parse_ansi(text, t["fg"])
    if max_cols:
        wrapped = []
        for ln in lines:
            if not ln:
                wrapped.append(ln)
            for j in range(0, len(ln), max_cols):
                wrapped.append(ln[j:j + max_cols])
        lines = wrapped

    cw = mono.getlength("M")
    asc, desc = mono.getmetrics()
    lh = int((asc + desc) * 1.15)
    pad = 14 * u
    head_h = 48 * u

    n_cols = cols or (max(len(ln) for ln in lines) + (1 if cursor else 0))
    tw = tfont.getlength(title) if title else 0
    win_w = _up(max(n_cols * cw + 2 * pad, 560 * u, tw + 2 * 210 * u))
    win_h = _up(head_h + len(lines) * lh + 2 * pad)

    win = Image.new("RGB", (win_w, win_h), t["body"])
    d = ImageDraw.Draw(win)

    # --- thanh tiêu đề -----------------------------------------------------
    d.rectangle([0, 0, win_w, head_h], fill=t["header"])
    glow = 6 * u  # bóng mờ ngay dưới thanh tiêu đề
    for i in range(glow):
        d.line([(0, head_h + i), (win_w, head_h + i)],
               fill=_lerp(t["edge"], t["body"], i / glow))
    cy = head_h / 2
    ic, w2 = t["icon"], 2 * u

    # nút "+" (tab mới)
    cx = 23 * u
    d.rounded_rectangle([cx - 8 * u, cy - 8 * u, cx + 8 * u, cy + 8 * u], 4 * u, outline=ic, width=w2)
    d.line([(cx - 4 * u, cy), (cx + 4 * u, cy)], fill=ic, width=w2)
    d.line([(cx, cy - 4 * u), (cx, cy + 4 * u)], fill=ic, width=w2)

    # tiêu đề + phụ đề
    mid = win_w / 2
    if title and subtitle:
        d.text((mid, head_h * 0.385), title, font=tfont, fill=t["title"], anchor="mm")
        d.text((mid, head_h * 0.73), subtitle, font=sfont, fill=t["subtitle"], anchor="mm")
    elif title:
        d.text((mid, cy), title, font=tfont, fill=t["title"], anchor="mm")

    # nút cửa sổ (thu nhỏ, phóng to, đóng)
    r = 13 * u
    for off, kind in ((97, "min"), (60, "max"), (23, "close")):
        bx = win_w - off * u
        d.ellipse([bx - r, cy - r, bx + r, cy + r], fill=t["btn"])
        if kind == "min":
            d.line([(bx - 4 * u, cy + 3 * u), (bx + 4 * u, cy + 3 * u)], fill=ic, width=w2)
        elif kind == "max":
            d.rounded_rectangle([bx - 4 * u, cy - 4 * u, bx + 4 * u, cy + 4 * u], u, outline=ic, width=w2)
        else:
            d.line([(bx - 4 * u, cy - 4 * u), (bx + 4 * u, cy + 4 * u)], fill=ic, width=w2)
            d.line([(bx - 4 * u, cy + 4 * u), (bx + 4 * u, cy - 4 * u)], fill=ic, width=w2)

    # menu (ba gạch)
    mx = win_w - 137 * u
    for dy in (-5, 0, 5):
        d.line([(mx - 7 * u, cy + dy * u), (mx + 7 * u, cy + dy * u)], fill=ic, width=w2)

    # nút lưới (tổng quan tab)
    gx = win_w - 177 * u
    for ox in (-7, 1):
        for oy in (-7, 1):
            d.rounded_rectangle([gx + ox * u, cy + oy * u, gx + (ox + 6) * u, cy + (oy + 6) * u],
                                1.5 * u, fill=ic)

    # --- nội dung ----------------------------------------------------------
    y = head_h + pad
    for ln in lines:
        x = pad
        for ch, fg, bg, bold, rev in ln:
            if rev:
                fg, bg = (bg or t["body"]), fg
            if bg and bg != t["body"]:
                d.rectangle([x, y, x + cw, y + lh], fill=bg)
            if ch != " ":
                base = y + (lh - asc - desc) / 2 + asc
                d.text((x, base), ch, font=bmono if bold else mono, fill=fg, anchor="ls")
            x += cw
        y += lh

    if cursor:
        last = lines[-1]
        cx0 = pad + len(last) * cw
        cy0 = head_h + pad + (len(lines) - 1) * lh
        d.rectangle([cx0, cy0, cx0 + cw, cy0 + lh], fill=t["cursor"])

    # --- hoàn thiện --------------------------------------------------------
    if shadow:
        margin, radius = 30 * u, 12 * u
        W, H = win_w + 2 * margin, win_h + 2 * margin
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle(
            [margin, margin + 8 * u, margin + win_w, margin + win_h + 8 * u],
            radius, fill=(0, 0, 0, 110))
        img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(14 * u)))
        mask = Image.new("L", (win_w, win_h), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, win_w - 1, win_h - 1], radius, fill=255)
        img.paste(win, (margin, margin), mask)
    else:
        img = win

    img = img.resize((img.width // SS, img.height // SS), Image.LANCZOS)
    img.save(out, dpi=(96 * scale, 96 * scale))
    return out


def main():
    ap = argparse.ArgumentParser(description="Xuất terminal ra ảnh PNG sắc nét (kiểu GNOME Console)")
    ap.add_argument("-t", "--title", default="Terminal", help="tiêu đề cửa sổ")
    ap.add_argument("--subtitle", default="~", help="phụ đề dưới tiêu đề (rỗng để ẩn)")
    ap.add_argument("-i", "--input", help="file chứa nội dung (mặc định: stdin)")
    ap.add_argument("-o", "--output", default="terminal.png")
    ap.add_argument("-s", "--scale", type=int, default=3, help="độ phân giải x (mặc định 3)")
    ap.add_argument("-f", "--font-size", type=int, default=15)
    ap.add_argument("--font", help="đường dẫn hoặc tên font monospace")
    ap.add_argument("--theme", choices=THEMES, default="dark")
    ap.add_argument("--shadow", action="store_true", help="bo góc + đổ bóng (cửa sổ nổi)")
    ap.add_argument("--no-cursor", action="store_true", help="không vẽ con trỏ khối")
    ap.add_argument("--wrap", type=int, help="tự xuống dòng sau N cột")
    ap.add_argument("--cols", type=int, help="cố định bề rộng N cột")
    a = ap.parse_args()

    text = open(a.input, encoding="utf-8", errors="replace").read() if a.input else sys.stdin.read()
    render_terminal(text, a.title, a.output, a.subtitle, a.scale, a.font_size, a.theme,
                    a.shadow, not a.no_cursor, a.wrap, a.cols, a.font)
    print(f"Đã lưu: {a.output}")


if __name__ == "__main__":
    main()
