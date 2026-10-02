#!/usr/bin/env python3
"""Template email HTML cho cảnh báo syslog Cisco (theo level 0-7) + gửi thử.

Nội dung email được dựng hoàn toàn từ 1 dict bản ghi log (các khóa giống cột của bảng
t12_syslog_messages), KHÔNG truy cập database. Ở đây dùng dữ liệu mẫu để demo.

Dùng thử:
    python3 mail_templates_demo.py --preview            # chỉ tạo file HTML xem trước ở ./preview/
    python3 mail_templates_demo.py                      # gửi mail thử level 0,1,2 (mỗi level 1 mail)
    python3 mail_templates_demo.py --levels 0-7         # gửi đủ 8 level
    python3 mail_templates_demo.py --levels 1,2 --digest   # gom thành 1 mail tổng hợp

Mật khẩu: đặt GMAIL_APP_PASSWORD hoặc script sẽ hỏi khi chạy.

Tích hợp vào alert.py: thay đoạn dựng msg bằng
    subject, text, html_body = render_email(list_of_records)
    msg.set_content(text); msg.add_alternative(html_body, subtype="html")
"""

import argparse
import getpass
import html
import os
import smtplib
import socket
import sys
import time
from email.message import EmailMessage
from pathlib import Path

# ----------------------------------------------------------------------------
# Giao diện theo level: màu, nhãn, gợi ý hành động. Gom thành 3 nhóm.
# ----------------------------------------------------------------------------
GROUPS = {
    "critical": "NHÓM NGHIÊM TRỌNG (LEVEL 0-2)",
    "warning": "NHÓM LỖI / CẢNH BÁO (LEVEL 3-4)",
    "info": "NHÓM THÔNG TIN (LEVEL 5-7)",
}

THEMES = {
    0: dict(name="EMERGENCY", vi="Khẩn cấp", color="#7f1d1d", soft="#fef2f2", group="critical",
            action="Hệ thống không thể sử dụng. Cần xử lý ngay lập tức."),
    1: dict(name="ALERT", vi="Báo động", color="#b91c1c", soft="#fef2f2", group="critical",
            action="Cần hành động ngay để tránh gián đoạn dịch vụ."),
    2: dict(name="CRITICAL", vi="Nghiêm trọng", color="#c2410c", soft="#fff7ed", group="critical",
            action="Tình trạng nghiêm trọng, nên kiểm tra thiết bị sớm."),
    3: dict(name="ERROR", vi="Lỗi", color="#d97706", soft="#fffbeb", group="warning",
            action="Có lỗi xảy ra, cần theo dõi và xử lý."),
    4: dict(name="WARNING", vi="Cảnh báo", color="#a16207", soft="#fefce8", group="warning",
            action="Dấu hiệu bất thường, nên kiểm tra khi có thể."),
    5: dict(name="NOTICE", vi="Chú ý", color="#2563eb", soft="#eff6ff", group="info",
            action="Sự kiện bình thường nhưng đáng chú ý."),
    6: dict(name="INFO", vi="Thông tin", color="#0f766e", soft="#f0fdfa", group="info",
            action="Thông tin hoạt động, không cần xử lý."),
    7: dict(name="DEBUG", vi="Gỡ lỗi", color="#4b5563", soft="#f3f4f6", group="info",
            action="Thông điệp gỡ lỗi, thường chỉ dùng khi chẩn đoán."),
}


def esc(v):
    return html.escape("" if v is None else str(v))


def cisco_code(r):
    """%FACILITY-SUBFACILITY-SEVERITY-MNEMONIC, bỏ phần nào không có."""
    if not r.get("cisco_facility"):
        return ""
    parts = [r["cisco_facility"]]
    if r.get("cisco_subfacility"):
        parts.append(r["cisco_subfacility"])
    parts.append(str(r["severity"]))
    if r.get("mnemonic"):
        parts.append(r["mnemonic"])
    return "%" + "-".join(parts)


def _badge(sev):
    t = THEMES[sev]
    return (f'<span style="display:inline-block;padding:2px 10px;border-radius:10px;'
            f'background:{t["color"]};color:#ffffff;font-size:12px;font-weight:bold;'
            f'letter-spacing:0.5px;">LV {sev} · {t["name"]}</span>')


