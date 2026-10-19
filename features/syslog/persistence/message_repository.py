"""Hot-path SQLite repository for Syslog messages and retention."""

from __future__ import annotations

import json
import re
import uuid
from collections.abc import Iterable
from contextlib import closing
from pathlib import Path
from typing import Any

from ..automation import AutomationDetection
from ..domain.models import SyslogMessage
from ..security import annotate_security, security_filter_clause
from .connections import info_connection
from .schema import ensure_schema


_AUTOMATION_INTERFACE_PATTERN = re.compile(r"^[A-Za-z][A-Za-z0-9./_-]{0,127}$")
_AUTOMATION_MAX_CLI_COMMANDS = 100
_AUTOMATION_MAX_VERIFY_COMMANDS = 20
_AUTOMATION_MAX_CLI_COMMAND_LENGTH = 512
_AUTOMATION_MAX_CLI_TOTAL_LENGTH = 16 * 1024
_AUTOMATION_SOURCE_TEXT_LENGTH = 2048


def _validated_cli_commands(
    value: Any, label: str, *, maximum: int, required: bool,
) -> list[str]:
    if not isinstance(value, list):
        raise ValueError(f"{label} must be a list")
    if required and not value:
        raise ValueError(f"{label} must not be empty")
    if len(value) > maximum:
        raise ValueError(f"{label} contains too many commands")
    commands: list[str] = []
    for command in value:
        if not isinstance(command, str):
            raise ValueError(f"{label} must contain strings")
        normalized = command.strip()
        if (
            not normalized
            or len(normalized) > _AUTOMATION_MAX_CLI_COMMAND_LENGTH
            or "\n" in command
            or "\r" in command
            or "\x00" in command
        ):
            raise ValueError(f"{label} contains an invalid CLI command")
        commands.append(normalized)
    if sum(len(command) for command in commands) > _AUTOMATION_MAX_CLI_TOTAL_LENGTH:
        raise ValueError(f"{label} is too large")
    return commands


MESSAGE_INSERT_SQL = """INSERT INTO t12_syslog_messages
    (device_host, source_ip, device_time, sequence_number,
     clock_unsynchronized, received_at, syslog_pri, syslog_facility,
     cisco_facility, cisco_subfacility, facility, severity, mnemonic,
     message, raw_message, protocol, parse_status)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"""

AUTOMATION_EVENT_INSERT_SQL = """INSERT INTO t13_automation_events
    (event_id, schema_version, event_type, device_host, subject_key,
     attributes_json, evidence_json, detected_at, fingerprint)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(event_id) DO NOTHING"""

AUTOMATION_ACTION_INSERT_SQL = """INSERT INTO t13_automation_actions
    (event_id, rule_id, rule_revision, mode, action_type, status,
     dedup_key, request_redacted_json)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(dedup_key) DO NOTHING"""


