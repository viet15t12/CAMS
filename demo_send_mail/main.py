#!/usr/bin/env python3
"""Gửi lại hai cảnh báo email gắn trực tiếp với Kịch bản 4 Syslog.

Hai bản ghi bên dưới được dựng từ chuỗi sự kiện xuất hiện trong các hình lab:

* SW1 đưa GigabitEthernet1/3 lên lại, phát sinh ``%LINK-3-UPDOWN``.
* R1 đánh dấu vòng thử 5/5 khi Loopback99 xuống, phát sinh
  ``%SYS-4-USERLOG_WARNING``.

Script dùng chính ``features.syslog.alerts.renderer`` của CAMS, vì vậy email
gửi thử và email do ứng dụng gửi trong vận hành có cùng mẫu HTML/text.

Ví dụ:

    python3 demo_send_mail/main.py --preview
    python3 demo_send_mail/main.py
    python3 demo_send_mail/main.py --levels 3,4

App Password được đọc từ ``GMAIL_APP_PASSWORD`` hoặc lời nhắc ẩn. Không truyền
mật khẩu trên dòng lệnh và không lưu mật khẩu vào tệp này.
"""

from __future__ import annotations

import argparse
from copy import deepcopy
from email.message import EmailMessage
import getpass
import importlib.util
import os
from pathlib import Path
import smtplib
import socket
import ssl
import time


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RENDERER_PATH = PROJECT_ROOT / "features/syslog/alerts/renderer.py"
_renderer_spec = importlib.util.spec_from_file_location(
    "cams_syslog_alert_renderer", RENDERER_PATH
)
if _renderer_spec is None or _renderer_spec.loader is None:
    raise RuntimeError(f"Không thể nạp bộ dựng email CAMS: {RENDERER_PATH}")
_renderer_module = importlib.util.module_from_spec(_renderer_spec)
_renderer_spec.loader.exec_module(_renderer_module)
render_email = _renderer_module.render_email


# Dữ liệu được chép lại từ Kịch bản 4, không phải tên/IP minh họa ngoài lab.
# PRI 187 = local7 (23) * 8 + severity 3; PRI 188 tương ứng severity 4.
LAB_RECORDS: dict[int, dict[str, object]] = {
    3: {
        "device_host": "SW1",
        "source_ip": "192.168.122.104",
        "device_time": "Aug 29 20:25:38.166",
        "received_at": "2026-08-29T20:25:46.525Z",
        "sequence_number": 110,
        "clock_unsynchronized": True,
        "syslog_pri": 187,
        "syslog_facility": 23,
        "cisco_facility": "LINK",
        "cisco_subfacility": None,
        "severity": 3,
        "mnemonic": "UPDOWN",
        "message": "Interface GigabitEthernet1/3, changed state to up",
        "raw_message": (
            "<187>104: 000110: *Aug 29 20:25:38.166: "
            "%LINK-3-UPDOWN: Interface GigabitEthernet1/3, changed state to up"
        ),
        "protocol": "udp",
        "parse_status": "parsed",
    },
    4: {
        "device_host": "R1",
        "source_ip": "192.168.122.101",
        "device_time": "Aug 29 20:25:34.340",
        "received_at": "2026-08-29T20:25:38.340Z",
        "sequence_number": 98,
        "clock_unsynchronized": True,
        "syslog_pri": 188,
        "syslog_facility": 23,
        "cisco_facility": "SYS",
        "cisco_subfacility": None,
        "severity": 4,
        "mnemonic": "USERLOG_WARNING",
        "message": (
            "Message from tty579(user id: admin): "
            "DEMO-R1 CYCLE=5/5 Loopback99=DOWN"
        ),
        "raw_message": (
            "<188>101: 000098: *Aug 29 20:25:34.340: "
            "%SYS-4-USERLOG_WARNING: Message from tty579(user id: admin): "
            "DEMO-R1 CYCLE=5/5 Loopback99=DOWN"
        ),
        "protocol": "udp",
        "parse_status": "parsed",
    },
}


