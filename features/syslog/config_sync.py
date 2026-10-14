"""Parse and reconcile Cisco Syslog state from a collected running-config."""

from __future__ import annotations

import sqlite3
from contextlib import closing
from ipaddress import ip_address
from pathlib import Path
from typing import Any

from .device_config.commands import SEVERITY_WORDS
from .persistence.schema import ensure_device_schema


_SEVERITY_BY_NAME = {name: index for index, name in enumerate(SEVERITY_WORDS)}
_SEVERITY_BY_NAME.update(
    {
        "emergency": 0,
        "alert": 1,
        "crit": 2,
        "critical": 2,
        "error": 3,
        "err": 3,
        "warning": 4,
        "warn": 4,
        "notification": 5,
        "notice": 5,
        "info": 6,
        "debug": 7,
    }
)


def _severity(value: str) -> int:
    token = str(value or "").strip().lower()
    if token.isdigit():
        number = int(token)
        return number if 0 <= number <= 7 else 6
    return _SEVERITY_BY_NAME.get(token, 6)


def _destination_from_line(line: str) -> dict[str, Any] | None:
    fields = line.split()
    if len(fields) < 2 or fields[0].lower() != "logging":
        return None

    if fields[1].lower() == "host":
        if len(fields) < 3:
            return None
        address_text = fields[2]
        options = fields[3:]
    else:
        # Older IOS releases also render a destination as ``logging 1.2.3.4``.
        address_text = fields[1]
        options = fields[2:]

    try:
        address = str(ip_address(address_text))
    except ValueError:
        return None

    protocol = "udp"
    port = 514
    for index, token in enumerate(options):
        lowered = token.lower()
        if lowered == "transport" and index + 1 < len(options):
            candidate = options[index + 1].lower()
            if candidate in {"udp", "tcp"}:
                protocol = candidate
        elif lowered == "port" and index + 1 < len(options):
            try:
                candidate_port = int(options[index + 1])
            except ValueError:
                continue
            if 1 <= candidate_port <= 65535:
                port = candidate_port

    return {"server_ip": address, "protocol": protocol, "port": port}


def parse_syslog_config(running_config: str) -> list[dict[str, Any]]:
    """Return normalized per-destination state from IOS/IOS-XE configuration."""
    destinations: list[dict[str, Any]] = []
    source_interface: str | None = None
    trap_severity = 6
    timestamps = False
    sequence_numbers = False

    for raw_line in str(running_config or "").replace("\r", "").splitlines():
        line = " ".join(raw_line.strip().split())
        lowered = line.lower()
        if not line or lowered.startswith("no "):
            continue
        if lowered.startswith("logging source-interface "):
            fields = line.split()
            if len(fields) >= 3:
                source_interface = fields[2]
            continue
        if lowered.startswith("logging trap "):
            fields = line.split()
            if len(fields) >= 3:
                trap_severity = _severity(fields[2])
            continue
        if lowered.startswith("service timestamps log datetime"):
            timestamps = True
            continue
        if lowered == "service sequence-numbers":
            sequence_numbers = True
            continue
        destination = _destination_from_line(line)
        if destination is not None:
            destinations.append(destination)

    result: list[dict[str, Any]] = []
    seen: set[tuple[str, str, int]] = set()
    for destination in destinations:
        key = (
            str(destination["server_ip"]),
            str(destination["protocol"]),
            int(destination["port"]),
        )
        if key in seen:
            continue
        seen.add(key)
        result.append(
            {
                **destination,
                "source_interface": source_interface,
                "trap_severity": trap_severity,
                "timestamps": timestamps,
                "sequence_numbers": sequence_numbers,
            }
        )
    return result


def sync_syslog_state(
    db_path: str | Path,
    host: str,
    running_config: str,
    mode: str = "safe",
) -> dict[str, Any]:
    """Merge collected Syslog state while preserving unpushed local edits."""
    normalized_mode = str(mode or "safe").strip().lower()
    if normalized_mode not in {"safe", "force_device_state", "preview"}:
        raise ValueError("Sync mode must be safe, force_device_state, or preview")

    clean_host = str(host or "").strip()
    if not clean_host:
        raise ValueError("Device host is required")
    rows = parse_syslog_config(running_config)

    with closing(sqlite3.connect(str(db_path))) as conn:
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        conn.execute("PRAGMA busy_timeout = 5000")
        ensure_device_schema(conn)
        pending = conn.execute(
            """SELECT 1 FROM t10_syslog_servers
               WHERE device_host = ?
                 AND sync_status IN ('pending_apply', 'pending_delete')
               LIMIT 1""",
            (clean_host,),
        ).fetchone() is not None

        if normalized_mode == "preview":
            return {
                "syslog_servers": len(rows),
                "syslog_conflict": pending,
                "syslog_applied": False,
            }
        if normalized_mode == "safe" and pending:
            return {
                "syslog_servers": len(rows),
                "syslog_conflict": True,
                "syslog_applied": False,
            }

        with conn:
            conn.execute(
                "DELETE FROM t10_syslog_servers WHERE device_host = ?",
                (clean_host,),
            )
            conn.executemany(
                """INSERT INTO t10_syslog_servers(
                       device_host, server_ip, protocol, port, source_interface,
                       trap_severity, timestamps, sequence_numbers, configured,
                       sync_status, last_result, updated_at
                   ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, 'synchronized', ?, CURRENT_TIMESTAMP)""",
                [
                    (
                        clean_host,
                        row["server_ip"],
                        row["protocol"],
                        row["port"],
                        row["source_interface"],
                        row["trap_severity"],
                        int(row["timestamps"]),
                        int(row["sequence_numbers"]),
                        "Imported from running-config.",
                    )
                    for row in rows
                ],
            )

    return {
        "syslog_servers": len(rows),
        "syslog_conflict": False,
        "syslog_applied": True,
    }


__all__ = ["parse_syslog_config", "sync_syslog_state"]
