# Documentation assets audit — Phase 1

Ngày audit: 2026-10-04 (Asia/Ho_Chi_Minh). Repository HEAD: `147556f360c97d10f9b2cdd18aaa52db7f923b65`.

Chỉ inventory, classification, provenance và usage map. Không migration, không đổi ảnh/reference/code/framework, không regenerate screenshots. Mọi output mới nằm trong thư mục audit.

## Kết quả

- **356 assets**: 326 raster, 30 SVG.
- Usage: **203 used**, **43 possibly-used**, **110 orphan**, 0 unknown.
- UI: **263**; docshot-confirmed **42** (chapter03: 11, chapter04: 19, VLAN: 9, welcome/workspace/devices: 3); docshot-probable **0**; manual-confirmed **0**, manual-probable **73**, unknown **148**.
- UI actions: keep 42; regenerate-later 127; investigate 21; preserve-as-evidence 73. Không chạy command regeneration nào.
- Evidence: terminal **32**, device/external-tool verification **1**, syslog **6**. **32** candidate có thể tái dựng phần text; ảnh gốc vẫn phải giữ. Khả năng tái dựng text không đồng nghĩa tái lập thực nghiệm.
- Vector canonical proposal **29**, SVG wrapper branding **1**; raster derivative confirmed **0**, topology/vector pairs uncertain **3**, same-name pairs different-content **2**.
- Duplicates: exact **0**; visual candidates **41 pairs**. Đây là candidate hình ảnh, không phải duplicate đã xác nhận.

| asset_class | count |
| --- | ---: |
| ui | 263 |
| terminal-evidence | 32 |
| device-verification | 1 |
| syslog-evidence | 6 |
| network-diagram | 18 |
| architecture-diagram | 8 |
| workflow-diagram | 13 |
| database-diagram | 1 |
| illustration | 0 |
| logo-icon | 2 |
| derivative-raster | 0 |
| misc | 12 |
| unknown | 0 |

## Phương pháp và giới hạn

Scan 1168 source files bằng danh sách Git tracked + untracked không bị ignore, trên toàn repository; tất cả 356 assets dưới 00_book/00_report được hash SHA-256 và đọc metadata. Các thư mục tài liệu được đọc đầy đủ trong bước scan; include/import graph xác định những Typst sources đi từ main.typ. Danh sách source, hash và số dòng nằm trong assets.json. Không scan .git, dependencies/generated/ignored files hoặc output để tránh self-reference.

Markdown inline/reference images, HTML img, Typst image/insert-image, CSS url, quoted code/config image paths và các bare documentation paths đều được kiểm tra. References.csv giữ exact file/line, resolution_status, context và intended_asset cho đường dẫn sai. Python output được đối chiếu thêm registry và renderers vì output filenames được ghép động. Đây là static scan, không thực thi toàn bộ source hay resolver; pattern động và QML resource paths ngoài phạm vi inventory giữ trạng thái unresolved/dynamic, không được diễn giải là lỗi tài liệu. Không dùng OCR.

Tất cả raster được kiểm tra trực quan qua contact sheets; SVG được parse XML và render bằng PyQt6 QtSvg hiện có. Đánh giá legibility/crop là sơ bộ; một số evidence được xem thêm ở độ phân giải gốc/lớn. Preview SVG có thể thiếu embedded icons; hybrid SVG không bị coi là hỏng chỉ vì QtSvg preview. `confidence` là tổng quát; JSON/CSV bổ sung classification_confidence, provenance_confidence và reproducibility_confidence để không gộp sự chắc chắn về nội dung với sự chưa chắc chắn về nguồn tạo.

Provenance docshot-confirmed ở đây có nghĩa filename thuộc generator/workflow và test hiện hành, không phải chứng minh lịch sử từng byte PNG bằng log tạo ảnh. Chapter05–19 không có workflow tương ứng trong CLI, vì vậy không được tự động confirmed/probable. Không tìm thấy bằng chứng đủ mạnh để gán docshot-probable. 73 lab UI có dấu vết capture desktop/live state nên manual-probable, không manual-confirmed.

