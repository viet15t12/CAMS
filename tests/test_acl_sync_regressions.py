from __future__ import annotations

import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from features.acl import get_acls, save_acl, save_acl_bindings, delete_acl
from features.acl.collector import collect_acl_tasks
from features.acl.dispatcher import apply_acl_results
from features.acl.worker import render_acl_payload, run_acl_config
from features.acl.rules import RULE_TABLES
from features.config_sync import ConfigSyncService
from features.devices.sync import parse_running_config_sections, sync_device_state
from scripts.build_databases import combine_sql


SCREEN_CONFIG = """hostname R1
interface GigabitEthernet0/0
 ip address 192.168.10.1 255.255.255.0
 ip access-group ACL_V10_NO_TELNET_R2 in
 ip access-group ACL_V20_V30_OUT out
!
ip access-list extended ACL_V10_NO_TELNET_R2
 10 deny tcp 192.168.10.0 0.0.0.255 host 192.168.12.2 eq telnet log
 20 permit ip any any log
 30 deny ip any any log
!
ip access-list extended ACL_V20_V30_OUT
 deny tcp 192.168.20.0 0.0.0.255 host 203.162.4.1 eq www log
 deny icmp 192.168.30.0 0.0.0.255 host 203.162.4.1 log
 permit ip any any log
 deny ip any any log
!
end
"""

ALL_CONFIG = SCREEN_CONFIG + """ip access-list standard MGMT
 remark Management sources
 10 permit host 192.0.2.1 log-input
 20 deny any
!
access-list 1 permit 192.0.2.0 0.0.0.255
access-list 100 permit tcp any eq 1024 host 192.0.2.2 range 80 443
ip access-list extended DYNAMIC
 10 permit tcp any host 192.0.2.2 eq telnet
 20 dynamic LOGIN timeout 5 permit ip any any
!
ip access-list extended REFLECT_OUT
 10 permit tcp any any reflect SESSION timeout 60
!
ip access-list extended REFLECT_IN
 10 evaluate SESSION
 20 deny ip any any log
!
mac access-list extended L2_FILTER
 permit host 0011.2233.4455 any 0x0800
 deny any any
!
interface GigabitEthernet0/1
 mac access-group L2_FILTER in
!
"""


