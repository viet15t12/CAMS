from __future__ import annotations

import os
import unittest
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt6.QtCore import QObject, QUrl, pyqtSignal, pyqtSlot
from PyQt6.QtQml import QQmlComponent, QQmlEngine, QQmlExpression
from PyQt6.QtWidgets import QApplication


class _Backend(QObject):
    runningConfigUpdated = pyqtSignal(str)
    runningConfigFinished = pyqtSignal(str, bool, str)

    def __init__(self):
        super().__init__()
        self.rows = []

    @pyqtSlot(str, result="QVariant")
    def getDhcpPools(self, _host):
        return self.rows


class DhcpPoolUiRefreshTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

    def setUp(self):
        root = Path(__file__).resolve().parents[1]
        self.engine = QQmlEngine()
        self.engine.addImportPath(str(root))
        self.backend = _Backend()
        self.engine.rootContext().setContextProperty("dbManager", self.backend)
        self.engine.rootContext().setContextProperty("cli", self.backend)
        self.warnings = []
        self.engine.warnings.connect(lambda rows: self.warnings.extend(row.toString() for row in rows))
        self.component = QQmlComponent(self.engine, QUrl.fromLocalFile(
            str(root / "UI/qml/features/dhcp/DhcpPoolForm.qml")
        ))
        self.page = self.component.createWithInitialProperties({"currentHostIp": "r1"})
        self.assertIsNotNone(self.page, [error.toString() for error in self.component.errors()])

    def tearDown(self):
        self.page.deleteLater()
        self.engine.deleteLater()
        self.app.processEvents()

    def evaluate(self, source):
        expression = QQmlExpression(QQmlEngine.contextForObject(self.page), self.page, source)
        value, undefined = expression.evaluate()
        self.assertFalse(expression.hasError(), expression.error().toString())
        self.assertFalse(undefined)
        return value.toVariant() if hasattr(value, "toVariant") else value

    def observed_pool(self, name="VLAN10"):
        self.backend.rows = [{
            "dhcp_id": 1, "host": "r1", "pool": name,
            "network": "192.168.10.0", "subnetmask": "255.255.255.0",
            "defaut": "192.168.10.1", "dns": "8.8.8.8", "lease": "1",
            "sync_status": "synchronized", "action_Cfg": "000",
        }]

    def test_get_running_config_refreshes_only_on_success_for_current_host(self):
        self.assertEqual(self.evaluate("poolListModel.count"), 0)
        self.observed_pool()
        self.backend.runningConfigFinished.emit("r2", True, "done")
        self.backend.runningConfigFinished.emit("r1", False, "failed")
        self.assertEqual(self.evaluate("poolListModel.count"), 0)
        self.backend.runningConfigFinished.emit("r1", True, "done")
        self.assertEqual(self.evaluate("poolListModel.get(0).pool"), "VLAN10")
        self.observed_pool("UPDATED")
        self.backend.runningConfigUpdated.emit("r2")
        self.assertEqual(self.evaluate("poolListModel.get(0).pool"), "VLAN10")
        self.backend.runningConfigUpdated.emit("r1")
        self.assertEqual(self.evaluate("poolListModel.get(0).pool"), "UPDATED")
        self.assertEqual(self.warnings, [])

    def test_refresh_preserves_staged_rows_and_partial_form_input(self):
        self.evaluate("poolField.text = 'LOCAL'; networkField.text = '192.168.20.0'; "
                      "subnetField.text = '255.255.255.0'; stagePool(); poolListModel.count")
        self.observed_pool()
        self.backend.runningConfigFinished.emit("r1", True, "done")
        self.assertEqual(self.evaluate("poolListModel.get(0).pool"), "LOCAL")
        self.assertTrue(self.page.property("hasPendingLocalChanges"))
        self.evaluate("cancelChanges(); poolListModel.count")
        self.assertEqual(self.evaluate("poolListModel.get(0).pool"), "VLAN10")
        self.evaluate("dnsField.text = '9.9.9.9'; dnsField.text")
        self.observed_pool("UPDATED")
        self.backend.runningConfigUpdated.emit("r1")
        self.assertEqual(self.evaluate("dnsField.text"), "9.9.9.9")
        self.assertEqual(self.evaluate("poolListModel.get(0).pool"), "VLAN10")
        self.assertEqual(self.warnings, [])

    def test_refresh_preserves_open_editor_and_staged_deletion(self):
        self.observed_pool()
        self.backend.runningConfigUpdated.emit("r1")
        self.evaluate("editPool(0, poolListModel.get(0)); editingDhcpId")
        self.observed_pool("UPDATED")
        self.backend.runningConfigUpdated.emit("r1")
        self.assertEqual(self.evaluate("poolField.text"), "VLAN10")
        self.assertEqual(self.page.property("editingDhcpId"), 1)
        self.evaluate("clearForm(); removePool(0, poolListModel.get(0)); poolListModel.count")
        self.backend.runningConfigFinished.emit("r1", True, "done")
        self.assertEqual(self.evaluate("poolListModel.count"), 0)
        self.assertEqual(self.evaluate("pendingDeletes"), [1])
        self.assertEqual(self.warnings, [])


if __name__ == "__main__":
    unittest.main()
