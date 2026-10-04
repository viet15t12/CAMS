# Phase 3.3 — Git-stable documentation asset bytes

Date: 2026-10-04. Branch: `docs/pictures-sort`. Base: `22653d8e80398fb211fe96a9348b60c4f8b387ad`.

## Problem and authority

The previous manifest hashed working-tree copies. `* text=auto` with `core.autocrlf=input` stored LF blobs while some local SVG copies retained CRLF. The complete 407-record audit found 29 mismatches, all exclusively CRLF/LF (4 planned B02A sources and 25 other pending sources); zero frozen assets differed. All 29 original manifest hashes matched the original local working-tree bytes. `phase3-3-eol-audit.csv` records all 407 assets, their original paths/hashes, original Git text attribute, EOL-only determination and action.

## Policy and correction

Explicit `-text` rules cover SVG/PNG/JPG/JPEG/WebP/GIF under `00_book/figures/`, `00_report/` and `documentation_assets/`. Runtime/application assets retain `text=auto`; no global SVG rule was added. No text renormalization command was run.

SHA-256 authority is exact repository-stored image bytes. The 29 affected pending manifest SHA fields now equal the binary-safe `git cat-file blob HEAD:<legacy-path>` SHA. Local copies were restored from those blobs. No image semantics, classification, ID, path, migration state, batch, approval or planned canonical location changed in this foundation. All 345 nonterminal records remain pending; 62 terminal records, their contract and reference multiset remain unchanged. Existing historical plans retain their old hash values and the preflight test verifies the explicit audit reconciliation.

## Regression and clean-checkout validation

Tests verify explicit `text=unset` for current/planned documentation SVGs and all six formats, plus root/nested paths. A real temporary Git repository stores CRLF SVG bytes and checks out exact identical bytes under `core.autocrlf=false`, `true` and `input`; validator SHA checks reject an LF-only substitution. The runtime logo still reports `text=auto`. The validator continues using binary reads without normalizing EOL.

A temporary local clone was created with `core.autocrlf=false`, the six candidate foundation files were committed inside that validation clone, and checkout was forced from its Git blobs. All 407 filesystem SHA values equal the clone's repository blob SHA and manifest SHA; every affected asset remains at its legacy path with `migration_state=pending` (345 pending / 62 frozen / 0 migrated). The existing frozen contract and reference baseline are byte-for-byte unchanged. Staging is generated/untracked; the existing 178 broken-reference exceptions remain unchanged.

Executed in that clean checkout:

| Command | Result |
| --- | --- |
| `python scripts/validate_documentation_assets.py --manifest-only` | PASS |
| `python scripts/sync_documentation_assets.py` | PASS |
| `python scripts/validate_documentation_assets.py --check-staging` | PASS |
| `python -m unittest tests.test_documentation_assets -v` | PASS, 19 tests |
| `python -m unittest tests.test_docshot_destinations -v` | PASS, 5 tests |
| `python -m unittest tests.test_typst_tooling -v` | PASS, 3 tests |
| `mkdocs build --strict` | PASS (existing `/tmp/cams-b02a-docs` environment) |
| `python scripts/build_typst.py --toolchain-dir <repository-pinned-toolchain>` | PASS; report 110 / book 170 physical pages |
| `git diff --check` | PASS |

The pinned Typst 0.14.2 toolchain and fonts were reused without system font fallback. Detailed logs remain in `/tmp/cams-phase33/foundation-*.log`; the assertions above establish normal CI-style clean-checkout behavior independently of pre-existing local CRLF files. The additional temporary-repository regression covers all three `core.autocrlf` settings. B02A work was saved outside the repository and excluded from this foundation commit. No asset transfers, docshot renders or later batches occur in Phase 3.3.

Typst PDF SHA-256 values from the clean foundation checkout:

- report: 110 pages; `627d59abb47e831782a5cd401b5317d85e04169092596951b132df63b3871576`.
- book: 170 pages; `aa4203a6d8ec73764857603c383cb40c80cf9aaa04fbf804b85a14eabc418442`.
