# Shared documentation assets — infrastructure foundation

This store is the future authority for migrated book/report documentation assets. Phase 3 creates metadata only: **345 pending nonterminal records, 62 frozen external records, zero migrated images**. No screenshots are moved, renamed, rendered or replaced here.

## Manifest lifecycle

`manifest.yaml` is bootstrapped from the committed Phase 2.1 planning overlay, using its current SHA-256 values. Each record has a stable logical ID, authoritative `current_path` (also `path`), `planned_canonical_path`, and `migration_state`:

- `pending`: current legacy source exists and matches SHA; planned canonical target may not exist. `canonical=false`. One UI naming hold has no planned path and explicit unresolved/review metadata.
- `migrated`: current path equals planned canonical path, target exists with matching SHA, `canonical=true`. A future batch must update source location, all references, manifest and staging together.
- `frozen`: current external path exists with matching SHA; `canonical_migration=false`, `canonical=false`, no planned target or staging. Terminal bytes, filenames and reference literals remain unchanged in every later phase.

`terminal-freeze.json` pins the 62 terminal IDs/paths/hashes and their reference multiset. It includes generated terminal assets and historical CLI/log/connectivity captures. Line numbers may shift during nonterminal edits; changing a terminal reference literal/count is rejected. Terminal text sources and `term2png.py` remain untouched. No terminal reconstruction workflow is implemented or permitted.

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

`reference-baseline.json` explicitly records **178 existing broken HTML image references**. Default validation permits only those precise source/literal/kind/resolution occurrences; new errors fail. Strict reference validation intentionally fails until future atomic batches fix them. Remove each resolved baseline entry in the same batch; never regenerate the baseline to hide regressions. A MkDocs strict build can succeed despite broken raw HTML image URLs, so it does not replace this static check.

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
