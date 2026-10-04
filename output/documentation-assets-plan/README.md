# Documentation assets plan — Phase 2.1

**Reconciled with current main; terminal freeze supersedes Phase 2 execution proposals. No Phase 3 migration performed.**

Current main `e44ba4e79fb14031b89eeca68446109da3cbfb2e` merged into docs/pictures-sort as `a15e7a42d03ea317f5ad5f1e7d8dbd849146167b`. Phase 1 audit unchanged. Historical Phase 2 plan remains in commit `5fb4bd7`; current CSV/YAML files are the active overlay.

## Goals, taxonomy and scope

Canonical documentation_assets/ and generated MkDocs staging 00_book/assets/ remain future contracts. Terminology: canonical is record authority, not a claim of best presentation; original evidence, UI recreation and staged copy have separate provenance. Logical IDs stay semantic and path-independent.

**Explicit exception: all terminal images remain at current paths**, including terminal-generated and historical lab/connectivity/console-log captures. They are classified, never absorbed into canonical migration. Freeze extends to text sources and renderer actions. No terminal reconstruction, cropping, replacement, rename, move, regeneration or taxonomy reference rewrite is permitted in any later phase.

407 current image records = 62 frozen terminals + 345 nonterminal migration records (344 path proposals + one UI naming hold).

| canonical category | transferable assets |
| --- | ---: |
| ui | 190 |
| evidence | 109 |
| diagrams | 44 |
| branding | 2 |

Counts include the unresolved nonterminal UI in intended evidence category. Terminal frozen registry is external to these counts. Four Syslog console log images are included in the 47 historical terminals despite their retained primary asset_class=syslog-evidence. 15 current terminal-generated images were added by main; 14 text sources support them, the OSPF composite has six related sources. Exact historical render/composition invocation is not asserted or executed.

## Evidence and UI policy

84 original lab UI captures remain transferable to evidence/ui-capture/original/<lab>. 83 hypothetical UI recreation candidates remain ui/docshot/lab-recreation/<lab> with recreates_evidence_asset linking originals, original_evidence=false; equivalence/data/provenance review is required before presentation preference changes. 42 confirmed docshots and 148 legacy documentation UI remain in scope. UI framework future destinations remain canonical; stage is not a renderer destination.

47 historical terminal captures and 15 main-rendered images have migration_role=frozen, migration_action=classify-only, canonical_migration=false; proposed_canonical_path and filename equal current values, batch_id empty, reconstruction_candidate=false. No rename proposals remain in naming-review.csv. Main-rendered images are not relabeled original experimental captures; source confidence remains distinct from render provenance.

Email/Jenkins/external-tool evidence remains transferable. Main changed both email-card bytes and introduced lv3/lv4 full Gmail captures; cropped Error SW1 and Warning R1 cards have separate semantic IDs/paths from full Gmail screenshots. Current report uses lv3/lv4, not the old cropped-card paths. No merge/delete inferred from likely crop relationship.

Raw LAB1 pages/UI/topology remain in scope; its three terminal captures are frozen. True vectors stay preferred; same-name different-content/uncertain SVG-raster pairs kept independent. Project-structure SVG has new wording/current SHA, same semantic ID/path.

## Naming, IDs and manifest

Nonterminal names lowercase-kebab-case without chapter/sequence prefix; device/state/data qualifiers distinguish meaning. One unresolved switching UI capture keeps empty proposed path rather than invented sequence. Logical ID stability is unaffected by future path changes. Frozen filenames preserve even opaque historic numbering.

manifest-schema.yaml is JSON Schema serialized as YAML, not a real canonical manifest. It now supports external frozen paths with canonical=false, planned=false, current SHA and no generator command. Terminal source kinds force canonical_migration=false. reconstruction_method/confidence must be null; reconstructed-terminal is no longer allowed. Seven examples retain UI recreation but remove the hypothetical terminal reconstruction. Original captures retain evidence provenance; new UI recreations do not rewrite original record identities.

Bootstrap manifest current legacy_path + planned destination applies only to nonterminal records; unresolved path record cannot become executable transfer entry. Frozen classification may live in external section/registry without moving binaries. Future validator must enforce cross-ID links/acyclic graph, path uniqueness/containment, source hashes, source-kind/freeze policy and stage suffix.

## Canonical vs staging and references

