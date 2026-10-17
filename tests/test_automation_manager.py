from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from PyQt6.QtCore import QCoreApplication
from PyQt6.QtTest import QSignalSpy

from features.automation.manager import AutomationManager
from features.automation.rules import sample_icmp_rule_text


class AutomationManagerSignalTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.app = QCoreApplication.instance() or QCoreApplication([])

    def test_read_slots_do_not_reemit_reload_signals(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            info_db = root / "info.db"
            info_db.touch()
            manager = AutomationManager(
                info_db=info_db,
                rules_dir=root / "rules",
            )
            rules_changed = QSignalSpy(manager.rulesChanged)
            actions_changed = QSignalSpy(manager.actionsChanged)
            try:
                self.assertEqual(manager.getRules(), [])
                self.assertEqual(manager.getActions(), [])
                self.assertEqual(len(rules_changed), 0)
                self.assertEqual(len(actions_changed), 0)

                result = manager.saveRule(sample_icmp_rule_text())
                self.assertTrue(result["ok"], result)
                self.assertEqual(len(rules_changed), 1)

                rules = manager.getRules()
                self.assertEqual(len(rules), 1)
                self.assertEqual(len(rules_changed), 1)
                self.assertIn('"version": 2', manager.sampleCliRule())
                self.assertIn('"type": "ssh.cli"', manager.sampleCliRule())
                stopped_sync = manager.syncRules()
                self.assertFalse(stopped_sync["ok"])
            finally:
                manager.shutdown()

    def test_editing_rule_id_renames_managed_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            info_db = root / "info.db"
            info_db.touch()
            manager = AutomationManager(info_db=info_db, rules_dir=root / "rules")
            try:
                created = manager.saveRule(sample_icmp_rule_text())
                edited = json.loads(sample_icmp_rule_text())
                edited["metadata"]["id"] = "edited-icmp-rule"
                result = manager.saveRule(
                    json.dumps(edited),
                    created["file_name"],
                )

                self.assertTrue(result["ok"], result)
                self.assertTrue(result["renamed"])
                self.assertEqual(
                    [item["id"] for item in manager.getRules()],
                    ["edited-icmp-rule"],
                )
            finally:
                manager.shutdown()

    def test_import_cams_rule_returns_visual_editor_reference(self) -> None:
        source = (
            Path(__file__).resolve().parents[1]
            / "templates/automation/shutdown-gigabitethernet0-3-on-icmp-flood.rule.cams"
        )
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            info_db = root / "info.db"
            info_db.touch()
            manager = AutomationManager(info_db=info_db, rules_dir=root / "rules")
            try:
                result = manager.importRule(source.as_uri())
                self.assertTrue(result["ok"], result)
                self.assertEqual(
                    result["file_name"],
                    "shutdown-gi0-3-on-icmp-flood.rule.cams",
                )
                loaded = manager.getRule(result["file_name"])
                self.assertTrue(loaded["ok"], loaded)
                self.assertIn('"interface": "GigabitEthernet0/3"', loaded["text"])
                self.assertIn('"transport": "ssh"', loaded["text"])
            finally:
                manager.shutdown()


if __name__ == "__main__":
    unittest.main()
