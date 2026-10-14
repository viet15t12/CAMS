"""Telegram alert support for stored Syslog messages."""

from .renderer import render_telegram
from .service import TelegramAlertService, send_telegram_message
from .settings import (
    TelegramAlertConfiguration,
    TelegramAlertSettingsStore,
    TelegramAlertValidationError,
    validate_telegram_configuration,
)

__all__ = [
    "TelegramAlertConfiguration",
    "TelegramAlertService",
    "TelegramAlertSettingsStore",
    "TelegramAlertValidationError",
    "render_telegram",
    "send_telegram_message",
    "validate_telegram_configuration",
]