Stage only targets containing book-mkdocs or explicit mkdocs_stage=true. 178 selected existing web assets remain unchanged; staged suffix equals canonical suffix. Recommend A generated+gitignored+CI sync over B generated+tracked to avoid duplicate binaries/staleness; local preview needs sync first. No .gitignore/CI edits now.

Future sync validates manifest/IDs/containment/hashes before writes, copies bytes atomically, verifies staged SHA, and removes stale files only from an ownership ledger inside 00_book/assets/. Unknown files/symlink escape cause failure. Frozen terminal sources are excluded. No convert/resize/re-render in sync.

Book/report Typst transferable references use /documentation_assets/... with --root .; book helper must transition to absolute pass-through while old callers still work. Markdown paths calculated relative to actual source parent, usually ../assets/... from 00_book/DOC; mkdocs.yml logo/favicon assets/... relative to docs_dir. **Terminal Typst references retain exact existing /00_book/figures/report/terminal-generated/... or historical literals.** They are not broken canonical exceptions.

Changed main documents were rescanned only for current image literals/line numbers; unchanged source reference graph inherited from audit. reference-rewrite-plan.csv marks frozen rows no-action-frozen and keeps future_reference=old_reference. Stale references from modified sources removed, not moved to new assets by guessing captions. Phase 1 broken web-reference ledger remains historical baseline.

## Future infrastructure/build and atomic ordering

18 batches remain, 345 physical nonterminal records assigned once; 344 concrete paths plus one UI hold. Before affected transfers, 6 nonterminal exact-copy pairs need shared logical canonical identity review. These counts are conservative physical source handling, not a final count of unique canonical content. Order: B01 foundation → B02 branding/vector → B03 confirmed docshot → B04–B10 legacy UI domains → B11–B14 nonterminal lab UI/topology/email (B13 also DHCP snooping) → B15 LAB1/LAB5 nonterminal sources → B16 Jenkins only → B17 nonterminal orphan/duplicate review → B18 validation.

Each transfer batch must preserve bytes, update every nonterminal reference + manifest state + staging selection, validate, then finish coherently. Frozen terminals do not count as transfer, and terminal refs must compare equal before/after every batch. B11's former terminal name hold is removed; one nonterminal UI hold remains. No move-only intermediate commits. Failures introduced by a batch must be fixed/rolled back within that batch.

Future commands (not run/implemented here):

```sh
python scripts/sync_documentation_assets.py
mkdocs build --strict
typst compile --root . 00_book/main.typ output/documentation-validation/book.pdf
typst compile --root . 00_report/main.typ output/documentation-validation/report.pdf
```

Future docs.yml triggers canonical sources/sync/schema, runs validation+sync before MkDocs, uploads site as today. Typst paths use --root ., frozen external allowlist; docshot destination registry/tests keep temp-output isolation. No terminal renderer workflow added. Existing docshot fixture/default-root discrepancies remain foundation work.

Per-batch static checks: unique IDs/paths, valid current/planned paths, no new broken refs, SHA preservation, stage suffix/hash, provenance original/recreation links, no terminal execution actions. Build tools unavailable => unavailable, never PASS. Carry exact Phase 1 broken-web baseline exceptions and reduce per migrated reference; final validation needs actual builds and zero broken refs. Earlier c21c153 markers were removed by latest main e44ba4e; reconciliation performs no document repair and does not claim build success.

## Risks and unresolved work

High risk: foundation, transfer/log UI workflows, lab evidence/source reviews and final validation. Main changed former Critical email content to Error, replaced report terminal references, changed SVG bytes/terminology, added DHCP/ACL evidence, and removed its earlier committed conflict markers. Old Phase 2 validation report is superseded by validation-results.json for reconciliation.

Remaining semantic review: one switching UI hold, twenty raw page headings/order (12 LAB1 + 8 LAB5), three uncertain vector pairs, legacy capture provenance/UI recreation equivalence and orphan dispositions. Orphan terminals remain orphan-but-frozen; no archive/delete. Phase 3 infrastructure readiness is **YES** from reconciliation: current main is contained, freeze contract validated, no current marker blocker. Tool/build availability and per-batch naming/provenance reviews remain implementation prerequisites; no automatic asset transfer is authorized by readiness.

## Active outputs

