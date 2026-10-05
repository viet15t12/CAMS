# Shared documentation assets — infrastructure foundation

Current inventory after B11: **455 records: 247 migrated, 133 pending, 75 frozen**. B11 review is CLOSED: 21 exact canonical evidence copies with every legacy original retained, plus six intentional semantic-review HOLDs (`1_1`, `1_18`, `1_19`, `1_22`, `1_32`, and unresolved `1_6`). All 27 B11 records still have zero live image references; none is staged or recreated. Source SHA/provenance/evidence policy and all HOLD records remain unchanged. See `output/documentation-assets-migrations/b11-review.md`, `b11a.md`, `b11b.md`, `b11c.md`, `b11r.md` and `b11-closure.md`.

Historical inventory after reconciling main `289568f`: **455 records: 226 migrated, 154 pending, 75 frozen**. The 48 main-added PNGs remain at their merged paths; 13 newly reviewed terminal/CLI files are frozen, and 15 raw/presentation pairs have exact SHA equality. B11 has 27 nonterminal records with zero current image references; no B11 migration occurred. See `output/documentation-assets-reconciliation/main-289568f.md` for the review and new deterministic PDF baseline.

Historical inventory at B10B closure: **226 migrated canonical assets, 119 pending nonterminal records, 62 frozen external records**. B10 is CLOSED: 13/13 Syslog configuration/System Logs legacy UI assets migrated byte-for-byte; seven System Logs APPROVE_MIGRATION / zero HOLD_MIGRATION. Provenance unknown retained; future B10A regenerate-canonical and B10B investigate-first policies unchanged; no regeneration. Reference baseline broken_images is empty (0). B04-B10 Phase 6 legacy UI execution is complete with the existing B06 intentional HOLD unchanged. See `output/documentation-assets-migrations/b10a.md`, `b10b-review.md`, `b10b.md` and `b10-closure.md`; no B11 work. B09 is CLOSED: 12/12 transfer/snapshot legacy UI assets migrated byte-for-byte, 12 APPROVE_MIGRATION / 0 HOLD_MIGRATION; unknown provenance retained and future regeneration remains investigate-first; no regeneration. See `output/documentation-assets-migrations/b09-review.md`, `b09a.md`, `b09b.md` and `b09-closure.md`. B08 is CLOSED: 6/6 legacy switching security UI assets migrated byte-for-byte; unknown provenance and future regenerate-canonical/new-workflow intent retained; no regeneration. See `output/documentation-assets-migrations/b08.md`. B07 is CLOSED: 35/35 legacy switching UI assets migrated byte-for-byte; both monitoring captures APPROVE_MIGRATION, future investigate-first retained; no regeneration. See `output/documentation-assets-migrations/b07-closure.md` and `b07r.md`. B06 is CLOSED: 38/39 legacy DHCP/ACL/FHRP/NAT UI assets migrated byte-for-byte + one intentional HOLD (`ui.routing.fhrp.hsrp-authentication-timers`, authentication not visible in the PNG); no regeneration. See `output/documentation-assets-migrations/b06-closure.md` and `b06r.md`. B05 is CLOSED: 33/33 legacy interface/static/OSPF/EIGRP UI assets migrated byte-for-byte; no regeneration. See `output/documentation-assets-migrations/b05-closure.md`. B04 migrated all 10 legacy chapter-02 project/core PNGs byte-for-byte with unknown provenance retained, 18 references rewritten and 10 exact baseline exceptions resolved (147 → 137); see `output/documentation-assets-migrations/b04.md`. B03 is CLOSED: 42/42 confirmed core/navigation/device/VLAN docshots migrated with unchanged PNG bytes. Managed default generation uses the explicit semantic output map; dialogs remains temporary-only. B02A migrated five used documentation sources; B02B1/B02B2/B02B3 preserve fifteen reviewed orphan diagrams. B02B4 adds three orphan workflows and two active report diagrams with byte-identical retained legacy sources under `preserve_original=true`. B02C adds four orphan assets as two independent raster/vector pairs with confirmed different content; no derivative relation or deduplication. B02D adds two independent representations of the same branch/backbone lab topology with export provenance unproven: the report retains its raster presentation and the vector remains orphan-review. B02E1 adds three reviewed legacy raster network diagrams, all still orphan-review with exact original JPEG bytes. B02E2 adds three reviewed legacy raster diagrams for DHCP Snooping, DHCP DORA and VLAN segmentation, all still orphan-review. The DORA raster and existing authored SVG remain independent representations of the same concept without proven derivative lineage. Retained legacy copies are not extra manifest records. B02 review is **CLOSED: 37/39 migrated + 2 intentional HOLD**. B02F holds PTIT for unresolved local Inkscape compatibility despite a successful pinned Typst render, and lab_4 for unverified branch/scenario semantics. Both logical records remain pending at their legacy paths; HOLD does not mean migrated. See `output/documentation-assets-migrations/b02a.md`, `b02b1.md`, `b02b2.md`, `b02b3.md`, `b02b4.md`, `b02c.md`, `b02d.md`, `b02e1.md`, `b02e2.md`, `b02f.md` and `b02-closure.md`. Runtime assets, terminal evidence and later batches remain outside this migration. No actual canonical rendering was run in B03. The Phase 3 counts below describe the historical bootstrap.

This store is the future authority for migrated book/report documentation assets. Phase 3 creates metadata only: **345 pending nonterminal records, 62 frozen external records, zero migrated images**. No screenshots are moved, renamed, rendered or replaced here.

## Repository byte contract (Phase 3.3)

