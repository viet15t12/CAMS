from __future__ import annotations

import sqlite3
from contextlib import closing
from typing import Any

from ..common import log_db_error, normalize_host
from .common import normalize_process, process_action_cfg
from .save_key_chains import sync_eigrp_key_chains
from .validation import validate_eigrp_processes
from .save_processes import (
    CHILD_TABLES,
    archive_eigrp_process,
    insert_eigrp_process,
    load_process_for_compare,
    sync_eigrp_child_table,
    update_eigrp_process_row,
)


def save_eigrp_routing(db: Any, host: str, payload: Any) -> bool:
    host = normalize_host(host)
    if not host:
        return False

    try:
        process_values = db._as_list(payload)
        validate_eigrp_processes(db, process_values)
        with closing(db._connect()) as conn:
            existing_processes = conn.execute(
                """
                SELECT eigrp_id, as_number
                FROM t04_eigrp_processes
                WHERE host = ? AND sync_status != 'pending_delete';
                """,
                (host,),
            ).fetchall()
            existing_ids = {row["eigrp_id"] for row in existing_processes}
            existing_by_as = {row["as_number"]: row["eigrp_id"] for row in existing_processes}
            submitted_ids: set[int] = set()

            for process_value in process_values:
                process = db._as_dict(process_value)
                eigrp_id = db._int_or_none(process.get("eigrp_id")) or 0
                as_number = db._int_or_none(process.get("as_number"))
                if as_number is None:
                    raise ValueError("EIGRP as_number is required")

                # A collected snapshot can replace database IDs. Resolve the
                # process by its device-scoped AS instead of recreating it.
                if eigrp_id not in existing_ids:
                    eigrp_id = existing_by_as.get(as_number, 0)
                if eigrp_id and eigrp_id in submitted_ids:
                    raise ValueError("The same EIGRP process was submitted more than once")

                if eigrp_id > 0 and eigrp_id in existing_ids:
                    submitted_ids.add(eigrp_id)
                    current = load_process_for_compare(conn, db, eigrp_id)
                    if current is None:
                        insert_eigrp_process(conn, db, host, process)
                        continue

                    current_as_number = db._int_or_none(current.get("as_number"))
                    if current_as_number != as_number:
                        archive_eigrp_process(conn, eigrp_id)
                        insert_eigrp_process(conn, db, host, process)
                        continue

                    if normalize_process(db, current) != normalize_process(db, process):
                        child_fields = {"networks", "interface_settings", "passive_interfaces",
                                        "distribute_lists", "offset_lists", "redistribute"}
                        before = {key: value for key, value in normalize_process(db, current).items()
                                  if key not in child_fields}
                        after = {key: value for key, value in normalize_process(db, process).items()
                                 if key not in child_fields}
                        if before != after:
                            updated = dict(process, action_Cfg=process_action_cfg(db, current, process))
                            update_eigrp_process_row(conn, db, eigrp_id, updated)
                        for table in CHILD_TABLES:
                            sync_eigrp_child_table(conn, db, eigrp_id, process, table, replace_all=False)
                    continue

                insert_eigrp_process(conn, db, host, process)

            for deleted_id in existing_ids - submitted_ids:
                archive_eigrp_process(conn, deleted_id)

            sync_eigrp_key_chains(conn, db, host, payload)
            conn.commit()
        if hasattr(db, "_set_last_routing_error"):
            db._set_last_routing_error("")
        return True
    except (sqlite3.Error, OverflowError, TypeError, ValueError) as exc:
        if hasattr(db, "_set_last_routing_error"):
            db._set_last_routing_error(str(exc))
        log_db_error("saveEigrpRouting", exc)
        return False
