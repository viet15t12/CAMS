"""Two-switch Quick EtherChannel workflow and transactional persistence."""

from __future__ import annotations

import re
import sqlite3
from contextlib import closing
from typing import Any

from .common import choice, integer, validate_vlan_expression
from .etherchannel_repository import save_etherchannel
from .interface_repository import save_switch_interface
from .schema import ensure_switch_schema


_PORT_CHANNEL_RE = re.compile(r"^(?:port[- ]?channel|po)\d+$", re.IGNORECASE)
_PROTOCOL_MODES = {"lacp": "active", "pagp": "desirable", "static": "on"}


class EtherChannelQuickService:
    """Stage one matching EtherChannel endpoint on exactly two connected switches."""

    def __init__(self, db: Any) -> None:
        self.db = db
        ensure_switch_schema(db)

    @staticmethod
    def _member_names(value: Any) -> set[str]:
        return {
            part.strip().casefold()
            for part in str(value or "").split(",")
            if part.strip()
        }

    def _host_options(
        self, conn: sqlite3.Connection, host: str, device_name: str
    ) -> dict[str, Any]:
        assigned: set[str] = set()
        for row in conn.execute(
            """
            SELECT member_ports FROM t06_etherchannel
            WHERE host = ?
              AND COALESCE(success, 'pending_apply') <> 'pending_delete';
            """,
            (host,),
        ).fetchall():
            assigned.update(self._member_names(row["member_ports"]))
        ports = [
            dict(row)
            for row in conn.execute(
                """
                SELECT id, if_name, description, mode, admin_status, oper_status,
                       speed, duplex, success
                FROM t06_interface_l2
                WHERE host = ? AND mode IN ('access', 'trunk')
                  AND COALESCE(success, 'pending_apply') <> 'pending_delete'
                ORDER BY if_name COLLATE NOCASE;
                """,
                (host,),
            ).fetchall()
            if not _PORT_CHANNEL_RE.fullmatch(str(row["if_name"] or "").strip())
            and str(row["if_name"] or "").strip().casefold() not in assigned
        ]
        vlans = [
            int(row["vlan_id"])
            for row in conn.execute(
                """
                SELECT vlan_id FROM t06_vlan_db
                WHERE host = ?
                  AND COALESCE(success, 'pending_apply') <> 'pending_delete'
                  AND (device_present = 1 OR success <> 'synchronized')
                ORDER BY vlan_id;
                """,
                (host,),
            ).fetchall()
        ]
        return {
            "host": host,
            "device_name": device_name,
            "ports": ports,
            "vlans": vlans,
        }

    def options(self, source_host: str) -> dict[str, Any]:
        source = str(source_host or "").strip()
        with closing(self.db._connect()) as conn:
            rows = conn.execute(
                """
                SELECT host, device_name
                FROM t01_devices
                WHERE connection_status = 'connected'
                  AND (
                    lower(COALESCE(role, '')) IN ('sw2', 'sw3')
                    OR lower(COALESCE(device_type, '')) IN ('switch', 'sw2', 'sw3')
                  )
                ORDER BY host COLLATE NOCASE;
                """
            ).fetchall()
            hosts = [
                self._host_options(
                    conn, str(row["host"]), str(row["device_name"] or "")
                )
                for row in rows
            ]
            used_numbers = {
                int(row["po_number"])
                for row in conn.execute(
                    """
                    SELECT po_number FROM t06_etherchannel
                    WHERE COALESCE(success, 'pending_apply') <> 'pending_delete';
                    """
                ).fetchall()
            }
        source_row = next((row for row in hosts if row["host"] == source), None)
        suggested = next(
            (number for number in range(1, 4097) if number not in used_numbers), 1
        )
        return {
            "ok": source_row is not None,
            "source": source_row or {"host": source, "ports": [], "vlans": []},
            "targets": [row for row in hosts if row["host"] != source],
            "suggestedPoNumber": suggested,
            "message": "" if source_row is not None else "Current switch is not connected.",
        }

    @staticmethod
    def _row_value(row: sqlite3.Row | None, key: str, default: Any) -> Any:
        if row is None or key not in row.keys() or row[key] is None:
            return default
        return row[key]

    @staticmethod
    def _interface_payload(
        row: sqlite3.Row | None,
        if_name: str,
        switchport_mode: str,
        profile: dict[str, Any],
        description: str,
    ) -> dict[str, Any]:
        payload = {
            "id": int(row["id"]) if row is not None else 0,
            "if_name": if_name,
            "description": str(
                EtherChannelQuickService._row_value(row, "description", description)
            ),
            "mode": switchport_mode,
            "admin_status": str(
                EtherChannelQuickService._row_value(row, "admin_status", "up")
            ),
            "oper_status": str(
                EtherChannelQuickService._row_value(row, "oper_status", "unknown")
            ),
            "speed": str(EtherChannelQuickService._row_value(row, "speed", "auto")),
            "duplex": str(EtherChannelQuickService._row_value(row, "duplex", "auto")),
            "portfast": str(
                EtherChannelQuickService._row_value(row, "portfast", "disabled")
            ),
            "bpduguard": str(
                EtherChannelQuickService._row_value(row, "bpduguard", "disabled")
            ),
            "bpdufilter": str(
                EtherChannelQuickService._row_value(row, "bpdufilter", "disabled")
            ),
            "root_guard": str(
                EtherChannelQuickService._row_value(row, "root_guard", "disabled")
            ),
            "loop_guard": str(
                EtherChannelQuickService._row_value(row, "loop_guard", "disabled")
            ),
            "port_security_enabled": bool(
                switchport_mode == "access"
                and EtherChannelQuickService._row_value(
                    row, "port_security_enabled", 0
                )
            ),
            "max_mac": EtherChannelQuickService._row_value(row, "max_mac", 1),
            "violation": str(
                EtherChannelQuickService._row_value(row, "violation", "shutdown")
            ),
            "sticky": bool(EtherChannelQuickService._row_value(row, "sticky", 0)),
            "aging_type": str(
                EtherChannelQuickService._row_value(row, "aging_type", "absolute")
            ),
            "aging_time": EtherChannelQuickService._row_value(row, "aging_time", 0),
        }
        payload.update(profile)
        return payload

    @staticmethod
    def _require_ok(result: dict[str, Any]) -> None:
        if not result.get("ok"):
            raise ValueError(str(result.get("message") or "Quick setup failed"))

    def _stage_endpoint(
        self,
        conn: sqlite3.Connection,
        *,
        host: str,
        peer: str,
        port: str,
        po_number: int,
        protocol: str,
        switchport_mode: str,
        profile: dict[str, Any],
    ) -> None:
        physical = conn.execute(
            """
            SELECT i.id, i.if_name, i.description, i.mode, i.admin_status,
                   i.oper_status, i.speed, i.duplex,
                   s.portfast, s.bpduguard, s.bpdufilter, s.root_guard, s.loop_guard,
                   COALESCE(ps.enabled, 0) AS port_security_enabled,
                   ps.max_mac, ps.violation, ps.sticky, ps.aging_type, ps.aging_time
            FROM t06_interface_l2 AS i
            LEFT JOIN t06_iface_stp AS s ON s.iface_id = i.id
            LEFT JOIN t06_iface_port_security AS ps ON ps.iface_id = i.id
            WHERE i.host = ? AND lower(i.if_name) = lower(?)
            LIMIT 1;
            """,
            (host, port),
        ).fetchone()
        if physical is None:
            raise ValueError(f"Interface {port} does not exist on {host}")

        logical_name = f"Port-channel{po_number}"
        logical = conn.execute(
            """
            SELECT i.id, i.if_name, i.description, i.mode, i.admin_status,
                   i.oper_status, i.speed, i.duplex,
                   s.portfast, s.bpduguard, s.bpdufilter, s.root_guard, s.loop_guard,
                   COALESCE(ps.enabled, 0) AS port_security_enabled,
                   ps.max_mac, ps.violation, ps.sticky, ps.aging_type, ps.aging_time
            FROM t06_interface_l2 AS i
            LEFT JOIN t06_iface_stp AS s ON s.iface_id = i.id
            LEFT JOIN t06_iface_port_security AS ps ON ps.iface_id = i.id
            WHERE i.host = ? AND (
                lower(replace(replace(i.if_name, '-', ''), ' ', '')) = lower(?)
                OR lower(i.if_name) = lower(?)
            )
            LIMIT 1;
            """,
            (host, f"portchannel{po_number}", f"po{po_number}"),
        ).fetchone()

        self._require_ok(
            save_switch_interface(
                self.db,
                host,
                self._interface_payload(
                    physical, port, switchport_mode, profile, ""
                ),
                connection=conn,
            )
        )
        self._require_ok(
            save_switch_interface(
                self.db,
                host,
                self._interface_payload(
                    logical,
                    str(logical["if_name"]) if logical is not None else logical_name,
                    switchport_mode,
                    profile,
                    f"Quick EtherChannel to {peer}",
                ),
                connection=conn,
            )
        )
        self._require_ok(
            save_etherchannel(
                self.db,
                host,
                {
                    "po_number": po_number,
                    "protocol": protocol,
                    "mode": _PROTOCOL_MODES[protocol],
                    "member_ports": port,
                    "description": f"Quick EtherChannel to {peer}",
                },
                connection=conn,
            )
        )

    def save(self, payload: dict[str, Any]) -> dict[str, Any]:
        source_host = str(payload.get("source_host") or "").strip()
        target_host = str(payload.get("target_host") or "").strip()
        source_port = str(payload.get("source_port") or "").strip()
        target_port = str(payload.get("target_port") or "").strip()
        try:
            if not source_host or not target_host or source_host == target_host:
                raise ValueError("Choose two different connected switches")
            if not source_port or not target_port:
                raise ValueError("Choose one physical port on each switch")
            po_number = integer(
                payload.get("po_number"), "Port-channel number", 1, 4096
            )
            protocol = choice(
                payload.get("protocol"), "Protocol", set(_PROTOCOL_MODES), "lacp"
            )
            switchport_mode = choice(
                payload.get("switchport_mode"),
                "Switchport mode",
                {"access", "trunk"},
                "trunk",
            )
            if switchport_mode == "access":
                profile = {
                    "access_vlan": integer(
                        payload.get("access_vlan"), "Access VLAN", 1, 4094
                    ),
                    "voice_vlan": None,
                }
            else:
                profile = {
                    "native_vlan": integer(
                        payload.get("native_vlan"), "Native VLAN", 1, 4094
                    ),
                    "allowed_vlans": validate_vlan_expression(
                        payload.get("allowed_vlans"), "Allowed VLANs", "all"
                    ),
                    "encapsulation": "dot1q",
                    "pruning_vlans": "none",
                }

            with closing(self.db._connect()) as conn:
                with conn:
                    connected = {
                        str(row["host"])
                        for row in conn.execute(
                            """
                            SELECT host FROM t01_devices
                            WHERE connection_status = 'connected'
                              AND (
                                lower(COALESCE(role, '')) IN ('sw2', 'sw3')
                                OR lower(COALESCE(device_type, ''))
                                   IN ('switch', 'sw2', 'sw3')
                              );
                            """
                        ).fetchall()
                    }
                    if source_host not in connected or target_host not in connected:
                        raise ValueError("Both EtherChannel switches must be connected")
                    endpoint_rows: list[sqlite3.Row] = []
                    for host, port in (
                        (source_host, source_port),
                        (target_host, target_port),
                    ):
                        duplicate = conn.execute(
                            """
                            SELECT 1 FROM t06_etherchannel
                            WHERE host = ? AND po_number = ?
                              AND COALESCE(success, 'pending_apply') <> 'pending_delete';
                            """,
                            (host, po_number),
                        ).fetchone()
                        if duplicate is not None:
                            raise ValueError(
                                f"Port-channel{po_number} already exists on {host}"
                            )
                        assigned = [
                            row
                            for row in conn.execute(
                                """
                                SELECT po_number, member_ports
                                FROM t06_etherchannel
                                WHERE host = ?
                                  AND COALESCE(success, 'pending_apply')
                                      <> 'pending_delete';
                                """,
                                (host,),
                            ).fetchall()
                            if port.casefold() in self._member_names(row["member_ports"])
                        ]
                        if assigned:
                            raise ValueError(
                                f"{port} already belongs to Port-channel"
                                f"{assigned[0]['po_number']} on {host}"
                            )
                        endpoint = conn.execute(
                            """
                            SELECT speed, duplex FROM t06_interface_l2
                            WHERE host = ? AND lower(if_name) = lower(?)
                              AND mode IN ('access', 'trunk')
                              AND COALESCE(success, 'pending_apply')
                                  <> 'pending_delete'
                            LIMIT 1;
                            """,
                            (host, port),
                        ).fetchone()
                        if endpoint is None:
                            raise ValueError(
                                f"{port} is not an available Layer 2 port on {host}"
                            )
                        endpoint_rows.append(endpoint)
                    if (
                        str(endpoint_rows[0]["speed"]) != str(endpoint_rows[1]["speed"])
                        or str(endpoint_rows[0]["duplex"])
                        != str(endpoint_rows[1]["duplex"])
                    ):
                        raise ValueError(
                            "The selected ports must use matching speed and duplex settings"
                        )
                    self._stage_endpoint(
                        conn,
                        host=source_host,
                        peer=target_host,
                        port=source_port,
                        po_number=po_number,
                        protocol=protocol,
                        switchport_mode=switchport_mode,
                        profile=profile,
                    )
                    self._stage_endpoint(
                        conn,
                        host=target_host,
                        peer=source_host,
                        port=target_port,
                        po_number=po_number,
                        protocol=protocol,
                        switchport_mode=switchport_mode,
                        profile=profile,
                    )
            return {
                "ok": True,
                "successful": [source_host, target_host],
                "message": (
                    f"Quick EtherChannel Port-channel{po_number} staged on both switches."
                ),
            }
        except (sqlite3.Error, ValueError, TypeError) as exc:
            return {"ok": False, "successful": [], "message": str(exc)}


__all__ = ["EtherChannelQuickService"]
