#!/usr/bin/env python3
"""Fault tests for the synchronous dedicated-server systemd stop helper."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest


TOKEN_A = "a" * 64
TOKEN_B = "b" * 64
SESSION_NAME = "junglelaw-server.shutdown"
RESULT_NAME = "junglelaw-server.shutdown-result.json"


FAKE_RUNTIME = r'''
import json
import os
from pathlib import Path
import sys
import time

root = Path(sys.argv[1])
token = sys.argv[2]
mode = sys.argv[3]
startup_delay = float(sys.argv[4])
session = root / "junglelaw-server.shutdown"
RESULT_NAME = "junglelaw-server.shutdown-result.json"
result_path = root / "junglelaw-server.shutdown-result.json"

time.sleep(startup_delay)
session.mkdir(mode=0o770)
os.chmod(str(session), 0o770)

def write_file(path, content, permissions=0o660):
    descriptor = os.open(str(path), os.O_WRONLY | os.O_CREAT | os.O_EXCL, permissions)
    try:
        data = content.encode("utf-8")
        while data:
            written = os.write(descriptor, data)
            data = data[written:]
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    os.chmod(str(path), permissions)

write_file(session / "owner_token", token)
write_file(
    session / "ready.json",
    json.dumps({
        "version": 1,
        "state": "ready",
        "pid": os.getpid(),
        "token": token,
        "started_at_unix": int(time.time()),
    }, separators=(",", ":")),
)
write_file(root / "fixture.ready", "ready", 0o600)

deadline = time.monotonic() + 15.0
request_path = session / "request.json"
while not request_path.exists() and time.monotonic() < deadline:
    time.sleep(0.01)
if not request_path.exists():
    raise SystemExit(89)
if mode == "timeout":
    time.sleep(30.0)

request = json.loads(request_path.read_text(encoding="utf-8"))
if set(request) != {"version", "action", "pid", "token", "requested_at_unix"}:
    raise SystemExit(90)
if request["version"] != 1 or request["action"] != "shutdown":
    raise SystemExit(91)
if request["pid"] != os.getpid() or request["token"] != token:
    raise SystemExit(92)

for name in ("request.json", "ready.json", "owner_token"):
    (session / name).unlink()
session.rmdir()

if mode == "no_result":
    raise SystemExit(0)

result_token = "b" * 64 if mode == "wrong_token" else token
ok = mode != "failed_result"
exit_code = 0 if ok else 74
reason = "graceful_shutdown_complete" if ok else "transport_close_failed"
payload = json.dumps({
    "version": 1,
    "pid": os.getpid(),
    "token": result_token,
    "ok": ok,
    "exit_code": exit_code,
    "reason": reason,
    "completed_at_unix": int(time.time()),
}, separators=(",", ":"))

temporary_path = root / (RESULT_NAME + ".fixture.tmp")
if temporary_path.exists():
    temporary_path.unlink()
write_file(temporary_path, payload)
os.replace(str(temporary_path), str(result_path))
os.chmod(str(result_path), 0o660)
if mode == "ambiguous_previous":
    write_file(Path(str(result_path) + ".previous"), payload)
raise SystemExit(0)
'''


class StopHelperTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.helper = Path(__file__).with_name("junglelaw-server-stop.sh").resolve()
        if not cls.helper.is_file():
            raise RuntimeError("stop helper is missing: {}".format(cls.helper))

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="junglelaw-stop-test-")
        self.base = Path(self.temporary.name)
        self.root = self.base / "control"
        self.root.mkdir(mode=0o700)
        os.chmod(str(self.root), 0o700)
        self.processes = []
        self.sentinels = self._create_sentinels()

    def tearDown(self):
        for process in reversed(self.processes):
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=2)
            else:
                process.wait(timeout=2)
        self.temporary.cleanup()

    @staticmethod
    def _write(path, content, permissions=0o660):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        os.chmod(str(path), permissions)

    def _create_sentinels(self):
        authority = self.base / "authority" / "player_accounts.json.write_lock" / "owner_token"
        foreign = self.root / "foreign-control-lock" / "owner_token"
        self._write(authority, "authority-must-remain", 0o600)
        self._write(foreign, "foreign-control-must-remain", 0o600)
        return {
            authority: (authority.read_bytes(), os.stat(str(authority)).st_mode & 0o777),
            foreign: (foreign.read_bytes(), os.stat(str(foreign)).st_mode & 0o777),
        }

    def _assert_sentinels_untouched(self):
        for path, expected in self.sentinels.items():
            self.assertTrue(path.is_file(), "sentinel disappeared: {}".format(path))
            actual = (path.read_bytes(), os.stat(str(path)).st_mode & 0o777)
            self.assertEqual(expected, actual, "sentinel changed: {}".format(path))

    def _start_sleep(self):
        process = subprocess.Popen(["/usr/bin/sleep", "60"])
        self.processes.append(process)
        return process

    def _start_fake(self, mode="success", startup_delay=0.0, wait_ready=True):
        process = subprocess.Popen([
            sys.executable,
            "-c",
            FAKE_RUNTIME,
            str(self.root),
            TOKEN_A,
            mode,
            str(startup_delay),
        ])
        self.processes.append(process)
        if not wait_ready:
            return process
        marker = self.root / "fixture.ready"
        deadline = time.monotonic() + 4.0
        while not marker.exists() and time.monotonic() < deadline:
            if process.poll() is not None:
                self.fail("fake runtime exited before readiness with {}".format(process.returncode))
            time.sleep(0.01)
        self.assertTrue(marker.is_file(), "fake runtime did not publish fixture readiness")
        return process

    def _prepare_manual(self, pid, ready_token=TOKEN_A, owner_token=TOKEN_A, extra_ready=False):
        session = self.root / SESSION_NAME
        session.mkdir(mode=0o770)
        os.chmod(str(session), 0o770)
        self._write(session / "owner_token", owner_token)
        ready = {
            "version": 1,
            "state": "ready",
            "pid": pid,
            "token": ready_token,
            "started_at_unix": int(time.time()),
        }
        if extra_ready:
            ready["unexpected"] = True
        self._write(session / "ready.json", json.dumps(ready, separators=(",", ":")))
        return session

    def _run_helper(self, pid, wait_seconds="2", ready_wait_seconds="2", python_bin=None):
        environment = os.environ.copy()
        environment.update({
            "ZHANCHENG_SHUTDOWN_CONTROL_ROOT": str(self.root),
            "ZHANCHENG_SHUTDOWN_WAIT_SECONDS": wait_seconds,
            "ZHANCHENG_SHUTDOWN_READY_WAIT_SECONDS": ready_wait_seconds,
            "ZHANCHENG_SHUTDOWN_POLL_SECONDS": "0.05",
            "ZHANCHENG_SHUTDOWN_PYTHON_BIN": python_bin or sys.executable,
        })
        return subprocess.run(
            ["/usr/bin/bash", str(self.helper), str(pid)],
            env=environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
            timeout=8,
        )

    def test_success_with_group_writable_runtime_files_and_delayed_ready(self):
        process = self._start_fake("success", startup_delay=0.35, wait_ready=False)
        result = self._run_helper(process.pid)
        self.assertEqual(0, result.returncode, result.stderr)
        process.wait(timeout=2)
        self.assertFalse((self.root / SESSION_NAME).exists())
        self.assertTrue((self.root / RESULT_NAME).is_file())
        self.assertFalse(list(self.root.glob(".junglelaw-server.shutdown-request.*.tmp")))
        self._assert_sentinels_untouched()

    def test_invalid_ready_token_is_config_failure_without_request(self):
        process = self._start_sleep()
        session = self._prepare_manual(process.pid, ready_token=TOKEN_B)
        result = self._run_helper(process.pid)
        self.assertEqual(78, result.returncode, result.stderr)
        self.assertFalse((session / "request.json").exists())
        self._assert_sentinels_untouched()

    def test_extra_ready_field_is_rejected(self):
        process = self._start_sleep()
        session = self._prepare_manual(process.pid, extra_ready=True)
        result = self._run_helper(process.pid)
        self.assertEqual(78, result.returncode, result.stderr)
        self.assertFalse((session / "request.json").exists())
        self._assert_sentinels_untouched()

    def test_existing_request_is_not_replaced(self):
        process = self._start_sleep()
        session = self._prepare_manual(process.pid)
        request = session / "request.json"
        original = b"preexisting-request-must-remain"
        request.write_bytes(original)
        os.chmod(str(request), 0o660)
        result = self._run_helper(process.pid)
        self.assertEqual(74, result.returncode, result.stderr)
        self.assertEqual(original, request.read_bytes())
        self._assert_sentinels_untouched()

    def test_timeout_leaves_committed_request_and_locks(self):
        process = self._start_fake("timeout")
        result = self._run_helper(process.pid, wait_seconds="1")
        self.assertEqual(74, result.returncode, result.stderr)
        self.assertIsNone(process.poll(), "helper must not kill the main process")
        self.assertTrue((self.root / SESSION_NAME / "request.json").is_file())
        self._assert_sentinels_untouched()

    def test_wrong_result_token_is_io_failure(self):
        process = self._start_fake("wrong_token")
        result = self._run_helper(process.pid)
        self.assertEqual(74, result.returncode, result.stderr)
        process.wait(timeout=2)
        self._assert_sentinels_untouched()

    def test_failed_result_is_io_failure(self):
        process = self._start_fake("failed_result")
        result = self._run_helper(process.pid)
        self.assertEqual(74, result.returncode, result.stderr)
        process.wait(timeout=2)
        self._assert_sentinels_untouched()

    def test_success_result_with_previous_file_is_ambiguous_failure(self):
        process = self._start_fake("ambiguous_previous")
        result = self._run_helper(process.pid)
        self.assertEqual(74, result.returncode, result.stderr)
        process.wait(timeout=2)
        self.assertTrue(Path(str(self.root / RESULT_NAME) + ".previous").is_file())
        self._assert_sentinels_untouched()

    def test_missing_python_is_config_failure(self):
        process = self._start_sleep()
        session = self._prepare_manual(process.pid)
        result = self._run_helper(process.pid, python_bin="/definitely/missing/python3")
        self.assertEqual(78, result.returncode, result.stderr)
        self.assertFalse((session / "request.json").exists())
        self._assert_sentinels_untouched()


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(StopHelperTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)
