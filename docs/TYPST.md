# Reproducible Typst validation

Both `00_report/main.typ` and `00_book/main.typ` are supported validation targets. Their current sources compile with **Typst 0.14.2**, pinned in `scripts/typst-toolchain.lock.json`. No previous compiler version was specified by this repository. This is a validation baseline before image migration; no assets or references are changed by building.

## Provision and build

The repository installer supports Linux x86_64 (including x86_64 WSL/Linux containers). It uses Python's standard library, downloads fixed official releases, checks archive SHA-256 before extracting reviewed members, and verifies installed compiler version/file hashes. It needs HTTPS access to GitHub on first provisioning. No root installation or Python Typst package is required.

From the repository root:

```sh
python scripts/provision_typst.py
python scripts/build_typst.py
python scripts/build_typst.py --target report
python scripts/build_typst.py --target book
```

Default toolchain: `output/typst/toolchain/`. PDFs, logs, package cache and `results.json` are under `output/typst/`, which is gitignored. Do not commit compiler, fonts, caches or generated PDFs. Invoke scripts by their absolute path from a different CWD; both determine the repository root from their own location.

For CI or isolated local runs:

```sh
python scripts/provision_typst.py --destination /tmp/cams-typst-toolchain
python scripts/build_typst.py --toolchain-dir /tmp/cams-typst-toolchain --output-dir /tmp/cams-typst-validation
```

The installer supports `--archive-dir` for a reusable checksum-verified download cache. An archive digest mismatch fails before extraction/execution. After a lock update, provision into a clean toolchain directory; unmanaged fonts are rejected rather than silently affecting rendering.

## Exact compiler contract

Equivalent direct commands, from the repository root after default provisioning:

```sh
output/typst/toolchain/bin/typst compile --root . \
  --font-path output/typst/toolchain/fonts --ignore-system-fonts \
  --creation-timestamp 0 --package-cache-path output/typst/package-cache \
  00_report/main.typ output/typst/report.pdf

output/typst/toolchain/bin/typst compile --root . \
  --font-path output/typst/toolchain/fonts --ignore-system-fonts \
  --creation-timestamp 0 --package-cache-path output/typst/package-cache \
  --input 'book-body-font=Liberation Serif' \
  00_book/main.typ output/typst/book.pdf
```

The wrapper prints the absolute command, checks toolchain integrity before execution, preserves diagnostics, and returns failure for compile errors or missing/unsupported font warnings. Creation timestamp 0 fixes validation PDF metadata; this is not a publication-date policy. Book and report outputs are checked independently; neither result is inferred from the other.

`--root .` means the repository root, not `00_report` or `00_book`. Typst absolute `/...` image paths resolve from that root; imported/included relative paths resolve from their source file. Book's helper preserves legacy relative paths and accepts project-root paths. Report uses its existing helper. No reference rewrite or MkDocs staging is required for current Typst compilation.

## Fonts and packages

The locked toolchain provides Liberation Serif **2.1.5** (regular/italic/bold/bold italic) and static Cascadia Code **2407.24** (regular/italic/light/light italic/bold/bold italic). Report body/cover use Liberation Serif; raw/code use Cascadia Code. Report's DejaVu Sans Mono table text uses the font embedded in the pinned Typst compiler. System font discovery is disabled, so CI/local font installations cannot silently change this baseline. Variable Cascadia fonts are deliberately excluded because Typst warns they are unsupported.

Book originally requests Times New Roman. A single config input `book-body-font` keeps that original default for existing users; the reproducible build explicitly selects the pinned free Liberation Serif. No proprietary Times New Roman binary is installed or committed. This is an explicit validation typography profile, not a claim that output is identical to a licensed Times New Roman layout. All document text, figures and captions remain unchanged.

Font provenance: [Liberation 2.1.5 official release](https://github.com/liberationfonts/liberation-fonts/releases/tag/2.1.5), [Cascadia 2407.24 official release](https://github.com/microsoft/cascadia-code/releases/tag/v2407.24), [Cascadia SIL Open Font License](https://github.com/microsoft/cascadia-code/blob/v2407.24/LICENSE). Liberation's license and Typst license/notice are extracted from their verified archives; Cascadia's upstream license URL is recorded in the lock. No font binaries are tracked.

Current source imports are repository-local; there are no `@preview`/`@local` external package dependencies. Report reads the tracked `00_report/bibliography/networktools_references.bib` using Typst's built-in IEEE bibliography style. Fonts and image/include files are the remaining inputs. If future sources introduce versioned Typst packages, normal CI package resolution may need network access; the wrapper places downloaded packages in the generated output cache. Adding dependencies must be reviewed with their explicit versions.

## CI

`.github/workflows/docs.yml` has a separate `typst` job on `ubuntu-24.04`, provisioning the lock and compiling report/book into `$RUNNER_TEMP`. Validation PDFs/logs/results are uploaded as an artifact retained for seven days. Pages deployment requires both the MkDocs and Typst jobs to pass; only `site/` is published. Triggers include report, book, toolchain scripts/lock and workflow changes. Fonts are provisioned from the same checked archives as local builds, with no apt/system-font dependency.

Baseline results and exact executed commands are recorded in `output/documentation-assets-foundation/phase3-2.md`. Terminal freeze and manifest lifecycle remain independent required checks. B02A is not executed by these tooling commands.
