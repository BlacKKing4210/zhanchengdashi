#!/usr/bin/env bash
# Synchronous systemd ExecStop bridge for the Godot dedicated server.
#
# The runtime owns cleanup of its shutdown session and all authoritative locks.
# This helper only publishes one no-replace request, waits for MAINPID to exit,
# and verifies the runtime-authenticated result.
set -Eeuo pipefail

readonly EXIT_IO=74
readonly EXIT_CONFIG=78
readonly SESSION_NAME='junglelaw-server.shutdown'
readonly READY_NAME='ready.json'
readonly REQUEST_NAME='request.json'
readonly OWNER_NAME='owner_token'
readonly RESULT_NAME='junglelaw-server.shutdown-result.json'

log() {
	printf 'junglelaw-server-stop: %s\n' "$*" >&2
}

fail_config() {
	log "$*"
	exit "${EXIT_CONFIG}"
}

fail_io() {
	log "$*"
	exit "${EXIT_IO}"
}

control_root="${ZHANCHENG_SHUTDOWN_CONTROL_ROOT:-}"
main_pid="${1:-${MAINPID:-}}"
python_bin="${ZHANCHENG_SHUTDOWN_PYTHON_BIN:-/usr/bin/python3}"
wait_seconds="${ZHANCHENG_SHUTDOWN_WAIT_SECONDS:-30}"
ready_wait_seconds="${ZHANCHENG_SHUTDOWN_READY_WAIT_SECONDS:-5}"
poll_seconds="${ZHANCHENG_SHUTDOWN_POLL_SECONDS:-0.10}"

