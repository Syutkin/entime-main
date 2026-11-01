from __future__ import annotations

import hashlib
import json
import shutil
import struct
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

PWSH = shutil.which("pwsh")
PACKAGER = Path(__file__).parents[1] / "scripts" / "package_windows_release.ps1"


@unittest.skipUnless(PWSH, "PowerShell is required for the archive integration test")
class LabelTemplatePackagingTests(unittest.TestCase):
    def package(self, labels: bool, empty: bool = False, ble: str = ""):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "languages").mkdir()
            (root / "languages" / "entime.ru.po").write_text('msgid "x"\nmsgstr "y"\n', encoding="utf-8")
            (root / "sample.csv").write_text("number,name\n1,Test\n", encoding="utf-8")
            reports = root / "templates" / "reports"
            reports.mkdir(parents=True)
            html = b"<html><body>Report</body></html>"
            (reports / "sample.html").write_bytes(html)
            ini = "[StartLabels]\nName=24 наклейки\nWidth=70.00\n".encode("utf-8")
            if labels:
                folder = root / "templates" / "labels"
                folder.mkdir()
                if not empty:
                    (folder / "70x37.ini").write_bytes(ini)
                    (folder / "ignore.txt").write_text("not a template", encoding="utf-8")
            pe = bytearray(128)
            struct.pack_into("<H", pe, 0, 0x5A4D)
            struct.pack_into("<i", pe, 0x3C, 0x40)
            struct.pack_into("<IH", pe, 0x40, 0x4550, 0x8664)
            (root / "Entime.exe").write_bytes(pe)
            dependencies = root / "deps"
            dependencies.mkdir()
            manifest = []
            for name in ("libcrypto-3-x64.dll", "libssl-3-x64.dll", "sqlite3.dll"):
                content = name.encode("ascii")
                (dependencies / name).write_bytes(content)
                manifest.append({"name": name, "sha256": hashlib.sha256(content).hexdigest()})
            metadata = {"runtime_files": manifest}
            if ble:
                names = ["simplecble.dll"] if ble != "legacy" else ["simplecble.dll", "simpleble.dll"]
                for name in names:
                    (dependencies / name).write_bytes(pe)
                    manifest.append({"name": name, "sha256": hashlib.sha256(pe).hexdigest()})
                if ble == "modern":
                    metadata["runtime"] = {"simpleble": {"provider": "SimpleDelphiBLE"}}
            (root / "manifest.json").write_text(json.dumps(metadata), encoding="utf-8")
            result = subprocess.run([
                PWSH, "-NoProfile", "-NonInteractive", "-File", str(PACKAGER),
                "-Tag", "test", "-ExecutablePath", str(root / "Entime.exe"),
                "-OpenSslDependenciesDirectory", str(dependencies),
                "-SqlitePath", str(dependencies / "sqlite3.dll"),
                "-SimpleBleDependenciesDirectory", str(dependencies),
                "-DependencyManifestPath", str(root / "manifest.json"),
                "-OutputDirectory", str(root / "output"),
            ], cwd=root, capture_output=True, text=True, timeout=60)
            if ble == "incomplete":
                self.assertNotEqual(0, result.returncode)
                self.assertIn("both SimpleBLE", result.stdout + result.stderr)
                return
            if empty:
                self.assertNotEqual(0, result.returncode)
                self.assertIn("label", (result.stdout + result.stderr).lower())
                return
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            with zipfile.ZipFile(root / "output" / "Entime-test-win-x64.zip") as archive:
                self.assertEqual(html, archive.read("templates/reports/sample.html"))
                actual = {name for name in archive.namelist() if name.startswith("templates/") and not name.endswith("/")}
                expected = {"templates/reports/sample.html"}
                if labels:
                    expected.add("templates/labels/70x37.ini")
                    self.assertEqual(ini, archive.read("templates/labels/70x37.ini"))
                self.assertEqual(expected, actual)
                if ble:
                    self.assertEqual(bytes(pe), archive.read("simplecble.dll"))
                    self.assertEqual(ble == "legacy", "simpleble.dll" in archive.namelist())

    def test_archive_contains_ini_and_html_unchanged(self):
        self.package(labels=True)

    def test_older_sources_without_labels_still_package(self):
        self.package(labels=False)

    def test_present_but_empty_label_directory_is_rejected(self):
        self.package(labels=True, empty=True)

    def test_modern_runtime_packages_one_dll(self):
        self.package(labels=True, ble="modern")

    def test_legacy_runtime_still_requires_two_dlls(self):
        self.package(labels=True, ble="legacy")

    def test_incomplete_legacy_runtime_is_rejected(self):
        self.package(labels=True, ble="incomplete")
