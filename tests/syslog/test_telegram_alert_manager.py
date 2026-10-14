from __future__ import annotations

from pathlib import Path
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

from PyQt6.QtCore import QObject, QMetaObject, QUrl
from PyQt6.QtQml import QQmlApplicationEngine, QQmlComponent
from PyQt6.QtWidgets import QApplication

from features.syslog.qt.telegram_alerts import TelegramAlertManager
from tests.syslog.test_telegram_alerts import _payload


APP_DIR = Path(__file__).resolve().parents[2]


class TelegramAlertManagerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.manager = TelegramAlertManager(
            settings_path=Path(self.temporary.name) / "telegram.json"
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
        engine.rootContext().setContextProperty("telegramAlertManager", self.manager)
        warnings = []
        engine.warnings.connect(
            lambda rows: warnings.extend(row.toString() for row in rows)
        )
        component = QQmlComponent(
            engine,
            QUrl.fromLocalFile(
                str(
                    APP_DIR
                    / "UI/qml/features/syslog/TelegramAlertSettings.qml"
                )
            ),
        )
        page = component.createWithInitialProperties({"width": 1200, "height": 1000})
        self.assertIsNotNone(page, [error.toString() for error in component.errors()])
        self.addCleanup(engine.deleteLater)
        self.addCleanup(page.deleteLater)
        self.app.processEvents()
        return engine, page, warnings

    def test_qml_saves_and_tests_unsaved_chat_id_asynchronously(self):
        self.manager.saveConfiguration(_payload(), "en")
        _engine, page, warnings = self._page()
        token = page.findChild(QObject, "telegramAlertsBotToken")
        chat_id = page.findChild(QObject, "telegramAlertsChatId")
        self.assertEqual(token.property("text"), "")
        self.assertFalse(page.property("dirty"))
        chat_id.setProperty("text", "123456")
        self.app.processEvents()
        self.assertTrue(page.property("dirty"))
        reached, release = threading.Event(), threading.Event()
        drafts = []

        def sender(config, _records, _language, _test):
            drafts.append(config)
            reached.set()
            release.wait(2)
            return "sent"

        with patch(
            "features.syslog.qt.telegram_alerts.send_telegram_message",
            side_effect=sender,
        ):
            try:
                QMetaObject.invokeMethod(page, "sendTest")
                self._wait(reached.is_set)
                self.assertTrue(page.property("testSending"))
                self.assertEqual(drafts[0].chat_id, "123456")
                self.assertEqual(self.manager.store.configuration().chat_id, "-1001234567890")
            finally:
                release.set()
            self._wait(lambda: not page.property("testSending"))
        self.assertEqual(page.property("feedbackSeverity"), "success")
        QMetaObject.invokeMethod(page, "saveConfiguration")
        self.app.processEvents()
        self.assertEqual(self.manager.store.configuration().chat_id, "123456")
        self.assertFalse(page.property("dirty"))
        self.assertEqual(warnings, [])


if __name__ == "__main__":
    unittest.main()
