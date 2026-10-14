"""Composition helper for the database facade's View & Push runtime."""

from __future__ import annotations

from typing import Any

from PyQt6.QtCore import QSettings

from core.app_paths import DATA_DIR
from core.tasks import AsyncTaskCoordinator
from core.view_push import ViewPushControllerFactory
from core.view_push_batch import ViewPushBatchService
from features.config_backup import ConfigBackupService
from features.devices import DeviceRepository, PostPushService


def initialize_view_push_runtime(
    owner: Any,
    config_backup_service: Any,
    config_sync_service: Any,
    task_coordinator: Any,
    session_registry: Any,
) -> None:
    """Attach Push, post-Push, backup, and background-task services."""
    owner._background_tasks = {}
    owner._task_coordinator = task_coordinator or AsyncTaskCoordinator(owner)
    owner._config_backup_service = config_backup_service or ConfigBackupService(
        DATA_DIR / "backup"
    )
    owner._config_sync_service = config_sync_service
    owner._post_push_service = PostPushService(
        owner._config_backup_service,
        owner._config_sync_service,
        lambda host: DeviceRepository(owner.db_path).get_role(host),
    )
    owner._view_push = ViewPushControllerFactory(owner, session_registry)
    owner._view_push_batch = ViewPushBatchService(owner._view_push)
    load_batch_policy(owner._view_push_batch)


BATCH_POLICY_KEYS = ("maxConcurrentHosts", "canaryHosts", "maxFailPercent")


def load_batch_policy(service: ViewPushBatchService) -> None:
    """Apply the Settings-page batch policy; env/defaults apply until saved."""
    settings = QSettings()
    current = service.policy()
    values = []
    for key in BATCH_POLICY_KEYS:
        try:
            values.append(int(settings.value(f"Batch/{key}", current[key])))
        except (TypeError, ValueError):
            values.append(current[key])
    service.set_policy(*values)


def save_batch_policy(service: ViewPushBatchService, *values: int) -> dict[str, int]:
    policy = service.set_policy(*values)
    settings = QSettings()
    for key in BATCH_POLICY_KEYS:
        settings.setValue(f"Batch/{key}", policy[key])
    settings.sync()
    return policy


__all__ = ["initialize_view_push_runtime", "load_batch_policy", "save_batch_policy"]
