#!/usr/bin/env bash
# Local WSL/Linux candidate verification. This never installs or starts a
# persistent service and must not be presented as Alibaba Cloud evidence.
set -Eeuo pipefail

umask 0077
export LC_ALL=C.UTF-8

candidate="${1:-}"
stop_helper="${2:-}"
evidence_root="${3:-}"
positive_port="${4:-39471}"
corrupt_port="${5:-39472}"
residual_lock_port="${6:-39473}"
runtime_root=""
active_pid=""

fail() {
	printf 'candidate verification failed: %s\n' "$*" >&2
	exit 1
}

[[ -n "${candidate}" && "${candidate}" == /* ]] || fail 'candidate must be an absolute path'
[[ -n "${stop_helper}" && "${stop_helper}" == /* ]] || fail 'stop helper must be an absolute path'
[[ -n "${evidence_root}" && "${evidence_root}" == /* ]] || fail 'evidence root must be an absolute path'
[[ -f "${candidate}" ]] || fail "candidate binary is missing: ${candidate}"
[[ -f "${stop_helper}" ]] || fail "stop helper is missing: ${stop_helper}"
[[ ! -e "${evidence_root}" ]] || fail "refusing to reuse evidence root: ${evidence_root}"
candidate_realpath="$(realpath -e -- "${candidate}")" || fail "cannot resolve candidate binary: ${candidate}"

for port in "${positive_port}" "${corrupt_port}" "${residual_lock_port}"; do
	[[ "${port}" =~ ^[0-9]+$ && "${port}" -ge 1024 && "${port}" -le 65535 ]] \
		|| fail "invalid test port: ${port}"
done
[[ "${positive_port}" != "${corrupt_port}" && "${positive_port}" != "${residual_lock_port}" && "${corrupt_port}" != "${residual_lock_port}" ]] \
	|| fail 'test ports must be distinct'

process_is_running() {
	local pid="$1"
	local stat_line rest process_state
	if [[ ! -r "/proc/${pid}/stat" ]]; then
		return 1
	fi
	IFS= read -r stat_line < "/proc/${pid}/stat" || return 1
	rest="${stat_line##*) }"
	process_state="${rest%% *}"
	if [[ "${process_state}" == 'Z' || "${process_state}" == 'X' ]]; then
		return 1
	fi
	kill -0 "${pid}" 2>/dev/null
}

candidate_executable_is_running() {
	local process_exe process_realpath
	for process_exe in /proc/[0-9]*/exe; do
		process_realpath="$(readlink -f -- "${process_exe}" 2>/dev/null || true)"
		if [[ "${process_realpath}" == "${candidate_realpath}" ]]; then
			return 0
		fi
	done
	return 1
}

safe_remove_runtime() {
	if [[ -z "${runtime_root}" || ! -e "${runtime_root}" ]]; then
		return 0
	fi
	case "${runtime_root}" in
		/tmp/junglelaw-server-candidate.*)
			rm -rf -- "${runtime_root}"
			;;
		*)
			printf 'refusing to remove unexpected runtime root: %s\n' "${runtime_root}" >&2
			return 1
			;;
	esac
}

stop_active_process_for_cleanup() {
	if [[ -z "${active_pid}" ]]; then
		return 0
	fi
	if process_is_running "${active_pid}"; then
		kill -TERM "${active_pid}" 2>/dev/null || true
		for _attempt in $(seq 1 30); do
			process_is_running "${active_pid}" || break
			sleep 0.1
		done
		if process_is_running "${active_pid}"; then
			kill -KILL "${active_pid}" 2>/dev/null || true
		fi
	fi
	wait "${active_pid}" 2>/dev/null || true
	active_pid=""
}

cleanup() {
	stop_active_process_for_cleanup || true
	safe_remove_runtime || true
}
trap cleanup EXIT INT TERM

port_open() {
	ss -H -lun "sport = :$1" | grep -q .
}

assert_port_closed() {
	local port="$1"
	if port_open "${port}"; then
		printf 'UDP port %s is unexpectedly open.\n' "${port}" >&2
		return 1
	fi
}

authority_path() {
	local scenario_root="$1"
	printf '%s\n' "${scenario_root}/xdg/godot/app_userdata/丛林法则/server/player_accounts.json"
}

