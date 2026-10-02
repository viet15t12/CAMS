"""Validation and restricted-file persistence for email alert settings."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from email.utils import parseaddr
import json
import os
from pathlib import Path
import re
import threading
from typing import Any


DEFAULT_VALUES: dict[str, Any] = {
    "enabled": False,
    "smtp_host": "smtp.gmail.com",
    "smtp_port": 465,
    "sender_email": "",
    "sender_app_password": "",
    "recipients": [""],
    "levels": [0, 1, 2],
    "cooldown_seconds": 300,
    "batch_seconds": 10,
}

_EMAIL_PATTERN = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")


@dataclass(frozen=True, slots=True)
class AlertConfiguration:
    enabled: bool
    smtp_host: str
    smtp_port: int
    sender_email: str
    sender_app_password: str
    recipients: tuple[str, ...]
    levels: tuple[int, ...]
    cooldown_seconds: int
    batch_seconds: int

    def public_dict(self) -> dict[str, Any]:
        """Return settings safe to expose to QML (never include the password)."""
        return {
            "enabled": self.enabled,
            "smtp_host": self.smtp_host,
            "smtp_port": self.smtp_port,
            "sender_email": self.sender_email,
            "recipients": list(self.recipients) or [""],
            "levels": list(self.levels),
            "cooldown_seconds": self.cooldown_seconds,
            "batch_seconds": self.batch_seconds,
            "has_password": bool(self.sender_app_password),
            "sender_app_password": "",
        }


class AlertValidationError(ValueError):
    def __init__(self, errors: dict[str, str]) -> None:
        self.errors = dict(errors)
        super().__init__(next(iter(self.errors.values()), "Invalid email alert settings."))


def _as_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    return str(value or "").strip().casefold() in {"1", "true", "yes", "on"}


def _as_int(value: Any, fallback: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return fallback


def _valid_email(value: str) -> bool:
    address = parseaddr(value)[1]
    return address == value and bool(_EMAIL_PATTERN.fullmatch(value))


def split_recipients(value: Any) -> list[str]:
    values = value if isinstance(value, (list, tuple)) else [value]
    result: list[str] = []
    for item in values:
        result.extend(
            part.strip()
            for part in re.split(r"[,;\r\n]+", str(item or ""))
            if part.strip()
        )
    return result


def validate_configuration(
    payload: dict[str, Any],
    *,
    saved_password: str = "",
    require_enabled_fields: bool = False,
) -> AlertConfiguration:
    """Normalize a UI payload and raise field-addressable validation errors."""
    values = dict(DEFAULT_VALUES)
    values.update(payload or {})

    enabled = _as_bool(values.get("enabled")) or require_enabled_fields
    smtp_host = str(values.get("smtp_host") or "").strip()
    smtp_port = _as_int(values.get("smtp_port"), 0)
    sender_email = str(values.get("sender_email") or "").strip()
    supplied_password = re.sub(r"\s+", "", str(values.get("sender_app_password") or ""))
    password = supplied_password or str(saved_password or "")
    recipients = split_recipients(values.get("recipients"))

    levels: list[int] = []
    for value in values.get("levels") or []:
        try:
            severity = int(value)
        except (TypeError, ValueError):
            continue
        if 0 <= severity <= 7 and severity not in levels:
            levels.append(severity)
    levels.sort()

    cooldown = _as_int(values.get("cooldown_seconds"), -1)
    batch = _as_int(values.get("batch_seconds"), -1)
    errors: dict[str, str] = {}

    if enabled:
        if not levels:
            errors["levels"] = "Select at least one Syslog level to alert on."
        if not smtp_host:
            errors["smtp_host"] = "SMTP server is required."
        if not 1 <= smtp_port <= 65535:
            errors["smtp_port"] = "SMTP port must be between 1 and 65535."
        if not sender_email or not _valid_email(sender_email):
            errors["sender_email"] = "Sender email is invalid."
        if not password:
            errors["sender_app_password"] = "Sender App Password is required."
        if not recipients:
            errors["recipients"] = "Add at least one recipient email."

        seen: set[str] = set()
        for index, recipient in enumerate(recipients):
            key = recipient.casefold()
            if not _valid_email(recipient):
                errors[f"recipients.{index}"] = "Email address is invalid."
            elif key in seen:
                errors[f"recipients.{index}"] = "This email is already in the list."
            seen.add(key)
        if len(recipients) > 20:
            errors["recipients"] = "A maximum of 20 recipients is supported."

    if not 0 <= cooldown <= 86400:
        errors["cooldown_seconds"] = "Cooldown must be between 0 and 86400 seconds."
    if not 0 <= batch <= 86400:
        errors["batch_seconds"] = "Batch window must be between 0 and 86400 seconds."

    if errors:
        raise AlertValidationError(errors)

    return AlertConfiguration(
        enabled=_as_bool(values.get("enabled")),
        smtp_host=smtp_host,
        smtp_port=smtp_port,
        sender_email=sender_email,
        sender_app_password=password,
        recipients=tuple(recipients),
        levels=tuple(levels),
        cooldown_seconds=cooldown,
        batch_seconds=batch,
    )


class AlertSettingsStore:
    """Thread-safe JSON settings store shared by the UI and alert worker."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path).expanduser()
        self._lock = threading.RLock()
        self._values = self._load()

    def _load(self) -> dict[str, Any]:
        values = dict(DEFAULT_VALUES)
        values["recipients"] = list(DEFAULT_VALUES["recipients"])
        values["levels"] = list(DEFAULT_VALUES["levels"])
        if self.path.is_file():
            try:
                stored = json.loads(self.path.read_text(encoding="utf-8"))
                if isinstance(stored, dict):
                    values.update({key: stored[key] for key in values if key in stored})
            except (OSError, json.JSONDecodeError):
                pass
        try:
            config = validate_configuration(values)
        except AlertValidationError:
            config = validate_configuration(DEFAULT_VALUES)
        normalized = asdict(config)
        normalized["recipients"] = list(config.recipients)
        normalized["levels"] = list(config.levels)
        self._write(normalized)
        return normalized

    def _write(self, values: dict[str, Any]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.path.with_suffix(self.path.suffix + ".tmp")
        temporary.write_text(
            json.dumps(values, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        try:
            os.chmod(temporary, 0o600)
        except OSError:
            pass
        temporary.replace(self.path)
        try:
            os.chmod(self.path, 0o600)
        except OSError:
            pass

    def configuration(self) -> AlertConfiguration:
        with self._lock:
            return validate_configuration(dict(self._values))

    def public_values(self) -> dict[str, Any]:
        return self.configuration().public_dict()

    def validate_draft(
        self, payload: dict[str, Any], *, require_enabled_fields: bool = False
    ) -> AlertConfiguration:
        with self._lock:
            return validate_configuration(
                payload,
                saved_password=str(self._values.get("sender_app_password") or ""),
                require_enabled_fields=require_enabled_fields,
            )

    def save(self, payload: dict[str, Any]) -> AlertConfiguration:
        with self._lock:
            config = validate_configuration(
                payload,
                saved_password=str(self._values.get("sender_app_password") or ""),
            )
            values = asdict(config)
            values["recipients"] = list(config.recipients)
            values["levels"] = list(config.levels)
            self._write(values)
            self._values = values
            return config


__all__ = [
    "AlertConfiguration",
    "AlertSettingsStore",
    "AlertValidationError",
    "DEFAULT_VALUES",
    "split_recipients",
    "validate_configuration",
]
