from __future__ import annotations

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
            finally:
                manager.shutdown()


if __name__ == "__main__":
    unittest.main()
