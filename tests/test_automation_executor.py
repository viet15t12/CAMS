from __future__ import annotations

import json
import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from typing import Any

from features.automation.executor import AutomationActionExecutor
from features.syslog.application.security_events import SecurityEventDetector
from features.syslog.persistence.message_repository import MessageRepository


FLOOD_LOG = {
    "id": 91,
    "device_host": "192.168.122.101",
    "source_ip": "192.168.122.101",
    "protocol": "udp",
    "cisco_facility": "HA_EM",
    "mnemonic": "LOG",
    "message": "ICMP-FLOOD: Vuot 200 ICMP Echo Request",
}


class _Connection:
    def __init__(self, states: list[str]) -> None:
        self.states = list(states)
        self.config_batches: list[list[str]] = []

    def send_command(self, command: str, **_kwargs: Any) -> str:
        if not self.states:
            raise AssertionError(f"Unexpected verification command: {command}")
        return self.states.pop(0)

    def send_config_set(self, commands: list[str], **_kwargs: Any) -> str:
        self.config_batches.append(list(commands))
        return "configuration accepted"


class _Connector:
    def __init__(self, connection: _Connection, method: str = "ssh") -> None:
        self.connection = connection
        self.method = method
        self.show_commands: list[str] = []

    def send_command(self, command: str) -> str:
        self.show_commands.append(command)
        return self.connection.send_command(command)


class _Registry:
    def __init__(self, connector: _Connector) -> None:
        self.connector = connector

    def execute(self, _host: str, operation: Any, **_kwargs: Any) -> dict[str, Any]:
        try:
            return {"ok": True, "value": operation(self.connector)}
        except Exception as exc:
            return {"ok": False, "message": str(exc)}


def _auto_plan(event_id: str) -> dict[str, Any]:
    return {
        "event_id": event_id,
        "device_host": "192.168.122.101",
        "subject_key": "192.168.122.101",
        "rule_id": "shutdown-gi0-3-on-icmp-flood",
        "rule_revision": "d" * 64,
        "mode": "auto",
        "action_type": "interface.admin-state",
        "status": "ready",
        "dedup_key": "auto-literal-interface",
        "cooldown_seconds": 300,
        "max_actions_per_hour": 2,
        "request_redacted": {
            "driver": "interface.admin-state",
            "transport": "ssh",
            "device_host": "192.168.122.101",
            "interface": "GigabitEthernet0/3",
            "interface_binding": "literal",
            "enabled": False,
            "ttl_seconds": 0,
            "dry_run": False,
        },
    }


def _cli_plan(
    event_id: str, *, mode: str = "config", rule_version: int = 2,
) -> dict[str, Any]:
    commands = (
        ["router ospf 1", "network 10.0.0.0 0.0.0.255 area 0"]
        if mode == "config"
        else ["show clock", "show ip interface brief"]
    )
    request = {
        "driver": "ssh.cli",
        "rule_version": rule_version,
        "transport": "ssh",
        "device_host": "192.168.122.101",
        "mode": mode,
        "commands": commands,
        "verify_commands": ["show ip ospf interface brief"],
        "ttl_seconds": 0,
        "dry_run": False,
    }
    if rule_version == 3:
        request.update({
            "commands": ["interface Te1/1/1", "shutdown"],
            "verify_commands": ["show interfaces Te1/1/1"],
            "variables": {"interface": "Te1/1/1"},
            "variable_source_message_ids": {"interface": 91},
        })
    return {
        "event_id": event_id,
        "device_host": "192.168.122.101",
        "subject_key": "192.168.122.101",
        "rule_id": f"cli-{mode}-v2",
        "rule_revision": "e" * 64,
        "mode": "auto",
        "action_type": "ssh.cli",
        "status": "ready",
        "dedup_key": f"cli-{mode}-v2-dedup",
        "cooldown_seconds": 300,
        "max_actions_per_hour": 2,
        "request_redacted": request,
    }


