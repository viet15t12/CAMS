"""Workspace-scoped declarative automation rule files."""

from __future__ import annotations

import ipaddress
import json
import os
import re
import tempfile
from pathlib import Path
from typing import Any


RULE_VERSION = 2
SUPPORTED_RULE_VERSIONS = frozenset({1, 2})
MAX_RULE_BYTES = 256 * 1024
MAX_RULE_FILES = 256
MAX_CLI_COMMANDS = 100
MAX_VERIFY_COMMANDS = 20
MAX_CLI_COMMAND_LENGTH = 512
MAX_CLI_TOTAL_LENGTH = 16 * 1024
RULE_SUFFIX = ".rule.cams"
LEGACY_RULE_SUFFIX = ".json"
_IDENTIFIER = re.compile(r"^[a-z0-9]+(?:[._-][a-z0-9]+)*$")
_TOP_LEVEL = {"version", "metadata", "schedule", "match", "policy", "action"}
_V1_ACTION_FIELDS = {
    "type", "transport", "protocol", "source_from", "interface_from",
    "interface", "enabled", "ttl_seconds",
}
_V2_ACTION_FIELDS = {
    "type", "transport", "mode", "commands", "verify_commands", "ttl_seconds",
}


def _require_keys(value: dict[str, Any], allowed: set[str], label: str) -> None:
    unknown = set(value) - allowed
    if unknown:
        raise ValueError(f"{label} contains unsupported field(s): {', '.join(sorted(unknown))}")


