#!/usr/bin/env python3
"""Exercise deployment failure boundaries without touching hosts or caches."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("deploy.nu")
REVISION = "a" * 40
SYSTEM = "/nix/store/" + "b" * 32 + "-nixos-system-us-1-test"
FIXTURE = r'''
import json
import os
from pathlib import Path
import sys
import subprocess

command = Path(sys.argv[0]).name
args = sys.argv[1:]
state = Path(os.environ["FIXTURE_STATE"])
case = os.environ["FIXTURE_CASE"]
with (state / "calls").open("a") as stream:
    stream.write(json.dumps([command, *args]) + "\n")
def output(host):
    return "/nix/store/" + "b" * 32 + "-nixos-system-" + host + "-test"

system = output("us-1")
if command == "git":
    if args[0] == "init":
        Path(args[-1]).mkdir(parents=True, exist_ok=True)
elif command == "gh":
    if args[:2] == ["run", "list"]:
        print('[{"databaseId": 1}]')
    elif args[:2] == ["run", "download"]:
        destination = Path(args[args.index("--dir") + 1])
        destination.mkdir(parents=True)
        host = args[args.index("--name") + 1].removeprefix("deploy-")
        (destination / "deployment.json").write_text(json.dumps({
            "revision": "a" * 40, "host": host, "system": output(host)
        }))
    elif args[0] == "api" and args[1].endswith("/jobs"):
        print(json.dumps({"jobs": [{"name": name, "conclusion": "success"} for name in ["Nix Flake Check", "Build us-1 (test)", "Build us-2 (test)"]]}))
    elif args[0] == "api":
        print(json.dumps({"artifacts": [
            {"name": "deploy-us-1", "expired": False},
            {"name": "deploy-us-2", "expired": False}
        ]}))
elif command == "nix-store":
    if case == "cache-miss":
        sys.stderr.write("substitute unavailable\n")
        sys.exit(1)
    assert "--option" in args and "max-jobs" in args and "builders" in args
elif command == "nix":
    if args[:2] == ["store", "verify"]:
        if case == "missing-signature" and not (state / "signed").exists():
            sys.exit(2)
    elif args[:2] == ["store", "copy-sigs"]:
        (state / "signed").touch()
    else:
        print(json.dumps({args[-1]: {"narSize": 100}}))
elif command == "colmena":
    if "eval" in args:
        print(json.dumps({host: output(host) + ("-wrong" if case == "mismatch" else "") for host in ["us-1", "us-2"]}))
    else:
        assert "--no-build-on-target" in args
        (state / args[args.index("--on") + 1]).touch()
elif command == "timeout":
    if args[1] != "ssh":
        sys.exit(subprocess.run(args[1:]).returncode)
    script = sys.stdin.read()
    host = "us-2" if "root@127.0.0.2" in args else "us-1"
    system = output(host)
    with (state / "scripts").open("a") as stream:
        stream.write(json.dumps([host, script]) + "\n")
    if "systemctl reboot" in script:
        (state / (host + "-booted")).touch()
    if "basename" in script:
        print("6.18.50")
    if "SERVICES" in script:
        active = (state / host).exists()
        print(system if active else "/nix/store/" + "c" * 32 + "-old")
        print("boot-after" if (state / (host + "-booted")).exists() else "boot-before")
        print("6.18.50")
        print("5000000")
        print("SERVICES")
        print("sshd.service")
        if not (active and case == "health-failure"):
            print("nginx.service")
        print("FAILED")
elif command != "curl":
    raise AssertionError(command)
'''


class DeploymentTests(unittest.TestCase):
    def deploy(self, case):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            commands = state / "bin"
            commands.mkdir()
            for name in ["git", "gh", "nix-store", "nix", "colmena", "timeout", "curl"]:
                path = commands / name
                path.write_text("#!" + sys.executable + "\n" + FIXTURE)
                path.chmod(0o755)
            config = state / "config.json"
            config.write_text(json.dumps({"caches": ["https://cache.example.invalid"], "servers": {
                host: {"name": host, "ip": "127.0.0." + host[-1], "port": 22}
                for host in ["us-1", "us-2"]
            }}))
            extra = []
            if case == "resume-after-reboot":
                extra = ["--reboot"]
                (state / "us-1").touch()
                (state / "us-1-booted").touch()
                checkpoint = state / "data" / "nixos-deploy" / REVISION
                checkpoint.mkdir(parents=True)
                (checkpoint / "us-1.json").write_text(json.dumps({
                    "profile": "/nix/store/" + "c" * 32 + "-old", "boot": "boot-before",
                    "rebootBoot": "boot-before", "services": ["sshd.service", "nginx.service"]
                }))
            result = subprocess.run(
                ["nu", str(SCRIPT), "--revision", REVISION,
                 "--on", "us-1,us-2", "--without-clash", *extra],
                env={**os.environ, "PATH": str(commands) + os.pathsep + os.environ["PATH"],
                     "XDG_STATE_HOME": str(state / "data"), "NIXOS_DEPLOY_CONFIG": str(config),
                     "FIXTURE_STATE": str(state), "FIXTURE_CASE": case},
                capture_output=True, text=True, timeout=90,
            )
            self.assertTrue((state / "calls").exists(), result.stderr)
            calls = [json.loads(line) for line in (state / "calls").read_text().splitlines()]
            scripts = [json.loads(line) for line in (state / "scripts").read_text().splitlines()] if (state / "scripts").exists() else []
            return result, calls, scripts

    def test_nested_proxy_selector_resolves_actual_node(self):
        expression = (
            'use ' + json.dumps(str(SCRIPT)) + ' selected-proxy; '
            'selected-proxy {GLOBAL: {now: PROXY}, PROXY: {now: "US-4 REALITY"}, '
            '"US-4 REALITY": {type: VLESS}} GLOBAL'
        )
        result = subprocess.run(["nu", "--no-config-file", "-c", expression],
                                capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.strip(), "US-4 REALITY")

    def test_cache_miss_never_activates(self):
        result, calls, _ = self.deploy("cache-miss")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("substitute unavailable", result.stderr)
        self.assertFalse(any("apply" in call for call in calls))

    def test_mismatched_ci_output_never_activates(self):
        result, calls, _ = self.deploy("mismatch")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("output mismatch", result.stderr)
        self.assertFalse(any("apply" in call for call in calls))

    def test_failed_health_stops_before_next_host(self):
        result, calls, _ = self.deploy("health-failure")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("nginx.service", result.stderr)
        applies = [call for call in calls if call[0] == "colmena" and "apply" in call]
        self.assertEqual(len(applies), 1)
        self.assertEqual(applies[0][applies[0].index("--on") + 1], "us-1")

    def test_matching_local_paths_gain_cache_signatures(self):
        result, calls, _ = self.deploy("missing-signature")
        self.assertEqual(result.returncode, 0, result.stderr)
        recovery = next(i for i, call in enumerate(calls) if call[:3] == ["nix", "store", "copy-sigs"])
        activation = next(i for i, call in enumerate(calls) if call[0] == "colmena" and "apply" in call)
        self.assertLess(recovery, activation)

    def test_resume_does_not_repeat_completed_reboot(self):
        result, _, scripts = self.deploy("resume-after-reboot")
        self.assertEqual(result.returncode, 0, result.stderr)
        rebooted = [host for host, script in scripts if "systemctl reboot" in script]
        self.assertEqual(rebooted, ["us-2"])

    def test_healthy_deployment_finishes(self):
        result, _, _ = self.deploy("healthy")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("us-2: expected system active", result.stdout)


if __name__ == "__main__":
    unittest.main()
