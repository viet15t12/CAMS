"""Structured, durable events consumed by the gocore automation sidecar."""

from .models import AutomationDetection, AutomationEvent, create_automation_event

__all__ = ["AutomationDetection", "AutomationEvent", "create_automation_event"]