def _mapping(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a JSON object")
    return dict(value)


def _cli_commands(
    value: Any,
    label: str,
    *,
    maximum: int,
    required: bool,
) -> list[str]:
    if not isinstance(value, list):
        raise ValueError(f"{label} must be a JSON array")
    if required and not value:
        raise ValueError(f"{label} must contain at least one command")
    if len(value) > maximum:
        raise ValueError(f"{label} must not contain more than {maximum} commands")
    commands: list[str] = []
    for index, command in enumerate(value):
        if not isinstance(command, str):
            raise ValueError(f"{label}[{index}] must be a string")
        normalized = command.strip()
        if (
            not normalized
            or len(normalized) > MAX_CLI_COMMAND_LENGTH
            or "\n" in command
            or "\r" in command
            or "\x00" in command
        ):
            raise ValueError(
                f"{label}[{index}] must be one non-empty CLI line of at most "
                f"{MAX_CLI_COMMAND_LENGTH} characters"
            )
        commands.append(normalized)
    if sum(len(command) for command in commands) > MAX_CLI_TOTAL_LENGTH:
        raise ValueError(f"{label} exceeds {MAX_CLI_TOTAL_LENGTH} total characters")
    return commands


def _validate_network_scope(match: dict[str, Any]) -> None:
    has_network = "network" in match
    has_subnet_mask = "subnet_mask" in match
    if has_network != has_subnet_mask:
        raise ValueError("match.network and match.subnet_mask must be provided together")
    if not has_network:
        return
    network = match.get("network")
    subnet_mask = match.get("subnet_mask")
    if not isinstance(network, str) or not network.strip():
        raise ValueError("match.network must be a non-empty IPv4 network address")
    if not isinstance(subnet_mask, str) or not subnet_mask.strip():
        raise ValueError("match.subnet_mask must be a non-empty IPv4 subnet mask")
    try:
        scope = ipaddress.IPv4Network(
            f"{network.strip()}/{subnet_mask.strip()}",
            strict=True,
        )
    except ValueError as exc:
        raise ValueError(
            "match.network and match.subnet_mask must define a canonical IPv4 network"
        ) from exc
    match["network"] = str(scope.network_address)
    match["subnet_mask"] = str(scope.netmask)


def validate_rule_payload(value: Any) -> dict[str, Any]:
    rule = _mapping(value, "rule")
    _require_keys(rule, _TOP_LEVEL, "rule")
    if set(rule) != _TOP_LEVEL:
        missing = _TOP_LEVEL - set(rule)
        raise ValueError(f"rule is missing: {', '.join(sorted(missing))}")
    version = rule["version"]
    if isinstance(version, bool) or version not in SUPPORTED_RULE_VERSIONS:
        raise ValueError("Only rule versions 1 and 2 are supported")

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
    _require_keys(
        match,
        {"event_type", "require_attributes", "attributes", "network", "subnet_mask"},
        "match",
    )
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
    _validate_network_scope(match)

    policy = _mapping(rule["policy"], "policy")
    _require_keys(policy, {"mode", "cooldown_seconds", "max_actions_per_hour"}, "policy")
    if policy.get("mode") not in {"dry-run", "auto"}:
        raise ValueError("policy.mode must be dry-run or auto")
    cooldown = policy.get("cooldown_seconds")
    hourly = policy.get("max_actions_per_hour")
    if isinstance(cooldown, bool) or not isinstance(cooldown, int) or not 0 <= cooldown <= 86400:
        raise ValueError("policy.cooldown_seconds must be between 0 and 86400")
    if isinstance(hourly, bool) or not isinstance(hourly, int) or not 1 <= hourly <= 1000:
        raise ValueError("policy.max_actions_per_hour must be between 1 and 1000")

    action = _mapping(rule["action"], "action")
    _require_keys(
        action,
        _V1_ACTION_FIELDS if version == 1 else _V2_ACTION_FIELDS,
        "action",
    )
    action_type = str(action.get("type") or "")
    ttl = action.get("ttl_seconds", 0)
    if isinstance(ttl, bool) or not isinstance(ttl, int) or not 0 <= ttl <= 86400:
        raise ValueError("action.ttl_seconds must be between 0 and 86400")
    if version == 2:
        if action_type != "ssh.cli":
            raise ValueError("Rule version 2 requires action.type ssh.cli")
        if action.get("transport") != "ssh":
            raise ValueError("Version 2 CLI actions require transport ssh")
        if action.get("mode") not in {"config", "exec"}:
            raise ValueError("Version 2 action.mode must be config or exec")
        action["commands"] = _cli_commands(
            action.get("commands"),
            "action.commands",
            maximum=MAX_CLI_COMMANDS,
            required=True,
        )
        action["verify_commands"] = _cli_commands(
            action.get("verify_commands", []),
            "action.verify_commands",
            maximum=MAX_VERIFY_COMMANDS,
            required=False,
        )
        if ttl != 0:
            raise ValueError("Version 2 CLI actions require ttl_seconds 0")
        return rule

    if action_type == "acl.deny-protocol-source":
        if action.get("protocol") not in {"icmp", "tcp", "udp", "ip"}:
            raise ValueError("ACL action protocol must be icmp, tcp, udp or ip")
        if action.get("source_from") != "attributes.offender_ip":
            raise ValueError("ACL source_from must be attributes.offender_ip")
        if action.get("interface_from") != "attributes.interface":
            raise ValueError("ACL interface_from must be attributes.interface")
        if "enabled" in action:
            raise ValueError("ACL action does not accept enabled")
        if "transport" in action:
            raise ValueError("ACL action does not accept transport")
    elif action_type == "interface.admin-state":
        interface_from = str(action.get("interface_from") or "")
        interface = str(action.get("interface") or "").strip()
        if bool(interface_from) == bool(interface):
            raise ValueError(
                "Interface action requires exactly one of interface_from or interface"
            )
        if interface_from and interface_from != "attributes.interface":
            raise ValueError("Interface action interface_from must be attributes.interface")
        if interface and (
            len(interface) > 128
            or not re.fullmatch(r"[A-Za-z][A-Za-z0-9./_-]*", interface)
        ):
            raise ValueError("Interface action interface is invalid")
        if action.get("transport", "") not in {"", "ssh"}:
            raise ValueError("Interface action transport must be ssh")
        if not isinstance(action.get("enabled"), bool):
            raise ValueError("Interface action enabled must be true or false")
        if "protocol" in action or "source_from" in action:
            raise ValueError("Interface action does not accept protocol or source_from")
    else:
        raise ValueError(f"Unsupported action.type: {action_type}")
    if policy.get("mode") == "auto" and action_type != "interface.admin-state":
        raise ValueError("Auto mode currently supports interface.admin-state only")
    if policy.get("mode") == "auto" and action.get("transport") != "ssh":
        raise ValueError("Auto interface actions require transport ssh")
    if policy.get("mode") == "auto" and ttl != 0:
        raise ValueError("Auto interface actions require ttl_seconds 0 until revert is supported")
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


def sample_cli_rule_text() -> str:
    value = {
        "version": 2,
        "metadata": {
            "id": "multi-command-icmp-response-v2",
            "name": "Multi-command ICMP flood response",
            "description": (
                "Disabled version 2 example that pushes a bounded configuration "
                "sequence through the active CAMS SSH session."
            ),
            "enabled": False,
        },
        "schedule": {"interval_seconds": 5},
        "match": {
            "event_type": "ICMP_FLOOD",
            "network": "192.168.122.0",
            "subnet_mask": "255.255.255.0",
            "require_attributes": [],
            "attributes": {"protocol": "icmp"},
        },
        "policy": {
            "mode": "auto",
            "cooldown_seconds": 600,
            "max_actions_per_hour": 1,
        },
        "action": {
            "type": "ssh.cli",
            "transport": "ssh",
            "mode": "config",
            "commands": [
                "interface GigabitEthernet0/3",
                "description CAMS_AUTO_ICMP_FLOOD",
                "shutdown",
            ],
            "verify_commands": ["show interfaces GigabitEthernet0/3"],
            "ttl_seconds": 0,
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
        files = sorted(
            (
                path
                for path in self.directory.iterdir()
                if path.name.casefold().endswith((RULE_SUFFIX, LEGACY_RULE_SUFFIX))
            ),
            key=lambda item: item.name.casefold(),
        )
        if len(files) > MAX_RULE_FILES:
            raise ValueError(f"Rules directory exceeds {MAX_RULE_FILES} rule files")
        result: list[dict[str, Any]] = []
        for path in files:
            if path.is_symlink() or not path.is_file():
                continue
            try:
                value = decode_rule_text(path.read_text(encoding="utf-8"))
                metadata = value["metadata"]
                action = value["action"]
                policy = value["policy"]
                target = str(
                    action.get("interface")
                    or action.get("interface_from")
                    or action.get("source_from")
                    or action.get("mode")
                    or ""
                )
                result.append({
                    "id": metadata["id"],
                    "version": value["version"],
                    "name": metadata["name"],
                    "description": metadata.get("description", ""),
                    "enabled": metadata["enabled"],
                    "event_type": value["match"]["event_type"],
                    "network": value["match"].get("network", ""),
                    "subnet_mask": value["match"].get("subnet_mask", ""),
                    "action_type": action["type"],
                    "action_enabled": action.get("enabled"),
                    "transport": action.get("transport", "internal"),
                    "target": target,
                    "action_mode": action.get("mode", ""),
                    "command_count": len(action.get("commands", [])),
                    "mode": policy["mode"],
                    "cooldown_seconds": policy["cooldown_seconds"],
                    "max_actions_per_hour": policy["max_actions_per_hour"],
                    "interval_seconds": value["schedule"]["interval_seconds"],
                    "valid": True,
                    "file_name": path.name,
                    "error": "",
                })
            except (OSError, UnicodeError, ValueError) as exc:
                result.append({
                    "id": path.stem, "name": path.name, "description": "",
                    "version": 0,
                    "enabled": False, "event_type": "", "network": "",
                    "subnet_mask": "", "action_type": "",
                    "action_enabled": None, "transport": "", "target": "",
                    "action_mode": "", "command_count": 0,
                    "mode": "", "cooldown_seconds": 0,
                    "max_actions_per_hour": 0,
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

    def save_rule_text(
        self,
        text: str,
        original_reference: str | None = None,
    ) -> dict[str, Any]:
        value = decode_rule_text(text)
        rule_id = str(value["metadata"]["id"])
        normalized = json.dumps(value, ensure_ascii=False, indent=2) + "\n"
        target = self._path_for_id(rule_id)
        source: Path | None = None
        if str(original_reference or "").strip():
            source = self._path_for_reference(str(original_reference))
            if source.is_symlink() or not source.is_file():
                raise FileNotFoundError(f"Rule not found: {original_reference}")
            if source != target and target.exists():
                raise FileExistsError(
                    f"Cannot rename rule: {target.name} already exists"
                )
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
            if source is not None and source != target:
                try:
                    source.unlink()
                except Exception:
                    target.unlink(missing_ok=True)
                    raise
        except Exception:
            Path(temporary_name).unlink(missing_ok=True)
            raise
        renamed = source is not None and source != target
        return {
            "ok": True,
            "id": rule_id,
            "file_name": target.name,
            "renamed": renamed,
            "message": (
                f"Renamed and saved rule as {target.name}."
                if renamed else f"Saved rule {target.name}."
            ),
        }

    def import_rule(self, source: str | Path) -> dict[str, Any]:
        path = Path(source)
        if path.is_symlink() or not path.is_file():
            raise ValueError("Choose a regular .rule.cams or legacy JSON rule file")
        if not path.name.casefold().endswith((RULE_SUFFIX, LEGACY_RULE_SUFFIX)):
            raise ValueError("Automation rule files must use .rule.cams")
        if path.stat().st_size > MAX_RULE_BYTES:
            raise ValueError(f"Rule exceeds {MAX_RULE_BYTES} bytes")
        return self.save_rule_text(path.read_text(encoding="utf-8"))

    def set_enabled(self, rule_reference: str, enabled: bool) -> dict[str, Any]:
        source = self._path_for_reference(rule_reference)
        value = decode_rule_text(self.get_rule_text(rule_reference))
        value["metadata"]["enabled"] = bool(enabled)
        return self.save_rule_text(
            json.dumps(value, ensure_ascii=False),
            source.name,
        )

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
        return self.directory / f"{normalized}{RULE_SUFFIX}"

    def _path_for_reference(self, rule_reference: str) -> Path:
        reference = str(rule_reference or "").strip()
        if reference.casefold().endswith((RULE_SUFFIX, LEGACY_RULE_SUFFIX)):
            if (
                Path(reference).name != reference
                or reference.casefold() in {RULE_SUFFIX, LEGACY_RULE_SUFFIX}
                or len(reference) > 160
            ):
                raise ValueError("Invalid automation rule file name")
            return self.directory / reference
        canonical = self._path_for_id(reference)
        legacy = self.directory / f"{reference}{LEGACY_RULE_SUFFIX}"
        return canonical if canonical.exists() or not legacy.exists() else legacy


__all__ = [
    "MAX_RULE_BYTES",
    "MAX_RULE_FILES",
    "RULE_VERSION",
    "SUPPORTED_RULE_VERSIONS",
    "MAX_CLI_COMMANDS",
    "MAX_VERIFY_COMMANDS",
    "MAX_CLI_COMMAND_LENGTH",
    "MAX_CLI_TOTAL_LENGTH",
    "RULE_SUFFIX",
    "RuleFileRepository",
    "decode_rule_text",
    "sample_icmp_rule_text",
    "sample_cli_rule_text",
    "validate_rule_payload",
]
