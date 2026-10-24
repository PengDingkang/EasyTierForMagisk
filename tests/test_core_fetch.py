"""Reject tampered or incompatible release assets without replacing tools."""
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/ci/fetch-core.sh"


class FetchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.cache = self.root / ".cache/core"
        self.cache.mkdir(parents=True)
        (self.root / "CORE_VERSION").write_text("v2.6.4\n")
        self.archive = self.cache / "easytier-linux-aarch64-v2.6.4.zip"
        with zipfile.ZipFile(self.archive, "w") as zipped:
            zipped.writestr("release/easytier-core", b"not an ARM64 ELF")
            zipped.writestr("release/easytier-cli", b"not an ARM64 ELF")
        self.digest = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        (self.root / "CORE_ASSET_SHA256").write_text(self.digest + "\n")
        for name in ("easytier-core", "easytier-cli"):
            (self.root / name).write_text("existing tool")
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        curl = bin_dir / "curl"
        curl.write_text(
            '#!/bin/sh\nwhile [ "$#" -gt 0 ]; do\n'
            'if [ "$1" = --output ]; then cp "$TEST_DOWNLOAD" "$2"; exit; fi\n'
            'shift\ndone\nexit 1\n'
        )
        curl.chmod(0o755)
        self.env = os.environ | {
            "ET_CORE_WORKSPACE": str(self.root),
            "TEST_DOWNLOAD": str(self.archive),
            "PATH": str(bin_dir) + os.pathsep + os.environ["PATH"],
        }

    def run_fetch(self):
        return subprocess.run(["sh", str(SCRIPT)], env=self.env, capture_output=True, text=True, timeout=10)

    def assert_tools_preserved(self):
        for name in ("easytier-core", "easytier-cli"):
            self.assertEqual((self.root / name).read_text(), "existing tool")

    def test_bad_checksum_is_rejected_before_extraction(self):
        (self.root / "CORE_ASSET_SHA256").write_text("0" * 64 + "\n")
        result = self.run_fetch()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("SHA256 mismatch", result.stderr)
        self.assert_tools_preserved()

    def test_valid_checksum_with_wrong_architecture_is_rejected(self):
        result = self.run_fetch()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("architecture or linkage", result.stderr)
        self.assert_tools_preserved()

    def test_invalid_version_does_not_download(self):
        (self.root / "CORE_VERSION").write_text("latest\n")
        result = self.run_fetch()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Invalid CORE_VERSION", result.stderr)
        self.assert_tools_preserved()


if __name__ == "__main__":
    unittest.main()
