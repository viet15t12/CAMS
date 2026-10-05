"""Regression coverage for saved, previewed and collected DAI logging policies."""

import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from unittest.mock import patch

from features.switching.commands import render_security
from features.switching.desired_state import collect_desired_state
from features.switching.policy_task_builder import build_security_tasks
from features.switching.schema import ensure_security_logging_schema
from features.switching.security_repository import get_l2_security, save_l2_vlan_security
from features.switching.sync import parse_running_config_security, sync_switch_state
from features.switching.view_push import SwitchingViewPushController
from infrastructure.database.paths import DEVICE_NETWORK_SCHEMA_DIR
from scripts import build_databases


class _Database:
    def __init__(self, path: Path):
        self.path = path

    def _connect(self):
        connection = sqlite3.connect(self.path)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        return connection


class SwitchSecurityLoggingTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.path = Path(self.temporary.name) / "device.db"
        build_databases.build_database(DEVICE_NETWORK_SCHEMA_DIR, self.path)
        self.db = _Database(self.path)
        with closing(self.db._connect()) as connection, connection:
            connection.execute(
                "INSERT INTO t01_devices(host, device_name, role, device_type) "
                "VALUES ('switch-1', 'lab-switch', 'sw2', 'switch_layer2');"
            )
            connection.executemany(
                "INSERT INTO t06_vlan_db(host, vlan_id, success, device_present) "
                "VALUES ('switch-1', ?, 'synchronized', 1);",
                [(10,), (20,)],
            )

    def save(self, mode="all", vlan_id=10):
        result = save_l2_vlan_security(self.db, "switch-1", {
            "vlan_id": vlan_id, "dhcp_snooping": True, "dai_enabled": True,
            "dai_log_mode": mode,
        })
        self.assertTrue(result["ok"], result)
        return result

    def test_running_config_sync_keeps_dhcp_and_arp_trust_independent(self):
        snapshot = {"running_config": """ip dhcp snooping vlan 10
interface GigabitEthernet0/1
 ip dhcp snooping trust
!
interface GigabitEthernet0/2
 ip arp inspection trust
!
interface GigabitEthernet0/3
 ip dhcp snooping trust
 ip arp inspection trust
!
"""}
        # A stale operational sample must not add DHCP trust to the ARP-only port.
        snapshot["dhcp_snooping"] = "GigabitEthernet0/2 yes yes unlimited\n"
        expected = [("GigabitEthernet0/1", 1, 0), ("GigabitEthernet0/2", 0, 1),
                    ("GigabitEthernet0/3", 1, 1)]
        for _ in range(2):
            sync_switch_state(self.path, "switch-1", snapshot, mode="force_device_state")
            with closing(self.db._connect()) as conn:
                actual = conn.execute("SELECT if_name, trust_dhcp, trust_arp FROM t06_dhcp_trust_ports "
                                      "ORDER BY if_name").fetchall()
            self.assertEqual([tuple(row) for row in actual], expected)
        snapshot["running_config"] = snapshot["running_config"].replace(" ip dhcp snooping trust\n", "")
        sync_switch_state(self.path, "switch-1", snapshot, mode="force_device_state")
        self.assertEqual([(row["if_name"], row["trust_dhcp"], row["trust_arp"])
                          for row in get_l2_security(self.db, "switch-1")["trust_ports"]],
                         [("GigabitEthernet0/2", 0, 1), ("GigabitEthernet0/3", 0, 1)])

    def test_snooping_show_only_does_not_invent_arp_trust(self):
        snapshot = {"dhcp_snooping": """Switch DHCP snooping is enabled
DHCP snooping is configured on following VLANs:
10
Interface                  Trusted    Allow option    Rate limit (pps)
-----------------------    -------    ------------    ----------------
GigabitEthernet0/1         yes        yes             unlimited
"""}
        sync_switch_state(self.path, "switch-1", snapshot, mode="force_device_state")
        row = get_l2_security(self.db, "switch-1")["trust_ports"][0]
        self.assertEqual((row["trust_dhcp"], row["trust_arp"]), (1, 0))
        with closing(self.db._connect()) as conn, conn:
            conn.execute("UPDATE t06_dhcp_trust_ports SET trust_arp=1")
        sync_switch_state(self.path, "switch-1", snapshot, mode="force_device_state")
        row = get_l2_security(self.db, "switch-1")["trust_ports"][0]
        self.assertEqual((row["trust_dhcp"], row["trust_arp"]), (1, 1))

    def test_save_reload_desired_state_and_pending_task_keep_per_vlan_modes(self):
        self.save("all", 10)
        self.save("deny", 20)
        reloaded = get_l2_security(self.db, "switch-1")["vlans"]
        self.assertEqual({row["vlan_id"]: row["dai_log_mode"] for row in reloaded},
                         {10: "all", 20: "deny"})
        tasks = build_security_tasks(self.db, "switch-1", "l2_security",
                                     SwitchingViewPushController._task)
        by_vlan = {task["entity_key"]: task["commands"] for task in tasks}
        self.assertIn("ip arp inspection vlan 10 logging dhcp-bindings all", by_vlan["vlan:10"])
        self.assertNotIn("no ip arp inspection vlan 10 logging dhcp-bindings", by_vlan["vlan:10"])
        self.assertIn("no ip arp inspection vlan 20 logging dhcp-bindings", by_vlan["vlan:20"])
        commands = render_security(collect_desired_state(self.db, "switch-1", "security"))
        self.assertIn("ip arp inspection vlan 10 logging dhcp-bindings all", commands)
        self.assertIn("no ip arp inspection vlan 20 logging dhcp-bindings", commands)

    def test_invalid_log_mode_does_not_mutate_saved_policy(self):
        self.save()
        result = save_l2_vlan_security(self.db, "switch-1", {
            "vlan_id": 10, "dhcp_snooping": True, "dai_enabled": True,
            "dai_log_mode": "all\nlogging off",
        })
        self.assertFalse(result["ok"])
        self.assertEqual(get_l2_security(self.db, "switch-1")["vlans"][0]["dai_log_mode"], "all")
        with self.assertRaises(ValueError):
            render_security({"vlans": [{"vlan_id": 10, "dai_enabled": True,
                                        "dhcp_snooping": True, "dai_log_mode": "invalid"}],
                             "trust_ports": [], "ports": [], "static_macs": []})

    def test_running_config_round_trip_keeps_all_and_default_deny(self):
        result = sync_switch_state(self.path, "switch-1", {"running_config": (
            "ip dhcp snooping vlan 10,20\n"
            "ip arp inspection vlan 10,20\n"
            "ip arp inspection vlan 10 logging dhcp-bindings all\n"
        )})
        self.assertIn("security", result["applied"])
        reloaded = get_l2_security(self.db, "switch-1")["vlans"]
        self.assertEqual({row["vlan_id"]: row["dai_log_mode"] for row in reloaded},
                         {10: "all", 20: "deny"})
        commands = render_security(collect_desired_state(self.db, "switch-1", "security"))
        self.assertIn("ip arp inspection vlan 10 logging dhcp-bindings all", commands)

    def test_logging_command_alone_does_not_enable_dai_during_pull(self):
        config = (
            "ip arp inspection vlan 10-11 logging dhcp-bindings all\n"
            "ip arp inspection vlan 20\n"
        )
        for separator in ("\n", "\r\n"):
            with self.subTest(separator=repr(separator)):
                parsed = parse_running_config_security(config.replace("\n", separator))
                self.assertEqual(parsed["dai_vlans"], {20})
                self.assertEqual(parsed["dai_log_modes"], {10: "all", 11: "all", 20: "deny"})

    def test_permit_only_and_disabled_device_policies_are_preserved(self):
        for mode in ("permit", "none"):
            with self.subTest(mode=mode):
                self.save(mode)
                commands = render_security(collect_desired_state(self.db, "switch-1", "security"))
                self.assertIn(f"ip arp inspection vlan 10 logging dhcp-bindings {mode}", commands)

    def test_startup_upgrade_preserves_existing_rows_and_is_idempotent(self):
        self.save("deny")
        with closing(self.db._connect()) as connection, connection:
            connection.execute("ALTER TABLE t06_security_l2 DROP COLUMN dai_log_mode;")
        with patch.object(build_databases, "TARGETS", ((DEVICE_NETWORK_SCHEMA_DIR, self.path),)):
            upgraded = build_databases.ensure_runtime_databases()
        self.assertIn("t06_security_l2.dai_log_mode", upgraded["repaired"][self.path.name])
        with closing(self.db._connect()) as connection, connection:
            row = connection.execute(
                "SELECT vlan_id, dhcp_snooping, dai_enabled, dai_log_mode, success "
                "FROM t06_security_l2;"
            ).fetchone()
            self.assertEqual(tuple(row), (10, 1, 1, "deny", "pending_apply"))
            self.assertEqual(ensure_security_logging_schema(connection), [])
            with self.assertRaises(sqlite3.IntegrityError):
                connection.execute("UPDATE t06_security_l2 SET dai_log_mode = 'invalid';")


if __name__ == "__main__":
    unittest.main()
