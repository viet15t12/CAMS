"""Parse and synchronize bounded Cisco switch operational snapshots."""

from __future__ import annotations

import re
import sqlite3
from contextlib import closing
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .etherchannel_sync import parse_etherchannels, sync_etherchannels
from .interface_names import INTERFACE_NAME_PATTERN, normalize_interface_name
from features.devices.sync import (
    clear_fhrp_members,
    insert_fhrp_members,
    parse_running_config_sections,
)


def parse_vlan_brief(output: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for match in re.finditer(
        r"(?m)^\s*(\d+)\s+(\S+)\s+(active|suspended|suspend)\b",
        str(output or ""),
        re.IGNORECASE,
    ):
        vlan_id = int(match.group(1))
        if 1002 <= vlan_id <= 1005:
            continue
        rows.append(
            {
                "vlan_id": vlan_id,
                "vlan_name": match.group(2),
                "state": "suspend" if "suspend" in match.group(3).lower() else "active",
            }
        )
    return rows


def parse_interface_status(output: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    pattern = re.compile(
        rf"(?m)^\s*({INTERFACE_NAME_PATTERN})\s+(.*?)\s+"
        r"(connected|notconnect|disabled|err-disabled)\s+"
        r"(trunk|routed|unassigned|\d+)\s+"
        r"(auto|a-full|full|a-half|half)\s+(auto|a-\d+|\d+)\b",
        re.IGNORECASE,
    )
    for match in pattern.finditer(str(output or "")):
        vlan = match.group(4).lower()
        rows.append(
            {
                "if_name": normalize_interface_name(match.group(1)),
                "description": match.group(2).strip(),
                "mode": "trunk" if vlan == "trunk" else "routed" if vlan == "routed" else "access",
                "admin_status": "down" if match.group(3).lower() == "disabled" else "up",
                "oper_status": (
                    "up" if match.group(3).lower() == "connected"
                    else "err-disabled" if match.group(3).lower() == "err-disabled"
                    else "down"
                ),
                "speed": match.group(6).lower().removeprefix("a-"),
                "duplex": match.group(5).lower().removeprefix("a-"),
                "access_vlan": int(vlan) if vlan.isdigit() else None,
            }
        )
    return rows


def parse_trunks(output: str) -> dict[str, dict[str, Any]]:
    trunks: dict[str, dict[str, Any]] = {}
    text = str(output or "")
    pattern = re.compile(
        rf"(?m)^\s*({INTERFACE_NAME_PATTERN})\s+\S+\s+"
        r"(802\.1q|isl|n-802\.1q|n-isl)\s+trunking\s+(\d+)\b",
        re.IGNORECASE,
    )
    for match in pattern.finditer(text):
        encapsulation = "dot1q" if "802.1q" in match.group(2).lower() else "isl"
        trunks[normalize_interface_name(match.group(1))] = {
            "native_vlan": int(match.group(3)),
            "encapsulation": encapsulation,
            "allowed_vlans": "all",
        }
    allowed_section = re.search(
        r"(?ims)^\s*Port\s+Vlans allowed on trunk\s*$"
        r"(.*?)(?=^\s*Port\s+Vlans |\Z)",
        text,
    )
    if allowed_section:
        allowed_pattern = re.compile(
            rf"(?m)^\s*({INTERFACE_NAME_PATTERN})\s+"
            r"(all|none|\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*)\s*$",
            re.IGNORECASE,
        )
        for match in allowed_pattern.finditer(allowed_section.group(1)):
            if_name = normalize_interface_name(match.group(1))
            if if_name in trunks:
                trunks[if_name]["allowed_vlans"] = match.group(2).lower()
    return trunks


def parse_vtp_status(output: str) -> dict[str, Any] | None:
    text = str(output or "")
    domain = re.search(r"VTP Domain Name\s*:\s*(\S+)", text, re.IGNORECASE)
    if not domain or domain.group(1).lower() in {"null", "none", "(none)"}:
        return None
    version = re.search(r"VTP version running\s*:\s*(\d+)", text, re.IGNORECASE)
    mode = re.search(r"VTP Operating Mode\s*:\s*(\w+)", text, re.IGNORECASE)
    pruning = re.search(r"VTP Pruning Mode\s*:\s*(\w+)", text, re.IGNORECASE)
    return {
        "domain_name": domain.group(1).strip(),
        "version": int(version.group(1)) if version else 2,
        "mode": mode.group(1).lower() if mode else "transparent",
        "pruning": int(bool(pruning and pruning.group(1).lower() == "enabled")),
        "primary_server": int(bool(re.search(r"VTP Primary Server\s*:\s*local", text, re.IGNORECASE))),
    }


def _parse_vlan_list(text: str) -> set[int]:
    """Parse comma/hyphen separated VLAN strings into a set of integers."""
    vlans: set[int] = set()
    cleaned = str(text or "").strip()
    if not cleaned or cleaned.lower() == "none":
        return vlans
    for token in re.findall(r"\d+(?:-\d+)?", cleaned):
        if "-" in token:
            parts = token.split("-", 1)
            try:
                start, end = int(parts[0]), int(parts[1])
                if 1 <= start <= end <= 4094:
                    vlans.update(range(start, end + 1))
            except ValueError:
                continue
        else:
            try:
                vlan_id = int(token)
                if 1 <= vlan_id <= 4094:
                    vlans.add(vlan_id)
            except ValueError:
                continue
    return vlans


def parse_dhcp_snooping(output: str) -> dict[str, Any]:
    """Parse Cisco IOS `show ip dhcp snooping` output."""
    text = str(output or "")
    dhcp_vlans: set[int] = set()
    trust_ports: set[str] = set()

    oper_match = re.search(
        r"(?ims)DHCP snooping is operational on following VLANs:\s*([0-9,\-\s]+)",
        text,
    )
    conf_match = re.search(
        r"(?ims)DHCP snooping is configured on following VLANs:\s*([0-9,\-\s]+)",
        text,
    )
    if oper_match and oper_match.group(1).strip().lower() != "none":
        dhcp_vlans.update(_parse_vlan_list(oper_match.group(1)))
    elif conf_match and conf_match.group(1).strip().lower() != "none":
        if not re.search(r"Switch DHCP snooping is disabled", text, re.IGNORECASE):
            dhcp_vlans.update(_parse_vlan_list(conf_match.group(1)))

    trust_section = re.search(
        r"(?ims)(?:following Interfaces:|Interface\s+Trusted)\s*\n.*?-{5,}\s*\n(.*?)(?=\n\n|\Z)",
        text,
    )
    search_target = trust_section.group(1) if trust_section else text
    for line in search_target.splitlines():
        line = line.strip()
        match = re.match(
            rf"^({INTERFACE_NAME_PATTERN})\s+(yes|no)\b",
            line,
            re.IGNORECASE,
        )
        if match and match.group(2).lower() == "yes":
            trust_ports.add(normalize_interface_name(match.group(1)))

    return {"dhcp_vlans": dhcp_vlans, "trust_ports": trust_ports}


def parse_running_config_security(config_text: str) -> dict[str, Any]:
    """Parse L2 security commands from Cisco IOS running configuration."""
    text = str(config_text or "")
    dhcp_vlans: set[int] = set()
    dai_vlans: set[int] = set()
    trust_ports: set[str] = set()

    for match in re.finditer(
        r"(?im)^\s*ip\s+dhcp\s+snooping\s+vlan\s+([0-9,\-\s]+)", text
    ):
        dhcp_vlans.update(_parse_vlan_list(match.group(1)))

    for match in re.finditer(
        r"(?im)^\s*ip\s+arp\s+inspection\s+vlan\s+([0-9,\-\s]+)", text
    ):
        dai_vlans.update(_parse_vlan_list(match.group(1)))

    iface_blocks = re.finditer(
        rf"(?ms)^\s*interface\s+({INTERFACE_NAME_PATTERN})\s*\n(.*?)(?=^\s*interface\b|^\s*!\s*$|\Z)",
        text,
    )
    for match in iface_blocks:
        if_name = normalize_interface_name(match.group(1))
        block = match.group(2)
        if re.search(r"(?im)^\s*ip\s+dhcp\s+snooping\s+trust\b", block) or re.search(
            r"(?im)^\s*ip\s+arp\s+inspection\s+trust\b", block
        ):
            trust_ports.add(if_name)

    return {
        "dhcp_vlans": dhcp_vlans,
        "dai_vlans": dai_vlans,
        "trust_ports": trust_ports,
    }


def parse_l2_security(snapshot: dict[str, str]) -> dict[str, Any]:
    """Combine L2 security operational state from show commands and running config."""
    dhcp_vlans: set[int] = set()
    dai_vlans: set[int] = set()
    trust_ports: set[str] = set()

    if "dhcp_snooping" in snapshot and snapshot["dhcp_snooping"]:
        cmd_result = parse_dhcp_snooping(snapshot["dhcp_snooping"])
        dhcp_vlans.update(cmd_result["dhcp_vlans"])
        trust_ports.update(cmd_result["trust_ports"])

    if "running_config" in snapshot and snapshot["running_config"]:
        cfg_result = parse_running_config_security(snapshot["running_config"])
        dhcp_vlans.update(cfg_result["dhcp_vlans"])
        dai_vlans.update(cfg_result["dai_vlans"])
        trust_ports.update(cfg_result["trust_ports"])

    return {
        "dhcp_vlans": dhcp_vlans,
        "dai_vlans": dai_vlans,
        "trust_ports": trust_ports,
    }


@dataclass
class _Database:
    db_path: str

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.db_path)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        return connection


def _module_has_local_state(conn: sqlite3.Connection, host: str, module: str) -> bool:
    if module == "security":
        return conn.execute(
            """
            SELECT 1 FROM t06_security_l2 WHERE host = ?
            UNION ALL
            SELECT 1 FROM t06_dhcp_trust_ports WHERE host = ?
            LIMIT 1;
            """,
            (host, host),
        ).fetchone() is not None
    table = {"vlan": "t06_vlan_db", "interfaces": "t06_interface_l2", "vtp": "t09_vtp_switches"}[module]
    return conn.execute(f"SELECT 1 FROM {table} WHERE host = ? LIMIT 1", (host,)).fetchone() is not None


def _module_is_pending(db: _Database, host: str, module: str) -> bool:
    if module == "security":
        tables = ("t06_security_l2", "t06_dhcp_trust_ports")
    else:
        tables = {
            "vlan": ("t06_vlan_db",),
            "interfaces": ("t06_interface_l2", "t06_etherchannel"),
            "vtp": ("t09_vtp_switches",),
        }[module]
    with closing(db._connect()) as conn:
        return any(
            conn.execute(
                f"""
                SELECT 1 FROM {table}
                WHERE host = ? AND (
                    success IN ('pending_apply','pending_delete') OR success IS NULL
                ) LIMIT 1;
                """,
                (host,),
            ).fetchone() is not None
            for table in tables
        )


def _sync_vlans(conn: sqlite3.Connection, host: str, rows: list[dict[str, Any]]) -> int:
    observed_ids = [row["vlan_id"] for row in rows]
    if observed_ids:
        placeholders = ",".join("?" for _ in observed_ids)
        conn.execute(
            f"""
            DELETE FROM t06_vlan_db
            WHERE host = ? AND success = 'synchronized'
              AND vlan_id NOT IN ({placeholders});
            """,
            (host, *sorted(observed_ids)),
        )
    else:
        conn.execute(
            """
            DELETE FROM t06_vlan_db
            WHERE host = ? AND success = 'synchronized';
            """,
            (host,),
        )
    for row in rows:
        conn.execute(
            """
            INSERT INTO t06_vlan_db(
                host, vlan_id, vlan_name, state, success, device_present
            )
            VALUES (?, ?, ?, ?, 'synchronized', 1)
            ON CONFLICT(host, vlan_id) DO UPDATE SET
                vlan_name = excluded.vlan_name, state = excluded.state,
                success = 'synchronized', device_present = 1;
            """,
            (host, row["vlan_id"], row["vlan_name"], row["state"]),
        )
    return len(rows)


def _sync_interfaces(conn: sqlite3.Connection, host: str, snapshot: dict[str, str]) -> int:
    rows = parse_interface_status(snapshot.get("interfaces_status", ""))
    trunks = parse_trunks(snapshot.get("interfaces_trunk", ""))
    synchronized_names: set[str] = set()
    for row in rows:
        # ``show interfaces trunk`` is authoritative for trunk mode. Some IOS
        # variants report a Port-channel's access/native VLAN number in
        # ``show interfaces status`` even while the logical interface is
        # actively trunking.
        trunk = trunks.get(row["if_name"])
        if trunk is not None:
            row["mode"] = "trunk"
            row["access_vlan"] = None
        conn.execute(
            """
            INSERT INTO t06_interface_l2(
                host, if_name, description, mode, admin_status, oper_status,
                speed, duplex, success
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'synchronized')
            ON CONFLICT(host, if_name) DO UPDATE SET
                description = excluded.description, mode = excluded.mode,
                admin_status = excluded.admin_status, oper_status = excluded.oper_status,
                speed = excluded.speed, duplex = excluded.duplex,
                updated_at = datetime('now'), success = 'synchronized'
            """,
            (host, row["if_name"], row["description"], row["mode"], row["admin_status"],
             row["oper_status"], row["speed"] if row["speed"] in {"auto", "10", "100", "1000", "10000"} else "auto",
             row["duplex"] if row["duplex"] in {"auto", "full", "half"} else "auto"),
        )
        iface_id = conn.execute(
            "SELECT id FROM t06_interface_l2 WHERE host = ? AND if_name = ?", (host, row["if_name"])
        ).fetchone()[0]
        synchronized_names.add(row["if_name"])
        if row["mode"] == "access" and row["access_vlan"] is not None:
            conn.execute("DELETE FROM t06_iface_trunk WHERE iface_id = ?", (iface_id,))
            conn.execute(
                "INSERT INTO t06_iface_access(iface_id, access_vlan) VALUES (?, ?) "
                "ON CONFLICT(iface_id) DO UPDATE SET access_vlan = excluded.access_vlan",
                (iface_id, row["access_vlan"]),
            )
        elif row["mode"] == "trunk":
            conn.execute("DELETE FROM t06_iface_access WHERE iface_id = ?", (iface_id,))
            if trunk is not None:
                conn.execute(
                    """
                    INSERT INTO t06_iface_trunk(iface_id, allowed_vlans, native_vlan, encapsulation)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(iface_id) DO UPDATE SET allowed_vlans = excluded.allowed_vlans,
                        native_vlan = excluded.native_vlan, encapsulation = excluded.encapsulation
                    """,
                    (iface_id, trunk["allowed_vlans"], trunk["native_vlan"], trunk["encapsulation"]),
                )

    # Keep a trunk visible even when a platform omits the logical
    # Port-channel from ``show interfaces status``. The trunk table still
    # provides an authoritative interface name and mode.
    for if_name, trunk in trunks.items():
        if if_name in synchronized_names:
            continue
        conn.execute(
            """
            INSERT INTO t06_interface_l2(host, if_name, mode, success)
            VALUES (?, ?, 'trunk', 'synchronized')
            ON CONFLICT(host, if_name) DO UPDATE SET
                mode = 'trunk', updated_at = datetime('now'),
                success = 'synchronized'
            """,
            (host, if_name),
        )
        iface_id = conn.execute(
            "SELECT id FROM t06_interface_l2 WHERE host = ? AND if_name = ?",
            (host, if_name),
        ).fetchone()[0]
        conn.execute("DELETE FROM t06_iface_access WHERE iface_id = ?", (iface_id,))
        conn.execute(
            """
            INSERT INTO t06_iface_trunk(iface_id, allowed_vlans, native_vlan, encapsulation)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(iface_id) DO UPDATE SET allowed_vlans = excluded.allowed_vlans,
                native_vlan = excluded.native_vlan, encapsulation = excluded.encapsulation
            """,
            (iface_id, trunk["allowed_vlans"], trunk["native_vlan"], trunk["encapsulation"]),
        )
    sync_etherchannels(conn, host, snapshot.get("etherchannel_summary", ""))
    return len(synchronized_names | set(trunks))


def _sync_vtp(conn: sqlite3.Connection, host: str, output: str) -> int:
    row = parse_vtp_status(output)
    if row is None:
        return 0
    conn.execute(
        """
        INSERT INTO t09_vtp_domains(domain_name, version, password_type, password_value)
        VALUES (?, ?, 'none', NULL)
        ON CONFLICT(domain_name) DO UPDATE SET version = excluded.version
        """,
        (row["domain_name"], row["version"]),
    )
    domain_id = conn.execute(
        "SELECT vtp_domain_id FROM t09_vtp_domains WHERE domain_name = ?", (row["domain_name"],)
    ).fetchone()[0]
    conn.execute(
        """
        INSERT INTO t09_vtp_switches(
            vtp_domain_id, host, pruning, sync_status, success
        ) VALUES (?, ?, ?, 'synchronized', 'synchronized')
        ON CONFLICT(host) DO UPDATE SET vtp_domain_id = excluded.vtp_domain_id,
            pruning = excluded.pruning, sync_status = 'synchronized',
            success = 'synchronized'
        """,
        (domain_id, host, row["pruning"]),
    )
    switch_id = conn.execute(
        "SELECT vtp_switch_id FROM t09_vtp_switches WHERE host = ?", (host,)
    ).fetchone()[0]
    conn.execute(
        """
        INSERT INTO t09_vtp_database_modes(vtp_switch_id, database_type, mode, primary_server)
        VALUES (?, 'vlan', ?, ?)
        ON CONFLICT(vtp_switch_id, database_type) DO UPDATE SET
            mode = excluded.mode, primary_server = excluded.primary_server
        """,
        (switch_id, row["mode"], row["primary_server"]),
    )
    return 1


def _sync_security(
    conn: sqlite3.Connection,
    host: str,
    security_data: dict[str, Any],
    mode: str = "safe",
) -> dict[str, int]:
    dhcp_vlans = set(security_data.get("dhcp_vlans") or ())
    dai_vlans = set(security_data.get("dai_vlans") or ())
    trust_ports = set(security_data.get("trust_ports") or ())
    protected_vlans = dhcp_vlans | dai_vlans
    force = mode == "force_device_state"

    # 1. Sync t06_security_l2
    clause = "" if force else "AND success = 'synchronized'"
    if protected_vlans:
        placeholders = ",".join("?" for _ in protected_vlans)
        conn.execute(
            f"""
            DELETE FROM t06_security_l2
            WHERE host = ? {clause}
              AND vlan_id NOT IN ({placeholders});
            """,
            (host, *sorted(protected_vlans)),
        )
    else:
        conn.execute(
            f"""
            DELETE FROM t06_security_l2
            WHERE host = ? {clause};
            """,
            (host,),
        )

    for vlan_id in sorted(protected_vlans):
        conn.execute(
            """
            INSERT INTO t06_security_l2(
                host, vlan_id, dhcp_snooping, dai_enabled, success
            ) VALUES (?, ?, ?, ?, 'synchronized')
            ON CONFLICT(host, vlan_id) DO UPDATE SET
                dhcp_snooping = excluded.dhcp_snooping,
                dai_enabled = excluded.dai_enabled,
                success = 'synchronized';
            """,
            (
                host,
                vlan_id,
                1 if vlan_id in dhcp_vlans else 0,
                1 if vlan_id in dai_vlans else 0,
            ),
        )

    # 2. Sync t06_dhcp_trust_ports
    if trust_ports:
        placeholders = ",".join("?" for _ in trust_ports)
        conn.execute(
            f"""
            DELETE FROM t06_dhcp_trust_ports
            WHERE host = ? {clause}
              AND if_name NOT IN ({placeholders});
            """,
            (host, *sorted(trust_ports)),
        )
    else:
        conn.execute(
            f"""
            DELETE FROM t06_dhcp_trust_ports
            WHERE host = ? {clause};
            """,
            (host,),
        )

    for if_name in sorted(trust_ports):
        conn.execute(
            """
            INSERT INTO t06_dhcp_trust_ports(host, if_name, success)
            VALUES (?, ?, 'synchronized')
            ON CONFLICT(host, if_name) DO UPDATE SET
                success = 'synchronized';
            """,
            (host, if_name),
        )

    return {"security_vlans": len(protected_vlans), "trust_ports": len(trust_ports)}


def sync_switch_state(
    db_path: str | Path,
    host: str,
    snapshot: dict[str, str],
    mode: str = "safe",
) -> dict[str, Any]:
    """Preview or merge switch state while preserving unpushed local modules."""
    db = _Database(str(db_path))
    from .schema import ensure_switch_schema

    ensure_switch_schema(db)
    device_role = ""
    with db._connect() as conn:
        role_row = conn.execute(
            "SELECT role FROM t01_devices WHERE host = ? LIMIT 1", (host,)
        ).fetchone()
        if role_row:
            device_role = str(role_row[0] or "").lower()

    parsed_fhrp = parse_running_config_sections(snapshot.get("running_config", ""))
    parsed_security = parse_l2_security(snapshot)
    has_security_snapshot = "dhcp_snooping" in snapshot or "running_config" in snapshot

    modules = {
        "vlan": bool(parse_vlan_brief(snapshot.get("vlan_brief", ""))),
        "interfaces": bool(parse_interface_status(snapshot.get("interfaces_status", ""))),
        "vtp": parse_vtp_status(snapshot.get("vtp_status", "")) is not None,
        "fhrp": ("running_config" in snapshot) and (device_role == "sw3" if device_role else True),
        "security": has_security_snapshot,
    }
    conflicts: list[str] = []
    with db._connect() as conn:
        for module, available in modules.items():
            if not available:
                continue
            if module == "fhrp":
                pending = conn.execute(
                    """
                    SELECT 1 FROM t08_fhrp_members AS m
                    LEFT JOIN t08_fhrp_tracks AS t ON t.member_id = m.member_id
                    WHERE m.host = ? AND (
                        m.sync_status IN ('pending_apply', 'pending_delete')
                        OR t.sync_status IN ('pending_apply', 'pending_delete')
                    ) LIMIT 1;
                    """,
                    (host,),
                ).fetchone()
                if pending is not None:
                    conflicts.append(module)
                continue
            if _module_has_local_state(conn, host, module) and _module_is_pending(db, host, module):
                conflicts.append(module)
    if mode == "preview":
        return {"conflicts": conflicts, "available": [key for key, value in modules.items() if value]}

    counts = {
        "vlans": 0,
        "interfaces": 0,
        "vtp": 0,
        "fhrp_members": 0,
        "security_vlans": 0,
        "trust_ports": 0,
    }
    applied: list[str] = []
    with db._connect() as conn, conn:
        if modules["vlan"] and (mode == "force_device_state" or "vlan" not in conflicts):
            counts["vlans"] = _sync_vlans(conn, host, parse_vlan_brief(snapshot["vlan_brief"]))
            applied.append("vlan")
        if modules["interfaces"] and (mode == "force_device_state" or "interfaces" not in conflicts):
            counts["interfaces"] = _sync_interfaces(conn, host, snapshot)
            applied.append("interfaces")
        if modules["vtp"] and (mode == "force_device_state" or "vtp" not in conflicts):
            counts["vtp"] = _sync_vtp(conn, host, snapshot["vtp_status"])
            applied.append("vtp")
        if modules["fhrp"] and (mode == "force_device_state" or "fhrp" not in conflicts):
            clear_fhrp_members(conn, host)
            insert_fhrp_members(conn, host, parsed_fhrp.fhrp_members)
            counts["fhrp_members"] = len(parsed_fhrp.fhrp_members)
            applied.append("fhrp")
        if modules["security"] and (mode == "force_device_state" or "security" not in conflicts):
            sec_counts = _sync_security(conn, host, parsed_security, mode=mode)
            counts["security_vlans"] = sec_counts["security_vlans"]
            counts["trust_ports"] = sec_counts["trust_ports"]
            applied.append("security")
    return {**counts, "conflicts": conflicts, "applied": applied}
