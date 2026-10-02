"""Responsive bilingual HTML/text templates for Cisco Syslog alerts."""

from __future__ import annotations

import html
from typing import Any


THEMES: dict[int, dict[str, str]] = {
    0: {"name": "EMERGENCY", "vi": "KHẨN CẤP", "color": "#7f1d1d", "soft": "#fef2f2"},
    1: {"name": "ALERT", "vi": "BÁO ĐỘNG", "color": "#b91c1c", "soft": "#fef2f2"},
    2: {"name": "CRITICAL", "vi": "NGHIÊM TRỌNG", "color": "#c2410c", "soft": "#fff7ed"},
    3: {"name": "ERROR", "vi": "LỖI", "color": "#d97706", "soft": "#fffbeb"},
    4: {"name": "WARNING", "vi": "CẢNH BÁO", "color": "#a16207", "soft": "#fefce8"},
    5: {"name": "NOTICE", "vi": "CHÚ Ý", "color": "#2563eb", "soft": "#eff6ff"},
    6: {"name": "INFO", "vi": "THÔNG TIN", "color": "#0f766e", "soft": "#f0fdfa"},
    7: {"name": "DEBUG", "vi": "GỠ LỖI", "color": "#4b5563", "soft": "#f3f4f6"},
}

_ACTIONS = {
    "en": (
        "The system is unusable. Immediate action is required.",
        "Take action immediately to prevent service disruption.",
        "A critical condition was detected. Check the device promptly.",
        "An error occurred and should be investigated.",
        "An unusual condition was detected. Review it when possible.",
        "A normal but significant event was reported.",
        "Operational information; no immediate action is required.",
        "Diagnostic information, normally used during troubleshooting.",
    ),
    "vi": (
        "Hệ thống không thể sử dụng. Cần xử lý ngay lập tức.",
        "Cần hành động ngay để tránh gián đoạn dịch vụ.",
        "Phát hiện tình trạng nghiêm trọng. Hãy kiểm tra thiết bị sớm.",
        "Đã xảy ra lỗi, cần theo dõi và xử lý.",
        "Phát hiện dấu hiệu bất thường. Hãy kiểm tra khi có thể.",
        "Sự kiện bình thường nhưng đáng chú ý.",
        "Thông tin hoạt động; không cần xử lý ngay.",
        "Thông tin chẩn đoán, thường chỉ dùng khi xử lý sự cố.",
    ),
}

_LABELS = {
    "en": {
        "alert": "SYSLOG ALERT",
        "new": "new alerts",
        "highest": "highest severity",
        "summary": "Recent Syslog alerts",
        "received": "Received",
        "device": "Device",
        "source": "Source IP",
        "device_time": "Device time",
        "sequence": "Sequence",
        "clock": "Clock",
        "synced": "Synchronized",
        "unsynced": "Not synchronized (*)",
        "code": "Cisco code",
        "protocol": "Protocol",
        "facility": "PRI / Facility",
        "raw": "Original message (raw)",
        "automatic": "This is an automated Syslog monitoring email. Please do not reply.",
        "note": "(*) The device clock is not synchronized with NTP, so its timestamp may be inaccurate.",
    },
    "vi": {
        "alert": "CẢNH BÁO SYSLOG",
        "new": "cảnh báo mới",
        "highest": "mức cao nhất",
        "summary": "Tổng hợp các log nhận được gần đây",
        "received": "Giờ nhận",
        "device": "Thiết bị",
        "source": "IP nguồn",
        "device_time": "Giờ thiết bị",
        "sequence": "Số thứ tự",
        "clock": "Đồng hồ",
        "synced": "Đồng bộ",
        "unsynced": "Chưa đồng bộ (*)",
        "code": "Mã Cisco",
        "protocol": "Giao thức",
        "facility": "PRI / Facility",
        "raw": "Bản gốc (raw)",
        "automatic": "Email tự động từ hệ thống giám sát Syslog, vui lòng không trả lời.",
        "note": "(*) Đồng hồ thiết bị chưa đồng bộ NTP nên giờ thiết bị có thể không chính xác.",
    },
}


def _esc(value: Any) -> str:
    return html.escape("" if value is None else str(value))


def _header(value: Any) -> str:
    """Collapse untrusted log fields so they cannot inject mail headers."""
    return " ".join(str(value or "").splitlines()).strip()