def _rows(r):
    clock = "Chưa đồng bộ (*)" if r.get("clock_unsynchronized") else "Đồng bộ"
    items = [
        ("Thiết bị", r.get("device_host")),
        ("IP nguồn", r.get("source_ip")),
        ("Giờ thiết bị", r.get("device_time")),
        ("Giờ nhận", r.get("received_at")),
        ("Số thứ tự", r.get("sequence_number")),
        ("Đồng hồ", clock),
        ("Mã Cisco", cisco_code(r)),
        ("Giao thức", (r.get("protocol") or "").upper()),
        ("PRI / Facility", f'{r["syslog_pri"]} / {r["syslog_facility"]}'
         if r.get("syslog_pri") is not None else None),
    ]
    out = []
    for label, val in items:
        if val in (None, ""):
            continue
        out.append(
            '<tr>'
            f'<td style="padding:6px 12px 6px 0;color:#6b7280;font-size:13px;white-space:nowrap;'
            f'vertical-align:top;">{esc(label)}</td>'
            f'<td style="padding:6px 0;color:#111827;font-size:13px;font-weight:bold;'
            f'vertical-align:top;">{esc(val)}</td></tr>'
        )
    return "".join(out)


def _card(r):
    t = THEMES[r["severity"]]
    raw = ""
    if r.get("raw_message"):
        raw = (
            '<div style="margin-top:14px;font-size:12px;color:#6b7280;">Bản gốc (raw)</div>'
            '<div style="margin-top:4px;padding:10px 12px;background:#111827;color:#e5e7eb;'
            'border-radius:6px;font-family:Consolas,Menlo,monospace;font-size:12px;'
            f'line-height:1.5;word-break:break-all;">{esc(r["raw_message"])}</div>'
        )
    return (
        f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" '
        f'style="margin:0 0 16px 0;border:1px solid #e5e7eb;border-left:6px solid {t["color"]};'
        f'border-radius:8px;background:#ffffff;"><tr><td style="padding:16px 18px;">'
        f'{_badge(r["severity"])} '
        f'<span style="color:#6b7280;font-size:12px;">&nbsp;{esc(r.get("device_host"))}</span>'
        f'<div style="margin-top:12px;padding:12px 14px;background:{t["soft"]};border-radius:6px;'
        f'color:#111827;font-size:15px;line-height:1.5;">{esc(r.get("message"))}</div>'
        f'<table role="presentation" cellpadding="0" cellspacing="0" style="margin-top:12px;">'
        f'{_rows(r)}</table>{raw}</td></tr></table>'
    )


def _summary(records):
    head = ('<tr style="background:#f3f4f6;">'
            + "".join(f'<th align="left" style="padding:8px 10px;font-size:12px;color:#374151;">{h}</th>'
                      for h in ("Giờ nhận", "Thiết bị", "Level", "Mã Cisco"))
            + "</tr>")
    body = ""
    for r in records:
        body += (
            '<tr>'
            f'<td style="padding:8px 10px;font-size:12px;border-top:1px solid #e5e7eb;">{esc(r.get("received_at"))}</td>'
            f'<td style="padding:8px 10px;font-size:12px;border-top:1px solid #e5e7eb;">{esc(r.get("device_host"))}</td>'
            f'<td style="padding:8px 10px;border-top:1px solid #e5e7eb;">{_badge(r["severity"])}</td>'
            f'<td style="padding:8px 10px;font-size:12px;border-top:1px solid #e5e7eb;'
            f'font-family:Consolas,Menlo,monospace;">{esc(cisco_code(r))}</td></tr>'
        )
    return (
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" '
        'style="margin:0 0 16px 0;border:1px solid #e5e7eb;border-radius:8px;background:#ffffff;">'
        f'{head}{body}</table>'
    )


