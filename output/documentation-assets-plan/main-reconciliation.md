# Main reconciliation — Phase 2.1

## Sync result

Branch docs/pictures-sort was clean at initial HEAD 5fb4bd75e6f3416fc3f4bfaa659b0b3819289eab. Old merge-base/main branch base: 147556f360c97d10f9b2cdd18aaa52db7f923b65.

First fetch/ort merge imported c21c153 as e83f451. During reconciliation origin/main advanced again. Second fetch/merge imported current main **e44ba4e79fb14031b89eeca68446109da3cbfb2e** as **a15e7a42d03ea317f5ad5f1e7d8dbd849146167b**, without merge conflicts or history rewrite. Both audit/planning commits are preserved. Planning edits survived the second merge. Snapshot authority for this output is the last fetched e44ba4e; origin/main is ancestor of branch HEAD.

## Delta scope and current authority

Only old merge-base → fetched current main delta audited: **142 paths** (75 added, 64 modified, 3 removed), **51 added images**, **3 modified images**, **14 new terminal text sources**. Current image inventory overlay is **407** records (356 + 51). main-delta-assets.csv includes supporting source/docs/code changes and explicit upstream deletions; reconciliation did not perform those deletions or document rename.

Initial delta added 15 terminal-generated PNGs, 2 full Gmail screenshots, changed 2 email-card bytes and 1 SVG. Second main advance added 34 images: 11 direct terminal captures, 11 CAMS UI, 2 topology PNGs, 2 authored SVGs and 8 raw pages. Source/UI/production/tests changed upstream and are preserved exactly; no scope expansion into production implementation.

Commit 8c657f3 provides terminal-generated PNGs, text sources and 9 active standardized report figures. Current renderer term2png.py is provenance, not an execution action. Six individual OSPF panels visually match the referenced composite; exact composition/render command is not established and not invented. Text/source bytes kept at current main locations.

## Terminal freeze

**62 frozen terminal images = 47 direct/historical captures + 15 terminal-generated PNGs**. Of the 47 captures, 36 were present in Phase 1 (32 terminal-evidence + 4 Syslog console log screenshots); 11 were newly added by main (DHCP status plus 10 ACL test CLI captures).

Frozen scope includes terminal connectivity tests and JSON/hex inspection, with classification based on substance. Keep historical primary class where useful (4 syslog-evidence records) and add terminal-console tag. CAMS UI, View & Push, log tables, Gmail, Jenkins, topology and whole raw document pages remain nonterminal scope.

Invariants: migration_role=frozen; migration_action=classify-only; canonical_migration=false; proposed path and filename equal current values; batch_id empty; reconstruction_candidate=false; every terminal future_reference=old_reference and action=no-action-frozen. **No terminal move/rename/crop/replace/regenerate/reconstruct/reference rewrite in any future phase.** Orphans are orphan-but-frozen, never garbage/archive/delete candidates.

62 images, 14 text sources, renderer and current report references preserve main bytes. Nine report references into /00_book/figures/report/terminal-generated remain exact; new LAB5/R2 terminal references are frozen as well. No hypothetical terminal reconstruction remains in sample/schema or execution candidates. Historical Phase 1 reconstructability survives only as audit history.

## Nonterminal delta and invalidated assumptions

Current email card 18-email-critical.png is actually **Error severity 3 SW1**; 19-email-warning.png is Warning severity 4 R1. Current report uses full Gmail lv3/lv4 at lines 739/746. Corrected semantic card IDs, paths and current hashes replace stale Critical/capture assumptions, with previous_asset_id trace. Four files remain independent; likely-crop relationship requires review, no auto-merge.

Project-structure SVG now says terminal nhúng; same logical domain/ID, new SHA. review-core-erd.svg is a database relationship diagram; review-syslog-sequence.svg is a workflow/sequence diagram. New DHCP and LAB5 UI captures are manual-screenshot-probable, preserve originals and allow only conditional future UI recreation. Raw source pages retain page context/headings, even when printed CLI examples occupy much of the page.

Seven exact SHA pairs appear in main delta: one terminal pair frozen/no-action, six nonterminal pairs require shared canonical-source/alias identity review across B13/B15. Exact means equal bytes; provenance/copy direction is not inferred. Keep both current files. canonical_group_id is a review group, not move/delete/deduplication authorization. Distinct physical source records remain until one logical canonical presentation identity is approved. Two email likely-crop candidates supplement 41 historical visual candidates.

Changed-source references were refreshed only for delta documents; unchanged references inherited from Phase 1. Newly added standalone 09_kich_ban_5_acl.typ duplicates evidence but is not included by report main, so references marked resolved-inactive. Modified old-source references/line numbers no longer drive execution. Upstream rename of old conclusion source to .typ.bak has no current active asset reference nodes.

## Updated batches

18 batches retained; **345 physical nonterminal records** assigned to transfer scope once, **344 concrete paths + one UI hold**. Six exact nonterminal pairs still need canonical identity review, so unique final canonical content count is not yet asserted.

| batch | Phase 2 count | Phase 2.1 nonterminal count |
| --- | ---: | ---: |
| B02 | 37 | 39 |
| B11 | 33 | 27 |
| B12 | 27 | 15 |
| B13 | 17 | 18 |
| B14 | 21 | 15 |
| B15 | 28 | 40 |
| B16 | 3 | 1 |

B13 adds DHCP snooping UI/topology; B15 includes LAB1/LAB5 nonterminal UI/topology/raw pages; B16 Jenkins only. B01 classification registry must permit external frozen paths. B17 nonterminal orphan/copy review excludes terminal actions. No terminal assets counted as transfer. Atomically update each nonterminal asset + all references + manifest + staging + validation; frozen literal/bytes comparison is a gate in every batch.

## Readiness and blockers

**Ready for Phase 3 infrastructure: YES.** Current fetched main is fully contained and terminal freeze contract is consistent. No current committed conflict markers remain in chapters08/09. The first c21c153 snapshot contained them; latest e44ba4e removed them upstream, with no repair by this task.

Remaining execution gates: one switching UI name/state hold, raw LAB1/LAB5 page headings/order, six exact nonterminal copy groups requiring shared canonical identity review, uncertain vector pairs and UI provenance/recreation equivalence. These gate affected transfers, not infrastructure setup. Confirm build-tool availability and establish current build diagnostics during Phase 3; reconciliation runs no MkDocs/Typst build and does not claim build PASS.

## Verification and change boundary

validation-results.json checks ancestry, current main delta bytes/deletions, audit-history integrity, all 407 current image hashes, all 62 frozen image bytes, exact report references, forbidden terminal actions, nonterminal batch accounting, schema/sample, staging and relative web paths. No canonical/staging directories created. After the two authorized main merges, working-tree changes are only output/documentation-assets-plan/*. Phase 1 outputs unchanged; original Phase 2 history retained in 5fb4bd7.