reproducible-now nghĩa có renderer/CLI workflow hiện hành, **chưa chạy/kiểm chứng thành công tại checkout này**. CLI chapter03/04 không ghi vào current asset directory; test training fixture hiện còn thiếu source. Các command trong coverage chỉ ghi những token tồn tại; --output-dir cho shot cơ bản/VLAN là option thực sự có. Dành cho phase sau, không phải command đã thực thi.

reproducible-with-existing-framework là đề xuất static: QML hiện có và framework có thể capture; vẫn cần khai báo shot/state và test. SFTP/history, logs/counters và live lab states cần fixture/workflow mới. Không suy luận rằng live results có thể được mô phỏng rồi thay evidence gốc.

evidence_original=true là chính sách bảo toàn bản capture đang có, với chain of custody chưa được chứng minh độc lập (basis nằm trong JSON). reconstructable=yes chỉ là có thể trình bày lại nội dung text đang thấy; các log/timestamp/email/live state khác để uncertain.

used chỉ tính reference local resolve đúng và active document graph. possibly-used giữ ảnh có broken intended link hoặc generator output khớp filename nhưng sai destination. orphan là không có reference hợp lệ hoặc intended-use mạnh trong static scan; tree.md listing không được coi là usage. Orphan không có nghĩa disposable. Cả 28 raw LAB1 files hiện orphan, nhưng vẫn là source/evidence cần bảo toàn.

Perceptual candidates dùng dHash 256 bit (distance ≤ 8), aspect ratio sai lệch ≤ 4%, RGB thumbnail MAE ≤ 15. Similar UI layouts có thể khác state dù match: không auto-delete và không gộp với exact. Giới hạn này không bảo đảm phát hiện crop lớn. SHA-256 tính trên tất cả assets, kể cả SVG.

## CURRENT_DIRECTORY_PROBLEMS

| subtree (recursive) | total | composition |
| --- | ---: | --- |
| `00_book/figures/report/diagrams/` | 133 | workflow-diagram: 13, architecture-diagram: 7, network-diagram: 17, database-diagram: 1, ui: 61, terminal-evidence: 27, device-verification: 1, syslog-evidence: 6 |
| `00_book/figures/report/diagrams/routing-ospf-lab/` | 27 | ui: 15, terminal-evidence: 12 |
| `00_book/figures/report/diagrams/switching-lab/` | 33 | ui: 27, terminal-evidence: 6 |
| `00_book/figures/report/diagrams/fhrp-nat-dhcp-lab/` | 17 | ui: 10, terminal-evidence: 5, network-diagram: 2 |
| `00_book/figures/report/diagrams/syslog-lab/` | 21 | ui: 9, terminal-evidence: 4, syslog-evidence: 6, network-diagram: 2 |
| `00_report/Tai_lieu_lab/` | 28 | misc: 12, network-diagram: 1, terminal-evidence: 3, ui: 12 |

- `routing-ospf-lab/10.png` là CAMS Routing Group dialog, không network diagram; `12.png` là multi-router terminal verification.
- `syslog-lab/06-syslog-r1-verify.png` là CLI terminal evidence; `13…16-device-logs.png` class chính syslog-evidence (secondary terminal); `10…12` vẫn là CAMS UI. `18/19-email` là evidence email cảnh báo ngoài CAMS, không CAMS UI.
- Jenkins screenshot là external CI tool evidence: dùng device-verification là bucket gần nhất, confidence medium; secondary external-tool/ci-evidence. Không nhận nhầm là CAMS UI.
- `00_report/Tai_lieu_lab/` có 12 raster pages chứa hướng dẫn/raw source, 16 hình extracted/capture; không có exact duplicates giữa chúng và inventory hiện tại. Không có nguồn DOCX/PDF trong subtree này.
- Naming: 73 opaque, 15 problematic, 254 partially-semantic, 14 semantic. Tên numbered có mô tả vẫn partially-semantic; tên đề xuất dùng lowercase-kebab-case, có phân biệt state/sequence. Đề xuất không phải tên cuối đã duyệt.

## VECTOR / SVG FINDINGS

`canonical_vector` là proposal về source chính hiện tại, không phải quyết định migration. 29 SVG được giữ làm canonical source candidates; một số là hybrid chứa raster icons (lab_4, fhrp-nat-dhcp, syslog-lab-topology). ptit-logo.svg chỉ bọc embedded bitmap nên canonical_vector=false.

