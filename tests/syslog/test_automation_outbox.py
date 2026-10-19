import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from features.syslog.application.security_events import SecurityEventDetector
from features.syslog.parser import parse_message
from features.syslog.persistence.message_repository import MessageRepository


ACL_FLOOD = {
    "id": 41,
    "device_host": "192.0.2.1",
    "source_ip": "192.0.2.1",
    "protocol": "udp",
    "cisco_facility": "SEC",
    "mnemonic": "IPACCESSLOGP",
    "message": (
        "list EDGE denied tcp 198.51.100.9(1000) -> "
        "192.0.2.10(22), 100 packets on interface GigabitEthernet1/0/2"
    ),
}


class AutomationOutboxTests(unittest.TestCase):
    def test_detector_emits_versioned_structured_event(self) -> None:
        detection = SecurityEventDetector().process_detections([ACL_FLOOD])[0]

        event = detection.event.to_dict()
        self.assertEqual(event["schema_version"], 1)
        self.assertEqual(event["event_type"], "ACL_DROP_FLOOD")
        self.assertEqual(event["device_host"], "192.0.2.1")
        self.assertEqual(event["attributes"]["offender_ip"], "198.51.100.9")
        self.assertEqual(event["attributes"]["protocol"], "tcp")
        self.assertEqual(event["attributes"]["interface"], "GigabitEthernet1/0/2")
        self.assertEqual(event["evidence"]["source_message_ids"], [41])
        self.assertTrue(event["event_id"].startswith("evt-"))

    def test_event_and_alert_are_atomic_and_deduplicated(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            database = Path(temp_dir) / "info.db"
            database.touch()
            repository = MessageRepository(database)
            detection = SecurityEventDetector().process_detections([ACL_FLOOD])[0]
            replayed = SecurityEventDetector().process_detections([dict(ACL_FLOOD)])[0]

            first = repository.insert_security_detections([detection])
            second = repository.insert_security_detections([replayed])

            self.assertEqual(len(first), 1)
            self.assertEqual(second, [])
            self.assertEqual(detection.event.event_id, replayed.event.event_id)
            events = repository.query_automation_events()
            self.assertEqual(len(events), 1)
            self.assertEqual(events[0]["source_alert_id"], first[0]["id"])
            self.assertEqual(events[0]["evidence"]["source_message_ids"], [41])
            with closing(sqlite3.connect(database)) as connection:
                alert_count = connection.execute(
                    "SELECT COUNT(*) FROM t12_syslog_messages "
                    "WHERE cisco_facility = 'CAMS'"
                ).fetchone()[0]
                action_count = connection.execute(
                    "SELECT COUNT(*) FROM t13_automation_actions"
                ).fetchone()[0]
            self.assertEqual(alert_count, 1)
            self.assertEqual(action_count, 0)

    def test_pending_event_is_enriched_from_its_sqlite_syslog_row(self) -> None:
        raw = (
            "%HA_EM-1-LOG: DETECT-DOS: NGHI DOS: ICMP flood vao R4 "
            "tu IP 10.1.1.5 tai cong Te1/1/1"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            database = Path(temp_dir) / "info.db"
            database.touch()
            repository = MessageRepository(database)
            message = parse_message(raw.encode(), "192.168.122.101", "udp")
            message.device_host = "192.168.122.101"
            stored = repository.insert_messages([message])[0]
            detection = SecurityEventDetector().process_detections([stored])[0]
            repository.insert_security_detections([detection])

            event = repository.query_pending_automation_events()[0]

            source = event["evidence"]["source_messages"][0]
            self.assertEqual(source["id"], stored["id"])
            self.assertIn("tai cong Te1/1/1", source["message"])
            self.assertIn("%HA_EM-1-LOG", source["raw_message"])

    def test_materialized_actions_are_audited_and_rate_limited(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            database = Path(temp_dir) / "info.db"
            database.touch()
            repository = MessageRepository(database)
            first_detection = SecurityEventDetector().process_detections([ACL_FLOOD])[0]
            second_row = dict(ACL_FLOOD, id=42)
            second_detection = SecurityEventDetector().process_detections([second_row])[0]
            repository.insert_security_detections([first_detection, second_detection])

            def plan(event_id: str, dedup_key: str) -> dict[str, object]:
                return {
                    "event_id": event_id,
                    "device_host": "192.0.2.1",
                    "subject_key": "198.51.100.9",
                    "rule_id": "deny-icmp",
                    "rule_revision": "a" * 64,
                    "mode": "dry-run",
                    "action_type": "acl.deny-protocol-source",
                    "status": "simulated",
                    "dedup_key": dedup_key,
                    "cooldown_seconds": 300,
                    "max_actions_per_hour": 6,
                    "request_redacted": {
                        "driver": "acl.deny-protocol-source",
                        "device_host": "192.0.2.1",
                        "source_ip": "198.51.100.9",
                        "interface": "GigabitEthernet1/0/2",
                        "protocol": "tcp",
                        "dry_run": True,
                    },
                }

            first = repository.materialize_automation_actions(
                [plan(first_detection.event.event_id, "dedup-1")],
                [first_detection.event.event_id],
            )
            second = repository.materialize_automation_actions(
                [plan(second_detection.event.event_id, "dedup-2")],
                [second_detection.event.event_id],
            )

            self.assertEqual(first, {"inserted": 1, "suppressed": 0})
            self.assertEqual(second, {"inserted": 0, "suppressed": 1})
            actions = repository.query_automation_actions()
            self.assertEqual(len(actions), 1)
            self.assertTrue(actions[0]["request_redacted"]["dry_run"])
            self.assertEqual(repository.query_pending_automation_events(), [])

    def test_materializer_rejects_action_values_not_present_in_event(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            database = Path(temp_dir) / "info.db"
            database.touch()
            repository = MessageRepository(database)
            detection = SecurityEventDetector().process_detections([ACL_FLOOD])[0]
            repository.insert_security_detections([detection])
            forged = {
                "event_id": detection.event.event_id,
                "device_host": "192.0.2.1",
                "subject_key": "198.51.100.9",
                "rule_id": "forged",
                "rule_revision": "b" * 64,
                "mode": "dry-run",
                "action_type": "acl.deny-protocol-source",
                "status": "simulated",
                "dedup_key": "forged-dedup",
                "cooldown_seconds": 0,
                "max_actions_per_hour": 1,
                "request_redacted": {
                    "driver": "acl.deny-protocol-source",
                    "device_host": "192.0.2.1",
                    "source_ip": "203.0.113.200",
                    "interface": "GigabitEthernet1/0/2",
                    "protocol": "tcp",
                    "dry_run": True,
                },
            }

            with self.assertRaisesRegex(ValueError, "do not match"):
                repository.materialize_automation_actions(
                    [forged], [detection.event.event_id]
                )

            self.assertEqual(repository.query_automation_actions(), [])
            self.assertEqual(len(repository.query_pending_automation_events()), 1)

    def test_materializer_accepts_validated_literal_interface_dry_run(self) -> None:
        row = {
            "id": 51,
            "device_host": "192.168.122.101",
            "source_ip": "192.168.122.101",
            "protocol": "udp",
            "cisco_facility": "HA_EM",
            "mnemonic": "LOG",
            "message": "ICMP-FLOOD: Vuot 200 ICMP Echo Request",
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            database = Path(temp_dir) / "info.db"
            database.touch()
            repository = MessageRepository(database)
            detection = SecurityEventDetector().process_detections([row])[0]
            repository.insert_security_detections([detection])
            plan = {
                "event_id": detection.event.event_id,
                "device_host": "192.168.122.101",
                "subject_key": "192.168.122.101",
                "rule_id": "shutdown-gi0-3-on-icmp-flood",
                "rule_revision": "c" * 64,
                "mode": "dry-run",
                "action_type": "interface.admin-state",
                "status": "simulated",
                "dedup_key": "literal-interface-dedup",
                "cooldown_seconds": 300,
                "max_actions_per_hour": 2,
                "request_redacted": {
                    "driver": "interface.admin-state",
                    "device_host": "192.168.122.101",
                    "interface": "GigabitEthernet0/3",
                    "interface_binding": "literal",
                    "enabled": False,
                    "ttl_seconds": 0,
                    "dry_run": True,
                },
            }
            result = repository.materialize_automation_actions(
                [plan], [detection.event.event_id]
            )
            self.assertEqual(result, {"inserted": 1, "suppressed": 0})
            action = repository.query_automation_actions()[0]
            self.assertEqual(
                action["request_redacted"]["interface"], "GigabitEthernet0/3"
            )
            self.assertFalse(action["request_redacted"]["enabled"])


if __name__ == "__main__":
    unittest.main()
