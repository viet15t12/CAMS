"""Pinned toolchain integrity checks without downloads or rendering."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from scripts import provision_typst as tooling


class TypstToolingTests(unittest.TestCase):
    def test_corrupt_cached_archive_fails_before_execution_or_download(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            lock = root / "lock.json"
            lock.write_text(json.dumps({"archives": [{"name": "typst", "sha256": "0" * 64}]}))
            cache = root / "cache"
            cache.mkdir()
            (cache / ("typst-" + "0" * 64)).write_bytes(b"corrupted")
            with patch.object(tooling, "LOCK", lock), patch.object(tooling.urllib.request, "urlopen") as download, patch.object(tooling.subprocess, "check_output") as execute:
                with self.assertRaisesRegex(ValueError, "checksum mismatch"):
                    tooling.provision(root / "install", cache)
                download.assert_not_called()
                execute.assert_not_called()
                self.assertFalse((root / "install").exists())

    def test_modified_or_unmanaged_installed_font_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "fonts").mkdir()
            font = root / "fonts/font.ttf"
            font.write_bytes(b"verified-font")
            lock = root / "lock.json"
            lock.write_text(json.dumps({"typst_version": "0.14.2", "archives": [{"files": {"source": "fonts/font.ttf"}}]}))
            (root / "installed.json").write_text(json.dumps({"lock_sha256": tooling.sha(lock), "files": {"fonts/font.ttf": tooling.sha(font)}}))
            with patch.object(tooling, "LOCK", lock), patch.object(tooling.subprocess, "check_output", return_value="typst 0.14.2 (hash)"):
                tooling.verify_toolchain(root)
                font.write_bytes(b"modified")
                with self.assertRaisesRegex(ValueError, "file changed"):
                    tooling.verify_toolchain(root)
                font.write_bytes(b"verified-font")
                (root / "fonts/unmanaged.ttf").write_bytes(b"injected")
                with self.assertRaisesRegex(ValueError, "Unmanaged"):
                    tooling.verify_toolchain(root)

    def test_wrong_compiler_version_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            lock = root / "lock.json"
            lock.write_text(json.dumps({"typst_version": "0.14.2", "archives": []}))
            (root / "installed.json").write_text(json.dumps({"lock_sha256": tooling.sha(lock), "files": {}}))
            with patch.object(tooling, "LOCK", lock), patch.object(tooling.subprocess, "check_output", return_value="typst 0.13.1"):
                with self.assertRaisesRegex(ValueError, "Wrong Typst version"):
                    tooling.verify_toolchain(root)


if __name__ == "__main__":
    unittest.main()
