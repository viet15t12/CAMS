"""Qt/QML controller for email alert settings and test delivery."""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import logging
import os
from pathlib import Path
import threading
from typing import Any

from PyQt6.QtCore import QObject, QStandardPaths, pyqtProperty, pyqtSignal, pyqtSlot

from ..alerts.service import (
    EmailAlertService,
    delivery_error_message,
    send_smtp_message,
    test_record,
)
from ..alerts.settings import AlertSettingsStore, AlertValidationError


LOGGER = logging.getLogger(__name__)


_VI_VALIDATION = {
    "Select at least one Syslog level to alert on.": "Chọn ít nhất 1 mức log cần cảnh báo.",
    "SMTP server is required.": "Nhập máy chủ SMTP.",
    "SMTP port must be between 1 and 65535.": "Cổng SMTP phải từ 1 đến 65535.",
    "Select Auto, SSL/TLS, or STARTTLS for SMTP security.": "Chọn Auto, SSL/TLS hoặc STARTTLS cho bảo mật SMTP.",
    "Sender email is invalid.": "Email gửi không hợp lệ.",
    "Sender App Password is required.": "Nhập App Password của tài khoản gửi.",
    "Add at least one recipient email.": "Thêm ít nhất 1 email nhận.",
    "Email address is invalid.": "Email không hợp lệ.",
    "This email is already in the list.": "Email này đã có trong danh sách.",
    "A maximum of 20 recipients is supported.": "Danh sách hỗ trợ tối đa 20 người nhận.",
    "Cooldown must be between 0 and 86400 seconds.": "Thời gian chống trùng phải từ 0 đến 86400 giây.",
    "Batch window must be between 0 and 86400 seconds.": "Thời gian gom cảnh báo phải từ 0 đến 86400 giây.",
}


def _mapping(value: Any) -> dict[str, Any]:
    if value is None:
        return {}
    to_variant = getattr(value, "toVariant", None)
    if callable(to_variant):
        value = to_variant()
    return dict(value) if isinstance(value, dict) else dict(value or {})


def _validation_result(exc: AlertValidationError, language: str) -> dict[str, Any]:
    errors = {
        key: (_VI_VALIDATION.get(message, message) if language == "vi" else message)
        for key, message in exc.errors.items()
    }
    return {
        "ok": False,
        "message": next(iter(errors.values()), "Invalid email alert settings."),
        "errors": errors,
    }


class EmailAlertManager(QObject):
    configurationChanged = pyqtSignal()
    testEmailFinished = pyqtSignal(bool, str)
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
        override = os.environ.get("CAMS_ALERT_SETTINGS", "").strip()
        default_root = Path(
            QStandardPaths.writableLocation(QStandardPaths.StandardLocation.AppConfigLocation)
        )
        path = Path(settings_path or override or (default_root / "alert_settings.json"))
        self.store = AlertSettingsStore(path)
        self._language_getter = language_getter or (lambda: "en")
        self.service = EmailAlertService(self.store, on_error=self._report_alert_error)
        self._executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="email-alert-test")
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
        LOGGER.warning("Syslog email alert delivery failed: %s", message)
        self.alertError.emit(str(message))

    @pyqtSlot(result="QVariant")
    def loadConfiguration(self) -> dict[str, Any]:
        return self.store.public_values()

    @pyqtSlot("QVariant", str, result="QVariant")
    def validateConfiguration(self, payload: Any, language: str = "en") -> dict[str, Any]:
        try:
            self.store.validate_draft(_mapping(payload))
            return {"ok": True, "message": "", "errors": {}}
        except AlertValidationError as exc:
            return _validation_result(exc, language)

    @pyqtSlot("QVariant", str, result="QVariant")
    def saveConfiguration(self, payload: Any, language: str = "en") -> dict[str, Any]:
        values = _mapping(payload)
        try:
            config = self.store.save(values)
        except AlertValidationError as exc:
            return _validation_result(exc, language)
        except OSError:
            return {"ok": False, "errors": {}, "message": (
                "Không lưu được cấu hình Email Alerts. Kiểm tra quyền ghi thư mục cấu hình."
                if language == "vi" else
                "Could not save Email Alerts settings. Check configuration folder permissions."
            )}
        self.configurationChanged.emit()
        warning = ""
        supplied = str(values.get("sender_app_password") or "").replace(" ", "")
        if supplied and config.smtp_host.casefold() == "smtp.gmail.com" and len(supplied) != 16:
            warning = (
                "Đã lưu. App Password Gmail thường có 16 ký tự; hãy kiểm tra lại nếu gửi thất bại."
                if language == "vi"
                else "Saved. Gmail App Passwords normally contain 16 characters; recheck it if delivery fails."
            )
        return {
            "ok": True,
            "message": warning or ("Đã lưu cấu hình Email Alerts." if language == "vi" else "Email Alerts settings saved."),
            "errors": {},
            "configuration": config.public_dict(),
        }

    @pyqtSlot("QVariant", str, result="QVariant")
    def sendTestEmail(self, payload: Any, language: str = "en") -> dict[str, Any]:
        if self._shutdown:
            return {"ok": False, "message": "Email alert service is shutting down.", "errors": {}}
        try:
            config = self.store.validate_draft(
                _mapping(payload), require_enabled_fields=True
            )
        except AlertValidationError as exc:
            return _validation_result(exc, language)

        selected_language = "vi" if language == "vi" else "en"
        with self._test_lock:
            if self._test_sending:
                return {"ok": False, "errors": {}, "message": (
                    "Email thử đang được gửi. Chờ kết quả trước khi thử lại."
                    if selected_language == "vi" else
                    "A test email is already being sent. Wait for the result before retrying."
                )}
            self._test_sending = True
        self.testStateChanged.emit()

        def task() -> None:
            try:
                send_smtp_message(
                    config, [test_record(selected_language)], selected_language, True
                )
                count = len(config.recipients)
                message = (
                    f"Đã gửi email thử tới {count} người nhận. Kiểm tra cả mục Spam."
                    if selected_language == "vi"
                    else f"Test email sent to {count} recipient(s). Check the Spam folder too."
                )
                ok = True
            except Exception as exc:
                message = delivery_error_message(exc, selected_language)
                LOGGER.warning("Syslog test email delivery failed: %s", message)
                ok = False
            finally:
                with self._test_lock:
                    self._test_sending = False
                self.testStateChanged.emit()
            self.testEmailFinished.emit(ok, message)

        try:
            self._executor.submit(task)
        except RuntimeError:
            with self._test_lock:
                self._test_sending = False
            self.testStateChanged.emit()
            return {"ok": False, "message": (
                "Dịch vụ Email Alerts đang dừng." if selected_language == "vi" else
                "Email alert service is shutting down."
            ), "errors": {}}
        return {
            "ok": True,
            "message": "Đang gửi email thử..." if selected_language == "vi" else "Sending test email...",
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


__all__ = ["EmailAlertManager"]
