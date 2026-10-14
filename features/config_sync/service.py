"""Decide when a committed running-config should update application state."""

from __future__ import annotations

from pathlib import Path
import re
from typing import Any, Callable

from features.devices.sync import sync_device_state
from features.switching.sync import sync_switch_state
from features.syslog.config_sync import sync_syslog_state


RoleLookup = Callable[[str], str | None]
Synchronizer = Callable[[str, str, str, str | None], dict[str, Any]]
SwitchSynchronizer = Callable[[str, str, dict[str, str], str], dict[str, Any]]
SyslogSynchronizer = Callable[[str | Path, str, str, str], dict[str, Any]]


class ConfigSyncService:
    """Gate the router sync pipeline by inventory role and Dulwich change state."""

    ROUTER_ROLE = "rou"

    def __init__(
        self,
        db_path: str | Path,
        role_lookup: RoleLookup,
        synchronizer: Synchronizer = sync_device_state,
        switch_synchronizer: SwitchSynchronizer = sync_switch_state,
        syslog_synchronizer: SyslogSynchronizer = sync_syslog_state,
    ) -> None:
        self.db_path = str(db_path)
        self._role_lookup = role_lookup
        self._synchronizer = synchronizer
        self._switch_synchronizer = switch_synchronizer
        self._syslog_synchronizer = syslog_synchronizer

    def _sync_syslog(
        self, host: str, running_config: str, mode: str
    ) -> dict[str, Any] | None:
        """Sync the cross-role Syslog module when a real workspace DB exists."""
        if not Path(self.db_path).is_file():
            return None
        return self._syslog_synchronizer(
            self.db_path,
            host,
            str(running_config or ""),
            mode,
        )

    @staticmethod
    def _merge_syslog_summary(
        summary: dict[str, Any], syslog: dict[str, Any] | None
    ) -> dict[str, Any]:
        merged = dict(summary or {})
        if not syslog:
            return merged
        merged.update(syslog)
        if bool(syslog.get("syslog_conflict")):
            conflicts = list(merged.get("conflicts") or [])
            if "syslog" not in conflicts:
                conflicts.append("syslog")
            merged["conflicts"] = conflicts
        return merged

    def sync_committed_snapshot(
        self,
        host: str,
        running_config: str,
        interface_brief: str,
        commit_result: dict[str, Any],
        mode: str = "safe",
        switch_state: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        """Sync a changed router snapshot; return a structured decision/result."""
        normalized_host = (host or "").strip()
        base = {
            "host": normalized_host,
            "role": "",
            "attempted": False,
            "skipped": True,
            "changed": bool(commit_result.get("changed")),
            "commitId": str(commit_result.get("commitId") or ""),
        }
        has_interface_inventory = bool(str(interface_brief or "").strip())
        has_acl_config = bool(re.search(r"(?m)^(?:ip access-list |mac access-list |access-list )",
                                        str(running_config or "")))
        if (
            not bool(commit_result.get("changed"))
            and not has_interface_inventory
            and not switch_state
            and not has_acl_config
        ):
            return {
                **base,
                "ok": True,
                "reason": "unchanged",
                "message": "Running-config is unchanged; database sync was not needed.",
                "summary": {},
            }

        try:
            role = str(self._role_lookup(normalized_host) or "").strip().lower()
        except Exception as exc:
            return {
                **base,
                "ok": False,
                "reason": "role-lookup-failed",
                "message": f"Could not verify device role: {exc}",
                "summary": {},
            }

        base["role"] = role
        if role in {"sw2", "sw3"}:
            if not switch_state and not has_acl_config:
                try:
                    syslog = self._sync_syslog(normalized_host, running_config, mode)
                except Exception as exc:
                    return {
                        **base,
                        "ok": False,
                        "attempted": True,
                        "skipped": False,
                        "reason": "sync-failed",
                        "message": str(exc),
                        "summary": {},
                    }
                if syslog is None:
                    return {
                        **base,
                        "ok": True,
                        "reason": "not-router",
                        "message": "Config sync skipped because no switch operational state was collected.",
                        "summary": {},
                    }
                return {
                    **base,
                    "ok": True,
                    "attempted": True,
                    "skipped": False,
                    "reason": "synchronized",
                    "message": "Changed switch Syslog configuration was synchronized.",
                    "summary": self._merge_syslog_summary({}, syslog),
                }
            try:
                switch_snapshot = dict(switch_state or {})
                if running_config:
                    switch_snapshot["running_config"] = str(running_config)
                summary = self._switch_synchronizer(
                    self.db_path,
                    normalized_host,
                    switch_snapshot,
                    mode,
                )
                syslog = self._sync_syslog(normalized_host, running_config, mode)
                return {
                    **base,
                    "ok": True,
                    "attempted": True,
                    "skipped": False,
                    "reason": "synchronized",
                    "message": "Changed switch state was synchronized.",
                    "summary": self._merge_syslog_summary(dict(summary or {}), syslog),
                }
            except Exception as exc:
                return {
                    **base,
                    "ok": False,
                    "attempted": True,
                    "skipped": False,
                    "reason": "sync-failed",
                    "message": str(exc),
                    "summary": {},
                }
        if role != self.ROUTER_ROLE:
            return {
                **base,
                "ok": True,
                "reason": "not-router",
                "message": f"Config sync skipped because device role is {role or 'unknown'}, not rou.",
                "summary": {},
            }
        try:
            args = (
                self.db_path,
                normalized_host,
                str(running_config or ""),
                str(interface_brief or ""),
            )
            summary = (
                self._synchronizer(*args)
                if mode == "safe"
                else self._synchronizer(*args, mode=mode)
            )
            syslog = self._sync_syslog(normalized_host, running_config, mode)
            return {
                **base,
                "ok": True,
                "attempted": True,
                "skipped": False,
                "reason": "synchronized",
                "message": "Changed router configuration was synchronized.",
                "summary": self._merge_syslog_summary(dict(summary or {}), syslog),
            }
        except Exception as exc:
            return {
                **base,
                "ok": False,
                "attempted": True,
                "skipped": False,
                "reason": "sync-failed",
                "message": str(exc),
                "summary": {},
            }

    def sync_manual_snapshot(
        self,
        host: str,
        running_config: str,
        interface_brief: str,
        commit_result: dict[str, Any],
        mode: str = "safe",
        switch_state: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        """Run the same guarded pipeline even when the snapshot commit is unchanged."""
        forced_commit = dict(commit_result)
        forced_commit["changed"] = True
        result = self.sync_committed_snapshot(
            host, running_config, interface_brief, forced_commit, mode, switch_state
        )
        if result.get("ok") and result.get("reason") == "synchronized":
            result["reason"] = "manual-synchronized"
            result["message"] = "Manual Sync completed."
        return result

    def preview_manual_snapshot(
        self,
        host: str,
        running_config: str,
        interface_brief: str,
        commit_result: dict[str, Any],
        switch_state: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        """Parse and diff a manual snapshot without changing the database."""
        return self.sync_manual_snapshot(
            host,
            running_config,
            interface_brief,
            commit_result,
            mode="preview",
            switch_state=switch_state,
        )
