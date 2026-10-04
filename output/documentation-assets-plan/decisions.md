# Decision log — Phase 2.1

Phase 2 commit `5fb4bd7` retains historical policy; this log and main-reconciliation.md supersede it.

- D001: One shared canonical store for migrated documentation assets, with explicit terminal external exception.
- D002: Canonical root remains documentation_assets/, outside book/report.
- D003: MkDocs uses generated staging 00_book/assets/, suffix-preserving; recommend generated+gitignored+CI sync.
- D004: Prefer true SVG sources; preserve different-content/uncertain pairs independently.
- D005: Original experimental evidence preserved; nonterminal lab UI goes evidence/ui-capture/original.
- D006: UI docshot recreation may become presentation-preferred after equivalence review, never original experimental evidence.
- D007 (SUPERSEDED): Terminal reconstruction proposal withdrawn. Historical reconstructability metadata does not authorize any action.
- D008: Semantic kebab-case names apply to transferable nonterminal files only. Terminal filenames stay exactly as current main/historical files.
- D009: No deletion of originals/orphans/visual candidates.
- D010: Each nonterminal transfer batch updates asset + all its references + manifest + stage + validation atomically. Frozen references excluded and kept literal.
- D011: Generated+gitignored+CI sync remains recommended; no implementation in Phase 2.1.
- D012: Bootstrap planned canonical manifest only for nonterminal scope; external frozen entries keep existing paths and canonical=false.
- D013: UI recreation preference conditional on reviewed equivalence; no terminal recreation.
- D014: Naming confidence separate from provenance confidence; main bytes override stale Phase 1 hashes.
- D015 (NEW AUTHORITY): Current-main terminal images/text/reference state is frozen. migration_role=frozen, migration_action=classify-only, canonical_migration=false, future_action=no-action. No render/reconstruct/crop/move/rename/replace/taxonomy reference rewrite in any later phase.
- D016: Terminal classification uses visual substance, including four Syslog console-log screenshots previously classified syslog-evidence. Email/Gmail/Jenkins/CAMS UI/topology are not frozen by this rule.
- D017: Current main email bytes/usage replace previous Critical assumptions: Error SW1 and Warning R1, full Gmail captures versus cropped cards remain separate.

## Remaining reviews

- Switching 1_6.png: nonterminal UI state distinction unresolved; keep proposed path empty until review. Former terminal naming hold 1_31.png is frozen, no rename review needed.
- Twenty LAB1/LAB5 page headings/source order; three uncertain SVG/raster pairs; legacy UI/lab capture provenance and future UI recreation equivalence.
- Earlier c21c153 report conflict markers were removed by latest main e44ba4e; no current marker blocker, and no document repair performed here.
- Old Phase 1 hashes/references remain audit history. Current overlay and main-delta-assets.csv are the active execution baseline.

- D018: Delta exact duplicates remain physical source records until reviewed. One frozen terminal pair has no action; six nonterminal pairs require shared logical canonical record/alias decision before B13/B15 transfers. No auto-delete/merge or duplicate presentation sources after that review.
- D019: Whole photographed LAB5 pages with embedded command examples remain raw source material. Extracted/direct CLI screenshots are terminal frozen; CAMS View & Push dialogs and log tables are UI, not frozen by CLI-looking text.
- D020: Readiness applies to Phase 3 infrastructure setup, not automatic transfer of unresolved/copy-review records. Snapshot e44ba4e resolves old marker blocker upstream.
