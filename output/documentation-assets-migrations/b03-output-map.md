# B03-0 semantic output map

PASS: 42 explicit workflow/filename → logical ID → full canonical path mappings. No images moved or regenerated; counts 37 migrated / 308 pending / 62 frozen. Default writes remain blocked. Dialogs remain temporary-only.

Chapter-03 now registers all 11 outputs including status-details; sidebar-collapsed index is adjusted without changing capture state/crop. Chapter-04 shares its unchanged 19 filenames with the lightweight registry. Cross-domain chapter-03 outputs are mapped explicitly.

28 targeted tests PASS; git diff --check PASS. Qt temporary smoke unavailable: runtime import lacks jinja2 in the available Python environment. No fixture or dependency changes.

Two historical review flags contradict the blanket preflight assumption. Targeted visual/source checks confirm the Switch feature bar and Connected menu identities and current captions; flags/provenance remain unchanged.

| Workflow | Legacy output | Asset ID | Canonical path | Pack |
|---|---|---|---|---|
| chapter-03 | 01-workspace-overview.png | ui.core.workspace-overview | documentation_assets/ui/docshot/core/workspace-overview.png | B03A |
| chapter-03 | 02-menu-bar.png | ui.core.view-menu | documentation_assets/ui/docshot/core/view-menu.png | B03A |
| chapter-03 | 03-activity-bar.png | ui.core.activity-bar | documentation_assets/ui/docshot/core/activity-bar.png | B03A |
| chapter-03 | 04-devices-sidebar.png | ui.devices.sidebar-status-groups | documentation_assets/ui/docshot/devices/sidebar-status-groups.png | B03A |
| chapter-03 | 05-device-tabs.png | ui.devices.tabs-router-active | documentation_assets/ui/docshot/devices/tabs-router-active.png | B03A |
| chapter-03 | 06-feature-bar-router.png | ui.core.feature-bar-router | documentation_assets/ui/docshot/core/feature-bar-router.png | B03A |
| chapter-03 | 07-feature-bar-switch.png | ui.core.feature-bar-switch | documentation_assets/ui/docshot/core/feature-bar-switch.png | B03A |
| chapter-03 | 08-content-area.png | ui.core.information-empty | documentation_assets/ui/docshot/core/information-empty.png | B03A |
| chapter-03 | 09-status-bar.png | ui.core.status-bar | documentation_assets/ui/docshot/core/status-bar.png | B03A |
| chapter-03 | 09-status-details.png | ui.core.status-details | documentation_assets/ui/docshot/core/status-details.png | B03A |
| chapter-03 | 10-sidebar-collapsed.png | ui.core.sidebar-collapsed | documentation_assets/ui/docshot/core/sidebar-collapsed.png | B03A |
| chapter-04 | 01-devices-inventory.png | ui.devices.inventory-waiting | documentation_assets/ui/docshot/devices/inventory-waiting.png | B03B |
| chapter-04 | 02-add-device-empty.png | ui.devices.create-empty | documentation_assets/ui/docshot/devices/create-empty.png | B03B |
| chapter-04 | 03-add-device-filled.png | ui.devices.create-filled | documentation_assets/ui/docshot/devices/create-filled.png | B03B |
| chapter-04 | 04-device-added-waiting.png | ui.devices.created-waiting | documentation_assets/ui/docshot/devices/created-waiting.png | B03B |
| chapter-04 | 05-ssh-compatibility.png | ui.devices.ssh-compatibility | documentation_assets/ui/docshot/devices/ssh-compatibility.png | B03B |
| chapter-04 | 06-add-multiple-devices.png | ui.devices.batch-create-empty | documentation_assets/ui/docshot/devices/batch-create-empty.png | B03B |
| chapter-04 | 07-batch-devices-filled.png | ui.devices.batch-create-filled | documentation_assets/ui/docshot/devices/batch-create-filled.png | B03B |
| chapter-04 | 08-search-filter.png | ui.devices.search-switches | documentation_assets/ui/docshot/devices/search-switches.png | B03B |
| chapter-04 | 09-device-context-waiting.png | ui.devices.context-waiting | documentation_assets/ui/docshot/devices/context-waiting.png | B03B |
| chapter-04 | 10-device-connected.png | ui.devices.connected | documentation_assets/ui/docshot/devices/connected.png | B03B |
| chapter-04 | 11-device-context-connected.png | ui.devices.context-connected | documentation_assets/ui/docshot/devices/context-connected.png | B03B |
| chapter-04 | 12-device-context-disconnected.png | ui.devices.context-disconnected | documentation_assets/ui/docshot/devices/context-disconnected.png | B03B |
| chapter-04 | 13-multi-select.png | ui.devices.multi-select-mixed-status | documentation_assets/ui/docshot/devices/multi-select-mixed-status.png | B03B |
| chapter-04 | 14-multi-select-actions.png | ui.devices.multi-select-actions | documentation_assets/ui/docshot/devices/multi-select-actions.png | B03B |
| chapter-04 | 15-edit-device.png | ui.devices.edit | documentation_assets/ui/docshot/devices/edit.png | B03B |
| chapter-04 | 16-delete-device-confirmation.png | ui.devices.delete-confirmation | documentation_assets/ui/docshot/devices/delete-confirmation.png | B03B |
| chapter-04 | 17-running-config-result.png | ui.devices.running-config-snapshot | documentation_assets/ui/docshot/devices/running-config-snapshot.png | B03B |
| chapter-04 | 18-import-result.png | ui.devices.import-result | documentation_assets/ui/docshot/devices/import-result.png | B03B |
| chapter-04 | 19-batch-table-detail.png | ui.devices.batch-host-name-detail | documentation_assets/ui/docshot/devices/batch-host-name-detail.png | B03B |
| devices | devices.png | ui.devices.inventory-router-selected | documentation_assets/ui/docshot/devices/inventory-router-selected.png | B03B |
| vlan | 01-select-switch.png | ui.switching.vlan.switch-selected | documentation_assets/ui/docshot/switching/vlan/switch-selected.png | B03C |
| vlan | 02-open-vlan.png | ui.switching.vlan.database | documentation_assets/ui/docshot/switching/vlan/database.png | B03C |
| vlan | 03-add-vlan.png | ui.switching.vlan.create-empty | documentation_assets/ui/docshot/switching/vlan/create-empty.png | B03C |
| vlan | 04-vlan-id.png | ui.switching.vlan.create-id-filled | documentation_assets/ui/docshot/switching/vlan/create-id-filled.png | B03C |
| vlan | 05-vlan-name.png | ui.switching.vlan.create-name-filled | documentation_assets/ui/docshot/switching/vlan/create-name-filled.png | B03C |
| vlan | 06-vlan-state.png | ui.switching.vlan.create-state-selector | documentation_assets/ui/docshot/switching/vlan/create-state-selector.png | B03C |
| vlan | 07-ready-to-save.png | ui.switching.vlan.create-ready | documentation_assets/ui/docshot/switching/vlan/create-ready.png | B03C |
| vlan | 08-vlan-created.png | ui.switching.vlan.created-pending-apply | documentation_assets/ui/docshot/switching/vlan/created-pending-apply.png | B03C |
| vlan | 09-view-preview.png | ui.switching.vlan.view-push-guest | documentation_assets/ui/docshot/switching/vlan/view-push-guest.png | B03C |
| welcome | welcome.png | ui.core.welcome-recent-projects | documentation_assets/ui/docshot/core/welcome-recent-projects.png | B03A |
| workspace | workspace.png | ui.core.workspace-empty | documentation_assets/ui/docshot/core/workspace-empty.png | B03A |
