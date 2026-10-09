"""Collect the IOS ACL forms represented by the ACL editor without queuing a push."""

from __future__ import annotations

import re
import sqlite3
from ipaddress import IPv4Address
from typing import Any

from features.acl.rules import RULE_TABLES, insert_rule, read_rules, normalized_rules
from features.acl.validation import validate_acl_name, validate_rules


def _address(parts: list[str], offset: int) -> tuple[str, str | None, int]:
    token = parts[offset]
    if token == "any":
        return "any", None, offset + 1
    if token == "host":
        return "host " + str(IPv4Address(parts[offset + 1])), None, offset + 2
    address = str(IPv4Address(token))
    wildcard = str(IPv4Address(parts[offset + 1]))
    return address, wildcard, offset + 2


def _port(parts: list[str], offset: int) -> tuple[str | None, int]:
    if offset < len(parts) and parts[offset] in {"eq", "neq", "lt", "gt", "range"}:
        size = 3 if parts[offset] == "range" else 2
        if len(parts) < offset + size:
            raise ValueError("Incomplete port condition")
        return " ".join(parts[offset:offset + size]), offset + size
    return None, offset


def _mac_address(parts: list[str], offset: int) -> tuple[str, str | None, int]:
    if parts[offset] == "any":
        return "any", None, offset + 1
    if parts[offset] == "host":
        return parts[offset + 1], "0000.0000.0000", offset + 2
    return parts[offset], parts[offset + 1], offset + 2


def _rule(kind: str, line: str, sequence: int) -> dict[str, Any]:
    parts = line.split()
    if parts and parts[0].isdigit():
        sequence = int(parts.pop(0))
    if parts[-1:] in (["log"], ["log-input"]):
        parts.pop()
    row: dict[str, Any] = {"sequence": sequence}
    if parts[:1] == ["evaluate"] and len(parts) == 2:
        return dict(row, action="permit", protocol="evaluate", source="any",
                    destination="any", reflect_name=parts[1], timeout_seconds=300)
    if parts[:1] == ["dynamic"]:
        row["dynamic_name"] = parts[1]
        offset = 2
        row["timeout_seconds"] = None
        if parts[offset:offset + 1] == ["timeout"]:
            row["timeout_seconds"] = int(parts[offset + 1]) * 60
            offset += 2
        parts = parts[offset:]
    row["action"] = parts[0]
    if row["action"] not in {"permit", "deny"}:
        raise ValueError("Unsupported ACL action")
    if kind == "mac":
        row["src_mac"], row["src_mask"], offset = _mac_address(parts, 1)
        row["dst_mac"], row["dst_mask"], offset = _mac_address(parts, offset)
        if len(parts) > offset + 1:
            raise ValueError("Unsupported MAC qualifier")
        row["ethertype"] = parts[offset] if offset < len(parts) else None
        return row
    if kind == "standard":
        if len(parts) == 2 and parts[1] != "any":
            row["source"], row["wildcard"], offset = "host " + str(IPv4Address(parts[1])), None, 2
        else:
            row["source"], row["wildcard"], offset = _address(parts, 1)
    else:
        row["protocol"] = parts[1]
        row["source"], row["src_wildcard"], offset = _address(parts, 2)
        row["src_port"], offset = _port(parts, offset)
        row["destination"], row["dst_wildcard"], offset = _address(parts, offset)
        row["dst_port"], offset = _port(parts, offset)
        if row["protocol"] == "icmp" and offset < len(parts) and parts[offset] != "reflect":
            row["dst_port"] = parts[offset]
            offset += 1
        if parts[offset:offset + 1] == ["reflect"]:
            row["reflect_name"] = parts[offset + 1]
            row["timeout_seconds"] = 300
            offset += 2
            if parts[offset:offset + 1] == ["timeout"]:
                row["timeout_seconds"] = int(parts[offset + 1])
                offset += 2
    if offset != len(parts):
        raise ValueError("ACL qualifier cannot be represented by the editor")
    return row


