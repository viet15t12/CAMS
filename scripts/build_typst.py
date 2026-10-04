"""Build supported report/book targets with the repository-pinned toolchain."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shlex
import subprocess

if __package__:
    from .provision_typst import ROOT, DEFAULT_TOOLCHAIN, verify_toolchain
else:
    from provision_typst import ROOT, DEFAULT_TOOLCHAIN, verify_toolchain


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", choices=["report", "book", "all"], default="all")
    parser.add_argument("--toolchain-dir", type=Path, default=DEFAULT_TOOLCHAIN)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "output/typst")
    args = parser.parse_args(argv)
    toolchain = args.toolchain_dir.expanduser().resolve()
    output = args.output_dir.expanduser().resolve()
    try:
        lock = verify_toolchain(toolchain)
        output.mkdir(parents=True, exist_ok=True)
        results = []
        for target in ["report", "book"] if args.target == "all" else [args.target]:
            command = [str(toolchain / "bin/typst"), "compile", "--root", str(ROOT),
                       "--font-path", str(toolchain / "fonts"), "--ignore-system-fonts",
                       "--creation-timestamp", str(lock["creation_timestamp"]),
                       "--package-cache-path", str(output / "package-cache")]
            if target == "book":
                command += ["--input", "book-body-font=Liberation Serif"]
            command += [str(ROOT / f"00_{target}/main.typ"), str(output / f"{target}.pdf")]
            print(shlex.join(command), flush=True)
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
            diagnostics = result.stdout + result.stderr
            (output / f"{target}.log").write_text(diagnostics)
            print(diagnostics, end="", flush=True)
            # Missing-font fallback must never be mistaken for a reproducible PASS.
            font_failure = any(message in diagnostics.lower() for message in ["unknown font family", "variable fonts are not currently supported"])
            status = "PASS" if result.returncode == 0 and not font_failure else "FAIL"
            results.append({"target": target, "command": command, "exit_code": result.returncode, "status": status})
        (output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
        return int(any(r["status"] != "PASS" for r in results))
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as exc:
        print(f"Typst build failed: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