Documentation image SHA-256 represents exact repository-stored bytes. Explicit `-text` rules in `.gitattributes` cover SVG/PNG/JPG/JPEG/WebP/GIF under `00_book/figures/`, `00_report/`, and `documentation_assets/`; Git cannot normalize their EOLs during add or checkout. Runtime/application assets retain their existing policy. The validator hashes binary filesystem bytes without normalizing or ignoring differences.

Phase 3.3 corrects 29 prior manifest hashes derived from CRLF working-tree copies to the corresponding committed LF blob hashes. No image semantics, classification, migration state, planned path, approval, or terminal contract changes. The historical planning hashes remain historical evidence; see `output/documentation-assets-foundation/phase3-3-eol-audit.csv` for the explicit reconciliation and `phase3-3.md` for clean-checkout verification.

## Manifest lifecycle

`manifest.yaml` is bootstrapped from the committed Phase 2.1 planning overlay, using its current SHA-256 values. Each record has a stable logical ID, authoritative `current_path` (also `path`), `planned_canonical_path`, and `migration_state`:

- `pending`: current legacy source exists and matches SHA; planned canonical target may not exist. `canonical=false`. One UI naming hold has no planned path and explicit unresolved/review metadata.
- `migrated`: current path equals planned canonical path, target exists with matching SHA, `canonical=true`. A future batch must update source location, all references, manifest and staging together.
- `frozen`: current external path exists with matching SHA; `canonical_migration=false`, `canonical=false`, no planned target or staging. Terminal bytes, filenames and reference literals remain unchanged in every later phase.

`terminal-freeze.json` pins 75 terminal IDs/paths/hashes and their current reference multiset. The original 62 asset records are unchanged; the main reconciliation adds 13 terminal files and explicitly records the main-driven removal of one obsolete Lab1 reference. It includes generated terminal assets and historical CLI/log/connectivity captures. Line numbers may shift during nonterminal edits; changing a terminal reference literal/count is rejected. Terminal text sources and `term2png.py` remain untouched. No terminal reconstruction workflow is implemented or permitted.

Six nonterminal exact-copy pairs retain distinct physical inventory records pending shared canonical identity/alias review. `canonical_group_id` is a review group, not automatic deduplication. Resolve affected groups before B13/B15 transfer; preserve current copies/provenance. UI recreation may still be planned separately with `recreates_evidence_asset`; no hypothetical asset with missing bytes is added to this current-byte manifest.

## Validation

```sh
python -m pip install -r requirements-docs.txt
python scripts/validate_documentation_assets.py --manifest-only
python scripts/sync_documentation_assets.py
python scripts/validate_documentation_assets.py --check-staging
python scripts/validate_documentation_assets.py --strict-references
```

The validator checks unique IDs/casefold canonical paths, containment/traversal/symlinks, current SHA, pending/migrated/frozen state, stage suffixes, logical links/cycles and frozen reference literals. Frozen paths outside this store are valid. It also scans Markdown/HTML/CSS and Typst image/helper syntax plus MkDocs logo/favicon paths. Report sources cannot reference MkDocs staging.

`reference-baseline.json` currently has **zero broken image references** (the historical bootstrap recorded 178). New errors fail; strict reference validation must also pass. Remove each resolved baseline entry in the same batch; never regenerate the baseline to hide regressions. A MkDocs strict build can succeed despite broken raw HTML image URLs, so it does not replace this static check.

## Generated staging

```sh
python scripts/sync_documentation_assets.py --dry-run
python scripts/sync_documentation_assets.py
python scripts/sync_documentation_assets.py --check
mkdocs build --strict
```

`00_book/assets/` is generated and gitignored, including its `.documentation-assets.json` ownership ledger. Only manifest `mkdocs_stage=true` nonterminal records are selected (currently 178). Staged suffixes mirror planned canonical paths; bootstrap copies from legacy `current_path`, later migrated records copy from canonical `current_path`. Copying into staging is not canonical migration and does not rewrite current document references. No frozen terminal is staged, and no 345-asset bulk copy into this store occurs.

The sync resolves this checkout independently of CWD, verifies source/destination hashes, copies bytes losslessly through temporary files and atomic replace, and uses deterministic JSON/order. Dry-run/check never write. A journal ledger owns intended outputs before copying so interrupted sync can retry; the completed ledger is written after successful cleanup. Unknown/unowned files, invalid ledgers, symlinks or modified stale files fail safely. Stale removal applies only to valid ledger-owned paths inside staging; source assets and arbitrary files are never deleted. The interrupted journal cannot pass `--check`.

Default docshot output now lives under `documentation_assets/ui/docshot/` by workflow domain. `--output-dir` remains an exact explicit override, including chapter workflows. Existing renderer filenames remain unchanged in this foundation; semantic filename/output-map transition belongs to its future asset batch. Phase 3.1 strategy B blocks default writes until B03 implements a manifest-backed semantic output map; explicit `--output-dir` still works. See `output/documentation-assets-foundation/phase3-1.md` for the mismatch audit and release gate.

## CI and next batch

Docs CI watches canonical metadata/source changes, asset scripts and book/config/dependencies. Order: pre-sync `--manifest-only` (current sources and frozen bytes/references) → sync → post-sync `--check-staging` (full references and freshness/hashes) → MkDocs strict build. Fresh checkout does not require generated files during pre-sync. It publishes the website output, not this canonical root. Book Typst's image helper passes project-root `/...` paths through and preserves the old relative behavior; report's helper already supports its existing absolute paths, so it remains unchanged.

B02 (branding/vector) follows the Phase 2.1 atomic plan. Preserve SHA and captions, rewrite only assets in that batch, update manifest current/planned state and baseline exceptions, resync/check, then validate/build. Never include frozen terminals. Baseline/runtime test limitations and executed commands are recorded in `output/documentation-assets-foundation/README.md`.
