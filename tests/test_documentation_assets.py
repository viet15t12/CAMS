"""Transitional manifest, frozen evidence and generated-stage boundary tests."""
from __future__ import annotations

import copy
import json
import subprocess
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

    def test_documentation_image_paths_explicitly_disable_git_text_filtering(self):
        import yaml
        root = Path(__file__).resolve().parents[1]
        records = yaml.safe_load((root / "documentation_assets/manifest.yaml").read_text())["assets"]
        paths = {a[key] for a in records for key in ("current_path", "planned_canonical_path")
                 if a.get(key) and a[key].endswith(".svg")}
        # Exercise all formats at both root and nested levels, including future assets.
        paths.update(f"{base}/{nested}fixture.{ext}"
                     for base in ("00_book/figures", "00_report", "documentation_assets")
                     for nested in ("", "nested/")
                     for ext in ("svg", "png", "jpg", "jpeg", "webp", "gif"))
        output = subprocess.check_output(["git", "check-attr", "-z", "text", "--", *sorted(paths)], cwd=root)
        values = output.decode().strip("\0").split("\0")
        for path, attribute, value in zip(values[::3], values[1::3], values[2::3]):
            with self.subTest(path=path):
                self.assertEqual((attribute, value), ("text", "unset"))
        runtime = subprocess.check_output(["git", "check-attr", "text", "--", "UI/resources/brand/logo.svg"], cwd=root, text=True)
        self.assertEqual(runtime.strip().rsplit(": ", 1)[1], "auto")

    def test_svg_repository_bytes_survive_autocrlf_and_validator_checks_exact_bytes(self):
        root = Path(__file__).resolve().parents[1]
        subprocess.run(["git", "init", "--quiet", str(self.root)], check=True)
        (self.root / ".gitattributes").write_bytes((root / ".gitattributes").read_bytes())
        path = "documentation_assets/diagrams/example.svg"
        source = self.root / path
        source.parent.mkdir(parents=True)
        content = b'<svg xmlns="http://www.w3.org/2000/svg">\r\n<text>fixture</text>\r\n</svg>\r\n'
        source.write_bytes(content)
        subprocess.run(["git", "-c", "core.autocrlf=true", "add", ".gitattributes", path], cwd=self.root, check=True)
        subprocess.run(["git", "-c", "user.name=Asset Test", "-c", "user.email=asset-test@example.invalid",
                        "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "byte fixture"], cwd=self.root, check=True)
        blob = subprocess.check_output(["git", "cat-file", "blob", f"HEAD:{path}"], cwd=self.root)
        self.assertEqual(blob, content)
        self.record.update(migration_state="migrated", canonical=True, current_path=path,
                           path=path, planned_canonical_path=path, sha256=digest(source),
                           mkdocs_stage=False, mkdocs_stage_path=None, targets=[])
        for autocrlf in ("false", "true", "input"):
            with self.subTest(autocrlf=autocrlf):
                checkout = self.root / f"clean-{autocrlf}"
                checkout.mkdir()
                subprocess.run(["git", "-c", f"core.autocrlf={autocrlf}", "checkout-index", "--all",
                                f"--prefix={checkout}/"], cwd=self.root, check=True)
                self.assertEqual((checkout / path).read_bytes(), blob)
                self.assertEqual(digest(checkout / path), self.record["sha256"])
                contract = checkout / "documentation_assets/terminal-freeze.json"
                contract.write_text(json.dumps(self.contract))
                self.assertEqual(validate_manifest(self.data, checkout), [])
                (checkout / path).write_bytes(content.replace(b"\r\n", b"\n"))
                self.assertTrue(any("SHA mismatch" in e for e in validate_manifest(self.data, checkout)))

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

    def test_fresh_checkout_pre_sync_then_full_post_sync(self):
        import yaml
        from scripts.validate_documentation_assets import main
        from contextlib import redirect_stdout
        import io
        (self.root / "documentation_assets/manifest.yaml").write_text(yaml.safe_dump(self.data))
        book = self.root / "00_book/DOC/page.md"
        book.parent.mkdir(parents=True)
        book.write_text('![asset](../assets/ui/core/example.png)\n')
        self.assertFalse((self.root / STAGE_ROOT).exists())
        with redirect_stdout(io.StringIO()):
            self.assertEqual(main(["--manifest-only"], root=self.root), 0)
            self.assertEqual(main(["--check-staging"], root=self.root), 1)
            sync(self.data, self.root)
            self.assertEqual(main(["--check-staging"], root=self.root), 0)
            (self.root / self.record["mkdocs_stage_path"]).unlink()
            self.assertEqual(main(["--check-staging"], root=self.root), 1)

    def test_pre_sync_keeps_frozen_reference_contract(self):
        import yaml
        from scripts.validate_documentation_assets import main
        from contextlib import redirect_stdout
        import io
        (self.root / "documentation_assets/manifest.yaml").write_text(yaml.safe_dump(self.data))
        self.contract["references"] = [dict(source_document="00_report/main.typ", referenced_path="/frozen.png", count=1)]
        self.write_contract()
        with redirect_stdout(io.StringIO()):
            self.assertEqual(main(["--manifest-only"], root=self.root), 1)

    def test_b02_preflight_partition_matches_manifest_without_approval(self):
        import csv
        import yaml
        root = Path(__file__).resolve().parents[1]
        records = {a["id"]: a for a in yaml.safe_load((root / "documentation_assets/manifest.yaml").read_text())["assets"]}
        with (root / "output/documentation-assets-foundation/phase3-3-eol-audit.csv").open() as stream:
            reconciled = {r["asset_id"]: r for r in csv.DictReader(stream) if r["eol_only"] == "true"}
        with (root / "output/documentation-assets-plan/b02-preflight.csv").open() as stream:
            rows = list(csv.DictReader(stream))
        with (root / "output/documentation-assets-plan/migration-batches.csv").open() as stream:
            parent = next(r for r in csv.DictReader(stream) if r["batch_id"] == "B02")
        self.assertEqual(len(rows), 39)
        self.assertEqual({r["asset_id"] for r in rows}, set(json.loads(parent["asset_ids"])))
        safe = {"branding.logos.cams", "diagrams.architecture.application-source-tree",
                "diagrams.workflow.configuration-state-flow", "diagrams.architecture.cams-layered-system",
                "diagrams.lab-topology.switching.layer-two-security"}
        reviewed_orphans = {"diagrams.workflow.configuration-automation", "diagrams.workflow.cisco-cli-modes",
                            "diagrams.architecture.ssh-session-connection", "diagrams.workflow.device-session-lifecycle",
                            "diagrams.workflow.dhcp-dora-sequence"}
        self.assertEqual({r["asset_id"] for r in rows if r["sub_batch"] == "B02A"}, safe)
        self.assertEqual({r["asset_id"] for r in rows if r["sub_batch"] == "B02B1"}, reviewed_orphans)
        review = json.loads((root / "output/documentation-assets-migrations/b02b1.json").read_text())["review"]
        self.assertEqual({r["asset_id"] for r in review}, reviewed_orphans)
        self.assertTrue(all(r["decision"] == "APPROVE" for r in review))
        second_orphans = {"diagrams.network.nat-pat-internet-topology", "diagrams.network.fhrp-virtual-gateway",
                          "diagrams.database.device-entity-relations", "diagrams.architecture.netmiko-ssh-stack",
                          "diagrams.architecture.qtquick-component-tree"}
        self.assertEqual({r["asset_id"] for r in rows if r["sub_batch"] == "B02B2"}, second_orphans)
        review = json.loads((root / "output/documentation-assets-migrations/b02b2.json").read_text())["review"]
        self.assertEqual({r["asset_id"] for r in review}, second_orphans)
        self.assertTrue(all(r["decision"] == "APPROVE" for r in review))
        reviewed_orphans |= second_orphans
        third_orphans = {"diagrams.architecture.qml-python-signal-flow", "diagrams.architecture.ui-thread-worker-dispatch",
                         "diagrams.architecture.per-host-session-lock", "diagrams.workflow.per-host-serial-cross-host-parallel",
                         "diagrams.workflow.syslog-processing-pipeline"}
        self.assertEqual({r["asset_id"] for r in rows if r["sub_batch"] == "B02B3"}, third_orphans)
        review = json.loads((root / "output/documentation-assets-migrations/b02b3.json").read_text())["review"]
        self.assertEqual({r["asset_id"] for r in review}, third_orphans)
        self.assertTrue(all(r["decision"] == "APPROVE" for r in review))
        reviewed_orphans |= third_orphans
        fourth_orphans = {"diagrams.workflow.service-repository-test", "diagrams.workflow.worker-fake-connector-test",
                          "diagrams.workflow.network-lab-verification"}
        preserved_active = {"diagrams.database.core-observed-data-relationships",
                            "diagrams.workflow.syslog-processing-sequence"}
        self.assertEqual({r["asset_id"] for r in rows if r["sub_batch"] == "B02B4"}, fourth_orphans | preserved_active)
        review = json.loads((root / "output/documentation-assets-migrations/b02b4.json").read_text())["review"]
        self.assertEqual({r["asset_id"] for r in review}, fourth_orphans | preserved_active)
        self.assertTrue(all(r["decision"] == "APPROVE" for r in review))
        reviewed_orphans |= fourth_orphans
        independent_pairs = {"diagrams.network.ospf-multi-area-backbone", "diagrams.network.ospf-area-zero-router-chain",
                             "diagrams.workflow.inbound-acl-tests", "diagrams.workflow.acl-rule-evaluation"}
        self.assertEqual({r["asset_id"] for r in rows if r["sub_batch"] == "B02C"}, independent_pairs)
        pair_report = json.loads((root / "output/documentation-assets-migrations/b02c.json").read_text())
        self.assertEqual({r["asset_id"] for r in pair_report["review"]}, independent_pairs)
        self.assertTrue(all(r["decision"] == "APPROVE" for r in pair_report["review"]))
        expected_pairs = {
            ("diagrams.network.ospf-multi-area-backbone", "diagrams.network.ospf-area-zero-router-chain"),
            ("diagrams.workflow.inbound-acl-tests", "diagrams.workflow.acl-rule-evaluation"),
        }
        self.assertEqual(len(pair_report["pair_review"]), 2)
        self.assertEqual({(r["raster_asset_id"], r["svg_asset_id"]) for r in pair_report["pair_review"]}, expected_pairs)
        self.assertTrue(all(r["decision"] == "DIFFERENT_CONTENT_CONFIRMED" and r["no_deduplication"]
                            and r["no_derivative_relation"] and r["both_members_preserved"]
                            for r in pair_report["pair_review"]))
        for asset_id in independent_pairs:
            self.assertIsNone(records[asset_id]["derived_from"])
            self.assertIsNone(records[asset_id]["canonical_group_id"])
        reviewed_orphans |= independent_pairs
        for row in rows:
            asset = records[row["asset_id"]]
            # The historical plan retains the source path after migration.
            self.assertEqual(row["current_path"], asset["legacy_path"] if asset["migration_state"] == "migrated" else asset["current_path"])
            self.assertEqual(row["planned_canonical_path"], asset["planned_canonical_path"])
            # Historical preflight hashes precede the repository-byte contract.
            if row["asset_id"] in reconciled:
                audit = reconciled[row["asset_id"]]
                self.assertEqual(row["sha256"], audit["manifest_sha"])
                self.assertEqual(asset["sha256"], audit["git_blob_sha"])
            else:
                self.assertEqual(row["sha256"], asset["sha256"])
            if row["asset_id"] in safe:
                self.assertIn(asset["migration_state"], {"pending", "migrated"})
                self.assertFalse(asset["review_required"])
                self.assertEqual(asset["confidence"], "high")
            elif row["asset_id"] in reviewed_orphans:
                self.assertIn(asset["migration_state"], {"pending", "migrated"})
                self.assertTrue(asset["review_required"])
                self.assertEqual(asset["status"], "orphan-review")
                self.assertEqual(asset["used_by"], [])
                self.assertEqual(asset["targets"], [])
                self.assertFalse(asset["mkdocs_stage"])
                self.assertEqual(row["review_approved"], "false")  # historical preflight
            elif row["asset_id"] in preserved_active:
                self.assertEqual(asset["migration_state"], "migrated")
                self.assertTrue(asset["preserve_original"])
                self.assertFalse(asset["original_evidence"])
                self.assertTrue(asset["review_required"])
                self.assertEqual(asset["status"], "active")
                self.assertEqual(asset["targets"], ["report-typst"])
                self.assertFalse(asset["mkdocs_stage"])
                self.assertEqual((root / asset["legacy_path"]).read_bytes(), (root / asset["current_path"]).read_bytes())
                self.assertEqual(digest(root / asset["legacy_path"]), asset["sha256"])
                self.assertEqual(len(asset["used_by"]), 1)
                use = asset["used_by"][0]
                self.assertEqual(use["target_type"], "report-typst")
                self.assertEqual(use["source_document"], "00_report/contents/07_phan_tich_thiet_ke.typ")
                self.assertEqual(use["referenced_path"], "/" + asset["current_path"])
                source = (root / use["source_document"]).read_text()
                self.assertIn(use["referenced_path"], source.splitlines()[use["line"] - 1])
                self.assertNotIn("/" + asset["legacy_path"], source)
                self.assertEqual(row["review_approved"], "false")  # historical preflight
            else:
                self.assertEqual(asset["migration_state"], "pending")
                self.assertTrue(asset["review_required"])
                self.assertEqual(row["review_approved"], "false")


if __name__ == "__main__":
    unittest.main()
