"""Validation and secure persistence for Telegram Syslog alerts."""

from __future__ import annotations

from dataclasses import asdict, dataclass
import json
import os
from pathlib import Path
import re
import threading
from typing import Any

from infrastructure.security import decrypt_credential, encrypt_credential


DEFAULT_VALUES: dict[str, Any] = {
    "enabled": False,
    "bot_token": "",
    "chat_id": "",
    "levels": [0, 1, 2],
    "cooldown_seconds": 300,
    "batch_seconds": 10,
}

_TOKEN_PATTERN = re.compile(r"^\d{5,20}:[A-Za-z0-9_-]{20,}$")
_CHAT_ID_PATTERN = re.compile(r"^-?\d+$")
_CHAT_USERNAME_PATTERN = re.compile(r"^@[A-Za-z][A-Za-z0-9_]{4,31}$")


@dataclass(frozen=True, slots=True)
class TelegramAlertConfiguration:
    enabled: bool
    bot_token: str
    chat_id: str
    levels: tuple[int, ...]
    cooldown_seconds: int
    batch_seconds: int

    def public_dict(self) -> dict[str, Any]:
        """Return settings safe to expose to QML without leaking the token."""
        return {
            "enabled": self.enabled,
            "bot_token": "",
            "has_token": bool(self.bot_token),
            "chat_id": self.chat_id,
            "levels": list(self.levels),
            "cooldown_seconds": self.cooldown_seconds,
            "batch_seconds": self.batch_seconds,
        }


class TelegramAlertValidationError(ValueError):
    def __init__(self, errors: dict[str, str]) -> None:
        self.errors = dict(errors)
        super().__init__(
            next(iter(self.errors.values()), "Invalid Telegram alert settings.")
        )


def _as_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    return str(value or "").strip().casefold() in {"1", "true", "yes", "on"}


def _as_int(value: Any, fallback: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return fallback


def validate_telegram_configuration(
    payload: dict[str, Any],
    *,
    saved_token: str = "",
    require_enabled_fields: bool = False,
) -> TelegramAlertConfiguration:
    values = dict(DEFAULT_VALUES)
    values.update(payload or {})

    validate_delivery = _as_bool(values.get("enabled")) or require_enabled_fields
    supplied_token = re.sub(r"\s+", "", str(values.get("bot_token") or ""))
    token = supplied_token or str(saved_token or "")
    chat_id = str(values.get("chat_id") or "").strip()

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

    if validate_delivery:
        if not levels:
            errors["levels"] = "Select at least one Syslog level to alert on."
        if not token:
            errors["bot_token"] = "Telegram Bot Token is required."
        elif not _TOKEN_PATTERN.fullmatch(token):
            errors["bot_token"] = "Telegram Bot Token format is invalid."
        if not chat_id:
            errors["chat_id"] = "Telegram Chat ID is required."
        elif not (
            _CHAT_ID_PATTERN.fullmatch(chat_id)
            or _CHAT_USERNAME_PATTERN.fullmatch(chat_id)
        ):
            errors["chat_id"] = "Telegram Chat ID must be numeric or a valid @channel username."

    if not 0 <= cooldown <= 86400:
        errors["cooldown_seconds"] = "Cooldown must be between 0 and 86400 seconds."
    if not 0 <= batch <= 86400:
        errors["batch_seconds"] = "Batch window must be between 0 and 86400 seconds."

    if errors:
        raise TelegramAlertValidationError(errors)

    return TelegramAlertConfiguration(
        enabled=_as_bool(values.get("enabled")),
        bot_token=token,
        chat_id=chat_id,
        levels=tuple(levels),
        cooldown_seconds=cooldown,
        batch_seconds=batch,
    )


class TelegramAlertSettingsStore:
    """Thread-safe JSON store that encrypts the Bot Token at rest."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path).expanduser()
        self._lock = threading.RLock()
        self._values = self._load()

    def _load(self) -> dict[str, Any]:
        values = dict(DEFAULT_VALUES)
        values["levels"] = list(DEFAULT_VALUES["levels"])
        if self.path.is_file():
            try:
                stored = json.loads(self.path.read_text(encoding="utf-8"))
                if isinstance(stored, dict):
                    values.update({key: stored[key] for key in values if key in stored})
                    raw_token = str(stored.get("bot_token") or "")
                    if raw_token:
                        try:
                            values["bot_token"] = decrypt_credential(
                                raw_token, context="telegram:bot_token"
                            )
                        except Exception:
                            values["bot_token"] = raw_token
            except (OSError, json.JSONDecodeError):
                pass
        try:
            config = validate_telegram_configuration(values)
        except TelegramAlertValidationError:
            config = validate_telegram_configuration(DEFAULT_VALUES)
        normalized = asdict(config)
        normalized["levels"] = list(config.levels)
        self._write(normalized)
        return normalized

    def _write(self, values: dict[str, Any]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        persisted = dict(values)
        raw_token = str(persisted.get("bot_token") or "")
        if raw_token:
            persisted["bot_token"] = encrypt_credential(
                raw_token, context="telegram:bot_token"
            )
        temporary = self.path.with_suffix(self.path.suffix + ".tmp")
        temporary.write_text(
            json.dumps(persisted, indent=2, ensure_ascii=False) + "\n",
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

    def configuration(self) -> TelegramAlertConfiguration:
        with self._lock:
            return validate_telegram_configuration(dict(self._values))

    def public_values(self) -> dict[str, Any]:
        return self.configuration().public_dict()

    def validate_draft(
        self, payload: dict[str, Any], *, require_enabled_fields: bool = False
    ) -> TelegramAlertConfiguration:
        with self._lock:
            return validate_telegram_configuration(
                payload,
                saved_token=str(self._values.get("bot_token") or ""),
                require_enabled_fields=require_enabled_fields,
            )

    def save(self, payload: dict[str, Any]) -> TelegramAlertConfiguration:
        with self._lock:
            config = validate_telegram_configuration(
                payload,
                saved_token=str(self._values.get("bot_token") or ""),
            )
            values = asdict(config)
            values["levels"] = list(config.levels)
            self._write(values)
            self._values = values
            return config


__all__ = [
    "TelegramAlertConfiguration",
    "TelegramAlertSettingsStore",
    "TelegramAlertValidationError",
    "validate_telegram_configuration",
]
