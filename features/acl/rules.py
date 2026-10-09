from __future__ import annotations

import sqlite3
from typing import Any

from .common import int_or_none, text_or_default, text_or_none

RULE_TABLES = {
    "standard": "t05_standard_acl_rules",
    "extended": "t05_extended_acl_rules",
    "dynamic": "t05_dynamic_acl_rules",
    "reflexive": "t05_reflexive_acl_rules",
    "mac": "t05_mac_acl_rules",
}


def normalized_rules(acl_type: str, rules: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Compare configuration fields rather than IDs or synchronization metadata."""
    fields = {
        "standard": ("sequence", "action", "source", "wildcard"),
        "mac": ("sequence", "action", "src_mac", "src_mask", "dst_mac", "dst_mask", "ethertype"),
    }.get(acl_type, ("sequence", "action", "protocol", "source", "src_wildcard", "src_port",
                     "destination", "dst_wildcard", "dst_port"))
    if acl_type in {"dynamic", "reflexive"}:
        fields += (("dynamic_name" if acl_type == "dynamic" else "reflect_name"), "timeout_seconds")
    defaults = {"action": "permit", "source": "any", "destination": "any", "protocol": "ip",
                "src_mac": "any", "dst_mac": "any", "timeout_seconds": 300}
    result = []
    for row in rules:
        item = {field: (int_or_none(row.get(field)) if field in {"sequence", "timeout_seconds"}
                        else text_or_none(row.get(field))) for field in fields}
        for field in fields:
            if item[field] is None and field in defaults:
                if field == "timeout_seconds" and acl_type == "dynamic" and field in row and row[field] is None:
                    continue
                item[field] = defaults[field]
        result.append(item)
    return sorted(result, key=lambda row: row["sequence"] or 0)


def insert_rule(conn: sqlite3.Connection, acl_type: str, acl_id: int, rule: dict[str, Any]) -> None:
    seq = int_or_none(rule.get("sequence"))
    action = text_or_default(rule.get("action"), "permit").lower()
    if acl_type == "standard":
        conn.execute(
            """INSERT INTO t05_standard_acl_rules
               (acl_id, sequence, action, source, wildcard, sync_status)
               VALUES (?, ?, ?, ?, ?, 'pending_apply')""",
            (acl_id, seq, action, text_or_default(rule.get("source"), "any"), text_or_none(rule.get("wildcard"))),
        )
    elif acl_type in {"extended", "dynamic", "reflexive"}:
        _insert_ip_rule(conn, acl_type, acl_id, seq, action, rule)
    else:
        conn.execute(
            """INSERT INTO t05_mac_acl_rules
               (acl_id, sequence, action, src_mac, src_mask, dst_mac, dst_mask, ethertype, sync_status)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending_apply')""",
            (acl_id, seq, action, text_or_default(rule.get("src_mac"), "any"),
             text_or_none(rule.get("src_mask")), text_or_default(rule.get("dst_mac"), "any"),
             text_or_none(rule.get("dst_mask")), text_or_none(rule.get("ethertype"))),
        )


def _insert_ip_rule(
    conn: sqlite3.Connection, acl_type: str, acl_id: int, seq: int | None,
    action: str, rule: dict[str, Any],
) -> None:
    fields = [acl_id, seq, action, text_or_default(rule.get("protocol"), "ip"),
              text_or_default(rule.get("source"), "any"), text_or_none(rule.get("src_wildcard")),
              text_or_none(rule.get("src_port")), text_or_default(rule.get("destination"), "any"),
              text_or_none(rule.get("dst_wildcard")), text_or_none(rule.get("dst_port"))]
    if acl_type == "extended":
        conn.execute(
            """INSERT INTO t05_extended_acl_rules
               (acl_id, sequence, action, protocol, source, src_wildcard, src_port,
                destination, dst_wildcard, dst_port, sync_status)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending_apply')""", fields,
        )
        return
    extra_name = "dynamic_name" if acl_type == "dynamic" else "reflect_name"
    table = RULE_TABLES[acl_type]
    timeout = (None if acl_type == "dynamic" and "timeout_seconds" in rule and rule["timeout_seconds"] is None
               else int_or_none(rule.get("timeout_seconds")) or 300)
    conn.execute(
        f"""INSERT INTO {table}
            (acl_id, sequence, action, protocol, source, src_wildcard, src_port,
             destination, dst_wildcard, dst_port, {extra_name}, timeout_seconds, sync_status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending_apply')""",
        fields + [(text_or_none(rule.get(extra_name)) or "") if acl_type == "dynamic"
                  else text_or_none(rule.get(extra_name)), timeout],
    )


def read_rules(conn: sqlite3.Connection, acl_type: str, acl_id: int) -> list[dict[str, Any]]:
    rows = conn.execute(
        f"SELECT * FROM {RULE_TABLES[acl_type]} WHERE acl_id = ? AND sync_status != 'pending_delete' "
        "ORDER BY sequence ASC, id ASC", (acl_id,),
    ).fetchall()
    return [dict(row) for row in rows]


def replace_rules(
    conn: sqlite3.Connection, acl_type: str, acl_id: int, rules: list[dict[str, Any]],
) -> None:
    table = RULE_TABLES[acl_type]
    conn.execute(f"UPDATE {table} SET sync_status = 'pending_delete' WHERE acl_id = ? AND sync_status != 'pending_delete'", (acl_id,))
    for rule in rules:
        insert_rule(conn, acl_type, acl_id, rule)


def mark_rules_deleted(conn: sqlite3.Connection, acl_type: str, acl_id: int) -> None:
    conn.execute(
        f"UPDATE {RULE_TABLES[acl_type]} SET sync_status = 'pending_delete' WHERE acl_id = ? AND sync_status != 'pending_delete'", (acl_id,),
    )