class Database:
    def __init__(self, path):
        self.path = path

    def _connect(self):
        conn = sqlite3.connect(self.path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys=ON")
        return conn


class AclSyncRegressionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "device.db"
        self.db = Database(self.path)
        root = Path(__file__).resolve().parents[1]
        with closing(self.db._connect()) as conn, conn:
            conn.executescript(combine_sql(root / "infrastructure/database/schemas/device_network"))
            conn.executemany("INSERT INTO t01_devices(host,role,os,method,dev) VALUES (?,?,'cisco','SSH',0)",
                             [("r1", "rou"), ("r2", "rou"), ("sw1", "sw2")])

    def snapshot(self, host="r1"):
        with closing(self.db._connect()) as conn:
            result = [tuple(row) for row in conn.execute("SELECT * FROM t05_ACL_DB WHERE host=? ORDER BY Acl_id", (host,))]
            for table in (*RULE_TABLES.values(), "t05_router_iface_acl"):
                result.extend(tuple(row) for row in conn.execute(
                    f"SELECT r.* FROM {table} r JOIN t05_ACL_DB a ON a.Acl_id=r.acl_id WHERE a.host=? ORDER BY r.id", (host,)))
            return result

    def payload(self, kind="extended", index=0):
        acl = get_acls(self.db, "r1", kind)[index]
        return {"acl_id": acl["Acl_id"], "host": "r1", "acl_name": acl["acl_name"],
                "acl_type": kind, "description": acl["description"], "rules": acl["rules"],
                "bindings": [{"iface_id": row["iface_id"], "direction": row["direction"]} for row in acl["bindings"]]}

    def test_screenshot_acls_import_rules_bindings_and_no_push_is_queued(self):
        service = ConfigSyncService(self.path, lambda _host: "rou")
        result = service.sync_committed_snapshot("r1", SCREEN_CONFIG, "", {"changed": False})
        self.assertTrue(result["ok"], result)
        self.assertTrue(result["attempted"])
        self.assertEqual(result["summary"]["acls"], 2)
        acls = get_acls(self.db, "r1", "Extended")
        self.assertEqual([len(row["rules"]) for row in acls], [3, 4])
        self.assertEqual(acls[0]["rules"][0]["dst_port"], "eq telnet")
        self.assertEqual(acls[0]["rules"][0]["destination"], "host 192.168.12.2")
        self.assertEqual([row["sequence"] for row in acls[1]["rules"]], [10, 20, 30, 40])
        self.assertEqual(acls[1]["rules"][1]["protocol"], "icmp")
        self.assertEqual(acls[0]["bindings"][0]["direction"], "in")
        self.assertEqual(acls[1]["bindings"][0]["direction"], "out")
        self.assertTrue(all(row["sync_status"] == "synchronized" for row in acls))
        self.assertEqual([row["action_Cfg"] for row in acls], [0, 2])
        self.assertEqual(collect_acl_tasks("r1", str(self.path)), [])

    def test_all_five_types_numbered_acl_and_terminal_noise(self):
        parsed = parse_running_config_sections("\x1b[0m" + ALL_CONFIG.replace("\n", "\r\n"))
        self.assertEqual(parsed.unsupported_acls, [])
        self.assertEqual(len(parsed.acls), 9)
        sync_device_state(self.path, "r1", ALL_CONFIG)
        self.assertEqual(len(get_acls(self.db, "r1", "standard")), 2)
        dynamic = get_acls(self.db, "r1", "dynamic")[0]
        self.assertEqual(dynamic["rules"][1]["timeout_seconds"], 300)
        reflexive = get_acls(self.db, "r1", "reflexive")
        self.assertEqual(len(reflexive), 2)
        self.assertEqual(reflexive[1]["rules"][0]["protocol"], "evaluate")
        mac = get_acls(self.db, "r1", "mac")[0]
        self.assertEqual(mac["rules"][0]["src_mask"], "0000.0000.0000")
        self.assertEqual(mac["bindings"][0]["interface_name"], "GigabitEthernet0/1")
        self.assertEqual(collect_acl_tasks("r1", str(self.path)), [])

    def test_repeat_import_and_unchanged_save_preserve_ids_and_sync_state(self):
        sync_device_state(self.path, "r1", ALL_CONFIG)
        before = self.snapshot()
        sync_device_state(self.path, "r1", ALL_CONFIG)
        self.assertEqual(self.snapshot(), before)
        for kind in RULE_TABLES:
            for index, _acl in enumerate(get_acls(self.db, "r1", kind)):
                self.assertTrue(save_acl(self.db, self.payload(kind, index)))
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(collect_acl_tasks("r1", str(self.path)), [])

    def test_changed_and_absent_observations_do_not_delete_on_device_or_touch_other_host(self):
        for host in ("r1", "r2"):
            sync_device_state(self.path, host, SCREEN_CONFIG)
        before = self.snapshot("r2")
        ids = [row["Acl_id"] for row in get_acls(self.db, "r1", "extended")]
        changed = SCREEN_CONFIG.replace("eq telnet", "eq ssh").replace(" ip access-group ACL_V20_V30_OUT out\n", "")
        sync_device_state(self.path, "r1", changed)
        self.assertEqual([row["Acl_id"] for row in get_acls(self.db, "r1", "extended")], ids)
        self.assertEqual(get_acls(self.db, "r1", "extended")[1]["bindings"], [])
        sync_device_state(self.path, "r1", "hostname R1\nend\n")
        self.assertEqual(get_acls(self.db, "r1", "extended"), [])
        self.assertEqual(collect_acl_tasks("r1", str(self.path)), [])
        self.assertEqual(self.snapshot("r2"), before)

    def test_pending_edits_and_interface_bindings_survive_safe_and_preview_force_restores_device(self):
        sync_device_state(self.path, "r1", SCREEN_CONFIG)
        payload = self.payload()
        payload["rules"][0]["dst_port"] = "eq ssh"
        self.assertTrue(save_acl(self.db, payload))
        before = self.snapshot()
        for mode in ("preview", "safe"):
            result = sync_device_state(self.path, "r1", "hostname R1\n", mode=mode)
            self.assertIn("acls", result["conflicts"])
            self.assertEqual(self.snapshot(), before)
        sync_device_state(self.path, "r1", SCREEN_CONFIG, mode="force_device_state")
        self.assertEqual(self.payload()["rules"][0]["dst_port"], "eq telnet")
        self.assertEqual(collect_acl_tasks("r1", str(self.path)), [])

    def test_unsupported_qualifier_preserves_whole_acl_and_reports_reason(self):
        sync_device_state(self.path, "r1", SCREEN_CONFIG)
        before = self.payload()
        result = sync_device_state(self.path, "r1", SCREEN_CONFIG.replace("eq telnet log", "eq telnet established log"))
        self.assertEqual(result["unsupported_acls"], 1)
        self.assertEqual(result["unsupported_acl_details"][0]["acl_name"], before["acl_name"])
        self.assertEqual(self.payload(), before)
        self.assertEqual(collect_acl_tasks("r1", str(self.path)), [])

    def test_switch_collects_acl_without_router_pipeline_or_operational_output(self):
        service = ConfigSyncService(self.path, lambda _host: "sw2")
        result = service.sync_committed_snapshot("sw1", ALL_CONFIG, "", {"changed": False})
        self.assertTrue(result["ok"], result)
        self.assertEqual(result["summary"]["acls"], 9)
        self.assertEqual(len(get_acls(self.db, "sw1", "mac")[0]["bindings"]), 1)
        self.assertEqual(collect_acl_tasks("sw1", str(self.path)), [])

    def test_dynamic_reflexive_and_mac_edits_render_correct_commands(self):
        sync_device_state(self.path, "r1", ALL_CONFIG)
        dynamic = self.payload("dynamic")
        dynamic["rules"][1]["timeout_seconds"] = 900
        self.assertTrue(save_acl(self.db, dynamic))
        reflexive = self.payload("reflexive", 1)
        reflexive["rules"].append({"sequence": 30, "action": "permit", "protocol": "evaluate",
                                   "source": "any", "destination": "any", "reflect_name": "OTHER"})
        self.assertTrue(save_acl(self.db, reflexive))
        mac = self.payload("mac")
        self.assertTrue(save_acl_bindings(self.db, mac["acl_id"], []))
        commands = [line for task in collect_acl_tasks("r1", str(self.path)) for line in render_acl_payload(task)]
        self.assertIn("20 dynamic LOGIN timeout 15 permit ip any any log", commands)
        self.assertIn("30 evaluate OTHER", commands)
        self.assertNotIn("30 evaluate OTHER log", commands)
        self.assertIn("no mac access-group L2_FILTER in", commands)
        self.assertNotIn("no ip access-group L2_FILTER in", commands)

    def test_edit_then_delete_keeps_deployed_acl_teardown_pending(self):
        for edit in ("description", "rules"):
            sync_device_state(self.path, "r1", SCREEN_CONFIG, mode="force_device_state")
            payload = self.payload()
            if edit == "description":
                payload.update(description="Updated description", description_only=True)
            else:
                payload["rules"][0]["dst_port"] = "eq ssh"
            self.assertTrue(save_acl(self.db, payload))
            self.assertTrue(delete_acl(self.db, payload["acl_id"]))
            commands = [line for task in collect_acl_tasks("r1", str(self.path)) for line in render_acl_payload(task)]
            self.assertIn("no ip access-list extended ACL_V10_NO_TELNET_R2", commands)
            self.assertEqual(len(get_acls(self.db, "r1", "extended")), 1)

    def test_invalid_rule_or_binding_rolls_back_entire_save(self):
        sync_device_state(self.path, "r1", SCREEN_CONFIG)
        before = self.snapshot()
        for bad in ({"sequence": 10.5}, {"protocol": "tcp\nno router ospf 1"}, {"dst_port": "eq 99999"}):
            payload = self.payload()
            payload["rules"][0].update(bad)
            self.assertFalse(save_acl(self.db, payload))
            self.assertEqual(self.snapshot(), before)
        for binding in ({"iface_id": 1, "direction": "invalid"}, {"iface_id": "bad", "direction": "in"}):
            payload = self.payload()
            payload.update(description="Must roll back", bindings=[binding])
            self.assertFalse(save_acl(self.db, payload))
            self.assertEqual(self.snapshot(), before)

    def test_large_sequence_round_trips_including_automatic_final_deny(self):
        config = SCREEN_CONFIG.replace(" 30 deny ip any any log", " 2147483647 deny ip any any log")
        sync_device_state(self.path, "r1", config)
        payload = self.payload()
        self.assertEqual(payload["rules"][-1]["sequence"], 2147483647)
        self.assertTrue(save_acl(self.db, payload))
        self.assertEqual(collect_acl_tasks("r1", str(self.path)), [])

    def test_collection_notice_reports_unsupported_names_and_pending_acl_conflict(self):
        from features.devices.running_config_service import acl_collection_notice
        notice = acl_collection_notice({"summary": {"conflicts": ["acls"], "unsupported_acl_details": [
            {"acl_name": "TIME_FILTER"}]}})
        self.assertIn("waiting for Push were preserved", notice)
        self.assertIn("TIME_FILTER", notice)

    def test_inferred_sequences_are_normalized_before_edits_and_flag_survives_description_push(self):
        sync_device_state(self.path, "r1", SCREEN_CONFIG)
        payload = self.payload(index=1)
        payload.update(description="Outbound policy", description_only=True)
        self.assertTrue(save_acl(self.db, payload))
        tasks = collect_acl_tasks("r1", str(self.path))
        self.assertFalse(tasks[0]["config"]["resequence"])
        apply_acl_results(tasks, [{"target": "r1", "status": "success"}], str(self.path))
        self.assertEqual(get_acls(self.db, "r1", "extended")[1]["action_Cfg"], 2)
        payload = self.payload(index=1)
        payload["rules"].pop(0)
        self.assertTrue(save_acl(self.db, payload))
        tasks = collect_acl_tasks("r1", str(self.path))
        commands = render_acl_payload(tasks[0])
        self.assertLess(commands.index("ip access-list resequence ACL_V20_V30_OUT 10 10"), commands.index("no 10"))
        apply_acl_results(tasks, [{"target": "r1", "status": "success"}], str(self.path))
        self.assertEqual(get_acls(self.db, "r1", "extended")[1]["action_Cfg"], 0)

    def test_ambiguous_remark_sequence_layout_is_visible_but_rule_changes_are_rejected(self):
        config = SCREEN_CONFIG.replace(" 10 deny tcp", " remark Policy description\n deny tcp")
        sync_device_state(self.path, "r1", config)
        payload = self.payload()
        acl = get_acls(self.db, "r1", "extended")[0]
        self.assertFalse(acl["rules_editable"])
        before = self.snapshot()
        payload["rules"].pop()
        self.assertFalse(save_acl(self.db, payload))
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(collect_acl_tasks("r1", str(self.path)), [])

    def test_multi_acl_fake_session_success_and_cli_failure_acknowledge_correctly(self):
        import json

        class Connection:
            output = "applied"
            commands = []
            def send_config_set(self, commands, **_kwargs):
                self.commands = commands
                return self.output
        class Connector:
            device_type = "cisco_ios"
            connection = Connection()
        connector = Connector()
        sync_device_state(self.path, "r1", SCREEN_CONFIG)
        for index in (0, 1):
            payload = self.payload(index=index)
            payload["rules"].append({"sequence": 50, "action": "deny", "protocol": "ip", "source": "any", "destination": "any"})
            self.assertTrue(save_acl(self.db, payload))
        tasks = collect_acl_tasks("r1", str(self.path))
        output = Path(self.temp.name) / "results.json"
        before = self.snapshot()
        connector.connection.output = "% Invalid input detected at '^' marker."
        run_acl_config(tasks, str(self.path), str(output), session_provider=lambda _host: connector)
        results = json.loads(output.read_text())
        self.assertEqual(results[0]["status"], "failed")
        apply_acl_results(tasks, results, str(self.path))
        self.assertEqual(self.snapshot(), before)
        connector.connection.output = "applied"
        run_acl_config(tasks, str(self.path), str(output), session_provider=lambda _host: connector)
        report = apply_acl_results(tasks, json.loads(output.read_text()), str(self.path))
        self.assertEqual(report[0]["status"], "SUCCESS")
        self.assertIn("ip access-list extended ACL_V10_NO_TELNET_R2", connector.connection.commands)
        self.assertIn("ip access-list extended ACL_V20_V30_OUT", connector.connection.commands)
        self.assertEqual(collect_acl_tasks("r1", str(self.path)), [])


if __name__ == "__main__":
    unittest.main()
