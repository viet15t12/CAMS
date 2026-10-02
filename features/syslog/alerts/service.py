"""Non-blocking batching, duplicate suppression, and SMTP delivery."""

from __future__ import annotations

from email.message import EmailMessage
import queue
import smtplib
import socket
import ssl
import threading
import time
from collections.abc import Callable
from datetime import datetime, timezone
from typing import Any

from .renderer import cisco_code, render_email
from .settings import AlertConfiguration, AlertSettingsStore


EmailSender = Callable[[AlertConfiguration, list[dict[str, Any]], str, bool], str]


def send_smtp_message(
    config: AlertConfiguration,
    records: list[dict[str, Any]],
    language: str,
    test: bool = False,
) -> str:
    """Render and send one SMTP message to every configured recipient."""
    subject, text_body, html_body = render_email(records, language, test=test)
    message = EmailMessage()
    message["From"] = config.sender_email
    message["To"] = ", ".join(config.recipients)
    message["Subject"] = subject
    message.set_content(text_body)
    message.add_alternative(html_body, subtype="html")
    context = ssl.create_default_context()
    with smtplib.SMTP_SSL(
        config.smtp_host, config.smtp_port, timeout=20, context=context
    ) as server:
        server.login(config.sender_email, config.sender_app_password)
        server.send_message(message)
    return subject


def delivery_error_message(exc: BaseException, language: str) -> str:
    vietnamese = language == "vi"
    if isinstance(exc, smtplib.SMTPAuthenticationError):
        return (
            "Đăng nhập thất bại. Kiểm tra App Password và đảm bảo tài khoản đã bật xác minh 2 bước."
            if vietnamese
            else "Sign-in failed. Check the App Password and make sure 2-Step Verification is enabled."
        )
    if isinstance(exc, (socket.timeout, TimeoutError, ConnectionError, OSError)):
        return (
            "Không kết nối được tới máy chủ SMTP. Kiểm tra mạng, máy chủ và cổng."
            if vietnamese
            else "Could not connect to the SMTP server. Check the network, server, and port."
        )
    return (
        f"Gửi email thất bại: {exc}"
        if vietnamese
        else f"Email delivery failed: {exc}"
    )


def test_record(language: str = "en") -> dict[str, Any]:
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    message = (
        "Cảnh báo thử CAMS: cấu hình thông báo qua email đang hoạt động."
        if language == "vi"
        else "CAMS test alert: email notification settings are working."
    )
    return {
        "device_host": "CAMS-TEST",
        "source_ip": "127.0.0.1",
        "device_time": now,
        "received_at": now,
        "sequence_number": 1,
        "clock_unsynchronized": False,
        "syslog_pri": 186,
        "syslog_facility": 23,
        "cisco_facility": "SYS",
        "cisco_subfacility": None,
        "severity": 2,
        "mnemonic": "EMAIL_TEST",
        "message": message,
        "raw_message": f"<186>%SYS-2-EMAIL_TEST: {message}",
        "protocol": "local",
        "parse_status": "parsed",
    }


class EmailAlertService:
    """Accept stored rows quickly; render and send them on one worker thread."""

    _STOP = object()

    def __init__(
        self,
        settings: AlertSettingsStore,
        *,
        sender: EmailSender = send_smtp_message,
        on_error: Callable[[str], None] | None = None,
        clock: Callable[[], float] = time.monotonic,
        max_queue: int = 10_000,
    ) -> None:
        self.settings = settings
        self._sender = sender
        self._on_error = on_error or (lambda _message: None)
        self._clock = clock
        self._queue: queue.Queue[object] = queue.Queue(maxsize=max_queue)
        self._lock = threading.Lock()
        self._last_accepted: dict[tuple[str, str], float] = {}
        self._dropped = 0
        self._thread = threading.Thread(
            target=self._run, name="syslog-email-alerts", daemon=True
        )
        self._thread.start()

    @property
    def dropped(self) -> int:
        with self._lock:
            return self._dropped

    @staticmethod
    def duplicate_key(record: dict[str, Any]) -> tuple[str, str]:
        device = str(record.get("device_host") or record.get("source_ip") or "").casefold()
        code = cisco_code(record)
        if not code:
            code = str(record.get("message") or record.get("raw_message") or "")
        return device, code.casefold()

    def submit(self, records: list[dict[str, Any]], language: str = "en") -> int:
        """Queue eligible rows and return immediately with the accepted count."""
        config = self.settings.configuration()
        if not config.enabled:
            return 0
        accepted = 0
        now = self._clock()
        for record in records:
            try:
                severity = int(record.get("severity", -1))
            except (TypeError, ValueError):
                continue
            if severity not in config.levels:
                continue
            key = self.duplicate_key(record)
            with self._lock:
                last = self._last_accepted.get(key)
                if config.cooldown_seconds > 0 and last is not None \
                        and now - last < config.cooldown_seconds:
                    continue
                try:
                    self._queue.put_nowait(
                        (dict(record), "vi" if language == "vi" else "en")
                    )
                except queue.Full:
                    self._dropped += 1
                    continue
                self._last_accepted[key] = now
                accepted += 1
        self._prune_cooldown(now, config.cooldown_seconds)
        return accepted

    def _prune_cooldown(self, now: float, cooldown: int) -> None:
        threshold = max(300, cooldown * 2)
        with self._lock:
            if len(self._last_accepted) < 4096:
                return
            self._last_accepted = {
                key: value
                for key, value in self._last_accepted.items()
                if now - value <= threshold
            }

    def _run(self) -> None:
        pending: list[dict[str, Any]] = []
        language = "en"
        deadline: float | None = None
        stopping = False
        while not stopping:
            timeout = 0.5 if deadline is None else max(0.0, deadline - self._clock())
            try:
                item = self._queue.get(timeout=min(timeout, 0.5) if deadline is not None else timeout)
            except queue.Empty:
                item = None
            if item is self._STOP:
                stopping = True
            elif item is not None:
                record, language = item  # type: ignore[misc]
                pending.append(record)
                if deadline is None:
                    batch_seconds = self.settings.configuration().batch_seconds
                    deadline = self._clock() + batch_seconds
            if pending and (stopping or deadline is not None and self._clock() >= deadline):
                self._deliver(pending, language)
                pending = []
                deadline = None

    def _deliver(self, records: list[dict[str, Any]], language: str) -> None:
        config = self.settings.configuration()
        if not config.enabled:
            return
        selected = []
        for record in records:
            try:
                severity = int(record.get("severity", -1))
            except (TypeError, ValueError):
                continue
            if severity in config.levels:
                selected.append(record)
        if not selected:
            return
        try:
            self._sender(config, selected, language, False)
        except Exception as exc:
            self._on_error(delivery_error_message(exc, language))

    def shutdown(self, timeout: float = 5.0) -> None:
        if not self._thread.is_alive():
            return
        try:
            self._queue.put_nowait(self._STOP)
        except queue.Full:
            self._queue.put(self._STOP, timeout=min(1.0, timeout))
        if self._thread is not threading.current_thread():
            self._thread.join(timeout)


__all__ = [
    "EmailAlertService",
    "delivery_error_message",
    "send_smtp_message",
    "test_record",
]
