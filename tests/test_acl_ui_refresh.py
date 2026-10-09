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

from core.acl_slots import AclSlotsMixin
from core.database.conversion import ConversionMixin
from features.acl import get_acls
from features.acl.collector import collect_acl_tasks
from features.devices.sync import sync_device_state
from scripts.build_databases import combine_sql
from tests.test_acl_sync_regressions import SCREEN_CONFIG, ALL_CONFIG


ROOT = Path(__file__).resolve().parents[1]


class Bridge(QObject, AclSlotsMixin, ConversionMixin):
    runningConfigFinished = pyqtSignal(str, bool, str)
    runningConfigUpdated = pyqtSignal(str)

    def __init__(self, path):
        super().__init__()
        self.path, self.messages = path, []

    def _connect(self):
        conn = sqlite3.connect(self.path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys=ON")
        return conn

    @pyqtSlot(str, result="QVariant")
    def getRouterInterfaces(self, host):
        with closing(self._connect()) as conn:
            return [dict(row) for row in conn.execute("SELECT iface_id,interface_name FROM t02_interface_name WHERE host=?", (host,))]

    @pyqtSlot(str, str, str, result=bool)
    def hasPendingViewPush(self, _controller, _host, _module):
        return False

    @pyqtSlot(str, str)
    def showMessage(self, message, level):
        self.messages.append((message, level))


class AclUiRefreshTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "device.db"
        self.bridge = Bridge(self.path)
        with closing(self.bridge._connect()) as conn, conn:
            conn.executescript(combine_sql(ROOT / "infrastructure/database/schemas/device_network"))
            conn.executemany("INSERT INTO t01_devices(host,role) VALUES (?, 'rou')", [("r1",), ("r2",)])
        self.engine = QQmlEngine()
        self.engine.addImportPath(str(ROOT))
        for name in ("dbManager", "cli", "statusBar"):
            self.engine.rootContext().setContextProperty(name, self.bridge)
        self.warnings, self.items, self.components = [], [], []
        self.engine.warnings.connect(lambda rows: self.warnings.extend(row.toString() for row in rows))

    def tearDown(self):
        for item in self.items:
            item.deleteLater()
        self.engine.deleteLater()
        self.app.processEvents()
        self.temp.cleanup()

    def pump(self):
        for _ in range(30):
            self.app.processEvents()

    def create(self, name="AclView", **properties):
        component = QQmlComponent(self.engine, QUrl.fromLocalFile(str(ROOT / "UI/qml/features/acl" / (name + ".qml"))))
        self.components.append(component)
        item = component.createWithInitialProperties({"currentHostIp": "r1", "width": 1500, "height": 1000, **properties})
        self.assertIsNotNone(item, [error.toString() for error in component.errors()])
        self.items.append(item)
        self.pump()
        return item

    def evaluate(self, item, source):
        expression = QQmlExpression(QQmlEngine.contextForObject(item), item, source)
        value, undefined = expression.evaluate()
        self.assertFalse(expression.hasError(), expression.error().toString())
        self.assertFalse(undefined)
        return value.toVariant() if hasattr(value, "toVariant") else value

    def tab(self, view, name):
        view.setProperty("currentTab", name)
        loader_name = "aclBindingsLoader" if name == "Bindings" else "aclRulesLoader"
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            self.app.processEvents()
            loader = view.findChild(QObject, loader_name)
            item = loader.property("item") if loader else None
            if item is not None:
                self.pump()
                return item
        self.fail("ACL tab failed to load")

    def description_field(self, form):
        return next(item for item in form.findChildren(QObject)
                    if item.property("placeholderText") == "e.g., Block untrusted inbound traffic")

    def test_running_config_refreshes_visible_rules_and_cached_binding_catalog(self):
        view = self.create()
        rules = self.tab(view, "Extended")
        bindings = self.tab(view, "Bindings")
        self.assertEqual(self.evaluate(rules, "savedAcls.length"), 0)
        self.assertEqual(self.evaluate(bindings, "aclCatalog.length"), 0)
        sync_device_state(self.path, "r1", SCREEN_CONFIG)
        self.bridge.runningConfigFinished.emit("r2", True, "other host")
        self.bridge.runningConfigFinished.emit("r1", False, "failed")
        self.pump()
        self.assertEqual(self.evaluate(rules, "savedAcls.length"), 0)
        self.bridge.runningConfigFinished.emit("r1", True, "done")
        self.pump()
        self.assertEqual(self.evaluate(rules, "savedAcls.length"), 2)
        self.assertEqual(self.evaluate(bindings, "aclCatalog.length"), 2)
        self.assertEqual(self.evaluate(rules, "savedAcls[0].rules[0].dst_port"), "eq telnet")
        sync_device_state(self.path, "r1", SCREEN_CONFIG.replace("eq telnet", "eq ssh"))
        self.bridge.runningConfigUpdated.emit("r1")
        self.pump()
        self.assertEqual(self.evaluate(rules, "savedAcls[0].rules[0].dst_port"), "eq ssh")
        self.assertEqual(self.warnings, [])

    def test_collection_preserves_editor_draft_and_staged_deletes_cancel_restores_rows(self):
        sync_device_state(self.path, "r1", SCREEN_CONFIG)
        view = self.create()
        rules = self.tab(view, "Extended")
        self.evaluate(rules, "loadAcl(0); selectedAclId")
        field = self.description_field(rules)
        field.setProperty("text", "Unsaved draft")
        self.pump()
        self.assertTrue(rules.property("hasPendingLocalChanges"))
        self.bridge.runningConfigFinished.emit("r1", True, "done")
        self.pump()
        self.assertEqual(field.property("text"), "Unsaved draft")
        self.evaluate(rules, "clearEditor(); stageDeleteAcl(savedAcls[0].Acl_id); hasPendingDeletes")
        self.bridge.runningConfigUpdated.emit("r1")
        self.pump()
        self.assertTrue(rules.property("hasPendingDeletes"))
        self.assertEqual(len(get_acls(self.bridge, "r1", "extended")), 2)
        self.evaluate(rules, "cancelPendingDeletes(); hasPendingDeletes")
        self.assertFalse(rules.property("hasPendingDeletes"))
        self.assertEqual(self.warnings, [])

    def test_real_qml_edit_saves_nested_rule_data_and_retains_other_rules(self):
        sync_device_state(self.path, "r1", SCREEN_CONFIG)
        form = self.create("AclForm", currentAclType="Extended")
        self.evaluate(form, "loadAcl(0); selectedAclId")
        self.evaluate(form, "ruleModel.remove(1); rulesSignature()")
        self.evaluate(form, "saveAcl(); lastError")
        self.assertEqual(form.property("lastError"), "")
        acl = get_acls(self.bridge, "r1", "extended")[0]
        self.assertEqual([row["sequence"] for row in acl["rules"]], [10, 30])
        self.assertEqual(acl["rules"][0]["dst_port"], "eq telnet")
        self.assertTrue(collect_acl_tasks("r1", str(self.path)))
        self.assertEqual(self.warnings, [])

    def test_all_types_round_trip_and_evaluate_is_displayed_without_becoming_permit_rule(self):
        sync_device_state(self.path, "r1", ALL_CONFIG)
        for kind in ("Standard", "Extended", "Dynamic", "Reflexive", "MAC"):
            form = self.create("AclForm", currentAclType=kind)
            for index in range(len(get_acls(self.bridge, "r1", kind))):
                self.evaluate(form, f"loadAcl({index}); selectedAclId")
                self.evaluate(form, "saveAcl(); lastError")
                self.assertEqual(form.property("lastError"), "")
            self.assertEqual(collect_acl_tasks("r1", str(self.path)), [])
        reflexive = self.create("AclForm", currentAclType="Reflexive")
        self.evaluate(reflexive, "loadAcl(1); selectedAclId")
        self.assertIn("Evaluate", self.evaluate(reflexive, "rulesSignature()"))
        self.assertEqual(self.warnings, [])

    def test_automatic_sequence_after_rule_deletion_stays_unique_and_host_switch_isolated(self):
        sync_device_state(self.path, "r1", SCREEN_CONFIG)
        form = self.create("AclForm", currentAclType="Extended")
        self.evaluate(form, "loadAcl(0); ruleModel.remove(1); addRule(); rulesSignature()")
        sequences = self.evaluate(form, "JSON.parse(rulesSignature()).map(function(row) {return row[0]})")
        self.assertEqual(sequences, [10, 30, 20])
        form.setProperty("currentHostIp", "r2")
        self.pump()
        self.assertEqual(self.evaluate(form, "savedAcls.length"), 0)
        self.assertFalse(form.property("hasPendingLocalChanges"))
        form.setProperty("currentHostIp", "r1")
        self.pump()
        self.assertEqual(self.evaluate(form, "savedAcls.length"), 2)
        self.assertEqual(self.warnings, [])

    def test_qml_rule_changes_save_for_all_five_types_including_evaluate_only(self):
        for kind, index, removed in (("Standard", 0, 1), ("Extended", 0, 1), ("Dynamic", 0, 0),
                                     ("Reflexive", 1, 1), ("MAC", 0, 1)):
            sync_device_state(self.path, "r1", ALL_CONFIG, mode="force_device_state")
            before = get_acls(self.bridge, "r1", kind)[index]
            form = self.create("AclForm", currentAclType=kind)
            self.evaluate(form, f"loadAcl({index}); ruleModel.remove({removed}); saveAcl(); lastError")
            self.assertEqual(form.property("lastError"), "", kind)
            after = get_acls(self.bridge, "r1", kind)[index]
            self.assertEqual(len(after["rules"]), len(before["rules"]) - 1, kind)
            if kind == "Reflexive":
                self.assertEqual(after["rules"][0]["protocol"], "evaluate")
            if kind == "Dynamic":
                self.assertEqual(after["rules"][0]["timeout_seconds"], 300)
        self.assertEqual(self.warnings, [])

    def test_qml_acl_rename_is_a_dirty_change_and_queues_old_acl_removal(self):
        from features.acl.worker import render_acl_payload
        sync_device_state(self.path, "r1", SCREEN_CONFIG)
        form = self.create("AclForm", currentAclType="Extended")
        self.evaluate(form, "loadAcl(0); selectedAclId")
        field = next(item for item in form.findChildren(QObject)
                     if item.property("placeholderText") == "e.g., ACL_INBOUND")
        field.setProperty("text", "RENAMED")
        self.pump()
        self.assertTrue(form.property("hasPendingLocalChanges"))
        self.evaluate(form, "saveAcl(); lastError")
        self.assertEqual(form.property("lastError"), "")
        commands = [command for task in collect_acl_tasks("r1", str(self.path)) for command in render_acl_payload(task)]
        self.assertIn("no ip access-list extended ACL_V10_NO_TELNET_R2", commands)
        self.assertIn("ip access-list extended RENAMED", commands)
        self.assertIn("ip access-group RENAMED in", commands)
        self.assertEqual(self.warnings, [])

    def test_dynamic_entry_without_absolute_timeout_preserves_optional_value_on_qml_save(self):
        from features.acl.worker import render_acl_payload
        sync_device_state(self.path, "r1", ALL_CONFIG.replace("dynamic LOGIN timeout 5", "dynamic LOGIN"))
        form = self.create("AclForm", currentAclType="Dynamic")
        self.evaluate(form, "loadAcl(0); ruleModel.remove(0); saveAcl(); lastError")
        self.assertEqual(form.property("lastError"), "")
        rule = get_acls(self.bridge, "r1", "dynamic")[0]["rules"][0]
        self.assertIsNone(rule["timeout_seconds"])
        commands = [command for task in collect_acl_tasks("r1", str(self.path)) for command in render_acl_payload(task)]
        self.assertIn("20 dynamic LOGIN permit ip any any log", commands)
        self.assertEqual(self.warnings, [])


if __name__ == "__main__":
    unittest.main()
