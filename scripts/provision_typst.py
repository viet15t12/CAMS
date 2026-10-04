"""Provision the checksum-pinned Linux x86_64 Typst/font toolchain."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
from pathlib import Path
import subprocess
import tarfile
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / "scripts/typst-toolchain.lock.json"
DEFAULT_TOOLCHAIN = ROOT / "output/typst/toolchain"


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(data)
        os.replace(temporary, path)
        temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def verify_toolchain(destination):
    lock = json.loads(LOCK.read_text())
    ledger = json.loads((destination / "installed.json").read_text())
    if ledger["lock_sha256"] != sha(LOCK):
        raise ValueError("Toolchain lock changed; provision again")
    expected = {p for archive in lock["archives"] for p in archive["files"].values()}
    if set(ledger["files"]) != expected:
        raise ValueError("Incomplete installed toolchain")
    expected_fonts = {name for name in expected if name.startswith("fonts/")}
    actual_fonts = {p.relative_to(destination).as_posix() for p in (destination / "fonts").rglob("*") if p.is_file()}
    if actual_fonts != expected_fonts:
        raise ValueError("Unmanaged/missing font files; provision into a clean toolchain directory")
    for name, digest in ledger["files"].items():
        if sha(destination / name) != digest:
            raise ValueError(f"Installed toolchain file changed: {name}")
    version = subprocess.check_output([str(destination / "bin/typst"), "--version"], text=True).strip()
    if version.split()[1] != lock["typst_version"]:
        raise ValueError(f"Wrong Typst version: {version}")
    return lock


def provision(destination, archive_dir):
    if platform.system() != "Linux" or platform.machine() not in {"x86_64", "AMD64"}:
        raise ValueError("Pinned installer supports Linux x86_64; use Linux/WSL/container on other platforms")
    lock = json.loads(LOCK.read_text())
    archive_dir.mkdir(parents=True, exist_ok=True)
    files = {}
    for archive in lock["archives"]:
        cached = archive_dir / (archive["name"] + "-" + archive["sha256"])
        if not cached.exists():
            print(f"Downloading {archive['name']} from {archive['url']}", flush=True)
            with urllib.request.urlopen(archive["url"], timeout=60) as response:
                payload = response.read()
            if hashlib.sha256(payload).hexdigest() != archive["sha256"]:
                raise ValueError(f"Download checksum mismatch: {archive['name']}")
            atomic_write(cached, payload)
        if sha(cached) != archive["sha256"]:
            raise ValueError(f"Cached archive checksum mismatch: {archive['name']}")
        # Extract only the reviewed members, never archive paths or symlinks.
        if archive["format"] == "zip":
            with zipfile.ZipFile(cached) as bundle:
                contents = {target: bundle.read(member) for member, target in archive["files"].items()}
        else:
            with tarfile.open(cached) as bundle:
                contents = {}
                for member, target in archive["files"].items():
                    info = bundle.getmember(member)
                    if not info.isfile():
                        raise ValueError(f"Archive member is not a regular file: {member}")
                    contents[target] = bundle.extractfile(info).read()
        for target, content in contents.items():
            atomic_write(destination / target, content)
            files[target] = hashlib.sha256(content).hexdigest()
    (destination / "bin/typst").chmod(0o755)
    atomic_write(destination / "installed.json", (json.dumps({"lock_sha256": sha(LOCK), "files": files}, sort_keys=True, indent=2) + "\n").encode())
    verify_toolchain(destination)
    print(f"Typst {lock['typst_version']} ready: {destination}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destination", type=Path, default=DEFAULT_TOOLCHAIN)
    parser.add_argument("--archive-dir", type=Path)
    args = parser.parse_args(argv)
    destination = args.destination.expanduser().resolve()
    try:
        provision(destination, args.archive_dir.expanduser().resolve() if args.archive_dir else destination / "archives")
    except (OSError, ValueError, KeyError, tarfile.TarError, zipfile.BadZipFile, subprocess.CalledProcessError) as exc:
        print(f"Typst provisioning failed: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