def parse_acl_sections(text: str) -> tuple[list[dict[str, Any]], list[dict[str, str]], list[dict[str, str]]]:
    blocks: dict[str, dict[str, Any]] = {}
    bindings: list[dict[str, str]] = []
    active = None
    interface = ""
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("!"):
            active, interface = None, ""
            continue
        if not raw.startswith((" ", "\t")):
            active, interface = None, ""
            match = re.fullmatch(r"ip access-list (standard|extended) (\S+)|mac access-list extended (\S+)", line)
            if match:
                kind, name = (match[1], match[2]) if match[1] else ("mac", match[3])
                active = blocks.setdefault(name, {"acl_name": name, "acl_type": kind, "lines": []})
            elif line.startswith("access-list "):
                parts = line.split(maxsplit=2)
                if len(parts) == 3:
                    name, body = parts[1:]
                    number = int(name) if name.isdigit() else 0
                    kind = ("standard" if 1 <= number <= 99 or 1300 <= number <= 1999
                            else "extended" if 100 <= number <= 199 or 2000 <= number <= 2699 else "unsupported")
                    blocks.setdefault(name, {"acl_name": name, "acl_type": kind, "lines": []})["lines"].append(body)
            elif line.startswith("interface "):
                interface = line[len("interface "):]
            continue
        if active is not None:
            active["lines"].append(line)
        elif interface:
            match = re.fullmatch(r"(ip|mac) access-group (\S+) (in|out)", line)
            if match:
                bindings.append({"interface_name": interface, "acl_name": match[2],
                                 "direction": match[3], "family": match[1]})

    parsed, unsupported = [], []
    for block in blocks.values():
        name, kind = block["acl_name"], block["acl_type"]
        try:
            validate_acl_name(name)
            if kind == "unsupported":
                raise ValueError("Unsupported ACL number range")
            rules, remarks, sequence, inferred = [], [], 10, []
            for line in block["lines"]:
                remark = re.fullmatch(r"(?:\d+\s+)?remark(?:\s+(.*))?", line)
                if remark:
                    remarks.append(remark[1] or "")
                    continue
                row = _rule(kind, line, sequence)
                inferred.append(not line.split()[0].isdigit())
                sequence = max(sequence, row["sequence"] + 10)
                rules.append(row)
            if any(row.get("dynamic_name") for row in rules):
                kind = "dynamic"
                for row in rules:
                    row.setdefault("dynamic_name", "")
            elif any(row.get("reflect_name") or row.get("protocol") == "evaluate" for row in rules):
                kind = "reflexive"
            validate_rules(kind, rules)
            # IOS can omit sequence numbers from running-config. Normalize
            # an unnumbered IP ACL before editing; ambiguous mixed/remark
            # layouts remain visible but require a sequenced snapshot to edit.
            action_cfg = 0
            if kind != "mac" and any(inferred):
                action_cfg = 2 if all(inferred) and not remarks else 4
            parsed.append({"acl_name": name, "acl_type": kind,
                           "description": " / ".join(remarks) or None, "rules": rules,
                           "action_Cfg": action_cfg})
        except (IndexError, TypeError, ValueError) as exc:
            unsupported.append({"acl_name": name, "code": "ACL_FORM_UNSUPPORTED", "reason": str(exc)})
    return parsed, unsupported, bindings


def acl_has_pending(conn: sqlite3.Connection, host: str) -> bool:
    if not conn.execute("SELECT 1 FROM sqlite_master WHERE name='t05_ACL_DB'").fetchone():
        return False
    checks = " OR ".join(
        f"EXISTS(SELECT 1 FROM {table} r WHERE r.acl_id=a.Acl_id "
        "AND r.sync_status IN ('pending_apply','pending_delete'))"
        for table in (*RULE_TABLES.values(), "t05_router_iface_acl")
    )
    return conn.execute(
        f"SELECT 1 FROM t05_ACL_DB a WHERE host=? AND "
        f"(sync_status IN ('pending_apply','pending_delete') OR {checks}) LIMIT 1", (host,),
    ).fetchone() is not None


