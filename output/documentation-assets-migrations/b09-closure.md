# B09 closure — transfer/snapshot legacy UI

**B09 CLOSED: 12/12 migrated, 12 APPROVE_MIGRATION / 0 HOLD_MIGRATION.** All review decisions completed as a group before moves. Fixed execution packs: B09A 9 SFTP/SCP images; B09B 3 snapshot/history images. B09A commit `30540b454f47ad34f1be60a703db83bb69e27516`; B09B follows as `docs: migrate B09B snapshot legacy UI`. No extra bookkeeping commit needed.

Manifest **213 migrated / 132 pending / 62 frozen**, total 407; nonterminal canonical scope 213/345 = 61.74%. Exactly 12 Git renames preserve original PNG bytes and all 407 SHA contracts. Unknown/low provenance and unknown source_kind retained. Future replacement remains **investigate-first**, needs_new_workflow=true; no regeneration approval granted.

Current documentation presents transfer workspace, authentication/host-key controls, notifications, snapshot browsing and version diff as UI behavior. No measured throughput/raw lab result assertion found in current captions/context. Visible example-like data alone do not prove generator provenance. Host-key confirmation is an application UI dialog. No real network/device/file-transfer actions or screenshot rendering/recreation performed.

**23 exact current references** rewritten: B09A 16 (9 Markdown + 7 book Typst), B09B 7 (3 Markdown + 3 book Typst + 1 report Typst). Local/remote files remain Markdown-only. Report Diff updated at line 36; captions, geometry, labels, prose and order unchanged. Actual used_by source/path/line refreshed.

Baseline **25 → 16 → 13**, exactly 9 B09A and 3 B09B exceptions removed by their current Markdown rewrites. Metadata and remaining baseline entries preserved. Twelve staged files match canonical SHA; all 178 selected staged assets match and stay generated/ignored/untracked. Figures tree removes only migrated paths and records canonical destinations.

B09A cheap gate: 39 actual tests and manifest/sync/staging/diff checks PASS; no fresh checkout performed at that stage. Cumulative full local gate: 39 actual tests, strict MkDocs and pinned Typst PASS. Report **110 pages**, book **170 pages**, PDF SHA byte-identical to baseline:

- report `627d59abb47e831782a5cd401b5317d85e04169092596951b132df63b3871576`
- book `aa4203a6d8ec73764857603c383cb40c80cf9aaa04fbf804b85a14eabc418442`

B02 intentional HOLDs/retained copies, B06 HOLD, B03 semantic map/42 canonical PNGs, terminal-freeze contract/62 sources/reference multiset, runtime assets and production QML unchanged. B10+ untouched. Review and execution details: `b09-review.md/.json`, `b09a.md/.json`, `b09b.md/.json`.

**One final cumulative clean checkout PASS** at `7ea54d12fd8ebc39e435b43f09d1fcb5ea2e8dd3`: 39 tests, all 407 SHA contracts, 213/132/62 counts, 12 old paths absent/new paths present, MkDocs strict, pinned Typst and stable PDF SHA, staging ignored/untracked and protected contracts. Final candidate differs only by completion of these execution reports; the same checkout selects the final commit for clean-state/SHA confirmation.

Push only after all gates pass. After successful push STOP; do not start B10.
