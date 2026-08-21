#!/usr/bin/env bash
# Local-only static and fault verification for the Linux dedicated-server unit.
set -Eeuo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
UNIT_PATH="${SCRIPT_DIR}/junglelaw-server.service"
HELPER_PATH="${SCRIPT_DIR}/junglelaw-server-stop.sh"
INSTALLER_PATH="${SCRIPT_DIR}/install_junglelaw_server.sh"
PREFLIGHT_PATH="${SCRIPT_DIR}/admin_dashboard_preflight.sh"
LOCAL_CANDIDATE_VERIFY_PATH="${SCRIPT_DIR}/verify_junglelaw_server_candidate.sh"
FAULT_TEST_PATH="${SCRIPT_DIR}/test_junglelaw_server_stop.py"

fail() {
	printf 'deploy verification failed: %s\n' "$*" >&2
	exit 1
}

for path in "${UNIT_PATH}" "${HELPER_PATH}" "${INSTALLER_PATH}" "${PREFLIGHT_PATH}" "${LOCAL_CANDIDATE_VERIFY_PATH}" "${FAULT_TEST_PATH}"; do
	[[ -f "${path}" ]] || fail "required file is missing: ${path}"
done

bash -n "${HELPER_PATH}"
bash -n "${INSTALLER_PATH}"
bash -n "${PREFLIGHT_PATH}"
bash -n "${LOCAL_CANDIDATE_VERIFY_PATH}"
bash -n "$0"

command -v python3 >/dev/null 2>&1 || fail 'python3 is required'
python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 6) else 1)' \
	|| fail 'python3 3.6 or newer is required'
python3 - "${HELPER_PATH}" <<'PY'
import ast
from pathlib import Path
import sys

lines = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
blocks = []
current = None
for line in lines:
    if current is None and "<<'PY'" in line:
        current = []
    elif current is not None and line == "PY":
        blocks.append("\n".join(current) + "\n")
        current = None
    elif current is not None:
        current.append(line)
if current is not None or len(blocks) != 2:
    raise SystemExit("expected exactly two complete embedded Python blocks")
for block in blocks:
    if sys.version_info >= (3, 8):
        ast.parse(block, feature_version=6)
    else:
        ast.parse(block)
PY

required_unit_lines=(
	'RuntimeDirectory=junglelaw'
	'RuntimeDirectoryMode=0700'
	'RuntimeDirectoryPreserve=yes'
	'Environment=ZHANCHENG_SHUTDOWN_CONTROL_ROOT=/run/junglelaw'
	'ExecStartPre=/usr/bin/test -x /usr/bin/python3'
	'ExecStop=/usr/local/libexec/junglelaw-server-stop $MAINPID'
	'TimeoutStopSec=40'
	'RestartPreventExitStatus=74 78'
)
for line in "${required_unit_lines[@]}"; do
	[[ "$(grep -Fxc -- "${line}" "${UNIT_PATH}")" -eq 1 ]] || fail "unit line must appear exactly once: ${line}"
done

grep -Fq 'install -o root -g root -m 0755 "${STOP_HELPER_PATH}" /usr/local/libexec/junglelaw-server-stop' "${INSTALLER_PATH}" \
	|| fail 'installer does not install the stop helper at the unit path'
grep -Fq 'bash -n "${STOP_HELPER_PATH}"' "${INSTALLER_PATH}" \
	|| fail 'installer does not syntax-check the stop helper'
grep -Fq "sys.version_info >= (3, 6)" "${INSTALLER_PATH}" \
	|| fail 'installer does not enforce Python 3.6 or newer'
for line in "${required_unit_lines[@]}"; do
	grep -Fq "require_exact_line \"\${GAME_UNIT_FILE}\" '${line}'" "${PREFLIGHT_PATH}" \
		|| fail "admin preflight does not enforce unit line: ${line}"
done

grep -Fq '\[::ffff:127\.0\.0\.1\]' "${LOCAL_CANDIDATE_VERIFY_PATH}" \
	|| fail 'candidate verifier must accept IPv4-mapped IPv6 loopback listeners'
grep -Fq 'candidate_realpath="$(realpath -e -- "${candidate}")"' "${LOCAL_CANDIDATE_VERIFY_PATH}" \
	|| fail 'candidate verifier must resolve the candidate executable path'
grep -Fq 'for process_exe in /proc/[0-9]*/exe; do' "${LOCAL_CANDIDATE_VERIFY_PATH}" \
	|| fail 'candidate verifier must detect processes by executable path'
if grep -Fq 'pgrep -f -- "${candidate}"' "${LOCAL_CANDIDATE_VERIFY_PATH}"; then
	fail 'candidate verifier must not self-match its own command line'
fi

unexpected_kill="$(grep -nE '(^|[^[:alnum:]_])kill([[:space:]]|$)' "${HELPER_PATH}" | grep -Fv 'kill -0' || true)"
[[ -z "${unexpected_kill}" ]] || fail "stop helper must never signal MAINPID: ${unexpected_kill}"
if grep -nE '(^|[[:space:]])rm([[:space:]]|$)|rm -r|rmdir' "${HELPER_PATH}" >/dev/null; then
	fail 'stop helper must not contain shell-side authority/control cleanup commands'
fi

command -v systemd-analyze >/dev/null 2>&1 || fail 'systemd-analyze is required for unit verification'
temporary_directory="$(mktemp -d /tmp/junglelaw-systemd-verify.XXXXXX)"
cleanup() {
	case "${temporary_directory}" in
		/tmp/junglelaw-systemd-verify.*)
			rm -rf -- "${temporary_directory}"
			;;
		*)
			printf 'refusing to remove unexpected temporary path: %s\n' "${temporary_directory}" >&2
			return 1
			;;
	esac
}
trap cleanup EXIT

# Replace only unavailable local executable/user paths. All unit directives and
# the ExecStop MAINPID argument remain parseable by systemd-analyze.
sed \
	-e 's/^User=.*/User=root/' \
	-e 's/^Group=.*/Group=root/' \
	-e 's#^ExecStartPre=.*#ExecStartPre=/usr/bin/true#' \
	-e 's#^ExecStart=.*#ExecStart=/usr/bin/true#' \
	-e 's#^ExecStop=/usr/local/libexec/junglelaw-server-stop#ExecStop=/usr/bin/true#' \
	"${UNIT_PATH}" > "${temporary_directory}/junglelaw-server.service"
systemd-analyze verify "${temporary_directory}/junglelaw-server.service"

PYTHONDONTWRITEBYTECODE=1 python3 "${FAULT_TEST_PATH}"
printf '%s\n' 'junglelaw dedicated-server deploy verification: PASS'
