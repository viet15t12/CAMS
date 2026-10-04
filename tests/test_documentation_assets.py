"""Transitional manifest, frozen evidence and generated-stage boundary tests."""
from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.documentation_assets import (AssetError, LEDGER, STAGE_ROOT, digest,
    validate_manifest, validate_references)
from scripts.sync_documentation_assets import sync


class DocumentationAssetTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "documentation_assets").mkdir()
        self.contract = {"version": 1, "assets": [], "references": []}
        self.write_contract()
        source = self.root / "00_book/figures/example.png"
        source.parent.mkdir(parents=True)
        source.write_bytes(b"lossless source fixture bytes")
        self.record = dict(id="ui.core.example", asset_class="ui", source_kind="unknown",
            migration_state="pending", migration_role="canonical", canonical_migration=True,
            canonical=False, current_path="00_book/figures/example.png", path="00_book/figures/example.png",
            planned_canonical_path="documentation_assets/ui/core/example.png", sha256=digest(source),
            mkdocs_stage=True, mkdocs_stage_path="00_book/assets/ui/core/example.png",
            original_evidence=False, preserve_original=False, review_required=False, targets=["book-mkdocs"],
            derived_from=None, recreates_evidence_asset=None, canonical_group_id=None,
            reconstruction_method=None, reconstruction_confidence=None, generator_command=None)
        self.data = {"manifest_version": 1, "assets": [self.record]}

    def write_contract(self):
        (self.root / "documentation_assets/terminal-freeze.json").write_text(json.dumps(self.contract))

    def test_pending_source_stages_losslessly_and_repeatably(self):
        self.assertEqual(validate_manifest(self.data, self.root), [])
        self.assertFalse((self.root / self.record["planned_canonical_path"]).exists())
        self.assertTrue(sync(self.data, self.root, dry_run=True))
        self.assertFalse((self.root / STAGE_ROOT).exists())
        self.assertTrue(sync(self.data, self.root, check=True))
        sync(self.data, self.root)
        destination = self.root / self.record["mkdocs_stage_path"]
        self.assertEqual(destination.read_bytes(), (self.root / self.record["current_path"]).read_bytes())
        before = (self.root / STAGE_ROOT / LEDGER).read_bytes()
        self.assertEqual(sync(self.data, self.root, check=True), [])
        self.assertEqual(sync(self.data, self.root), [])
        self.assertEqual((self.root / STAGE_ROOT / LEDGER).read_bytes(), before)

    def test_current_hash_mismatch_prevents_any_staging(self):
        (self.root / self.record["current_path"]).write_bytes(b"changed source")
        with self.assertRaisesRegex(AssetError, "SHA mismatch"):
            sync(self.data, self.root)
        self.assertFalse((self.root / STAGE_ROOT).exists())

    def test_duplicates_casefold_and_traversal_rejected(self):
        for edit in [dict(id=self.record["id"]),
                     dict(id="ui.core.other", planned_canonical_path="documentation_assets/ui/Core/example.png", mkdocs_stage_path="00_book/assets/ui/Core/example.png")]:
            data = copy.deepcopy(self.data)
            data["assets"].append({**self.record, **edit})
            self.assertTrue(validate_manifest(data, self.root))
        for bad in ["../outside.png", "/outside.png", "00_book/../outside.png", "C:\\outside.png"]:
            data = copy.deepcopy(self.data)
            data["assets"][0]["current_path"] = bad
            self.assertTrue(validate_manifest(data, self.root))

    def test_migrated_requires_current_canonical_file(self):
        self.record.update(migration_state="migrated", canonical=True,
                           current_path=self.record["planned_canonical_path"], path=self.record["planned_canonical_path"])
        self.assertTrue(validate_manifest(self.data, self.root))
        path = self.root / self.record["current_path"]
        path.parent.mkdir(parents=True)
        path.write_bytes(b"lossless source fixture bytes")
        self.assertEqual(validate_manifest(self.data, self.root), [])

    def test_unresolved_pending_target_is_explicit_review_only(self):
        self.record.update(planned_canonical_path=None, mkdocs_stage=False, mkdocs_stage_path=None,
                           targets=[], review_required=True, status="unresolved", unresolved_reason="Review state")
        self.assertEqual(validate_manifest(self.data, self.root), [])
        self.record["review_required"] = False
        self.assertTrue(validate_manifest(self.data, self.root))

    def test_frozen_external_record_cannot_transfer_or_stage(self):
        a = self.record
        a.update(id="terminal.capture.example", asset_class="terminal-evidence", source_kind="terminal-capture",
            migration_state="frozen", migration_role="frozen", canonical_migration=False,
            planned_canonical_path=None, mkdocs_stage=False, mkdocs_stage_path=None,
            original_evidence=True, preserve_original=True, targets=["book-mkdocs"])
        self.contract["assets"] = [dict(id=a["id"], path=a["current_path"], sha256=a["sha256"])]
        self.write_contract()
        self.assertEqual(validate_manifest(self.data, self.root), [])
        self.assertFalse(sync(self.data, self.root, dry_run=True) == [])  # ledger initialization only
        for changes in [dict(migration_state="pending", canonical_migration=True), dict(mkdocs_stage=True),
                        dict(source_kind="reconstructed-terminal"), dict(reconstruction_method="transcribe")]:
            data = copy.deepcopy(self.data)
            data["assets"][0].update(changes)
            self.assertTrue(validate_manifest(data, self.root))
        self.assertTrue(validate_manifest({"manifest_version": 1, "assets": []}, self.root))

    def test_dangling_links_and_cycles_rejected(self):
        self.record["derived_from"] = "missing.asset"
        self.assertTrue(validate_manifest(self.data, self.root))
        self.record["derived_from"] = "ui.core.second"
        other = {**self.record, "id": "ui.core.second", "planned_canonical_path": "documentation_assets/ui/core/second.png",
                 "mkdocs_stage_path": "00_book/assets/ui/core/second.png", "derived_from": self.record["id"]}
        self.assertTrue(validate_manifest({"manifest_version": 1, "assets": [self.record, other]}, self.root))

    def test_unowned_file_and_invalid_ledger_never_deleted(self):
        stage = self.root / STAGE_ROOT
        stage.mkdir(parents=True)
        unknown = stage / "hand-written.txt"
        unknown.write_text("preserve")
        with self.assertRaisesRegex(AssetError, "unowned"):
            sync(self.data, self.root)
        self.assertEqual(unknown.read_text(), "preserve")
        unknown.unlink()
        (stage / LEDGER).write_text('{"version":99}')
        with self.assertRaisesRegex(AssetError, "invalid ownership"):
            sync(self.data, self.root)

    def test_stale_owned_cleanup_and_stale_check(self):
        sync(self.data, self.root)
        destination = self.root / self.record["mkdocs_stage_path"]
        self.record.update(mkdocs_stage=False, mkdocs_stage_path=None, targets=[])
        self.assertIn("remove-owned ui/core/example.png", sync(self.data, self.root, check=True))
        sync(self.data, self.root)
        self.assertFalse(destination.exists())
        self.assertTrue((self.root / self.record["current_path"]).exists())

    def test_modified_stale_file_is_preserved(self):
        sync(self.data, self.root)
        path = self.root / self.record["mkdocs_stage_path"]
        path.write_text("manually changed")
        self.record.update(mkdocs_stage=False, mkdocs_stage_path=None, targets=[])
        with self.assertRaisesRegex(AssetError, "refuse delete"):
            sync(self.data, self.root)
        self.assertEqual(path.read_text(), "manually changed")

    def test_symlink_stage_cannot_escape_repository(self):
        with tempfile.TemporaryDirectory() as outside:
            stage = self.root / STAGE_ROOT
            stage.parent.mkdir(parents=True, exist_ok=True)
            stage.symlink_to(outside, target_is_directory=True)
            with self.assertRaises(AssetError):
                sync(self.data, self.root)
            self.assertEqual(list(Path(outside).iterdir()), [])

    def test_interrupted_copy_is_owned_and_retryable(self):
        from scripts import sync_documentation_assets as staging
        replace = staging.os.replace
        def fail_image(source, destination):
            if Path(destination).suffix == ".png":
                raise OSError("simulated interruption")
            return replace(source, destination)
        with patch.object(staging.os, "replace", side_effect=fail_image), self.assertRaises(OSError):
            sync(self.data, self.root)
        self.assertTrue(sync(self.data, self.root, check=True))
        sync(self.data, self.root)
        self.assertEqual(sync(self.data, self.root, check=True), [])
        self.assertFalse(list((self.root / STAGE_ROOT).rglob(".asset-*")))

    def test_reference_errors_baseline_freeze_and_report_stage(self):
        book = self.root / "00_book/DOC/page.md"
        book.parent.mkdir(parents=True)
        book.write_text('![missing](../assets/ui/core/missing.png)\n')
        errors, accepted = validate_references(self.root)
        self.assertTrue(errors)
        self.assertEqual(accepted, 0)
        book.write_text('')
        report = self.root / "00_report/main.typ"
        report.parent.mkdir(parents=True)
        report.write_text('#image("/00_book/assets/ui/core/example.png")\n')
        self.assertTrue(any("report cannot reference" in e for e in validate_references(self.root)[0]))
        report.write_text('#image("/00_book/figures/example.png")\n')
        self.contract["assets"] = [dict(id="terminal.capture.example", path=self.record["current_path"], sha256=self.record["sha256"])]
        self.contract["references"] = [dict(source_document="00_report/main.typ", referenced_path="/00_book/figures/example.png", count=1)]
        self.write_contract()
        self.assertEqual(validate_references(self.root), ([], 0))
        report.write_text('#image("/renamed-terminal.png")\n')
        self.assertTrue(any("frozen terminal reference" in e for e in validate_references(self.root)[0]))

    def test_multiline_image_syntax_is_checked(self):
        from scripts.documentation_assets import image_references
        book = self.root / "00_book/DOC/page.md"
        book.parent.mkdir(parents=True)
        book.write_text('<img\n src="../assets/missing.png">\n![reference][shot]\n[shot]: ../assets/other.png\n')
        typst = self.root / "00_report/main.typ"
        typst.parent.mkdir(parents=True)
        typst.write_text('// image("/ignored.png")\n#image(\n "/missing.png"\n)\n')
        refs = image_references(self.root)
        self.assertEqual(len(refs), 3)
        self.assertEqual([r["line"] for r in refs], [1, 3, 2])
        self.assertTrue(all(not r["exists"] for r in refs))


if __name__ == "__main__":
    unittest.main()
