from __future__ import annotations

import json
from pathlib import Path
import smtplib
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

from PyQt6.QtCore import QObject, QMetaObject, QUrl
from PyQt6.QtQml import QQmlApplicationEngine, QQmlComponent
from PyQt6.QtWidgets import QApplication

from features.syslog.qt.alerts import EmailAlertManager
from tests.syslog.test_email_alerts import _payload


APP_DIR = Path(__file__).resolve().parents[2]


class EmailAlertManagerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.manager = EmailAlertManager(
            settings_path=Path(self.temporary.name) / "alerts.json"
        )
        self.addCleanup(self.manager.shutdown)

    def _wait(self, predicate):
        deadline = time.monotonic() + 2
        while not predicate() and time.monotonic() < deadline:
            self.app.processEvents()
            threading.Event().wait(0.005)
        self.app.processEvents()
        self.assertTrue(predicate())

    def _page(self):
        engine = QQmlApplicationEngine()
        engine.addImportPath(str(APP_DIR))
        engine.rootContext().setContextProperty("emailAlertManager", self.manager)
        warnings = []
        engine.warnings.connect(lambda rows: warnings.extend(row.toString() for row in rows))
        component = QQmlComponent(
            engine, QUrl.fromLocalFile(str(APP_DIR / "UI/qml/features/syslog/EmailAlertSettings.qml"))
        )
        page = component.createWithInitialProperties({"width": 1200, "height": 1000})
        self.assertIsNotNone(page, [error.toString() for error in component.errors()])
        self.addCleanup(engine.deleteLater)
        self.addCleanup(page.deleteLater)
        self.app.processEvents()
        return engine, page, warnings

    def test_qml_saves_security_and_tests_the_unsaved_draft_asynchronously(self):
        self.manager.saveConfiguration(_payload(), "en")
        engine, page, warnings = self._page()
        port = page.findChild(QObject, "emailAlertsSmtpPort")
        security = page.findChild(QObject, "emailAlertsSmtpSecurity")
        password = page.findChild(QObject, "emailAlertsAppPassword")
        self.assertEqual(security.property("currentValue"), "auto")
        self.assertEqual(password.property("text"), "")
        self.assertFalse(page.property("dirty"))
        port.setProperty("value", 587)
        security.setProperty("currentIndex", 2)
        self.app.processEvents()
        self.assertTrue(page.property("dirty"))
        reached, release = threading.Event(), threading.Event()
        drafts = []

        def sender(config, _records, _language, _test):
            drafts.append(config)
            reached.set()
            release.wait(2)
            return "sent"

        with patch("features.syslog.qt.alerts.send_smtp_message", side_effect=sender):
            try:
                QMetaObject.invokeMethod(page, "sendTest")
                self._wait(reached.is_set)
                self.assertTrue(page.property("testSending"))
                self.assertFalse(page.findChild(QObject, "emailAlertsTestButton").property("enabled"))
                self.assertEqual(drafts[0].smtp_port, 587)
                self.assertEqual(drafts[0].transport_security, "starttls")
                self.assertEqual(drafts[0].sender_app_password, "abcdefghijklmnop")
                self.assertEqual(self.manager.store.configuration().smtp_port, 465)
                # A rebuilt page must still show the pending test and prevent duplicates.
                _, reopened, reopened_warnings = self._page()
                self.assertTrue(reopened.property("testSending"))
                QMetaObject.invokeMethod(reopened, "sendTest")
                self.assertEqual(len(drafts), 1)
                self.assertEqual(reopened_warnings, [])
            finally:
                release.set()
            self._wait(lambda: not page.property("testSending"))
        self.assertEqual(page.property("feedbackSeverity"), "success")
        self.assertTrue(page.property("dirty"))
        QMetaObject.invokeMethod(page, "saveConfiguration")
        self.app.processEvents()
        saved = self.manager.store.configuration()
        self.assertEqual(saved.smtp_port, 587)
        self.assertEqual(saved.smtp_security, "starttls")
        self.assertFalse(page.property("dirty"))
        self.assertNotIn("abcdefghijklmnop", json.dumps(self.manager.loadConfiguration()))
        self.assertEqual(warnings, [])

    def test_qml_displays_specific_smtp_error_and_reenables_retry(self):
        self.manager.saveConfiguration(_payload(), "en")
        engine, page, warnings = self._page()
        with patch("features.syslog.qt.alerts.send_smtp_message",
                   side_effect=smtplib.SMTPDataError(554, b"abcdefghijklmnop")):
            QMetaObject.invokeMethod(page, "sendTest")
            self._wait(lambda: "554" in str(page.property("feedbackMessage")))
        self.assertFalse(page.property("testSending"))
        self.assertEqual(page.property("feedbackSeverity"), "error")
        self.assertTrue(page.findChild(QObject, "emailAlertsTestButton").property("enabled"))
        self.assertNotIn("abcdefghijklmnop", page.property("feedbackMessage"))
        self.assertEqual(warnings, [])

    def test_backend_prevents_concurrent_test_requests_and_shutdown_submission(self):
        reached, release = threading.Event(), threading.Event()
        results = []
        self.manager.testEmailFinished.connect(lambda ok, message: results.append((ok, message)))

        def sender(*_args):
            reached.set()
            release.wait(2)
            return "sent"

        with patch("features.syslog.qt.alerts.send_smtp_message", side_effect=sender) as mocked:
            try:
                self.assertTrue(self.manager.sendTestEmail(_payload(), "en")["ok"])
                self._wait(reached.is_set)
                second = self.manager.sendTestEmail(_payload(), "vi")
                self.assertFalse(second["ok"])
                self.assertIn("đang được gửi", second["message"])
            finally:
                release.set()
            self._wait(lambda: len(results) == 1)
            mocked.assert_called_once()
        self.manager.shutdown()
        self.assertFalse(self.manager.sendTestEmail(_payload(), "en")["ok"])
        self.assertFalse(self.manager.testSending)

    def test_invalid_security_and_storage_failure_are_returned_without_sending(self):
        result = self.manager.sendTestEmail(_payload(smtp_security="plain"), "vi")
        self.assertFalse(result["ok"])
        self.assertIn("smtp_security", result["errors"])
        self.assertIn("Chọn", result["message"])
        with patch.object(self.manager.store, "_write", side_effect=PermissionError("secret")):
            result = self.manager.saveConfiguration(_payload(), "vi")
        self.assertFalse(result["ok"])
        self.assertNotIn("secret", result["message"])
        self.assertFalse(self.manager.store.configuration().enabled)

    def test_automatic_delivery_errors_are_visible_on_the_settings_page(self):
        self.manager.saveConfiguration(_payload(), "en")
        engine, page, warnings = self._page()
        self.manager.alertError.emit("smtp.gmail.com:465: SMTP 535 sign-in failed")
        self.app.processEvents()
        self.assertIn("535", page.property("feedbackMessage"))
        self.assertEqual(page.property("feedbackSeverity"), "error")
        self.assertEqual(warnings, [])


if __name__ == "__main__":
    unittest.main()
