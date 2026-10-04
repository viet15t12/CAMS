# Phase 3 — Infrastructure foundation

Đã hoàn thành hạ tầng trên branch `docs/pictures-sort`, dựa trên planning authority `output/documentation-assets-plan/` tại `ab9a407`. **Asset transfer count = 0**. Cả 407 ảnh nguồn vẫn tồn tại tại path cũ với SHA-256 không đổi. Không regenerate screenshot nguồn, sửa production QML/runtime, thay ảnh report hoặc triển khai terminal renderer.

## Manifest và terminal freeze

- `documentation_assets/manifest.yaml`: 407 record; **345 pending nonterminal**, **62 frozen external**, **0 migrated**. Canonical root chỉ chứa metadata, chưa chứa ảnh.
- Pending record giữ `current_path` thật và `planned_canonical_path` tương lai. Có một record switching UI chưa chốt tên, được đánh dấu unresolved/review thay vì tạo target giả.
- `terminal-freeze.json` khóa ID/path/SHA của 62 terminal assets và multiset reference hiện tại. Reference được phép đổi line number khi nội dung khác thay đổi; literal và số lần dùng phải giữ nguyên.
- Validator kiểm tra ID, canonical target/casefold collision, containment/traversal/symlink, SHA, lifecycle, staging và logical links/cycles. Frozen assets ngoài canonical root hợp lệ, không được transfer/stage/reconstruct.
- `reference-baseline.json` giữ chính xác **178 broken HTML image occurrences đã có trước Phase 3**. Default validation chỉ chấp nhận các ngoại lệ đó; broken reference mới bị reject. Strict reference mode vẫn fail; không mass rewrite tài liệu.

## Staging

Root: `00_book/assets/`. **178 nonterminal records được stage losslessly từ legacy current sources**, không copy toàn bộ 345 ảnh vào canonical root. Đây là derivative cho MkDocs, không phải asset migration. Không terminal nào được stage.

Staging binaries và `.documentation-assets.json` ledger đều generated/gitignored. Manifest, freeze/baseline contracts, scripts, tests và documentation là source được track. Ledger chỉ cho phép cleanup file do sync sở hữu; unknown files, malformed ledger, symlink và stale file đã bị sửa bị reject trước cleanup. Copy kiểm tra SHA nguồn/đích và atomic replace; journal hỗ trợ retry sau interruption.

Sync lần hai giữ nguyên bytes **và mtime của cả 179 generated files** (178 ảnh + ledger). `--check` chạy thành công từ CWD `/tmp`; `--dry-run`/`--check` không ghi file. CI chạy validate → sync → check → MkDocs strict và chỉ publish `site/`.

## Docshot và Typst

Default cũ tính repository root bằng `APP_DIR.parent`, dẫn đến `docs/research/book/figures/gui`; chapter workflows ép output về `APP_DIR/book/figures/gui/chapter-*` và bỏ qua override. Default mới nằm trong checkout tại **`documentation_assets/ui/docshot/`**:

| Shot/workflow | Domain mặc định |
| --- | --- |
| welcome, chapter-03 | core |
| workspace | project |
| devices, chapter-04 | devices |
| vlan | switching/vlan |
| dialogs | core/dialogs |
| all | domain riêng của welcome/workspace/devices |

`--output-dir` là override chính xác cho mọi workflow, kể cả chapter và VLAN. Resolver không tạo directory; default symlink trỏ ra ngoài repo bị reject. Renderer filename chưa đổi, không chạy default render. Integration tests chỉ render vào temporary directories; ảnh nguồn vẫn không đổi.

Book Typst helper giữ nguyên cách resolve relative legacy path và bổ sung project-root `/documentation_assets/...`. Report helper hiện hỗ trợ root paths nên không sửa. Không rewrite book/report contents hoặc Markdown references trong phase này.

## Commands và kết quả

