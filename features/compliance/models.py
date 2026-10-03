"""Data models for Cisco IOS security compliance audit."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from enum import Enum
from typing import Any


class AuditSeverity(str, Enum):
    CRITICAL = "critical"
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


class AuditStatus(str, Enum):
    PASS = "pass"
    FAIL = "fail"
    WARNING = "warning"
    NOT_APPLICABLE = "na"


class AuditCategory(str, Enum):
    AUTH = "auth"
    MGMT = "mgmt"
    HARDENING = "hardening"
    LOGGING = "logging"
    L2_SECURITY = "l2_security"


CATEGORY_TITLES = {
    AuditCategory.AUTH.value: "Xác thực & Kiểm soát truy cập (Authentication)",
    AuditCategory.MGMT.value: "Quản trị từ xa an toàn (Remote Management)",
    AuditCategory.HARDENING.value: "Vô hiệu hóa dịch vụ rủi ro (Service Hardening)",
    AuditCategory.LOGGING.value: "Ghi nhật ký & Đồng bộ thời gian (Logging & Time)",
    AuditCategory.L2_SECURITY.value: "An ninh hạ tầng Lớp 2 (Layer 2 Security)",
}


@dataclass(frozen=True)
class AuditRuleDefinition:
    id: str
    title: str
    category: str
    severity: str
    description: str
    rationale: str
    remediation: str
    weight: int = 10
    applicable_roles: tuple[str, ...] = ("rou", "sw2", "sw3")


@dataclass
class RuleResult:
    rule_id: str
    title: str
    category: str
    severity: str
    status: str  # pass, fail, warning, na
    details: str
    matched_lines: list[str] = field(default_factory=list)
    remediation: str = ""

    @property
    def category_title(self) -> str:
        return CATEGORY_TITLES.get(self.category, self.category)

    def to_dict(self) -> dict[str, Any]:
        return {
            "ruleId": self.rule_id,
            "title": self.title,
            "category": self.category,
            "categoryTitle": self.category_title,
            "severity": self.severity,
            "status": self.status,
            "details": self.details,
            "matchedLines": self.matched_lines,
            "remediation": self.remediation,
        }


@dataclass
class DeviceAuditReport:
    host: str
    device_name: str
    role: str
    score: int  # 0 to 100
    grade: str  # A, B, C, D, F
    passed_count: int
    failed_count: int
    warnings_count: int
    total_rules: int
    results: list[RuleResult] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "host": self.host,
            "deviceName": self.device_name,
            "role": self.role,
            "score": self.score,
            "grade": self.grade,
            "passedCount": self.passed_count,
            "failedCount": self.failed_count,
            "warningsCount": self.warnings_count,
            "totalRules": self.total_rules,
            "results": [r.to_dict() for r in self.results],
        }


@dataclass
class NetworkAuditSummary:
    average_score: float
    overall_grade: str
    total_devices: int
    healthy_devices: int
    warning_devices: int
    critical_devices: int
    total_critical_fails: int
    total_high_fails: int
    device_reports: list[DeviceAuditReport] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "averageScore": round(self.average_score, 1),
            "overallGrade": self.overall_grade,
            "totalDevices": self.total_devices,
            "healthyDevices": self.healthy_devices,
            "warningDevices": self.warning_devices,
            "criticalDevices": self.critical_devices,
            "totalCriticalFails": self.total_critical_fails,
            "totalHighFails": self.total_high_fails,
            "deviceReports": [r.to_dict() for r in self.device_reports],
        }
