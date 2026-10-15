"""CAMS network automation rule management and sidecar lifecycle."""

from .executor import AutomationActionExecutor
from .manager import AutomationManager, SERVICE_COMMAND, SERVICE_NAME
from .rules import (
    RULE_SUFFIX,
    RuleFileRepository,
    sample_cli_rule_text,
    sample_icmp_rule_text,
    validate_rule_payload,
)

__all__ = [
    "AutomationActionExecutor",
    "AutomationManager",
    "RuleFileRepository",
    "RULE_SUFFIX",
    "SERVICE_COMMAND",
    "SERVICE_NAME",
    "sample_cli_rule_text",
    "sample_icmp_rule_text",
    "validate_rule_payload",
]