def cisco_code(record: dict[str, Any]) -> str:
    facility = str(record.get("cisco_facility") or "").strip()
    if not facility:
        return ""
    parts = [facility]
    subfacility = str(record.get("cisco_subfacility") or "").strip()
    if subfacility:
        parts.append(subfacility)
    parts.append(str(_severity(record)))
    mnemonic = str(record.get("mnemonic") or "").strip()
    if mnemonic:
        parts.append(mnemonic)
    return "%" + "-".join(parts)


def _severity(record: dict[str, Any]) -> int:
    try:
        value = int(record.get("severity", 6))
    except (TypeError, ValueError):
        return 6
    return value if value in THEMES else 6


def _badge(severity: int, language: str) -> str:
    theme = THEMES[severity]
    name = theme["vi"] if language == "vi" else theme["name"]
    return (
        '<span style="display:inline-block;padding:2px 10px;border-radius:10px;'
        f'background:{theme["color"]};color:#fff;font-size:12px;font-weight:bold;'
        f'letter-spacing:.5px;">LV {severity} · {_esc(name)}</span>'
    )


def _detail_rows(record: dict[str, Any], language: str) -> str:
    labels = _LABELS[language]
    clock = labels["unsynced"] if record.get("clock_unsynchronized") else labels["synced"]
    pri = record.get("syslog_pri")
    facility = record.get("syslog_facility")
    items = (
        (labels["device"], record.get("device_host")),
        (labels["source"], record.get("source_ip")),
        (labels["device_time"], record.get("device_time")),
        (labels["received"], record.get("received_at")),
        (labels["sequence"], record.get("sequence_number")),
        (labels["clock"], clock),
        (labels["code"], cisco_code(record)),
        (labels["protocol"], str(record.get("protocol") or "").upper()),
        (labels["facility"], f"{pri} / {facility}" if pri is not None else None),
    )
    return "".join(
        '<tr>'
        f'<td style="padding:6px 12px 6px 0;color:#6b7280;font-size:13px;white-space:nowrap;vertical-align:top;">{_esc(label)}</td>'
        f'<td style="padding:6px 0;color:#111827;font-size:13px;font-weight:bold;vertical-align:top;">{_esc(value)}</td>'
        '</tr>'
        for label, value in items
        if value not in (None, "")
    )


def _card(record: dict[str, Any], language: str) -> str:
    severity = _severity(record)
    theme = THEMES[severity]
    labels = _LABELS[language]
    raw = ""
    if record.get("raw_message"):
        raw = (
            f'<div style="margin-top:14px;font-size:12px;color:#6b7280;">{_esc(labels["raw"])}</div>'
            '<div style="margin-top:4px;padding:10px 12px;background:#111827;color:#e5e7eb;'
            'border-radius:6px;font:12px/1.5 Consolas,Menlo,monospace;word-break:break-all;">'
            f'{_esc(record["raw_message"])}</div>'
        )
    return (
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" '
        f'style="margin:0 0 16px;border:1px solid #e5e7eb;border-left:6px solid {theme["color"]};'
        'border-radius:8px;background:#fff;"><tr><td style="padding:16px 18px;">'
        f'{_badge(severity, language)} '
        f'<span style="color:#6b7280;font-size:12px;">&nbsp;{_esc(record.get("device_host"))}</span>'
        f'<div style="margin-top:12px;padding:12px 14px;background:{theme["soft"]};border-radius:6px;'
        f'color:#111827;font-size:15px;line-height:1.5;">{_esc(record.get("message"))}</div>'
        '<table role="presentation" cellpadding="0" cellspacing="0" style="margin-top:12px;">'
        f'{_detail_rows(record, language)}</table>{raw}</td></tr></table>'
    )


