"""Shared filesystem, manifest and reference contracts for documentation assets."""
from __future__ import annotations

import collections
import hashlib
import json
import re
from pathlib import Path, PurePosixPath
from urllib.parse import unquote, urlsplit

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST = "documentation_assets/manifest.yaml"
STAGE_ROOT = "00_book/assets"
LEDGER = ".documentation-assets.json"
TERMINAL_KINDS = {"terminal-capture", "syslog-capture", "generated-terminal"}
TARGETS = {"book-typst", "book-mkdocs", "report-typst", "lab-source", "code", "config", "other"}
IMAGE_SUFFIX = r"(?:png|jpe?g|webp|gif|svg)"


class AssetError(ValueError):
    """A contract failure; callers must fail before any copy or cleanup."""


def repository_path(root: Path, value: str) -> Path:
    if (not isinstance(value, str) or not value or "\\" in value or "\x00" in value
            or ":" in value or value.startswith("/")
            or any(p in {".", "..", ""} for p in value.split("/"))):
        raise AssetError(f"unsafe repository path: {value!r}")
    path = root / value
    if not path.resolve().is_relative_to(root.resolve()):
        raise AssetError(f"path escapes repository: {value}")
    for part in (path, *path.parents):
        if part == root:
            break
        if part.is_symlink():
            raise AssetError(f"symlink in asset path: {value}")
    return path


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def load_manifest(root: Path = REPO_ROOT) -> dict:
    data = yaml.safe_load(repository_path(root, MANIFEST).read_text(encoding="utf-8"))
    if not isinstance(data, dict) or data.get("manifest_version") != 1 or not isinstance(data.get("assets"), list):
        raise AssetError("manifest_version=1 and assets list required")
    return data