`07_ospf_area.svg` là chain R1/R2/R3 trong area0; PNG cùng tên là hình nhiều area/router khác. `08_acl_packet_flow.svg` và JPG cùng tên có flow/layout khác. Không đặt raster_derivative_of cho hai cặp này. LAB_2/LAB_2-report, fhrp-nat-dhcp và syslog topology có topology tương ứng nhưng chưa thấy exporter/source provenance; relationship=uncertain. Không ép chúng vào derivative-raster. Xem vector-raster-relationships.csv.

## DOCSHOT_INFRASTRUCTURE_FINDINGS

| file:line | current behavior | inconsistency | recommended future fix |
| --- | --- | --- | --- |
| `docshots/cli.py:20` | REPOSITORY_ROOT = APP_DIR.parent; DEFAULT_OUTPUT_DIR under parent/docs/research/book/figures/gui | APP_DIR is CAMS root; default resolves outside repository, not documented repo-root | Use explicit canonical/staging destination model in later phase; correct root definition and destination contracts together |
| `docshots/cli.py:81` | chapter-03/04 force APP_DIR/book/figures/gui/<shot>; ignore --output-dir | Current assets live under 00_book; standard command cannot regenerate current asset location | Update both forced destinations and tests after architecture decision; retain independent renderer output support |
| `docs/DOCSHOTS.md:32` | Documented default <repo-root>/docs/research/book/figures/gui | Legacy layout; also disagrees with actual parent-root behavior | Document canonical source vs MkDocs staging and real CLI output after migration |
| `docs/DOCSHOTS.md:68` | VLAN output documented in legacy docs/research/book tree | Current inventory is 00_book/figures/gui/vlan | Update documentation plus default destination contract |
| `tests/test_docshots_chapter03.py:19` | Asserts APP_DIR/book/figures/gui/chapter-03 | Test locks obsolete book destination | Update destination assertions with CLI, preserving isolation/repeatability tests |
| `tests/test_docshots_chapter04.py:16` | Asserts APP_DIR/book/figures/gui/chapter-04 | Test locks obsolete book destination | Update destination assertions with CLI |
| `tests/test_docshots_chapter03.py:59` | Loads book/fixtures/chapter-03/build_fixture.py | Neither book/fixtures nor 00_book/fixtures/chapter-03 exists in checked-out repository | Recover/locate intended training fixture source; investigate before claiming full test reproducibility |
| `tests/test_docshots.py:45` | Default test compares parser output only to DEFAULT_OUTPUT_DIR constant; rendering tests use temporary override | Does not detect wrong repository-root calculation or current asset-tree mismatch | Add future destination contract checks once approved architecture exists |
| `docs/DOCSHOTS.md:99` | Says add-device unregistered and describes future capture work | Standalone add-device token remains unregistered, but chapter04 already renders Add Device/Multiple/Edit windows | Clarify supported workflow vs standalone shot; document chapter03/04/dialogs commands and crop geometry |

Các path này chưa sửa. docs/DOCSHOTS.md còn thiếu chapter03/04/dialogs trong Current shots/Run dù CLI đã support. `all` chỉ bao gồm welcome/workspace/devices, không bao gồm workflows. Tests dùng temporary output xác nhận format/geometry/repeatability, nhưng không chứng minh các PNG inventory hiện tại là byte outputs từ lần chạy đó.

## BASELINE_DOCUMENT_VALIDATION

| target | requested command | status |
| --- | --- | --- |
| MkDocs | `mkdocs build --strict` | **unavailable**: executable không có trên PATH, Python module mkdocs cũng không có |
| Book Typst | `typst compile --root . 00_book/main.typ output/documentation-assets-audit/book-baseline.pdf` | **unavailable**: typst không có trên PATH |
| Report Typst | `typst compile --root . 00_report/main.typ output/documentation-assets-audit/report-baseline.pdf` | **unavailable**: typst không có trên PATH |

Không cài dependency, không tạo baseline PDF, không sửa build. baseline-builds.json ghi command và diagnostic. Kết quả unavailable không chứng minh passed/failed. Static path audit bên dưới là finding độc lập, không được gọi là build failure đã chạy.

