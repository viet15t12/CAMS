"""CAMS network automation rule management and sidecar lifecycle."""

from .manager import AutomationManager, SERVICE_COMMAND, SERVICE_NAME
from .rules import RuleFileRepository, sample_icmp_rule_text, validate_rule_payload

__all__ = [
    "AutomationManager",
    "RuleFileRepository",
    "SERVICE_COMMAND",
    "SERVICE_NAME",
    "sample_icmp_rule_text",
    "validate_rule_payload",
]
