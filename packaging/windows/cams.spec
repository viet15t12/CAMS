# -*- mode: python ; coding: utf-8 -*-
"""PyInstaller one-folder build for the Windows 11 installer."""

from pathlib import Path
import tomllib

from PyInstaller.utils.hooks import collect_all, collect_submodules


ROOT = Path(SPECPATH).resolve().parents[1]
WORK_ROOT = ROOT / "build" / "windows"
ICON = ROOT / "UI" / "resources" / "brand" / "logo.ico"

project = tomllib.loads((ROOT / "pyproject.toml").read_text(encoding="utf-8"))
VERSION = str(project["project"]["version"])
version_parts = [int(part) for part in VERSION.split(".")]
version_parts.extend([0] * (4 - len(version_parts)))
version_tuple = tuple(version_parts[:4])

WORK_ROOT.mkdir(parents=True, exist_ok=True)
version_file = WORK_ROOT / "version_info.txt"
version_file.write_text(
    "VSVersionInfo(ffi=FixedFileInfo(filevers=%r, prodvers=%r, mask=0x3f, "
    "flags=0x0, OS=0x40004, fileType=0x1, subtype=0x0, date=(0, 0)), "
    "kids=[StringFileInfo([StringTable('040904B0', ["
    "StringStruct('CompanyName', 'NetCamsTeam'), "
    "StringStruct('FileDescription', 'CAMS Network Management'), "
    "StringStruct('FileVersion', '%s'), "
    "StringStruct('InternalName', 'CAMS'), "
    "StringStruct('LegalCopyright', 'Copyright (c) NetCamsTeam'), "
    "StringStruct('OriginalFilename', 'CAMS.exe'), "
    "StringStruct('ProductName', 'CAMS'), "
    "StringStruct('ProductVersion', '%s')])]), "
    "VarFileInfo([VarStruct('Translation', [1033, 1200])])])"
    % (version_tuple, version_tuple, VERSION, VERSION),
    encoding="utf-8",
)

datas = [
    (str(ROOT / "UI"), "UI"),
    (str(ROOT / "templates"), "templates"),
    (str(ROOT / "runtime_qml"), "runtime_qml"),
    (str(ROOT / "features" / "acl" / "templates"), "features/acl/templates"),
    (str(ROOT / "features" / "dhcp" / "templates"), "features/dhcp/templates"),
    (str(ROOT / "features" / "fhrp" / "templates"), "features/fhrp/templates"),
    (str(ROOT / "features" / "nat" / "templates"), "features/nat/templates"),
    (
        str(ROOT / "features" / "routing" / "templates"),
        "features/routing/templates",
    ),
    (
        str(ROOT / "infrastructure" / "database" / "schemas"),
        "infrastructure/database/schemas",
    ),
    (str(ROOT / "licenses"), "licenses"),
    (str(ROOT / "README.md"), "."),
    (str(ROOT / "README.en.md"), "."),
    (str(ROOT / "LICENSE"), "."),
    (str(ROOT / "pyproject.toml"), "."),
]

hiddenimports = []
binaries = []
for package in ("core", "features", "infrastructure", "qtpyTerminal"):
    hiddenimports += collect_submodules(package)

# These libraries use plugin/driver discovery that static import analysis does
# not fully see. Their package data is required for device type dispatch.
for package in ("napalm", "netmiko", "nornir", "nornir_netmiko", "scapy"):
    package_datas, package_binaries, package_hidden = collect_all(package)
    datas += package_datas
    binaries += package_binaries
    hiddenimports += package_hidden

terminal_binary = (
    ROOT / "vendor" / "alacritty" / "target" / "release" / "cams-terminal.exe"
)
if terminal_binary.is_file():
    binaries.append((str(terminal_binary), "bin"))

a = Analysis(
    [str(ROOT / "main.py")],
    pathex=[str(ROOT), str(ROOT / "qtpyTerminal-main" / "src")],
    binaries=binaries,
    datas=datas,
    hiddenimports=sorted(set(hiddenimports)),
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=["archive", "tests", "docshots", "tkinter", "matplotlib"],
    noarchive=False,
    optimize=1,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="CAMS",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=str(ICON),
    version=str(version_file),
    uac_admin=False,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name="CAMS",
)