## MKDOCS_STAGING_REQUIREMENTS

`mkdocs.yml:10` đặt docs_dir=00_book, site_dir=site. Markdown hiện có **178 image references**, tới **177 distinct UI images theo intended target**; tất cả 178 links này dùng `../../figures/...` và resolve ngoài docs_dir (root figures, không tồn tại). Correct future relative pattern từ DOC là `../figures/...`, như MKDOCS.md đã hướng dẫn; audit không sửa.

Tập cần stage/copy tối thiểu trong tương lai là **178 assets**: 177 ảnh Markdown + 1 logo.svg dùng chung theme logo/favicon (`mkdocs.yml:48–49`). Tổng size hiện tại của tập này: **22,092,185 bytes**. Danh sách từng asset nằm trong mkdocs-staging-requirements.csv. Đây là intended-use staging set, không phải tập đang resolve thành công.

- CSS: `stylesheets/extra.css`; JS: `javascripts/lightbox.js` được khai báo dưới docs_dir. CSS không có local image URL cần stage thêm. JS lightbox lấy target.src runtime, cần image URL resolve đúng; không có fixed binary image path. Theme Material icons là theme resources, không tính thành local inventory assets.
- Markdown dùng relative HTML img src; Typst report dùng `/00_book/...` project-root paths; book helper dùng `image("../" + path)` trong config/images.typ, resolve relative theo file định nghĩa helper, thành 00_book/figures. Không thay những resolver khác nhau bằng một quy tắc giả định.
- `exclude_docs` loại **/*.typ, config/**, cover/**, figures/report/** khỏi website. Book website cần gui + theme icon; không cần stage report diagrams chỉ vì đang cùng docs_dir. Hiện MkDocs có thể copy nhiều assets GUI không được reference; lượng 178 là minimum usage set, không phải tổng file website sẽ copy.
- Các external URL repo/site/fontawesome/material icon names không phải filesystem paths. Workflow docs.yml chỉ trigger 00_book, mkdocs.yml, requirements-docs.txt, .github/workflows; canonical root mới sẽ cần trigger và staging step ở phase sau.
- Canonical assets ngoài docs_dir sẽ cần staging/derivative trong 00_book để website publish được: chọn path stable, content/hash verification và build ordering trước mkdocs; chưa triển khai bất kỳ staging nào.

## Outputs

| file | purpose |
| --- | --- | --- |
| [assets.csv](assets.csv) | Một row/asset, metadata và classification |
| [assets.json](assets.json) | Full inventory, context, used_by/possible_usage, confidence, source manifest/include graph |
| [references.csv](references.csv) | Một row/reference, file/line, literal path, resolution và intended target |
| [duplicates.csv](duplicates.csv) | Exact và visual candidate pairs (không có exact pair trong snapshot) |
| [docshot-coverage.csv](docshot-coverage.csv) | Mọi UI asset, provenance, supported command, action |
| [orphans.csv](orphans.csv) | 110 orphan candidates; không được xóa tự động |
| [migration-proposal.csv](migration-proposal.csv) | Proposal một row/asset; không thực thi |
| [baseline-builds.json](baseline-builds.json) | Availability/diagnostic của baseline commands |
| [docshot-infrastructure-findings.csv](docshot-infrastructure-findings.csv) | Legacy destination và test/documentation inconsistencies |
| [mkdocs-staging-requirements.csv](mkdocs-staging-requirements.csv) | 178 assets cần stage theo intended book web usage |
| [broken-document-references.csv](broken-document-references.csv) | Các broken active-document image links |
| [vector-raster-relationships.csv](vector-raster-relationships.csv) | 5 cặp đã so sánh, different-content hoặc uncertain |
| [integrity-verification.json](integrity-verification.json) | Hash/schema/graph verification |
| [previews/](previews/) | Contact sheets hỗ trợ kiểm tra content; chỉ là audit previews |

## Integrity

Kiểm tra lại SHA-256 toàn bộ assets sau audit và hash toàn bộ source files đã scan: không thay đổi. git diff không có tracked changes; git status chỉ có thư mục output/documentation-assets-audit mới. Không stage/commit. Không sửa 00_book, 00_report, docshots, UI, features hay tests.
