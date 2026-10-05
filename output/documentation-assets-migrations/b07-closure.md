# B07 closure — legacy switching UI

B07 **35/35 migrated byte-for-byte**, in four logical commits: A=9 L2/VLAN; B=10 EtherChannel/STP/VTP; C=14 L3/DHCP/ACL; R=2 reviewed monitoring captures. Starting HEAD `964745b724e1ecd44748aafadd420d62f040bf1e`; initial fetch main behind=0. No B08 work.

Monitoring review decisions: **APPROVE_MIGRATION** independently for `ui.switching.monitoring.port-counters` and `ui.switching.monitoring.mac-address-table`; no B07 HOLD. Direct original-PNG inspection shows the intended Port Counters and MAC Address Table UI and columns. Current chapter 17 teaches filtering/reloading/interpreting collected UI state, with no specific experimental measurement/result asserted for these values; live uses are only book Markdown/Typst. The captured values may originate from collected data or fixtures: acquisition provenance is unknown, and no claim of synthetic/real data is made. Byte-preserving movement retains the exact data and semantics. It does not establish future reproducibility or generator provenance.

Future transition policy is unchanged: **33 regenerate-canonical / 2 investigate-first**. All remain ui/legacy, source_kind/provenance unknown, replacement-candidate, original_evidence=false, preserve_original=false; no regeneration, resize, crop, recompression, overlays, monitoring fixtures/new workflows or production QML change. See b07r.md/json for per-image review evidence.

Final manifest **195 migrated / 150 pending / 62 frozen**, total 407. All 407 original Git blob / current filesystem / index / manifest SHA contracts PASS. All 35 old B07 physical files absent; 35 canonical files present. Other 372 records unchanged. A/B/C fast lane alone reached 193/345 nonterminal migrations (55.94%); final 195/345 (56.52%).

**67 actual live reference rewrites**: 35 MkDocs HTML image references and 32 book Typst references; no report use. Captions, prose, geometry, order and labels unchanged. Markdown-only assets receive no invented Typst usage. Current figures tree shows only canonical migration locations; B06 orphan HOLD remains in its legacy entry.

| Pack | Assets | References | Exact exceptions removed | Baseline | Actual cheap/local tests |
|---|---:|---:|---:|---|---:|
| B07A | 9 | 17 | 9 | 66 → 57 | 39 |
| B07B | 10 | 20 | 10 | 57 → 47 | 39 |
| B07C | 14 | 26 | 14 | 47 → 33 | 39 |
| B07R | 2 | 4 | 2 | 33 → 31 | 39 |

Baseline **66 → 57 → 47 → 33 → 31**. Only 35 exact exceptions resolved by current Markdown rewrites are removed; metadata and remaining entries preserved. No wholesale baseline regeneration. A/B/C passed cheap gates before commit and also ran the requested post-commit cheap gates (39 actual tests each), with no fresh checkout per pack or early push.

Full cumulative local gate PASS: manifest-only, sync, check-staging, the three required unittest suites (**39 actual tests**), MkDocs strict, repository-pinned Typst, git diff --check and git diff --cached --check. No dependencies installed. All 178 manifest-selected staging assets match SHA and remain generated, ignored and untracked; none committed.

| Typst target | Physical pages | SHA-256, byte-identical to starting baseline |
|---|---:|---|
| report | 110 | `627d59abb47e831782a5cd401b5317d85e04169092596951b132df63b3871576` |
| book | 170 | `aa4203a6d8ec73764857603c383cb40c80cf9aaa04fbf804b85a14eabc418442` |

B02 HOLD sources/records and retained copies, B06 HOLD source/record, B03 42 canonical PNGs/output map/dialog policy, all B05/B06 migrated assets, terminal freeze/62 images/reference multiset, runtime assets and production behavior remain unchanged. No historical audit/planning files were rewritten.

**One final clean checkout PASS**, candidate `56c0a0e4df95fc12b557ff5d776c5834c2eb6c00`: 39 actual tests, all 407 SHA contracts, exact counts/path/staging checks, MkDocs/Typst and unchanged PDF SHA. Only three execution reports are completed after the validated tree; final source/config/assets remain identical. The same checkout will select final commit and recheck clean state/SHA proofs. Full machine-readable commands/evidence in b07r.json.

Local fast-lane commits:

- `9abb3c3e55b797b893eb9e9a53d331b7ce396bff docs: migrate B07A L2 interface and VLAN UI`
- `98ec51fd4a0b1d251dcb9dd2d37a4ada55c0ff0b docs: migrate B07B switching protocol UI`
- `fef194fff22590b8bff2d65f48cd97f947941c79 docs: migrate B07C L3 switching services UI`

Final review commit: `docs: resolve B07 monitoring review gate`. Push all four only after full cumulative/fresh success, then STOP; no B08.
