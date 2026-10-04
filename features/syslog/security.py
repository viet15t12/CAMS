"""Security log categories shared by stored queries and live notifications.

Classification describes the device event; a security event is not necessarily
an attack. Threshold-based attack alerts remain in application/security_events.
"""

from __future__ import annotations

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
    if code.startswith("PM-") and "psecure" in str(row.get("message") or "").lower():
        return "port_security"
    return ""


def annotate_security(row: Mapping[str, Any]) -> dict[str, Any]:
    result = dict(row)
    feature = security_feature(row)
    result["security_feature"] = feature
    result["security_label"] = SECURITY_LABELS.get(feature, "")
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
        if selected == "port_security":
            clauses.append(f"(substr({code}, 1, 3) = 'PM-' AND instr(LOWER(message), 'psecure') > 0)")
    return "(" + " OR ".join(clauses) + ")", params


__all__ = ["SECURITY_LABELS", "annotate_security", "normalize_security_filter", "security_feature", "security_filter_clause"]