def render_email(records):
    """records: list[dict] (hoặc 1 dict). Trả về (subject, text, html)."""
    if isinstance(records, dict):
        records = [records]
    records = sorted(records, key=lambda r: r["severity"])
    worst = records[0]["severity"]
    t = THEMES[worst]

    if len(records) == 1:
        r = records[0]
        subject = f'[SYSLOG {t["name"]}] {r.get("device_host", "")} {cisco_code(r)}'.strip()
        title = f'LEVEL {worst} · {t["name"]} ({t["vi"]})'
        sub = f'{esc(r.get("device_host"))} · {esc(r.get("source_ip"))}'
    else:
        subject = f'[SYSLOG {t["name"]}] {len(records)} cảnh báo mới'
        title = f'{len(records)} cảnh báo · mức cao nhất LEVEL {worst} {t["name"]}'
        sub = "Tổng hợp các log nhận được gần đây"

    body_cards = (_summary(records) if len(records) > 1 else "") + "".join(_card(r) for r in records)

    html_body = f"""<!doctype html>
<html lang="vi"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{esc(subject)}</title></head>
<body style="margin:0;padding:0;background:#f3f4f6;font-family:Segoe UI,Roboto,Arial,sans-serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f3f4f6;">
<tr><td align="center" style="padding:24px 12px;">
  <table role="presentation" width="640" cellpadding="0" cellspacing="0" style="width:100%;max-width:640px;">
    <tr><td style="background:{t['color']};border-radius:10px 10px 0 0;padding:22px 24px;">
      <div style="color:#ffffff;opacity:0.85;font-size:11px;letter-spacing:1.5px;">SYSLOG ALERT · {GROUPS[t['group']]}</div>
      <div style="color:#ffffff;font-size:22px;font-weight:bold;margin-top:6px;">{esc(title)}</div>
      <div style="color:#ffffff;opacity:0.9;font-size:13px;margin-top:6px;">{sub}</div>
    </td></tr>
    <tr><td style="background:{t['soft']};padding:12px 24px;border-bottom:1px solid #e5e7eb;
        color:{t['color']};font-size:13px;font-weight:bold;">{esc(t['action'])}</td></tr>
    <tr><td style="background:#f9fafb;padding:20px 24px 8px 24px;">{body_cards}</td></tr>
    <tr><td style="background:#f9fafb;border-radius:0 0 10px 10px;padding:4px 24px 20px 24px;
        color:#9ca3af;font-size:11px;line-height:1.5;">
      Email tự động từ hệ thống giám sát syslog, vui lòng không trả lời.<br>
      (*) Đồng hồ thiết bị chưa đồng bộ NTP nên giờ thiết bị có thể không chính xác.
    </td></tr>
  </table>
</td></tr></table></body></html>"""

    lines = []
    for r in records:
        lines.append(
            f'[LV {r["severity"]} {THEMES[r["severity"]]["name"]}] {r.get("device_host")} '
            f'({r.get("source_ip")})\n  {cisco_code(r)}\n  {r.get("message")}\n'
            f'  Giờ nhận: {r.get("received_at")}\n'
        )
    text = f'{title}\n{t["action"]}\n\n' + "\n".join(lines)
    return subject, text, html_body


# ----------------------------------------------------------------------------
# Dữ liệu mẫu (không lấy từ DB)
# ----------------------------------------------------------------------------
_SAMPLES = {
    0: ("SW-CORE-01", "10.0.0.1", "SYS", None, "SYSTEM_HALT", "System halted due to unrecoverable hardware fault"),
    1: ("SW-CORE-01", "10.0.0.1", "SYS", None, "OVERTEMP", "System temperature exceeded threshold on slot 1"),
    2: ("RT-EDGE-02", "10.0.0.2", "SYS", None, "MALLOCFAIL", "Memory allocation of 65536 bytes failed from process IP Input"),
    3: ("SW-ACC-05", "10.0.1.5", "LINK", None, "UPDOWN", "Interface GigabitEthernet0/1, changed state to down"),
    4: ("SW-ACC-05", "10.0.1.5", "PM", None, "ERR_DISABLE", "bpduguard error detected on Gi0/12, putting Gi0/12 in err-disable state"),
    5: ("SW-ACC-06", "10.0.1.6", "LINEPROTO", None, "UPDOWN", "Line protocol on Interface GigabitEthernet0/1, changed state to up"),
    6: ("RT-EDGE-02", "10.0.0.2", "SYS", None, "CONFIG_I", "Configured from console by admin on vty0 (10.0.0.50)"),
    7: ("SW-ACC-06", "10.0.1.6", "SYS", None, "DEBUG_DEMO", "Debug message sample: IP packet processed, len 100"),
}


def sample_record(level, seq):
    host, ip, fac, sub, mnem, msg = _SAMPLES[level]
    pri = 23 * 8 + level  # local7
    now = time.strftime("%Y-%m-%d %H:%M:%S")
    dev_time = time.strftime("%b %d %Y %H:%M:%S")
    full = f"{cisco_code(dict(cisco_facility=fac, cisco_subfacility=sub, severity=level, mnemonic=mnem))}: {msg}"
    return dict(
        device_host=host, source_ip=ip, device_time=dev_time, sequence_number=seq,
        clock_unsynchronized=1 if level == 4 else 0, received_at=now,
        syslog_pri=pri, syslog_facility=23, cisco_facility=fac, cisco_subfacility=sub,
        severity=level, mnemonic=mnem, message=msg,
        raw_message=f"<{pri}>{seq}: {dev_time}: {full}", protocol="udp", parse_status="parsed",
    )


