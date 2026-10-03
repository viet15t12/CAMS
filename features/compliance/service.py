"""Service layer for running security compliance audits and exporting reports."""

from __future__ import annotations

from contextlib import closing
from datetime import datetime
import json
from pathlib import Path
import sqlite3
from typing import Any, Callable

from .engine import CiscoConfigAuditor, redact_sensitive_config_line
from .models import DeviceAuditReport, NetworkAuditSummary, RuleResult


class SecurityComplianceService:
    """Coordinates inventory discovery, configuration extraction, and audit execution."""

    def __init__(
        self,
        db_path_getter: Callable[[], str | Path | None] | str | Path,
        backup_service_getter: Callable[[], Any] | Any = None,
        auditor: CiscoConfigAuditor | None = None,
    ) -> None:
        self._db_getter = db_path_getter
        self._backup_getter = backup_service_getter
        self.auditor = auditor or CiscoConfigAuditor()

    def _resolve_db_path(self) -> Path | None:
        raw = self._db_getter() if callable(self._db_getter) else self._db_getter
        if not raw:
            return None
        path = Path(raw)
        return path if path.is_file() else None

    def _resolve_backup_service(self) -> Any:
        return self._backup_getter() if callable(self._backup_getter) else self._backup_getter

    def get_inventory(self) -> list[dict[str, Any]]:
        db_path = self._resolve_db_path()
        if not db_path:
            return []
        try:
            with closing(sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)) as conn:
                conn.row_factory = sqlite3.Row
                rows = conn.execute(
                    """
                    SELECT host, COALESCE(device_name, host) AS device_name,
                           COALESCE(role, 'rou') AS role,
                           COALESCE(connection_status, 'disconnected') AS connection_status
                    FROM t01_devices
                    ORDER BY role, device_name, host;
                    """
                ).fetchall()
                return [dict(r) for r in rows]
        except Exception:
            return []

    def get_device_config(self, host: str) -> str:
        backup = self._resolve_backup_service()
        if backup and hasattr(backup, "read_latest"):
            try:
                result = backup.read_latest(host)
                if isinstance(result, dict) and result.get("ok"):
                    return str(result.get("content") or "")
            except Exception:
                pass
        return ""

    def audit_device(
        self, host: str, device_name: str = "", role: str = ""
    ) -> DeviceAuditReport:
        target_host = (host or "").strip()
        name = device_name
        dev_role = role

        if not name or not dev_role:
            inventory = self.get_inventory()
            dev_entry = next((d for d in inventory if d["host"] == target_host), None)
            if dev_entry:
                name = name or dev_entry.get("device_name", target_host)
                dev_role = dev_role or dev_entry.get("role", "rou")

        name = name or target_host
        dev_role = dev_role or "rou"

        config_text = self.get_device_config(target_host)
        if not config_text.strip():
            # Return empty/unbacked report
            return DeviceAuditReport(
                host=target_host,
                device_name=name,
                role=dev_role,
                score=0,
                grade="F",
                passed_count=0,
                failed_count=1,
                warnings_count=0,
                total_rules=1,
                results=[
                    RuleResult(
                        rule_id="SYS-00",
                        title="Sao lưu cấu hình thiết bị (Running-Config)",
                        category="hardening",
                        severity="critical",
                        status="fail",
                        details="Chưa thu thập hoặc sao lưu running-config cho thiết bị này. Vui lòng kết nối và sao lưu cấu hình trước khi kiểm định.",
                        matched_lines=[],
                        remediation="Thực hiện kết nối và lấy cấu hình: 'show running-config'",
                    )
                ],
            )

        return self.auditor.audit(
            config_text=config_text,
            host=target_host,
            device_name=name,
            role=dev_role,
        )

    def audit_all(self) -> NetworkAuditSummary:
        inventory = self.get_inventory()
        reports: list[DeviceAuditReport] = []

        for dev in inventory:
            report = self.audit_device(
                host=dev["host"],
                device_name=dev.get("device_name", dev["host"]),
                role=dev.get("role", "rou"),
            )
            reports.append(report)

        if not reports:
            return NetworkAuditSummary(
                average_score=0.0,
                overall_grade="N/A",
                total_devices=0,
                healthy_devices=0,
                warning_devices=0,
                critical_devices=0,
                total_critical_fails=0,
                total_high_fails=0,
                device_reports=[],
            )

        avg_score = sum(r.score for r in reports) / len(reports)
        healthy = sum(1 for r in reports if r.score >= 80)
        warning = sum(1 for r in reports if 60 <= r.score < 80)
        critical = sum(1 for r in reports if r.score < 60)
        crit_fails = sum(
            sum(1 for res in r.results if res.status == "fail" and res.severity == "critical")
            for r in reports
        )
        high_fails = sum(
            sum(1 for res in r.results if res.status == "fail" and res.severity == "high")
            for r in reports
        )

        overall_grade = CiscoConfigAuditor._score_to_grade(int(avg_score))

        return NetworkAuditSummary(
            average_score=avg_score,
            overall_grade=overall_grade,
            total_devices=len(reports),
            healthy_devices=healthy,
            warning_devices=warning,
            critical_devices=critical,
            total_critical_fails=crit_fails,
            total_high_fails=high_fails,
            device_reports=reports,
        )

    @staticmethod
    def export_markdown(summary: NetworkAuditSummary) -> str:
        now = datetime.now().strftime("%d/%m/%Y %H:%M:%S")
        lines = [
            "# BÁO CÁO KIỂM ĐỊNH TUÂN THỦ AN NINH CẤU HÌNH (CISCO IOS)",
            f"*Thời gian thực hiện kiểm định:* {now}",
            "",
            "## 1. TỔNG QUAN AN NINH TOÀN MẠNG",
            "",
            f"- **Chỉ số an ninh trung bình (Network Security Score):** {summary.average_score:.1f} / 100",
            f"- **Xếp loại an toàn toàn mạng:** **Hạng {summary.overall_grade}**",
            f"- **Tổng số thiết bị:** {summary.total_devices} "
            f"(An toàn: {summary.healthy_devices}, Cảnh báo: {summary.warning_devices}, Nguy cơ cao: {summary.critical_devices})",
            f"- **Tổng số vi phạm mức Nghiêm trọng (Critical):** {summary.total_critical_fails}",
            f"- **Tổng số vi phạm mức Cao (High):** {summary.total_high_fails}",
            "",
            "### Bảng điểm an ninh chi tiết theo thiết bị",
            "",
            "| Thiết bị | Vai trò | Điểm số | Xếp hạng | Đạt (Pass) | Vi phạm (Fail) | Cảnh báo |",
            "| :--- | :---: | :---: | :---: | :---: | :---: | :---: |",
        ]

        for r in summary.device_reports:
            role_badge = "Router" if r.role == "rou" else "Switch L2/L3"
            lines.append(
                f"| **{r.device_name}** (`{r.host}`) | {role_badge} | **{r.score}/100** | **{r.grade}** | "
                f"{r.passed_count} | {r.failed_count} | {r.warnings_count} |"
            )

        lines.extend(["", "---", "", "## 2. CHI TIẾT CÁC LỖ HỔNG VÀ KHUYẾN NGHỊ KHẮC PHỤC", ""])

        for r in summary.device_reports:
            lines.append(f"### Thiết bị: {r.device_name} ({r.host}) -- Điểm: {r.score}/100 (Hạng {r.grade})")
            lines.append("")

            fails = [res for res in r.results if res.status in ("fail", "warning")]
            if not fails:
                lines.append("> ✅ Thiết bị tuân thủ đầy đủ tất cả các quy tắc an ninh cơ sở!")
                lines.append("")
                continue

            for item in fails:
                badge = "🔴 VI PHẠM (FAIL)" if item.status == "fail" else "🟡 CẢNH BÁO (WARNING)"
                sev_text = item.severity.upper()
                lines.append(f"#### [{item.rule_id}] {item.title} ({badge} - Mức: `{sev_text}`)")
                lines.append(f"- **Danh mục:** {item.category_title}")
                lines.append(f"- **Mô tả hiện trạng:** {item.details}")
                if item.matched_lines:
                    lines.append("- **Dòng cấu hình liên quan (đã lược bỏ bí mật):**")
                    lines.append("```text")
                    for m in item.matched_lines:
                        lines.append(f"  {redact_sensitive_config_line(m)}")
                    lines.append("```")
                if item.remediation:
                    lines.append("- **Câu lệnh Cisco IOS khắc phục khuyến nghị:**")
                    lines.append("```cisco")
                    lines.append(item.remediation)
                    lines.append("```")
                lines.append("")

        lines.extend([
            "---",
            "*Báo cáo được tự động tạo bởi Hệ thống Quản lý tập trung, Tự động hóa cấu hình và Giám sát an ninh mạng CAMS.*",
        ])
        return "\n".join(lines)
