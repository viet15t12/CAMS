"""Versioned automation event objects shared by detection and persistence."""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any

from ..domain.models import SyslogMessage


AUTOMATION_EVENT_SCHEMA_VERSION = 1


@dataclass(frozen=True, slots=True)
class AutomationEvent:
    """A normalized security event safe to persist in the automation outbox."""

    event_id: str
    event_type: str
    device_host: str
    subject_key: str
    detected_at: str
    fingerprint: str
    attributes: dict[str, Any]
    evidence: dict[str, Any]
    schema_version: int = AUTOMATION_EVENT_SCHEMA_VERSION

    def database_values(self) -> tuple[Any, ...]:
        """Return the stable column order used by the SQLite repository."""
        return (
            self.event_id,
            self.schema_version,
            self.event_type,
            self.device_host,
            self.subject_key,
            json.dumps(self.attributes, ensure_ascii=False, sort_keys=True, separators=(",", ":")),
            json.dumps(self.evidence, ensure_ascii=False, sort_keys=True, separators=(",", ":")),
            self.detected_at,
            self.fingerprint,
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema_version": self.schema_version,
            "event_id": self.event_id,
            "event_type": self.event_type,
            "device_host": self.device_host,
            "detected_at": self.detected_at,
            "subject_key": self.subject_key,
            "attributes": dict(self.attributes),
            "evidence": dict(self.evidence),
            "fingerprint": self.fingerprint,
        }


@dataclass(frozen=True, slots=True)
class AutomationDetection:
    """A human-facing synthetic Syslog alert plus its machine-facing event."""

    alert: SyslogMessage
    event: AutomationEvent


def create_automation_event(
    *,
    event_type: str,
    device_host: str,
    subject_key: str,
    detected_at: str,
    attributes: dict[str, Any],
    evidence: dict[str, Any],
) -> AutomationEvent:
    """Build a deterministic ID so replay cannot duplicate an outbox event."""
    normalized_type = str(event_type or "").strip().upper()
    normalized_device = str(device_host or "").strip()
    normalized_subject = str(subject_key or "").strip()
    if not normalized_type or not normalized_device or not normalized_subject:
        raise ValueError("automation event requires type, device_host and subject_key")

    source_ids = sorted({
        int(value)
        for value in evidence.get("source_message_ids", [])
        if isinstance(value, int) and not isinstance(value, bool) and value > 0
    })
    normalized_evidence = dict(evidence)
    normalized_evidence["source_message_ids"] = source_ids
    identity = {
        "schema_version": AUTOMATION_EVENT_SCHEMA_VERSION,
        "event_type": normalized_type,
        "device_host": normalized_device,
        "subject_key": normalized_subject,
        "source_message_ids": source_ids,
    }
    # Stored Syslog rows always have IDs. The timestamp is a safe fallback for
    # isolated detector tests and callers that have not persisted a row yet.
    if not source_ids:
        identity["detected_at"] = detected_at
    canonical = json.dumps(identity, sort_keys=True, separators=(",", ":")).encode("utf-8")
    fingerprint = hashlib.sha256(canonical).hexdigest()
    return AutomationEvent(
        event_id=f"evt-{fingerprint[:32]}",
        event_type=normalized_type,
        device_host=normalized_device,
        subject_key=normalized_subject,
        detected_at=detected_at,
        fingerprint=fingerprint,
        attributes=dict(attributes),
        evidence=normalized_evidence,
    )
