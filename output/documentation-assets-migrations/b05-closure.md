# B05 closure — legacy interface/routing UI

B05 **33/33 migrated byte-for-byte**, exactly three functional packs: A interface/static=10, B OSPF=14, C EIGRP=9. No screenshot regeneration, new docshot workflow, production QML change, or B06 work. Current source_kind/provenance stays unknown; replacement intent is unchanged. Starting commit `a6887e05c9edffebd9f75a7f792e6aa4b6015deb`; initial fetch confirmed main behind=0.

Final manifest **122 migrated / 223 pending / 62 frozen**, total 407. All 407 original Git blob / current filesystem / canonical index / manifest SHA contracts PASS. All 33 old B05 files absent and 33 canonical files present. All 178 manifest-selected MkDocs staged assets match their SHA, are ignored and untracked; staging is generated rather than committed.

**55 actual live reference rewrites**: 33 MkDocs HTML image references, 21 book Typst references, one report Typst reference. Captions, prose, geometry, labels and figure order unchanged. The report use of interface view-push is retained. Markdown-only images have no invented Typst use. Current figures inventory reflects the canonical paths.

| Pack | Assets | References | Exact exceptions removed | Baseline | Tests actually run |
|---|---:|---:|---:|---|---:|
| B05A | 10 | 18 | 10 | 137 → 127 | 39 |
| B05B | 14 | 24 | 14 | 127 → 113 | 39 |
| B05C | 9 | 13 | 9 | 113 → 104 | 39 |

Baseline **137 → 127 → 113 → 104**, exact 33 resolved entries removed; source/version/description and remaining exceptions unchanged. A/B passed cheap gates and committed locally without pushing or claiming full builds. Full cumulative C validation PASS: manifest-only, sync, check-staging, three unittest suites (39 actual tests), MkDocs strict, repository-pinned Typst, git diff --check and git diff --cached --check. No dependency installation.

| Typst target | Physical pages | SHA-256, byte-identical to starting baseline |
|---|---:|---|
| report | 110 | `627d59abb47e831782a5cd401b5317d85e04169092596951b132df63b3871576` |
| book | 170 | `aa4203a6d8ec73764857603c383cb40c80cf9aaa04fbf804b85a14eabc418442` |

B02 intentional HOLD records and retained source copies remain unchanged. B03 42 canonical PNGs/semantic map/dialog policy, 62 frozen terminal images/contract/reference multiset, runtime assets and application behavior remain unchanged. The OSPF Group Networks known bug is not fixed or reinterpreted: legacy screenshot bytes are preserved. No forced provenance upgrade.

**One final clean checkout PASS** at candidate `154cbe4148faa29b0e0c22a78ea52c49141ca1c3`: 39 actual tests and all cumulative gates/proofs above. Only report completion follows this candidate; final commit source/config/assets are identical to the validated tree. No extra A/B checkout was required. Full commands and machine-readable proofs are in b05c.json.

Local A/B commits:

- `fa2bf1b57908d5205be1e9b35ca08d41311b3dcd docs: migrate B05A interface and static routing UI`
- `dba4551158f7eaa13cc6cd0c6b59d0a329f38cab docs: migrate B05B OSPF legacy UI`

The final C commit contains this closure. Push all three together only after final success, then STOP; no B06+.