class MessageRepository:
    def __init__(self, info_db: Path) -> None:
        self.info_db = Path(info_db)
        with closing(info_connection(self.info_db)) as conn:
            ensure_schema(conn)

    def insert_messages(self, messages: Iterable[SyslogMessage]) -> list[dict[str, Any]]:
        rows = list(messages)
        if not rows:
            return []
        values = [self._message_values(row) for row in rows]
        with closing(info_connection(self.info_db)) as conn:
            conn.executemany(MESSAGE_INSERT_SQL, values)
            last_id = int(conn.execute("SELECT last_insert_rowid()").fetchone()[0])
            conn.commit()
        first_id = max(1, last_id - len(rows) + 1) if last_id else 0
        result: list[dict[str, Any]] = []
        for offset, row in enumerate(rows):
            item = row.to_dict()
            item["id"] = first_id + offset if first_id else 0
            result.append(self._public_row(item))
        return result

    def insert_security_detections(
        self, detections: Iterable[AutomationDetection],
    ) -> list[dict[str, Any]]:
        """Atomically persist deduplicated machine events and synthetic alerts."""
        pending = list(detections)
        if not pending:
            return []
        inserted: list[tuple[SyslogMessage, int]] = []
        with closing(info_connection(self.info_db)) as conn:
            with conn:
                for detection in pending:
                    event_cursor = conn.execute(
                        AUTOMATION_EVENT_INSERT_SQL,
                        detection.event.database_values(),
                    )
                    if event_cursor.rowcount == 0:
                        continue
                    alert_cursor = conn.execute(
                        MESSAGE_INSERT_SQL,
                        self._message_values(detection.alert),
                    )
                    alert_id = int(alert_cursor.lastrowid)
                    conn.execute(
                        "UPDATE t13_automation_events SET source_alert_id = ? "
                        "WHERE event_id = ?",
                        (alert_id, detection.event.event_id),
                    )
                    inserted.append((detection.alert, alert_id))
        result: list[dict[str, Any]] = []
        for alert, alert_id in inserted:
            item = alert.to_dict()
            item["id"] = alert_id
            result.append(self._public_row(item))
        return result

    def query_automation_events(self, limit: int = 100) -> list[dict[str, Any]]:
        """Return recent structured detections without exposing action secrets."""
        row_limit = max(1, min(int(limit), 1_000))
        with closing(info_connection(self.info_db)) as conn:
            rows = conn.execute(
                "SELECT * FROM t13_automation_events ORDER BY id DESC LIMIT ?",
                (row_limit,),
            ).fetchall()
        result: list[dict[str, Any]] = []
        for row in rows:
            item = dict(row)
            item["attributes"] = json.loads(item.pop("attributes_json") or "{}")
            item["evidence"] = json.loads(item.pop("evidence_json") or "{}")
            result.append(item)
        return result

    def query_pending_automation_events(self, limit: int = 100) -> list[dict[str, Any]]:
        """Return events plus the newest trusted source Syslog row for v3 bindings."""
        row_limit = max(1, min(int(limit), 100))
        with closing(info_connection(self.info_db)) as conn:
            rows = conn.execute(
                """SELECT event_id, schema_version, event_type, device_host,
                          subject_key, attributes_json, evidence_json,
                          detected_at, fingerprint
                   FROM t13_automation_events
                   WHERE status = 'pending'
                   ORDER BY id LIMIT ?""",
                (row_limit,),
            ).fetchall()
            events = [self._automation_event_contract(row) for row in rows]
            for event in events:
                evidence = event.get("evidence")
                if not isinstance(evidence, dict):
                    continue
                source_ids = [
                    int(value)
                    for value in evidence.get("source_message_ids", [])
                    if isinstance(value, int)
                    and not isinstance(value, bool)
                    and value > 0
                ]
                if not source_ids:
                    continue
                # One newest row keeps the sidecar protocol bounded while covering
                # the single HA_EM record that raises an ICMP_FLOOD event.
                source = conn.execute(
                    """SELECT id, message, raw_message
                       FROM t12_syslog_messages
                       WHERE id = ? AND device_host = ?""",
                    (max(source_ids), str(event.get("device_host") or "")),
                ).fetchone()
                if source is None:
                    continue
                source_row = dict(source)
                evidence["source_messages"] = [{
                    "id": int(source_row["id"]),
                    "message": str(source_row.get("message") or "")[
                        -_AUTOMATION_SOURCE_TEXT_LENGTH:
                    ],
                    "raw_message": str(source_row.get("raw_message") or "")[
                        -_AUTOMATION_SOURCE_TEXT_LENGTH:
                    ],
                }]
        return events

    def materialize_automation_actions(
        self,
        actions: Iterable[dict[str, Any]],
        processed_event_ids: Iterable[str],
    ) -> dict[str, int]:
        """Persist simulated plans and complete evaluated events atomically.

        Cooldown and hourly limits are rechecked against durable state here;
        the sidecar cannot bypass them by returning a crafted response.
        """
        pending_actions = [dict(action) for action in actions]
        processed = list(dict.fromkeys(
            str(event_id).strip() for event_id in processed_event_ids
            if str(event_id).strip()
        ))
        inserted = 0
        suppressed = 0
        with closing(info_connection(self.info_db)) as conn:
            conn.execute("BEGIN IMMEDIATE")
            try:
                pending_rows = conn.execute(
                    "SELECT event_id, device_host, subject_key, attributes_json, evidence_json "
                    "FROM t13_automation_events WHERE status = 'pending'"
                ).fetchall()
                events: dict[str, dict[str, Any]] = {}
                for row in pending_rows:
                    event_row = dict(row)
                    event_row["attributes"] = json.loads(
                        event_row.pop("attributes_json") or "{}"
                    )
                    event_row["evidence"] = json.loads(
                        event_row.pop("evidence_json") or "{}"
                    )
                    events[str(row["event_id"])] = event_row
                for action in pending_actions:
                    values = self._validated_action_values(action, events)
                    event_row = events[values[0]]
                    cooldown = max(0, min(int(action.get("cooldown_seconds", 0)), 86400))
                    hourly_limit = max(
                        1, min(int(action.get("max_actions_per_hour", 1)), 1000)
                    )
                    if cooldown and conn.execute(
                        """SELECT 1
                           FROM t13_automation_actions AS action
                           JOIN t13_automation_events AS event
                             ON event.event_id = action.event_id
                           WHERE action.rule_id = ?
                             AND event.device_host = ?
                             AND event.subject_key = ?
                             AND julianday(action.created_at) >=
                                 julianday('now', ?)
                           LIMIT 1""",
                        (
                            values[1], event_row["device_host"],
                            event_row["subject_key"], f"-{cooldown} seconds",
                        ),
                    ).fetchone() is not None:
                        suppressed += 1
                        continue
                    recent_count = int(conn.execute(
                        """SELECT COUNT(*) FROM t13_automation_actions
                           WHERE rule_id = ?
                             AND julianday(created_at) >= julianday('now', '-1 hour')""",
                        (values[1],),
                    ).fetchone()[0])
                    if recent_count >= hourly_limit:
                        suppressed += 1
                        continue
                    cursor = conn.execute(AUTOMATION_ACTION_INSERT_SQL, values)
                    if cursor.rowcount:
                        inserted += 1
                if processed:
                    valid_processed = [event_id for event_id in processed if event_id in events]
                    if valid_processed:
                        placeholders = ",".join("?" for _ in valid_processed)
                        conn.execute(
                            "UPDATE t13_automation_events "
                            "SET status = 'processed', updated_at = CURRENT_TIMESTAMP "
                            f"WHERE status = 'pending' AND event_id IN ({placeholders})",
                            valid_processed,
                        )
                conn.commit()
            except Exception:
                conn.rollback()
                raise
        return {"inserted": inserted, "suppressed": suppressed}

    def query_automation_actions(self, limit: int = 100) -> list[dict[str, Any]]:
        row_limit = max(1, min(int(limit), 500))
        with closing(info_connection(self.info_db)) as conn:
            rows = conn.execute(
                """SELECT action.*, event.device_host, event.subject_key,
                          event.event_type, event.detected_at
                   FROM t13_automation_actions AS action
                   JOIN t13_automation_events AS event
                     ON event.event_id = action.event_id
                   ORDER BY action.id DESC LIMIT ?""",
                (row_limit,),
            ).fetchall()
        result: list[dict[str, Any]] = []
        for row in rows:
            item = dict(row)
            item["request_redacted"] = json.loads(
                item.pop("request_redacted_json") or "{}"
            )
            result.append(item)
        return result

    def claim_next_auto_action(
        self, lease_owner: str | None = None, lease_seconds: int = 90,
    ) -> dict[str, Any] | None:
        """Atomically lease the oldest executable auto action.

        Interface admin-state changes are idempotent, so an expired claim can
        safely return to ``ready`` after a process interruption. Version 2/3
        CLI sequences fail closed instead of being replayed after an expired lease.
        """
        owner = str(lease_owner or uuid.uuid4().hex).strip()
        if not owner or len(owner) > 128:
            raise ValueError("Automation lease owner is invalid")
        seconds = max(15, min(int(lease_seconds), 300))
        with closing(info_connection(self.info_db)) as conn:
            conn.execute("BEGIN IMMEDIATE")
            try:
                conn.execute(
                    """UPDATE t13_automation_actions
                       SET status = 'failed', lease_owner = NULL, lease_until = NULL,
                           last_error = 'SSH CLI action lease expired; automatic replay is disabled',
                           updated_at = CURRENT_TIMESTAMP
                       WHERE mode = 'auto' AND action_type = 'ssh.cli'
                         AND status IN ('claimed', 'applying')
                         AND lease_until IS NOT NULL
                         AND datetime(lease_until) <= datetime('now')"""
                )
                conn.execute(
                    """UPDATE t13_automation_actions
                       SET status = 'ready', lease_owner = NULL, lease_until = NULL,
                           updated_at = CURRENT_TIMESTAMP
                       WHERE mode = 'auto' AND action_type = 'interface.admin-state'
                         AND status IN ('claimed', 'applying')
                         AND lease_until IS NOT NULL
                         AND datetime(lease_until) <= datetime('now')"""
                )
                row = conn.execute(
                    """SELECT id FROM t13_automation_actions
                       WHERE mode = 'auto' AND status = 'ready'
                         AND (next_attempt_at IS NULL
                              OR datetime(next_attempt_at) <= datetime('now'))
                       ORDER BY id LIMIT 1"""
                ).fetchone()
                if row is None:
                    conn.commit()
                    return None
                action_id = int(row["id"])
                cursor = conn.execute(
                    """UPDATE t13_automation_actions
                       SET status = 'claimed', attempts = attempts + 1,
                           lease_owner = ?,
                           lease_until = datetime('now', ?),
                           updated_at = CURRENT_TIMESTAMP
                       WHERE id = ? AND mode = 'auto' AND status = 'ready'""",
                    (owner, f"+{seconds} seconds", action_id),
                )
                if cursor.rowcount != 1:
                    conn.rollback()
                    return None
                claimed = conn.execute(
                    """SELECT action.*, event.device_host, event.subject_key,
                              event.event_type, event.detected_at
                       FROM t13_automation_actions AS action
                       JOIN t13_automation_events AS event
                         ON event.event_id = action.event_id
                       WHERE action.id = ?""",
                    (action_id,),
                ).fetchone()
                conn.commit()
            except Exception:
                conn.rollback()
                raise
        if claimed is None:
            return None
        item = dict(claimed)
        item["request_redacted"] = json.loads(
            item.pop("request_redacted_json") or "{}"
        )
        return item

    def begin_auto_action(self, action_id: int, lease_owner: str) -> None:
        """Move one leased action into the applying state."""
        with closing(info_connection(self.info_db)) as conn:
            cursor = conn.execute(
                """UPDATE t13_automation_actions
                   SET status = 'applying', updated_at = CURRENT_TIMESTAMP
                   WHERE id = ? AND mode = 'auto' AND status = 'claimed'
                     AND lease_owner = ?
                     AND datetime(lease_until) > datetime('now')""",
                (int(action_id), str(lease_owner)),
            )
            if cursor.rowcount != 1:
                raise RuntimeError("Automation action lease is no longer valid")
            conn.commit()

    def finish_auto_action(
        self,
        action_id: int,
        lease_owner: str,
        status: str,
        *,
        before: dict[str, Any] | None = None,
        after: dict[str, Any] | None = None,
        error: str = "",
    ) -> None:
        """Persist the final verified result without storing credentials."""
        final_status = str(status or "").strip()
        if final_status not in {"verified", "noop_verified", "failed"}:
            raise ValueError("Unsupported automation completion status")
        before_json = json.dumps(
            before or {}, ensure_ascii=False, sort_keys=True, separators=(",", ":")
        )
        after_json = json.dumps(
            after or {}, ensure_ascii=False, sort_keys=True, separators=(",", ":")
        )
        last_error = str(error or "").strip()[:4000] or None
        successful = final_status in {"verified", "noop_verified"}
        with closing(info_connection(self.info_db)) as conn:
            cursor = conn.execute(
                """UPDATE t13_automation_actions
                   SET status = ?, before_json = ?, after_json = ?, last_error = ?,
                       applied_at = CASE WHEN ? THEN CURRENT_TIMESTAMP ELSE applied_at END,
                       verified_at = CASE WHEN ? THEN CURRENT_TIMESTAMP ELSE verified_at END,
                       lease_owner = NULL, lease_until = NULL,
                       updated_at = CURRENT_TIMESTAMP
                   WHERE id = ? AND mode = 'auto'
                     AND status IN ('claimed', 'applying') AND lease_owner = ?""",
                (
                    final_status, before_json, after_json, last_error,
                    int(successful), int(successful), int(action_id), str(lease_owner),
                ),
            )
            if cursor.rowcount != 1:
                raise RuntimeError("Automation action could not be completed")
            conn.commit()

    def query_messages(
        self, filters: dict[str, Any], before_id: int = 0, limit: int = 200
    ) -> list[dict[str, Any]]:
        clauses: list[str] = []
        params: list[Any] = []
        host = str(filters.get("host") or "").strip()
        hosts = self._valid_hosts(filters.get("hosts", []))
        search = str(filters.get("search") or "").strip()
        from_time = str(filters.get("from_time") or "").strip()
        to_time = str(filters.get("to_time") or "").strip()
        facility = str(filters.get("facility") or "").strip()
        mnemonic = str(filters.get("mnemonic") or "").strip()
        per_host = max(0, min(int(filters.get("per_host") or 0), 500))
        severities = self._valid_severities(filters.get("severities", []))
        protocols = self._valid_protocols(filters.get("protocols", []))
        security_clause, security_params = security_filter_clause(filters.get("security"))
        if security_clause:
            clauses.append(security_clause)
            params.extend(security_params)
        if hosts:
            clauses.append(f"device_host IN ({','.join('?' for _ in hosts)})")
            params.extend(hosts)
        elif host:
            clauses.append("device_host = ?")
            params.append(host)
        if search:
            clauses.append(
                "(message LIKE ? ESCAPE '\\' OR mnemonic LIKE ? ESCAPE '\\' "
                "OR COALESCE(NULLIF(cisco_facility, ''), facility, '') "
                "LIKE ? ESCAPE '\\')"
            )
            escaped = search.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            params.extend((f"%{escaped}%", f"%{escaped}%", f"%{escaped}%"))
        if from_time:
            clauses.append("julianday(received_at) >= julianday(?)")
            params.append(from_time)
        if to_time:
            clauses.append("julianday(received_at) <= julianday(?)")
            params.append(to_time)
        if facility:
            clauses.append(
                "COALESCE(NULLIF(cisco_facility, ''), facility, '') LIKE ? ESCAPE '\\'"
            )
            params.append(f"%{self._escape_like(facility)}%")
        if mnemonic:
            clauses.append("COALESCE(mnemonic, '') LIKE ? ESCAPE '\\'")
            params.append(f"%{self._escape_like(mnemonic)}%")
        if severities:
            clauses.append(f"severity IN ({','.join('?' for _ in severities)})")
            params.extend(severities)
        if protocols:
            clauses.append(f"protocol IN ({','.join('?' for _ in protocols)})")
            params.extend(protocols)
        if before_id > 0 and per_host <= 0:
            clauses.append("id < ?")
            params.append(before_id)
        where = " WHERE " + " AND ".join(clauses) if clauses else ""
        row_limit = max(1, min(int(limit), 5_000))
        with closing(info_connection(self.info_db)) as conn:
            if per_host > 0:
                outer_clauses = ["host_rank <= ?"]
                outer_params: list[Any] = [*params, per_host]
                if before_id > 0:
                    outer_clauses.append("id < ?")
                    outer_params.append(before_id)
                outer_params.append(row_limit)
                rows = conn.execute(
                    "WITH ranked AS ("
                    "SELECT *, ROW_NUMBER() OVER ("
                    "PARTITION BY device_host ORDER BY id DESC"
                    ") AS host_rank FROM t12_syslog_messages" + where + ") "
                    "SELECT * FROM ranked WHERE " + " AND ".join(outer_clauses)
                    + " ORDER BY id DESC LIMIT ?",
                    outer_params,
                ).fetchall()
            else:
                params.append(row_limit)
                rows = conn.execute(
                    "SELECT * FROM t12_syslog_messages" + where + " ORDER BY id DESC LIMIT ?",
                    params,
                ).fetchall()
        return [self._public_row(dict(row)) for row in rows]

    def distinct_hosts(self) -> list[str]:
        with closing(info_connection(self.info_db)) as conn:
            rows = conn.execute(
                "SELECT DISTINCT device_host FROM t12_syslog_messages "
                "WHERE TRIM(COALESCE(device_host, '')) != '' "
                "ORDER BY device_host COLLATE NOCASE"
            ).fetchall()
        return [str(row[0]) for row in rows]

    def reset_options(self) -> dict[str, Any]:
        """Return message counts used by the destructive reset workflow."""
        with closing(info_connection(self.info_db)) as conn:
            rows = conn.execute(
                "SELECT device_host, COUNT(*) AS message_count "
                "FROM t12_syslog_messages "
                "GROUP BY device_host ORDER BY device_host COLLATE NOCASE"
            ).fetchall()
        hosts = [
            {
                "host": str(row["device_host"] or ""),
                "count": int(row["message_count"]),
            }
            for row in rows
            if str(row["device_host"] or "").strip()
        ]
        return {
            "total": sum(int(row["message_count"]) for row in rows),
            "hosts": hosts,
        }

    def messages_for_export(self, host: str = "") -> list[dict[str, Any]]:
        """Load a complete reset scope for a pre-delete Excel backup."""
        selected_host = str(host or "").strip()
        sql = "SELECT * FROM t12_syslog_messages"
        params: tuple[Any, ...] = ()
        if selected_host:
            sql += " WHERE device_host = ?"
            params = (selected_host,)
        sql += " ORDER BY id DESC"
        with closing(info_connection(self.info_db)) as conn:
            rows = conn.execute(sql, params).fetchall()
        return [self._public_row(dict(row)) for row in rows]

    def reset_messages(self, host: str = "") -> int:
        """Delete one host's messages, or every message when host is empty."""
        selected_host = str(host or "").strip()
        with closing(info_connection(self.info_db)) as conn:
            conn.execute("BEGIN IMMEDIATE")
            if selected_host:
                cursor = conn.execute(
                    "DELETE FROM t12_syslog_messages WHERE device_host = ?",
                    (selected_host,),
                )
            else:
                cursor = conn.execute("DELETE FROM t12_syslog_messages")
                # A full reset should also restart the local message sequence.
                has_sequence = conn.execute(
                    "SELECT 1 FROM sqlite_master "
                    "WHERE type = 'table' AND name = 'sqlite_sequence'"
                ).fetchone()
                if has_sequence:
                    conn.execute(
                        "DELETE FROM sqlite_sequence "
                        "WHERE name = 't12_syslog_messages'"
                    )
            deleted = max(0, int(cursor.rowcount))
            conn.commit()
        return deleted

    @staticmethod
    def _message_values(row: SyslogMessage) -> tuple[Any, ...]:
        return (
            row.device_host, row.source_ip, row.device_time, row.sequence_number,
            int(row.clock_unsynchronized), row.received_at, row.syslog_pri,
            row.syslog_facility, row.cisco_facility, row.cisco_subfacility,
            row.facility, row.severity, row.mnemonic, row.message,
            row.raw_message, row.protocol, row.parse_status,
        )

    @staticmethod
    def _automation_event_contract(row: Any) -> dict[str, Any]:
        item = dict(row)
        item["attributes"] = json.loads(item.pop("attributes_json") or "{}")
        item["evidence"] = json.loads(item.pop("evidence_json") or "{}")
        return item

    @staticmethod
    def _validated_action_values(
        action: dict[str, Any], events: dict[str, dict[str, Any]],
    ) -> tuple[str, str, str, str, str, str, str, str]:
        event_id = str(action.get("event_id") or "").strip()
        rule_id = str(action.get("rule_id") or "").strip()
        revision = str(action.get("rule_revision") or "").strip()
        mode = str(action.get("mode") or "").strip()
        action_type = str(action.get("action_type") or "").strip()
        status = str(action.get("status") or "").strip()
        dedup_key = str(action.get("dedup_key") or "").strip()
        request = action.get("request_redacted")
        if event_id not in events:
            raise ValueError("Automation action references a non-pending event")
        if not rule_id or not revision or not dedup_key:
            raise ValueError("Automation action identity is incomplete")
        if mode == "dry-run":
            if status != "simulated":
                raise ValueError("Dry-run actions must be simulated")
        elif mode == "auto":
            if status != "ready":
                raise ValueError("Auto actions must enter the ready state")
        else:
            raise ValueError("Unsupported automation action mode")
        if action_type not in {
            "acl.deny-protocol-source", "interface.admin-state", "ssh.cli",
        }:
            raise ValueError("Unsupported automation action type")
        if (
            not isinstance(request, dict)
            or request.get("dry_run") is not (mode == "dry-run")
        ):
            raise ValueError("Automation action request mode is invalid")
        event = events[event_id]
        attributes = event.get("attributes")
        if not isinstance(attributes, dict):
            raise ValueError("Automation event attributes are invalid")
        if (
            str(action.get("device_host") or "") != str(event["device_host"])
            or str(action.get("subject_key") or "") != str(event["subject_key"])
            or request.get("driver") != action_type
            or request.get("device_host") != event["device_host"]
        ):
            raise ValueError("Automation action target does not match its source event")
        if action_type == "acl.deny-protocol-source":
            if mode == "auto":
                raise ValueError("Auto mode currently supports interface actions only")
            if (
                request.get("source_ip") != attributes.get("offender_ip")
                or request.get("interface") != attributes.get("interface")
                or request.get("protocol") != attributes.get("protocol")
            ):
                raise ValueError("ACL action values do not match source event attributes")
        elif action_type == "interface.admin-state":
            interface = str(request.get("interface") or "")
            binding = str(request.get("interface_binding") or "")
            if mode == "auto" and request.get("transport") != "ssh":
                raise ValueError("Auto interface actions require SSH transport")
            if not isinstance(request.get("enabled"), bool):
                raise ValueError("Interface action enabled value is invalid")
            if binding == "event":
                if interface != attributes.get("interface"):
                    raise ValueError(
                        "Interface action values do not match source event attributes"
                    )
            elif binding == "literal":
                if not _AUTOMATION_INTERFACE_PATTERN.fullmatch(interface):
                    raise ValueError("Interface action literal is invalid")
            else:
                raise ValueError("Interface action binding is invalid")
        else:
            rule_version = request.get("rule_version")
            if rule_version not in {2, 3}:
                raise ValueError("SSH CLI actions require rule version 2 or 3")
            if request.get("transport") != "ssh":
                raise ValueError("SSH CLI actions require SSH transport")
            if request.get("mode") not in {"config", "exec"}:
                raise ValueError("SSH CLI action mode is invalid")
            _validated_cli_commands(
                request.get("commands"),
                "SSH CLI commands",
                maximum=_AUTOMATION_MAX_CLI_COMMANDS,
                required=True,
            )
            _validated_cli_commands(
                request.get("verify_commands", []),
                "SSH CLI verification commands",
                maximum=_AUTOMATION_MAX_VERIFY_COMMANDS,
                required=False,
            )
            ttl_seconds = request.get("ttl_seconds", 0)
            if isinstance(ttl_seconds, bool) or ttl_seconds != 0:
                raise ValueError("SSH CLI actions require ttl_seconds 0")
            if rule_version == 3:
                variables = request.get("variables")
                source_ids = request.get("variable_source_message_ids")
                evidence = event.get("evidence")
                allowed_source_ids = {
                    int(value)
                    for value in (
                        evidence.get("source_message_ids", [])
                        if isinstance(evidence, dict) else []
                    )
                    if isinstance(value, int)
                    and not isinstance(value, bool)
                    and value > 0
                }
                if (
                    not isinstance(variables, dict)
                    or not variables
                    or not isinstance(source_ids, dict)
                    or set(variables) != set(source_ids)
                ):
                    raise ValueError("Version 3 variable audit data is invalid")
                for name, resolved in variables.items():
                    if (
                        not isinstance(name, str)
                        or not re.fullmatch(r"[a-z][a-z0-9_]*", name)
                        or not isinstance(resolved, str)
                        or not resolved
                        or len(resolved) > 128
                        or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9./:_-]*", resolved)
                        or isinstance(source_ids.get(name), bool)
                        or not isinstance(source_ids.get(name), int)
                        or source_ids[name] <= 0
                        or source_ids[name] not in allowed_source_ids
                    ):
                        raise ValueError("Version 3 variable audit data is invalid")
        return (
            event_id, rule_id, revision, mode, action_type, status, dedup_key,
            json.dumps(request, ensure_ascii=False, sort_keys=True, separators=(",", ":")),
        )

    @staticmethod
    def _public_row(row: dict[str, Any]) -> dict[str, Any]:
        row.pop("host_rank", None)
        row["clock_unsynchronized"] = bool(row.get("clock_unsynchronized"))
        row["facility"] = row.get("cisco_facility") or (
            str(row["syslog_facility"]) if row.get("syslog_facility") is not None else row.get("facility")
        )
        return annotate_security(row)

    @staticmethod
    def _escape_like(value: str) -> str:
        return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")

    @staticmethod
    def _valid_severities(values: Any) -> list[int]:
        result: list[int] = []
        for value in values or []:
            try:
                severity = int(value)
            except (TypeError, ValueError):
                continue
            if 0 <= severity <= 7 and severity not in result:
                result.append(severity)
        return result

    @staticmethod
    def _valid_protocols(values: Any) -> list[str]:
        result: list[str] = []
        for value in values or []:
            protocol = str(value or "").strip().lower()
            if protocol in {"udp", "tcp"} and protocol not in result:
                result.append(protocol)
        return result

    @staticmethod
    def _valid_hosts(values: Any) -> list[str]:
        if not isinstance(values, (list, tuple)):
            return []
        result: list[str] = []
        seen: set[str] = set()
        for value in values:
            host = str(value or "").strip()
            key = host.casefold()
            if host and key not in seen:
                result.append(host)
                seen.add(key)
        return result

    def delete_expired(self, retention_days: int, batch_size: int = 5_000) -> int:
        total = 0
        modifier = f"-{max(1, int(retention_days))} days"
        batch_size = max(100, min(int(batch_size), 10_000))
        with closing(info_connection(self.info_db)) as conn:
            while True:
                cursor = conn.execute(
                    """DELETE FROM t12_syslog_messages WHERE id IN (
                         SELECT id FROM t12_syslog_messages
                         WHERE received_at < datetime('now', ?) LIMIT ?
                       )""",
                    (modifier, batch_size),
                )
                conn.commit()
                deleted = max(0, int(cursor.rowcount))
                total += deleted
                if deleted < batch_size:
                    break
        return total


__all__ = ["MessageRepository"]
