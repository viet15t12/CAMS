"""Validated per-VLAN DAI logging policy shared by persistence and rendering."""

from __future__ import annotations

from typing import Any

from .common import choice


DAI_LOG_MODES = {"deny", "all", "permit", "none"}


def dai_log_mode(value: Any) -> str:
    """Return an IOS DAI log mode; old payloads keep deny-only logging."""
    return choice(value, "DAI logging mode", DAI_LOG_MODES, "deny")
