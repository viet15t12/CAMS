from __future__ import annotations

import os
import sqlite3
import tempfile
import time
import unittest
from contextlib import closing
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
import main as _bootstrap  # noqa: F401
from PyQt6.QtCore import QObject, QUrl, pyqtSignal, pyqtSlot
from PyQt6.QtQml import QQmlComponent, QQmlEngine, QQmlExpression
from PyQt6.QtWidgets import QApplication

from core.database.conversion import ConversionMixin
from core.database.routing_slots import RoutingSlotsMixin
from features.devices.sync import sync_device_state
from features.routing.eigrp import get_eigrp_routing
from features.routing.ospf import get_ospf_routing
from scripts.build_databases import combine_sql
from tests.test_routing_regressions import CONFIG


ROOT = Path(__file__).resolve().parents[1]


class _Bridge(QObject, RoutingSlotsMixin, ConversionMixin):
    runningConfigFinished = pyqtSignal(str, bool, str)
    runningConfigUpdated = pyqtSignal(str)

    def __init__(self, path):
        super().__init__()
        self.path, self._last_routing_error, self.messages = path, "", []

    def _connect(self):
        conn = sqlite3.connect(self.path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        return conn

    @pyqtSlot(str, result="QVariant")
    def getRouterInterfaces(self, host):
        with closing(self._connect()) as conn:
            return [dict(row) for row in conn.execute(
                "SELECT interface_name FROM t02_interface_name WHERE host=?", (host,))]

    @pyqtSlot(str, str, str, result=bool)
    def hasPendingViewPush(self, _controller, _host, _module):
        return False

    @pyqtSlot(str, str)
    def showMessage(self, message, level):
        self.messages.append((message, level))

    @pyqtSlot(result="QVariant")
    def getRoutingGroupOptions(self):
        return {"hosts": []}


class RoutingUiRegressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "device.db"
        self.bridge = _Bridge(self.path)
        with closing(self.bridge._connect()) as conn, conn:
            conn.executescript(combine_sql(ROOT / "infrastructure/database/schemas/device_network"))
            conn.executemany("INSERT INTO t01_devices(host,role) VALUES (?, 'rou')", [("r1",), ("r2",)])
        sync_device_state(self.path, "r1", CONFIG)
        sync_device_state(self.path, "r2", CONFIG.replace("router ospf 10", "router ospf 20")
                          .replace("ip ospf 10", "ip ospf 20").replace("eigrp 100", "eigrp 200"))
        self.engine = QQmlEngine()
        self.engine.addImportPath(str(ROOT))
        for name in ("dbManager", "cli", "statusBar"):
            self.engine.rootContext().setContextProperty(name, self.bridge)
        self.warnings = []
        self.engine.warnings.connect(lambda rows: self.warnings.extend(row.toString() for row in rows))
        self.objects, self.components = [], []

    def tearDown(self):
        for item in self.objects:
            item.deleteLater()
        self.engine.deleteLater()
        self.app.processEvents()
        self.temp.cleanup()

    def pump(self, count=20):
        for _ in range(count):
            self.app.processEvents()

    def create(self, source):
        component = QQmlComponent(self.engine, QUrl.fromLocalFile(str(ROOT / source)))
        self.components.append(component)
        item = component.createWithInitialProperties({"currentHostIp": "r1", "width": 1400, "height": 900})
        self.assertIsNotNone(item, [error.toString() for error in component.errors()])
        self.objects.append(item)
        self.pump()
        return item

    def evaluate(self, item, source):
        expression = QQmlExpression(QQmlEngine.contextForObject(item), item, source)
        value, undefined = expression.evaluate()
        self.assertFalse(expression.hasError(), expression.error().toString())
        self.assertFalse(undefined)
        return value.toVariant() if hasattr(value, "toVariant") else value

    def activate(self, view, tab):
        names = {"Static": "routingStaticLoader", "Default": "routingDefaultLoader",
                 "OSPF": "routingOspfLoader", "EIGRP": "routingEigrpLoader"}
        view.setProperty("currentTab", tab)
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            self.app.processEvents()
            loader = view.findChild(QObject, names[tab])
            item = loader.property("item") if loader else None
            if item is not None and not item.property("isLoading"):
                self.pump()
                return item
        self.fail(f"{tab} loader did not finish")

    def test_ospf_remove_message_uses_snapshot_and_cancel_restores_process(self):
        form = self.create("UI/qml/features/routing/ospf/OspfRoutingForm.qml")
        self.evaluate(form, "removeProcessByUid(processItems()[0].modelUid); processCount")
        self.pump()
        self.assertEqual(form.property("processCount"), 0)
        self.assertTrue(form.property("hasPendingLocalChanges"))
        messages = [message for message, _ in self.bridge.messages if "Removed OSPF" in message]
        self.assertEqual(messages, ["Removed OSPF process 1 from the local editor."])
        self.assertEqual(len(get_ospf_routing(self.bridge, "r1")["processes"]), 1)
        self.evaluate(form, "cancelAllChanges()")
        self.pump()
        self.assertEqual(form.property("processCount"), 1)
        self.assertFalse(form.property("hasPendingLocalChanges"))
        self.assertEqual(self.warnings, [])

    def test_ospf_remove_one_of_two_keeps_other_draft_and_saves_correct_process(self):
        form = self.create("UI/qml/features/routing/ospf/OspfRoutingForm.qml")
        self.evaluate(form, "addEmptyProcess(); processCount")
        self.pump()
        self.evaluate(form, "processItems()[1].processId = '30'; processItems()[1].routerId = '3.3.3.3'; "
                      "removeProcessByUid(processItems()[0].modelUid); processCount")
        self.pump()
        self.assertEqual(self.evaluate(form, "processItems()[0].processId"), "30")
        self.assertTrue(self.evaluate(form, "saveToDatabase()"))
        self.pump()
        self.assertEqual([row["process_id"] for row in get_ospf_routing(self.bridge, "r1")["processes"]], [30])
        self.assertFalse(form.property("hasPendingLocalChanges"))
        self.assertEqual(self.warnings, [])

    def test_process_forms_survive_rapid_host_switch_and_empty_host(self):
        for protocol, field, expected in (("ospf", "process_id", 20), ("eigrp", "as_number", 200)):
            with self.subTest(protocol=protocol):
                name = "Ospf" if protocol == "ospf" else "Eigrp"
                form = self.create(f"UI/qml/features/routing/{protocol}/{name}RoutingForm.qml")
                form.setProperty("currentHostIp", "r2")
                form.setProperty("currentHostIp", "")
                self.pump()
                self.assertFalse(form.property("isLoading"))
                self.assertEqual(form.property("processCount"), 0)
                form.setProperty("currentHostIp", "r2")
                self.pump()
                self.assertEqual(int(self.evaluate(form, "processItems()[0].processId")), expected)
                self.assertFalse(form.property("hasPendingLocalChanges"))
        self.assertEqual(self.warnings, [])

    def test_eigrp_qml_round_trip_and_invalid_process_input_are_atomic(self):
        form = self.create("UI/qml/features/routing/eigrp/EigrpRoutingForm.qml")
        self.assertTrue(self.evaluate(form, "saveToDatabase()"))
        self.pump()
        process = get_eigrp_routing(self.bridge, "r1")["processes"][0]
        self.assertEqual(process["sync_status"], "synchronized")
        self.assertEqual(len(process["distribute_lists"]), 1)
        self.assertEqual(len(process["offset_lists"]), 1)
        self.assertEqual(len(process["key_chains"]), 1)
        self.evaluate(form, "processItems()[0].processId = '100oops'; processItems()[0].processId")
        self.assertFalse(self.evaluate(form, "saveToDatabase()"))
        self.assertEqual(get_eigrp_routing(self.bridge, "r1")["processes"][0]["as_number"], 100)
        self.assertEqual(self.warnings, [])

    def test_eigrp_qml_preserves_zero_key_id_on_noop_save(self):
        sync_device_state(self.path, "r1", CONFIG.replace(" key 1", " key 0"))
        form = self.create("UI/qml/features/routing/eigrp/EigrpRoutingForm.qml")
        self.assertTrue(self.evaluate(form, "saveToDatabase()"))
        self.pump()
        process = get_eigrp_routing(self.bridge, "r1")["processes"][0]
        self.assertEqual(process["key_chains"][0]["key_id"], 0)
        self.assertEqual(process["key_chains"][0]["sync_status"], "synchronized")
        self.assertEqual(self.warnings, [])

    def test_collection_refreshes_all_cached_routing_tabs_and_preserves_drafts(self):
        view = self.create("UI/qml/features/routing/RoutingView.qml")
        forms = {tab: self.activate(view, tab) for tab in ("Static", "Default", "OSPF", "EIGRP")}
        self.evaluate(forms["OSPF"], "processItems()[0].routerId = '9.9.9.9'; processItems()[0].routerId")
        self.pump()
        changed = CONFIG.replace("eigrp router-id 2.2.2.2", "eigrp router-id 4.4.4.4")
        changed += "ip route 203.0.113.0 255.255.255.0 10.0.0.3\nip route 0.0.0.0 0.0.0.0 10.0.0.3\n"
        sync_device_state(self.path, "r1", changed)
        self.bridge.runningConfigFinished.emit("r2", True, "done")
        self.bridge.runningConfigFinished.emit("r1", False, "failed")
        self.pump()
        self.assertEqual(self.evaluate(forms["EIGRP"], "processItems()[0].routerId"), "2.2.2.2")
        self.bridge.runningConfigFinished.emit("r1", True, "done")
        self.pump()
        self.assertEqual(self.evaluate(forms["EIGRP"], "processItems()[0].routerId"), "4.4.4.4")
        self.assertEqual(self.evaluate(forms["OSPF"], "processItems()[0].routerId"), "9.9.9.9")
        self.assertEqual(self.evaluate(forms["Static"], "buildRoutesPayload(false).length"), 2)
        self.assertEqual(self.evaluate(forms["Default"], "JSON.parse(signature()).length"), 2)
        changed = changed.replace("eigrp router-id 4.4.4.4", "eigrp router-id 5.5.5.5")
        sync_device_state(self.path, "r1", changed)
        self.bridge.runningConfigUpdated.emit("r1")
        self.pump()
        self.assertEqual(self.evaluate(forms["EIGRP"], "processItems()[0].routerId"), "5.5.5.5")
        self.assertEqual(self.warnings, [])


if __name__ == "__main__":
    unittest.main()
