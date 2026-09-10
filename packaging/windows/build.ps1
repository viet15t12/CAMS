[CmdletBinding()]
param(
    [string]$Version = "",
    [switch]$SkipTests,
    [switch]$FullTests,
    [switch]$SkipCython,
    [switch]$SkipTerminal,
    [switch]$SkipInstaller,
    [string]$SigningThumbprint = $env:CAMS_SIGN_SHA1
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw "The Windows package must be built on Windows 11 or a Windows CI runner."
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $RepoRoot

function Invoke-AuthenticodeSign {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not $SigningThumbprint) { return }
    $SignTool = Get-Command signtool.exe -ErrorAction SilentlyContinue
    if (-not $SignTool) {
        throw "signtool.exe is required when SigningThumbprint/CAMS_SIGN_SHA1 is set."
    }
    & $SignTool.Source sign /sha1 $SigningThumbprint /fd SHA256 `
        /tr "http://timestamp.digicert.com" /td SHA256 $Path
    if ($LASTEXITCODE -ne 0) { throw "Authenticode signing failed for $Path." }
}

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw "uv is required. Install it from https://docs.astral.sh/uv/."
}

Write-Host "Synchronizing the reproducible Windows build environment..."
uv sync --extra packaging --extra speed --python 3.12 --locked
if ($LASTEXITCODE -ne 0) { throw "uv sync failed." }

if (-not $SkipCython) {
    Write-Host "Building the optional accelerated device-sync engine..."
    uv run --python 3.12 python setup_cython.py build_ext --inplace --force
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Cython acceleration failed; packaging the Python fallback."
    } else {
        uv run --python 3.12 python -c `
            "from pathlib import Path; from features.devices.sync import _engine; raise SystemExit(0 if Path(_engine.__file__).suffix == '.pyd' else 1)"
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "The Cython module did not load; packaging the Python fallback."
        }
    }
}

if (-not $SkipTests) {
    uv run --python 3.12 python scripts/validate_structure.py
    if ($LASTEXITCODE -ne 0) { throw "Structure validation failed." }
    if ($FullTests) {
        uv run --python 3.12 python -m unittest discover -s tests -v
    } else {
        uv run --python 3.12 python -m unittest -v `
            tests.unit.test_windows_packaging_paths `
            tests.unit.test_runtime_tmp `
            tests.test_database_bootstrap `
            tests.test_workspace_package `
            tests.test_launcher_contracts
    }
    if ($LASTEXITCODE -ne 0) { throw "Tests failed." }
}

if (-not $SkipTerminal) {
    $Cargo = Get-Command cargo -ErrorAction SilentlyContinue
    if ($Cargo) {
        Write-Host "Building the optional CAMS Terminal companion..."
        cargo build --release --manifest-path vendor\alacritty\Cargo.toml --bin cams-terminal
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "CAMS Terminal failed to build; the main application will still be packaged."
        }
    } else {
        Write-Warning "Rust/Cargo was not found; packaging CAMS without the terminal companion."
    }
}

Write-Host "Building the one-folder Windows application..."
uv run --python 3.12 pyinstaller --noconfirm --clean `
    --distpath dist\windows --workpath build\windows `
    packaging\windows\cams.spec
if ($LASTEXITCODE -ne 0) { throw "PyInstaller failed." }

Invoke-AuthenticodeSign "dist\windows\CAMS\CAMS.exe"
$BundledTerminal = "dist\windows\CAMS\_internal\bin\cams-terminal.exe"
if (Test-Path $BundledTerminal) {
    Invoke-AuthenticodeSign $BundledTerminal
}

$Smoke = Start-Process -FilePath "dist\windows\CAMS\CAMS.exe" `
    -ArgumentList "--packaging-smoke-test" -Wait -PassThru
if ($Smoke.ExitCode -ne 0) {
    throw "The packaged executable failed its smoke test (exit $($Smoke.ExitCode))."
}

$PreviousQtPlatform = $env:QT_QPA_PLATFORM
$env:QT_QPA_PLATFORM = "offscreen"
try {
    $QmlSmoke = Start-Process -FilePath "dist\windows\CAMS\CAMS.exe" `
        -ArgumentList "--packaging-qml-smoke-test" -Wait -PassThru
    if ($QmlSmoke.ExitCode -ne 0) {
        throw "The packaged QML UI failed its smoke test (exit $($QmlSmoke.ExitCode))."
    }
} finally {
    $env:QT_QPA_PLATFORM = $PreviousQtPlatform
}

if (-not $Version) {
    $Version = uv run --python 3.12 python -c `
        "import tomllib; print(tomllib.load(open('pyproject.toml','rb'))['project']['version'])"
    if ($LASTEXITCODE -ne 0) { throw "Could not read the application version." }
    $Version = $Version.Trim()
}

if (-not $SkipInstaller) {
    $IsccCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    $IsccPath = if ($IsccCommand) { $IsccCommand.Source } else { "" }
    if (-not $IsccPath) {
        $IsccPath = @(
            "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
            "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
            "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
            "$env:ProgramFiles\Inno Setup 7\ISCC.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $IsccPath) {
            throw "Inno Setup 6/7 was not found. Install it or use -SkipInstaller."
        }
    }
    & $IsccPath "/DAppVersion=$Version" packaging\windows\installer.iss
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed." }
}

$Artifacts = Get-ChildItem dist\installer\*.exe -ErrorAction SilentlyContinue
if ($Artifacts) {
    foreach ($Artifact in $Artifacts) {
        Invoke-AuthenticodeSign $Artifact.FullName
    }
    $Artifacts | Get-FileHash -Algorithm SHA256 |
        ForEach-Object { "$($_.Hash.ToLower())  $([IO.Path]::GetFileName($_.Path))" } |
        Set-Content -Encoding ascii dist\installer\SHA256SUMS.txt
    Write-Host "Installer and checksum are ready in dist\installer."
} else {
    Write-Host "Portable application is ready in dist\windows\CAMS."
}