def validate_manifest(data: dict, root: Path = REPO_ROOT) -> list[str]:
    errors: list[str] = []
    assets = data.get("assets", [])
    if data.get("manifest_version") != 1 or not isinstance(assets, list):
        return ["invalid manifest version/assets"]
    ids: dict[str, dict] = {}
    paths: dict[str, str] = {}
    stages: set[str] = set()
    for a in assets:
        label = a.get("id", "<missing-id>") if isinstance(a, dict) else "<invalid-record>"
        try:
            if not isinstance(a, dict) or not re.fullmatch(r"[a-z][a-z0-9-]*(\.[a-z][a-z0-9-]*)+", label):
                raise AssetError("invalid semantic asset ID")
            if label in ids:
                raise AssetError("duplicate asset ID")
            ids[label] = a
            state = a.get("migration_state")
            if state not in {"pending", "migrated", "frozen"}:
                raise AssetError("invalid migration_state")
            for key in ("canonical_migration", "canonical", "mkdocs_stage", "original_evidence", "preserve_original", "review_required"):
                if type(a.get(key)) is not bool:
                    raise AssetError(f"{key} must be boolean")
            current = a.get("current_path")
            source = repository_path(root, current)
            if current.startswith(STAGE_ROOT + "/"):
                raise AssetError("generated staging cannot be a current source")
            if a.get("path") != current:
                raise AssetError("path must equal authoritative current_path")
            if not source.is_file():
                raise AssetError(f"missing current source: {current}")
            sha = a.get("sha256")
            if not isinstance(sha, str) or not re.fullmatch(r"[0-9a-f]{64}", sha):
                raise AssetError("invalid SHA-256")
            if digest(source) != sha:
                raise AssetError(f"current SHA mismatch: {current}")
            planned = a.get("planned_canonical_path")
            terminal = a.get("asset_class") == "terminal-evidence" or a.get("source_kind") in TERMINAL_KINDS
            if a.get("source_kind") == "reconstructed-terminal" or a.get("reconstruction_method") is not None or a.get("reconstruction_confidence") is not None:
                raise AssetError("terminal reconstruction is forbidden")
            if terminal and state != "frozen":
                raise AssetError("terminal must be frozen")
            if state == "frozen":
                if (a.get("migration_role") != "frozen" or a["canonical_migration"] or a["canonical"]
                        or planned is not None or a["mkdocs_stage"] or a.get("mkdocs_stage_path") is not None
                        or a.get("generator_command") is not None or not a["preserve_original"]
                        or a.get("derived_from") or a.get("recreates_evidence_asset")):
                    raise AssetError("invalid frozen external contract")
            else:
                if not a["canonical_migration"] or a.get("migration_role") == "frozen":
                    raise AssetError("nonterminal migration contract inconsistent")
                if planned is None:
                    if state != "pending" or not a["review_required"] or a.get("status") != "unresolved" or not a.get("unresolved_reason"):
                        raise AssetError("missing canonical path requires explicit pending unresolved review")
                else:
                    repository_path(root, planned)
                    if not planned.startswith("documentation_assets/") or len(PurePosixPath(planned).parts) < 3:
                        raise AssetError("target must be an asset under documentation_assets/")
                    if PurePosixPath(planned).parts[1] not in {"ui", "evidence", "diagrams", "illustrations", "branding", "misc"}:
                        raise AssetError("invalid canonical category")
                    if not re.fullmatch(r"[a-z][a-z0-9]*(?:-[a-z0-9]+)*\." + IMAGE_SUFFIX, PurePosixPath(planned).name):
                        raise AssetError("canonical filename must be semantic lowercase-kebab-case")
                    if Path(planned).suffix.lower() != Path(current).suffix.lower():
                        raise AssetError("migration must preserve media extension")
                    folded = planned.casefold()
                    if folded in paths:
                        raise AssetError(f"canonical path collision with {paths[folded]}")
                    paths[folded] = label
                if state == "migrated":
                    if current != planned or not a["canonical"]:
                        raise AssetError("migrated current_path must equal canonical target and canonical=true")
                elif a["canonical"]:
                    raise AssetError("pending records cannot claim current canonical bytes")
            targets = a.get("targets")
            if not isinstance(targets, list) or any(t not in TARGETS for t in targets) or len(set(targets)) != len(targets):
                raise AssetError("invalid/duplicate targets")
            if state != "frozen" and "book-mkdocs" in targets and not a["mkdocs_stage"]:
                raise AssetError("book-mkdocs target requires staging")
            if a["mkdocs_stage"]:
                expected = STAGE_ROOT + "/" + planned.removeprefix("documentation_assets/") if planned else None
                if a.get("mkdocs_stage_path") != expected or expected is None:
                    raise AssetError("stage path must preserve canonical suffix")
                repository_path(root, expected)
                if expected.casefold() in stages:
                    raise AssetError("case-insensitive staging collision")
                stages.add(expected.casefold())
            elif a.get("mkdocs_stage_path") is not None:
                raise AssetError("unselected asset cannot have staging path")
        except (AssetError, OSError, TypeError, AttributeError) as exc:
            errors.append(f"{label}: {exc}")
    # Check ID links and cycles without pretending hypothetical recreations exist.
    graph = {}
    for label, a in ids.items():
        graph[label] = []
        for key in ("derived_from", "recreates_evidence_asset", "canonical_group_id"):
            target = a.get(key)
            if target and target not in ids:
                errors.append(f"{label}: dangling {key}: {target}")
            if target and key != "canonical_group_id" and target in ids:
                graph[label].append(target)
                if target == label:
                    errors.append(f"{label}: self-reference {key}")
                if key == "recreates_evidence_asset" and (not ids[target].get("original_evidence") or a.get("original_evidence") or ids[target].get("migration_state") == "frozen"):
                    errors.append(f"{label}: recreation must link nonterminal original evidence")
    visited, active = set(), set()
    def visit(node):
        if node in active:
            errors.append(f"{node}: derivation/recreation cycle")
            return
        if node in visited:
            return
        active.add(node)
        for target in graph[node]:
            visit(target)
        active.remove(node)
        visited.add(node)
    for label in graph:
        visit(label)
    try:
        freeze = json.loads(repository_path(root, "documentation_assets/terminal-freeze.json").read_text())
        expected = {a["id"]: a for a in freeze["assets"]}
        actual = {label: a for label, a in ids.items() if a.get("migration_state") == "frozen"}
        if set(expected) != set(actual):
            errors.append("frozen registry IDs differ from immutable terminal contract")
        for label, f in expected.items():
            a = actual.get(label, {})
            if a.get("current_path") != f["path"] or a.get("sha256") != f["sha256"]:
                errors.append(f"{label}: frozen path/SHA changed against terminal contract")
    except (OSError, ValueError, KeyError, TypeError, AssetError) as exc:
        errors.append(f"terminal freeze contract: {exc}")
    return errors


