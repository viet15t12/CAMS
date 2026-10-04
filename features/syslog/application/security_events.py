"""Detect attack-like patterns in Cisco security Syslog messages.

A single ACL ``deny`` or a single port-security violation is normal noise, but
the *same* offender triggering it again and again inside a short window usually
means a DoS/DDoS flood, a scan, ARP spoofing, a rogue DHCP server or a MAC
flood.  This module is framework independent: it receives stored Syslog rows
(``dict``), keeps a bounded sliding window per offender and returns synthetic
``%CAMS-<sev>-<MNEMONIC>`` messages when a rule threshold is crossed.  The
caller stores/publishes them like any other Syslog row, so they appear in
System Logs and can trigger e-mail alerts.
"""

from __future__ import annotations

import ipaddress
import re
import threading
import time
from collections import deque
from collections.abc import Callable, Iterable
from dataclasses import dataclass, field
from typing import Any

from ..domain.models import SyslogMessage


ALERT_FACILITY = "CAMS"
ALERT_SUBFACILITY = "SECURITY"
_LOCAL7_FACILITY = 23

_MAC_RE = re.compile(r"\b([0-9A-Fa-f]{4}\.[0-9A-Fa-f]{4}\.[0-9A-Fa-f]{4})\b")
_INTERFACE_RE = re.compile(
    r"(?:\bon(?:\s+interface|\s+port)?|\bport|\binterface)[\s:]+"
    r"([A-Za-z][A-Za-z-]*\d+(?:/\d+){0,3}(?:\.\d+)?)",
    re.IGNORECASE,
)
_ACL_RE = re.compile(
    r"list\s+(?P<acl>\S+)\s+(?P<action>denied|permitted)\s+(?P<rest>.*?)"
    r"[,\s]*(?P<count>\d+)\s+packets?\b",
    re.IGNORECASE | re.DOTALL,
)
_TOKEN_RE = re.compile(r"[0-9A-Fa-f:.]+")
_PORT_RE = re.compile(r"\((\d+)\)")
_DHCP_SERVER_MESSAGE_RE = re.compile(r"\bDHCP(?:OFFER|ACK|NAK)\b", re.IGNORECASE)


@dataclass(frozen=True, slots=True)
class DetectionRule:
    """Thresholds for one attack pattern."""

    name: str
    severity: int
    window_seconds: float
    min_events: int
    min_packets: int = 0
    cooldown_seconds: float = 300.0

    def crossed(self, events: int, packets: int) -> bool:
        return events >= self.min_events or (
            self.min_packets > 0 and packets >= self.min_packets
        )


DEFAULT_RULES: dict[str, DetectionRule] = {
    # >=10 denied flows or >=100 denied packets from one source within 60 s.
    "ACL_DROP_FLOOD": DetectionRule("ACL_DROP_FLOOD", 2, 60, 10, 100),
    # DHCPOFFER/ACK/NAK received on an untrusted port: a rogue DHCP server.
    "DHCP_ROGUE_SERVER": DetectionRule("DHCP_ROGUE_SERVER", 2, 60, 3),
    # Many other snooping drops from one source: starvation / spoofing.
    "DHCP_SNOOPING_FLOOD": DetectionRule("DHCP_SNOOPING_FLOOD", 3, 60, 10),
    # Repeated invalid ARP from one sender/interface: ARP spoofing.
    "DAI_ARP_SPOOF": DetectionRule("DAI_ARP_SPOOF", 3, 60, 5),
    # Repeated violations on one port: unauthorised device or MAC flooding.
    "PORT_SECURITY_REPEAT": DetectionRule("PORT_SECURITY_REPEAT", 2, 60, 3),
}


@dataclass(frozen=True, slots=True)
class SecurityEvent:
    """Normalised security-relevant fields extracted from one Syslog row."""

    rule: str
    key: str
    description: str
    packets: int = 1
    target: str = ""
    detail: str = ""


def _text(row: dict[str, Any]) -> str:
    return str(row.get("message") or row.get("raw_message") or "")


def _facility(row: dict[str, Any]) -> str:
    return str(row.get("cisco_facility") or "").upper()


def _valid_ip(token: str) -> str | None:
    try:
        return str(ipaddress.ip_address(token.strip(".,:")))
    except ValueError:
        return None


def _first_ip(text: str) -> tuple[str | None, int]:
    for match in _TOKEN_RE.finditer(text):
        address = _valid_ip(match.group(0))
        if address:
            return address, match.end()
    return None, 0


def _interface(text: str) -> str:
    match = _INTERFACE_RE.search(text)
    return match.group(1) if match else ""


