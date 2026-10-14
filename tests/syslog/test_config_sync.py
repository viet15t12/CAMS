from __future__ import annotations

import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from features.syslog.config_sync import parse_syslog_config, sync_syslog_state


CONFIG = """hostname R1
logging trap debugging
logging source-interface GigabitEthernet0/0
logging host 192.168.122.1 transport udp port 5514
service timestamps log datetime msec
service sequence-numbers
"""


class SyslogConfigSyncTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.db_path = Path(self.temp.name) / "device.db"
        with closing(sqlite3.connect(self.db_path)) as conn, conn:
            conn.execute("CREATE TABLE t01_devices(host TEXT PRIMARY KEY)")
            conn.execute("INSERT INTO t01_devices(host) VALUES ('r1')")

    def rows(self):
        with closing(sqlite3.connect(self.db_path)) as conn:
            conn.row_factory = sqlite3.Row
            return [dict(row) for row in conn.execute(
                "SELECT * FROM t10_syslog_servers ORDER BY server_ip"
            )]

    def test_parser_reads_destination_source_and_debugging_severity(self) -> None:
        self.assertEqual(
            parse_syslog_config(CONFIG),
            [{
                "server_ip": "192.168.122.1",
                "protocol": "udp",
                "port": 5514,
                "source_interface": "GigabitEthernet0/0",
                "trap_severity": 7,
                "timestamps": True,
                "sequence_numbers": True,
            }],
        )

    def test_sync_imports_running_config_as_synchronized_database_state(self) -> None:
        summary = sync_syslog_state(self.db_path, "r1", CONFIG)

        self.assertEqual(summary["syslog_servers"], 1)
        self.assertTrue(summary["syslog_applied"])
        row = self.rows()[0]
        self.assertEqual(row["server_ip"], "192.168.122.1")
        self.assertEqual(row["source_interface"], "GigabitEthernet0/0")
        self.assertEqual(row["trap_severity"], 7)
        self.assertEqual(row["sync_status"], "synchronized")
        self.assertEqual(row["configured"], 1)

    def test_safe_sync_preserves_pending_ui_edit_and_force_replaces_it(self) -> None:
        sync_syslog_state(self.db_path, "r1", CONFIG)
        with closing(sqlite3.connect(self.db_path)) as conn, conn:
            conn.execute(
                "UPDATE t10_syslog_servers SET source_interface = 'Loopback0', "
                "sync_status = 'pending_apply' WHERE device_host = 'r1'"
            )

        safe = sync_syslog_state(self.db_path, "r1", CONFIG, "safe")
        self.assertTrue(safe["syslog_conflict"])
        self.assertEqual(self.rows()[0]["source_interface"], "Loopback0")

        forced = sync_syslog_state(
            self.db_path, "r1", CONFIG, "force_device_state"
        )
        self.assertFalse(forced["syslog_conflict"])
        self.assertEqual(
            self.rows()[0]["source_interface"], "GigabitEthernet0/0"
        )


if __name__ == "__main__":
    unittest.main()
