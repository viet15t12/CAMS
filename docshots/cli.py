"""Command-line interface for the CAMS documentation renderer."""

from __future__ import annotations

import argparse
from contextlib import nullcontext
import tempfile
import sys
from pathlib import Path
from typing import Sequence

from .environment import configure_qt_environment
from .outputs import canonical_destinations, publish_outputs
from .shots import (
    SHOT_REGISTRY,
    resolve_shots,
)


APP_DIR = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = APP_DIR
DEFAULT_OUTPUT_DIR = REPOSITORY_ROOT / "documentation_assets" / "ui" / "docshot"
DEFAULT_DOMAINS = {
    "welcome": "core", "workspace": "core", "devices": "devices",
    "chapter-03": "core", "chapter-04": "devices",
    "vlan": "switching/vlan", "dialogs": "core/dialogs", "all": "",
}


def resolve_output_directory(shot: str, override: Path | None = None) -> Path:
    """Overrides are exact destinations; defaults are contained in this checkout."""
    if override is not None:
        return override.expanduser().resolve()
    destination = (DEFAULT_OUTPUT_DIR / DEFAULT_DOMAINS[shot]).resolve()
    if not destination.is_relative_to(REPOSITORY_ROOT.resolve()):
        raise ValueError("Default docshot output escapes repository (check symlinks)")
    return destination


def _positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def _positive_scale(value: str) -> float:
    parsed = float(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Render deterministic CAMS QML screenshots as PNG files."
    )
    parser.add_argument(
        "shot",
        choices=(*SHOT_REGISTRY.keys(), "vlan", "dialogs", "chapter-03", "chapter-04", "all"),
        help="registered screenshot name, a workflow ('vlan', 'dialogs', 'chapter-03', or 'chapter-04'), or 'all'",
    )
    parser.add_argument("--width", type=_positive_int, default=1600)
    parser.add_argument("--height", type=_positive_int, default=1000)
    parser.add_argument("--scale", type=_positive_scale, default=2.0)
    parser.add_argument("--theme", choices=("light", "dark"), default="light")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="exact temporary destination with legacy filenames (default: managed semantic canonical paths)",
    )
    return parser


def ensure_output_directory(path: Path) -> Path:
    resolved = path.expanduser().resolve()
    resolved.mkdir(parents=True, exist_ok=True)
    return resolved


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.output_dir is None and args.shot == "dialogs":
        print("docshots: dialogs are temporary-only; use --output-dir", file=sys.stderr)
        return 1
    try:
        if args.output_dir is None:
            canonical_destinations(args.shot, REPOSITORY_ROOT)
        else:
            resolve_output_directory(args.shot, args.output_dir)
    except ValueError as exc:
        print(f"docshots: {exc}", file=sys.stderr)
        return 1
    configure_qt_environment()

    # Qt and main.py must only be imported after the headless/DPI variables exist.
    from .runtime import (
        DocshotError, RenderRequest, render_dialog_regressions,
        render_shot, render_vlan_workflow,
    )

    # Default rendering emits legacy filenames in a temporary directory first.
    # Only the explicit map may publish them; overrides never publish canonically.
    context = (tempfile.TemporaryDirectory(prefix="cams-docshot-publish-")
               if args.output_dir is None else nullcontext(None))
    try:
        with context as temporary:
            output_dir = (Path(temporary) if temporary is not None
                          else resolve_output_directory(args.shot, args.output_dir))
            request = RenderRequest(width=args.width, height=args.height, scale=args.scale,
                                    theme=args.theme, output_dir=output_dir)
            if args.shot == "chapter-04":
                from .chapter04 import render_chapter_04_workflow
                results = render_chapter_04_workflow(request)
            elif args.shot == "chapter-03":
                from .chapter03 import render_chapter_03_workflow
                results = render_chapter_03_workflow(request)
            elif args.shot == "vlan":
                results = render_vlan_workflow(request)
            elif args.shot == "dialogs":
                results = render_dialog_regressions(request)
            else:
                results = [render_shot(shot, request) for shot in resolve_shots(args.shot)]
            if args.output_dir is None:
                destinations = publish_outputs(args.shot, [r.path for r in results],
                                               output_dir, REPOSITORY_ROOT)
            else:
                destinations = {r.path.name: r.path for r in results}
            for result in results:
                path = destinations[result.path.name]
                print(f"{path.name}: {path} ({result.width}x{result.height})")
    except (DocshotError, OSError, ValueError) as exc:
        print(f"docshots: {exc}", file=sys.stderr)
        return 1
    return 0


__all__ = [
    "APP_DIR",
    "DEFAULT_OUTPUT_DIR",
    "REPOSITORY_ROOT",
    "build_parser",
    "ensure_output_directory",
    "main",
    "resolve_output_directory",
]
