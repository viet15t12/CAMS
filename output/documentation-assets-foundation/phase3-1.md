# Phase 3.1 — Infrastructure hardening + B02 preflight

Hoàn tất trên `docs/pictures-sort`, baseline `9dfb15d50b9707b8beb22b071e9d117214845bdf`. **Không thực hiện B02A hoặc migration nào.** Manifest vẫn là 345 pending, 62 frozen, 0 migrated; canonical store chưa chứa ảnh. Phase 1 history và các kết quả Phase 3 được giữ nguyên; báo cáo này cập nhật trạng thái hiện tại.

## CI fix và regression

Order cũ: full validation → sync → staging check → MkDocs. Full validation kiểm tra physical existence nên reference staged hợp lệ có thể fail trên fresh checkout.

Order mới:

```sh
python scripts/validate_documentation_assets.py --manifest-only
python scripts/sync_documentation_assets.py
python scripts/validate_documentation_assets.py --check-staging
mkdocs build --strict
```

Pre-sync kiểm tra manifest, current files/SHA, ID/path/state/link/staging metadata và immutable terminal reference contract. Không yêu cầu staged files tồn tại. Post-sync kiểm tra đầy đủ manifest, document references và staging ownership/freshness/SHA. Không tắt reference validation trong CI. `--manifest-only` không được kết hợp với `--check-staging` hoặc `--strict-references`.

Regression `test_fresh_checkout_pre_sync_then_full_post_sync` sử dụng repository tạm: pending source tồn tại ở legacy path, Markdown đã dùng `../assets/ui/core/example.png`, staging chưa tồn tại. Pre-sync PASS; full validation trước sync FAIL; sync tạo staged bytes; full post-sync PASS; xóa staged fixture rồi full post-sync FAIL. Test bổ sung chứng minh pre-sync vẫn reject terminal reference contract bị thay đổi.

## B02: 39 = 5 + 34

Sửa stale description/cap 37 trong current `migration-batches.csv` thành 39. Historical Phase 2 count 37 chỉ còn trong history đã được đánh dấu; không sửa Phase 1 history. Parent B02 vẫn là assignment trong asset path map; execution split là metadata riêng, không đếm thêm vào 345 assets hoặc thực hiện transfer.

B02A gồm đúng 5 record high-confidence và `review_required=false` do yêu cầu xác định:

| Asset ID | Current source | Planned canonical target |
| --- | --- | --- |
| branding.logos.cams | 00_book/figures/icons/logo.svg | documentation_assets/branding/logos/cams.svg |
| diagrams.architecture.application-source-tree | 00_book/figures/report/appendix/project-structure.svg | documentation_assets/diagrams/architecture/application-source-tree.svg |
| diagrams.workflow.configuration-state-flow | 00_book/figures/report/diagrams/02_state_flow.svg | documentation_assets/diagrams/workflow/configuration-state-flow.svg |
| diagrams.architecture.cams-layered-system | 00_book/figures/report/diagrams/22_architecture_overview.svg | documentation_assets/diagrams/architecture/cams-layered-system.svg |
| diagrams.lab-topology.switching.layer-two-security | 00_book/figures/report/diagrams/LAB_KICH_BAN_1.svg | documentation_assets/diagrams/lab-topology/switching/layer-two-security.svg |

34 record còn lại giữ `review_required=true`, chưa được approve:

| Future sub-batch | Review category | Count | Review gate |
| --- | --- | ---: | --- |
| B02B1–B02B4 | safe-authored-svg | 20 (5 mỗi batch) | SVG standalone format được parse; cần explicit review caption, semantic target và tất cả usage. Không xác nhận tác giả/exporter chỉ từ format. |
| B02C | raster-vector-pair-review | 4 | OSPF và ACL có khác nội dung theo vector audit; giữ độc lập, không suy luận derivative theo tên. |
| B02D | lab-topology-review | 2 | LAB_2 raster/vector chưa chứng minh equivalence; xác minh topology/scenario/usage, giữ độc lập. |
| B02E1–B02E2 | legacy-raster-diagram | 6 (3 mỗi batch) | Etherchannel, STP, VTP, DHCP snooping, DHCP DORA, VLAN: giữ bytes; review caption/role, không vectorize/re-render hay xóa orphan. |
| B02F | unresolved | 2 | PTIT hybrid SVG embeds raster: review compatibility/provenance; lab_4: semantic scenario/name còn provisional. |

