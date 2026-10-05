"""Security log categories shared by stored queries and live notifications.

Classification describes the device event; a security event is not necessarily
an attack. Threshold-based attack alerts remain in application/security_events.
"""

from __future__ import annotations

import re
from typing import Any, Mapping


SECURITY_LABELS = {
    "acl": "ACL",
    "dhcp_snooping": "DHCP Snooping",
    "port_security": "Port Security",
    "dai": "Dynamic ARP Inspection",
    "authentication": "Authentication",
    "stp_guard": "STP Protection",
    "security_alert": "Security Alert",
}

# Literal prefixes are compared with substr rather than LIKE so underscores
# in facility names cannot become wildcard matches. Order matches Python.
SECURITY_PREFIXES = {
    "security_alert": ("CAMS-SECURITY-",),
    "acl": ("SEC-IPACCESSLOG", "SEC-ACCESSLOG", "ACL-", "IPACL-"),
    "dhcp_snooping": ("DHCP_SNOOPING-",),
    "port_security": ("PORT_SECURITY-",),
    "dai": ("SW_DAI-", "DAI-"),
    "authentication": ("SEC_LOGIN-", "AAA-", "AUTHMGR-", "DOT1X-", "MAB-", "SSH-"),
    "stp_guard": ("SPANTREE-BLOCK", "SPANTREE-ROOTGUARD", "SPANTREE-LOOPGUARD", "SPANTREE-BPDU"),
}

SECURITY_OUTCOME_LABELS = {
    "permit": "Permitted",
    "deny": "Denied",
    "violation": "Violation",
    "recovery": "Recovered",
    "operational": "Operational",
    "alert": "Security alert",
}
_PM_REASONS = {
    "port_security": ("psecure",),
    "dhcp_snooping": ("dhcp-rate-limit",),
    "dai": ("arp-inspection",),
    "stp_guard": ("bpduguard", "rootguard", "loopguard"),
}
_DHCP_DENY_MNEMONICS = {
    "DHCP_SNOOPING_UNTRUSTED_PORT", "DHCP_SNOOPING_MAC_NOT_EQUAL",
    "DHCP_SNOOPING_NONZERO_GIADDR", "DHCP_SNOOPING_RATE_LIMIT",
}
_DENY_TEXT_RE = re.compile(r"\b(?:drop(?:ped|ping)?|denied|discard(?:ed|ing)?|invalid ARPs?)\b", re.I)
_DAI_INVALID_TEXT_RE = re.compile(r"\bInvalid\s+ARPs?(?:\s*\(|\s+(?:on|packets?)\b)", re.I)


def security_outcome(row: Mapping[str, Any], feature: str | None = None) -> str:
    """Describe observed behavior without treating operational logs as violations."""
    feature = security_feature(row) if feature is None else feature
    if not feature:
        return ""
    mnemonic = str(row.get("mnemonic") or "").upper()
    message = str(row.get("message") or "")
    if feature == "security_alert":
        return "alert"
    if any(token in mnemonic for token in ("UNBLOCK", "RECOVER", "RESTORE")):
        return "recovery"
    if mnemonic.endswith("PERMIT") or (
        feature == "acl" and re.search(r"\bpermitted\b", message, re.I)
    ):
        return "permit"
    if mnemonic == "ERR_DISABLE":
        return "violation"
    if feature == "dhcp_snooping":
        if mnemonic in _DHCP_DENY_MNEMONICS or _DENY_TEXT_RE.search(message):
            return "deny"
    elif feature == "dai":
        if "DENY" in mnemonic or mnemonic == "INVALID_ARP" or _DAI_INVALID_TEXT_RE.search(message):
            return "deny"
    elif feature == "acl":
        if re.search(r"\bdenied\b", message, re.I):
            return "deny"
    elif feature == "port_security" and "VIOLATION" in mnemonic:
        return "violation"
    elif feature == "stp_guard" and "BLOCK" in mnemonic:
        return "violation"
    return "operational"


def _event_code(row: Mapping[str, Any]) -> str:
    facility = str(row.get("cisco_facility") or row.get("facility") or "").upper()
    subfacility = str(row.get("cisco_subfacility") or "").upper()
    mnemonic = str(row.get("mnemonic") or "").upper()
    return facility + "-" + (subfacility + "-" if subfacility else "") + mnemonic


def security_feature(row: Mapping[str, Any]) -> str:
    code = _event_code(row)
    for feature, prefixes in SECURITY_PREFIXES.items():
        if code.startswith(prefixes):
            return feature
    if code.startswith("PM-"):
        message = str(row.get("message") or "").lower()
        for feature, reasons in _PM_REASONS.items():
            if any(reason in message for reason in reasons):
                return feature
    return ""


def annotate_security(row: Mapping[str, Any]) -> dict[str, Any]:
    result = dict(row)
    feature = security_feature(row)
    result["security_feature"] = feature
    result["security_label"] = SECURITY_LABELS.get(feature, "")
    outcome = security_outcome(row, feature)
    result["security_outcome"] = outcome
    result["security_outcome_label"] = SECURITY_OUTCOME_LABELS.get(outcome, "")
    return result


def normalize_security_filter(value: Any) -> str:
    feature = str(value or "").strip().lower().replace("-", "_")
    if feature and feature != "all" and feature not in SECURITY_LABELS:
        raise ValueError("Unknown security feature. Use all, " + ", ".join(SECURITY_LABELS) + ".")
    return feature


def security_filter_clause(value: Any) -> tuple[str, list[Any]]:
    """Return a parameterized predicate with the same rules as live events."""
    feature = normalize_security_filter(value)
    if not feature:
        return "", []
    code = (
        "UPPER(COALESCE(NULLIF(cisco_facility, ''), facility, '')) || '-' || "
        "CASE WHEN COALESCE(cisco_subfacility, '') <> '' "
        "THEN UPPER(cisco_subfacility) || '-' ELSE '' END || "
        "UPPER(COALESCE(mnemonic, ''))"
    )
    features = tuple(SECURITY_LABELS) if feature == "all" else (feature,)
    clauses: list[str] = []
    params: list[Any] = []
    for selected in features:
        for prefix in SECURITY_PREFIXES[selected]:
            clauses.append(f"substr({code}, 1, ?) = ?")
            params.extend((len(prefix), prefix))
        for reason in _PM_REASONS.get(selected, ()):
            clauses.append(f"(substr({code}, 1, 3) = 'PM-' AND instr(LOWER(message), ?) > 0)")
            params.append(reason)
    return "(" + " OR ".join(clauses) + ")", params


__all__ = [
    "SECURITY_LABELS", "SECURITY_OUTCOME_LABELS", "annotate_security",
    "normalize_security_filter", "security_feature", "security_filter_clause", "security_outcome",
]
