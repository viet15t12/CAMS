# Phase 3.2 — Typst build foundation

Baseline branch `docs/pictures-sort`, starting HEAD `f297286b2a89dcff9958b4f415be3bc5762647bf`. **Report PASS, book PASS; ready for B02A: YES. B02A chưa execute. Image transfer count = 0.**

## Contract được thiết lập

Repository trước phase này không pin compiler, không provision Typst và không có external Typst package imports. `00_report/README.md` đã yêu cầu repository root nhưng output cũ là `00_report/main.pdf`; workflow chỉ build MkDocs. Cả report và book có `main.typ` cùng local config/contents, nên cả hai được kiểm tra như supported targets, không đánh dấu book NOT-SUPPORTED để né build.

Chọn phương án B: **documented installer với version/checksum pinned**, dùng cùng script cho CI và local. Pin [Typst 0.14.2 official release](https://github.com/typst/typst/releases/tag/v0.14.2) trong `scripts/typst-toolchain.lock.json`. Linux x86_64 musl archive SHA-256:

```text
a6044cbad2a954deb921167e257e120ac0a16b20339ec01121194ff9d394996d
```

Digest đã được đối chiếu với `sha256` của official GitHub release asset và bytes tải về. Installer dùng Python standard library, kiểm tra SHA trước extraction, chỉ đọc reviewed regular-file members, ghi installed ledger và xác minh compiler version/file hashes. Không cài Python Typst package, không dùng `latest`, không đưa compiler/font binaries vào Git. Local provisioning dùng verified cache chứa chính official archives; CI tải cùng URLs/checksums trên fresh runner.

## Fonts và dependencies

| Input | Provision |
| --- | --- |
| Liberation Serif | Official Liberation 2.1.5 archive; SHA `7191c669bf38899f73a2094ed00f7b800553364f90e2637010a69c0e268f25d0`; 4 static styles |
| Cascadia Code | Official Microsoft 2407.24 ZIP; SHA `e67a68ee3386db63f48b9054bd196ea752bc6a4ebb4df35adce6733da50c8474`; 6 static styles |
| DejaVu Sans Mono | Embedded in pinned Typst compiler, used by report tables |
| Body/math fallback fonts | Embedded compiler fonts, independent of system font installation |
| Bibliography | Tracked `00_report/bibliography/networktools_references.bib`, built-in IEEE style |
| Typst packages | No external `@preview`/`@local` dependencies in current source |

System font discovery bị tắt bằng `--ignore-system-fonts`. Source/license links và reviewed members nằm trong lock và `docs/TYPST.md`; không commit font binary. Future versioned package imports có thể dùng normal network resolution với generated package cache, nhưng baseline hiện tại không cần package download.

Lần compile thăm dò dùng variable Cascadia fonts báo unsupported-font warnings. Toolchain cuối chọn **static TTF từ cùng pinned archive**, compile không còn diagnostic. Wrapper không gọi missing/unsupported font fallback là PASS.

Book đang có Times New Roman. Thay đổi config nhỏ, duy nhất trong `.typ`, là thêm `book-body-font` input với **default giữ Times New Roman**. Reproducible validation truyền `book-body-font=Liberation Serif`, không cần proprietary font và không thay text/image/caption. Đây là profile typography rõ ràng cho CI; không khẳng định layout giống bản dùng licensed Times New Roman. Report config/contents không sửa.

## Commands thực tế và baseline

Provision:

```sh
python scripts/provision_typst.py \
  --destination /tmp/cams-phase32-static-toolchain \
  --archive-dir /tmp/cams-phase32-archives
```

Build wrapper:

```sh
python scripts/build_typst.py \
  --toolchain-dir /tmp/cams-phase32-static-toolchain \
  --output-dir /tmp/cams-phase32-static-baseline
```

Hai compiler commands chạy với CWD repository root (wrapper in absolute equivalents, recorded in `phase3-2-results.json`):

```sh
/tmp/cams-phase32-static-toolchain/bin/typst compile --root . \
  --font-path /tmp/cams-phase32-static-toolchain/fonts --ignore-system-fonts \
  --creation-timestamp 0 --package-cache-path /tmp/cams-phase32-static-baseline/package-cache \
  00_report/main.typ /tmp/cams-phase32-static-baseline/report.pdf

/tmp/cams-phase32-static-toolchain/bin/typst compile --root . \
  --font-path /tmp/cams-phase32-static-toolchain/fonts --ignore-system-fonts \
  --creation-timestamp 0 --package-cache-path /tmp/cams-phase32-static-baseline/package-cache \
  --input 'book-body-font=Liberation Serif' \
  00_book/main.typ /tmp/cams-phase32-static-baseline/book.pdf
```

| Target | Result | Physical pages | Diagnostics |
| --- | --- | ---: | --- |
| 00_report/main.typ | **PASS** | 110 | None |
| 00_book/main.typ | **PASS** | 170 | None |

Build lần hai ghi vào `/tmp/cams-phase32-repeat`; PDF SHA giống hoàn toàn với lần đầu:

```text
report: 627d59abb47e831782a5cd401b5317d85e04169092596951b132df63b3871576
book:   aa4203a6d8ec73764857603c383cb40c80cf9aaa04fbf804b85a14eabc418442
```

Metadata creation timestamp 0 dùng riêng cho validation reproducibility; không đặt publication-date policy. PDF chỉ nằm trong `/tmp`, không commit. Default local toolchain/PDF/cache directory `output/typst/` cũng được gitignore.

Root semantics giữ nguyên: `--root .` là root repository, `/...` là project-root path; relative imports/includes vẫn theo file chứa reference. Report không dùng MkDocs staging. Không rewrite image reference để compile pass.

## CI và local documentation

`.github/workflows/docs.yml` thêm job `typst` trên `ubuntu-24.04`: setup Python 3.12 → provision locked compiler/fonts trong `$RUNNER_TEMP` → toolchain tests → compile report/book. Upload validation PDFs/logs/results như temporary artifact, retention 7 ngày, kể cả diagnostic khi fail. Pages deploy phụ thuộc cả `build` và `typst`; chỉ `site/` được publish. Triggers bổ sung `00_report/**`, installer/builder/lock. Newly defined remote job chưa được dispatch trong task này; PASS ở trên là local execution của cùng repository-supported contract.

Developer commands, font profile, exact root semantics và platform support được ghi trong `docs/TYPST.md`, liên kết từ root/report README và scripts README. Linux x86_64/WSL/container là supported provisioning platform; không giả định arbitrary native OS được installer hỗ trợ.

## Existing checks và freeze

| Command | Result |
| --- | --- |
| `python scripts/validate_documentation_assets.py --manifest-only` | PASS |
| `python scripts/sync_documentation_assets.py` | PASS; staging không thay đổi |
| `python scripts/validate_documentation_assets.py --check-staging` | PASS; 178 existing HTML baseline exceptions vẫn giữ nguyên |
| `python -m unittest tests.test_documentation_assets -v` | PASS: 17 |
| `python -m unittest tests.test_docshot_destinations -v` | PASS: 5 |
| `python -m unittest tests.test_typst_tooling -v` | PASS: 3 |
| `mkdocs build --strict` | PASS, dùng `/tmp/cams-phase3-docs/bin/mkdocs` theo requirements-docs.txt |
| `git diff --check` | PASS |

Toolchain tests kiểm tra corrupt cached archive bị reject trước download/execution, installed font bị sửa hoặc inject bị reject và compiler version sai bị reject. Logs đi kèm dùng prefix `phase3-2-`; machine-readable full results/exact commands nằm trong `phase3-2-results.json`.

SHA/path check trước/sau xác nhận **407 source images + 178 staged images giữ nguyên**. **62 frozen terminal images và reference multiset không đổi**; terminal sources/renderer không sửa. Manifest, freeze và reference-baseline contracts giữ nguyên byte-for-byte; migration states vẫn 345 pending / 62 frozen / 0 migrated. Không move/rename/delete/regenerate image hoặc docshot. Không thay production code.

## Ready for B02A

**YES — không còn Typst/build blocker cho 5 safe records.** Current report và book đều compile được trước migration; repository có pinned CI/local contract. B02A vẫn là future task, chưa transfer ảnh nào. 34 remaining review-required records và B03 semantic-output gate không được thay đổi hoặc tự approve trong phase này. Các baseline errors khác ghi ở Phase 3 không bị che thành PASS; chúng không được sửa ngoài scope.