def sync_acls(conn: sqlite3.Connection, host: str, acls: list[dict[str, Any]],
              unsupported: list[dict[str, str]], bindings: list[dict[str, str]]) -> None:
    if not conn.execute("SELECT 1 FROM sqlite_master WHERE name='t05_ACL_DB'").fetchone():
        return
    protected = {row["acl_name"] for row in unsupported}
    kept = protected | {row["acl_name"] for row in acls}
    existing = {row["acl_name"]: dict(row) for row in conn.execute(
        "SELECT * FROM t05_ACL_DB WHERE host=?", (host,))}
    for name, row in existing.items():
        if name not in kept:
            conn.execute("DELETE FROM t05_ACL_DB WHERE Acl_id=?", (row["Acl_id"],))
    for acl in acls:
        name, kind = acl["acl_name"], acl["acl_type"]
        current = existing.get(name)
        if current:
            acl_id = current["Acl_id"]
            conn.execute("UPDATE t05_ACL_DB SET acl_type=?, description=?, action_Cfg=?, "
                         "sync_status='synchronized' WHERE Acl_id=?", (kind, acl["description"], acl["action_Cfg"], acl_id))
        else:
            acl_id = conn.execute(
                "INSERT INTO t05_ACL_DB(host,acl_name,acl_type,description,action_Cfg,sync_status) "
                "VALUES(?,?,?,?,?,'synchronized')", (host, name, kind, acl["description"], acl["action_Cfg"]),
            ).lastrowid
        has_deleted_rules = conn.execute(f"SELECT 1 FROM {RULE_TABLES[kind]} WHERE acl_id=? "
                                         "AND sync_status='pending_delete' LIMIT 1", (acl_id,)).fetchone()
        if not current or current["acl_type"] != kind or has_deleted_rules or (
                normalized_rules(kind, read_rules(conn, kind, acl_id)) != normalized_rules(kind, acl["rules"])):
            for table in RULE_TABLES.values():
                conn.execute(f"DELETE FROM {table} WHERE acl_id=?", (acl_id,))
            for rule in acl["rules"]:
                insert_rule(conn, kind, acl_id, rule)
        conn.execute(f"UPDATE {RULE_TABLES[kind]} SET sync_status='synchronized' WHERE acl_id=?", (acl_id,))

    # Binding reconciliation is by interface/direction, retaining unchanged IDs.
    desired = {}
    catalog = {row["acl_name"]: row["Acl_id"] for row in conn.execute(
        "SELECT acl_name,Acl_id FROM t05_ACL_DB WHERE host=?", (host,))}
    for binding in bindings:
        name = binding["acl_name"]
        if name not in catalog:
            continue
        interface = conn.execute("SELECT iface_id FROM t02_interface_name WHERE host=? AND interface_name=?",
                                 (host, binding["interface_name"])).fetchone()
        if not interface:
            # Switch operational inventory lives in t06_*; ACL bindings use
            # the shared interface identity table, without an L3 profile.
            iface_id = conn.execute("INSERT INTO t02_interface_name(host,interface_name,sync_status) "
                                    "VALUES(?,?,'synchronized')", (host, binding["interface_name"])).lastrowid
        else:
            iface_id = interface["iface_id"]
        desired[(iface_id, binding["direction"])] = catalog[name]
    rows = conn.execute("SELECT b.*,a.acl_name FROM t05_router_iface_acl b "
                        "JOIN t05_ACL_DB a ON a.Acl_id=b.acl_id WHERE a.host=?", (host,)).fetchall()
    for row in rows:
        key = (row["iface_id"], row["direction"])
        if row["acl_name"] not in protected and key not in desired:
            conn.execute("DELETE FROM t05_router_iface_acl WHERE id=?", (row["id"],))
    for (iface_id, direction), acl_id in desired.items():
        current = conn.execute("SELECT id FROM t05_router_iface_acl WHERE iface_id=? AND direction=?",
                               (iface_id, direction)).fetchone()
        if current:
            conn.execute("UPDATE t05_router_iface_acl SET acl_id=?,sync_status='synchronized' WHERE id=?",
                         (acl_id, current["id"]))
        else:
            conn.execute("INSERT INTO t05_router_iface_acl(iface_id,acl_id,direction,sync_status) "
                         "VALUES(?,?,?,'synchronized')", (iface_id, acl_id, direction))
