from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from infrastructure.database.paths import _default_data_dir
from main import _project_argument


class WindowsPackagingPathTests(unittest.TestCase):
    ROOT = Path(__file__).resolve().parents[2]

    def test_frozen_windows_build_uses_local_app_data(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            local_app_data = Path(temporary_directory) / "Local"

            result = _default_data_dir(
                platform_name="nt",
                frozen=True,
                environ={"LOCALAPPDATA": str(local_app_data)},
            )

            self.assertEqual(
                result,
                (local_app_data / "NetCamsTeam" / "CAMS" / "data").resolve(),
            )

    def test_explicit_data_directory_wins_in_packaged_build(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            override = Path(temporary_directory) / "portable-data"

            result = _default_data_dir(
                platform_name="nt",
                frozen=True,
                environ={
                    "LOCALAPPDATA": str(Path(temporary_directory) / "Local"),
                    "CAMS_DATA_DIR": str(override),
                },
            )

            self.assertEqual(result, override.resolve())

    def test_source_execution_keeps_repository_local_data(self) -> None:
        result = _default_data_dir(
            platform_name="nt",
            frozen=False,
            environ={},
        )

        self.assertEqual(result, (Path(__file__).resolve().parents[2] / "data").resolve())

    def test_ntp_file_association_argument_is_discovered(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            project = Path(temporary_directory) / "lab.ntp"
            project.touch()

            result = _project_argument(["CAMS.exe", str(project)])

            self.assertEqual(result, project.resolve())

    def test_installer_is_per_user_and_preserves_user_data(self) -> None:
        installer = (
            self.ROOT / "packaging" / "windows" / "installer.iss"
        ).read_text(encoding="utf-8")

        self.assertIn("PrivilegesRequired=lowest", installer)
        self.assertIn("DefaultDirName={localappdata}\\Programs\\CAMS", installer)
        self.assertIn("LicenseFile=..\\..\\LICENSE", installer)
        self.assertIn('Subkey: "Software\\Classes\\.ntp"', installer)
        self.assertNotIn("[UninstallDelete]", installer)

    def test_spec_bundles_qml_schemas_and_feature_templates(self) -> None:
        spec = (self.ROOT / "packaging" / "windows" / "cams.spec").read_text(
            encoding="utf-8"
        )

        for required in (
            'ROOT / "UI"',
            'ROOT / "infrastructure" / "database" / "schemas"',
            'ROOT / "features" / "routing" / "templates"',
            'ROOT / "features" / "dhcp" / "templates"',
        ):
            self.assertIn(required, spec)

    def test_windows_launcher_exposes_packaging_command(self) -> None:
        launcher = (self.ROOT / "cams.bat").read_text(encoding="utf-8")

        self.assertIn('if /I "%~1"=="package" goto package', launcher)
        self.assertIn("packaging\\windows\\build.ps1", launcher)


if __name__ == "__main__":
    unittest.main()