control_root() {
	local scenario_root="$1"
	printf '%s\n' "${scenario_root}/control"
}

prepare_scenario() {
	local scenario_root="$1"
	mkdir -p \
		"${scenario_root}/xdg" \
		"${scenario_root}/exports" \
		"${scenario_root}/commands" \
		"$(control_root "${scenario_root}")"
	chmod 0700 "$(control_root "${scenario_root}")"
}

start_candidate() {
	local scenario_root="$1"
	local port="$2"
	local log_path="$3"
	local scenario_control
	scenario_control="$(control_root "${scenario_root}")"
	(
		umask 0007
		exec env \
			XDG_DATA_HOME="${scenario_root}/xdg" \
			ZHANCHENG_BIND_HOST=127.0.0.1 \
			ZHANCHENG_SERVER_PORT="${port}" \
			ZHANCHENG_MAX_CLIENTS=4 \
			ZHANCHENG_DASHBOARD_SNAPSHOT_PATH="${scenario_root}/exports/dashboard_snapshot.json" \
			ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH="${scenario_root}/exports/admin_accounts_snapshot.json" \
			ZHANCHENG_DASHBOARD_COMMAND_ROOT="${scenario_root}/commands" \
			ZHANCHENG_SHUTDOWN_CONTROL_ROOT="${scenario_control}" \
			"${candidate}" --headless -- \
			--bind-host=127.0.0.1 \
			--server-port="${port}" \
			--max-clients=4
	) >"${log_path}" 2>&1 &
	active_pid=$!
}

wait_for_listener_and_ready() {
	local scenario_root="$1"
	local port="$2"
	local ready_path
	ready_path="$(control_root "${scenario_root}")/junglelaw-server.shutdown/ready.json"
	for _attempt in $(seq 1 150); do
		if port_open "${port}" && [[ -s "${ready_path}" ]]; then
			return 0
		fi
		process_is_running "${active_pid}" || return 1
		sleep 0.1
	done
	return 1
}

wait_for_runtime_exports() {
	local scenario_root="$1"
	local authority="$2"
	for _attempt in $(seq 1 100); do
		if [[ -s "${scenario_root}/exports/dashboard_snapshot.json" ]] \
			&& [[ -s "${scenario_root}/exports/admin_accounts_snapshot.json" ]] \
			&& [[ -s "${authority}" ]]; then
			return 0
		fi
		process_is_running "${active_pid}" || return 1
		sleep 0.1
	done
	return 1
}

scan_unexpected_script_errors() {
	local log_path="$1"
	if grep -Eq 'SCRIPT ERROR|Parse Error|Assertion failed' "${log_path}"; then
		cat "${log_path}" >&2
		return 1
	fi
}

wait_for_log_pattern() {
	local log_path="$1"
	local pattern="$2"
	for _attempt in $(seq 1 50); do
		if grep -Fq "${pattern}" "${log_path}"; then
			return 0
		fi
		process_is_running "${active_pid}" || return 1
		sleep 0.1
	done
	return 1
}