def parse_levels(s):
    out = set()
    for part in s.split(","):
        part = part.strip()
        if "-" in part:
            a, b = part.split("-", 1)
            out.update(range(int(a), int(b) + 1))
        elif part:
            out.add(int(part))
    bad = [x for x in out if x not in THEMES]
    if bad:
        raise ValueError(f"Level không hợp lệ: {bad} (chỉ 0-7)")
    return sorted(out)


def write_previews(levels, outdir="preview"):
    Path(outdir).mkdir(exist_ok=True)
    cells = []
    for i, lv in enumerate(levels, 1):
        subject, _, body = render_email(sample_record(lv, 1000 + i))
        (Path(outdir) / f"level_{lv}.html").write_text(body, encoding="utf-8")
        cells.append(
            f'<div style="margin:0 0 24px 0;"><div style="font:bold 13px sans-serif;margin:0 0 6px 0;">'
            f'Level {lv} · {esc(subject)}</div>'
            f'<iframe style="width:100%;height:640px;border:1px solid #ccc;background:#fff;" '
            f'srcdoc="{html.escape(body, quote=True)}"></iframe></div>'
        )
    digest = render_email([sample_record(lv, 2000 + lv) for lv in levels])
    (Path(outdir) / "digest.html").write_text(digest[2], encoding="utf-8")
    cells.append(
        f'<div><div style="font:bold 13px sans-serif;margin:0 0 6px 0;">Mail tổng hợp (digest) · '
        f'{esc(digest[0])}</div><iframe style="width:100%;height:1100px;border:1px solid #ccc;'
        f'background:#fff;" srcdoc="{html.escape(digest[2], quote=True)}"></iframe></div>'
    )
    index = ('<!doctype html><meta charset="utf-8"><title>Xem trước template</title>'
             '<body style="margin:0;padding:20px;background:#e5e7eb;">' + "".join(cells) + "</body>")
    (Path(outdir) / "index.html").write_text(index, encoding="utf-8")
    return Path(outdir)


def send(records, sender, password, to):
    subject, text, html_body = render_email(records)
    msg = EmailMessage()
    msg["From"] = sender
    msg["To"] = to
    msg["Subject"] = "[DEMO] " + subject
    msg.set_content(text)
    msg.add_alternative(html_body, subtype="html")
    with smtplib.SMTP_SSL("smtp.gmail.com", 465, timeout=20) as server:
        server.login(sender, password)
        server.send_message(msg)
    return msg["Subject"]


def main():
    ap = argparse.ArgumentParser(description="Template email syslog + gửi thử")
    ap.add_argument("--levels", default="0-2", help='vd "0-2", "0,3,5", "0-7" (mặc định 0-2)')
    ap.add_argument("--digest", action="store_true", help="gom các level thành 1 mail tổng hợp")
    ap.add_argument("--preview", action="store_true", help="chỉ tạo file HTML xem trước, không gửi")
    ap.add_argument("--to", default=os.environ.get("MAIL_TO", "nguyenquocviet15t12@gmail.com"))
    ap.add_argument("--sender", default=os.environ.get("GMAIL_USER", "cams.syslog.alert@gmail.com"))
    a = ap.parse_args()

    levels = parse_levels(a.levels)

    if a.preview:
        out = write_previews(levels if a.levels != "0-2" else list(range(8)))
        print(f"Đã tạo xem trước trong {out}/ (mở {out}/index.html bằng trình duyệt)")
        return

    password = (os.environ.get("GMAIL_APP_PASSWORD")
                or getpass.getpass(f"App Password của {a.sender} (gõ sẽ không hiện): ")).replace(" ", "")
    batches = ([[sample_record(lv, 3000 + lv) for lv in levels]] if a.digest
               else [[sample_record(lv, 3000 + lv)] for lv in levels])
    try:
        for i, recs in enumerate(batches):
            if i:
                time.sleep(1)
            print("Đã gửi:", send(recs, a.sender, password, a.to))
    except smtplib.SMTPAuthenticationError:
        sys.exit("LỖI đăng nhập: sai App Password hoặc chưa bật xác minh 2 bước.")
    except (socket.timeout, TimeoutError, ConnectionError, OSError) as e:
        sys.exit(f"LỖI kết nối smtp.gmail.com:465: {e}")
    except smtplib.SMTPException as e:
        sys.exit(f"LỖI SMTP: {e}")
    print(f"Xong, {len(batches)} mail gửi tới {a.to}. Kiểm tra cả mục Spam.")


if __name__ == "__main__":
    main()
