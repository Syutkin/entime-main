from __future__ import annotations

import importlib.util
import json
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).parents[1] / "scripts"


def load_module(name: str):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / f"{name}.py")
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load {name}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


changelog = load_module("extract_changelog_release_notes")
release_tags = load_module("select_release_tag")


class ChangelogTests(unittest.TestCase):
    def test_bracketed_version_with_date(self):
        text = """# Changelog

## [Unreleased]

- Work in progress.

## [0.8.1] - 2026-08-01

### Fixed

- Release fix.

## [0.8.0]

- Previous.
"""
        self.assertEqual(
            changelog.extract_section(text, "0.8.1"),
            "### Fixed\n\n- Release fix.\n",
        )

    def test_unbracketed_last_section(self):
        text = (
            "# Changelog\n\n"
            "## 0.7.10\n\n"
            "- First release.\n\n"
            "[unreleased]: https://example.test/compare/0.7.10...HEAD\n"
            "[0.7.10]: https://example.test/releases/0.7.10\n"
        )
        self.assertEqual(
            changelog.extract_section(text, "0.7.10"),
            "- First release.\n",
        )

    def test_missing_and_empty_sections_fail(self):
        with self.assertRaises(ValueError):
            changelog.extract_section("## [0.8.0]\n\n- Existing.\n", "0.8.1")
        with self.assertRaises(ValueError):
            changelog.extract_section("## [0.8.1]\n\n## [0.8.0]\n", "0.8.1")


class ReleaseTagTests(unittest.TestCase):
    def test_next_tag_is_semantically_sorted(self):
        selected = release_tags.select_release_tag(
            "sync_next",
            "",
            ["0.10.0", "0.9.1", "invalid", "0.8.1"],
            ["0.8.0"],
        )
        self.assertEqual(selected, "0.8.1")

    def test_requested_newer_codeberg_tag(self):
        selected = release_tags.select_release_tag(
            "sync_next",
            "0.10.0",
            ["0.8.1", "0.10.0"],
            ["0.8.0"],
        )
        self.assertEqual(selected, "0.10.0")

    def test_no_new_tag_is_a_successful_empty_result(self):
        self.assertIsNone(
            release_tags.select_release_tag(
                "sync_next", "", ["0.8.0"], ["0.8.0"]
            )
        )

    def test_invalid_sync_requests_fail(self):
        with self.assertRaises(ValueError):
            release_tags.select_release_tag(
                "sync_next", "0.7.9", ["0.7.9"], ["0.8.0"]
            )
        with self.assertRaises(ValueError):
            release_tags.select_release_tag(
                "sync_next", "0.8.1", ["0.8.2"], ["0.8.0"]
            )
        with self.assertRaises(ValueError):
            release_tags.select_release_tag(
                "sync_next", "v0.8.1", ["v0.8.1"], ["0.8.0"]
            )

    def test_existing_modes_require_an_existing_tag(self):
        for mode in ("publish_existing", "rebuild_existing"):
            with self.subTest(mode=mode):
                self.assertEqual(
                    release_tags.select_release_tag(
                        mode, "0.7.13", [], ["0.7.13", "0.8.0"]
                    ),
                    "0.7.13",
                )
                with self.assertRaises(ValueError):
                    release_tags.select_release_tag(mode, "", [], ["0.7.13"])
                with self.assertRaises(ValueError):
                    release_tags.select_release_tag(mode, "0.7.14", [], ["0.7.13"])


class WorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = (
            Path(__file__).parents[1] / "workflows" / "create-release.yml"
        ).read_text(encoding="utf-8")
        cls.packager = (
            Path(__file__).parents[1] / "scripts" / "package_windows_release.ps1"
        ).read_text(encoding="utf-8")
        cls.resolver = (
            Path(__file__).parents[1]
            / "scripts"
            / "resolve_lazarus_dependencies.ps1"
        ).read_text(encoding="utf-8")
        cls.restorer = (
            Path(__file__).parents[1]
            / "scripts"
            / "restore_locked_dependencies.ps1"
        ).read_text(encoding="utf-8")
        cls.lazarus_installer = (
            Path(__file__).parents[1]
            / "scripts"
            / "install_official_lazarus.ps1"
        ).read_text(encoding="utf-8")
        cls.openssl_downloader = (
            Path(__file__).parents[1]
            / "scripts"
            / "download_latest_openssl.ps1"
        ).read_text(encoding="utf-8")
        cls.sqlite_downloader = (
            Path(__file__).parents[1]
            / "scripts"
            / "download_latest_sqlite.ps1"
        ).read_text(encoding="utf-8")
        cls.lazarus_packages = json.loads(
            (Path(__file__).parents[1] / "lazarus-packages.json").read_text(
                encoding="utf-8"
            )
        )

    def test_dependency_mode_is_not_exposed(self):
        self.assertNotIn("dependency_mode:", self.workflow)

    def test_dry_run_precedes_toolchain_installation(self):
        self.assertLess(
            self.workflow.index("- name: Report dry run"),
            self.workflow.index("- name: Install Lazarus toolchain"),
        )

    def test_dry_run_validates_notes_and_does_not_build(self):
        self.assertLess(
            self.workflow.index("- name: Validate changelog release notes"),
            self.workflow.index("- name: Report dry run"),
        )
        report = self.workflow.split("- name: Report dry run", 1)[1].split(
            "- name: Create imported release commit and tag", 1
        )[0]
        self.assertIn("CONTINUE_PIPELINE=false", report)

    def test_release_does_not_compile_gettext_catalogs(self):
        self.assertNotIn("msgfmt", self.workflow)
        self.assertNotIn("choco install gettext", self.workflow)

    def test_release_contains_all_po_files_only(self):
        self.assertIn("Get-ChildItem $languagesRoot -Recurse -File -Filter '*.po'", self.packager)
        self.assertIn("must not contain MO catalogs or POT templates", self.packager)

    def test_release_contains_all_root_csv_files_as_samples(self):
        self.assertIn(
            "Get-ChildItem -Path '.' -File -Filter '*.csv'", self.packager
        )
        self.assertIn(
            "Archive sample CSV files do not match the current project root CSV files",
            self.packager,
        )
        self.assertIn(
            "Sample CSV files included in the release ($($sampleFiles.Count)):",
            self.packager,
        )
        self.assertIn('Write-Host "  - $($sampleFile.Name)"', self.packager)
        self.assertNotIn("'finish_results.csv'", self.packager)

    def test_release_notes_are_exact_changelog_section(self):
        self.assertNotIn("- name: Create release notes", self.workflow)
        publish_step = self.workflow.split("- name: Publish GitHub Release", 1)[1]
        self.assertIn('--notes-file "$env:BASE_RELEASE_NOTES"', publish_step)
        self.assertNotIn("Archive SHA-256", self.workflow)
        self.assertNotIn("## Source", self.workflow)

    def test_synapse_comes_from_git_master_and_records_commit(self):
        synapse = next(
            package
            for package in self.lazarus_packages["packages"]
            if package["name"] == "Synapse"
        )
        self.assertEqual(synapse["source"], "git")
        self.assertEqual(synapse["repository"], "https://github.com/geby/synapse.git")
        self.assertEqual(synapse["branch"], "master")
        self.assertEqual(synapse["lpk"], ["laz_synapse.lpk"])
        self.assertNotIn("Synapse40.1.zip", json.dumps(self.lazarus_packages))
        self.assertIn("commit = $commit", self.resolver)
        self.assertIn("Locked Git metadata", self.resolver)
        self.assertIn("Locked Git metadata", self.restorer)

    def test_runtime_packages_use_lazarus_package_links(self):
        self.assertIn("lazbuild --add-package-link $path", self.resolver)
        self.assertIn("lazbuild --add-package-link $myForksPath", self.resolver)
        self.assertNotIn('"--add-package-link=$path"', self.resolver)

    def test_lazarus_installation_has_compact_progress_logging(self):
        for message in (
            "Installed toolchain cache: hit",
            "Installed toolchain cache: miss",
            "Verifying installer SHA-256",
            "Verifying installer Authenticode signature",
            "Installing Lazarus to",
            "Lazarus toolchain is ready",
        ):
            with self.subTest(message=message):
                self.assertIn(message, self.lazarus_installer)
        self.assertIn("WaitForExit(60000)", self.lazarus_installer)
        self.assertIn("--silent --show-error", self.lazarus_installer)

    def test_lazarus_cache_contains_installed_toolchain_not_installer(self):
        self.assertIn(
            "- name: Restore installed Lazarus toolchain cache", self.workflow
        )
        self.assertIn(
            "- name: Save installed Lazarus toolchain cache", self.workflow
        )
        self.assertIn("path: C:\\lazarus", self.workflow)
        self.assertIn("entime-installed-lazarus-v1-", self.workflow)
        self.assertNotIn(
            "key: entime-official-lazarus-", self.workflow
        )
        cache_sections = "\n".join(
            section
            for section in self.workflow.split("\n\n")
            if "Lazarus toolchain cache" in section
        )
        self.assertNotIn("runner.temp }}/lazarus-toolchain", cache_sections)

    def test_unsigned_openssl_requires_official_manifest_hash(self):
        self.assertLess(
            self.openssl_downloader.index("SHA-256 mismatch"),
            self.openssl_downloader.index("Get-AuthenticodeSignature"),
        )
        self.assertIn(
            "$signatureStatus -eq 'NotSigned'", self.openssl_downloader
        )
        self.assertIn(
            "official-manifest-sha256-only", self.openssl_downloader
        )
        self.assertIn(
            "verification = $signatureVerification", self.openssl_downloader
        )

    def test_openssl_manifest_commit_does_not_use_github_rest_api(self):
        self.assertIn("git ls-remote --exit-code", self.openssl_downloader)
        self.assertIn("refs/heads/master", self.openssl_downloader)
        self.assertNotIn("api.github.com", self.openssl_downloader)
        self.assertNotIn("Invoke-RestMethod", self.openssl_downloader)

    def test_sqlite_sha3_uses_python_hashlib(self):
        self.assertIn("hashlib.sha3_256", self.sqlite_downloader)
        self.assertIn("PRODUCT,[^,", self.sqlite_downloader)
        self.assertIn("$actualSize -ne $expectedSize", self.sqlite_downloader)
        self.assertNotIn(
            "Get-FileHash -Path $archivePath -Algorithm SHA3-256",
            self.sqlite_downloader,
        )
        self.assertNotIn("$contextStart", self.sqlite_downloader)
        self.assertIn(
            "actualHash -notmatch '^[a-f0-9]{64}$'",
            self.sqlite_downloader,
        )


if __name__ == "__main__":
    unittest.main()