publish_rejected_request_fixture() {
	local scenario_root="$1"
	local fixture_kind="$2"
	local session_path request_path owner_path temporary_path
	session_path="$(control_root "${scenario_root}")/junglelaw-server.shutdown"
	request_path="${session_path}/request.json"
	owner_path="${session_path}/owner_token"
	temporary_path="$(control_root "${scenario_root}")/.rejected-request-fixture.${fixture_kind}.tmp"
	[[ ! -e "${request_path}" && ! -e "${temporary_path}" ]] || fail "request fixture path already exists for ${fixture_kind}"
	python3 - "${fixture_kind}" "${active_pid}" "${owner_path}" "${temporary_path}" "${request_path}" <<'PY'
import json
import os
import sys
import time

kind, pid_text, owner_path, temporary_path, request_path = sys.argv[1:]
pid = int(pid_text)
with open(owner_path, "r", encoding="ascii") as handle:
    token = handle.read()
if kind == "malformed":
    encoded = b'{"version":1,'
elif kind == "wrong-token":
    wrong_token = "f" * 64 if token != "f" * 64 else "e" * 64
    encoded = json.dumps({
        "version": 1,
        "action": "shutdown",
        "pid": pid,
        "token": wrong_token,
        "requested_at_unix": int(time.time()),
    }, separators=(",", ":")).encode("utf-8")
elif kind == "stale-pid":
    encoded = json.dumps({
        "version": 1,
        "action": "shutdown",
        "pid": pid + 100000,
        "token": token,
        "requested_at_unix": int(time.time()),
    }, separators=(",", ":")).encode("utf-8")
else:
    raise SystemExit("unsupported request fixture")
descriptor = os.open(temporary_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
try:
    os.write(descriptor, encoded)
    os.fsync(descriptor)
finally:
    os.close(descriptor)
os.link(temporary_path, request_path, follow_symlinks=False)
os.unlink(temporary_path)
PY
}

exercise_rejected_requests() {
	local scenario_root="$1"
	local log_path="$2"
	local session_path request_path before_hash after_hash
	session_path="$(control_root "${scenario_root}")/junglelaw-server.shutdown"
	request_path="${session_path}/request.json"

	local fixture_kind expected_reason
	while IFS='|' read -r fixture_kind expected_reason; do
		publish_rejected_request_fixture "${scenario_root}" "${fixture_kind}"
		before_hash="$(sha256sum "${request_path}" | awk '{print $1}')"
		wait_for_log_pattern "${log_path}" "Dedicated shutdown request rejected (${expected_reason})" \
			|| fail "runtime did not reject ${fixture_kind} request as ${expected_reason}"
		process_is_running "${active_pid}" || fail "runtime exited for rejected ${fixture_kind} request"
		port_open "${positive_port}" || fail "listener closed for rejected ${fixture_kind} request"
		after_hash="$(sha256sum "${request_path}" | awk '{print $1}')"
		[[ "${before_hash}" == "${after_hash}" ]] || fail "runtime changed rejected ${fixture_kind} request"
		printf 'rejected_request_%s=PASS reason=%s preserved=true\n' "${fixture_kind}" "${expected_reason}" \
			| tee -a "${evidence_root}/summary.txt"
		# This is local-fixture cleanup by the harness, never helper/runtime cleanup.
		rm -f -- "${request_path}"
		sleep 0.35
	done <<'REQUEST_FIXTURES'
malformed|request_json_invalid
wrong-token|request_token_mismatch
stale-pid|request_pid_mismatch
REQUEST_FIXTURES
}

run_graceful_stop() {
	local scenario_root="$1"
	local label="$2"
	local pid="${active_pid}"
	local helper_log="${evidence_root}/${label}-stop-helper.log"
	local scenario_control
	scenario_control="$(control_root "${scenario_root}")"

	set +e
	env \
		ZHANCHENG_SHUTDOWN_CONTROL_ROOT="${scenario_control}" \
		ZHANCHENG_SHUTDOWN_PYTHON_BIN=/usr/bin/python3 \
		ZHANCHENG_SHUTDOWN_READY_WAIT_SECONDS=5 \
		ZHANCHENG_SHUTDOWN_WAIT_SECONDS=15 \
		ZHANCHENG_SHUTDOWN_POLL_SECONDS=0.05 \
		/usr/bin/bash "${stop_helper}" "${pid}" \
		>"${helper_log}" 2>&1
	local helper_exit=$?
	set -e
	if [[ "${helper_exit}" -ne 0 ]]; then
		cat "${helper_log}" >&2
		printf '%s helper failed with exit %s.\n' "${label}" "${helper_exit}" >&2
		return 1
	fi

	set +e
	wait "${pid}"
	local process_exit=$?
	set -e
	active_pid=""
	[[ "${process_exit}" -eq 0 ]] || fail "${label} process exit must be 0, got ${process_exit}"
	printf '%s helper_exit=%s process_exit=%s\n' "${label}" "${helper_exit}" "${process_exit}" \
		| tee -a "${evidence_root}/summary.txt"
}

validate_success_result_without_disclosing_token() {
	local scenario_root="$1"
	local label="$2"
	local scenario_control result_path
	scenario_control="$(control_root "${scenario_root}")"
	result_path="${scenario_control}/junglelaw-server.shutdown-result.json"
	[[ -s "${result_path}" ]] || fail "${label} result is missing"
	[[ ! -e "${result_path}.previous" ]] || fail "${label} result.previous remains"
	[[ ! -e "${scenario_control}/junglelaw-server.shutdown" ]] || fail "${label} shutdown session remains"
	python3 - "${result_path}" <<'PY'
import json
import re
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    value = json.load(handle)
required = {"version", "pid", "token", "ok", "exit_code", "reason", "completed_at_unix"}
assert type(value) is dict and set(value) == required
assert type(value["version"]) is int and value["version"] == 1
assert type(value["pid"]) is int and value["pid"] > 1
assert type(value["token"]) is str and re.fullmatch(r"[0-9a-fA-F]{64}", value["token"])
assert type(value["ok"]) is bool and value["ok"] is True
assert type(value["exit_code"]) is int and value["exit_code"] == 0
assert value["reason"] == "graceful_shutdown_complete"
assert type(value["completed_at_unix"]) is int and value["completed_at_unix"] > 0
PY
	sha256sum "${result_path}" >"${evidence_root}/${label}-shutdown-result.sha256"
}

run_expected_success() {
	local label="$1"
	local scenario_root="$2"
	local port="$3"
	local check_rejected_requests="${4:-0}"
	local log_path="${evidence_root}/${label}.log"
	local authority session_path
	authority="$(authority_path "${scenario_root}")"
	session_path="$(control_root "${scenario_root}")/junglelaw-server.shutdown"

	assert_port_closed "${port}"
	prepare_scenario "${scenario_root}"
	start_candidate "${scenario_root}" "${port}" "${log_path}"
	if ! wait_for_listener_and_ready "${scenario_root}" "${port}"; then
		cat "${log_path}" >&2
		fail "${label} did not open loopback UDP and publish ready"
	fi
	ss -H -lunp "sport = :${port}" | tee "${evidence_root}/${label}-listener.txt"
	if ! ss -H -lun "sport = :${port}" \
		| grep -Eq '(^|[[:space:]])(127\.0\.0\.1|\[::ffff:127\.0\.0\.1\]):'; then
		fail "${label} listener is not bound to loopback"
	fi
	if ss -H -lun "sport = :${port}" | grep -Eq '0\.0\.0\.0:|\[::\]:'; then
		fail "${label} exposed a wildcard listener"
	fi
	wait_for_runtime_exports "${scenario_root}" "${authority}" || fail "${label} runtime exports were not produced"
	for command_state in pending processed failed; do
		[[ -d "${scenario_root}/commands/${command_state}" ]] || fail "${label} missing command directory ${command_state}"
	done
	[[ -d "${authority}.write_lock" ]] || fail "${label} did not hold the authority lifecycle lock while alive"
	[[ "$(stat -c '%a' "$(control_root "${scenario_root}")")" == '700' ]] || fail "${label} control root is not 0700"
	[[ "$(stat -c '%a' "${session_path}")" == '770' ]] || fail "${label} session mode is not 0770 under UMask=0007"
	[[ "$(stat -c '%a' "${session_path}/owner_token")" == '660' ]] || fail "${label} owner token mode is not 0660 under UMask=0007"
	[[ "$(stat -c '%a' "${session_path}/ready.json")" == '660' ]] || fail "${label} ready mode is not 0660 under UMask=0007"
	if [[ "${check_rejected_requests}" -eq 1 ]]; then
		exercise_rejected_requests "${scenario_root}" "${log_path}"
	fi
	scan_unexpected_script_errors "${log_path}"
	sha256sum \
		"${scenario_root}/exports/dashboard_snapshot.json" \
		"${scenario_root}/exports/admin_accounts_snapshot.json" \
		"${authority}" \
		>"${evidence_root}/${label}-runtime.sha256"

	run_graceful_stop "${scenario_root}" "${label}"
	assert_port_closed "${port}"
	[[ ! -e "${authority}.write_lock" ]] || fail "${label} left the authority lifecycle lock"
	validate_success_result_without_disclosing_token "${scenario_root}" "${label}"
	scan_unexpected_script_errors "${log_path}"
}

run_raw_signal_fail_closed() {
	local scenario_root="$1"
	local port="$2"
	local log_path="${evidence_root}/raw-signal-fail-closed.log"
	local authority process_exit
	authority="$(authority_path "${scenario_root}")"

	assert_port_closed "${port}"
	prepare_scenario "${scenario_root}"
	mkdir -p "$(dirname -- "${authority}")"
	cp "${positive_authority}" "${authority}"
	start_candidate "${scenario_root}" "${port}" "${log_path}"
	wait_for_listener_and_ready "${scenario_root}" "${port}" || fail 'raw-signal scenario did not become ready'
	wait_for_runtime_exports "${scenario_root}" "${authority}" || fail 'raw-signal scenario did not produce runtime exports'
	[[ -d "${authority}.write_lock" ]] || fail 'raw-signal scenario did not hold the lifecycle lock'
	kill -TERM "${active_pid}"
	for _attempt in $(seq 1 80); do
		process_is_running "${active_pid}" || break
		sleep 0.1
	done
	process_is_running "${active_pid}" && fail 'raw SIGTERM did not terminate the candidate'
	set +e
	wait "${active_pid}"
	process_exit=$?
	set -e
	active_pid=""
	[[ "${process_exit}" -ne 0 ]] || fail 'raw SIGTERM unexpectedly returned OS exit 0'
	assert_port_closed "${port}"
	[[ -d "${authority}.write_lock" ]] || fail 'raw SIGTERM did not retain the authority lock fail-closed'
	[[ -d "$(control_root "${scenario_root}")/junglelaw-server.shutdown" ]] \
		|| fail 'raw SIGTERM did not retain the shutdown session fail-closed'
	scan_unexpected_script_errors "${log_path}"
	find "${scenario_root}" -printf '%y %m %s %p\n' >"${evidence_root}/raw-signal-post-exit-tree.txt"
	printf 'raw_signal_fail_closed=PASS process_exit=%s lifecycle_lock=retained control_session=retained\n' "${process_exit}" \
		| tee -a "${evidence_root}/summary.txt"
	case "${scenario_root}" in
		"${runtime_root}/raw-signal") rm -rf -- "${scenario_root}" ;;
		*) fail "refusing to remove unexpected raw-signal fixture path: ${scenario_root}" ;;
	esac
	[[ ! -e "${scenario_root}" ]] || fail 'raw-signal fixture data was not removed'
	printf '%s\n' 'raw_signal_fixture_cleanup=PASS' >>"${evidence_root}/summary.txt"
}