[[ -n "${control_root}" ]] || fail_config 'ZHANCHENG_SHUTDOWN_CONTROL_ROOT is required'
[[ "${control_root}" == /* && "${control_root}" != '/' ]] || fail_config 'shutdown control root must be an absolute non-root path'
[[ "${main_pid}" =~ ^[0-9]+$ && "${main_pid}" -gt 1 ]] || fail_config 'MAINPID must be a positive process id greater than 1'
[[ "${wait_seconds}" =~ ^[0-9]+$ && "${wait_seconds}" -ge 1 && "${wait_seconds}" -le 120 ]] || fail_config 'shutdown wait must be an integer from 1 through 120 seconds'
[[ "${ready_wait_seconds}" =~ ^[0-9]+$ && "${ready_wait_seconds}" -ge 1 && "${ready_wait_seconds}" -le 30 ]] || fail_config 'ready wait must be an integer from 1 through 30 seconds'
[[ "${poll_seconds}" =~ ^(0\.[0-9]+|[1-9][0-9]*(\.[0-9]+)?)$ ]] || fail_config 'shutdown poll interval must be a positive decimal number'
[[ -x "${python_bin}" ]] || fail_config "required JSON helper is not executable: ${python_bin}"

session_path="${control_root}/${SESSION_NAME}"
ready_path="${session_path}/${READY_NAME}"
request_path="${session_path}/${REQUEST_NAME}"
owner_path="${session_path}/${OWNER_NAME}"
result_path="${control_root}/${RESULT_NAME}"
result_previous_path="${result_path}.previous"

process_is_running() {
	local stat_line rest process_state
	if [[ ! -r "/proc/${main_pid}/stat" ]]; then
		return 1
	fi
	IFS= read -r stat_line < "/proc/${main_pid}/stat" || return 1
	rest="${stat_line##*) }"
	process_state="${rest%% *}"
	if [[ "${process_state}" == 'Z' || "${process_state}" == 'X' ]]; then
		return 1
	fi
	kill -0 "${main_pid}" 2>/dev/null
}

process_is_running || fail_io "MAINPID ${main_pid} is not running before shutdown request"

ready_deadline=$((SECONDS + ready_wait_seconds))
while [[ ! -e "${session_path}" || ! -e "${owner_path}" || ! -e "${ready_path}" ]]; do
	process_is_running || fail_io "MAINPID ${main_pid} exited before publishing shutdown readiness"
	if (( SECONDS >= ready_deadline )); then
		fail_config "timed out waiting for the authenticated shutdown ready files for MAINPID ${main_pid}"
	fi
	sleep "${poll_seconds}"
done

set +e
owner_token="$("${python_bin}" - "${control_root}" "${session_path}" "${owner_path}" "${ready_path}" "${request_path}" "${main_pid}" <<'PY'
import json
import os
import re
import secrets
import stat
import sys
import time

EXIT_IO = 74
EXIT_CONFIG = 78
MAX_BYTES = 4096
TOKEN_PATTERN = re.compile(r"[0-9a-fA-F]{64}")


def fail(code, message):
    print(f"junglelaw-server-stop: {message}", file=sys.stderr)
    raise SystemExit(code)


def secure_directory(path, label, exact_mode=None, allow_group=False):
    try:
        info = os.lstat(path)
    except OSError as exc:
        fail(EXIT_CONFIG, f"{label} is unavailable: {exc}")
    if not stat.S_ISDIR(info.st_mode) or stat.S_ISLNK(info.st_mode):
        fail(EXIT_CONFIG, f"{label} must be a real directory")
    if info.st_uid != os.geteuid():
        fail(EXIT_CONFIG, f"{label} must be owned by the service user")
    permissions = stat.S_IMODE(info.st_mode)
    if exact_mode is not None and permissions != exact_mode:
        fail(EXIT_CONFIG, f"{label} mode must be {exact_mode:04o}, got {permissions:04o}")
    if allow_group:
        if permissions & 0o007 or permissions & 0o700 != 0o700:
            fail(EXIT_CONFIG, f"{label} must be owner-accessible and grant no other access")
    elif permissions & 0o077:
        fail(EXIT_CONFIG, f"{label} must not grant group or other access")
    return info


def secure_file(path, label, allow_group=False):
    descriptor = None
    try:
        flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
        descriptor = os.open(path, flags)
        info = os.fstat(descriptor)
    except OSError as exc:
        fail(EXIT_CONFIG, f"{label} is unavailable: {exc}")
    if not stat.S_ISREG(info.st_mode):
        os.close(descriptor)
        fail(EXIT_CONFIG, f"{label} must be a regular non-symlink file")
    if info.st_uid != os.geteuid():
        os.close(descriptor)
        fail(EXIT_CONFIG, f"{label} must be owned by the service user")
    permissions = stat.S_IMODE(info.st_mode)
    if allow_group:
        if permissions & 0o007 or permissions & 0o010 or permissions & 0o700 != 0o600:
            os.close(descriptor)
            fail(EXIT_CONFIG, f"{label} must be owner-readable/writable, non-executable, and grant no other access")
    elif permissions & 0o077:
        os.close(descriptor)
        fail(EXIT_CONFIG, f"{label} must not grant group or other access")
    if info.st_size <= 0 or info.st_size > MAX_BYTES:
        os.close(descriptor)
        fail(EXIT_CONFIG, f"{label} size is outside the accepted range")
    try:
        payload = b""
        while len(payload) <= MAX_BYTES:
            chunk = os.read(descriptor, min(1024, MAX_BYTES + 1 - len(payload)))
            if not chunk:
                break
            payload += chunk
    except OSError as exc:
        os.close(descriptor)
        fail(EXIT_CONFIG, f"cannot read {label}: {exc}")
    os.close(descriptor)
    if len(payload) > MAX_BYTES:
        fail(EXIT_CONFIG, f"{label} exceeds {MAX_BYTES} bytes")
    return payload


def parse_ready(payload, expected_pid):
    try:
        decoded = payload.decode("utf-8")
        value = json.loads(decoded)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        fail(EXIT_CONFIG, f"ready JSON is invalid: {exc}")
    required = {"version", "state", "pid", "token", "started_at_unix"}
    if type(value) is not dict or set(value) != required:
        fail(EXIT_CONFIG, "ready JSON does not have the fixed contract fields")
    if type(value["version"]) is not int or value["version"] != 1:
        fail(EXIT_CONFIG, "ready JSON version must be integer 1")
    if value["state"] != "ready":
        fail(EXIT_CONFIG, "ready JSON state must be ready")
    if type(value["pid"]) is not int or value["pid"] != expected_pid:
        fail(EXIT_CONFIG, "ready JSON pid does not match MAINPID")
    token = value["token"]
    if type(token) is not str or TOKEN_PATTERN.fullmatch(token) is None:
        fail(EXIT_CONFIG, "ready JSON token must be exactly 64 hexadecimal characters")
    if type(value["started_at_unix"]) is not int or value["started_at_unix"] <= 0:
        fail(EXIT_CONFIG, "ready JSON started_at_unix must be a positive integer")
    return value["pid"], token


def write_request_no_replace(path, session, root, pid, token):
    try:
        os.lstat(path)
    except FileNotFoundError:
        pass
    except OSError as exc:
        fail(EXIT_IO, f"cannot inspect shutdown request path: {exc}")
    else:
        fail(EXIT_IO, "shutdown request already exists; refusing to replace it")

    payload = {
        "version": 1,
        "action": "shutdown",
        "pid": pid,
        "token": token,
        "requested_at_unix": int(time.time()),
    }
    encoded = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
    temp_path = os.path.join(root, f".junglelaw-server.shutdown-request.{pid}.{secrets.token_hex(12)}.tmp")
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
    descriptor = None
    root_descriptor = None
    session_descriptor = None
    committed = False
    try:
        directory_flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
        root_descriptor = os.open(root, directory_flags)
        session_descriptor = os.open(session, directory_flags)
        descriptor = os.open(temp_path, flags, 0o600)
        view = memoryview(encoded)
        while view:
            written = os.write(descriptor, view)
            if written <= 0:
                raise OSError("short write")
            view = view[written:]
        os.fsync(descriptor)
        os.close(descriptor)
        descriptor = None
        try:
            os.link(temp_path, path, follow_symlinks=False)
        except FileExistsError:
            fail(EXIT_IO, "shutdown request appeared concurrently; refusing to replace it")
        committed = True
        try:
            os.fsync(session_descriptor)
        except OSError as exc:
            print(f"junglelaw-server-stop: warning: request is committed but session fsync failed: {exc}", file=sys.stderr)
    except SystemExit:
        raise
    except OSError as exc:
        if committed:
            print(f"junglelaw-server-stop: warning: request is committed; continuing after post-commit failure: {exc}", file=sys.stderr)
        else:
            fail(EXIT_IO, f"cannot publish shutdown request: {exc}")
    finally:
        if descriptor is not None:
            try:
                os.close(descriptor)
            except OSError:
                pass
        try:
            os.unlink(temp_path)
            if root_descriptor is not None:
                os.fsync(root_descriptor)
        except FileNotFoundError:
            pass
        except OSError as exc:
            print(f"junglelaw-server-stop: warning: cannot remove owned request temp file: {exc}", file=sys.stderr)
        if session_descriptor is not None:
            try:
                os.close(session_descriptor)
            except OSError:
                pass
        if root_descriptor is not None:
            try:
                os.close(root_descriptor)
            except OSError:
                pass


def main():
    if len(sys.argv) != 7:
        fail(EXIT_CONFIG, "internal request helper arguments are invalid")
    root, session, owner_path, ready_path, request_path, expected_pid_text = sys.argv[1:]
    try:
        expected_pid = int(expected_pid_text)
    except ValueError:
        fail(EXIT_CONFIG, "MAINPID is not an integer")
    secure_directory(root, "shutdown control root", 0o700)
    secure_directory(session, "shutdown session", allow_group=True)
    owner_payload = secure_file(owner_path, "shutdown owner token", allow_group=True)
    ready_payload = secure_file(ready_path, "shutdown ready file", allow_group=True)
    try:
        owner_token = owner_payload.decode("ascii")
    except UnicodeDecodeError:
        fail(EXIT_CONFIG, "shutdown owner token is not ASCII")
    if TOKEN_PATTERN.fullmatch(owner_token) is None:
        fail(EXIT_CONFIG, "shutdown owner token must be exactly 64 hexadecimal characters")
    ready_pid, ready_token = parse_ready(ready_payload, expected_pid)
    if owner_token != ready_token:
        fail(EXIT_CONFIG, "shutdown owner and ready tokens do not match")
    try:
        os.kill(expected_pid, 0)
    except OSError as exc:
        fail(EXIT_IO, f"MAINPID is not running before request commit: {exc}")
    write_request_no_replace(request_path, session, root, ready_pid, ready_token)
    print(ready_token)


try:
    main()
except SystemExit:
    raise
except Exception as exc:
    fail(EXIT_IO, f"unexpected request helper failure: {exc}")
PY
)"
request_status=$?
set -e
if [[ "${request_status}" -ne 0 ]]; then
	if [[ "${request_status}" -eq "${EXIT_CONFIG}" || "${request_status}" -eq "${EXIT_IO}" ]]; then
		exit "${request_status}"
	fi
	fail_io "request helper exited with unexpected status ${request_status}"
fi
[[ "${owner_token}" =~ ^[0-9a-fA-F]{64}$ ]] || fail_io 'request helper returned an invalid owner token'

log "shutdown request committed for MAINPID ${main_pid}; waiting up to ${wait_seconds}s"
deadline=$((SECONDS + wait_seconds))
while process_is_running; do
	if (( SECONDS >= deadline )); then
		fail_io "timed out waiting for MAINPID ${main_pid} to exit; request and authority state were left untouched"
	fi
	sleep "${poll_seconds}"
done

set +e
"${python_bin}" - "${control_root}" "${session_path}" "${result_path}" "${result_previous_path}" "${main_pid}" "${owner_token}" <<'PY'
import json
import os
import re
import stat
import sys

EXIT_IO = 74
MAX_BYTES = 4096
TOKEN_PATTERN = re.compile(r"[0-9a-fA-F]{64}")


def fail(message):
    print(f"junglelaw-server-stop: {message}", file=sys.stderr)
    raise SystemExit(EXIT_IO)


def main():
    if len(sys.argv) != 7:
        fail("internal result helper arguments are invalid")
    root, session, result_path, previous_path, expected_pid_text, expected_token = sys.argv[1:]
    try:
        expected_pid = int(expected_pid_text)
    except ValueError:
        fail("expected pid is invalid")
    if TOKEN_PATTERN.fullmatch(expected_token) is None:
        fail("expected token is invalid")

    try:
        root_info = os.lstat(root)
    except OSError as exc:
        fail(f"shutdown control root disappeared before result validation: {exc}")
    if not stat.S_ISDIR(root_info.st_mode) or stat.S_ISLNK(root_info.st_mode):
        fail("shutdown control root is not a real directory")
    if root_info.st_uid != os.geteuid() or stat.S_IMODE(root_info.st_mode) != 0o700:
        fail("shutdown control root ownership or mode changed during shutdown")

    try:
        os.lstat(session)
    except FileNotFoundError:
        pass
    except OSError as exc:
        fail(f"cannot inspect released shutdown session: {exc}")
    else:
        fail("runtime exited without releasing its shutdown session")

    try:
        os.lstat(previous_path)
    except FileNotFoundError:
        pass
    except OSError as exc:
        fail(f"cannot inspect shutdown result previous path: {exc}")
    else:
        fail("shutdown result previous file remains; success is ambiguous")

    descriptor = None
    try:
        flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
        descriptor = os.open(result_path, flags)
        info = os.fstat(descriptor)
    except OSError as exc:
        fail(f"shutdown result is unavailable: {exc}")
    if not stat.S_ISREG(info.st_mode):
        os.close(descriptor)
        fail("shutdown result must be a regular non-symlink file")
    permissions = stat.S_IMODE(info.st_mode)
    if (
        info.st_uid != os.geteuid()
        or permissions & 0o007
        or permissions & 0o010
        or permissions & 0o700 != 0o600
    ):
        os.close(descriptor)
        fail("shutdown result ownership or permissions are unsafe")
    if info.st_size <= 0 or info.st_size > MAX_BYTES:
        os.close(descriptor)
        fail("shutdown result size is outside the accepted range")
    try:
        payload = b""
        while len(payload) <= MAX_BYTES:
            chunk = os.read(descriptor, min(1024, MAX_BYTES + 1 - len(payload)))
            if not chunk:
                break
            payload += chunk
        os.close(descriptor)
        descriptor = None
        decoded = payload.decode("utf-8")
        value = json.loads(decoded)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        if descriptor is not None:
            try:
                os.close(descriptor)
            except OSError:
                pass
        fail(f"shutdown result JSON is invalid: {exc}")
    required = {"version", "pid", "token", "ok", "exit_code", "reason", "completed_at_unix"}
    if type(value) is not dict or set(value) != required:
        fail("shutdown result does not have the fixed contract fields")
    if type(value["version"]) is not int or value["version"] != 1:
        fail("shutdown result version must be integer 1")
    if type(value["pid"]) is not int or value["pid"] != expected_pid:
        fail("shutdown result pid does not match MAINPID")
    if value["token"] != expected_token:
        fail("shutdown result token does not match the ready token")
    if type(value["ok"]) is not bool or value["ok"] is not True:
        fail("shutdown result ok must be true")
    if type(value["exit_code"]) is not int or value["exit_code"] != 0:
        fail("shutdown result exit_code must be integer 0")
    if value["reason"] != "graceful_shutdown_complete":
        fail("shutdown result reason is not graceful_shutdown_complete")
    if type(value["completed_at_unix"]) is not int or value["completed_at_unix"] <= 0:
        fail("shutdown result completed_at_unix must be a positive integer")


try:
    main()
except SystemExit:
    raise
except Exception as exc:
    fail(f"unexpected result helper failure: {exc}")
PY
result_status=$?
set -e
if [[ "${result_status}" -ne 0 ]]; then
	if [[ "${result_status}" -eq "${EXIT_IO}" ]]; then
		exit "${result_status}"
	fi
	fail_io "result helper exited with unexpected status ${result_status}"
fi

log "graceful shutdown authenticated for MAINPID ${main_pid}"
exit 0