class AutomationActionExecutorTests(unittest.TestCase):
    def _repository_with_action(
        self, root: Path, plan_factory: Any = _auto_plan,
    ) -> MessageRepository:
        database = root / "info.db"
        database.touch()
        repository = MessageRepository(database)
        detection = SecurityEventDetector().process_detections([FLOOD_LOG])[0]
        repository.insert_security_detections([detection])
        result = repository.materialize_automation_actions(
            [plan_factory(detection.event.event_id)], [detection.event.event_id]
        )
        self.assertEqual(result, {"inserted": 1, "suppressed": 0})
        return repository

    def test_auto_shutdown_waits_for_and_records_verification(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repository = self._repository_with_action(Path(temporary))
            connection = _Connection([
                "GigabitEthernet0/3 is up, line protocol is up",
                "GigabitEthernet0/3 is administratively down, line protocol is down",
            ])
            executor = AutomationActionExecutor(
                _Registry(_Connector(connection)), verify_timeout=0
            )

            result = executor.execute_ready(repository)

            self.assertEqual(result, {"verified": 1, "noop_verified": 0, "failed": 0})
            self.assertEqual(
                connection.config_batches,
                [["interface GigabitEthernet0/3", "shutdown"]],
            )
            action = repository.query_automation_actions()[0]
            self.assertEqual(action["status"], "verified")
            self.assertEqual(action["attempts"], 1)
            self.assertFalse(json.loads(action["after_json"])["enabled"])
            self.assertIsNone(action["lease_owner"])

    def test_auto_shutdown_is_idempotent_when_already_down(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repository = self._repository_with_action(Path(temporary))
            connection = _Connection([
                "GigabitEthernet0/3 is administratively down, line protocol is down"
            ])
            executor = AutomationActionExecutor(
                _Registry(_Connector(connection)), verify_timeout=0
            )

            result = executor.execute_ready(repository)

            self.assertEqual(result, {"verified": 0, "noop_verified": 1, "failed": 0})
            self.assertEqual(connection.config_batches, [])
            self.assertEqual(
                repository.query_automation_actions()[0]["status"], "noop_verified"
            )

    def test_empty_show_interfaces_falls_back_to_interface_brief(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repository = self._repository_with_action(Path(temporary))
            connection = _Connection([
                "",
                "GigabitEthernet0/3 unassigned YES NVRAM up up",
                "GigabitEthernet0/3 is administratively down, line protocol is down",
            ])
            connector = _Connector(connection)
            executor = AutomationActionExecutor(
                _Registry(connector), verify_timeout=0
            )

            result = executor.execute_ready(repository)

            self.assertEqual(result, {"verified": 1, "noop_verified": 0, "failed": 0})
            self.assertEqual(
                connector.show_commands[:2],
                [
                    "show interfaces GigabitEthernet0/3",
                    "show ip interface brief | include GigabitEthernet0/3",
                ],
            )
            self.assertEqual(
                repository.query_automation_actions()[0]["status"], "verified"
            )

    def test_auto_shutdown_rejects_non_ssh_session(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repository = self._repository_with_action(Path(temporary))
            connection = _Connection([])
            executor = AutomationActionExecutor(
                _Registry(_Connector(connection, method="telnet")), verify_timeout=0
            )

            result = executor.execute_ready(repository)

            self.assertEqual(result, {"verified": 0, "noop_verified": 0, "failed": 1})
            action = repository.query_automation_actions()[0]
            self.assertEqual(action["status"], "failed")
            self.assertIn("active SSH session", action["last_error"])
            self.assertEqual(connection.config_batches, [])

    def test_version_2_config_commands_run_as_one_batch_and_verify(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repository = self._repository_with_action(
                Path(temporary), lambda event_id: _cli_plan(event_id, mode="config")
            )
            connection = _Connection(["OSPF process 1 with Router ID 10.0.0.1"])
            connector = _Connector(connection)
            executor = AutomationActionExecutor(_Registry(connector))

            result = executor.execute_ready(repository)

            self.assertEqual(result, {"verified": 1, "noop_verified": 0, "failed": 0})
            self.assertEqual(
                connection.config_batches,
                [["router ospf 1", "network 10.0.0.0 0.0.0.255 area 0"]],
            )
            self.assertEqual(
                connector.show_commands, ["show ip ospf interface brief"]
            )

    def test_version_3_rendered_interface_commands_execute(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repository = self._repository_with_action(
                Path(temporary),
                lambda event_id: _cli_plan(event_id, rule_version=3),
            )
            connection = _Connection(["Te1/1/1 is administratively down"])
            connector = _Connector(connection)
            executor = AutomationActionExecutor(_Registry(connector))

            result = executor.execute_ready(repository)

            self.assertEqual(result, {"verified": 1, "noop_verified": 0, "failed": 0})
            self.assertEqual(
                connection.config_batches,
                [["interface Te1/1/1", "shutdown"]],
            )
            self.assertEqual(connector.show_commands, ["show interfaces Te1/1/1"])
            action = repository.query_automation_actions()[0]
            after = json.loads(action["after_json"])
            self.assertEqual(action["status"], "verified")
            self.assertEqual(after["verification_mode"], "commands")
            self.assertEqual(after["command_count"], 2)

    def test_version_2_exec_commands_run_sequentially(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repository = self._repository_with_action(
                Path(temporary), lambda event_id: _cli_plan(event_id, mode="exec")
            )
            connection = _Connection([
                "08:30:00 ICT",
                "GigabitEthernet0/0 up up",
                "OSPF process 1 with Router ID 10.0.0.1",
            ])
            connector = _Connector(connection)
            executor = AutomationActionExecutor(_Registry(connector))

            result = executor.execute_ready(repository)

            self.assertEqual(result, {"verified": 1, "noop_verified": 0, "failed": 0})
            self.assertEqual(connection.config_batches, [])
            self.assertEqual(
                connector.show_commands,
                ["show clock", "show ip interface brief", "show ip ospf interface brief"],
            )

    def test_expired_version_2_cli_lease_fails_without_replay(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repository = self._repository_with_action(
                Path(temporary), lambda event_id: _cli_plan(event_id, mode="config")
            )
            claimed = repository.claim_next_auto_action("first-worker")
            self.assertIsNotNone(claimed)
            repository.begin_auto_action(int(claimed["id"]), "first-worker")
            with closing(sqlite3.connect(repository.info_db)) as connection:
                connection.execute(
                    "UPDATE t13_automation_actions "
                    "SET lease_until = '2000-01-01 00:00:00' WHERE id = ?",
                    (int(claimed["id"]),),
                )
                connection.commit()

            replay = repository.claim_next_auto_action("second-worker")

            self.assertIsNone(replay)
            action = repository.query_automation_actions()[0]
            self.assertEqual(action["status"], "failed")
            self.assertIn("automatic replay is disabled", action["last_error"])


if __name__ == "__main__":
    unittest.main()
