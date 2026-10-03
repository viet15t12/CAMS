from __future__ import annotations

from pathlib import Path
import sqlite3
import unittest
from unittest.mock import MagicMock

from infrastructure.network.privilege import ensure_privileged_mode
from features.devices.repository import DeviceRepository
from features.devices.login_service import DeviceLoginService
from infrastructure.network.connector import create_connector


class PrivilegeEscalationTests(unittest.TestCase):
    def test_privilege_1_calls_standard_enable(self) -> None:
        """When prompt is '>' (privilege 1), Netmiko check_enable_mode() returns False."""
        conn = MagicMock()
        conn.check_config_mode.return_value = False
        conn.check_enable_mode.return_value = False

        result = ensure_privileged_mode(conn)

        self.assertTrue(result)
        conn.enable.assert_called_once_with()

    def test_privilege_15_does_not_call_enable(self) -> None:
        """When prompt is '#' and privilege level is already 15, no enable command is sent."""
        conn = MagicMock()
        conn.device_type = "cisco_ios"
        conn.check_config_mode.return_value = False
        conn.check_enable_mode.return_value = True
        conn.send_command.return_value = "Current privilege level is 15\n"

        result = ensure_privileged_mode(conn)

        self.assertTrue(result)
        conn.send_command.assert_called_once_with("show privilege")
        conn.enable.assert_not_called()

    def test_privilege_5_forces_enable_escalation(self) -> None:
        """When prompt is '#' but privilege is 5 (< 15), force enable escalation."""
        conn = MagicMock()
        conn.device_type = "cisco_ios"
        conn.check_config_mode.return_value = False
        conn.check_enable_mode.return_value = True
        # First call returns level 5, second call (after elevation) returns level 15
        conn.send_command.side_effect = [
            "Current privilege level is 5\n",
            "Current privilege level is 15\n",
        ]

        result = ensure_privileged_mode(conn)

        self.assertTrue(result)
        conn.enable.assert_called_once_with(cmd="enable 15", check_state=False)

    def test_privilege_5_fails_if_elevation_rejected(self) -> None:
        """When enable is rejected (wrong secret), an error is raised."""
        conn = MagicMock()
        conn.device_type = "cisco_ios"
        conn.check_config_mode.return_value = False
        conn.check_enable_mode.return_value = True
        conn.send_command.side_effect = [
            "Current privilege level is 5\n",
            "Current privilege level is 5\n",
        ]

        with self.assertRaises(RuntimeError) as ctx:
            ensure_privileged_mode(conn)
        self.assertIn("Failed to elevate to privilege 15", str(ctx.exception))

    def test_config_mode_exits_before_privilege_check(self) -> None:
        """If session is in config mode, it exits config mode first."""
        conn = MagicMock()
        conn.device_type = "cisco_ios"
        conn.check_config_mode.return_value = True
        conn.check_enable_mode.return_value = True
        conn.send_command.return_value = "Current privilege level is 15\n"

        result = ensure_privileged_mode(conn)

        self.assertTrue(result)
        conn.exit_config_mode.assert_called_once()

    def test_initial_privilege_15_passes_without_secret(self) -> None:
        """Privilege 15 account connects directly without requiring Enable Secret."""
        from infrastructure.network.privilege import ensure_initial_privilege

        conn = MagicMock()
        conn.device_type = "cisco_ios"
        conn.check_enable_mode.return_value = True
        conn.send_command.return_value = "Current privilege level is 15\n"

        # Should not raise any error
        ensure_initial_privilege(conn, secret="", username="admin")
        conn.enable.assert_not_called()

    def test_initial_privilege_5_without_secret_drops_connection(self) -> None:
        """Privilege 5 account without Enable Secret MUST DROP immediately (raise PermissionError)."""
        from infrastructure.network.privilege import ensure_initial_privilege

        conn = MagicMock()
        conn.device_type = "cisco_ios"
        conn.check_enable_mode.return_value = True
        conn.send_command.return_value = "Current privilege level is 5\n"

        with self.assertRaises(PermissionError) as ctx:
            ensure_initial_privilege(conn, secret="", username="Kien")
        self.assertIn("Connection dropped", str(ctx.exception))
        self.assertIn("no Enable Secret was configured", str(ctx.exception))

    def test_initial_privilege_5_with_wrong_secret_drops_connection(self) -> None:
        """Privilege 5 account with WRONG Enable Secret MUST DROP immediately."""
        from infrastructure.network.privilege import ensure_initial_privilege

        conn = MagicMock()
        conn.device_type = "cisco_ios"
        conn.check_enable_mode.return_value = True
        conn.send_command.return_value = "Current privilege level is 5\n"
        conn.enable.side_effect = ValueError("Failed to enter enable mode")

        with self.assertRaises(PermissionError) as ctx:
            ensure_initial_privilege(conn, secret="wrong_pass", username="Kien")
        self.assertIn("Connection dropped", str(ctx.exception))

    def test_initial_privilege_5_with_correct_secret_elevates_and_passes(self) -> None:
        """Privilege 5 account with CORRECT Enable Secret elevates to 15 and connects."""
        from infrastructure.network.privilege import ensure_initial_privilege

        conn = MagicMock()
        conn.device_type = "cisco_ios"
        conn.check_enable_mode.return_value = True
        conn.send_command.side_effect = [
            "Current privilege level is 5\n",
            "Current privilege level is 15\n",
        ]

        ensure_initial_privilege(conn, secret="correct_secret", username="Kien")
        conn.enable.assert_called_once_with(cmd="enable 15", check_state=False)

    def test_initial_privilege_fail_closed_on_unparsable_verify_output(self) -> None:
        """If verify output is corrupted/unparsable after enable, fail-closed and reject."""
        from infrastructure.network.privilege import ensure_initial_privilege

        conn = MagicMock()
        conn.device_type = "cisco_ios"
        conn.check_enable_mode.return_value = True
        conn.send_command.side_effect = [
            "Current privilege level is 5\n",
            "% Unknown error / truncated response\n",
        ]

        with self.assertRaises(PermissionError) as ctx:
            ensure_initial_privilege(conn, secret="some_secret", username="Kien")
        self.assertIn("Connection dropped", str(ctx.exception))
        self.assertIn("strict fail-closed", str(ctx.exception))

    def test_ensure_enable_privilege_fail_closed_on_unparsable_output(self) -> None:
        """ensure_privileged_mode must raise RuntimeError if verify output is unparsable."""
        conn = MagicMock()
        conn.device_type = "cisco_ios"
        conn.check_config_mode.return_value = False
        conn.check_enable_mode.return_value = True
        conn.send_command.side_effect = [
            "Current privilege level is 5\n",
            "Garbled output without privilege level\n",
        ]

        with self.assertRaises(RuntimeError) as ctx:
            ensure_privileged_mode(conn)
        self.assertIn("strict fail-closed", str(ctx.exception))


