"""Email alert support for stored Syslog messages."""

from .renderer import render_email
from .service import EmailAlertService, send_smtp_message
from .settings import (
    AlertConfiguration,
    AlertSettingsStore,
    AlertValidationError,
    validate_configuration,
)

__all__ = [
    "AlertConfiguration",
    "AlertSettingsStore",
    "AlertValidationError",
    "EmailAlertService",
    "render_email",
    "send_smtp_message",
    "validate_configuration",
]
