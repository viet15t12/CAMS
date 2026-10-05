# B12 closure

Status: **PASS**. B12 review is CLOSED with **6 APPROVE_COPY / 9 intentional HOLD**. Every one of the 15 legacy originals remains intact; only the six approved exact-byte canonical copies were created. No recreation, alternative semantic naming or B13 work.

## Review outcomes

| Source | Asset ID | Decision | Visible state / semantic judgment |
|---|---|---|---|
| `1.png` | `evidence.routing-ospf.router-interfaces-overview` | APPROVE_COPY | R1 / 192.168.122.101; Router Interfaces > Physical, light theme. Eight physical interfaces; GigabitEthernet0/1 selected, 10.1.12.1 / 255.255.255.0, Link_To_R2, L3 profile. Layer 3 fields/options and Update Interface button visible. Generic router-interfaces-overview ID and filename accurately describe this inventory/editor state. Device/interface details distinguish it from unselected dark editor 2 and R2 inventory 3. |
| `10.png` | `evidence.routing-ospf.routing-group-hosts` | APPROVE_COPY | Routing Group · OSPF dialog, light theme; Step 1 Hosts. R1/R2/R3/ISP1/ISP2/R6 (.101-.106) listed with all six checkboxes unchecked. Heading says Select participating hosts (2–5 devices). routing-group-hosts is generic and accurate without claiming selected hosts or applied configuration; distinct from Networks step 11. |
| `11.png` | `evidence.routing-ospf.routing-group-networks` | APPROVE_COPY | Routing Group · OSPF dialog, light theme; Step 4 Networks. Connected networks/interfaces grouped under .101 and .102; visible checkboxes unchecked and Area fields all 0, including 10.1.12.0/24, 10.1.13.0/24 and 10.1.23.0/24. Generic routing-group-networks identifies actual UI state regardless of intended Area values. Does not assert correctness, selection, applied topology or resolution of the known group issue. |
| `13.png` | `evidence.routing-ospf.r1-process-dark` | HOLD | R2 / .102 selected, dark Routing > OSPF > Redistribute. One process, three networks, SYNC; process .102/PID 1, protocol static, Subnets checked; Add Redistribute. R2 Redistribute form contradicts r1-process-dark device and Process-page subject. No corrected name invented. |
| `14.png` | `evidence.routing-ospf.routing-group-push-progress` | HOLD | Light View & Push OSPF dialog for .102/R2. Prepared one routing task, Pushing in progress, OSPF setup/network area 1 and redistribute connected subnets CLI preview. routing-group-push-progress is unproven: single-host generic dialog has no explicit Routing Group identity; report places it in R2 redistribution section. Screenshot alone cannot establish a group push origin. |
| `15.png` | `evidence.routing-ospf.r1-view-push-dark` | HOLD | Dark View & Push OSPF dialog, host .103/R3, background R3 OSPF > Redistribute. Prepared one task, Pushing, router-id 3.3.3.3, area 1 networks and redistribute connected subnets; toast says saved for .103. R3 target directly contradicts r1-view-push-dark. This is CAMS UI command preview, not terminal verification or proof of completed push. |
| `16.png` | `evidence.routing-ospf.r2-process` | HOLD | ISP1 / 192.168.122.104 selected in tab/sidebar/Host card, light Routing > OSPF > Redistribute. Process 1, networks 3, SYNC; .104/PID 1, protocol static, Subnets checked, Add Redistribute. ISP1 identity and Redistribute page contradict r2-process ID/name. Do not silently identify as R2 or R6, or invent ISP1 canonical name. |
| `2.png` | `evidence.routing-ospf.router-interface-editor-dark` | APPROVE_COPY | R1 / .101; Router Interfaces > Physical, dark theme. Eight-interface inventory shows management and routed IPv4 addresses; right pane says Select a physical interface with unbound Identity and addressing / Layer 3 form, disabled Save Interface. Generic router-interface-editor-dark is valid for the editor view without a selected editable interface; it does not assert saved/actively edited input. Distinct from selected light interface 1. |
| `3.png` | `evidence.routing-ospf.router-interface-addresses-dark` | APPROVE_COPY | R2 / .102; Router Interfaces > Physical, dark theme. Eight interfaces include .102 management, 10.1.12.2 on Gi0/1, 10.1.23.1 on Gi0/3 and 192.168.10.1 on Gi0/4; right editor remains unselected. router-interface-addresses-dark accurately identifies visible interface IPv4 inventory. Distinct device/address set from R1 capture 2. |
| `4.png` | `evidence.routing-ospf.router-interface-policy-dark` | HOLD | R3 / .103; Router Interfaces > Physical, dark theme. Gi0/1 row highlighted with No IPv4 address; right pane still says Select a physical interface and shows unbound standard addressing/L3 fields. router-interface-policy-dark does not identify a distinct visible policy. Current InterfaceEditorPane.qml labels the same form Identity and addressing / Layer 3 options, not a policy page. No repository evidence establishes the planned policy-specific subject. |
| `5.png` | `evidence.routing-ospf.router-interfaces-inventory-dark` | HOLD | SW9 / .109; Switching > Switch Ports > Access, dark theme. Ten ports/up, nine access, one trunk; Gi0/0 read-only selected Access VLAN 99, other ports include VLAN 30/40; applied two switching tasks. Visible switching inventory contradicts routing-ospf router-interfaces-inventory-dark ID/domain/name. Do not invent a switching canonical identity in B12. |
| `6.png` | `evidence.routing-ospf.router-interfaces-selected-dark` | HOLD | SW8 / .108; Switching > Switch Ports > Access, dark theme. Ten ports/up/access, zero trunks; Gi0/0 read-only Access VLAN 99 selected, Gi0/2 Access VLAN 20. Switch-port selection contradicts router-interfaces-selected-dark identity; distinct switch/count/VLAN state from SW9 5 and SW7 7. |
| `7.png` | `evidence.routing-ospf.router-interface-edit-dark` | HOLD | SW7 / .107; Switching > Switch Ports > Access, dark theme. Ten ports/up/access, zero trunks; Gi0/0 read-only Access VLAN 99, Gi0/2 Access VLAN 10. No router-interface editor shown; router-interface-edit-dark identity contradicted. Read-only switch-port details are not an active router edit. |
| `8.png` | `evidence.routing-ospf.router-interface-counters-dark` | HOLD | R1 / .101; Routing > Info > Overview, dark theme. Routing Information counters Routes/Visible/Best/Protocols all zero; no routing entries. Routing information counters are not router-interface counters. Planned router-interface-counters-dark identity is unsupported. Distinct page from OSPF process 9. |
| `9.png` | `evidence.routing-ospf.router-process-overview-dark` | APPROVE_COPY | R1 / .101; Routing > OSPF > Process, dark theme. OSPF PROCESS 0, NETWORKS 0, state SYNC; No OSPF process saved, Add Process visible. Generic router-process-overview-dark describes empty OSPF process overview accurately. No configured/successful process claim; distinguish from Routing Info 8 and R2 Redistribute 13. |

