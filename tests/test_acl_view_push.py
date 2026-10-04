from __future__ import annotations

import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from typing import Any

from features.acl import get_acls, save_acl
from features.acl.collector import collect_acl_tasks
from features.acl.dispatcher import apply_acl_results
from features.acl.worker import render_acl_payload
from core.view_push import AclViewPushController


APP_DIR = Path(__file__).resolve().parents[1]


class _Database:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.db_path = path

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        return connection

    def _routing_device_context(self, _host: str) -> dict[str, str]:
        return {"template_folder": "cisco_ios", "platform": "cisco_ios"}


class AclViewPushTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp.name) / "device_network.db"
        schemas = APP_DIR / "infrastructure" / "database" / "schemas" / "device_network"
        with closing(sqlite3.connect(self.db_path)) as connection:
            connection.execute("PRAGMA foreign_keys = ON")
            for name in ("01_core_devices.sql", "02_interface_router_l3.sql", "05_security_nat.sql"):
                connection.executescript((schemas / name).read_text(encoding="utf-8"))
            connection.execute(
                "INSERT INTO t01_devices(host, os, method, dev) VALUES ('10.0.0.1', 'cisco', 'SSH', 1)"
            )
            connection.execute(
                "INSERT INTO t02_interface_name(host, interface_name) VALUES ('10.0.0.1', 'GigabitEthernet0/0')"
            )
            connection.commit()
        self.db = _Database(self.db_path)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _save(self, acl_id: int, sequence: int, source: str) -> None:
        with closing(self.db._connect()) as connection:
            iface_id = int(connection.execute("SELECT iface_id FROM t02_interface_name").fetchone()[0])
        self.assertTrue(save_acl(self.db, {
            "acl_id": acl_id,
            "host": "10.0.0.1",
            "acl_name": "EDGE_IN",
            "acl_type": "standard",
            "description": "edge filter",
            "rules": [{
                "sequence": sequence,
                "action": "permit",
                "source": source,
                "wildcard": "0.0.0.255",
            }],
            "bindings": [{"iface_id": iface_id, "direction": "in"}],
        }))

    def test_collect_render_and_apply_new_acl(self) -> None:
        self._save(0, 10, "192.168.1.0")
        tasks = collect_acl_tasks("10.0.0.1", str(self.db_path))
        self.assertEqual(len(tasks), 1)
        commands = render_acl_payload(tasks[0])
        self.assertIn("ip access-list standard EDGE_IN", commands)
        self.assertIn("10 permit 192.168.1.0 0.0.0.255 log", commands)
        self.assertIn("ip access-group EDGE_IN in", commands)

        report = apply_acl_results(
            tasks,
            [{"target": "10.0.0.1", "status": "success", "message": "simulated"}],
            str(self.db_path),
        )
        self.assertEqual(report[0]["status"], "SUCCESS")
        self.assertEqual(collect_acl_tasks("10.0.0.1", str(self.db_path)), [])

    def test_controller_preview_uses_its_active_workspace_database(self) -> None:
        self._save(0, 10, "192.168.1.0")
        result = AclViewPushController(self.db, session_registry=object()).preview(
            "10.0.0.1", "all"
        )
        self.assertTrue(result["ok"], result["message"])
        self.assertIn("ip access-list standard EDGE_IN", result["commands"])

    def test_preview_blocks_cross_host_interface_binding(self) -> None:
        self._save(0, 10, "192.168.1.0")
        with closing(self.db._connect()) as connection:
            connection.execute(
                "INSERT INTO t01_devices(host, os, method, dev) "
                "VALUES ('10.0.0.2', 'cisco', 'SSH', 1)"
            )
            foreign_iface = int(connection.execute(
                "INSERT INTO t02_interface_name(host, interface_name) "
                "VALUES ('10.0.0.2', 'GigabitEthernet9/9') RETURNING iface_id"
            ).fetchone()[0])
            acl_id = int(connection.execute(
                "SELECT Acl_id FROM t05_ACL_DB WHERE host='10.0.0.1'"
            ).fetchone()[0])
            connection.execute(
                "INSERT INTO t05_router_iface_acl(iface_id, acl_id, direction) "
                "VALUES (?, ?, 'out')",
                (foreign_iface, acl_id),
            )
            connection.commit()

        result = AclViewPushController(self.db, session_registry=object()).preview(
            "10.0.0.1", "all"
        )
        self.assertFalse(result["ok"])
        self.assertEqual(result["commands"], "")
        self.assertIn("references an interface owned by 10.0.0.2", result["message"])

    def test_edit_renders_rule_replacement(self) -> None:
        self._save(0, 10, "192.168.1.0")
        first_tasks = collect_acl_tasks("10.0.0.1", str(self.db_path))
        apply_acl_results(
            first_tasks,
            [{"target": "10.0.0.1", "status": "success", "message": "simulated"}],
            str(self.db_path),
        )
        acl_id = int(get_acls(self.db, "10.0.0.1", "standard")[0]["Acl_id"])
        self._save(acl_id, 20, "198.51.100.0")

        tasks = collect_acl_tasks("10.0.0.1", str(self.db_path))
        commands = render_acl_payload(tasks[0])
        self.assertIn("no 10", commands)
        self.assertIn("20 permit 198.51.100.0 0.0.0.255 log", commands)

    def test_retried_edits_render_each_deleted_sequence_once(self) -> None:
        self._save(0, 10, "192.168.1.0")
        acl_id = int(get_acls(self.db, "10.0.0.1", "standard")[0]["Acl_id"])
        for source in ("192.168.2.0", "192.168.3.0", "192.168.4.0"):
            self._save(acl_id, 10, source)

        tasks = collect_acl_tasks("10.0.0.1", str(self.db_path))
        commands = render_acl_payload(tasks[0])
        self.assertEqual(commands.count("no 10"), 1)
        self.assertIn("10 permit 192.168.4.0 0.0.0.255 log", commands)
        self.assertGreater(len(tasks[0]["tracking"]["rules"]["standard"]["del"]), 1)

    def test_legacy_icmp_eq_type_renders_valid_ios_syntax(self) -> None:
        self.assertTrue(save_acl(self.db, {
            "host": "10.0.0.1",
            "acl_name": "ICMP_IN",
            "acl_type": "extended",
            "rules": [{
                "sequence": 30,
                "action": "permit",
                "protocol": "icmp",
                "source": "192.168.10.0",
                "src_wildcard": "0.0.0.255",
                "destination": "192.168.100.0",
                "dst_wildcard": "0.0.0.255",
                "dst_port": "echo",
            }],
        }))
        with closing(self.db._connect()) as connection:
            connection.execute(
                "UPDATE t05_extended_acl_rules SET dst_port='eq echo'"
            )
            connection.commit()

        tasks = collect_acl_tasks("10.0.0.1", str(self.db_path))
        commands = render_acl_payload(tasks[0])
        rendered_rule = next(command for command in commands if command.startswith("30 permit"))
        self.assertTrue(rendered_rule.endswith(" echo log"), rendered_rule)
        self.assertNotIn("eq echo", rendered_rule)

    def test_acl_automatic_logging_rules(self) -> None:
        # Standard ACL
        payload_std = {
            "acl_name": "TEST_STD",
            "acl_type": "standard",
            "rules_add": [{"seq": 10, "action": "deny", "src": "any", "src_mask": None}],
            "rules_del": [],
        }
        cmds_std = render_acl_payload(payload_std)
        self.assertIn("10 deny any log", cmds_std)

        # Extended ACL
        payload_ext = {
            "acl_name": "TEST_EXT",
            "acl_type": "extended",
            "rules_add": [{
                "seq": 20, "action": "permit", "protocol": "tcp",
                "src": "any", "src_mask": None, "src_port": None,
                "dst": "host 10.1.1.1", "dst_mask": None, "dst_port": "eq 80",
            }],
            "rules_del": [],
        }
        cmds_ext = render_acl_payload(payload_ext)
        self.assertIn("20 permit tcp any host 10.1.1.1 eq 80 log", cmds_ext)

        # Dynamic ACL
        payload_dyn = {
            "acl_name": "TEST_DYN",
            "acl_type": "dynamic",
            "rules_add": [{
                "seq": 30, "action": "permit", "protocol": "ip",
                "src": "any", "src_mask": None, "src_port": None,
                "dst": "any", "dst_mask": None, "dst_port": None,
                "dyn_name": "DYN_USER", "timeout": 15,
            }],
            "rules_del": [],
        }
        cmds_dyn = render_acl_payload(payload_dyn)
        self.assertIn("30 dynamic DYN_USER timeout 15 permit ip any any log", cmds_dyn)

        # Reflexive ACL (evaluate rule must NOT have log, reflect rule must NOT have log)
        payload_refl = {
            "acl_name": "TEST_REFL",
            "acl_type": "reflexive",
            "rules_add": [
                {"seq": 10, "action": "evaluate", "reflect_name": "REFL_TRACK"},
                {
                    "seq": 20, "action": "permit", "protocol": "tcp",
                    "src": "any", "src_mask": None, "src_port": None,
                    "dst": "any", "dst_mask": None, "dst_port": None,
                    "reflect_name": "REFL_TRACK", "timeout": 60,
                },
            ],
            "rules_del": [],
        }
        cmds_refl = render_acl_payload(payload_refl)
        self.assertIn("10 evaluate REFL_TRACK", cmds_refl)
        self.assertNotIn("10 evaluate REFL_TRACK log", cmds_refl)
        self.assertIn("20 permit tcp any any reflect REFL_TRACK timeout 60", cmds_refl)
        self.assertNotIn("timeout 60 log", cmds_refl)