def parse_levels(value: str) -> list[int]:
    """Phân tích danh sách level và chỉ nhận các bản ghi có trong lab."""
    levels: set[int] = set()
    for part in value.split(","):
        part = part.strip()
        if not part:
            continue
        try:
            levels.add(int(part))
        except ValueError as exc:
            raise argparse.ArgumentTypeError(
                f"Level không hợp lệ: {part!r}. Dùng 3, 4 hoặc 3,4."
            ) from exc

    unavailable = sorted(levels.difference(LAB_RECORDS))
    if unavailable or not levels:
        available = ", ".join(str(level) for level in sorted(LAB_RECORDS))
        detail = f"; không có dữ liệu lab cho {unavailable}" if unavailable else ""
        raise argparse.ArgumentTypeError(
            f"Chỉ hỗ trợ các level đã đối chiếu từ hình lab: {available}{detail}."
        )
    return sorted(levels)


def lab_record(level: int) -> dict[str, object]:
    return deepcopy(LAB_RECORDS[level])


def write_previews(levels: list[int], output_dir: Path) -> list[Path]:
    """Xuất đúng HTML sẽ được gửi để chụp lại Hình 5.51 và 5.52."""
    output_dir.mkdir(parents=True, exist_ok=True)
    paths: list[Path] = []
    for level in levels:
        _subject, _text, html_body = render_email(
            lab_record(level), language="vi"
        )
        path = output_dir / f"level_{level}.html"
        path.write_text(html_body, encoding="utf-8")
        paths.append(path)
    return paths


def send_record(
    record: dict[str, object],
    *,
    sender: str,
    password: str,
    recipient: str,
) -> str:
    subject, text_body, html_body = render_email(record, language="vi")
    message = EmailMessage()
    message["From"] = sender
    message["To"] = recipient
    message["Subject"] = "[LAB CAMS] " + subject
    message.set_content(text_body)
    message.add_alternative(html_body, subtype="html")

    context = ssl.create_default_context()
    with smtplib.SMTP_SSL(
        "smtp.gmail.com", 465, timeout=20, context=context
    ) as server:
        server.login(sender, password)
        server.send_message(message)
    return str(message["Subject"])


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Gửi lại email từ hai sự kiện của Kịch bản 4 Syslog"
    )
    parser.add_argument(
        "--levels",
        type=parse_levels,
        default=parse_levels("3,4"),
        help="level lab cần gửi: 3, 4 hoặc 3,4 (mặc định: 3,4)",
    )
    parser.add_argument(
        "--preview",
        action="store_true",
        help="chỉ xuất HTML, không đăng nhập SMTP và không gửi email",
    )
    parser.add_argument(
        "--preview-dir",
        type=Path,
        default=Path(__file__).resolve().with_name("preview"),
        help="thư mục xuất HTML khi dùng --preview",
    )
    parser.add_argument(
        "--to",
        default=os.environ.get("MAIL_TO", "nguyenquocviet15t12@gmail.com"),
        help="địa chỉ nhận (mặc định lấy MAIL_TO hoặc địa chỉ của bài lab)",
    )
    parser.add_argument(
        "--sender",
        default=os.environ.get("GMAIL_USER", "cams.syslog.alert@gmail.com"),
        help="tài khoản Gmail gửi (mặc định lấy GMAIL_USER)",
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()

    if args.preview:
        paths = write_previews(args.levels, args.preview_dir)
        for path in paths:
            print(f"Đã tạo: {path}")
        return

    password = (
        os.environ.get("GMAIL_APP_PASSWORD")
        or getpass.getpass(
            f"App Password của {args.sender} (ký tự nhập sẽ không hiển thị): "
        )
    ).replace(" ", "")
    if not password:
        raise SystemExit("LỖI: App Password không được để trống.")

    try:
        for index, level in enumerate(args.levels):
            if index:
                time.sleep(1)
            subject = send_record(
                lab_record(level),
                sender=args.sender,
                password=password,
                recipient=args.to,
            )
            print(f"Đã gửi level {level}: {subject}")
    except smtplib.SMTPAuthenticationError:
        raise SystemExit(
            "LỖI đăng nhập: kiểm tra App Password và xác minh 2 bước."
        ) from None
    except (socket.timeout, TimeoutError, ConnectionError, OSError) as exc:
        raise SystemExit(
            f"LỖI kết nối smtp.gmail.com:465: {exc}"
        ) from None
    except smtplib.SMTPException as exc:
        raise SystemExit(f"LỖI SMTP: {exc}") from None

    print(
        f"Hoàn tất: {len(args.levels)} email lab đã gửi tới {args.to}. "
        "Kiểm tra cả hộp thư Spam nếu chưa thấy."
    )


if __name__ == "__main__":
    main()