HOLD records remain pending at legacy paths, canonical=false, and all nine complete records are unchanged. Their existing proposed IDs/paths are historical planning metadata, not approved identities. No replacement names were invented. See immutable `b12-review.md/json` for the original full-resolution review fixed before copying.

## Current usage and report boundaries

Re-scanning actual paths found five live references, all in `00_report/contents/09_thu_nghiem_danh_gia.typ`. Contrary to stale preliminary planning, starting HEAD already has correct used_by/targets for all 15: 13 and 15 are unused; 14 and 16 have their own live references. **Zero starting usage corrections were required.** Only three used_by referenced_path values were refreshed after approved path rewrites; targets and line numbers stay unchanged.

| Source | Line | Action | Reference after B12 |
|---|---:|---|---|
| `1.png` | 77 | Rewritten to exact copy | `/documentation_assets/evidence/ui-capture/original/routing-ospf-lab/router-interfaces-overview.png` |
| `10.png` | 87 | Rewritten to exact copy | `/documentation_assets/evidence/ui-capture/original/routing-ospf-lab/routing-group-hosts.png` |
| `11.png` | 95 | Rewritten to exact copy | `/documentation_assets/evidence/ui-capture/original/routing-ospf-lab/routing-group-networks.png` |
| `14.png` | 142 | HOLD; retained legacy | `/00_book/figures/report/diagrams/routing-ospf-lab/14.png` |
| `16.png` | 129 | HOLD; retained legacy | `/00_book/figures/report/diagrams/routing-ospf-lab/16.png` |