run_expected_failure() {
	local label="$1"
	local scenario_root="$2"
	local port="$3"
	local expected_pattern="$4"
	local log_path="${evidence_root}/${label}.log"
	local saw_listener=0

	assert_port_closed "${port}"
	start_candidate "${scenario_root}" "${port}" "${log_path}"
	for _attempt in $(seq 1 120); do
		if port_open "${port}"; then
			saw_listener=1
			break
		fi
		process_is_running "${active_pid}" || break
		sleep 0.1
	done
	[[ "${saw_listener}" -eq 0 ]] || fail "${label} unexpectedly opened UDP ${port}"
	if process_is_running "${active_pid}"; then
		cat "${log_path}" >&2
		fail "${label} did not terminate after startup rejection"
	fi
	set +e
	wait "${active_pid}"
	local process_exit=$?
	set -e
	active_pid=""
	[[ "${process_exit}" -ne 0 ]] || fail "${label} returned OS exit code 0"
	assert_port_closed "${port}"
	grep -Fq "${expected_pattern}" "${log_path}" || {
		cat "${log_path}" >&2
		fail "${label} missing expected diagnostic: ${expected_pattern}"
	}
	scan_unexpected_script_errors "${log_path}"
	[[ ! -e "$(control_root "${scenario_root}")/junglelaw-server.shutdown" ]] \
		|| fail "${label} left a shutdown control session"
	printf '%s process_exit=%s listener_opened=false\n' "${label}" "${process_exit}" \
		| tee -a "${evidence_root}/summary.txt"
}

