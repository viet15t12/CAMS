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


class SmtpDeliveryError(RuntimeError):
    """Keep the failing SMTP stage without storing or logging credentials."""

    def __init__(self, config: AlertConfiguration, stage: str, cause: Exception) -> None:
        self.endpoint = f"{config.smtp_host}:{config.smtp_port}"
        self.security = config.transport_security
        self.stage = stage
        self.cause = cause
        super().__init__(f"SMTP {stage} failed ({type(cause).__name__})")


class PartialRecipientRefusal(smtplib.SMTPRecipientsRefused):
    def __init__(self, recipients: dict, total: int) -> None:
        super().__init__(recipients)
        self.total = total


def _close_smtp(server: smtplib.SMTP) -> None:
    try:
        server.close()
    except Exception:
        # Cleanup must never hide the delivery result or its original error.
        pass


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
    server = None
    stage = "connection"
    try:
        if config.transport_security == "ssl":
            server = smtplib.SMTP_SSL(
                config.smtp_host, config.smtp_port, timeout=20, context=context
            )
        else:
            server = smtplib.SMTP(config.smtp_host, config.smtp_port, timeout=20)
            stage = "STARTTLS"
            server.ehlo()
            server.starttls(context=context)
            server.ehlo()
        stage = "authentication"
        server.login(config.sender_email, config.sender_app_password)
        stage = "delivery"
        refused = server.send_message(message)
        if refused:
            raise PartialRecipientRefusal(refused, len(config.recipients))
    except Exception as exc:
        if server is not None:
            _close_smtp(server)
        raise SmtpDeliveryError(config, stage, exc) from exc
    # SMTP has already accepted the message. A QUIT error cannot undo delivery.
    try:
        server.quit()
    except OSError:
        pass
    finally:
        _close_smtp(server)
    return subject


def delivery_error_message(exc: BaseException, language: str) -> str:
    vietnamese = language == "vi"
    prefix = ""
    if isinstance(exc, SmtpDeliveryError):
        stages = {
            "connection": "kết nối", "STARTTLS": "STARTTLS",
            "authentication": "đăng nhập", "delivery": "gửi thư",
        }
        stage = stages.get(exc.stage, exc.stage) if vietnamese else exc.stage
        security = "SSL/TLS" if exc.security == "ssl" else "STARTTLS"
        prefix = f"{exc.endpoint} ({security}, {stage}): "
        exc = exc.cause

    def result(en: str, vi: str) -> str:
        return prefix + (vi if vietnamese else en)

    def codes(recipients: dict) -> str:
        return ", ".join(sorted({str(value[0]) for value in recipients.values()}))

    if isinstance(exc, smtplib.SMTPAuthenticationError):
        return result(
            f"Sign-in failed (SMTP {exc.smtp_code}). Check the App Password and 2-Step Verification.",
            f"Đăng nhập thất bại (SMTP {exc.smtp_code}). Kiểm tra App Password và xác minh 2 bước.",
        )
    if isinstance(exc, ssl.SSLCertVerificationError):
        return result(
            "TLS certificate verification failed. Check the computer clock, trusted certificates, and network TLS inspection.",
            "Không xác minh được chứng thư TLS. Kiểm tra giờ máy, chứng thư tin cậy và proxy kiểm tra TLS của mạng.",
        )
    if isinstance(exc, ssl.SSLError):
        return result(
            "TLS negotiation failed. Use SSL/TLS for port 465 or STARTTLS for port 587.",
            "Bắt tay TLS thất bại. Dùng SSL/TLS cho cổng 465 hoặc STARTTLS cho cổng 587.",
        )
    if isinstance(exc, PartialRecipientRefusal):
        accepted = exc.total - len(exc.recipients)
        return result(
            f"Email accepted for {accepted} of {exc.total} recipients; others were refused (SMTP {codes(exc.recipients)}).",
            f"Máy chủ nhận thư cho {accepted}/{exc.total} người nhận; các địa chỉ còn lại bị từ chối (SMTP {codes(exc.recipients)}).",
        )
    if isinstance(exc, smtplib.SMTPRecipientsRefused):
        return result(
            f"All recipient addresses were refused (SMTP {codes(exc.recipients)}). Check the recipients and sending policy.",
            f"Tất cả địa chỉ nhận bị từ chối (SMTP {codes(exc.recipients)}). Kiểm tra người nhận và chính sách gửi thư.",
        )
    if isinstance(exc, smtplib.SMTPSenderRefused):
        return result(
            f"Sender address was refused (SMTP {exc.smtp_code}). Check the sender account and sending permissions.",
            f"Địa chỉ gửi bị từ chối (SMTP {exc.smtp_code}). Kiểm tra tài khoản và quyền gửi thư.",
        )
    if isinstance(exc, smtplib.SMTPDataError):
        return result(
            f"SMTP server rejected the email (SMTP {exc.smtp_code}). Check sending limits and server policy.",
            f"Máy chủ từ chối thư (SMTP {exc.smtp_code}). Kiểm tra hạn mức và chính sách gửi thư.",
        )
    if isinstance(exc, smtplib.SMTPNotSupportedError):
        return result(
            "SMTP server does not support the required STARTTLS or authentication method. Check connection security and port.",
            "Máy chủ không hỗ trợ STARTTLS hoặc cách đăng nhập yêu cầu. Kiểm tra chế độ bảo mật và cổng.",
        )
    if isinstance(exc, smtplib.SMTPResponseException):
        return result(
            f"SMTP server refused the request (SMTP {exc.smtp_code}). Check server availability and sending policy.",
            f"Máy chủ từ chối yêu cầu (SMTP {exc.smtp_code}). Kiểm tra trạng thái máy chủ và chính sách gửi thư.",
        )
    if isinstance(exc, smtplib.SMTPServerDisconnected):
        return result(
            "SMTP server closed the connection. Check the network and connection security, then retry.",
            "Máy chủ SMTP đóng kết nối. Kiểm tra mạng và chế độ bảo mật, rồi thử lại.",
        )
    if isinstance(exc, smtplib.SMTPException):
        return result("SMTP protocol error. Check server capabilities and settings.",
                      "Lỗi giao thức SMTP. Kiểm tra khả năng máy chủ và cấu hình.")
    if isinstance(exc, socket.gaierror):
        return result("DNS could not resolve the SMTP server. Check its hostname and DNS/network settings.",
                      "DNS không phân giải được máy chủ SMTP. Kiểm tra tên máy chủ, DNS và mạng.")
    if isinstance(exc, (socket.timeout, TimeoutError)):
        return result(
            "SMTP operation timed out. The network may block the port; for Gmail, try port 587 with STARTTLS.",
            "Thao tác SMTP hết thời gian chờ. Mạng có thể chặn cổng; với Gmail, thử cổng 587 và STARTTLS.",
        )
    if isinstance(exc, ConnectionRefusedError):
        return result("SMTP connection was refused. Check the server, port, and firewall.",
                      "Kết nối SMTP bị từ chối. Kiểm tra máy chủ, cổng và tường lửa.")
    if isinstance(exc, OSError):
        code = f" (OS {exc.errno})" if exc.errno is not None else ""
        return result(
            f"SMTP network operation failed{code}. Check the network, server, port, and firewall.",
            f"Thao tác mạng SMTP thất bại{code}. Kiểm tra mạng, máy chủ, cổng và tường lửa.",
        )
    return result(f"Email delivery failed ({type(exc).__name__}).",
                  f"Gửi email thất bại ({type(exc).__name__}).")


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
