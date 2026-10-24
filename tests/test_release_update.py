"""Release verification and metadata promotion regressions, without network access."""
import importlib.util
import io
import json
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("prepare_update", ROOT / "scripts/ci/prepare-update.py")
VERIFY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFY)
PUBLISH = ROOT / "scripts/ci/publish-update.sh"


class VerifyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.package = Path(self.temp.name) / "module.zip"
        with zipfile.ZipFile(self.package, "w") as archive:
            archive.writestr("module.prop", "version=v2.0.0\nversionCode=20000\n")
        self.content = self.package.read_bytes()
        self.url = "https://github.com/owner/repo/releases/download/v2.0.0/module.zip"
        self.asset = {"name": "module.zip", "state": "uploaded", "size": len(self.content), "browser_download_url": self.url}

    def prepare(self, assets=None):
        return VERIFY.prepare_update(self.package, [self.asset] if assets is None else assets, "owner/repo", "v2.0.0")

    def test_public_asset_is_verified_and_metadata_matches_zip(self):
        with patch.object(VERIFY, "urlopen", return_value=io.BytesIO(self.content)) as download:
            result = self.prepare()
        download.assert_called_once_with(self.url, timeout=30)
        self.assertEqual(result["versionCode"], 20000)
        self.assertEqual(result["version"], "v2.0.0")
        self.assertEqual(result["zipUrl"], self.url)
        self.assertIn("/v2.0.0/changelog.md", result["changelog"])

    def test_absent_or_incomplete_assets_are_rejected(self):
        variants = [[], [self.asset, self.asset], [self.asset | {"state": "new"}], [self.asset | {"size": 0}]]
        for assets in variants:
            with self.subTest(assets=assets), self.assertRaises(ValueError):
                self.prepare(assets)

    def test_failed_or_wrong_download_never_produces_metadata(self):
        for response in [OSError("HTTP 404"), None]:
            with self.subTest(response=response), patch.object(VERIFY.time, "sleep"):
                if response is None:
                    download = lambda *_args, **_kwargs: io.BytesIO(b"wrong ZIP")
                else:
                    def download(*_args, **_kwargs):
                        raise OSError("HTTP 404")
                with patch.object(VERIFY, "urlopen", side_effect=download), self.assertRaises(RuntimeError):
                    self.prepare()


class PublishTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.remote = self.root / "remote.git"
        self.seed = self.root / "seed"
        self.checkout = self.root / "metadata"
        self.git("init", "--bare", str(self.remote))
        self.git("init", "-b", "main", str(self.seed))
        self.git("config", "user.name", "Fixture", cwd=self.seed)
        self.git("config", "user.email", "fixture@example.invalid", cwd=self.seed)
        self.git("remote", "add", "origin", str(self.remote), cwd=self.seed)
        (self.seed / "README").write_text("source content\n")
        (self.seed / "update.json").write_text(json.dumps({"versionCode": 10000}))
        self.commit_seed("Initial fixture")
        self.git("--git-dir=" + str(self.remote), "symbolic-ref", "HEAD", "refs/heads/main")
        self.git("clone", str(self.remote), str(self.checkout))
        self.metadata = self.root / "verified-update.json"
        self.metadata.write_text(json.dumps({"version": "v2.0.0", "versionCode": 20000, "zipUrl": "https://example.invalid/verified.zip"}))

    def git(self, *args, cwd=None):
        result = subprocess.run(["git", "-c", "commit.gpgsign=false", *args], cwd=cwd, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def commit_seed(self, message):
        self.git("add", ".", cwd=self.seed)
        self.git("commit", "-m", message, cwd=self.seed)
        self.git("push", "origin", "HEAD:main", cwd=self.seed)

    def publish(self):
        result = subprocess.run(["sh", str(PUBLISH), str(self.metadata), str(self.checkout), "main", "v2.0.0"], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def advertised_code(self):
        value = self.git("--git-dir=" + str(self.remote), "show", "main:update.json")
        return json.loads(value)["versionCode"]

    def test_preserves_new_source_commits_and_is_idempotent(self):
        (self.seed / "new-source").write_text("arrived during release")
        self.commit_seed("Source advanced")
        self.publish()
        self.assertEqual(self.advertised_code(), 20000)
        self.assertEqual(self.git("--git-dir=" + str(self.remote), "show", "main:new-source"), "arrived during release")
        before = self.git("--git-dir=" + str(self.remote), "rev-parse", "main")
        self.publish()
        self.assertEqual(before, self.git("--git-dir=" + str(self.remote), "rev-parse", "main"))

    def test_does_not_downgrade_a_newer_release(self):
        (self.seed / "update.json").write_text(json.dumps({"versionCode": 30000}))
        self.commit_seed("Newer release advertised")
        self.publish()
        self.assertEqual(self.advertised_code(), 30000)

    def test_creates_metadata_for_first_release(self):
        (self.seed / "update.json").unlink()
        self.commit_seed("No release yet")
        self.publish()
        self.assertEqual(self.advertised_code(), 20000)

    def test_retries_when_branch_advances_during_push(self):
        hook = self.checkout / ".git/hooks/pre-push"
        marker = self.root / "raced"
        hook.write_text(
            '#!/bin/sh\nset -e\nif [ ! -e ' + shlex.quote(str(marker)) + ' ]; then\n'
            'touch ' + shlex.quote(str(marker)) + '\n'
            'printf raced > ' + shlex.quote(str(self.seed / "race-source")) + '\n'
            'git -C ' + shlex.quote(str(self.seed)) + ' add race-source\n'
            'git -C ' + shlex.quote(str(self.seed)) + ' -c commit.gpgsign=false commit -m race\n'
            'git -C ' + shlex.quote(str(self.seed)) + ' push origin HEAD:main\nfi\n'
        )
        hook.chmod(0o755)
        self.publish()
        self.assertTrue(marker.exists())
        self.assertEqual(self.advertised_code(), 20000)
        self.assertEqual(self.git("--git-dir=" + str(self.remote), "show", "main:race-source"), "raced")


if __name__ == "__main__":
    unittest.main()
