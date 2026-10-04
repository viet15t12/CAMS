"""CLI destination contracts without importing Qt or rendering repository images."""
from __future__ import annotations

import os
import sys
import tempfile
import types
import unittest
from dataclasses import dataclass
from pathlib import Path
from unittest.mock import patch

from docshots import cli
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
        chapter03.render_chapter_03_workflow = lambda r: workflow(r, 'chapter-03')
        chapter04 = types.ModuleType('docshots.chapter04')
        chapter04.render_chapter_04_workflow = lambda r: workflow(r, 'chapter-04')
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


if __name__ == '__main__':
    unittest.main()
