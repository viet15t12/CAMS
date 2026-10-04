# Documentation assets migration plan — Phase 2

Thiết kế migration cho branch `docs/pictures-sort`, Phase 1 commit `39be1884020c4034aff9a39bd0d54fb2d6d9b7be`. Ngày: 2026-10-04 (Asia/Ho_Chi_Minh). **Chỉ tạo plan; chưa có canonical root, staging, manifest thật, sync script hoặc migration nào.**

## Goals và terminology

Chuyển việc thực thi các phase sau thành những batch nhỏ có path/ID/naming/reference rõ, bảo toàn evidence, giữ book Typst/MkDocs và report Typst nhất quán. Phase 1 là lịch sử audit không sửa; Phase 2 là overlay, không copy máy móc suggested names/buckets.

- Canonical store: nơi quản lý source bytes và logical records, không đồng nghĩa mọi file là best presentation.
- Original evidence: capture thực nghiệm đang có; probable/unknown historical provenance giữ nguyên, không tự nâng thành confirmed.
- Recreation: screenshot mới bằng fixture/QML để trình bày một state tương đương; original_evidence=false.
- Reconstruction: trình bày lại text từ original terminal, là derivative; không phải replay thực nghiệm.
- Staging: byte-verified generated copy cho MkDocs, không nguồn biên tập và không logical asset mới.
- Proposed path: tên đích cần duyệt trước phase thực thi; confidence chỉ là đề xuất naming/domain, không bằng chứng lịch sử.

## Inventory overlay

**356 rows**, **354 concrete path proposals**, **2 filename/path holds**. Confidence: high 219, medium 122, low 15; review-required **164**. Tất cả logical IDs hiện unique; IDs provisional chỉ chốt sau semantic review và sau đó không đổi theo filesystem.

| category (including unresolved intended categories) | assets |
| --- | ---: |
| ui | 190 |
| evidence | 124 |
| diagrams | 40 |
| illustrations | 0 |
| branding | 2 |
| misc | 0 |

UI: 42 confirmed docshot + 148 legacy documentation + 73 lab original. Lab originals vào evidence, không ui/legacy. 72 concrete recreation candidates; một UI capture hold chưa có recreation path. Terminal captures 32 (4 connectivity ở evidence/connectivity), syslog device-log captures 4, external tools 3 (Jenkins + 2 email), raw pages 12. 32 terminal text reconstruction candidates; không tạo file mới từ chúng.

## Taxonomy

Giữ tầng category đã quyết định: ui/docshot, ui/legacy; evidence/ui-capture/original, terminal/original|reconstructed, device-verification/original, syslog/original, connectivity/original, external-tools/original, source-material; diagrams/architecture|workflow|network|database|lab-topology; illustrations; branding/logos|icons; misc.

Leaf additions: routing/static cho static/default routes; evidence/ui-capture/original/lab1 cho extracted lab captures; evidence/terminal/original/project-format cho JSON/hex inspection; external-tools/original/ci cho Jenkins; lab-topology per scenario. Legacy domains có thể thêm cùng leaf structure với docshot để giữ mapping rõ. Những category chưa có current assets không được tạo folder chỉ để lấp taxonomy. proposed-tree.txt được generate từ asset-path-map.csv; không bao gồm hypothetical recreation hoặc future manifest metadata trong asset count.

## Canonical vs MkDocs staging

