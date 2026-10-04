"""Validate transitional asset metadata, current bytes and document references."""
from __future__ import annotations

import argparse
import json

if __package__:
    from .documentation_assets import REPO_ROOT, AssetError, load_manifest, validate_manifest, validate_references, validate_frozen_references
    from .sync_documentation_assets import sync
else:
    from documentation_assets import REPO_ROOT, AssetError, load_manifest, validate_manifest, validate_references, validate_frozen_references
    from sync_documentation_assets import sync


def main(argv=None, *, root=REPO_ROOT) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict-references", action="store_true", help="reject even recorded pre-existing broken images")
    parser.add_argument("--check-staging", action="store_true", help="also require a fresh owned staging tree")
    parser.add_argument("--manifest-only", action="store_true", help="pre-sync: validate current sources and frozen contracts; defer general image references")
    args = parser.parse_args(argv)
    if args.manifest_only and (args.check_staging or args.strict_references):
        parser.error("--manifest-only cannot be combined with --check-staging or --strict-references")
    try:
        data = load_manifest(root)
        errors = validate_manifest(data, root)
        existing = None
        if args.manifest_only:
            errors += validate_frozen_references(root)
        else:
            reference_errors, existing = validate_references(root, strict=args.strict_references)
            errors += reference_errors
        if args.check_staging and not errors:
            changes = sync(data, root, check=True)
            errors += ["stale staging: " + c for c in changes]
        summary = {"records": len(data["assets"]), "pending": sum(a["migration_state"] == "pending" for a in data["assets"]), "frozen": sum(a["migration_state"] == "frozen" for a in data["assets"]), "migrated": sum(a["migration_state"] == "migrated" for a in data["assets"]), "known_broken_reference_occurrences": existing}
        print(json.dumps(summary, ensure_ascii=False, sort_keys=True))
        if errors:
            for error in errors:
                print("ERROR: " + error)
            return 1
        print("Pre-sync validation passed; general references deferred until after sync." if args.manifest_only else "Documentation asset validation passed (recorded baseline exceptions shown above).")
        return 0
    except (AssetError, OSError, ValueError, KeyError, TypeError) as exc:
        print(f"Documentation asset validation failed: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
