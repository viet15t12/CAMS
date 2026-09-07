from __future__ import annotations

import os
import unittest
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt6.QtCore import QProcess
from PyQt6.QtWidgets import QApplication

from core.update_manager import UpdateManager


class UpdateManagerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.app = QApplication.instance() or QApplication([])

    def test_background_check_announces_available_update_once(self) -> None:
        manager = UpdateManager()
        manager._busy = True
        manager._operation = "check"
        manager._output.extend(
            b"CAMS_UPDATE_CURRENT=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n"
            b"CAMS_UPDATE_LATEST=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n"
            b"CAMS_UPDATE_STATUS=available\n"
        )

        with patch.object(manager, "_drain_output"):
            manager._on_finished(0, QProcess.ExitStatus.NormalExit)

        self.assertTrue(manager.updateAvailable)
        self.assertTrue(manager.notificationPending)
        self.assertEqual(manager.latestVersion, "bbbbbbbbbbbb")
        self.assertTrue(manager.claimUpdateNotification())
        self.assertFalse(manager.notificationPending)
        self.assertFalse(manager.claimUpdateNotification())
        manager.shutdown()


if __name__ == "__main__":
    unittest.main()