The report source is byte-for-byte equal to the starting Git source after exactly three authorized image-path literal replacements. Caption, width, label, prose and line count are unchanged. The complete repository reference multiset matches the starting scan after those three path substitutions; no terminal or unrelated OSPF refs changed.

Existing contradictions are preserved and reported: 10 shows six unchecked hosts rather than selected hosts and a 2–5 heading; 11 shows Area 0 while the report table assigns Area 1; 14 provides no explicit group identity and no route-map filter matching the surrounding paragraph; 16 visibly selects ISP1/.104 despite the R2 planned identity and R6 caption/prose. The known Group Networks issue and production/report claims are outside B12.

## Byte preservation and inventory

Final counts: **455 total / 253 migrated / 127 pending / 75 frozen**. Non-frozen progress: **253/380 = 66.58%**. All 455 current manifest SHA contracts pass against the starting Git blob, current filesystem and index. Six canonical pairs have identical legacy Git/filesystem, canonical filesystem/index and manifest SHA.

| Legacy source | Canonical evidence copy | SHA-256 (all five authorities) |
|---|---|---|
| `00_book/figures/report/diagrams/routing-ospf-lab/1.png` | `documentation_assets/evidence/ui-capture/original/routing-ospf-lab/router-interfaces-overview.png` | `98426b2a12db4173473253eb032d97d61995349bfb5660b686b0dadec6c68b28` |
| `00_book/figures/report/diagrams/routing-ospf-lab/10.png` | `documentation_assets/evidence/ui-capture/original/routing-ospf-lab/routing-group-hosts.png` | `3a5bb49ff629e349cc22076db1e5ea41ab9d877e9cd30c9ffd7e47ce137d74bb` |
| `00_book/figures/report/diagrams/routing-ospf-lab/11.png` | `documentation_assets/evidence/ui-capture/original/routing-ospf-lab/routing-group-networks.png` | `20a3ce2f004c74f6f5abcc65b7467d0ab15de9483ab800926fd3c364c80b3fff` |
| `00_book/figures/report/diagrams/routing-ospf-lab/2.png` | `documentation_assets/evidence/ui-capture/original/routing-ospf-lab/router-interface-editor-dark.png` | `e67bf4ab1c89813323bfae2e089b0811a82b64bd27fe7b4feadbb7c330dbfe9f` |
| `00_book/figures/report/diagrams/routing-ospf-lab/3.png` | `documentation_assets/evidence/ui-capture/original/routing-ospf-lab/router-interface-addresses-dark.png` | `86643a83be2ae67f2d69a2fb24903bcc3cd38814e7bd448b5be567dee9ff51b4` |
| `00_book/figures/report/diagrams/routing-ospf-lab/9.png` | `documentation_assets/evidence/ui-capture/original/routing-ospf-lab/router-process-overview-dark.png` | `614946c0b125eedc2654d2a62a9253f6c15ef5e17ca73fa284e2f6a25af1d0e5` |

All 440 records outside B12 and nine B12 HOLD records are unchanged. For approved copies, only current_path/path/migration_state/canonical and three actual used_by paths changed. SHA, provenance, legacy_path, source_kind, original/preserve flags, status, planned semantic identity and transition intent remain unchanged. Tracked physical inventory is 484 = 455 logical records + 29 retained originals (two prior B02 + 21 B11 + six B12 copies).

The tree retains every legacy entry and adds six canonical locations plus nine legacy-only HOLD entries. B12 staging is zero; existing 178 staging selections remain hash-correct and generated/untracked. Broken-image baseline stays empty and byte-identical. All 75 frozen terminal registry/path/byte/reference contracts, term2png/text/generated assets, reconciled LAB1 evidence, B11/B02/B06 HOLDs, runtime/production QML and B03 docshot mapping are untouched.

## Validation

