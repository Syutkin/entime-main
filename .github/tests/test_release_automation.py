from __future__ import annotations

import importlib.util
import json
import unittest
from copy import deepcopy
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
release_profiles = load_module("select_release_profile")
package_versions = load_module("select_lazarus_packages")


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


class ReleaseProfileTests(unittest.TestCase):
    def test_legacy_profile_is_used_before_0_9_0(self):
        profile = release_profiles.select_release_profile("0.8.3")
        self.assertEqual(profile["profile"], "legacy")
        self.assertEqual(profile["project_file"], "Entime.lpi")
        self.assertEqual(profile["build_mode"], "Release")
        self.assertEqual(profile["executable_path"], "release/Entime.exe")

    def test_current_profile_starts_at_0_9_0_and_includes_later_major_versions(self):
        for tag in ("0.9.0", "0.9.1", "1.0.0"):
            with self.subTest(tag=tag):
                profile = release_profiles.select_release_profile(tag)
                self.assertEqual(profile["profile"], "current")
                self.assertEqual(profile["project_file"], "entime.lpi")
                self.assertEqual(profile["build_mode"], "release")
                self.assertEqual(
                    profile["executable_path"], "build/bin/release/Entime.exe"
                )

    def test_invalid_release_tag_fails(self):
        for tag in ("v0.9.0", "0.9", "0.09.0", ""):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                release_profiles.select_release_profile(tag)


class PackageVersionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.configuration = json.loads(
            (Path(__file__).parents[1] / "lazarus-packages.json").read_text(
                encoding="utf-8"
            )
        )

    def selected_names(self, tag: str) -> set[str]:
        selected = package_versions.select_package_configuration(
            self.configuration, tag
        )
        return {package["name"] for package in selected["packages"]}

    def test_legacy_versions_exclude_ble_packages(self):
        selected = package_versions.select_package_configuration(
            self.configuration, "0.8.3"
        )
        names = {package["name"] for package in selected["packages"]}
        self.assertNotIn("SimpleBlePascal", names)
        self.assertNotIn("LazBle", names)
        self.assertIn("DataPort", names)
        self.assertIn("LazSerial", names)
        self.assertEqual(selected["schema"], 1)
        self.assertTrue(
            all(
                "entime_version_range" not in package
                for package in selected["packages"]
            )
        )

    def test_current_versions_replace_dataport_with_ble_packages(self):
        for tag in ("0.9.0", "0.9.1", "1.0.0"):
            with self.subTest(tag=tag):
                names = self.selected_names(tag)
                self.assertIn("SimpleBlePascal", names)
                self.assertIn("LazBle", names)
                self.assertNotIn("DataPort", names)

    def test_comparator_ranges_support_and_or(self):
        self.assertTrue(
            package_versions.version_matches((0, 8, 3), ">=0.8.0 <0.9.0")
        )
        self.assertFalse(
            package_versions.version_matches((0, 9, 0), ">=0.8.0 <0.9.0")
        )
        self.assertTrue(
            package_versions.version_matches((1, 2, 3), "<0.8.0 || >=1.0.0")
        )

    def test_invalid_or_missing_ranges_fail(self):
        with self.assertRaises(ValueError):
            package_versions.version_matches((0, 8, 3), ">=0.8")
        with self.assertRaises(ValueError):
            package_versions.version_matches((0, 8, 3), ">=0.8.0 ||")
        invalid = deepcopy(self.configuration)
        invalid["packages"][0].pop("entime_version_range")
        with self.assertRaises(ValueError):
            package_versions.select_package_configuration(invalid, "0.8.3")

    def test_overlapping_package_definitions_fail(self):
        invalid = deepcopy(self.configuration)
        invalid["packages"].append(deepcopy(invalid["packages"][0]))
        with self.assertRaisesRegex(ValueError, "Several package definitions"):
            package_versions.select_package_configuration(invalid, "0.8.3")


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
        cls.simpleble_downloader = (
            Path(__file__).parents[1]
            / "scripts"
            / "download_latest_simpleble.ps1"
        ).read_text(encoding="utf-8")
        cls.dependency_packager = (
            Path(__file__).parents[1]
            / "scripts"
            / "package_build_dependencies.ps1"
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

    def test_codeberg_snapshot_excludes_only_git_metadata_and_automation(self):
        import_step = self.workflow.split("- name: Import Codeberg source snapshot", 1)[1]
        self.assertIn("@('.git', '.github')", import_step)
        self.assertNotIn("@('.git', '.github', 'doc')", import_step)

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
        self.assertEqual(synapse["selector"], "branch")
        self.assertEqual(synapse["branch"], "master")
        self.assertEqual(synapse["lpk"], ["laz_synapse.lpk"])
        self.assertNotIn("Synapse40.1.zip", json.dumps(self.lazarus_packages))
        self.assertIn("commit = $commit", self.resolver)
        self.assertIn("Locked Git metadata", self.resolver)
        self.assertIn("Locked Git metadata", self.restorer)

    def test_ble_packages_use_latest_semver_tags_from_shared_config(self):
        packages = {
            package["name"]: package
            for package in self.lazarus_packages["packages"]
        }
        bindings = packages["SimpleBlePascal"]
        lazble = packages["LazBle"]
        self.assertEqual(bindings["source"], "git")
        self.assertEqual(bindings["selector"], "latest_tag")
        self.assertEqual(bindings["lpk"], ["simpleblepascal.lpk"])
        self.assertEqual(lazble["source"], "git")
        self.assertEqual(lazble["selector"], "latest_tag")
        self.assertEqual(lazble["lpk"], ["lazble.lpk", "lazblelcl.lpk"])
        self.assertLess(
            self.lazarus_packages["packages"].index(bindings),
            self.lazarus_packages["packages"].index(lazble),
        )
        self.assertNotIn("branch", bindings)
        self.assertNotIn("branch", lazble)
        self.assertIn("git ls-remote --tags --refs", self.resolver)
        self.assertIn("stable SemVer tags", self.resolver)
        self.assertIn("$metadata['tag'] = $target.tag", self.resolver)
        self.assertNotIn("v1.0.0", json.dumps(self.lazarus_packages))
        self.assertNotIn("v1.1.0", json.dumps(self.lazarus_packages))

    def test_workflow_selects_versioned_package_configuration(self):
        self.assertIn(
            "python .github/scripts/select_lazarus_packages.py",
            self.workflow,
        )
        self.assertIn("-ConfigFile $env:LAZARUS_PACKAGES_CONFIG", self.workflow)
        self.assertIn("$blePackages.Count -notin @(0, 2)", self.workflow)
        self.assertIn("USES_SIMPLEBLE=$(($blePackages.Count -eq 2)", self.workflow)

    def test_simplecble_latest_release_asset_supplies_both_dlls(self):
        self.assertIn(
            "$assetName = 'libsimplecble_windows-x64.zip'",
            self.simpleble_downloader,
        )
        self.assertNotIn(
            "$assetName = 'libsimpleble_windows-x64.zip'",
            self.simpleble_downloader,
        )
        self.assertIn("/releases/latest", self.simpleble_downloader)
        self.assertIn("selector = 'latest_release'", self.simpleble_downloader)
        self.assertIn("shared/bin", self.simpleble_downloader)
        self.assertIn("@('simplecble.dll', 'simpleble.dll')", self.simpleble_downloader)
        self.assertNotIn("v1.1.0", self.simpleble_downloader)

    def test_ble_runtime_files_are_locked_and_packaged(self):
        for dll in ("simplecble.dll", "simpleble.dll"):
            with self.subTest(dll=dll):
                self.assertIn(dll, self.dependency_packager)
                self.assertIn(dll, self.restorer)
                self.assertIn(dll, self.packager)
        self.assertIn("simpleble/dll", self.dependency_packager)
        self.assertIn("simpleble/dll", self.restorer)
        self.assertIn("-SimpleBleDirectory", self.workflow)
        self.assertIn("-SimpleBleDependenciesDirectory", self.workflow)
        self.assertIn("env.USES_SIMPLEBLE == 'true'", self.workflow)
        self.assertIn("if ($SimpleBleDirectory)", self.dependency_packager)

    def test_release_uses_versioned_project_layout_without_shipping_sql(self):
        self.assertIn(
            "python .github/scripts/select_release_profile.py --tag $env:TARGET_TAG",
            self.workflow,
        )
        self.assertIn(
            "lazbuild --no-write-project --ws=win32 --build-mode=$env:RELEASE_BUILD_MODE $env:PROJECT_FILE",
            self.workflow,
        )
        self.assertIn("-ExecutablePath $env:RELEASE_EXECUTABLE_PATH", self.workflow)
        self.assertIn("Runtime archive must not contain the build-time SQL schema", self.packager)
        self.assertNotIn("Copy-Item 'sql", self.packager)

    def test_release_can_run_from_a_branch_and_pushes_back_to_it(self):
        self.assertIn("$env:GITHUB_REF_TYPE -ne 'branch'", self.workflow)
        self.assertIn("AUTOMATION_BRANCH=$env:GITHUB_REF_NAME", self.workflow)
        self.assertIn("refs/heads/$env:AUTOMATION_BRANCH", self.workflow)
        self.assertNotIn("$branch -ne 'master'", self.workflow)

    def test_windows_release_runs_current_entime_test_projects(self):
        self.assertIn("- name: Run Windows test suites", self.workflow)
        self.assertIn(
            "lazbuild --no-write-project --ws=win32 --build-mode=windows $unitProject",
            self.workflow,
        )
        self.assertIn("& $unitBinary --all --format=plain", self.workflow)
        self.assertIn(
            "lazbuild --no-write-project --ws=win32 --build-mode=windows $integrationProject",
            self.workflow,
        )
        self.assertIn("& $integrationBinary --all --format=plain", self.workflow)
        self.assertNotIn("./scripts/run-tests.sh", self.workflow)
        self.assertNotIn("./scripts/run-integration-tests.sh", self.workflow)
        self.assertLess(
            self.workflow.index("- name: Restore locked runtime DLL paths"),
            self.workflow.index("- name: Run Windows test suites"),
        )
        self.assertLess(
            self.workflow.index("- name: Run Windows test suites"),
            self.workflow.index("- name: Build Windows x64 executable"),
        )

    def test_ci_does_not_compare_simpleble_and_pascal_binding_versions(self):
        combined = "\n".join(
            (self.simpleble_downloader, self.resolver, self.packager, self.workflow)
        ).lower()
        self.assertNotIn("abi", combined)
        self.assertNotIn("exported symbol", combined)
        self.assertNotIn("bindings version", combined)

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