def _summary(records: list[dict[str, Any]], language: str) -> str:
    labels = _LABELS[language]
    headings = (labels["received"], labels["device"], "Level", labels["code"])
    head = '<tr style="background:#f3f4f6;">' + "".join(
        f'<th align="left" style="padding:8px 10px;font-size:12px;color:#374151;">{_esc(value)}</th>'
        for value in headings
    ) + "</tr>"
    body = ""
    for record in records:
        severity = _severity(record)
        body += (
            '<tr>'
            f'<td style="padding:8px 10px;font-size:12px;border-top:1px solid #e5e7eb;">{_esc(record.get("received_at"))}</td>'
            f'<td style="padding:8px 10px;font-size:12px;border-top:1px solid #e5e7eb;">{_esc(record.get("device_host"))}</td>'
            f'<td style="padding:8px 10px;border-top:1px solid #e5e7eb;">{_badge(severity, language)}</td>'
            f'<td style="padding:8px 10px;font:12px Consolas,Menlo,monospace;border-top:1px solid #e5e7eb;">{_esc(cisco_code(record))}</td>'
            '</tr>'
        )
    return (
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" '
        'style="margin:0 0 16px;border:1px solid #e5e7eb;border-radius:8px;background:#fff;">'
        f'{head}{body}</table>'
    )


def render_email(
    records: dict[str, Any] | list[dict[str, Any]],
    language: str = "en",
    *,
    test: bool = False,
) -> tuple[str, str, str]:
    """Return ``(subject, plain_text, html)`` for one alert or a digest."""
    language = "vi" if language == "vi" else "en"
    rows = [records] if isinstance(records, dict) else list(records)
    if not rows:
        raise ValueError("At least one Syslog record is required")
    rows.sort(key=_severity)
    worst = _severity(rows[0])
    theme = THEMES[worst]
    labels = _LABELS[language]
    severity_name = theme["vi"] if language == "vi" else theme["name"]
    prefix = "[TEST] " if test else ""

    if len(rows) == 1:
        record = rows[0]
        subject = (
            f"{prefix}[SYSLOG {severity_name}] "
            f"{_header(record.get('device_host'))} {_header(cisco_code(record))}"
        ).strip()
        title = f"LEVEL {worst} · {severity_name}"
        subtitle = f'{_esc(record.get("device_host"))} · {_esc(record.get("source_ip"))}'
    else:
        subject = f"{prefix}[SYSLOG {severity_name}] {len(rows)} {labels['new']}"
        title = f"{len(rows)} {labels['new']} · {labels['highest']} LEVEL {worst} {severity_name}"
        subtitle = labels["summary"]

    cards = (_summary(rows, language) if len(rows) > 1 else "") + "".join(
        _card(record, language) for record in rows
    )
    action = _ACTIONS[language][worst]
    html_body = f"""<!doctype html>
<html lang="{language}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{_esc(subject)}</title></head>
<body style="margin:0;padding:0;background:#f3f4f6;font-family:Segoe UI,Roboto,Arial,sans-serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f3f4f6;"><tr><td align="center" style="padding:24px 12px;">
<table role="presentation" width="640" cellpadding="0" cellspacing="0" style="width:100%;max-width:640px;">
<tr><td style="background:{theme['color']};border-radius:10px 10px 0 0;padding:22px 24px;">
<div style="color:#fff;opacity:.85;font-size:11px;letter-spacing:1.5px;">{labels['alert']}</div>
<div style="color:#fff;font-size:22px;font-weight:bold;margin-top:6px;">{_esc(title)}</div>
<div style="color:#fff;opacity:.9;font-size:13px;margin-top:6px;">{subtitle}</div></td></tr>
<tr><td style="background:{theme['soft']};padding:12px 24px;border-bottom:1px solid #e5e7eb;color:{theme['color']};font-size:13px;font-weight:bold;">{_esc(action)}</td></tr>
<tr><td style="background:#f9fafb;padding:20px 24px 8px;">{cards}</td></tr>
<tr><td style="background:#f9fafb;border-radius:0 0 10px 10px;padding:4px 24px 20px;color:#9ca3af;font-size:11px;line-height:1.5;">
{_esc(labels['automatic'])}<br>{_esc(labels['note'])}</td></tr></table></td></tr></table></body></html>"""

    lines = []
    for record in rows:
        severity = _severity(record)
        name = THEMES[severity]["vi"] if language == "vi" else THEMES[severity]["name"]
        lines.append(
            f'[LV {severity} {name}] {record.get("device_host", "")} ({record.get("source_ip", "")})\n'
            f'  {cisco_code(record)}\n  {record.get("message", "")}\n'
            f'  {labels["received"]}: {record.get("received_at", "")}\n'
        )
    plain_text = f"{title}\n{action}\n\n" + "\n".join(lines)
    return subject, plain_text, html_body


__all__ = ["THEMES", "cisco_code", "render_email"]
