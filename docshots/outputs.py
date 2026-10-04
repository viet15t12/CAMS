"""Explicit docshot output identities; temporary rendering keeps legacy filenames.

This registry is checked against the manifest and preflight by destination tests.
No runtime YAML dependency and no filename/domain inference.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path, PurePosixPath
import os
import tempfile

from .shots import SHOT_REGISTRY


@dataclass(frozen=True, slots=True)
class OutputSpec:
    workflow: str
    filename: str
    asset_id: str
    canonical_path: str


OUTPUT_MAP = (
    OutputSpec('chapter-03', '01-workspace-overview.png',
               'ui.core.workspace-overview', 'documentation_assets/ui/docshot/core/workspace-overview.png'),
    OutputSpec('chapter-03', '02-menu-bar.png',
               'ui.core.view-menu', 'documentation_assets/ui/docshot/core/view-menu.png'),
    OutputSpec('chapter-03', '03-activity-bar.png',
               'ui.core.activity-bar', 'documentation_assets/ui/docshot/core/activity-bar.png'),
    OutputSpec('chapter-03', '04-devices-sidebar.png',
               'ui.devices.sidebar-status-groups', 'documentation_assets/ui/docshot/devices/sidebar-status-groups.png'),
    OutputSpec('chapter-03', '05-device-tabs.png',
               'ui.devices.tabs-router-active', 'documentation_assets/ui/docshot/devices/tabs-router-active.png'),
    OutputSpec('chapter-03', '06-feature-bar-router.png',
               'ui.core.feature-bar-router', 'documentation_assets/ui/docshot/core/feature-bar-router.png'),
    OutputSpec('chapter-03', '07-feature-bar-switch.png',
               'ui.core.feature-bar-switch', 'documentation_assets/ui/docshot/core/feature-bar-switch.png'),
    OutputSpec('chapter-03', '08-content-area.png',
               'ui.core.information-empty', 'documentation_assets/ui/docshot/core/information-empty.png'),
    OutputSpec('chapter-03', '09-status-bar.png',
               'ui.core.status-bar', 'documentation_assets/ui/docshot/core/status-bar.png'),
    OutputSpec('chapter-03', '09-status-details.png',
               'ui.core.status-details', 'documentation_assets/ui/docshot/core/status-details.png'),
    OutputSpec('chapter-03', '10-sidebar-collapsed.png',
               'ui.core.sidebar-collapsed', 'documentation_assets/ui/docshot/core/sidebar-collapsed.png'),
    OutputSpec('chapter-04', '01-devices-inventory.png',
               'ui.devices.inventory-waiting', 'documentation_assets/ui/docshot/devices/inventory-waiting.png'),
    OutputSpec('chapter-04', '02-add-device-empty.png',
               'ui.devices.create-empty', 'documentation_assets/ui/docshot/devices/create-empty.png'),
    OutputSpec('chapter-04', '03-add-device-filled.png',
               'ui.devices.create-filled', 'documentation_assets/ui/docshot/devices/create-filled.png'),
    OutputSpec('chapter-04', '04-device-added-waiting.png',
               'ui.devices.created-waiting', 'documentation_assets/ui/docshot/devices/created-waiting.png'),
    OutputSpec('chapter-04', '05-ssh-compatibility.png',
               'ui.devices.ssh-compatibility', 'documentation_assets/ui/docshot/devices/ssh-compatibility.png'),
    OutputSpec('chapter-04', '06-add-multiple-devices.png',
               'ui.devices.batch-create-empty', 'documentation_assets/ui/docshot/devices/batch-create-empty.png'),
    OutputSpec('chapter-04', '07-batch-devices-filled.png',
               'ui.devices.batch-create-filled', 'documentation_assets/ui/docshot/devices/batch-create-filled.png'),
    OutputSpec('chapter-04', '08-search-filter.png',
               'ui.devices.search-switches', 'documentation_assets/ui/docshot/devices/search-switches.png'),
    OutputSpec('chapter-04', '09-device-context-waiting.png',
               'ui.devices.context-waiting', 'documentation_assets/ui/docshot/devices/context-waiting.png'),
    OutputSpec('chapter-04', '10-device-connected.png',
               'ui.devices.connected', 'documentation_assets/ui/docshot/devices/connected.png'),
    OutputSpec('chapter-04', '11-device-context-connected.png',
               'ui.devices.context-connected', 'documentation_assets/ui/docshot/devices/context-connected.png'),
    OutputSpec('chapter-04', '12-device-context-disconnected.png',
               'ui.devices.context-disconnected', 'documentation_assets/ui/docshot/devices/context-disconnected.png'),
    OutputSpec('chapter-04', '13-multi-select.png',
               'ui.devices.multi-select-mixed-status', 'documentation_assets/ui/docshot/devices/multi-select-mixed-status.png'),
    OutputSpec('chapter-04', '14-multi-select-actions.png',
               'ui.devices.multi-select-actions', 'documentation_assets/ui/docshot/devices/multi-select-actions.png'),
    OutputSpec('chapter-04', '15-edit-device.png',
               'ui.devices.edit', 'documentation_assets/ui/docshot/devices/edit.png'),
    OutputSpec('chapter-04', '16-delete-device-confirmation.png',
               'ui.devices.delete-confirmation', 'documentation_assets/ui/docshot/devices/delete-confirmation.png'),
    OutputSpec('chapter-04', '17-running-config-result.png',
               'ui.devices.running-config-snapshot', 'documentation_assets/ui/docshot/devices/running-config-snapshot.png'),
    OutputSpec('chapter-04', '18-import-result.png',
               'ui.devices.import-result', 'documentation_assets/ui/docshot/devices/import-result.png'),
    OutputSpec('chapter-04', '19-batch-table-detail.png',
               'ui.devices.batch-host-name-detail', 'documentation_assets/ui/docshot/devices/batch-host-name-detail.png'),
    OutputSpec('devices', 'devices.png',
               'ui.devices.inventory-router-selected', 'documentation_assets/ui/docshot/devices/inventory-router-selected.png'),
    OutputSpec('vlan', '01-select-switch.png',
               'ui.switching.vlan.switch-selected', 'documentation_assets/ui/docshot/switching/vlan/switch-selected.png'),
    OutputSpec('vlan', '02-open-vlan.png',
               'ui.switching.vlan.database', 'documentation_assets/ui/docshot/switching/vlan/database.png'),
    OutputSpec('vlan', '03-add-vlan.png',
               'ui.switching.vlan.create-empty', 'documentation_assets/ui/docshot/switching/vlan/create-empty.png'),
    OutputSpec('vlan', '04-vlan-id.png',
               'ui.switching.vlan.create-id-filled', 'documentation_assets/ui/docshot/switching/vlan/create-id-filled.png'),
    OutputSpec('vlan', '05-vlan-name.png',
               'ui.switching.vlan.create-name-filled', 'documentation_assets/ui/docshot/switching/vlan/create-name-filled.png'),
    OutputSpec('vlan', '06-vlan-state.png',
               'ui.switching.vlan.create-state-selector', 'documentation_assets/ui/docshot/switching/vlan/create-state-selector.png'),
    OutputSpec('vlan', '07-ready-to-save.png',
               'ui.switching.vlan.create-ready', 'documentation_assets/ui/docshot/switching/vlan/create-ready.png'),
    OutputSpec('vlan', '08-vlan-created.png',
               'ui.switching.vlan.created-pending-apply', 'documentation_assets/ui/docshot/switching/vlan/created-pending-apply.png'),
    OutputSpec('vlan', '09-view-preview.png',
               'ui.switching.vlan.view-push-guest', 'documentation_assets/ui/docshot/switching/vlan/view-push-guest.png'),
    OutputSpec('welcome', 'welcome.png',
               'ui.core.welcome-recent-projects', 'documentation_assets/ui/docshot/core/welcome-recent-projects.png'),
    OutputSpec('workspace', 'workspace.png',
               'ui.core.workspace-empty', 'documentation_assets/ui/docshot/core/workspace-empty.png'),
)


def validate_output_map(specs=OUTPUT_MAP) -> None:
    keys, ids, paths = set(), set(), set()
    for spec in specs:
        key = (spec.workflow, spec.filename)
        path = PurePosixPath(spec.canonical_path)
        if (key in keys or spec.asset_id in ids or str(path).casefold() in paths):
            raise ValueError("Docshot output map collision")
        if (path.is_absolute() or ".." in path.parts or "." in spec.canonical_path.split("/")
                or "\\" in spec.canonical_path
                or not spec.canonical_path.startswith("documentation_assets/ui/docshot/")
                or path.suffix != ".png" or path.name[0].isdigit()
                or PurePosixPath(spec.filename).name != spec.filename):
            raise ValueError("Unsafe docshot output map path")
        keys.add(key)
        ids.add(spec.asset_id)
        paths.add(str(path).casefold())


def workflow_outputs(workflow: str) -> tuple[OutputSpec, ...]:
    validate_output_map()
    workflows = tuple(SHOT_REGISTRY) if workflow == "all" else (workflow,)
    specs = tuple(s for s in OUTPUT_MAP if s.workflow in workflows)
    if not specs:
        raise ValueError(f"Unmanaged docshot workflow: {workflow}")
    return specs


validate_output_map()


def canonical_destinations(workflow: str, root: Path) -> dict[str, Path]:
    """Resolve the complete managed set without writes; reject symlink paths."""
    root = root.resolve()
    canonical = root / "documentation_assets/ui/docshot"
    destinations = {}
    for spec in workflow_outputs(workflow):
        path = root / spec.canonical_path
        if not path.resolve().is_relative_to(canonical):
            raise ValueError("Docshot destination escapes canonical root (check symlinks)")
        for part in (path, *path.parents):
            if part == root:
                break
            if part.is_symlink():
                raise ValueError("Symlink in canonical docshot destination")
        if spec.filename in destinations:
            raise ValueError("Docshot output filename collision")
        destinations[spec.filename] = path
    return destinations


def publish_outputs(workflow: str, paths: list[Path], staging: Path, root: Path) -> dict[str, Path]:
    """Publish rendered temporary bytes only after validating the entire output set."""
    destinations = canonical_destinations(workflow, root)
    names = [p.name for p in paths]
    if len(names) != len(set(names)) or set(names) != set(destinations):
        raise ValueError("Incomplete, unmanaged or colliding docshot outputs")
    for path in paths:
        if path.is_symlink() or path.resolve().parent != staging.resolve() or not path.is_file():
            raise ValueError("Docshot output is outside temporary rendering directory")
    # Check all source bytes before replacing any canonical file.
    payloads = {p.name: p.read_bytes() for p in paths}
    for name, payload in payloads.items():
        destination = canonical_destinations(workflow, root)[name]
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(dir=destination.parent, prefix=".docshot-", delete=False) as stream:
                temporary = Path(stream.name)
                stream.write(payload)
            # Recheck immediately before the atomic replacement as well.
            canonical_destinations(workflow, root)
            os.replace(temporary, destination)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)
    return destinations
