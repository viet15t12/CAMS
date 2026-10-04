"""Validate transitional asset metadata, current bytes and document references."""
from __future__ import annotations

import argparse
import json

if __package__:
    from .documentation_assets import REPO_ROOT, AssetError, load_manifest, validate_manifest, validate_references
    from .sync_documentation_assets import sync
else:
    from documentation_assets import REPO_ROOT, AssetError, load_manifest, validate_manifest, validate_references
    from sync_documentation_assets import sync


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict-references", action="store_true", help="reject even recorded pre-existing broken images")
    parser.add_argument("--check-staging", action="store_true", help="also require a fresh owned staging tree")
    args = parser.parse_args(argv)
    try:
        data = load_manifest()
        errors = validate_manifest(data)
        reference_errors, existing = validate_references(strict=args.strict_references)
        errors += reference_errors
        if args.check_staging and not errors:
            changes = sync(data, check=True)
            errors += ["stale staging: " + c for c in changes]
        summary = {"records": len(data["assets"]), "pending": sum(a["migration_state"] == "pending" for a in data["assets"]), "frozen": sum(a["migration_state"] == "frozen" for a in data["assets"]), "migrated": sum(a["migration_state"] == "migrated" for a in data["assets"]), "known_broken_reference_occurrences": existing}
        print(json.dumps(summary, ensure_ascii=False, sort_keys=True))
        if errors:
            for error in errors:
                print("ERROR: " + error)
            return 1
        print("Documentation asset validation passed (recorded baseline exceptions shown above).")
        return 0
    except (AssetError, OSError, ValueError, KeyError, TypeError) as exc:
        print(f"Documentation asset validation failed: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
