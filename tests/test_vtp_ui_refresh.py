import unittest
from pathlib import Path

from PyQt6.QtCore import QObject, QUrl, pyqtSignal, pyqtSlot
from PyQt6.QtQml import QQmlComponent, QQmlEngine, QQmlExpression
from PyQt6.QtWidgets import QApplication


class _Backend(QObject):
    runningConfigUpdated = pyqtSignal(str)

    def __init__(self):
        super().__init__()
        self.rows = [{"id": 1, "vlan_id": 1, "vlan_name": "default", "state": "active", "success": "synchronized"}]

    @pyqtSlot(str, result="QVariant")
    def getSwitchVlans(self, _host):
        return self.rows

    @pyqtSlot(str, str, str, result=bool)
    def hasPendingViewPush(self, _controller, _host, _module):
        return False


class VtpUiRefreshTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

    def test_client_vlan_page_refreshes_on_host_signal_and_preserves_editor(self):
        root = Path(__file__).resolve().parents[1]
        engine = QQmlEngine()
        engine.addImportPath(str(root))
        backend = _Backend()
        engine.rootContext().setContextProperty("dbManager", backend)
        warnings = []
        engine.warnings.connect(lambda rows: warnings.extend(row.toString() for row in rows))
        component = QQmlComponent(engine, QUrl.fromLocalFile(str(root / "UI/qml/features/switching/switching/VlanPage.qml")))
        page = component.createWithInitialProperties({"host": "client"})
        self.assertIsNotNone(page, [error.toString() for error in component.errors()])
        def count():
            value, undefined = QQmlExpression(engine.rootContext(), page, "allRows.length").evaluate()
            self.assertFalse(undefined)
            return value
        try:
            self.assertEqual(count(), 1)
            backend.rows = [*backend.rows, {"id": 2, "vlan_id": 10, "vlan_name": "users", "success": "synchronized"}]
            backend.runningConfigUpdated.emit("other")
            self.assertEqual(count(), 1)
            backend.runningConfigUpdated.emit("client")
            self.app.processEvents()
            self.assertEqual(count(), 2)
            page.setProperty("formMode", 2)
            page.setProperty("draftData", {"id": 2, "vlan_name": "unsaved"})
            backend.rows = backend.rows[:1]
            backend.runningConfigUpdated.emit("client")
            self.app.processEvents()
            self.assertEqual(count(), 2)
            draft = page.property("draftData")
            draft = draft.toVariant() if hasattr(draft, "toVariant") else draft
            self.assertEqual(draft["vlan_name"], "unsaved")
            page.setProperty("formMode", 0)
            self.app.processEvents()
            self.assertEqual(count(), 1)
            self.assertEqual(warnings, [])
        finally:
            page.deleteLater()
            engine.deleteLater()
