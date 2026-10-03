"""PyQt6 QObject controller exposing the security audit service to QML."""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import logging
from pathlib import Path
from typing import Any

from PyQt6.QtCore import QObject, pyqtProperty, pyqtSignal, pyqtSlot

from .models import DeviceAuditReport, NetworkAuditSummary
from .service import SecurityComplianceService

LOGGER = logging.getLogger(__name__)


class SecurityAuditController(QObject):
    """Bridge between QML views and the Security Compliance audit engine."""

    isAuditingChanged = pyqtSignal(bool)
    auditFinished = pyqtSignal()
    selectedHostChanged = pyqtSignal()
    summaryChanged = pyqtSignal()
    errorOccurred = pyqtSignal(str)

    def __init__(
        self,
        service: SecurityComplianceService,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self.service = service
        self._is_auditing = False
        self._summary: NetworkAuditSummary | None = None
        self._selected_host = ""
        self._executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="audit-worker")

    @pyqtProperty(bool, notify=isAuditingChanged)
    def isAuditing(self) -> bool:
        return self._is_auditing

    def _set_is_auditing(self, value: bool) -> None:
        if self._is_auditing != value:
            self._is_auditing = value
            self.isAuditingChanged.emit(value)

    @pyqtProperty(float, notify=summaryChanged)
    def averageScore(self) -> float:
        return self._summary.average_score if self._summary else 0.0

    @pyqtProperty(str, notify=summaryChanged)
    def overallGrade(self) -> str:
        return self._summary.overall_grade if self._summary else "--"

    @pyqtProperty(int, notify=summaryChanged)
    def totalDevices(self) -> int:
        return self._summary.total_devices if self._summary else 0

    @pyqtProperty(int, notify=summaryChanged)
    def healthyDevices(self) -> int:
        return self._summary.healthy_devices if self._summary else 0

    @pyqtProperty(int, notify=summaryChanged)
    def warningDevices(self) -> int:
        return self._summary.warning_devices if self._summary else 0

    @pyqtProperty(int, notify=summaryChanged)
    def criticalDevices(self) -> int:
        return self._summary.critical_devices if self._summary else 0

    @pyqtProperty(int, notify=summaryChanged)
    def totalCriticalFails(self) -> int:
        return self._summary.total_critical_fails if self._summary else 0

    @pyqtProperty(int, notify=summaryChanged)
    def totalHighFails(self) -> int:
        return self._summary.total_high_fails if self._summary else 0

    @pyqtProperty("QVariant", notify=summaryChanged)
    def deviceReports(self) -> list[dict[str, Any]]:
        if not self._summary:
            return []
        return [r.to_dict() for r in self._summary.device_reports]

    @pyqtProperty(str, notify=selectedHostChanged)
    def selectedHost(self) -> str:
        return self._selected_host

    @selectedHost.setter
    def selectedHost(self, host: str) -> None:
        clean = (host or "").strip()
        if self._selected_host != clean:
            self._selected_host = clean
            self.selectedHostChanged.emit()

    @pyqtProperty("QVariant", notify=selectedHostChanged)
    def selectedReport(self) -> dict[str, Any]:
        if not self._summary:
            return {}
        for r in self._summary.device_reports:
            if r.host == self._selected_host:
                return r.to_dict()
        if self._summary.device_reports:
            return self._summary.device_reports[0].to_dict()
        return {}

    @pyqtSlot()
    def runAuditAll(self) -> None:
        """Trigger background audit for all devices in the current workspace."""
        if self._is_auditing:
            return

        self._set_is_auditing(True)

        def worker() -> None:
            try:
                summary = self.service.audit_all()
                self._summary = summary
                if summary.device_reports and (
                    not self._selected_host
                    or not any(r.host == self._selected_host for r in summary.device_reports)
                ):
                    self._selected_host = summary.device_reports[0].host
                    self.selectedHostChanged.emit()
                self.summaryChanged.emit()
                self.auditFinished.emit()
            except Exception as exc:
                LOGGER.exception("Audit execution failed: %s", exc)
                self.errorOccurred.emit(str(exc))
            finally:
                self._set_is_auditing(False)

        self._executor.submit(worker)

    @pyqtSlot(str)
    def selectDevice(self, host: str) -> None:
        self.selectedHost = host

    @pyqtSlot(result=str)
    def exportMarkdownReport(self) -> str:
        """Return the complete audit report as formatted Markdown string."""
        if not self._summary:
            return "Chưa có dữ liệu kiểm định. Vui lòng nhấn 'Quét lại toàn mạng' trước khi xuất báo cáo."
        return self.service.export_markdown(self._summary)

    @pyqtSlot(str, result="QVariant")
    def exportMarkdownToFile(self, filepath: str) -> dict[str, Any]:
        if not self._summary:
            return {"ok": False, "message": "Chưa có dữ liệu kiểm định để xuất."}
        try:
            target = Path(filepath).expanduser().resolve()
            target.parent.mkdir(parents=True, exist_ok=True)
            text = self.service.export_markdown(self._summary)
            target.write_text(text, encoding="utf-8")
            return {
                "ok": True,
                "path": str(target),
                "message": f"Đã xuất báo cáo thành công ra: {target.name}",
            }
        except Exception as exc:
            return {"ok": False, "message": f"Lỗi khi lưu tệp: {exc}"}

    @pyqtSlot(str)
    def copyToClipboard(self, text: str) -> None:
        from PyQt6.QtGui import QGuiApplication
        cb = QGuiApplication.clipboard()
        if cb:
            cb.setText(text or "")

    def shutdown(self) -> None:
        self._executor.shutdown(wait=False, cancel_futures=True)
