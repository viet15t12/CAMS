import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from features.syslog.application.security_events import SecurityEventDetector
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
        "192.0.2.10(22), 100 packets"
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


if __name__ == "__main__":
    unittest.main()
