"""CLI destination contracts without importing Qt or rendering repository images."""
from __future__ import annotations

import os
import csv
import json
import collections
import sys
import tempfile
import types
import unittest
from dataclasses import dataclass, replace
from pathlib import Path
from unittest.mock import patch

from docshots import cli
from docshots.outputs import OUTPUT_MAP, validate_output_map, workflow_outputs, canonical_destinations, publish_outputs
from docshots.shots import CHAPTER_03_FILENAMES, CHAPTER_04_FILENAMES, SHOT_REGISTRY
from docshots.shots import VLAN_WORKFLOW_FILENAMES, DIALOG_REGRESSION_FILENAMES


@dataclass(frozen=True)
class Request:
    width: int
    height: int
    scale: float
    theme: str
    output_dir: Path
    timeout_ms: int = 15000


class DocshotDestinationTests(unittest.TestCase):
    def run_cli(self, arguments):
        calls = []
        runtime = types.ModuleType('docshots.runtime')
        runtime.DocshotError = RuntimeError
        runtime.RenderRequest = Request
        def result(path):
            return types.SimpleNamespace(path=path, width=3200, height=2000)
        def render(shot, request):
            calls.append((shot.name, request))
            return result(request.output_dir / (shot.name + '.png'))
        def workflow(request, name, filenames=()):
            calls.append((name, request))
            return [result(request.output_dir / filename) for filename in filenames]
        runtime.render_shot = render
        runtime.render_vlan_workflow = lambda r: workflow(r, 'vlan', VLAN_WORKFLOW_FILENAMES)
        runtime.render_dialog_regressions = lambda r: workflow(r, 'dialogs', DIALOG_REGRESSION_FILENAMES)
        chapter03 = types.ModuleType('docshots.chapter03')
        chapter03.render_chapter_03_workflow = lambda r: workflow(r, 'chapter-03', CHAPTER_03_FILENAMES)
        chapter04 = types.ModuleType('docshots.chapter04')
        chapter04.render_chapter_04_workflow = lambda r: workflow(r, 'chapter-04', CHAPTER_04_FILENAMES)
        with patch.dict(sys.modules, {'docshots.runtime': runtime, 'docshots.chapter03': chapter03, 'docshots.chapter04': chapter04}), patch('builtins.print'), patch.object(cli, 'publish_outputs', side_effect=lambda workflow, paths, stage, root: canonical_destinations(workflow, root)) as publish:
            self.assertEqual(cli.main(arguments), 0)
            if '--output-dir' in arguments:
                publish.assert_not_called()
            else:
                publish.assert_called_once()
                self.assertEqual({p.name for p in publish.call_args.args[1]}, set(canonical_destinations(arguments[0], cli.REPOSITORY_ROOT)))
        return calls

    def test_default_root_is_this_repository(self):
        self.assertEqual(cli.REPOSITORY_ROOT, Path(__file__).resolve().parents[1])
        self.assertEqual(cli.DEFAULT_OUTPUT_DIR, cli.APP_DIR / 'documentation_assets/ui/docshot')
        with tempfile.TemporaryDirectory() as unrelated:
            previous = Path.cwd()
            try:
                os.chdir(unrelated)
                for shot, domain in cli.DEFAULT_DOMAINS.items():
                    self.assertEqual(cli.resolve_output_directory(shot), cli.DEFAULT_OUTPUT_DIR / domain)
            finally:
                os.chdir(previous)

    def test_dialogs_default_blocked_before_runtime_import(self):
        with patch.object(cli, 'configure_qt_environment') as configure, patch('builtins.print') as message:
            self.assertEqual(cli.main(['dialogs']), 1)
            configure.assert_not_called()
            self.assertIn('temporary-only', message.call_args.args[0])

    def test_default_managed_dispatch_uses_temporary_rendering_then_map(self):
        for name in ['welcome', 'workspace', 'devices', 'chapter-03', 'chapter-04', 'vlan', 'all']:
            calls = self.run_cli([name])
            self.assertTrue(calls)
            for _, request in calls:
                self.assertFalse(request.output_dir.is_relative_to(cli.DEFAULT_OUTPUT_DIR))
                self.assertFalse(request.output_dir.exists())  # temporary context cleaned
        self.assertEqual([n for n, _ in self.run_cli(['all'])], list(SHOT_REGISTRY))

    def test_every_workflow_respects_exact_temporary_override(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / 'isolated'
            for name in ['welcome', 'workspace', 'devices', 'all', 'vlan', 'dialogs', 'chapter-03', 'chapter-04']:
                calls = self.run_cli([name, '--output-dir', str(destination)])
                self.assertTrue(calls)
                self.assertTrue(all(request.output_dir == destination for _, request in calls))
            self.assertFalse(destination.exists())  # dispatch tests are mocked, never render

    def test_repeat_dispatch_keeps_requests_isolated(self):
        with tempfile.TemporaryDirectory() as directory:
            one = self.run_cli(['chapter-03', '--output-dir', directory + '/first'])[0][1]
            two = self.run_cli(['chapter-03', '--output-dir', directory + '/second'])[0][1]
            self.assertEqual((one.width, one.height, one.scale, one.theme), (two.width, two.height, two.scale, two.theme))
            self.assertNotEqual(one.output_dir, two.output_dir)
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_default_symlink_escape_rejected_without_writes(self):
        with tempfile.TemporaryDirectory() as root, tempfile.TemporaryDirectory() as outside:
            repo = Path(root)
            (repo / 'canonical').symlink_to(outside, target_is_directory=True)
            with patch.object(cli, 'REPOSITORY_ROOT', repo), patch.object(cli, 'DEFAULT_OUTPUT_DIR', repo / 'canonical'):
                with self.assertRaisesRegex(ValueError, 'escapes repository'):
                    cli.resolve_output_directory('chapter-04')
            self.assertEqual(list(Path(outside).iterdir()), [])


    def test_complete_map_matches_preflight_and_manifest(self):
        import yaml
        root = cli.REPOSITORY_ROOT
        records = {a['id']: a for a in yaml.safe_load((root / 'documentation_assets/manifest.yaml').read_text())['assets']}
        with (root / 'output/documentation-assets-plan/docshot-output-preflight.csv').open() as stream:
            planned = [r for r in csv.DictReader(stream) if r['asset_id']]
        self.assertEqual(len(OUTPUT_MAP), 42)
        self.assertEqual({(s.workflow, s.filename, s.asset_id, s.canonical_path) for s in OUTPUT_MAP},
                         {(r['workflow'], r['current_filename'], r['asset_id'], r['planned_canonical_path']) for r in planned})
        validate_output_map()
        for spec in OUTPUT_MAP:
            record = records[spec.asset_id]
            self.assertEqual(spec.canonical_path, record['planned_canonical_path'])
            if record['migration_state'] == 'migrated':
                self.assertEqual(spec.canonical_path, record['current_path'])
            self.assertFalse(Path(spec.canonical_path).name[0].isdigit())

    def test_workflow_coverage_and_cross_domain_identity(self):
        self.assertEqual(collections.Counter(s.workflow for s in OUTPUT_MAP),
                         {'chapter-03': 11, 'chapter-04': 19, 'vlan': 9, 'welcome': 1, 'workspace': 1, 'devices': 1})
        for workflow, names in [('chapter-03', CHAPTER_03_FILENAMES), ('chapter-04', CHAPTER_04_FILENAMES), ('vlan', VLAN_WORKFLOW_FILENAMES)]:
            self.assertEqual({s.filename for s in workflow_outputs(workflow)}, set(names))
        for name in SHOT_REGISTRY:
            self.assertEqual([s.filename for s in workflow_outputs(name)], [name + '.png'])
        mapping = {s.asset_id: s for s in OUTPUT_MAP}
        self.assertEqual(mapping['ui.core.status-details'].filename, '09-status-details.png')
        for asset in ['ui.devices.sidebar-status-groups', 'ui.devices.tabs-router-active']:
            self.assertEqual(mapping[asset].workflow, 'chapter-03')
            self.assertIn('/devices/', mapping[asset].canonical_path)
        self.assertIn('/core/', mapping['ui.core.workspace-empty'].canonical_path)

    def test_collision_and_unmanaged_fail_closed(self):
        for key in ['asset_id', 'canonical_path', 'filename']:
            specs = list(OUTPUT_MAP)
            specs[1] = replace(specs[1], **{key: getattr(specs[0], key)})
            with self.assertRaisesRegex(ValueError, 'collision'):
                validate_output_map(specs)
        with self.assertRaisesRegex(ValueError, 'Unmanaged'):
            workflow_outputs('dialogs')
        self.assertTrue(set(DIALOG_REGRESSION_FILENAMES).isdisjoint(s.filename for s in OUTPUT_MAP))

    def test_unsafe_registry_paths_rejected(self):
        for path in ['../outside.png', '/tmp/outside.png', 'documentation_assets/ui/docshot/core/../escape.png',
                     'documentation_assets/ui/docshot/core/01-legacy.png']:
            with self.assertRaisesRegex(ValueError, 'Unsafe'):
                validate_output_map([replace(OUTPUT_MAP[0], canonical_path=path)])

    def test_enabled_defaults_require_all_42_manifest_transitions(self):
        import yaml
        records = {a['id']: a for a in yaml.safe_load((cli.REPOSITORY_ROOT / 'documentation_assets/manifest.yaml').read_text())['assets']}
        for spec in OUTPUT_MAP:
            self.assertEqual(records[spec.asset_id]['migration_state'], 'migrated')
            self.assertTrue(records[spec.asset_id]['canonical'])
            self.assertEqual(records[spec.asset_id]['current_path'], spec.canonical_path)

    def test_all_exact_generic_destinations_and_canonical_containment(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for workflow in ['chapter-03', 'chapter-04', 'vlan', *SHOT_REGISTRY, 'all']:
                resolved = canonical_destinations(workflow, root)
                self.assertEqual(resolved, {s.filename: root / s.canonical_path for s in workflow_outputs(workflow)})
                self.assertTrue(all(p.is_relative_to(root / 'documentation_assets/ui/docshot') for p in resolved.values()))
            self.assertEqual(set(canonical_destinations('all', root)), {'welcome.png', 'workspace.png', 'devices.png'})
            self.assertEqual(list(root.iterdir()), [])

    def test_semantic_symlink_parent_and_leaf_escapes_rejected(self):
        for location in ['documentation_assets', 'documentation_assets/ui/docshot/core',
                         'documentation_assets/ui/docshot/core/welcome-recent-projects.png']:
            with tempfile.TemporaryDirectory() as directory, tempfile.TemporaryDirectory() as outside:
                root = Path(directory); link = root / location
                link.parent.mkdir(parents=True, exist_ok=True)
                link.symlink_to(outside, target_is_directory=True)
                with self.assertRaisesRegex(ValueError, 'escapes canonical|Symlink'):
                    canonical_destinations('welcome', root)
                self.assertEqual(list(Path(outside).iterdir()), [])
        # Escaping canonical storage to another directory INSIDE the repo is unsafe too.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); link = root / 'documentation_assets/ui/docshot/core'
            link.parent.mkdir(parents=True); (root / 'unmanaged').mkdir()
            link.symlink_to(root / 'unmanaged', target_is_directory=True)
            with self.assertRaises(ValueError):
                canonical_destinations('welcome', root)

    def test_publisher_rejects_unmanaged_missing_colliding_and_escaped_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'repo'; stage = Path(directory) / 'stage'; stage.mkdir()
            normal = stage / 'welcome.png'; normal.write_bytes(b'test temporary bytes')
            extra = stage / 'unmanaged.png'; extra.write_bytes(b'test temporary bytes')
            for paths in [[], [normal, normal], [normal, extra], [extra]]:
                with self.assertRaisesRegex(ValueError, 'Incomplete, unmanaged or colliding'):
                    publish_outputs('welcome', paths, stage, root)
                self.assertFalse(root.exists())
            outside = Path(directory) / 'welcome.png'; outside.write_bytes(b'outside')
            with self.assertRaisesRegex(ValueError, 'outside temporary'):
                publish_outputs('welcome', [outside], stage, root)
            self.assertFalse(root.exists())

    def test_publisher_preserves_rendered_bytes_and_semantic_filename_in_temp_repo(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'repo'; stage = Path(directory) / 'stage'; stage.mkdir()
            paths = []
            for spec in workflow_outputs('chapter-03'):
                path = stage / spec.filename; path.write_bytes(spec.asset_id.encode()); paths.append(path)
            destinations = publish_outputs('chapter-03', paths, stage, root)
            self.assertEqual(len(destinations), 11)
            for spec in workflow_outputs('chapter-03'):
                self.assertEqual(destinations[spec.filename], root / spec.canonical_path)
                self.assertEqual(destinations[spec.filename].read_bytes(), spec.asset_id.encode())
            self.assertFalse(list(root.rglob('.docshot-*')))

    def test_default_escape_fails_before_qt_initialization(self):
        with tempfile.TemporaryDirectory() as directory, tempfile.TemporaryDirectory() as outside:
            root = Path(directory)
            (root / 'documentation_assets').symlink_to(outside, target_is_directory=True)
            with patch.object(cli, 'REPOSITORY_ROOT', root), patch.object(cli, 'configure_qt_environment') as configure, patch('builtins.print'):
                self.assertEqual(cli.main(['welcome']), 1)
                configure.assert_not_called()
            self.assertEqual(list(Path(outside).iterdir()), [])

    def test_migrated_used_by_edges_have_exact_current_lines_without_duplicates(self):
        import yaml
        root = cli.REPOSITORY_ROOT
        records = {a['id']: a for a in yaml.safe_load((root / 'documentation_assets/manifest.yaml').read_text())['assets']}
        for spec in OUTPUT_MAP:
            edges = records[spec.asset_id]['used_by']
            keys = [(e['source_document'], e['line'], e['referenced_path']) for e in edges]
            self.assertEqual(len(keys), len(set(keys)), spec.asset_id)
            for source, line, referenced in keys:
                self.assertIn(referenced, (root / source).read_text().splitlines()[line - 1], spec.asset_id)

if __name__ == '__main__':
    unittest.main()
