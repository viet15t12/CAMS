from __future__ import annotations

import json
import os
from pathlib import Path
import tempfile
import threading
import unittest

from features.syslog.alerts.renderer import render_email
from features.syslog.alerts.service import EmailAlertService
from features.syslog.alerts.settings import AlertSettingsStore, AlertValidationError


def _payload(**updates):
    values = {
        "enabled": True,
        "smtp_host": "smtp.gmail.com",
        "smtp_port": 465,
        "sender_email": "sender@example.com",
        "sender_app_password": "abcdefghijklmnop",
        "recipients": ["one@example.com", "two@example.com"],
        "levels": [0, 2, 4],
        "cooldown_seconds": 300,
        "batch_seconds": 0,
    }
    values.update(updates)
    return values


def _record(severity: int = 2, mnemonic: str = "MALLOCFAIL"):
    return {
        "device_host": "RT-EDGE-02",
        "source_ip": "10.0.0.2",
        "received_at": "2026-10-02T10:00:00+07:00",
        "severity": severity,
        "cisco_facility": "SYS",
        "mnemonic": mnemonic,
        "message": "Memory <allocation> failed & needs attention",
        "raw_message": "<186>%SYS-2-MALLOCFAIL: demo",
        "protocol": "udp",
    }


class AlertSettingsTests(unittest.TestCase):
    def test_secret_is_persisted_but_never_returned_to_qml(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "alert_settings.json"
            store = AlertSettingsStore(path)
            store.save(_payload())

            public = store.public_values()
            stored = json.loads(path.read_text(encoding="utf-8"))
            self.assertTrue(public["has_password"])
            self.assertNotIn("abcdefghijklmnop", json.dumps(public))
            self.assertTrue(stored["sender_app_password"].startswith("ENC$v2$"))
            self.assertNotIn("abcdefghijklmnop", json.dumps(stored))
            self.assertEqual(store.configuration().sender_app_password, "abcdefghijklmnop")
            if os.name != "nt":
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_blank_password_keeps_the_saved_password(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            store = AlertSettingsStore(Path(temporary) / "alert_settings.json")
            store.save(_payload())
            updated = store.save(_payload(sender_app_password="", levels=[1, 3]))
            self.assertEqual(updated.sender_app_password, "abcdefghijklmnop")
            self.assertEqual(updated.levels, (1, 3))

    def test_recipient_validation_is_case_insensitive(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            store = AlertSettingsStore(Path(temporary) / "alert_settings.json")
            with self.assertRaises(AlertValidationError) as raised:
                store.save(_payload(recipients=["Admin@example.com", "admin@example.com"]))
            self.assertIn("recipients.1", raised.exception.errors)


class AlertRendererTests(unittest.TestCase):
    def test_renderer_uses_selected_language_and_escapes_log_content(self) -> None:
        en_subject, en_text, en_html = render_email(_record(), "en")
        vi_subject, vi_text, vi_html = render_email(_record(), "vi")

        self.assertIn("CRITICAL", en_subject)
        self.assertIn("critical condition", en_text)
        self.assertIn("NGHIÊM TRỌNG", vi_subject)
        self.assertIn("tình trạng nghiêm trọng", vi_text)
        self.assertIn("Giờ nhận", vi_html)
        self.assertIn("Memory &lt;allocation&gt; failed &amp; needs attention", en_html)

    def test_test_email_subject_is_marked(self) -> None:
        subject, _, _ = render_email(_record(), "en", test=True)
        self.assertTrue(subject.startswith("[TEST]"))

    def test_subject_fields_cannot_inject_an_email_header(self) -> None:
        record = _record()
        record["device_host"] = "router-1\nBcc: attacker@example.com"
        subject, _, _ = render_email(record, "en")
        self.assertNotIn("\n", subject)
        self.assertIn("router-1 Bcc: attacker@example.com", subject)


class EmailAlertServiceTests(unittest.TestCase):
    def test_batch_window_groups_multiple_alerts_into_one_email(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            store = AlertSettingsStore(Path(temporary) / "alert_settings.json")
            store.save(_payload(levels=[2], cooldown_seconds=0, batch_seconds=10))
            delivered: list[list[dict]] = []

            def sender(_config, records, _language, _test):
                delivered.append(records)
                return "sent"

            service = EmailAlertService(store, sender=sender)
            self.assertEqual(
                service.submit([
                    _record(2, "MALLOCFAIL"),
                    _record(2, "OVERTEMP"),
                ]),
                2,
            )
            service.shutdown()

            self.assertEqual(len(delivered), 1)
            self.assertEqual(len(delivered[0]), 2)

    def test_selected_levels_are_delivered_and_duplicates_are_suppressed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            store = AlertSettingsStore(Path(temporary) / "alert_settings.json")
            store.save(_payload(levels=[2], cooldown_seconds=300, batch_seconds=0))
            delivered: list[list[dict]] = []
            completed = threading.Event()

            def sender(_config, records, _language, _test):
                delivered.append(records)
                completed.set()
                return "sent"

            service = EmailAlertService(store, sender=sender)
            try:
                self.assertEqual(service.submit([_record(3)]), 0)
                self.assertEqual(service.submit([_record(2)]), 1)
                self.assertEqual(service.submit([_record(2)]), 0)
                self.assertTrue(completed.wait(2.0))
            finally:
                service.shutdown()

            self.assertEqual(len(delivered), 1)
            self.assertEqual([row["severity"] for row in delivered[0]], [2])

    def test_disabled_configuration_never_builds_or_sends_email(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            store = AlertSettingsStore(Path(temporary) / "alert_settings.json")
            store.save(_payload(enabled=False))
            delivered = []
            service = EmailAlertService(
                store,
                sender=lambda *_args: delivered.append(True) or "sent",
            )
            try:
                self.assertEqual(service.submit([_record(2)]), 0)
            finally:
                service.shutdown()
            self.assertEqual(delivered, [])


if __name__ == "__main__":
    unittest.main()
