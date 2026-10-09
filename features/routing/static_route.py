from __future__ import annotations

import sqlite3
from contextlib import closing
from ipaddress import IPv4Address, IPv4Network
from typing import Any

from .common import log_db_error, normalize_host
from .ospf.validation import _integer
from .static_default import default_route_payload, fetch_default_route, fetch_default_routes, replace_default_route


def get_static_routing(db: Any, host: str) -> dict[str, Any]:
    host = normalize_host(host)
    if not host:
        return {"ok": False, "message": "Host is empty", "default_route": "", "routes": []}

    try:
        with closing(db._connect()) as conn:
            default_row = fetch_default_route(conn, host)
            default_rows = fetch_default_routes(conn, host)
            route_rows = conn.execute(
                """
                SELECT id, network, subnet_mask, next_hop, ad, sync_status
                FROM t04_static_routes
                WHERE host = ? AND sync_status != 'pending_delete'
                ORDER BY id ASC;
                """,
                (host,),
            ).fetchall()

        routes = [
            {
                "id": row["id"],
                "network": row["network"],
                "mask": row["subnet_mask"],
                "nexthop": row["next_hop"],
                "ad": row["ad"],
                "sync_status": row["sync_status"],
            }
            for row in route_rows
        ]
        return {
            "ok": True,
            "message": "Loaded static/default routes",
            **default_route_payload(default_row),
            "default_routes": [
                {"id": row["id"], "nexthop": row["next_hop_ip"], "sync_status": row["sync_status"]}
                for row in default_rows
            ],
            "routes": routes,
        }
    except sqlite3.Error as exc:
        log_db_error("getStaticRouting", exc)
        return {"ok": False, "message": str(exc), "default_route": "", "routes": []}


def save_static_routing(db: Any, host: str, default_value: str, routes: Any) -> bool:
    """Backward-compatible combined save used by older callers."""
    host = normalize_host(host)
    if not host:
        return False
    try:
        default_text = str(default_value or "").strip()
        if default_text:
            default_text = str(IPv4Address(default_text))
        with closing(db._connect()) as conn, conn:
            replace_default_route(conn, host, default_text)
            _save_static_routes(conn, db, host, routes)
    except (sqlite3.Error, OverflowError, TypeError, ValueError) as exc:
        log_db_error("saveStaticRouting", exc)
        if hasattr(db, "_set_last_routing_error"):
            db._set_last_routing_error(str(exc))
        return False
    if hasattr(db, "_set_last_routing_error"):
        db._set_last_routing_error("")
    return True


def save_static_routes(db: Any, host: str, routes: Any) -> bool:
    """Save static routes without touching the independently managed defaults."""
    host = normalize_host(host)
    if not host:
        return False
    try:
        with closing(db._connect()) as conn, conn:
            _save_static_routes(conn, db, host, routes)
        if hasattr(db, "_set_last_routing_error"):
            db._set_last_routing_error("")
        return True
    except (sqlite3.Error, OverflowError, TypeError, ValueError) as exc:
        log_db_error("saveStaticRoutes", exc)
        if hasattr(db, "_set_last_routing_error"):
            db._set_last_routing_error(str(exc))
        return False


def _save_static_routes(conn: sqlite3.Connection, db: Any, host: str, routes: Any) -> None:
    # Validate all rows before reconciliation; a failed combined save
    # rolls back both the default route and static routes.
    submitted = []
    identities = set()
    ids = set()
    for value in db._as_list(routes):
        route = db._as_dict(value)
        route_id = _integer(route.get("id", route.get("routeId")), "Static route ID", minimum=0, optional=True) or 0
        if route_id and route_id in ids:
            raise ValueError("Duplicate static-route ID")
        ids.add(route_id)
        network = str(route.get("network") or "").strip()
        mask = str(route.get("mask") or "").strip()
        if not network or not mask:
            raise ValueError("Static route must include network, mask, and next-hop")
        subnet = IPv4Network(f"{network}/{mask.lstrip('/')}", strict=True)
        network, mask = str(subnet.network_address), str(subnet.netmask)
        nexthop = str(IPv4Address(str(route.get("nexthop") or "").strip()))
        ad = _integer(route.get("ad"), "Static route AD", minimum=1, maximum=255, optional=True)
        ad = 1 if ad is None else ad
        identity = (network, mask, nexthop, ad)
        if identity in identities:
            raise ValueError("Duplicate static route")
        identities.add(identity)
        submitted.append((route_id, identity))
    existing_ids = {
        row["id"] for row in conn.execute(
            "SELECT id FROM t04_static_routes WHERE host=? AND sync_status!='pending_delete'",
            (host,),
        ).fetchall()
    }
    submitted_ids: set[int] = set()
    for route_id, identity in submitted:
        network, mask, nexthop, ad = identity
        if route_id in existing_ids:
            submitted_ids.add(route_id)
            current = conn.execute(
                "SELECT network, subnet_mask, next_hop, ad FROM t04_static_routes WHERE id=? AND host=?",
                (route_id, host),
            ).fetchone()
            if tuple(current) != identity:
                conn.execute("UPDATE t04_static_routes SET sync_status='pending_delete' WHERE id=? AND host=?", (route_id, host))
                conn.execute(
                    "INSERT INTO t04_static_routes(host,network,subnet_mask,next_hop,ad,sync_status) VALUES(?,?,?,?,?,'pending_apply')",
                    (host, network, mask, nexthop, ad),
                )
        else:
            conn.execute(
                "INSERT INTO t04_static_routes(host,network,subnet_mask,next_hop,ad,sync_status) VALUES(?,?,?,?,?,'pending_apply')",
                (host, network, mask, nexthop, ad),
            )
    deleted = existing_ids - submitted_ids
    if deleted:
        placeholders = ",".join("?" for _ in deleted)
        conn.execute(f"UPDATE t04_static_routes SET sync_status='pending_delete' WHERE host=? AND id IN ({placeholders})", (host, *deleted))