def selected_assets(data: dict) -> list[dict]:
    return sorted((a for a in data["assets"] if a["mkdocs_stage"] and a["migration_state"] != "frozen"), key=lambda a: a["mkdocs_stage_path"])


def typst_named_image_references(text: str):
    """Resolve literal calls to local helpers using prefix + first argument + suffix.

    This is deliberately not a Typst evaluator. Only brace-bodied helpers and
    constant string call arguments are supported; each call remains one use.
    """
    header = r'\b(?:let)\s+([\w-]+)\(\s*(\w+)\b[^)\n]*\)\s*=\s*[^\n{]*\{'
    for definition in re.finditer(header, text):
        depth, end = 1, definition.end()
        # Quoted strings and comments cannot terminate the helper body.
        token = re.compile(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*.*?\*/|[{}]', re.S)
        for part in token.finditer(text, end):
            if part[0] == "{":
                depth += 1
            elif part[0] == "}":
                depth -= 1
            if depth == 0:
                end = part.start()
                break
        else:
            continue
        expression = (r'\bimage\s*\(\s*"([^"\n]*)"\s*\+\s*'
                      + re.escape(definition[2]) + r'\s*\+\s*"([^"\n]*)"\s*(?=[,)])')
        templates = list(re.finditer(expression, text[definition.end():end]))
        call = r'(?<![\w-])' + re.escape(definition[1]) + r'\s*\(\s*"([^"\n]+)"\s*(?=[,)])'
        for use in re.finditer(call, text):
            if definition.start() <= use.start() <= end:
                continue
            for template in templates:
                yield use.start(), template[1] + use[1] + template[2]


def image_references(root: Path = REPO_ROOT) -> list[dict]:
    """Read actual source syntax; do not scan output/audit prose or treat generator examples as uses."""
    refs = []
    def add(source, line, literal, kind):
        url = urlsplit(literal)
        if url.scheme or url.netloc or literal.startswith("#"):
            return
        value = unquote(url.path)
        if not re.search(r"\." + IMAGE_SUFFIX + r"$", value, re.I):
            return
        if value.startswith("/"):
            resolved = root / value.lstrip("/")
        elif kind == "typst-helper" and source.startswith("00_book/"):
            resolved = root / "00_book" / value
        elif kind == "typst-helper" and source.startswith("00_report/"):
            resolved = root / "00_report/config" / value
        elif kind == "mkdocs-config":
            resolved = root / "00_book" / value
        else:
            resolved = (root / source).parent / value
        resolved = resolved.resolve()
        relative = str(resolved.relative_to(root.resolve())) if resolved.is_relative_to(root.resolve()) else "<outside-repository>"
        refs.append(dict(source_document=source, line=line, referenced_path=literal, reference_kind=kind, resolved_path=relative, exists=resolved.is_file()))
    for directory in ("00_book", "00_report"):
        for p in sorted((root / directory).rglob("*")):
            if not p.is_file() or p.suffix.lower() not in {".typ", ".md", ".html", ".css"} or p.is_relative_to(root / STAGE_ROOT):
                continue
            source = p.relative_to(root).as_posix()
            text = p.read_text(encoding="utf-8", errors="replace")
            definitions = {m.group(1).strip().casefold(): m.group(2) for m in re.finditer(r"^\s*\[([^\]]+)\]:\s*<?([^\s>]+)>?", text, re.M)}
            if p.suffix.lower() == ".typ":
                # Preserve line offsets while excluding full-line Typst comments.
                searchable = re.sub(r"(?m)^([ \t]*)//[^\n]*", "", text)
                for m in re.finditer(r'\b(image|insert-image)\s*\(\s*"([^"\n]+)"', searchable):
                    add(source, searchable.count("\n", 0, m.start()) + 1, m[2], "typst-helper" if m[1] == "insert-image" else "typst-image")
                for offset, literal in typst_named_image_references(searchable):
                    add(source, searchable.count("\n", 0, offset) + 1, literal, "typst-named-image-helper")
            else:
                for m in re.finditer(r'<img\b[^>]*\bsrc\s*=\s*["\']([^"\']+)', text, re.I):
                    add(source, text.count("\n", 0, m.start()) + 1, m[1], "html-img")
                for m in re.finditer(r'!\[[^\]]*\]\(\s*(?:<([^>]+)>|([^\s)]+))', text):
                    add(source, text.count("\n", 0, m.start()) + 1, m[1] or m[2], "markdown-image")
                for m in re.finditer(r'!\[([^\]]*)\]\[([^\]]*)\]', text):
                    key = (m[2] or m[1]).strip().casefold()
                    if key in definitions:
                        add(source, text.count("\n", 0, m.start()) + 1, definitions[key], "markdown-reference-image")
                for m in re.finditer(r'url\(\s*["\']?([^\s)"\']+)', text, re.I):
                    add(source, text.count("\n", 0, m.start()) + 1, m[1], "css-url")
    config = root / "mkdocs.yml"
    if config.is_file():
        for line, content in enumerate(config.read_text().splitlines(), 1):
            m = re.match(r'\s*(?:logo|favicon):\s*["\']?([^\s"\']+)', content)
            if m:
                add("mkdocs.yml", line, m[1], "mkdocs-config")
    return refs


def reference_key(r: dict) -> tuple:
    return tuple(r[k] for k in ("source_document", "referenced_path", "reference_kind", "resolved_path"))


def validate_references(root: Path = REPO_ROOT, strict: bool = False) -> tuple[list[str], int]:
    errors, accepted = [], 0
    refs = image_references(root)
    baseline_path = root / "documentation_assets/reference-baseline.json"
    baseline = json.loads(baseline_path.read_text()) if baseline_path.is_file() else {"broken_images": []}
    allowed = collections.Counter({reference_key(r): r["count"] for r in baseline["broken_images"]})
    current = collections.Counter(reference_key(r) for r in refs if not r["exists"])
    for key, count in current.items():
        exempt = min(count, allowed[key]) if not strict else 0
        accepted += exempt
        if count > exempt:
            errors.append(f"broken image ({count-exempt}): {key[0]} -> {key[1]} resolves {key[3]}")
    errors += validate_frozen_references(root, refs)
    for r in refs:
        if r["source_document"].startswith("00_report/") and (r["resolved_path"].startswith(STAGE_ROOT + "/") or "00_book/assets/" in r["referenced_path"]):
            errors.append(f"report cannot reference MkDocs staging: {r['source_document']}:{r['line']}")
    return errors, accepted


def validate_frozen_references(root: Path = REPO_ROOT, refs: list[dict] | None = None) -> list[str]:
    """Enforce immutable terminal uses without requiring generated staging."""
    errors = []
    if refs is None:
        refs = image_references(root)
    # Frozen reference counts are a multiset; line shifts during future nonterminal edits are harmless.
    freeze = json.loads(repository_path(root, "documentation_assets/terminal-freeze.json").read_text())
    expected = collections.Counter({(r["source_document"], r["referenced_path"]): r["count"] for r in freeze["references"]})
    frozen_paths = {r["path"] for r in freeze["assets"]}
    actual = collections.Counter((r["source_document"], r["referenced_path"]) for r in refs if r["resolved_path"] in frozen_paths)
    if expected != actual:
        errors.append(f"frozen terminal reference multiset changed: removed={dict(expected-actual)}, added={dict(actual-expected)}")
    return errors