def _classify_acl(row: dict[str, Any]) -> SecurityEvent | None:
    mnemonic = str(row.get("mnemonic") or "").upper()
    if "ACCESSLOG" not in mnemonic:
        return None
    match = _ACL_RE.search(_text(row))
    if not match or match.group("action").lower() != "denied":
        return None
    rest = match.group("rest")
    source_part, _, target_part = rest.partition("->")
    source, _ = _first_ip(source_part)
    if not source:
        return None
    target, end = _first_ip(target_part) if target_part else (None, 0)
    port = _PORT_RE.search(target_part[end:end + 12]) if target and target_part else None
    target_text = f"{target}:{port.group(1)}" if target and port else (target or "")
    return SecurityEvent(
        rule="ACL_DROP_FLOOD",
        key=source,
        description=f"ACL {match.group('acl')}",
        packets=max(1, int(match.group("count"))),
        target=target_text,
        detail=f"ACL {match.group('acl')}",
    )


def _classify_dhcp_snooping(row: dict[str, Any]) -> SecurityEvent | None:
    if _facility(row) != "DHCP_SNOOPING" and not "DHCP_SNOOPING" in _text(row):
        return None
    text = _text(row)
    mac = re.search(r"MAC sa:\s*" + _MAC_RE.pattern, text, re.IGNORECASE)
    offender_mac = mac.group(1).lower() if mac else ""
    if not offender_mac:
        any_mac = _MAC_RE.search(text)
        offender_mac = any_mac.group(1).lower() if any_mac else ""
    interface = _interface(text)
    key = offender_mac or interface or str(row.get("device_host") or "")
    rogue = _DHCP_SERVER_MESSAGE_RE.search(text) is not None and (
        "untrusted" in text.lower()
    )
    return SecurityEvent(
        rule="DHCP_ROGUE_SERVER" if rogue else "DHCP_SNOOPING_FLOOD",
        key=key,
        description="DHCP Snooping",
        target=interface,
    )


def _classify_dai(row: dict[str, Any]) -> SecurityEvent | None:
    if _facility(row) != "SW_DAI":
        return None
    text = _text(row)
    mac = _MAC_RE.search(text)
    interface = _interface(text)
    key = mac.group(1).lower() if mac else (interface or str(row.get("device_host") or ""))
    return SecurityEvent(
        rule="DAI_ARP_SPOOF",
        key=key,
        description="Dynamic ARP Inspection",
        target=interface,
    )


def _classify_port_security(row: dict[str, Any]) -> SecurityEvent | None:
    facility = _facility(row)
    text = _text(row)
    if facility == "PM" and "psecure-violation" in text.lower():
        interface = _interface(text)
        return SecurityEvent(
            rule="PORT_SECURITY_REPEAT",
            key=interface or str(row.get("device_host") or ""),
            description="Port Security",
            target=interface,
        )
    if facility != "PORT_SECURITY":
        return None
    if "VIOLATION" not in str(row.get("mnemonic") or "").upper():
        return None
    interface = _interface(text)
    mac = _MAC_RE.search(text)
    return SecurityEvent(
        rule="PORT_SECURITY_REPEAT",
        key=interface or (mac.group(1).lower() if mac else str(row.get("device_host") or "")),
        description="Port Security",
        target=interface,
        detail=mac.group(1).lower() if mac else "",
    )


_CLASSIFIERS: tuple[Callable[[dict[str, Any]], SecurityEvent | None], ...] = (
    _classify_acl,
    _classify_dhcp_snooping,
    _classify_dai,
    _classify_port_security,
)


def classify_security_event(row: dict[str, Any]) -> SecurityEvent | None:
    """Return the security event described by one Syslog row, if any."""
    if _facility(row) == ALERT_FACILITY:
        return None
    for classifier in _CLASSIFIERS:
        event = classifier(row)
        if event is not None:
            return event
    return None


@dataclass(slots=True)
class _Window:
    hits: deque[tuple[float, int, str, str]] = field(default_factory=deque)
    last_alert: float | None = None

    def prune(self, now: float, window: float) -> None:
        while self.hits and now - self.hits[0][0] > window:
            self.hits.popleft()


def _sample(values: Iterable[str], limit: int = 3) -> str:
    unique = list(dict.fromkeys(value for value in values if value))
    text = ", ".join(unique[:limit])
    return text + (f" +{len(unique) - limit} more" if len(unique) > limit else "")


