"""Service lifecycle must preserve WireGuard and other modules' policy rules."""
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RoutingTests(unittest.TestCase):
    def run_service(self, failed=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            props = (ROOT / "module.prop").read_text()
            wrapper = "easytier" if "id=EasyTierForMagisk\n" in props else "zerotier"
            binary = "easytier-core" if wrapper == "easytier" else "zerotier-one"
            peer_priority = 1002 if wrapper == "easytier" else 1001
            original = [1, peer_priority]
            (root / "rules.json").write_text(json.dumps(original))
            (root / "config").mkdir()
            (root / "config/config.toml").write_text('instance_name = "fixture"\n')
            core = root / binary
            core.write_text("#!/bin/sh\nexit 0\n")
            core.chmod(0o755)
            source = (ROOT / wrapper).read_text().split('\ncase "$1" in\n', 1)[0]
            source = re.sub(r"(?m)^path=.*$", "path=" + shlex.quote(str(root)), source)
            (root / "functions.sh").write_text(source)
            fake_ip = root / "ip.py"
            fake_ip.write_text('''import json, os, sys
from pathlib import Path
p = Path(os.environ["RULE_STATE"])
args = sys.argv[1:]
if args[:1] != ["rule"]: sys.exit(0)
priority = int(args[args.index("pref") + 1])
rules = json.loads(p.read_text())
if args[1] == "add":
    if priority in rules: sys.exit(2)
    rules.append(priority)
elif args[1] == "del":
    if priority not in rules: sys.exit(2)
    rules.remove(priority)
p.write_text(json.dumps(rules))
''')
            driver = '''. "$1/functions.sh"
hostname() { :; }
sleep() { :; }
kill() { :; }
killall() { :; }
ip() { python3 "$FAKE_IP" "$@"; }
checks=0
bin_status() {
  checks=$((checks + 1))
  [ "$FAIL_START" = 0 ] || return 1
  case "$checks" in 2|3) return 0 ;; *) return 1 ;; esac
}
start_service
cp "$RULE_STATE" "$AFTER_START"
stop_service
'''
            env = dict(os.environ, FAKE_IP=str(fake_ip), RULE_STATE=str(root / "rules.json"), AFTER_START=str(root / "started.json"), FAIL_START="1" if failed else "0")
            result = subprocess.run(["sh", "-c", driver, "sh", str(root)], env=env, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            started = json.loads((root / "started.json").read_text())
            stopped = json.loads((root / "rules.json").read_text())
            return original, started, stopped

    def test_stopping_preserves_wireguard_and_other_module(self):
        original, started, stopped = self.run_service()
        self.assertTrue(set(original).issubset(started), "Start removed another module's rule")
        self.assertEqual(len(started), len(original) + 1, "Service needs an independent rule")
        self.assertEqual(stopped, original, "Stop removed WireGuard or another module's rule")

    def test_failed_start_does_not_change_rules(self):
        original, started, stopped = self.run_service(failed=True)
        self.assertEqual(started, original)
        self.assertEqual(stopped, original)


if __name__ == "__main__":
    unittest.main()
