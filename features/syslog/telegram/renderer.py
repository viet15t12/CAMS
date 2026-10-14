"""Plain-text Telegram templates for Cisco Syslog alerts."""

from __future__ import annotations

from typing import Any

from ..alerts.renderer import THEMES, cisco_code


MAX_TELEGRAM_TEXT = 4096


def _severity(record: dict[str, Any]) -> int:
    try:
        value = int(record.get("severity", 6))
    except (TypeError, ValueError):
        return 6
    return value if value in THEMES else 6


def _clean(value: Any) -> str:
    return " ".join(str(value or "").replace("\x00", "").splitlines()).strip()


def render_telegram(
    records: dict[str, Any] | list[dict[str, Any]],
    language: str = "en",
    *,
    test: bool = False,
) -> str:
    """Render a Bot API-safe message of at most 4096 characters."""
    selected_language = "vi" if language == "vi" else "en"
    rows = [records] if isinstance(records, dict) else list(records)
    if not rows:
        raise ValueError("At least one Syslog record is required")
    rows.sort(key=_severity)
    worst = _severity(rows[0])
    theme = THEMES[worst]
    severity_name = theme["vi"] if selected_language == "vi" else theme["name"]
    test_prefix = "[THỬ] " if test and selected_language == "vi" else "[TEST] " if test else ""
    header = (
        f"{test_prefix}🚨 CẢNH BÁO SYSLOG · LEVEL {worst} · {severity_name}"
        if selected_language == "vi"
        else f"{test_prefix}🚨 SYSLOG ALERT · LEVEL {worst} · {severity_name}"
    )
    if len(rows) > 1:
        header += (
            f"\n{len(rows)} cảnh báo mới"
            if selected_language == "vi"
            else f"\n{len(rows)} new alerts"
        )

    labels = (
        ("Thiết bị", "IP nguồn", "Giờ nhận", "Mã Cisco", "Nội dung")
        if selected_language == "vi"
        else ("Device", "Source IP", "Received", "Cisco code", "Message")
    )
    blocks: list[str] = []
    for record in rows:
        severity = _severity(record)
        row_theme = THEMES[severity]
        row_name = row_theme["vi"] if selected_language == "vi" else row_theme["name"]
        values = (
            _clean(record.get("device_host")),
            _clean(record.get("source_ip")),
            _clean(record.get("received_at")),
            _clean(cisco_code(record)),
            _clean(record.get("message") or record.get("raw_message")),
        )
        details = [f"LEVEL {severity} · {row_name}"]
        details.extend(
            f"{label}: {value}" for label, value in zip(labels, values) if value
        )
        blocks.append("\n".join(details))

    message = header
    omitted = 0
    for index, block in enumerate(blocks):
        candidate = f"{message}\n\n{block}"
        if len(candidate) > MAX_TELEGRAM_TEXT - 80:
            omitted = len(blocks) - index
            break
        message = candidate
    if omitted:
        suffix = (
            f"\n\n… còn {omitted} cảnh báo trong đợt này."
            if selected_language == "vi"
            else f"\n\n… {omitted} more alert(s) in this batch."
        )
        message += suffix
    return message[:MAX_TELEGRAM_TEXT]


__all__ = ["MAX_TELEGRAM_TEXT", "render_telegram"]