for command_name in bash file grep python3 readelf sha256sum ss stat; do
	command -v "${command_name}" >/dev/null 2>&1 || fail "missing verification command: ${command_name}"
done
bash -n "${stop_helper}"
mkdir -p "${evidence_root}"
file "${candidate}" | tee "${evidence_root}/elf-file.txt"
file "${candidate}" | grep -Fq 'ELF 64-bit LSB'
readelf -h "${candidate}" >"${evidence_root}/elf-header.txt"
grep -Fq 'Machine:                           Advanced Micro Devices X86-64' "${evidence_root}/elf-header.txt"
sha256sum "${candidate}" >"${evidence_root}/candidate.sha256"

for port in "${positive_port}" "${corrupt_port}" "${residual_lock_port}"; do
	assert_port_closed "${port}"
done

runtime_root="$(mktemp -d /tmp/junglelaw-server-candidate.XXXXXX)"
positive_root="${runtime_root}/positive"
corrupt_root="${runtime_root}/corrupt"
residual_root="${runtime_root}/residual-lock"
raw_signal_root="${runtime_root}/raw-signal"

prepare_scenario "${positive_root}"
positive_authority="$(authority_path "${positive_root}")"
mkdir -p "$(dirname -- "${positive_authority}")"
printf '%s\n' '{"version":3,"accounts":{},"installations":{},"admin_command_receipts":{}}' >"${positive_authority}"
positive_baseline_sha="$(sha256sum "${positive_authority}" | awk '{print $1}')"