| Command | Kết quả |
| --- | --- |
| `python scripts/validate_documentation_assets.py` | PASS; 407 records, 178 baseline exceptions |
| `python scripts/validate_documentation_assets.py --check-staging` | PASS |
| `python scripts/sync_documentation_assets.py --dry-run` | PASS; deterministic plan, không ghi |
| `python scripts/sync_documentation_assets.py` | PASS; bootstrap 178 derivative copies, repeat sync không thay đổi |
| `python scripts/sync_documentation_assets.py --check` | PASS |
| `python scripts/validate_documentation_assets.py --strict-references` | FAIL như baseline: 178 existing broken occurrences |
| `python -m unittest tests.test_documentation_assets tests.test_docshot_destinations -v` | PASS: 19 tests |
| `uv run python scripts/validate_structure.py` | FAIL: thiếu README ở `features/compliance`, `features/syslog/alerts` |
| `uv run python -m unittest tests.test_docshots -v` | PASS: 9 tests |
| `uv run python -m unittest tests.test_docshots_chapter03 -v` | 2 PASS, 1 FAIL: thiếu `00_book/fixtures/chapter-03/build_fixture.py` |
| `uv run python -m unittest tests.test_docshots_chapter04 -v` | PASS: 3 tests |
| `mkdocs build --strict` | PASS |
| `typst compile --root . 00_book/main.typ ...` | UNAVAILABLE |
| `typst compile --root . 00_report/main.typ ...` | UNAVAILABLE |

Dependencies MkDocs được cài theo `requirements-docs.txt` vào `/tmp/cams-phase3-docs`; application tests dùng environment `/tmp/cams-phase3-app` tạo bằng repository `uv.lock`. Không đổi lock file. Lệnh uv thực tế thêm `--locked --offline --python /usr/bin/python3`; Python hiện có là 3.14.7. XDG config/cache/data và leak-check TMPDIR được đặt trong `/tmp` để không ghi user configuration. Một thử nghiệm chạy suites đồng thời gặp global `/tmp` fixture leak assertions; suite docshots được chạy lại riêng với TMPDIR riêng và pass. Các kết quả cuối nằm trong log đi kèm.

Typst binary không có và repository không provision nó; không cài ad-hoc, không tạo PDF, không ghi PASS. MkDocs strict không kiểm tra hết raw HTML image URLs; 178 broken references vẫn còn và được static validator theo dõi riêng. Không sửa feature READMEs hoặc tạo training builder ngoài scope.

## Files changed

- Metadata: `documentation_assets/README.md`, `manifest.yaml`, `terminal-freeze.json`, `reference-baseline.json`.
- Scripts: `scripts/documentation_assets.py`, `scripts/validate_documentation_assets.py`, `scripts/sync_documentation_assets.py`, `scripts/README.md`.
- CI/dependencies: `.github/workflows/docs.yml`, `.gitignore`, `requirements-docs.txt`.
- Helpers/docshot/docs: `00_book/config/images.typ`, `docshots/cli.py`, `docs/DOCSHOTS.md`, `MKDOCS.md`.
- Tests: `tests/test_documentation_assets.py`, `tests/test_docshot_destinations.py`, `tests/test_docshots.py`, `tests/test_docshots_chapter03.py`, `tests/test_docshots_chapter04.py`.
- Báo cáo thực thi: thư mục này, gồm `validation-results.json`, `changed-files.txt` và command logs.

Không thay đổi Phase 1/2/2.1 planning outputs, `00_report/`, ảnh gốc, terminal sources/renderer, latest feature/UI source hoặc `uv.lock`. Chi tiết git status ở `changed-files.txt`; chưa commit/push.

## Ready for B02

**Hạ tầng: YES. Unconditional asset transfer: NO.** Các prerequisite manifest/staging/helper/CI đã có. B02 có 39 records, 34 records cần review theo planning authority trước khi chuyển. Existing B02 description và maximum-transfer note vẫn ghi 37, trong khi estimated count/input IDs đã là 39; cần hòa giải giới hạn này trước execution, không tự sửa plan trong Phase 3.

Typst validation chưa available; structure/training-package checks có các lỗi prerequisite nêu trên. Không coi chúng là PASS hoặc lỗi do migration. B02 phải review các row bị ảnh hưởng, bảo toàn bytes/caption và cập nhật reference/manifest/staging atomically; terminal freeze tiếp tục giữ nguyên. **Không migration được thực hiện trong Phase 3.**
