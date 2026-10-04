"""Lossless, owned MkDocs staging; source assets and frozen terminals never change."""
from __future__ import annotations

import argparse
import json
import os
import re
import tempfile
from pathlib import Path

if __package__:
    from .documentation_assets import (AssetError, LEDGER, REPO_ROOT, STAGE_ROOT, digest,
        load_manifest, repository_path, selected_assets, validate_manifest)
else:
    from documentation_assets import (AssetError, LEDGER, REPO_ROOT, STAGE_ROOT, digest,
        load_manifest, repository_path, selected_assets, validate_manifest)


def stage_plan(data: dict, root: Path) -> tuple[dict, dict, list[str]]:
    errors = validate_manifest(data, root)
    if errors:
        raise AssetError("manifest invalid:\n" + "\n".join(errors))
    stage = repository_path(root, STAGE_ROOT)
    ledger_path = stage / LEDGER
    old = {"version": 1, "root": STAGE_ROOT, "files": {}}
    if ledger_path.exists():
        if ledger_path.is_symlink():
            raise AssetError("ownership ledger cannot be a symlink")
        old = json.loads(ledger_path.read_text())
        if (not isinstance(old, dict) or old.get("version") != 1 or old.get("root") != STAGE_ROOT
                or not isinstance(old.get("files"), dict)):
            raise AssetError("invalid ownership ledger; no writes or cleanup permitted")
        for suffix, record in old["files"].items():
            repository_path(root, STAGE_ROOT + "/" + suffix)
            if suffix == LEDGER or not isinstance(record, dict) or not isinstance(record.get("sha256"), str) or not re.fullmatch(r"[0-9a-f]{64}", record["sha256"]):
                raise AssetError("invalid owned file entry")
    actual = set()
    if stage.exists():
        for p in stage.rglob("*"):
            if p.is_symlink():
                raise AssetError(f"symlink in staging: {p}")
            if p.is_file() and p != ledger_path:
                actual.add(p.relative_to(stage).as_posix())
    unknown = actual - old["files"].keys()
    if unknown:
        raise AssetError(f"unowned staged files, refuse overwrite/delete: {sorted(unknown)}")
    new = {"version": 1, "root": STAGE_ROOT, "files": {}}
    for a in selected_assets(data):
        suffix = a["mkdocs_stage_path"].removeprefix(STAGE_ROOT + "/")
        new["files"][suffix] = {"asset_id": a["id"], "sha256": a["sha256"], "source_path": a["current_path"]}
    all_paths = set(old["files"]) | set(new["files"])
    if len({p.casefold() for p in all_paths}) != len(all_paths):
        raise AssetError("case-insensitive collision in ownership ledger/stage plan")
    stale = sorted(old["files"].keys() - new["files"].keys())
    for suffix in stale:
        path = repository_path(root, STAGE_ROOT + "/" + suffix)
        if path.exists() and digest(path) != old["files"][suffix]["sha256"]:
            raise AssetError(f"stale owned file modified; refuse delete: {suffix}")
    return old, new, stale



def write_ledger(stage: Path, value: dict) -> None:
    encoded = json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    ledger = stage / LEDGER
    if ledger.is_file() and ledger.read_text() == encoded:
        return
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=stage, prefix=".ledger-", delete=False) as out:
            temporary = Path(out.name)
            out.write(encoded)
            out.flush()
            os.fsync(out.fileno())
        os.replace(temporary, ledger)
        temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def sync(data: dict, root: Path = REPO_ROOT, *, check: bool = False, dry_run: bool = False) -> list[str]:
    old, new, stale = stage_plan(data, root)
    stage = repository_path(root, STAGE_ROOT)
    differences = []
    for suffix, record in new["files"].items():
        path = repository_path(root, STAGE_ROOT + "/" + suffix)
        if not path.is_file() or digest(path) != record["sha256"]:
            differences.append("copy " + suffix)
    differences += ["remove-owned " + suffix for suffix in stale]
    if old != new or not (stage / LEDGER).is_file():
        differences.append("update-ledger")
    if check or dry_run:
        return differences
    # Journal intended owned outputs before copying; interrupted copies can be retried.
    # --check rejects the in-progress ledger until all copies and cleanup complete.
    stage.mkdir(parents=True, exist_ok=True)
    if differences:
        journal = {"version": 1, "root": STAGE_ROOT, "phase": "syncing",
                   "files": {**old["files"], **new["files"]}}
        write_ledger(stage, journal)
    for suffix, record in new["files"].items():
        destination = repository_path(root, STAGE_ROOT + "/" + suffix)
        source = repository_path(root, record["source_path"])
        if digest(source) != record["sha256"]:
            raise AssetError(f"source changed during sync: {record['source_path']}")
        if destination.is_file() and digest(destination) == record["sha256"]:
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(dir=destination.parent, prefix=".asset-", delete=False) as out, source.open("rb") as inp:
                temporary = Path(out.name)
                while chunk := inp.read(1024 * 1024):
                    out.write(chunk)
                out.flush()
                os.fsync(out.fileno())
            if digest(temporary) != record["sha256"]:
                raise AssetError(f"copy SHA mismatch: {suffix}")
            os.replace(temporary, destination)
            temporary = None
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)
    for suffix in stale:
        path = repository_path(root, STAGE_ROOT + "/" + suffix)
        if path.exists() and digest(path) != old["files"][suffix]["sha256"]:
            raise AssetError(f"stale file changed during sync: {suffix}")
        path.unlink(missing_ok=True)
    # Stable completed ledger; no timestamps or transient state remain.
    write_ledger(stage, new)
    return differences


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--check", action="store_true", help="read-only freshness/ownership check")
    modes.add_argument("--dry-run", action="store_true", help="read-only deterministic copy/cleanup plan")
    args = parser.parse_args(argv)
    try:
        data = load_manifest()
        changes = sync(data, check=args.check, dry_run=args.dry_run)
        for change in changes:
            print(change)
        print(f"Selected {len(selected_assets(data))} nonterminal assets; frozen terminals excluded.")
        return 1 if args.check and changes else 0
    except (AssetError, OSError, ValueError, TypeError) as exc:
        print(f"Documentation staging failed: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