Canonical root **documentation_assets/**. Staging root **00_book/assets/**. Staged suffix = canonical path bỏ documentation_assets/; logo/favicon paths trong mkdocs.yml tính tương đối với docs_dir.

```text
documentation_assets/ui/docshot/routing/ospf/networks.png
 -> 00_book/assets/ui/docshot/routing/ospf/networks.png
documentation_assets/branding/logos/cams.svg
 -> 00_book/assets/branding/logos/cams.svg
```

**178** staged current assets: 177 intended Markdown UI + CAMS logo/favicon (một file cho hai config references). Dữ liệu lấy từ Phase 1 staging set vì hiện 178 HTML image references đều broken; valid-used-only sẽ bỏ mất intended web images. 674 Phase 1 reference rows đều có disposition trong rewrite plan; 435 rows nhận logical asset mapping, những row ngoài inventory/dynamic giữ nguyên với explicit retain/investigate action.

Selection future: targets contains book-mkdocs OR mkdocs_stage=true. Future validator bắt buộc targets book-mkdocs => stage=true; stage true explicit opt-in hợp lệ cho theme logo dù used_by là config. Không stage report-only/orphan assets nếu không có intended book web usage. CSS stylesheets/extra.css và JS javascripts/lightbox.js tiếp tục là book sources; không bị đưa vào image canonical taxonomy.

Khuyến nghị **A: generated + gitignored + CI sync**. Ưu điểm: không commit 178 binary duplicates, hash đảm bảo freshness, stale cleanup có ranh giới rõ. Đổi lại: preview local phải sync trước serve/build; CI phải chạy sync sau checkout và trước MkDocs. B generated+tracked giảm bước local nhưng tăng binary/history/conflicts/staleness; chỉ cân nhắc khi hosting không cho pre-build step. Hiện không thấy blocker cho A. Phase 2 không chỉnh .gitignore/workflow.

## Deterministic sync contract (future only)

Future script scripts/sync_documentation_assets.py, chưa được tạo:

1. Resolve repository root từ script, không phụ thuộc CWD; read manifest/version, validate toàn bộ IDs/path suffix/selection trước khi ghi.
2. Reject duplicate IDs, case-insensitive canonical/staged collisions, absolute OS paths, .. traversal và symlink escape; reject canonical source bất kỳ trong staging root.
3. Chỉ chọn active/current existing records được opt-in; planned/hypothetical/unresolved-null-hash records không được stage. Verify source SHA-256 trước mọi copy; thiếu source/hash mismatch -> nonzero, không prune.
4. Derive stage suffix giữ nguyên taxonomy. Copy bytes losslessly vào temporary file dưới generated root, verify destination hash, atomic replace. Không convert/resize/compress tại sync.
5. Ownership marker/ledger trong 00_book/assets ghi manifest version/selected IDs/hashes; ledger phải có trước stale removal. Có unknown hand-written file hoặc unexpected symlink -> fail, không xóa.
6. Loại stale generated files chỉ từ ledger dưới đúng 00_book/assets; không chạm 00_book/figures, canonical, document/CSS/JS. Initial sync không có ledger tuyệt đối không prune arbitrary files.
7. Deterministic output/listing/order; repeat run không đổi bytes; dry-run/check mode báo missing/stale/hash mismatch. Transaction/staging recovery không để partial hash mismatch được coi là passed.

## Evidence provenance và presentation preference

73 lab UI originals đều preserve_original=true, original_evidence=true theo audit capture policy, historical confidence vẫn probable. final original path evidence/ui-capture/original/<lab>. Docshot recreation ở ui/docshot/lab-recreation/<lab>, ID riêng và recreates_evidence_asset=<original ID>. Original preferred_for_presentation=false là future preference policy: khi chưa có recreation được review, documents tiếp tục dùng original. Không tự rewrite vào hypothetical target.

Terminal originals giữ pixels/commands/data. Reconstructed record derived_from trỏ original; reconstruction_method và reconstruction_confidence bắt buộc. Text transcript phải faithful, flag uncertain glyph; không bịa timestamp/command output. Connectivity terminal cũng giữ semantic domain, reconstruction có thể đặt terminal/reconstructed/<lab> với cross-ID link.

4 router/switch log screenshots là syslog-capture; 2 email screenshots là external-tool-capture và chuyển bucket external-tools/original/syslog-lab trong overlay. Jenkins là external-tools/original/ci. Asset_class Phase 1 giữ để trace audit; source_kind/category mới sửa taxonomy interpretation, không sửa history.

SVG true source ưu tiên canonical; generated-svg chỉ dùng khi có generator evidence. Existing vector records proposed authored-svg với provenance_confidence low nếu author/exporter không rõ. 2 same-name different-content pairs có semantic names khác; 3 uncertain pairs raster/vector có state/media-qualified names, keep-both. Không đặt derived_from khi chưa chứng minh nguồn/export. ptit-logo.svg giữ branding wrapper, không khai là pure canonical vector.

## Naming và ID stability

Names lowercase-kebab-case, bỏ chapter/old sequence prefix; directories giữ domain, filename chỉ subject/state/device/data cần phân biệt. Thí dụ routing/ospf/networks.png; evidence/.../routing-ospf-lab/r2-ospf-routing-verification.png. Số trong R2/VLAN/port là semantic data; không dùng old filename number để tạo ID/tên. Hai View & Push VLAN thật sự dùng Guest/Users -> logical IDs/names phân biệt state, không theo legacy/docshot folder.

354 names/path proposals không collision (kể cả casefold). Không thêm -1/-2 để giải collision. Hai hold rows switching 1_31.png/1_6.png có subject gần trùng nhưng chưa xác minh khác biệt: path/filename rỗng, migration_role=unresolved; có intended category và provisional logical ID, không dùng làm executable move map. naming-review.csv ghi low-confidence/raw/ambiguous/orphan review. Raw page names chỉ candidate theo broad content; cần xác nhận heading/source sequence trước move.

Logical ID biểu thị meaning, không chapter/old number/filesystem root/provenance-folder. Khi path hoặc presentation generator thay đổi mà meaning giữ nguyên, ID không đổi. Original và recreation là hai records/IDs khác nhau. New evidence session/data khác phải tạo record meaning/state qualifier mới; không reuse ID original như ảnh mới. Không có superseded/archive-candidate chỉ vì similarity.

## Manifest contract

manifest-schema.yaml là **JSON Schema Draft 2020-12 serialized as YAML**, dùng cho future documentation_assets/manifest.yaml, không phải manifest thật. Example gồm 8 records: confirmed UI, legacy UI, original lab UI, hypothetical recreation, original terminal, hypothetical reconstruction, SVG và branding. planned=true trên path proposals; hai hypothetical records sha256=null/status=unresolved/no invented command/targets empty.

canonical=true nghĩa record authority cho source bytes; original evidence cũng có thể canonical=true mà preferred=false. staged copies không phải record canonical riêng. source_kind và status enums có đủ các giá trị yêu cầu. used_by giữ file/line/target/resolution; targets union nhiều documents, không duplicate canonical source. Provenance confidence tách naming confidence.

Schema kiểm tra shape/enums/conditional metadata; future semantic validator kiểm tra IDs unique, references derived_from/recreates tồn tại, graph acyclic, counterpart original=true cho recreation, reconstructed original=false, media/extension match, path containment, path uniqueness, stage suffix equality và SHA content. Không thể chứng minh filesystem/hash/equivalence bằng schema đơn thuần.

Bootstrap Phase 3: dùng legacy_path để verify source hiện tại và planned path; không đòi tất cả canonical paths tồn tại trước batch đầu. Batch commit asset transfer -> path canonical tồn tại/hash đúng, planned=false; used_by rewritten/staging map updated. Hold rows không được chuyển sang executable entries khi path chưa resolve. Current/planned state tách rõ, không fake PASS.

## Reference rewriting contract

Book/report Typst: /documentation_assets/... với --root .; tuyệt đối không report -> staged copy. Book HTML/Markdown: relative path từ actual parent tới 00_book/assets. Từ 00_book/DOC là ../assets/...; từ root index.md sẽ là assets/... nếu có reference. Config logo/favicon: assets/branding/logos/cams.svg, docs_dir-relative.

Reference plan gồm mọi 674 row từ Phase 1, giữ row ID. Chỉ apply mapped active nodes hoặc reviewed example/generator node; không search-replace strings mù. 178 broken web references đã có precise future relative paths. Ngoài inventory/dynamic references action retain-out-of-scope không phải migration failure. Duplicate filename registry/generator references cần rename output-map + tests, không sửa renderer logic ở Phase 2.

Book helper hiện image("../" + path) không nhận canonical absolute path đúng. Phase 3 cần transitional pass-through nếu path bắt đầu /; legacy relative branch giữ đúng hiện hành để batch chưa migrate không bị gãy. Phase cuối chỉ bỏ legacy branch khi scanner chứng minh không còn caller dùng old form. Preserve captions, alt, width, link target semantics. Source hash/old_literal/line context phải match trước applying plan; nếu document drift, re-resolve node và review, không áp old line number mù.

## Docshot destination transition (future only)

42 supported shot filenames có current workflow code/tests; destination legacy chưa sửa. Phase 3 chọn canonical output-root và workflow output-map; Phase 5 transfer current bytes + semantic leaf names. Navigation/devices/VLAN/generic mapped theo domain, không giữ chapter folders làm taxonomy. Default canonical root và explicit --output-dir override phải đồng nhất, preserve temp tests; override không ép người dùng ghi vào source store.

docshot-transition.csv target_generator_family planned/... chỉ là design family, không CLI command tồn tại. Không bịa token chapter05–19/lab. For canonical regeneration update generator_command trong manifest chỉ sau infrastructure support/rename map được thực hiện và tested. Current commands trong audit vẫn đi legacy destination; đây là evidence về support, không lệnh đã chạy hoặc future-ready.

Training fixture chapter03 book/fixtures/... không tồn tại, default REPOSITORY_ROOT=APP_DIR.parent sai tree, tests chapter03/04 lock book path. Phase 3 giải quyết CLI/docs/tests destination contracts và locate fixture source trước reproducibility claim. Rendering runtime logic thay đổi không thuộc Phase 2; migration later không được suy luận screenshot hash equals latest render.

## Future build and CI wiring

Những commands sau chỉ là **future contracts**, scripts chưa tồn tại trong checkout:

```sh
python scripts/sync_documentation_assets.py
mkdocs build --strict
typst compile --root . 00_book/main.typ output/documentation-validation/book.pdf
typst compile --root . 00_report/main.typ output/documentation-validation/report.pdf
```

Future docs.yml: add documentation_assets/**, scripts/sync_documentation_assets.py và manifest/staging validator paths vào push trigger; checkout canonical sources; install existing docs dependencies; validate manifest, sync, verify hashes rồi mkdocs build --strict; upload site như hiện tại. Không publish canonical store riêng chỉ để lách docs_dir. Local mkdocs serve cũng phải sync/check trước, documented wrapper chỉ được thêm ở infrastructure phase. Future book/report Typst validation job phải có executable/fonts; report-only canonical paths không dựa vào website output.

## Migration ordering và atomic batch contract

**18 batches**, 15 transfer batches, asset count 3–42 mỗi batch; tổng assign 356 exactly once. B01 infrastructure không transfer, B17 review-only, B18 final validation.

| batch | phase | scope | assets | risk |
| --- | --- | --- | ---: | --- |
| B01 | Phase 3 | Infrastructure foundation | 0 | high |
| B02 | Phase 4 | Branding and diagrams | 37 | medium |
| B03 | Phase 5 | Confirmed docshot UI | 42 | medium |
| B04 | Phase 6 | Legacy project/core UI | 10 | medium |
| B05 | Phase 6 | Legacy interface and routing UI | 33 | medium |
| B06 | Phase 6 | Legacy DHCP ACL FHRP NAT UI | 39 | medium |
| B07 | Phase 6 | Legacy switching UI | 35 | medium |
| B08 | Phase 6 | Legacy switching security UI | 6 | medium |
| B09 | Phase 6 | Legacy transfer and snapshots UI | 12 | high |
| B10 | Phase 6 | Legacy Syslog and System Logs UI | 13 | high |
| B11 | Phase 7 | Switching lab original evidence | 33 | high |
| B12 | Phase 7 | Routing OSPF lab original evidence | 27 | high |
| B13 | Phase 7 | FHRP NAT DHCP lab original evidence | 17 | high |
| B14 | Phase 7 | Syslog lab original evidence | 21 | high |
| B15 | Phase 8 | LAB1 source material | 28 | high |
| B16 | Phase 8 | External tools and format evidence | 3 | medium |
| B17 | Phase 9 | Duplicate orphan archive review | 0 | high |
| B18 | Phase 10 | Final validation and cleanup review | 0 | high |

B01 → B02 → B03 → B04–B10 domain documentation → B11–B14 lab evidence → B15 raw LAB1 → B16 external/format → B17 duplicate/orphan review → B18 validation. High risk: infrastructure, transfer/log fixture assumptions, all lab/raw evidence, duplicate/orphan and final cleanup. B17 xử lý 110 orphan records bằng 5 review subpasses tối đa 25; 41 pair review bằng 2 subpasses. estimated_asset_count=0 cho review batch không che giấu số record review (có review_record_count).

Mỗi transfer batch phải: verify source hash -> transfer preserving bytes -> update mọi reference (book/report/code/config/mentions đã review) -> update manifest state/IDs/provenance -> update staging selection -> sync/check -> static/build validation -> review diff. Không commit intermediate move-only state. Nếu bất kỳ check mới fail, sửa trong batch hoặc rollback riêng batch; không postpone link fixes. Không regenerate evidence trong transfer batch. Review-required là prerequisite của từng affected row; split batch thành subtransactions ≤25 khi review phức tạp, giữ all-reference atomicity per asset.

Hai unresolved filename rows thuộc B11: chưa thể coi B11 complete trước review; có thể migrate các row còn lại thành atomic subtransactions rồi hold hai row. Nếu muốn giữ nguyên 18 batch completion accounting, B11 chỉ đóng khi cả hai đã có tên được duyệt.

## Validation per future batch

- Static: canonical and current manifest paths exist as appropriate planned/current state; unique IDs and casefold paths; no path traversal/symlink escape; all document references resolve; no new unapproved broken local path.
- Bytes: source hash equals audited baseline before move; destination SHA equals source; staged hashes equal canonical, no extra opt-out stage files. Captures source files giữ nguyên nội dung.
- Semantics: review visual state/name, caption/alt preservation, original vs recreation/reconstruction graph, preferred records uniqueness per presentation subject; no silent replacement with changed data.
- MkDocs: sync/check + mkdocs build --strict; both Typst compile --root .; docshot destination and isolation/repeatability tests when generator/output mapping changes. Baseline tools unavailable phải ghi unavailable, không PASS.
- Baseline exceptions: Phase 1 có 178 pre-existing broken Markdown references và builds unavailable. Phase 3 establish precise exception ledger; per batch không tăng hoặc che lỗi. Remove exception từng migrated node; final B18 requires zero broken references and actual successful builds in capable environment. Intermediate baseline failures phải báo failed-existing/unavailable, không gọi PASS hay postpone newly introduced issues.
- Build checks per batch có thể lộ baseline không liên quan; report exact diagnostic và distinguish original regression bằng hash/context baseline. Không sửa lỗi ngoài asset scope để ép build green.

## Risks và unresolved review

164 review-required rows; 15 low confidence gồm 12 raw pages, lab_4 purpose và 2 visually near-identical capture holds. Classification/path proposals không cho phép tự thực thi. Ba topology pairs uncertain và hai different-content pairs không merge; original preservation có ưu tiên hơn naming perfection. 41 duplicate candidates có review class/state rationale; không auto-delete, không perceptual==exact. 110 orphans giữ source/evidence và review disposition riêng.

Cần human/source review cho headings raw pages, pair state/capture lineage, ambiguous captions, SVG export equivalence, fixture availability, lab recreation equivalence và eventual archive choice. Kiến trúc canonical/staging đã chốt, không xin lại quyết định root. Không ép precise filename cho hai hold rows. Xem decisions.md U001–U008.

## Outputs và verification

- [asset-path-map.csv](asset-path-map.csv): 356 asset rows, 354 proposed paths + 2 holds.
- [reference-rewrite-plan.csv](reference-rewrite-plan.csv): 674 reference rows với action/phase và future reference.
- [naming-review.csv](naming-review.csv): candidate names cần review.
- [duplicate-review-plan.csv](duplicate-review-plan.csv): 41 pair dispositions, keep-both.
- [vector-plan.csv](vector-plan.csv): 30 SVG records và 5 related raster comparisons.
- [docshot-transition.csv](docshot-transition.csv): 263 UI transitions, no invented commands.
- [migration-batches.csv](migration-batches.csv): 18 atomic future batches.
- [manifest-schema.yaml](manifest-schema.yaml): JSON Schema as YAML.
- [manifest-example.yaml](manifest-example.yaml): 8 design examples, 2 hypothetical.
- [proposed-tree.txt](proposed-tree.txt): tree generated from map.
- [decisions.md](decisions.md): D001–D014, U001–U008.
- [orphan-review-plan.csv](orphan-review-plan.csv): 110 preservation/review dispositions.
- [mkdocs-staging-plan.csv](mkdocs-staging-plan.csv): 178 current intended web assets.
- [plan-summary.json](plan-summary.json): counts and Phase 1 input hashes.
- [validation-results.json](validation-results.json): schema/sample, map/reference/tree and repository integrity checks.

Phase 2 validation kiểm tra design consistency và integrity; không chạy future migration/build/regeneration. No canonical/staging directory created. Final git status/diff chỉ có output/documentation-assets-plan; toàn bộ Phase 1 inputs và tracked files giữ SHA-256 như trước.