class CredentialFlowTests(unittest.TestCase):
    def setUp(self) -> None:
        import tempfile
        from contextlib import closing

        self.temp = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp.name) / "device.db"
        with closing(sqlite3.connect(self.db_path)) as conn, conn:
            conn.execute(
                """
                CREATE TABLE t01_devices (
                    host TEXT PRIMARY KEY,
                    device_name TEXT,
                    method TEXT,
                    portnumber INTEGER,
                    username TEXT,
                    password TEXT,
                    enable_password TEXT DEFAULT '',
                    os TEXT,
                    role TEXT,
                    dev INTEGER DEFAULT 0
                );
                """
            )
            conn.execute(
                """
                CREATE TABLE t01_ssh_algo (
                    host TEXT PRIMARY KEY,
                    kex_algorithms TEXT DEFAULT '',
                    host_key_algorithms TEXT DEFAULT '',
                    ciphers TEXT DEFAULT '',
                    macs TEXT DEFAULT '',
                    note TEXT DEFAULT ''
                );
                """
            )
            conn.execute(
                """
                INSERT INTO t01_devices (host, device_name, method, portnumber, username, password, enable_password, os, role, dev)
                VALUES ('192.168.1.1', 'R1', 'ssh', 22, 'kien', 'kien123', 'secret999', 'cisco_ios', 'rou', 0);
                """
            )

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_repository_get_login_includes_enable_password(self) -> None:
        repo = DeviceRepository(self.db_path)
        login_row = repo.get_login("192.168.1.1")
        self.assertIsNotNone(login_row)
        self.assertEqual(login_row["enable_password"], "secret999")

    def test_login_service_load_maps_secret_and_enable_password(self) -> None:
        repo = DeviceRepository(self.db_path)
        service = DeviceLoginService(repo)
        payload = service.load("192.168.1.1")
        self.assertIsNotNone(payload)
        self.assertEqual(payload["secret"], "secret999")
        self.assertEqual(payload["enable_password"], "secret999")

    def test_create_connector_passes_secret(self) -> None:
        device_dict = {
            "host": "192.168.1.1",
            "method": "ssh",
            "port": 22,
            "username": "kien",
            "password": "kien123",
            "secret": "secret999",
            "device_type": "cisco_ios",
        }
        connector = create_connector(device_dict)
        self.assertEqual(connector.secret, "secret999")