class SecurityEventDetector:
    """Thread-safe sliding-window detector producing synthetic alert rows."""

    _MAX_KEYS = 4096

    def __init__(
        self,
        rules: dict[str, DetectionRule] | None = None,
        *,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self.rules = dict(DEFAULT_RULES if rules is None else rules)
        self._clock = clock
        self._lock = threading.Lock()
        self._windows: dict[tuple[str, str, str], _Window] = {}

    def process(self, rows: Iterable[dict[str, Any]]) -> list[SyslogMessage]:
        alerts: list[SyslogMessage] = []
        now = self._clock()
        with self._lock:
            for row in rows:
                event = classify_security_event(row)
                if event is None:
                    continue
                rule = self.rules.get(event.rule)
                if rule is None:
                    continue
                alert = self._record(row, event, rule, now)
                if alert is not None:
                    alerts.append(alert)
            self._prune(now)
        return alerts

    def _record(
        self, row: dict[str, Any], event: SecurityEvent, rule: DetectionRule, now: float,
    ) -> SyslogMessage | None:
        device = str(row.get("device_host") or row.get("source_ip") or "")
        window = self._windows.setdefault((device.casefold(), rule.name, event.key), _Window())
        window.prune(now, rule.window_seconds)
        window.hits.append((now, event.packets, event.target, event.detail))
        events = len(window.hits)
        packets = sum(hit[1] for hit in window.hits)
        if not rule.crossed(events, packets):
            return None
        if window.last_alert is not None and now - window.last_alert < rule.cooldown_seconds:
            return None
        window.last_alert = now
        return self._build_alert(row, event, rule, device, events, packets, window)

    @staticmethod
    def _build_alert(
        row: dict[str, Any], event: SecurityEvent, rule: DetectionRule,
        device: str, events: int, packets: int, window: _Window,
    ) -> SyslogMessage:
        seconds = int(rule.window_seconds)
        targets = _sample(hit[2] for hit in window.hits)
        details = _sample(hit[3] for hit in window.hits)
        if rule.name == "ACL_DROP_FLOOD":
            message = (
                f"Possible DoS/DDoS or scan: source {event.key} was denied "
                f"{packets} packet(s) in {events} log event(s) within {seconds}s "
                f"on {device} by {details or event.description}"
                + (f"; targets: {targets}" if targets else "")
            )
        elif rule.name == "DHCP_ROGUE_SERVER":
            message = (
                f"Possible rogue DHCP server: {events} DHCP server message(s) "
                f"from {event.key} dropped on an untrusted port within {seconds}s "
                f"on {device}" + (f" (port {targets})" if targets else "")
            )
        elif rule.name == "DHCP_SNOOPING_FLOOD":
            message = (
                f"Repeated DHCP Snooping violations: {events} drop(s) from "
                f"{event.key} within {seconds}s on {device} "
                "(possible DHCP starvation or spoofing)"
            )
        elif rule.name == "DAI_ARP_SPOOF":
            message = (
                f"Possible ARP spoofing: {events} invalid ARP packet(s) from "
                f"{event.key} dropped by Dynamic ARP Inspection within {seconds}s "
                f"on {device}" + (f" (port {targets})" if targets else "")
            )
        else:
            message = (
                f"Repeated port-security violations: {events} violation(s) on "
                f"{event.key} within {seconds}s on {device}"
                + (f" from MAC {details}" if details else "")
                + " (unauthorised device or MAC flooding)"
            )
        protocol = str(row.get("protocol") or "udp").lower()
        severity = rule.severity
        return SyslogMessage(
            source_ip=str(row.get("source_ip") or ""),
            severity=severity,
            message=message,
            raw_message=f"%{ALERT_FACILITY}-{severity}-{rule.name}: {message}",
            protocol=protocol if protocol in {"udp", "tcp"} else "udp",
            device_host=str(row.get("device_host") or ""),
            syslog_pri=_LOCAL7_FACILITY * 8 + severity,
            syslog_facility=_LOCAL7_FACILITY,
            cisco_facility=ALERT_FACILITY,
            cisco_subfacility=ALERT_SUBFACILITY,
            mnemonic=rule.name,
            parse_status="parsed",
        )

    def _prune(self, now: float) -> None:
        if len(self._windows) < self._MAX_KEYS:
            return
        longest = max((rule.window_seconds for rule in self.rules.values()), default=60.0)
        for key, window in list(self._windows.items()):
            window.prune(now, longest)
            cooled = window.last_alert is None or now - window.last_alert > longest
            if not window.hits and cooled:
                del self._windows[key]


__all__ = [
    "ALERT_FACILITY",
    "DEFAULT_RULES",
    "DetectionRule",
    "SecurityEvent",
    "SecurityEventDetector",
    "classify_security_event",
]
