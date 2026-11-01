from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

PWSH = shutil.which("pwsh")
SCRIPTS = Path(__file__).parents[1] / "scripts"


@unittest.skipUnless(PWSH, "PowerShell is required")
class PinnedDependencyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.addCleanup(self.temp.cleanup)
        (self.root / "myforks.lpk").write_text("fixture")
        self.toolchain = self.root / "toolchain"
        self.toolchain.mkdir()
        (self.toolchain / "lazarus-toolchain.json").write_text("{}")

    def git(self, repo, *args):
        return subprocess.check_output([
            "git", "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
            "-c", "commit.gpgsign=false", "-C", str(repo), *args,
        ], stderr=subprocess.DEVNULL, text=True).strip()

    def run_ps(self, script, args, setup="", extra=None):
        launcher = self.root / "run.ps1"
        quoted = " ".join(str(a) if str(a).startswith("-") else "'" + str(a).replace("'", "''") + "'" for a in args)
        launcher.write_text("$ErrorActionPreference = 'Stop'\n" + setup + "\n& '" + str(SCRIPTS / script).replace("'", "''") + "' " + quoted)
        env = dict(os.environ, LAZARUS_TOOLCHAIN_DIRECTORY=str(self.toolchain))
        if extra:
            env.update(extra)
        return subprocess.run([PWSH, "-NoProfile", "-NonInteractive", "-File", str(launcher)],
                              cwd=self.root, env=env, capture_output=True, text=True, timeout=45)

    def resolve(self, config, mode="latest", lock=None):
        path = self.root / "config.json"
        path.write_text(json.dumps(config))
        args = ["-Mode", mode, "-OutputDirectory", self.root / "output", "-ConfigFile", path]
        if lock:
            args += ["-LockFile", lock]
        setup = """
function global:lazbuild { $global:LASTEXITCODE = 0; 'fixture lazbuild' }
function global:fpc { $global:LASTEXITCODE = 0; '3.2.2' }
"""
        return self.run_ps("resolve_lazarus_dependencies.ps1", args, setup)

    def test_commit_checkout_ignores_newer_head_and_locked_restore_checks_hash(self):
        repo = self.root / "repo"
        repo.mkdir()
        self.git(repo, "init", "-q")
        (repo / "fixture.lpk").write_text("first")
        self.git(repo, "add", ".")
        self.git(repo, "commit", "-qm", "first")
        commit = self.git(repo, "rev-parse", "HEAD")
        (repo / "fixture.lpk").write_text("newer")
        self.git(repo, "commit", "-qam", "second")
        config = {"schema": 1, "packages": [{"name": "Pinned", "source": "git",
                  "repository": str(repo), "selector": "commit", "commit": commit,
                  "archive": "Pinned.zip", "directory": "packages/Pinned", "lpk": ["fixture.lpk"]}]}
        result = self.resolve(config)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        archive = self.root / "output/Pinned.zip"
        with zipfile.ZipFile(archive) as z:
            self.assertEqual(b"first", z.read("fixture.lpk"))
        lock = self.root / "output/build-dependencies.json"
        metadata = json.loads(lock.read_text(encoding="utf-8-sig"))
        self.assertEqual(commit, metadata["packages"][0]["commit"])
        shutil.rmtree(self.root / "output/packages/Pinned")
        result = self.resolve(config, "locked", lock)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual("first", (self.root / "output/packages/Pinned/fixture.lpk").read_text())
        archive.write_bytes(b"corrupt archive")
        result = self.resolve(config, "locked", lock)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("Checksum mismatch", result.stdout + result.stderr)

    def test_commit_selector_rejects_short_sha(self):
        config = {"schema": 1, "packages": [{"name": "Pinned", "source": "git",
                  "repository": str(self.root), "selector": "commit", "commit": "1234567", "archive": "Pinned.zip"}]}
        result = self.resolve(config)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("full commit SHA", result.stdout + result.stderr)

    def test_lazarus_uses_stable_installer_when_rc_appears_first(self):
        html = self.root / "checksums.html"
        html.write_text("<h2>Lazarus 5.0RC1</h2><pre>" + "a" * 64 +
                        " lazarus-5.0RC1-fpc-3.2.2-win64.exe</pre>" +
                        "<h2>Lazarus 4.8</h2><pre>" + "b" * 64 +
                        " lazarus-4.8-fpc-3.2.2-win64.exe</pre>")
        setup = """
function global:Invoke-WebRequest {
    param($Uri, [switch]$UseBasicParsing)
    [PSCustomObject]@{ Content = (Get-Content -Raw $env:CHECKSUMS_HTML) }
}
"""
        result = self.run_ps("install_official_lazarus.ps1",
                             ["-OutputDirectory", self.root / "installer", "-ResolveOnly"],
                             setup, {"CHECKSUMS_HTML": str(html)})
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("lazarus-4.8-fpc-3.2.2-win64.exe", result.stdout)
        self.assertEqual("b" * 64, result.stdout.strip().splitlines()[-1])

    def test_runtime_uses_pinned_distribution_and_rejects_wrong_hash(self):
        fixture = self.root / "runtime.zip"
        dll = b"matching native runtime"
        with zipfile.ZipFile(fixture, "w") as z:
            z.writestr("simpledelphible-1.3.1-dev.25/lib/win64/simplecble.dll", dll)
        runtime = {"release_tag": "v1.3.1-dev.25", "asset": "simpledelphible-1.3.1-dev.25.zip",
                   "sha256": hashlib.sha256(fixture.read_bytes()).hexdigest()}
        config = {"packages": [{"name": "SimpleDelphiBLE", "commit": "a" * 40, "runtime": runtime}]}
        path = self.root / "config.json"
        path.write_text(json.dumps(config))
        setup = """
function global:Invoke-WebRequest {
    param($Uri, $OutFile, [switch]$UseBasicParsing)
    Copy-Item $env:FIXTURE_ARCHIVE $OutFile
}
"""
        args = ["-ConfigFile", path, "-OutputDirectory", self.root / "runtime"]
        result = self.run_ps("download_simpledelphible_runtime.ps1", args, setup, {"FIXTURE_ARCHIVE": str(fixture)})
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual(dll, (self.root / "runtime/simplecble.dll").read_bytes())
        metadata = json.loads((self.root / "runtime/simpleble-dependency.json").read_text(encoding="utf-8-sig"))
        self.assertEqual("a" * 40, metadata["commit"])
        self.assertEqual(hashlib.sha256(dll).hexdigest(), metadata["dlls"][0]["sha256"])
        shutil.rmtree(self.root / "runtime")
        runtime["sha256"] = "0" * 64
        path.write_text(json.dumps(config))
        result = self.run_ps("download_simpledelphible_runtime.ps1", args, setup, {"FIXTURE_ARCHIVE": str(fixture)})
        self.assertNotEqual(0, result.returncode)
        self.assertIn("SHA-256 mismatch", result.stdout + result.stderr)
        self.assertFalse((self.root / "runtime/simplecble.dll").exists())
