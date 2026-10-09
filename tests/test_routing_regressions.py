from __future__ import annotations

import copy
import io
import json
import sqlite3
import tempfile
import unittest
from contextlib import closing, redirect_stdout
from pathlib import Path
from unittest.mock import patch

from core.database.conversion import ConversionMixin
from features.devices.sync import sync_device_state
from features.routing import dispatcher
from features.routing.eigrp import get_eigrp_routing, save_eigrp_routing
from features.routing.ospf import get_ospf_routing, save_ospf_routing
from features.routing.static_route import get_static_routing, save_static_routes, save_static_routing
from features.routing.static_default import get_default_routes, save_default_routes
from features.routing.worker import render_routing_config
from features.routing.view_push import RoutingViewPushController
from scripts.build_databases import combine_sql


class _Database(ConversionMixin):
    def __init__(self, path):
        self.path, self.error = path, ""

    def _connect(self):
        conn = sqlite3.connect(self.path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        return conn

    def _set_last_routing_error(self, message):
        self.error = message


CONFIG = """hostname R1
key chain AUTH
 key 1
  key-string test-secret
!
interface GigabitEthernet0/0
 ip address 10.0.0.1 255.255.255.0
 bandwidth 10000
 delay 10
 ip ospf 10 area 0
 ip ospf priority 0
 ip ospf cost 20
 ip ospf authentication
 ip ospf authentication-key plain-test
 ip hello-interval eigrp 100 5
 ip hold-time eigrp 100 15
 no ip split-horizon eigrp 100
 ip authentication key-chain eigrp 100 AUTH
!
router ospf 10
 router-id 1.1.1.1
 network 10.0.0.0 0.0.0.255 area 0
!
router eigrp 100
 eigrp router-id 2.2.2.2
 network 10.0.0.0 0.0.0.255
 distribute-list FILTER in GigabitEthernet0/0
 offset-list 1 out 10 GigabitEthernet0/0
!
ip route 198.51.100.0 255.255.255.0 10.0.0.2
ip route 0.0.0.0 0.0.0.0 10.0.0.2
end
"""


class RoutingRegressionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "device.db"
        self.db = _Database(self.path)
        root = Path(__file__).resolve().parents[1]
        with closing(self.db._connect()) as conn, conn:
            conn.executescript(combine_sql(root / "infrastructure/database/schemas/device_network"))
            conn.execute("INSERT INTO t01_devices(host, role) VALUES ('r1', 'rou')")
        self.patchers = [patch.object(dispatcher, "DB_PATH", str(self.path)),
                         patch.object(dispatcher, "TMP_DIR", self.temp.name),
                         patch.object(dispatcher, "ROUTE_OUTPUT", str(Path(self.temp.name) / "result.json"))]
        for patcher in self.patchers:
            patcher.start()
            self.addCleanup(patcher.stop)

    def tasks(self, module="all"):
        with redirect_stdout(io.StringIO()):
            return dispatcher.routing_dispatcher("r1", module, dry_run=True) or []

    def snapshot(self):
        with closing(self.db._connect()) as conn:
            return "\n".join(conn.iterdump())

    def load_eigrp(self):
        return get_eigrp_routing(self.db, "r1")["processes"]

    def commands(self, tasks):
        return [line.strip() for task in tasks for config in task["config"]
                for line in render_routing_config("cisco_ios", task["sub_type"], config, task["action"]).splitlines()
                if line.strip()]

    def test_running_config_imports_all_four_modules_and_ospf_interface_without_queued_push(self):
        summary = sync_device_state(self.path, "r1", CONFIG)
        self.assertEqual(summary["ospf_processes"], 1)
        self.assertEqual(summary["eigrp_processes"], 1)
        process = get_ospf_routing(self.db, "r1")["processes"][0]
        self.assertEqual(process["action_Cfg"], "0000")
        interface = process["interface_settings"][0]
        self.assertEqual(interface["priority"], 0)
        self.assertEqual(interface["auth_key"], "plain-test")
        self.assertEqual(interface["sync_status"], "synchronized")
        eigrp = self.load_eigrp()[0]
        self.assertEqual(eigrp["action_Cfg"], "0000000")
        self.assertEqual(eigrp["interface_settings"][0]["hello_interval"], 5)
        self.assertEqual(eigrp["interface_settings"][0]["split_horizon"], 0)
        self.assertEqual(eigrp["key_chains"][0]["chain_name"], "AUTH")
        self.assertEqual(len(eigrp["distribute_lists"]), 1)
        self.assertEqual(len(eigrp["offset_lists"]), 1)
        self.assertEqual(len(get_static_routing(self.db, "r1")["routes"]), 1)
        self.assertEqual(len(get_default_routes(self.db, "r1")["routes"]), 1)
        self.assertEqual(self.tasks(), [])

    def test_unchanged_save_is_noop_for_every_routing_module(self):
        sync_device_state(self.path, "r1", CONFIG)
        before = self.snapshot()
        self.assertTrue(save_eigrp_routing(self.db, "r1", self.load_eigrp()), self.db.error)
        self.assertTrue(save_ospf_routing(self.db, "r1", get_ospf_routing(self.db, "r1")["processes"]))
        self.assertTrue(save_static_routes(self.db, "r1", get_static_routing(self.db, "r1")["routes"]))
        self.assertTrue(save_default_routes(self.db, "r1", get_default_routes(self.db, "r1")["routes"]))
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(self.tasks(), [])

    def test_eigrp_child_edit_does_not_remove_or_resend_unchanged_process_options(self):
        sync_device_state(self.path, "r1", CONFIG)
        processes = self.load_eigrp()
        processes[0]["networks"].append({"network": "192.0.2.0", "wildcard": "0.0.0.255"})
        self.assertTrue(save_eigrp_routing(self.db, "r1", processes), self.db.error)
        commands = self.commands(self.tasks("eigrp"))
        self.assertIn("network 192.0.2.0 0.0.0.255", commands)
        self.assertEqual(commands, ["router eigrp 100", "network 192.0.2.0 0.0.0.255", "exit"])

    def test_eigrp_missing_or_stale_database_id_resolves_the_existing_as(self):
        sync_device_state(self.path, "r1", CONFIG)
        before = self.snapshot()
        for database_id in (None, 999999):
            processes = self.load_eigrp()
            processes[0]["eigrp_id"] = database_id
            self.assertTrue(save_eigrp_routing(self.db, "r1", processes), self.db.error)
            self.assertEqual(self.snapshot(), before)
            self.assertEqual(self.tasks("eigrp"), [])

    def test_eigrp_process_teardown_renders_pending_global_key_deletions(self):
        sync_device_state(self.path, "r1", CONFIG.replace(" key 1", " key 0"))
        self.assertTrue(save_eigrp_routing(self.db, "r1", []), self.db.error)
        tasks = self.tasks("eigrp")
        self.assertEqual(len(tasks), 1)
        commands = self.commands(tasks)
        self.assertIn("no router eigrp 100", commands)
        self.assertIn("no key 0", commands)
        self.assertNotIn("no key chain AUTH", commands)
        self.assertTrue(tasks[0]["key_ids_del"])

    def test_preview_redacts_the_entire_key_string(self):
        commands = ["key-string secret with spaces", "key-string 7 encrypted-secret"]
        self.assertEqual(RoutingViewPushController._redact_secrets(commands),
                         ["key-string <redacted>", "key-string <redacted>"])

    def test_eigrp_option_mask_accumulates_multiple_unsent_edits(self):
        sync_device_state(self.path, "r1", CONFIG)
        processes = self.load_eigrp()
        processes[0]["router_id"] = "3.3.3.3"
        self.assertTrue(save_eigrp_routing(self.db, "r1", processes))
        processes = self.load_eigrp()
        self.assertEqual(processes[0]["action_Cfg"], "1000000")
        processes[0]["variance"] = 2
        self.assertTrue(save_eigrp_routing(self.db, "r1", processes))
        self.assertEqual(self.load_eigrp()[0]["action_Cfg"], "1000010")
        commands = self.commands(self.tasks("eigrp"))
        self.assertIn("eigrp router-id 3.3.3.3", commands)
        self.assertIn("variance 2", commands)
        self.assertNotIn("no maximum-paths", commands)
        self.assertNotIn("no passive-interface default", commands)

    def test_ospf_option_mask_accumulates_multiple_unsent_edits(self):
        sync_device_state(self.path, "r1", CONFIG)
        processes = get_ospf_routing(self.db, "r1")["processes"]
        processes[0]["router_id"] = "3.3.3.3"
        self.assertTrue(save_ospf_routing(self.db, "r1", processes))
        processes = get_ospf_routing(self.db, "r1")["processes"]
        self.assertEqual(processes[0]["action_Cfg"], "1000")
        processes[0]["reference_bandwidth"] = 1000
        self.assertTrue(save_ospf_routing(self.db, "r1", processes))
        self.assertEqual(get_ospf_routing(self.db, "r1")["processes"][0]["action_Cfg"], "1100")
        commands = self.commands(self.tasks("ospf"))
        self.assertIn("router-id 3.3.3.3", commands)
        self.assertIn("auto-cost reference-bandwidth 1000", commands)

    def test_rejected_cli_output_never_marks_routing_rows_synchronized(self):
        class Connection:
            def send_config_set(self, _commands, **_kwargs):
                return "% Invalid input detected at '^' marker."
        class Connector:
            host, device_type, connection = "r1", "cisco_ios", Connection()
        sync_device_state(self.path, "r1", CONFIG)
        processes = self.load_eigrp()
        processes[0]["variance"] = 2
        self.assertTrue(save_eigrp_routing(self.db, "r1", processes))
        before = self.snapshot()
        with redirect_stdout(io.StringIO()):
            dispatcher.routing_dispatcher("r1", "eigrp", session_provider=lambda _host: Connector())
        self.assertEqual(self.snapshot(), before)
        report = json.loads((Path(self.temp.name) / "routing_log_eigrp_r1.json").read_text())
        self.assertEqual(report[0]["status"], "FAIL")
        self.assertIn("rejected routing commands", report[0]["log"])

    def test_eigrp_explicit_clear_emits_only_selected_no_command(self):
        sync_device_state(self.path, "r1", CONFIG)
        processes = self.load_eigrp()
        processes[0]["router_id"] = ""
        self.assertTrue(save_eigrp_routing(self.db, "r1", processes))
        commands = self.commands(self.tasks("eigrp"))
        self.assertIn("no eigrp router-id", commands)
        self.assertNotIn("no timers active-time", commands)

    def test_eigrp_filter_and_key_changes_reach_preview_and_success_acknowledgement(self):
        sync_device_state(self.path, "r1", CONFIG)
        processes = self.load_eigrp()
        processes[0]["distribute_lists"].append({"list_name": "OUT", "direction": "out"})
        processes[0]["offset_lists"].append({"list_name": "2", "direction": "in", "value": 20})
        processes[0]["key_chains"][0]["key_string"] = "updated-test-secret"
        self.assertTrue(save_eigrp_routing(self.db, "r1", processes), self.db.error)
        commands = self.commands(self.tasks("eigrp"))
        self.assertIn("distribute-list OUT out", commands)
        self.assertIn("offset-list 2 in 20", commands)
        self.assertIn("key-string updated-test-secret", commands)
        self.assertIn("key-string <redacted>", RoutingViewPushController._redact_secrets(commands))
        def worker(tasks, _database, output, **_kwargs):
            Path(output).write_text(json.dumps([{"target": "r1", "status": "success"}]))
        with patch.object(dispatcher, "run_routing_config", side_effect=worker), redirect_stdout(io.StringIO()):
            dispatcher.routing_dispatcher("r1", "eigrp")
        self.assertEqual(self.tasks("eigrp"), [])
        self.assertEqual(self.load_eigrp()[0]["action_Cfg"], "0000000")

    def test_failed_eigrp_push_preserves_pending_state(self):
        sync_device_state(self.path, "r1", CONFIG)
        processes = self.load_eigrp()
        processes[0]["offset_lists"].append({"list_name": "2", "direction": "in", "value": 20})
        self.assertTrue(save_eigrp_routing(self.db, "r1", processes))
        before = self.snapshot()
        def worker(tasks, _database, output, **_kwargs):
            Path(output).write_text(json.dumps([{"target": "r1", "status": "failed"}]))
        with patch.object(dispatcher, "run_routing_config", side_effect=worker), redirect_stdout(io.StringIO()):
            dispatcher.routing_dispatcher("r1", "eigrp")
        self.assertEqual(self.snapshot(), before)

    def test_invalid_eigrp_payloads_are_atomic(self):
        sync_device_state(self.path, "r1", CONFIG)
        original = self.load_eigrp()
        before = self.snapshot()
        for change in ({"as_number": "100oops"}, {"as_number": 0}, {"router_id": "invalid"},
                       {"variance": "2.5"}, {"networks": [object()]},
                       {"offset_lists": [{"list_name": "1", "direction": "bad", "value": 1}]}):
            with self.subTest(change=change):
                payload = copy.deepcopy(original)
                payload[0].update(change)
                self.assertFalse(save_eigrp_routing(self.db, "r1", payload))
                self.assertTrue(self.db.error)
                self.assertEqual(self.snapshot(), before)
        self.assertFalse(save_eigrp_routing(self.db, "r1", original + original))
        self.assertEqual(self.snapshot(), before)

    def test_combined_static_save_rolls_back_default_when_route_is_invalid(self):
        sync_device_state(self.path, "r1", CONFIG)
        before = self.snapshot()
        for route in ({"network": "invalid", "mask": "255.255.255.0", "nexthop": "10.0.0.2"},
                      {"network": "192.0.2.0", "mask": "255.0.255.0", "nexthop": "10.0.0.2"},
                      {"network": "192.0.2.0", "mask": "255.255.255.0", "nexthop": "10.0.0.2", "ad": 0}):
            with self.subTest(route=route):
                self.assertFalse(save_static_routing(self.db, "r1", "10.0.0.3", [route]))
                self.assertEqual(self.snapshot(), before)

    def test_blank_default_row_is_rejected_without_removing_existing_routes(self):
        sync_device_state(self.path, "r1", CONFIG)
        before = self.snapshot()
        self.assertFalse(save_default_routes(self.db, "r1", [{"nexthop": ""}]))
        self.assertEqual(self.snapshot(), before)


if __name__ == "__main__":
    unittest.main()