`output/documentation-assets-plan/b02-preflight.csv` chứa mỗi record đúng một lần, kèm current/planned path, SHA, confidence, pairing policy và review gate. `plan-summary.json.b02_execution_preflight` ghi aggregate/sub-batch counts. Regression test đối chiếu đủ 39 IDs với parent B02, đúng 5 safe IDs, current/planned paths/SHA khớp manifest và tất cả vẫn pending. Không thay asset meaning, planned target hoặc approval.

## Docshot — strategy B được enforce

Canonical root/domain trong resolver chưa phải output contract hoàn chỉnh. Ví dụ:

| Workflow | Current reserved output | Planned manifest target |
| --- | --- | --- |
| chapter-03 | ui/docshot/core/01-workspace-overview.png | ui/docshot/core/workspace-overview.png |
| chapter-04 | ui/docshot/devices/01-devices-inventory.png | ui/docshot/devices/inventory-waiting.png |
| vlan | ui/docshot/switching/vlan/01-select-switch.png | ui/docshot/switching/vlan/switch-selected.png |
| workspace | ui/docshot/project/workspace.png | ui/docshot/core/workspace-empty.png |

Các path trên nằm dưới `documentation_assets/`. Chapter-03 sidebar/tabs cũng cần domain devices thay vì core. Runtime tạo `09-status-details.png`, dù registry tuple chapter-03 không liệt kê filename đó; audit đã kiểm tra source và ghi nhận output thật. Không gọi renderer để thu thập audit.

**Strategy B:** CLI reject mọi request thiếu `--output-dir` trước Qt/runtime initialization. Reserved resolver paths được giữ; temporary override vẫn hoạt động chính xác cho mọi shot/workflow. Không regenerate hoặc ghi PNG vào canonical store. Test destination kiểm tra guard cho mọi CLI token và exact override/isolation qua mocked renderer.

`output/documentation-assets-plan/docshot-output-preflight.csv` ghi 42 existing planned records với workflow/source evidence và filename/domain mismatch; thêm 4 dialog regression outputs hiện không có manifest record. Đây là audit, không thêm hypothetical asset vào manifest.

**B03 release gate:** xây explicit shot/output → logical ID → full semantic path map; xác minh coverage với manifest và source workflow (kể cả status-details); quyết định manifest identities cho dialogs hoặc giữ temporary-only; reject unknown output/ID/collision trước write; thêm tests output set khớp manifest. Chỉ gỡ guard sau khi contract này hoàn chỉnh. Không strip numeric prefix để suy luận tên hoặc tự tạo unmanaged canonical outputs. B03 migration chưa bắt đầu.

## Validation và integrity

| Command | Result |
| --- | --- |
| `python scripts/validate_documentation_assets.py --manifest-only` | PASS |
| `python scripts/sync_documentation_assets.py` | PASS; 178 selected, existing staging không thay đổi |
| `python scripts/validate_documentation_assets.py --check-staging` | PASS; 178 broken HTML baseline exceptions giữ nguyên |
| `python -m unittest tests.test_documentation_assets -v` | PASS: 17 tests |
| `python -m unittest tests.test_docshot_destinations -v` | PASS: 5 tests |
| `mkdocs build --strict` | PASS; dùng executable trong `/tmp/cams-phase3-docs` theo `requirements-docs.txt` |
| Book Typst | UNAVAILABLE: binary chưa có, repository không provision |
| Report Typst | UNAVAILABLE: binary chưa có, repository không provision |

Đối chiếu baseline trước/sau: **407 source images và 178 staging images giữ nguyên path/SHA**, không có ảnh canonical mới; 62 terminal images, terminal text sources và terminal reference multiset giữ nguyên. Manifest, terminal-freeze contract và reference-baseline contract giống byte-for-byte với HEAD. Không sửa report/image documents, terminal renderer, production UI/features hoặc runtime/chapter renderers. **0 ảnh moved/renamed/deleted/regenerated**; tests dùng temporary fixture bytes/mocked rendering, không chạy render screenshot.

Machine-readable evidence: `phase3-1-results.json`; logs: `phase3-1-assets.log`, `phase3-1-destinations.log`, `phase3-1-mkdocs.log`. Các lỗi prerequisite khác trong Phase 3 vẫn là baseline; không ghi đè lịch sử hoặc coi Typst unavailable là PASS.

Files changed: validators/frozen-reference helper, docs CI, docshot CLI guard, regression/destination tests, `MKDOCS.md`, `docs/DOCSHOTS.md`, canonical README, B02 planning metadata/CSV và báo cáo Phase 3.1. Không commit/push. **B02A được chuẩn bị, chưa được execute.**
