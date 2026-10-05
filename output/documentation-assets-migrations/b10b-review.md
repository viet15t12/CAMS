# B10B — aggregate System Logs migration-safety review

**7 APPROVE_MIGRATION / 0 HOLD_MIGRATION**, all decided before any B10B move. Original PNGs visually inspected alongside full current book chapter 13 Markdown/Typst and both report uses. All names describe the actual application UI subject. No current caption/paragraph treats the PNG as original experiment/measurement evidence. In particular, Raw message describes a detail-dialog field; the report says critical filtering shows query capability and cannot establish attack detection.

Log rows, addresses, timestamps and message strings are illustrative UI state in this documentation context. Example-like values alone do not prove synthetic origin or docshot provenance. **Provenance stays unknown/low; future regeneration remains investigate-first**, needs_new_workflow=true. This approves only byte-preserving migration to ui/legacy; no future recreation approval or new workflow. No OCR, listener, packets, network/device actions or regeneration.

| Asset ID | Visible subject | UI/evidence judgment | Decision |
|---|---|---|---|
| ui.system-logs.overview | System Logs full page: active listener, filters and table illustrating all eight severity levels. | Book teaches reading the log table; report describes viewer/filter capabilities. No claim makes this screenshot an original experiment result. | APPROVE_MIGRATION |
| ui.system-logs.listener-status | Listener status strip: active, 0.0.0.0:5514/UDP+TCP, 8 received, Stop Listener. | Book explains listener-state controls and counters. The screenshot illustrates status UI, not a throughput measurement. | APPROVE_MIGRATION |
| ui.system-logs.filter-bar | Filter bar: Smart Filter, hosts, severity, protocol, UTC range, latest-per-host limit and export/reset. | Book describes quick filtering conditions and exporting current filtered rows. | APPROVE_MIGRATION |
| ui.system-logs.severity-levels | Syslog severity dropdown with levels 0 Emergency through 7 Debug. | Book explains selection of exact severity levels and distinguishes this from router trap severity. | APPROVE_MIGRATION |
| ui.system-logs.critical-filter-result | Filtered log table with four selected severities and Error/Critical/Alert/Emergency rows. | Book illustrates filtering severity 0-3; report explicitly says it illustrates query capability and cannot establish attack detection. | APPROVE_MIGRATION |
| ui.system-logs.smart-filter-builder | Build Smart Filter application dialog: message/device, facility/mnemonic, severity/transport and generated expression. | Book describes composing filter conditions and reading the generated expression; no raw-evidence claim. | APPROVE_MIGRATION |
| ui.system-logs.message-details | System Log Message application dialog: source, received/device timestamps, protocol, facility, severity/mnemonic and raw-message field. | Book describes opening a row to inspect parsed fields and Raw message. Calling the field raw does not assert this PNG is original lab evidence; its documented role is UI illustration. | APPROVE_MIGRATION |

Companion JSON retains exact pre-migration document/line context, old/planned paths and unchanged provenance/future policy for each of the seven records. All existing captions, widths and prose preserved.
