"""Canonical, working-directory-independent database paths."""

from __future__ import annotations

import os
import sys
from pathlib import Path


APP_DIR = Path(__file__).resolve().parents[2]


def _default_data_dir(
    *,
    platform_name: str | None = None,
    frozen: bool | None = None,
    environ: dict[str, str] | os._Environ[str] | None = None,
    home: Path | None = None,
) -> Path:
    """Return a writable data directory for source and packaged executions.

    Source checkouts intentionally keep their existing repository-local data
    directory.  A frozen Windows build may live below Program Files, so its
    mutable state belongs below the current user's LocalAppData directory.
    ``CAMS_DATA_DIR`` remains the highest-priority override on every platform.
    """
    environment = os.environ if environ is None else environ
    platform_name = os.name if platform_name is None else platform_name
    frozen = bool(getattr(sys, "frozen", False)) if frozen is None else frozen
    override = environment.get("CAMS_DATA_DIR", "").strip()
    if override:
        return Path(override).expanduser().resolve()
    if platform_name == "nt" and frozen:
        local_app_data = environment.get("LOCALAPPDATA", "").strip()
        root = (
            Path(local_app_data)
            if local_app_data
            else (home or Path.home()) / "AppData" / "Local"
        )
        return (root / "NetCamsTeam" / "CAMS" / "data").resolve()
    return (APP_DIR / "data").resolve()


DATA_DIR = _default_data_dir()
TMP_DIR = DATA_DIR / "tmp"
BACKUP_DIR = DATA_DIR / "backup"
SCHEMA_DIR = Path(__file__).resolve().parent / "schemas"
DEVICE_NETWORK_SCHEMA_DIR = SCHEMA_DIR / "device_network"
INFO_COLLECTED_SCHEMA_DIR = SCHEMA_DIR / "info_collected"
# Compatibility aliases for older imports. They now identify the canonical
# schema directories; database creation no longer writes aggregate SQL files.
DEVICE_NETWORK_SQL = DEVICE_NETWORK_SCHEMA_DIR
INFO_COLLECTED_SQL = INFO_COLLECTED_SCHEMA_DIR
DEVICE_NETWORK_DB = DATA_DIR / "device_network.db"
INFO_COLLECTED_DB = DATA_DIR / "info_collected.db"
APP_STATE_DB = DATA_DIR / "app_state.db"


def ensure_data_dir() -> Path:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    return DATA_DIR


def require_database(path: str | Path) -> Path:
    resolved = Path(path)
    if not resolved.is_file():
        raise FileNotFoundError(
            f"Database not found: {resolved}. Start the app with `uv run main.py`."
        )
    return resolved
