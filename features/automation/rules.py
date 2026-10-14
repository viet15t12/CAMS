"""Workspace-scoped declarative automation rule files."""

from __future__ import annotations

import json
import os
import re
import tempfile
from pathlib import Path
from typing import Any


RULE_VERSION = 1
MAX_RULE_BYTES = 256 * 1024
MAX_RULE_FILES = 256
_IDENTIFIER = re.compile(r"^[a-z0-9]+(?:[._-][a-z0-9]+)*$")
_TOP_LEVEL = {"version", "metadata", "schedule", "match", "policy", "action"}


def _require_keys(value: dict[str, Any], allowed: set[str], label: str) -> None:
    unknown = set(value) - allowed
    if unknown:
        raise ValueError(f"{label} contains unsupported field(s): {', '.join(sorted(unknown))}")


def _mapping(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a JSON object")
    return dict(value)


def validate_rule_payload(value: Any) -> dict[str, Any]:
    rule = _mapping(value, "rule")
    _require_keys(rule, _TOP_LEVEL, "rule")
    if set(rule) != _TOP_LEVEL:
        missing = _TOP_LEVEL - set(rule)
        raise ValueError(f"rule is missing: {', '.join(sorted(missing))}")
    if isinstance(rule["version"], bool) or rule["version"] != RULE_VERSION:
        raise ValueError("Only rule version 1 is supported")

    metadata = _mapping(rule["metadata"], "metadata")
    _require_keys(metadata, {"id", "name", "description", "enabled"}, "metadata")
    rule_id = str(metadata.get("id") or "")
    if not _IDENTIFIER.fullmatch(rule_id) or len(rule_id) > 96:
        raise ValueError("metadata.id must be a lowercase identifier of at most 96 characters")
    name = str(metadata.get("name") or "").strip()
    if not name or len(name) > 200:
        raise ValueError("metadata.name is required and must not exceed 200 characters")
    if not isinstance(metadata.get("enabled"), bool):
        raise ValueError("metadata.enabled must be true or false")
    if len(str(metadata.get("description") or "")) > 2000:
        raise ValueError("metadata.description must not exceed 2000 characters")

    schedule = _mapping(rule["schedule"], "schedule")
    _require_keys(schedule, {"interval_seconds"}, "schedule")
    interval = schedule.get("interval_seconds")
    if isinstance(interval, bool) or not isinstance(interval, int) or not 1 <= interval <= 3600:
        raise ValueError("schedule.interval_seconds must be between 1 and 3600")

    match = _mapping(rule["match"], "match")
    _require_keys(match, {"event_type", "require_attributes", "attributes"}, "match")
    event_type = str(match.get("event_type") or "").strip()
    if not event_type or len(event_type) > 96:
        raise ValueError("match.event_type is required")
    required = match.get("require_attributes", [])
    if not isinstance(required, list) or any(
        not isinstance(item, str) or not _IDENTIFIER.fullmatch(item) or len(item) > 96
        for item in required
    ):
        raise ValueError("match.require_attributes must contain valid attribute names")
    attributes = _mapping(match.get("attributes", {}), "match.attributes")
    if any(
        not _IDENTIFIER.fullmatch(str(key))
        or not isinstance(expected, str)
        or not expected.strip()
        for key, expected in attributes.items()
    ):
        raise ValueError("match.attributes contains an invalid equality match")

    policy = _mapping(rule["policy"], "policy")
    _require_keys(policy, {"mode", "cooldown_seconds", "max_actions_per_hour"}, "policy")
    if policy.get("mode") != "dry-run":
        raise ValueError("This release only accepts policy.mode dry-run")
    cooldown = policy.get("cooldown_seconds")
    hourly = policy.get("max_actions_per_hour")
    if isinstance(cooldown, bool) or not isinstance(cooldown, int) or not 0 <= cooldown <= 86400:
        raise ValueError("policy.cooldown_seconds must be between 0 and 86400")
    if isinstance(hourly, bool) or not isinstance(hourly, int) or not 1 <= hourly <= 1000:
        raise ValueError("policy.max_actions_per_hour must be between 1 and 1000")

    action = _mapping(rule["action"], "action")
    _require_keys(
        action,
        {"type", "protocol", "source_from", "interface_from", "enabled", "ttl_seconds"},
        "action",
    )
    action_type = str(action.get("type") or "")
    ttl = action.get("ttl_seconds", 0)
    if isinstance(ttl, bool) or not isinstance(ttl, int) or not 0 <= ttl <= 86400:
        raise ValueError("action.ttl_seconds must be between 0 and 86400")
    if action_type == "acl.deny-protocol-source":
        if action.get("protocol") not in {"icmp", "tcp", "udp", "ip"}:
            raise ValueError("ACL action protocol must be icmp, tcp, udp or ip")
        if action.get("source_from") != "attributes.offender_ip":
            raise ValueError("ACL source_from must be attributes.offender_ip")
        if action.get("interface_from") != "attributes.interface":
            raise ValueError("ACL interface_from must be attributes.interface")
        if "enabled" in action:
            raise ValueError("ACL action does not accept enabled")
    elif action_type == "interface.admin-state":
        if action.get("interface_from") != "attributes.interface":
            raise ValueError("Interface action interface_from must be attributes.interface")
        if not isinstance(action.get("enabled"), bool):
            raise ValueError("Interface action enabled must be true or false")
        if "protocol" in action or "source_from" in action:
            raise ValueError("Interface action does not accept protocol or source_from")
    else:
        raise ValueError(f"Unsupported action.type: {action_type}")
    return rule


def decode_rule_text(text: str) -> dict[str, Any]:
    encoded = text.encode("utf-8")
    if len(encoded) > MAX_RULE_BYTES:
        raise ValueError(f"Rule exceeds {MAX_RULE_BYTES} bytes")
    try:
        value = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid rule JSON at line {exc.lineno}, column {exc.colno}") from exc
    return validate_rule_payload(value)


def sample_icmp_rule_text() -> str:
    value = {
        "version": 1,
        "metadata": {
            "id": "mitigate-icmp-dos",
            "name": "Mitigate ICMP DoS",
            "description": (
                "When repeated ACL deny logs identify an ICMP source and a trusted "
                "ingress interface, prepare a temporary inbound deny action."
            ),
            "enabled": False,
        },
        "schedule": {"interval_seconds": 1},
        "match": {
            "event_type": "ACL_DROP_FLOOD",
            "require_attributes": ["offender_ip", "interface", "protocol"],
            "attributes": {"protocol": "icmp"},
        },
        "policy": {
            "mode": "dry-run",
            "cooldown_seconds": 300,
            "max_actions_per_hour": 6,
        },
        "action": {
            "type": "acl.deny-protocol-source",
            "protocol": "icmp",
            "source_from": "attributes.offender_ip",
            "interface_from": "attributes.interface",
            "ttl_seconds": 300,
        },
    }
    return json.dumps(value, ensure_ascii=False, indent=2) + "\n"


class RuleFileRepository:
    def __init__(self, directory: str | Path) -> None:
        self.set_directory(directory)

    def set_directory(self, directory: str | Path) -> None:
        path = Path(directory).resolve()
        path.mkdir(parents=True, exist_ok=True)
        if path.is_symlink() or not path.is_dir():
            raise ValueError("Automation rules path must be a real directory")
        self.directory = path

    def list_rules(self) -> list[dict[str, Any]]:
        files = sorted(self.directory.glob("*.json"), key=lambda item: item.name.casefold())
        if len(files) > MAX_RULE_FILES:
            raise ValueError(f"Rules directory exceeds {MAX_RULE_FILES} JSON files")
        result: list[dict[str, Any]] = []
        for path in files:
            if path.is_symlink() or not path.is_file():
                continue
            try:
                value = decode_rule_text(path.read_text(encoding="utf-8"))
                metadata = value["metadata"]
                result.append({
                    "id": metadata["id"],
                    "name": metadata["name"],
                    "description": metadata.get("description", ""),
                    "enabled": metadata["enabled"],
                    "event_type": value["match"]["event_type"],
                    "action_type": value["action"]["type"],
                    "interval_seconds": value["schedule"]["interval_seconds"],
                    "valid": True,
                    "file_name": path.name,
                    "error": "",
                })
            except (OSError, UnicodeError, ValueError) as exc:
                result.append({
                    "id": path.stem, "name": path.name, "description": "",
                    "enabled": False, "event_type": "", "action_type": "",
                    "interval_seconds": 0, "valid": False,
                    "file_name": path.name, "error": str(exc),
                })
        return result

    def get_rule_text(self, rule_reference: str) -> str:
        path = self._path_for_reference(rule_reference)
        if not path.is_file() or path.is_symlink():
            raise FileNotFoundError(f"Rule not found: {rule_reference}")
        text = path.read_text(encoding="utf-8")
        decode_rule_text(text)
        return text

    def save_rule_text(self, text: str) -> dict[str, Any]:
        value = decode_rule_text(text)
        rule_id = str(value["metadata"]["id"])
        normalized = json.dumps(value, ensure_ascii=False, indent=2) + "\n"
        target = self._path_for_id(rule_id)
        descriptor, temporary_name = tempfile.mkstemp(
            prefix=f".{rule_id}.", suffix=".tmp", dir=self.directory
        )
        try:
            with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
                stream.write(normalized)
                stream.flush()
                os.fsync(stream.fileno())
            os.chmod(temporary_name, 0o600)
            os.replace(temporary_name, target)
        except Exception:
            Path(temporary_name).unlink(missing_ok=True)
            raise
        return {"ok": True, "id": rule_id, "message": f"Saved rule {rule_id}."}

    def import_rule(self, source: str | Path) -> dict[str, Any]:
        path = Path(source)
        if path.is_symlink() or not path.is_file():
            raise ValueError("Choose a regular JSON rule file")
        if path.stat().st_size > MAX_RULE_BYTES:
            raise ValueError(f"Rule exceeds {MAX_RULE_BYTES} bytes")
        return self.save_rule_text(path.read_text(encoding="utf-8"))

    def set_enabled(self, rule_reference: str, enabled: bool) -> dict[str, Any]:
        source = self._path_for_reference(rule_reference)
        value = decode_rule_text(self.get_rule_text(rule_reference))
        value["metadata"]["enabled"] = bool(enabled)
        result = self.save_rule_text(json.dumps(value, ensure_ascii=False))
        target = self._path_for_id(str(value["metadata"]["id"]))
        if source != target:
            source.unlink(missing_ok=True)
        return result

    def delete_rule(self, rule_reference: str) -> dict[str, Any]:
        reference = str(rule_reference or "").strip()
        path = self._path_for_reference(reference)
        if not path.exists():
            return {"ok": False, "message": f"Rule not found: {reference}"}
        if path.is_symlink() or not path.is_file():
            raise ValueError("Refusing to delete a non-regular rule path")
        path.unlink()
        return {"ok": True, "message": f"Deleted rule {path.stem}."}

    def _path_for_id(self, rule_id: str) -> Path:
        normalized = str(rule_id or "").strip()
        if not _IDENTIFIER.fullmatch(normalized) or len(normalized) > 96:
            raise ValueError("Invalid automation rule id")
        return self.directory / f"{normalized}.json"

    def _path_for_reference(self, rule_reference: str) -> Path:
        reference = str(rule_reference or "").strip()
        if reference.casefold().endswith(".json"):
            if (
                Path(reference).name != reference
                or reference in {".json", "..json"}
                or len(reference) > 128
            ):
                raise ValueError("Invalid automation rule file name")
            return self.directory / reference
        return self._path_for_id(reference)


__all__ = [
    "MAX_RULE_BYTES",
    "MAX_RULE_FILES",
    "RULE_VERSION",
    "RuleFileRepository",
    "decode_rule_text",
    "sample_icmp_rule_text",
    "validate_rule_payload",
]