run_expected_success positive-start-1 "${positive_root}" "${positive_port}" 1
positive_first_stop_sha="$(sha256sum "${positive_authority}" | awk '{print $1}')"
run_expected_success positive-restart-2 "${positive_root}" "${positive_port}"
positive_second_stop_sha="$(sha256sum "${positive_authority}" | awk '{print $1}')"
run_expected_success positive-restart-3 "${positive_root}" "${positive_port}"
positive_third_stop_sha="$(sha256sum "${positive_authority}" | awk '{print $1}')"
[[ "${positive_baseline_sha}" == "${positive_first_stop_sha}" \
	&& "${positive_first_stop_sha}" == "${positive_second_stop_sha}" \
	&& "${positive_second_stop_sha}" == "${positive_third_stop_sha}" ]] \
	|| fail 'same-data restart changed the untouched authority payload'
printf 'same_data_repeated_restart=PASS cycles=3 authority_sha256=%s\n' "${positive_third_stop_sha}" \
	| tee -a "${evidence_root}/summary.txt"

run_raw_signal_fail_closed "${raw_signal_root}" "${positive_port}"

prepare_scenario "${corrupt_root}"
corrupt_authority="$(authority_path "${corrupt_root}")"
mkdir -p "$(dirname -- "${corrupt_authority}")"
printf '%s' '{"version":3,' >"${corrupt_authority}"
run_expected_failure \
	negative-corrupt-authority \
	"${corrupt_root}" \
	"${corrupt_port}" \
	'PlayerAccountStore authority storage is unavailable: authority_json_invalid'
[[ ! -e "${corrupt_authority}.write_lock" ]] || fail 'corrupt-authority test left a lifecycle lock'

prepare_scenario "${residual_root}"
residual_authority="$(authority_path "${residual_root}")"
mkdir -p "$(dirname -- "${residual_authority}")"
cp "${positive_authority}" "${residual_authority}"
mkdir "${residual_authority}.write_lock"
printf '%s\n' 'stale-test-owner-token' >"${residual_authority}.write_lock/owner_token"
run_expected_failure \
	negative-residual-lifecycle-lock \
	"${residual_root}" \
	"${residual_lock_port}" \
	'PlayerAccountStore authority storage is unavailable: authority_lifecycle_lock_unavailable'
[[ -d "${residual_authority}.write_lock" ]] || fail 'runtime removed the foreign residual lifecycle lock'
printf '%s\n' 'negative-residual-lifecycle-lock_preserved_foreign_lock=true' >>"${evidence_root}/summary.txt"
rm -f -- "${residual_authority}.write_lock/owner_token"
rmdir -- "${residual_authority}.write_lock"

if find "${runtime_root}" -type d \( -name '*.write_lock' -o -name 'junglelaw-server.shutdown' \) -print -quit | grep -q .; then
	fail 'a lifecycle/control lock remains in the local runtime root'
fi
for port in "${positive_port}" "${corrupt_port}" "${residual_lock_port}"; do
	assert_port_closed "${port}"
done
if candidate_executable_is_running; then
	fail 'candidate process remains after verification'
fi

safe_remove_runtime
[[ ! -e "${runtime_root}" ]] || fail 'local runtime test data was not removed'
runtime_root=""
trap - EXIT INT TERM

printf '%s\n' 'cleanup=PASS processes=none ports=closed locks=none runtime_test_data=removed' \
	| tee -a "${evidence_root}/summary.txt"
printf '%s\n' 'LOCAL_CANDIDATE_VALIDATION_PASS' | tee -a "${evidence_root}/summary.txt"
