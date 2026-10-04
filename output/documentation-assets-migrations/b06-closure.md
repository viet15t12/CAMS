# B06 closure — DHCP / ACL / FHRP / NAT legacy UI

B06 review/migration is **CLOSED: 38/39 migrated + one intentional HOLD**. All 38 fast-lane PNGs were migrated byte-for-byte in A=11 (DHCP/ACL), B=13 (safe FHRP), C=14 (NAT). No screenshot regeneration, reconstruction, overlays, new docshot workflow or production QML change. Source_kind/provenance remain unknown; future regenerate-canonical/new-workflow intent stays separate. Starting HEAD `651c479fd19505a0b2a828b3a7155a171f5e8720`; initial main fetch behind=0.

**B06R HOLD**: `ui.routing.fhrp.hsrp-authentication-timers`. The PNG shows Hold timer and member policy/preempt/tracking, with no visible authentication control. Chapter 09 and QML separate the authentication view, which is visible in a different neighbour. Therefore the planned combined authentication/timers identity is insufficiently supported. The entire orphan manifest record/source bytes remain unchanged: pending, canonical=false, review_required=true, used_by=[], targets=[], mkdocs_stage=false, provenance unknown/low. Legacy path stays present and in the figures inventory; planned canonical destination is absent. Provisional observational name is recorded only, not adopted. HOLD is an intentional valid closure, not migrated and not a build/test failure. Details/evidence in b06r.md/json.

Final manifest **160 migrated / 185 pending / 62 frozen**, total 407. All 407 original Git blob / filesystem / index / manifest SHA contracts PASS. All 38 fast-lane old files absent and canonical files present. Other 369 records, including B06R and B02 HOLDs, are unchanged.

**64 actual reference rewrites**: 38 MkDocs HTML image references + 26 book Typst references; no report reference affected. Captions, prose, geometry, labels and order unchanged. Markdown-only assets have no invented Typst usage; the orphan has no invented use. Current figures tree reflects only migrated assets and keeps the HOLD legacy entry.

| Pack | Assets migrated | References rewritten | Exact baseline removals | Baseline | Actual cheap-gate tests |
|---|---:|---:|---:|---|---:|
| B06A | 11 | 22 | 11 | 104 → 93 | 39 |
| B06B | 13 | 20 | 13 | 93 → 80 | 39 |
| B06C | 14 | 22 | 14 | 80 → 66 | 39 |
| B06R (HOLD) | 0 | 0 | 0 | 66 → 66 | full cumulative gate |

Baseline **104 → 93 → 80 → 66 → 66**. Only 38 exact resolved exceptions removed; original baseline metadata and all remaining entries unchanged. No wholesale regeneration. A/B/C committed locally after cheap gates without pushing or claiming full builds.

Full cumulative local gate **PASS**: 39 actual tests across the three required suites, manifest-only, sync, check-staging, MkDocs build --strict, repository-pinned build_typst.py, git diff --check and git diff --cached --check. No dependency installation. All 178 selected staged assets match SHA, are ignored/untracked, and no staging is committed.

| Typst target | Physical pages | SHA-256, byte-identical to starting B05 baseline |
|---|---:|---|
| report | 110 | `627d59abb47e831782a5cd401b5317d85e04169092596951b132df63b3871576` |
| book | 170 | `aa4203a6d8ec73764857603c383cb40c80cf9aaa04fbf804b85a14eabc418442` |

B02 HOLD assets/retained copies, all B03 canonical PNGs/output map/dialog policy, B05 assets, terminal freeze/62 images/reference multiset, runtime assets and production behavior unchanged. No B07+.

**One final clean checkout PASS** at candidate `681ac021c9b0ab598a47de00395e11a16c20a31e`: 39 actual tests and all cumulative gates above. Only execution-report completion follows the validated tree. The same checkout will select the final commit to verify clean state and SHA proofs; no duplicate full build is necessary for report-only changes. Full machine-readable command/proof evidence is in b06r.json.

Local fast-lane commits:

- `ae51f5f492ca777f6765acaeb06b039c7f4bcbe4 docs: migrate B06A DHCP and ACL legacy UI`
- `2cdbd8eafa32d4d02e646b6465e55b5ea8fccac8 docs: migrate B06B FHRP legacy UI`
- `7d4ef952081849ceec0892da987e9e0e76765d28 docs: migrate B06C NAT legacy UI`

Final review commit: `docs: resolve B06 FHRP review gate`. Push all four together only after full cumulative/fresh success, then STOP. No B07.