| Checkout | Command | Result |
|---|---|---|
| Execution cheap | `python scripts/validate_documentation_assets.py --manifest-only` | PASS |
| Execution cheap | `python -m unittest tests.test_documentation_assets -v` | PASS (22 tests) |
| Execution cheap | `python -m unittest tests.test_docshot_destinations -v` | PASS (17 tests) |
| Execution cheap | `python -m unittest tests.test_typst_tooling -v` | PASS (3 tests) |
| Execution cheap | `git diff --check` | PASS |
| Execution cheap | `git diff --cached --check` | PASS |
| Local final | `python scripts/validate_documentation_assets.py --manifest-only` | PASS |
| Local final | `python scripts/sync_documentation_assets.py` | PASS |
| Local final | `python scripts/validate_documentation_assets.py --check-staging` | PASS |
| Local final | `python -m unittest tests.test_documentation_assets -v` | PASS (22 tests) |
| Local final | `python -m unittest tests.test_docshot_destinations -v` | PASS (17 tests) |
| Local final | `python -m unittest tests.test_typst_tooling -v` | PASS (3 tests) |
| Local final | `/tmp/cams-b02b4/docs-venv/bin/mkdocs build --strict` | PASS |
| Local final | `python scripts/build_typst.py` | PASS |
| Local final | `python scripts/build_typst.py` | PASS |
| Local final | `git diff --check` | PASS |
| Local final | `git diff --cached --check` | PASS |
| Fresh final | `python scripts/validate_documentation_assets.py --manifest-only` | PASS |
| Fresh final | `python scripts/sync_documentation_assets.py` | PASS |
| Fresh final | `python scripts/validate_documentation_assets.py --check-staging` | PASS |
| Fresh final | `python -m unittest tests.test_documentation_assets -v` | PASS (22 tests) |
| Fresh final | `python -m unittest tests.test_docshot_destinations -v` | PASS (17 tests) |
| Fresh final | `python -m unittest tests.test_typst_tooling -v` | PASS (3 tests) |
| Fresh final | `/tmp/cams-b02b4/docs-venv/bin/mkdocs build --strict` | PASS |
| Fresh final | `python scripts/build_typst.py --toolchain-dir /home/ntdatphu/Data/Workspace/Repository/CAMS/output/typst/toolchain` | PASS |
| Fresh final | `python scripts/build_typst.py --toolchain-dir /home/ntdatphu/Data/Workspace/Repository/CAMS/output/typst/toolchain` | PASS |
| Fresh final | `git diff --check` | PASS |
| Fresh final | `git diff --cached --check` | PASS |

Every test run totals **42 documentation tests** (22 asset + 17 destination + three Typst tooling). Pinned Typst toolchain/fonts and repository deterministic build configuration are used. Both local builds and both fresh builds exactly match baseline:

| PDF | Pages | SHA-256 |
|---|---:|---|
| report | 117 | `a78c673bb8730c28fe807601434dd1d1632466ef8f252f9d113936ba26c64985` |
| book | 170 | `aa4203a6d8ec73764857603c383cb40c80cf9aaa04fbf804b85a14eabc418442` |

MkDocs strict uses the installed documentation virtual environment. No remote CI was run or claimed.

## Commit and fresh-checkout gate

Execution commit: `232bd0634acfcb7e922c59dc7e3d80218f94a7e4` (`docs: preserve reviewed B12 OSPF evidence`).

Exactly one final clean candidate checkout passed: `7c2f40645ae6d95294268b6e083580afc1e5d87a`. Main `289568fecdcd6fa61564f897cd2ed996ad7fd1c0` is an ancestor, behind=0. Fresh validation confirms all 455 SHA contracts, six preserved original/canonical pairs, nine HOLD legacy-only sources, five valid live B12 refs, zero broken images/staging and 75 immutable terminal contracts. Only these closure validation reports are finalized after the tested candidate.

Closure commit: `docs: close B12 semantic evidence holds`; final local/remote SHA is verified and reported after commit/push. Working tree must be clean and every gate PASS. STOP after push; do not begin B13.

Outputs: `b12-review.md/json`, `b12-closure.md/json`. Per-asset byte proofs, actual before/after usage and command results are in the machine-readable closure.