- [main-reconciliation.md](main-reconciliation.md): main sync, delta, policy precedence, blockers.
- [main-delta-assets.csv](main-delta-assets.csv): all 142 changed main paths, 54 image deltas/current hashes and supporting text/docs.
- [terminal-freeze.csv](terminal-freeze.csv): all 62 current/historical frozen images and current reference metadata.
- [asset-path-map.csv](asset-path-map.csv): all 407 images, explicit canonical_migration/migration_action.
- [reference-rewrite-plan.csv](reference-rewrite-plan.csv): current reference overlay and no-action frozen literals.
- [migration-batches.csv](migration-batches.csv), [proposed-tree.txt](proposed-tree.txt), [plan-summary.json](plan-summary.json): updated nonterminal transfer accounting.
- [naming-review.csv](naming-review.csv), [duplicate-review-plan.csv](duplicate-review-plan.csv), [orphan-review-plan.csv](orphan-review-plan.csv), [vector-plan.csv](vector-plan.csv), [docshot-transition.csv](docshot-transition.csv): current review policies; frozen terminal actions disabled.
- [manifest-schema.yaml](manifest-schema.yaml), [manifest-example.yaml](manifest-example.yaml), [decisions.md](decisions.md): revised architecture contract.
- [mkdocs-staging-plan.csv](mkdocs-staging-plan.csv): unchanged 178 stage selections.
- [validation-results.json](validation-results.json): actual reconciliation integrity/plan checks, not build/migration PASS.

## Additional main delta inspected during reconciliation

origin/main advanced from c21c153 to e44ba4e while the task was running. A second fetch/merge preserved that delta; the report now contains ACL lab evidence and main removed its old conflict markers. This plan is pinned to the fetched e44ba4e snapshot.

34 additional images in that advance: 11 terminal captures, 11 CAMS lab UI captures, 2 topology PNGs, 2 authored SVGs, 8 photographed source pages. New terminal captures are frozen; source pages with embedded command excerpts are classified as whole raw documents, not extracted terminal captures. All 62 frozen images remain byte-identical to main. Lab UI total is now 84; documentation UI remains 42 confirmed + 148 legacy, so all UI assets total 274. Potential lab UI recreation paths total 83.

New leaf domains: dhcp-snooping-lab, lab5, lab1 UI recreation. Existing report chapter09 now uses LAB5 terminal/UI/topology; the standalone 09_kich_ban_5_acl.typ fragment repeats evidence but is not included by main.typ, so its reference edges are resolved-inactive. New database/workflow SVGs added to B02; B13 adds DHCP snooping UI/topology; B15 expands to LAB1/LAB5 raw/UI/topology.

Seven exact SHA-256 pairs found by comparing delta hashes to known inventory: one terminal pair frozen/no-action, six nonterminal pairs require shared canonical-source/alias review across B13/B15. Preserve both current copies; no automatic merge, move or deletion. canonical_group_id identifies review group, not an executable deduplication operation. Unique physical record IDs preserve source provenance; shared logical canonical identity must be finalized before either affected transfer. Two new email likely-crop pairs join the 41 historical visual candidates; total pair ledger has 43 visual + 7 exact records.

Main also changes production/QML/tests and upstream deletes/renames document/helper files. Those changes arrived only via merge and match current main; no task implementation edits outside planning artifacts. Upstream production changes may affect UI recreation fixtures, so the planned workflow families remain proposals rather than reproducibility claims.

## Phase 3.1 — B02 execution preflight

Current B02 scope/cap is **39**, split into **B02A = 5** exact high-confidence/no-review assets and **34 remaining review-required records**. Parent B02 stays the assignment in the asset path map; execution sub-batches are recorded once in `b02-preflight.csv` and `plan-summary.json.b02_execution_preflight`. No asset meaning, SHA, planned path or review approval changed. The historical Phase 2 count 37 remains only in preserved history.

B02B1–B02B4: 20 standalone authored-format SVG review candidates (5 each); B02C: 4 independent OSPF/ACL raster/vector records; B02D: 2 LAB_2 topology records; B02E1–B02E2: 6 legacy raster diagrams (3 each); B02F: 2 unresolved hybrid-branding/topology records. Every one of these 34 remains gated by explicit review. No batch is executed in Phase 3.1.

Docshot strategy B is enforced: default canonical writes are blocked until B03 has a manifest-backed semantic filename/domain map. `docshot-output-preflight.csv` audits 42 planned records plus 4 currently unmapped dialog outputs. Temporary output overrides remain available. Infrastructure now uses pre-sync manifest/source/frozen validation → sync → post-sync full references/staging validation → MkDocs strict. Execution evidence: `output/documentation-assets-foundation/phase3-1.md`.
