"""Qt/QML controller for Telegram alert settings and test delivery."""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import logging
import os
from pathlib import Path
import threading
from typing import Any

from PyQt6.QtCore import QObject, QStandardPaths, pyqtProperty, pyqtSignal, pyqtSlot

from ..telegram.service import (
    TelegramAlertService,
    delivery_error_message,
    send_telegram_message,
    test_record,
)
from ..telegram.settings import (
    TelegramAlertSettingsStore,
    TelegramAlertValidationError,
)


LOGGER = logging.getLogger(__name__)


_VI_VALIDATION = {
    "Select at least one Syslog level to alert on.": "Chọn ít nhất 1 mức log cần cảnh báo.",
    "Telegram Bot Token is required.": "Nhập Telegram Bot Token.",
    "Telegram Bot Token format is invalid.": "Định dạng Telegram Bot Token không hợp lệ.",
    "Telegram Chat ID is required.": "Nhập Telegram Chat ID.",
    "Telegram Chat ID must be numeric or a valid @channel username.":
        "Telegram Chat ID phải là số hoặc username kênh dạng @channel hợp lệ.",
    "Cooldown must be between 0 and 86400 seconds.":
        "Thời gian chống trùng phải từ 0 đến 86400 giây.",
    "Batch window must be between 0 and 86400 seconds.":
        "Thời gian gom cảnh báo phải từ 0 đến 86400 giây.",
}


def _mapping(value: Any) -> dict[str, Any]:
    if value is None:
        return {}
    to_variant = getattr(value, "toVariant", None)
    if callable(to_variant):
        value = to_variant()
    return dict(value) if isinstance(value, dict) else dict(value or {})


def _validation_result(
    exc: TelegramAlertValidationError, language: str
) -> dict[str, Any]:
    errors = {
        key: (_VI_VALIDATION.get(message, message) if language == "vi" else message)
        for key, message in exc.errors.items()
    }
    return {
        "ok": False,
        "message": next(iter(errors.values()), "Invalid Telegram alert settings."),
        "errors": errors,
    }


class TelegramAlertManager(QObject):
    configurationChanged = pyqtSignal()
    testTelegramFinished = pyqtSignal(bool, str)
    testStateChanged = pyqtSignal()
    alertError = pyqtSignal(str)

    def __init__(
        self,
        parent: QObject | None = None,
        *,
        settings_path: str | Path | None = None,
        language_getter=None,
    ) -> None:
        super().__init__(parent)
        override = os.environ.get("CAMS_TELEGRAM_ALERT_SETTINGS", "").strip()
        default_root = Path(
            QStandardPaths.writableLocation(
                QStandardPaths.StandardLocation.AppConfigLocation
            )
        )
        path = Path(
            settings_path
            or override
            or (default_root / "telegram_alert_settings.json")
        )
        self.store = TelegramAlertSettingsStore(path)
        self._language_getter = language_getter or (lambda: "en")
        self.service = TelegramAlertService(
            self.store, on_error=self._report_alert_error
        )
        self._executor = ThreadPoolExecutor(
            max_workers=1, thread_name_prefix="telegram-alert-test"
        )
        self._shutdown = False
        self._test_lock = threading.Lock()
        self._test_sending = False

    @pyqtProperty(bool, notify=testStateChanged)
    def testSending(self) -> bool:
        with self._test_lock:
            return self._test_sending

    def _language(self) -> str:
        try:
            return "vi" if self._language_getter() == "vi" else "en"
        except Exception:
            return "en"

    def _report_alert_error(self, message: str) -> None:
        LOGGER.warning("Syslog Telegram alert delivery failed: %s", message)
        self.alertError.emit(str(message))

    @pyqtSlot(result="QVariant")
    def loadConfiguration(self) -> dict[str, Any]:
        return self.store.public_values()

    @pyqtSlot("QVariant", str, result="QVariant")
    def validateConfiguration(
        self, payload: Any, language: str = "en"
    ) -> dict[str, Any]:
        try:
            self.store.validate_draft(_mapping(payload))
            return {"ok": True, "message": "", "errors": {}}
        except TelegramAlertValidationError as exc:
            return _validation_result(exc, language)

    @pyqtSlot("QVariant", str, result="QVariant")
    def saveConfiguration(
        self, payload: Any, language: str = "en"
    ) -> dict[str, Any]:
        try:
            config = self.store.save(_mapping(payload))
        except TelegramAlertValidationError as exc:
            return _validation_result(exc, language)
        except OSError:
            return {
                "ok": False,
                "errors": {},
                "message": (
                    "Không lưu được cấu hình Telegram Alerts. Kiểm tra quyền ghi thư mục cấu hình."
                    if language == "vi"
                    else "Could not save Telegram Alerts settings. Check configuration "
                    "folder permissions."
                ),
            }
        self.configurationChanged.emit()
        return {
            "ok": True,
            "message": (
                "Đã lưu cấu hình Telegram Alerts."
                if language == "vi"
                else "Telegram Alerts settings saved."
            ),
            "errors": {},
            "configuration": config.public_dict(),
        }

    @pyqtSlot("QVariant", str, result="QVariant")
    def sendTestTelegram(
        self, payload: Any, language: str = "en"
    ) -> dict[str, Any]:
        if self._shutdown:
            return {
                "ok": False,
                "message": "Telegram alert service is shutting down.",
                "errors": {},
            }
        try:
            config = self.store.validate_draft(
                _mapping(payload), require_enabled_fields=True
            )
        except TelegramAlertValidationError as exc:
            return _validation_result(exc, language)

        selected_language = "vi" if language == "vi" else "en"
        with self._test_lock:
            if self._test_sending:
                return {
                    "ok": False,
                    "errors": {},
                    "message": (
                        "Tin nhắn thử đang được gửi. Chờ kết quả trước khi thử lại."
                        if selected_language == "vi"
                        else "A test Telegram message is already being sent. Wait for "
                        "the result before retrying."
                    ),
                }
            self._test_sending = True
        self.testStateChanged.emit()

        def task() -> None:
            try:
                send_telegram_message(
                    config,
                    [test_record(selected_language)],
                    selected_language,
                    True,
                )
                message = (
                    "Đã gửi tin nhắn thử tới Telegram."
                    if selected_language == "vi"
                    else "Test message sent to Telegram."
                )
                ok = True
            except Exception as exc:
                message = delivery_error_message(exc, selected_language)
                LOGGER.warning("Syslog test Telegram delivery failed: %s", message)
                ok = False
            finally:
                with self._test_lock:
                    self._test_sending = False
                self.testStateChanged.emit()
            self.testTelegramFinished.emit(ok, message)

        try:
            self._executor.submit(task)
        except RuntimeError:
            with self._test_lock:
                self._test_sending = False
            self.testStateChanged.emit()
            return {
                "ok": False,
                "message": (
                    "Dịch vụ Telegram Alerts đang dừng."
                    if selected_language == "vi"
                    else "Telegram alert service is shutting down."
                ),
                "errors": {},
            }
        return {
            "ok": True,
            "message": (
                "Đang gửi tin nhắn thử..."
                if selected_language == "vi"
                else "Sending test Telegram message..."
            ),
            "errors": {},
        }

    def submit(self, records: list[dict[str, Any]]) -> int:
        return self.service.submit(records, self._language())

    @pyqtSlot()
    def shutdown(self) -> None:
        if self._shutdown:
            return
        self._shutdown = True
        self.service.shutdown()
        self._executor.shutdown(wait=True, cancel_futures=True)


__all__ = ["TelegramAlertManager"]
