"""Non-blocking batching, duplicate suppression, and Telegram delivery."""

from __future__ import annotations

import json
import queue
import socket
import threading
import time
from collections.abc import Callable
from datetime import datetime, timezone
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from ..alerts.renderer import cisco_code
from .renderer import render_telegram
from .settings import TelegramAlertConfiguration, TelegramAlertSettingsStore


TelegramSender = Callable[
    [TelegramAlertConfiguration, list[dict[str, Any]], str, bool], str
]


class TelegramDeliveryError(RuntimeError):
    """Delivery error that never exposes the Bot Token or request URL."""

    def __init__(
        self,
        message: str,
        *,
        status: int | None = None,
        cause: BaseException | None = None,
    ) -> None:
        self.detail = " ".join(str(message or "").splitlines())[:300]
        self.status = status
        self.cause = cause
        super().__init__(self.detail or "Telegram delivery failed")


def _api_error_detail(payload: bytes) -> str:
    try:
        parsed = json.loads(payload.decode("utf-8", errors="replace"))
    except (json.JSONDecodeError, UnicodeDecodeError):
        return "Telegram Bot API rejected the request."
    if isinstance(parsed, dict):
        return str(parsed.get("description") or "Telegram Bot API rejected the request.")
    return "Telegram Bot API rejected the request."


def send_telegram_message(
    config: TelegramAlertConfiguration,
    records: list[dict[str, Any]],
    language: str,
    test: bool = False,
) -> str:
    """Send one plain-text Bot API message to the configured chat."""
    text = render_telegram(records, language, test=test)
    body = urlencode(
        {
            "chat_id": config.chat_id,
            "text": text,
            "disable_web_page_preview": "true",
        }
    ).encode("utf-8")
    request = Request(
        f"https://api.telegram.org/bot{config.bot_token}/sendMessage",
        data=body,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urlopen(request, timeout=20) as response:
            payload = response.read()
    except HTTPError as exc:
        try:
            detail = _api_error_detail(exc.read())
        except OSError:
            detail = "Telegram Bot API rejected the request."
        detail = detail.replace(config.bot_token, "[redacted]")
        raise TelegramDeliveryError(
            detail, status=getattr(exc, "code", None), cause=exc
        ) from exc
    except (URLError, OSError, TimeoutError) as exc:
        raise TelegramDeliveryError(
            "Could not connect to Telegram Bot API.", cause=exc
        ) from exc

    try:
        result = json.loads(payload.decode("utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        raise TelegramDeliveryError(
            "Telegram Bot API returned an invalid response.", cause=exc
        ) from exc
    if not isinstance(result, dict) or result.get("ok") is not True:
        detail = (
            str(result.get("description") or "Telegram Bot API rejected the request.")
            if isinstance(result, dict)
            else "Telegram Bot API rejected the request."
        )
        detail = detail.replace(config.bot_token, "[redacted]")
        status = result.get("error_code") if isinstance(result, dict) else None
        raise TelegramDeliveryError(detail, status=status)
    return text


def delivery_error_message(exc: BaseException, language: str) -> str:
    vietnamese = language == "vi"
    if isinstance(exc, TelegramDeliveryError):
        status = f" (HTTP {exc.status})" if exc.status else ""
        detail = exc.detail
        lowered = detail.casefold()
        if "unauthorized" in lowered:
            return (
                f"Telegram từ chối Bot Token{status}. Kiểm tra token từ BotFather."
                if vietnamese
                else f"Telegram rejected the Bot Token{status}. Check the token from BotFather."
            )
        if "chat not found" in lowered:
            return (
                f"Không tìm thấy Telegram Chat ID{status}. Hãy nhắn /start cho bot "
                "và kiểm tra lại Chat ID."
                if vietnamese
                else f"Telegram Chat ID was not found{status}. Send /start to the "
                "bot and recheck the Chat ID."
            )
        if isinstance(exc.cause, URLError):
            return (
                "Không kết nối được Telegram Bot API. Kiểm tra Internet, DNS và firewall."
                if vietnamese
                else "Could not connect to Telegram Bot API. Check Internet access, "
                "DNS, and the firewall."
            )
        return (
            f"Gửi Telegram thất bại{status}: {detail}"
            if vietnamese
            else f"Telegram delivery failed{status}: {detail}"
        )
    if isinstance(exc, (socket.timeout, TimeoutError)):
        return (
            "Kết nối Telegram đã hết thời gian chờ."
            if vietnamese
            else "The Telegram connection timed out."
        )
    return (
        f"Gửi Telegram thất bại ({type(exc).__name__})."
        if vietnamese
        else f"Telegram delivery failed ({type(exc).__name__})."
    )


def test_record(language: str = "en") -> dict[str, Any]:
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    message = (
        "Cảnh báo thử CAMS: cấu hình Telegram đang hoạt động."
        if language == "vi"
        else "CAMS test alert: Telegram notification settings are working."
    )
    return {
        "device_host": "CAMS-TEST",
        "source_ip": "127.0.0.1",
        "received_at": now,
        "severity": 2,
        "cisco_facility": "SYS",
        "mnemonic": "TELEGRAM_TEST",
        "message": message,
        "raw_message": f"%SYS-2-TELEGRAM_TEST: {message}",
        "protocol": "local",
    }


class TelegramAlertService:
    """Accept stored rows quickly and deliver them on a worker thread."""

    _STOP = object()

    def __init__(
        self,
        settings: TelegramAlertSettingsStore,
        *,
        sender: TelegramSender = send_telegram_message,
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
            target=self._run, name="syslog-telegram-alerts", daemon=True
        )
        self._thread.start()

    @property
    def dropped(self) -> int:
        with self._lock:
            return self._dropped

    @staticmethod
    def duplicate_key(record: dict[str, Any]) -> tuple[str, str]:
        device = str(
            record.get("device_host") or record.get("source_ip") or ""
        ).casefold()
        code = cisco_code(record)
        if not code:
            code = str(record.get("message") or record.get("raw_message") or "")
        return device, code.casefold()

    def submit(self, records: list[dict[str, Any]], language: str = "en") -> int:
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
                if (
                    config.cooldown_seconds > 0
                    and last is not None
                    and now - last < config.cooldown_seconds
                ):
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
                item = self._queue.get(
                    timeout=min(timeout, 0.5) if deadline is not None else timeout
                )
            except queue.Empty:
                item = None
            if item is self._STOP:
                stopping = True
            elif item is not None:
                record, language = item  # type: ignore[misc]
                pending.append(record)
                if deadline is None:
                    deadline = (
                        self._clock()
                        + self.settings.configuration().batch_seconds
                    )
            if pending and (
                stopping or deadline is not None and self._clock() >= deadline
            ):
                self._deliver(pending, language)
                pending = []
                deadline = None

    def _deliver(self, records: list[dict[str, Any]], language: str) -> None:
        config = self.settings.configuration()
        if not config.enabled:
            return
        selected: list[dict[str, Any]] = []
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
    "TelegramAlertService",
    "TelegramDeliveryError",
    "delivery_error_message",
    "send_telegram_message",
    "test_record",
]
