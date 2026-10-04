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
from docshots.outputs import OUTPUT_MAP, validate_output_map, workflow_outputs
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
        with patch.dict(sys.modules, {'docshots.runtime': runtime, 'docshots.chapter03': chapter03, 'docshots.chapter04': chapter04}), patch('builtins.print'):
            self.assertEqual(cli.main(arguments), 0)
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

    def test_default_canonical_writes_blocked_before_runtime_import(self):
        with patch.object(cli, 'configure_qt_environment') as configure, patch('builtins.print') as message:
            for name in cli.DEFAULT_DOMAINS:
                self.assertEqual(cli.main([name]), 1)
            configure.assert_not_called()
            self.assertIn('semantic output map', message.call_args.args[0])

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

if __name__ == '__main__':
    unittest.main()
