# Scripts

Cập nhật: **2026-08-16**.

- `build_databases.py`: build atomically DB runtime từ schema chuẩn; chạy lại sẽ thay DB đích nên cần backup dữ liệu cần giữ.
- `validate_structure.py`: kiểm tra README bắt buộc, README/status feature,
  `qmldir`, runtime artifact, path tuyệt đối và ranh giới core/session; chỉ đọc
  repository.

## Documentation asset migration foundation

`validate_documentation_assets.py` validates transitional current/planned metadata, source hashes, frozen terminals and static document image references. `sync_documentation_assets.py` creates/checks owned lossless MkDocs staging; use `--dry-run` or `--check` for read-only modes. Shared implementation is in `documentation_assets.py`; contracts and commands are in `documentation_assets/README.md`. No script moves or renders source assets.

- `provision_typst.py`: provision Linux x86_64 Typst 0.14.2 and fonts from official checksum-pinned releases (`typst-toolchain.lock.json`).
- `build_typst.py`: validate report/book using that toolchain, repository root and isolated fonts; outputs PDF/log/results only in generated output. See `docs/TYPST.md`.
