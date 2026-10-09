from __future__ import annotations

import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from features.config_sync import ConfigSyncService
from features.devices.sync_state import parse_running_config_sections, sync_device_state
from scripts.build_databases import combine_sql


CONFIG = """hostname R1
ip dhcp pool VLAN10
 network 192.168.10.0 255.255.255.0
 default-router 192.168.10.1
 dns-server 8.8.8.8 1.1.1.1
 lease 7 12 30
!
ip dhcp pool VLAN20
 network 192.168.20.0 /24
!
ip dhcp pool VLAN30
 network 192.168.30.0 255.255.255.0
 lease infinite
!
end
"""


class DhcpPoolSyncTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.db_path = Path(self.temp.name) / "device.db"
        schema = Path(__file__).resolve().parents[1] / "infrastructure/database/schemas/device_network"
        with closing(sqlite3.connect(self.db_path)) as conn, conn:
            conn.executescript(combine_sql(schema))
            conn.executemany(
                "INSERT INTO t01_devices(host, role) VALUES (?, 'rou')",
                [("r1",), ("r2",)],
            )

    def rows(self, host="r1"):
        with closing(sqlite3.connect(self.db_path)) as conn:
            conn.row_factory = sqlite3.Row
            return [dict(row) for row in conn.execute(
                "SELECT * FROM t03_dhcp_pool WHERE host = ? ORDER BY pool", (host,)
            )]

    def test_parser_reads_options_defaults_and_terminal_noise(self) -> None:
        parsed = parse_running_config_sections("\x1b[0m" + CONFIG.replace("\n", "\r\n"))
        self.assertEqual(len(parsed.dhcp_pools), 3)
        self.assertEqual(parsed.dhcp_pools[0], {
            "pool": "VLAN10", "network": "192.168.10.0", "subnetmask": "255.255.255.0",
            "defaut": "192.168.10.1", "dns": "8.8.8.8 1.1.1.1", "lease": "7 12 30",
        })
        self.assertEqual(parsed.dhcp_pools[1]["lease"], "1")
        self.assertIsNone(parsed.dhcp_pools[1]["defaut"])
        self.assertIsNone(parsed.dhcp_pools[1]["dns"])
        self.assertEqual(parsed.dhcp_pools[2]["lease"], "infinite")
        eof = parse_running_config_sections("ip dhcp pool EOF\n network 192.168.40.0/24\n")
        self.assertEqual(eof.dhcp_pools[0]["subnetmask"], "255.255.255.0")

    def test_unchanged_committed_snapshot_populates_saved_pools(self) -> None:
        service = ConfigSyncService(self.db_path, lambda _host: "rou")
        result = service.sync_committed_snapshot(
            "r1", CONFIG, "GigabitEthernet0/0 unassigned YES unset up up\n",
            {"changed": False, "commitId": "abc"},
        )
        self.assertTrue(result["ok"], result)
        self.assertEqual(result["summary"]["dhcp_pools"], 3)
        self.assertEqual(len(self.rows()), 3)
        self.assertTrue(all(row["sync_status"] == "synchronized" and row["action_Cfg"] == "000"
                            for row in self.rows()))

    def test_sync_retains_ids_updates_options_and_removes_absent_pools_only_for_host(self) -> None:
        sync_device_state(self.db_path, "r1", CONFIG)
        sync_device_state(self.db_path, "r2", CONFIG)
        initial = self.rows()
        sync_device_state(self.db_path, "r1", CONFIG)
        self.assertEqual(self.rows(), initial)
        changed = CONFIG.replace(" dns-server 8.8.8.8 1.1.1.1\n", "").replace(" lease 7 12 30\n", "")
        sync_device_state(self.db_path, "r1", changed)
        row = self.rows()[0]
        self.assertEqual(row["dhcp_id"], initial[0]["dhcp_id"])
        self.assertIsNone(row["dns"])
        self.assertEqual(row["lease"], "1")
        sync_device_state(self.db_path, "r1", "hostname R1\nend\n")
        self.assertEqual(self.rows(), [])
        self.assertEqual(len(self.rows("r2")), 3)

    def test_safe_and_preview_preserve_pending_edits_and_deletes_force_reconciles(self) -> None:
        sync_device_state(self.db_path, "r1", CONFIG)
        with closing(sqlite3.connect(self.db_path)) as conn, conn:
            conn.execute("UPDATE t03_dhcp_pool SET dns = '9.9.9.9', sync_status = 'pending_apply', "
                         "action_Cfg = '010' WHERE pool = 'VLAN10'")
            conn.execute("UPDATE t03_dhcp_pool SET sync_status = 'pending_delete' WHERE pool = 'VLAN20'")
        pending = self.rows()
        for mode in ("preview", "safe"):
            summary = sync_device_state(self.db_path, "r1", CONFIG, mode=mode)
            self.assertIn("dhcp_pools", summary["conflicts"])
            self.assertEqual(summary["dhcp_pools"], 3)
            self.assertEqual(self.rows(), pending)
        sync_device_state(self.db_path, "r1", CONFIG, mode="force_device_state")
        self.assertEqual(self.rows()[0]["dns"], "8.8.8.8 1.1.1.1")
        self.assertTrue(all(row["sync_status"] == "synchronized" and row["action_Cfg"] == "000"
                            for row in self.rows()))

    def test_preview_does_not_import_pools(self) -> None:
        summary = sync_device_state(self.db_path, "r1", CONFIG, mode="preview")
        self.assertEqual(summary["dhcp_pools"], 3)
        self.assertEqual(self.rows(), [])

    def test_unsupported_pools_are_reported_and_existing_rows_are_preserved(self) -> None:
        sync_device_state(self.db_path, "r1", CONFIG)
        initial = self.rows()
        changed = CONFIG.replace("ip dhcp pool VLAN10\n", "ip dhcp pool VLAN10\n vrf BLUE\n")
        changed += "ip dhcp pool STATIC\n host 192.168.40.10 255.255.255.0\n client-identifier abcd\n!\n"
        summary = sync_device_state(self.db_path, "r1", changed)
        self.assertEqual(summary["dhcp_pools"], 2)
        self.assertEqual(summary["unsupported_dhcp_pools"], 2)
        self.assertEqual(self.rows(), initial)

    def test_parser_rejects_invalid_or_unrepresentable_pools_without_truncation(self) -> None:
        for body in (
            " network 192.168.10.0\n",
            " network 192.168.10.0 255.0.255.0\n",
            " network 192.168.10.0 255.255.255.0\n default-router 192.168.10.1 192.168.10.2\n",
            " network 192.168.10.0 255.255.255.0\n network 192.168.20.0 255.255.255.0 secondary\n",
            " network 192.168.10.0 255.255.255.0\n lease 1 25\n",
        ):
            with self.subTest(body=body):
                parsed = parse_running_config_sections("ip dhcp pool TEST\n" + body + "!\n")
                self.assertEqual(parsed.dhcp_pools, [])
                self.assertEqual(parsed.unsupported_dhcp_pools[0]["pool"], "TEST")


if __name__ == "__main__":
    unittest.main()
