# B03 closure

B03 CLOSED: **42/42 confirmed docshot assets migrated**, byte-preserving. No canonical PNG regeneration. Manifest: **79 migrated / 266 pending / 62 frozen**, 407 total. B02 stays CLOSED at 37/39 plus two intentional HOLD, unchanged. No B04/lab-evidence batch started.

## Atomic series

| Commit | Pack | Result |
|---|---|---|
| `36ce6dd778bf6a18f5f244a6a277be8bde7c9a24` | docs: map canonical docshot outputs | PASS |
| `b87ac21cf5ce0753303da934e8f8c4aae360e553` | docs: migrate B03A core docshots | PASS |
| `7d6d66aa80086ef26dcb75dfa33da16c66dafcc3` | docs: migrate B03B device docshots | PASS |
| Final commit containing this report | docs: migrate B03C VLAN docshots | PASS |

B03-0 adds 42 explicit workflow/legacy output → asset ID → semantic canonical path entries and keeps default writes blocked. B03A moves 13 core/navigation assets. B03B moves 20 device assets. B03C moves 9 VLAN assets and enables managed default publishing only after all 42 transitions. The default `all` means the three generic registered shots; four dialog regression outputs have no IDs and remain temporary-only. Temporary overrides keep original filenames and exact destinations.

## Reference and staging contracts

67 current reference edits, with captions/geometry/prose retained; 31 matching historical MkDocs exceptions removed surgically (178 → 147). No baseline refresh to hide errors. All 109 current used_by edges have exact lines and paths with no duplicate edge. The final gate corrects surplus fallback metadata edges produced by the temporary rewrite helper; actual image reference literals were already correct. B03A/B03B execution reference line metadata is corrected in B03C. All 365 records outside B03, both B02 HOLD records, terminal contract/multiset, runtime assets and retained B02 copies are unchanged.

178 manifest-selected MkDocs staging assets: SHA matches source, ignored, none tracked. Generator-only assets gain no document usage or staging. Tree lists canonical locations for migrated files.

## Validation

B03-0: 28 targeted tests PASS. B03A/B03B: 31 required tests each PASS. B03C and cumulative clean checkout: **39 tests PASS** (19 documentation assets, 17 destination/output map, 3 Typst tooling). Manifest-only, sync, staging check, MkDocs strict, pinned Typst and both diff checks PASS. Default map tests cover all 42 identities, cross-domain outputs, status-details, containment, symlinks, temporary overrides, dialogs, all, collisions and unmanaged outputs. Publishing tests only write into temporary test repositories; actual canonical generator was never invoked.

One fresh checkout was created for the full series and reused after adding the final reference-line check. All 407 source Git blob / filesystem / index / manifest SHA contracts PASS. All 42 old physical B03 paths absent; all 42 canonical paths present. Validated candidate: `ced000fc6cbc14fe30511a292a0cc89a7d5207da`, tree `14bba357c92153f41929c8171cd0888f32bbbf3f`. Subsequent changes complete these execution reports only.

| PDF | Physical pages | SHA-256 (unchanged from initial baseline) |
|---|---:|---|
| report | 110 | `627d59abb47e831782a5cd401b5317d85e04169092596951b132df63b3871576` |
| book | 170 | `aa4203a6d8ec73764857603c383cb40c80cf9aaa04fbf804b85a14eabc418442` |

Optional Qt workflow smoke was unavailable: available Python fails to import docshots.runtime because jinja2 is missing. No dependencies/fixtures were invented. This limitation is separate from the passing mocked destination contracts and documentation builds.

## Reports

b03-output-map.md/.json; b03a.md/.json; b03b.md/.json; b03c.md/.json; this b03-closure.md. JSON reports include every identity/path/hash, reference rewrite, baseline removal, test/build outcome and fresh-checkout proof. Stop after push; B04–B10 awaits user review.
