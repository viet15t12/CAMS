"""Validate the complete EIGRP editor payload before changing its database state."""

from __future__ import annotations

from typing import Any

from ..common import text
from ..ospf.validation import _integer, _ipv4, _row, _validate_unique


def validate_eigrp_processes(db: Any, values: list[Any]) -> None:
    numbers: set[object] = set()
    database_ids: set[object] = set()
    shared_keys: dict[tuple[str, int], dict[str, Any]] = {}
    for index, value in enumerate(values, 1):
        prefix = f"EIGRP process #{index}"
        process = _row(db, value, prefix)
        number = _integer(process.get("as_number"), f"{prefix} AS Number", minimum=1, maximum=65535)
        _validate_unique(number, numbers, f"EIGRP AS Number {number}")
        database_id = _integer(process.get("eigrp_id"), f"{prefix} database ID", minimum=0, optional=True)
        if database_id:
            _validate_unique(database_id, database_ids, f"EIGRP database ID {database_id}")
        if text(process.get("router_id")):
            _ipv4(process["router_id"], f"{prefix} Router ID")
        for field in ("timers_active_time", "distance_internal", "distance_external", "variance", "maximum_paths"):
            _integer(process.get(field), f"{prefix} {field}", minimum=0,
                     maximum=255 if field.startswith("distance_") else None, optional=True)
        weights = text(process.get("metric_weights")) or "0 1 0 1 0 0"
        parts = weights.split()
        if len(parts) != 6 or parts[0] != "0":
            raise ValueError(f"{prefix} metric weights require six integers starting with 0")
        for part in parts:
            _integer(part, f"{prefix} metric weight", minimum=0, maximum=255)

        for field in ("networks", "interface_settings", "passive_interfaces", "distribute_lists",
                      "offset_lists", "redistribute", "key_chains"):
            seen: set[object] = set()
            for row_index, row_value in enumerate(db._as_list(process.get(field)), 1):
                label = f"{prefix} {field} #{row_index}"
                row = _row(db, row_value, label)
                if field == "networks":
                    network = _ipv4(row.get("network"), label)
                    wildcard = text(row.get("wildcard"))
                    if wildcard:
                        _ipv4(wildcard, label + " wildcard")
                    key = (network, wildcard)
                elif field in {"interface_settings", "passive_interfaces"}:
                    key = text(row.get("interface_name"))
                    if not key:
                        raise ValueError(label + " requires an interface")
                    if field == "passive_interfaces":
                        if (text(row.get("mode")) or "passive") not in {"passive", "no-passive"}:
                            raise ValueError(label + " has an invalid passive mode")
                    else:
                        for numeric in ("bandwidth", "delay", "hello_interval", "hold_time", "bandwidth_percent",
                                        "bfd_tx", "bfd_rx", "bfd_multiplier"):
                            _integer(row.get(numeric), label + " " + numeric, minimum=0, optional=True)
                        for address in ("summary_ip", "summary_mask"):
                            if text(row.get(address)):
                                _ipv4(row[address], label + " " + address)
                        if bool(text(row.get("summary_ip"))) != bool(text(row.get("summary_mask"))):
                            raise ValueError(label + " requires both summary IP and mask")
                elif field in {"distribute_lists", "offset_lists"}:
                    name = text(row.get("list_name"))
                    direction = text(row.get("direction")) or "in"
                    if not name or direction not in {"in", "out"}:
                        raise ValueError(label + " requires a list and an in/out direction")
                    key = (name, direction, text(row.get("interface_name")))
                    if field == "offset_lists":
                        _integer(row.get("value"), label + " offset", minimum=1)
                elif field == "redistribute":
                    key = text(row.get("protocol"))
                    if key not in {"static", "connected", "ospf", "bgp", "rip", "isis", "eigrp"}:
                        raise ValueError(label + " has an invalid redistribution protocol")
                    for numeric in ("metric_bw", "metric_delay", "metric_reliability", "metric_load", "metric_mtu"):
                        _integer(row.get(numeric), label + " " + numeric, minimum=0, optional=True)
                else:
                    chain = text(row.get("chain_name"))
                    key_id = _integer(row.get("key_id"), label + " key ID", minimum=0)
                    if not chain or not text(row.get("key_string")):
                        raise ValueError(label + " requires a chain name and key string")
                    key = (chain, key_id)
                    content = {name: text(row.get(name)) for name in
                               ("chain_name", "key_string", "accept_lifetime", "send_lifetime")}
                    if key in shared_keys and shared_keys[key] != content:
                        raise ValueError(f"Conflicting EIGRP key chain {chain} key {key_id}")
                    shared_keys[key] = content
                _validate_unique(key, seen, label)
