#!/usr/bin/env bash
# Read-only deployment preflight for an already prepared Alibaba Cloud host.
# It does not install packages, create users/directories, change permissions,
# start services, open ports, initialize accounts, or write remote state.
set -Eeuo pipefail

ENV_FILE="${1:-/etc/junglelaw-admin-dashboard/dashboard.env}"
UNIT_FILE="${2:-/etc/systemd/system/junglelaw-admin-dashboard.service}"
RELEASE_ROOT="${3:-/opt/junglelaw-admin/current}"
GAME_UNIT_FILE="${4:-/etc/systemd/system/junglelaw-server.service}"
GAME_DROPIN_FILE="${5:-/etc/systemd/system/junglelaw-server.service.d/admin-dashboard.conf}"
GAME_STOP_HELPER="${6:-/usr/local/libexec/junglelaw-server-stop}"
CERT_RENEW_UNIT="${7:-/etc/systemd/system/junglelaw-admin-dashboard-cert-renew.service}"
CERT_RENEW_TIMER="${8:-/etc/systemd/system/junglelaw-admin-dashboard-cert-renew.timer}"
CERT_RENEW_CONFIG="${9:-/etc/junglelaw-admin-dashboard/cert-renew.env}"
PUBLIC_443_DROPIN="${10:-/etc/systemd/system/junglelaw-admin-dashboard.service.d/public-443.conf}"
JUNGLELAW_ROOT='/var/lib/junglelaw'
CERT_DEPLOY_HOOK='/etc/letsencrypt/renewal-hooks/deploy/junglelaw-admin-dashboard-cert-deploy'

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

pass() {
	printf 'PASS: %s\n' "$*"
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

read_env_value() {
	local key="$1"
	local line
	line="$(grep -E "^[[:space:]]*${key}=" "${ENV_FILE}" | tail -n 1 || true)"
	[[ -n "${line}" ]] || fail "missing ${key} in ${ENV_FILE}"
	line="${line#*=}"
	line="${line%$'\r'}"
	[[ -n "${line}" ]] || fail "empty ${key} in ${ENV_FILE}"
	[[ "${line}" != *'<'* && "${line}" != *'>'* ]] || fail "placeholder remains in ${key}"
	printf '%s' "${line}"
}

read_setting_from() {
	local file_path="$1"
	local key="$2"
	local line
	line="$(grep -E "^[[:space:]]*${key}=" "${file_path}" | tail -n 1 || true)"
	[[ -n "${line}" ]] || fail "missing ${key} in ${file_path}"
	line="${line#*=}"
	line="${line%$'\r'}"
	[[ -n "${line}" ]] || fail "empty ${key} in ${file_path}"
	[[ "${line}" != *'<'* && "${line}" != *'>'* ]] || fail "placeholder remains in ${key}"
	printf '%s' "${line}"
}

run_as() {
	local account="$1"
	shift
	runuser -u "${account}" -- "$@"
}

require_exact_line() {
	local file_path="$1"
	local expected_line="$2"
	grep -Fxq "${expected_line}" "${file_path}" \
		|| fail "missing required line in ${file_path}: ${expected_line}"
}

verify_systemd_units_fail_on_unknown() {
	local verify_output
	local verify_status
	set +e
	verify_output="$(LC_ALL=C systemd-analyze verify "$@" 2>&1)"
	verify_status=$?
	set -e
	printf '%s\n' "${verify_output}"
	if printf '%s\n' "${verify_output}" \
		| grep -Eiq 'Unknown lvalue|Unknown key name|Unknown assignment'; then
		fail 'systemd unit contains a directive unknown to the target systemd'
	fi
	[[ "${verify_status}" -eq 0 ]] || fail "systemd-analyze verify failed with status ${verify_status}"
}

check_setgid_group_rw_directory() {
	local directory_path="$1"
	local expected_group="$2"
	local mode_text
	local mode_number
	[[ -d "${directory_path}" ]] || fail "required directory not found: ${directory_path}"
	[[ "$(stat -c '%G' "${directory_path}")" == "${expected_group}" ]] \
		|| fail "${directory_path} must use group ${expected_group}"
	mode_text="$(stat -c '%a' "${directory_path}")"
	mode_number=$((8#${mode_text}))
	(( (mode_number & 02000) != 0 )) || fail "${directory_path} is missing setgid (mode ${mode_text})"
	[[ "${mode_text}" == '2770' ]] \
		|| fail "${directory_path} mode must be 2770 (found ${mode_text})"
}

check_group_rw_file() {
	local file_path="$1"
	local expected_group="$2"
	local mode_text
	[[ -f "${file_path}" ]] || fail "required generated file not found: ${file_path}"
	[[ "$(stat -c '%G' "${file_path}")" == "${expected_group}" ]] \
		|| fail "${file_path} must use group ${expected_group}"
	mode_text="$(stat -c '%a' "${file_path}")"
	[[ "${mode_text}" == '660' ]] \
		|| fail "${file_path} mode must be 0660 (found ${mode_text})"
}

check_authoritative_root_acl() {
	local acl_text
	[[ "$(realpath -e -- "${JUNGLELAW_ROOT}")" == "${JUNGLELAW_ROOT}" ]] \
		|| fail "authoritative root is not canonical: ${JUNGLELAW_ROOT}"
	acl_text="$(getfacl -cp -- "${JUNGLELAW_ROOT}")"
	if printf '%s\n' "${acl_text}" | grep -Eq '^default:'; then
		fail 'authoritative root must not carry inheritable default ACL entries'
	fi
	for required_acl_line in \
		'user::rwx' 'user:junglelaw-admin:--x' 'group::r-x' 'mask::r-x' 'other::---'; do
		[[ "$(printf '%s\n' "${acl_text}" | grep -Fxc "${required_acl_line}")" -eq 1 ]] \
			|| fail "authoritative root ACL is missing exact line: ${required_acl_line}"
	done
	if printf '%s\n' "${acl_text}" | grep -Eq '^group:[^:]+'; then
		fail 'authoritative root must not grant a named group ACL'
	fi
	if printf '%s\n' "${acl_text}" \
		| grep -E '^user:[^:]+' \
		| grep -Fvx 'user:junglelaw-admin:--x' \
		| grep -q .; then
		fail 'authoritative root contains an unapproved named-user ACL'
	fi
}

[[ "${EUID}" -eq 0 ]] || fail "run with sudo/root so service-account permissions can be checked"
[[ -f "${ENV_FILE}" ]] || fail "environment file not found: ${ENV_FILE}"
[[ -f "${UNIT_FILE}" ]] || fail "systemd unit not found: ${UNIT_FILE}"
[[ -f "${GAME_UNIT_FILE}" ]] || fail "game-server systemd unit not found: ${GAME_UNIT_FILE}"
[[ -f "${GAME_DROPIN_FILE}" ]] || fail "game-server admin drop-in not found: ${GAME_DROPIN_FILE}"
[[ -f "${GAME_STOP_HELPER}" ]] || fail "game-server synchronous stop helper not found: ${GAME_STOP_HELPER}"
[[ -f "${CERT_RENEW_UNIT}" ]] || fail "certificate-renewal unit not found: ${CERT_RENEW_UNIT}"
[[ -f "${CERT_RENEW_TIMER}" ]] || fail "certificate-renewal timer not found: ${CERT_RENEW_TIMER}"
[[ -f "${CERT_RENEW_CONFIG}" ]] || fail "certificate-renewal configuration not found: ${CERT_RENEW_CONFIG}"
[[ -f "${CERT_DEPLOY_HOOK}" && ! -L "${CERT_DEPLOY_HOOK}" ]] \
	|| fail "certificate deploy hook not found or is a symlink: ${CERT_DEPLOY_HOOK}"
[[ -d "${RELEASE_ROOT}/tools/admin_dashboard" ]] || fail "release dashboard directory not found"

require_command grep
require_command id
require_command node
require_command openssl
require_command python3
require_command runuser
require_command stat
require_command systemd-analyze
require_command cut
require_command dirname
require_command getfacl
require_command realpath
require_command tail
require_command tr

[[ -x /usr/bin/python3 ]] || fail "required Python executable is missing: /usr/bin/python3"
/usr/bin/python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 6) else 1)' \
	|| fail "Python 3.6 or newer is required by the synchronous stop helper"
[[ "$(stat -c '%U:%G' "${GAME_STOP_HELPER}")" == 'root:root' ]] \
	|| fail "game-server stop helper owner must be root:root"
[[ "$(stat -c '%a' "${GAME_STOP_HELPER}")" == '755' ]] \
	|| fail "game-server stop helper mode must be 0755"
bash -n "${GAME_STOP_HELPER}"
require_exact_line "${GAME_UNIT_FILE}" 'RuntimeDirectory=junglelaw'
require_exact_line "${GAME_UNIT_FILE}" 'RuntimeDirectoryMode=0700'
require_exact_line "${GAME_UNIT_FILE}" 'RuntimeDirectoryPreserve=yes'
require_exact_line "${GAME_UNIT_FILE}" 'Environment=ZHANCHENG_SHUTDOWN_CONTROL_ROOT=/run/junglelaw'
require_exact_line "${GAME_UNIT_FILE}" 'ExecStartPre=/usr/bin/test -x /usr/bin/python3'
require_exact_line "${GAME_UNIT_FILE}" 'ExecStop=/usr/local/libexec/junglelaw-server-stop $MAINPID'
require_exact_line "${GAME_UNIT_FILE}" 'TimeoutStopSec=40'
require_exact_line "${GAME_UNIT_FILE}" 'RestartPreventExitStatus=74 78'
pass "game-server synchronous shutdown deployment contract"

id -u junglelaw-admin >/dev/null 2>&1 || fail "missing service account: junglelaw-admin"
id -u junglelaw >/dev/null 2>&1 || fail "missing game-server account: junglelaw"
for account_name in junglelaw-admin junglelaw; do
	for group_name in junglelaw-admin-read junglelaw-admin-command; do
		id -nG "${account_name}" | tr ' ' '\n' | grep -Fxq "${group_name}" \
			|| fail "${account_name} is not in ${group_name}"
	done
done
if id -nG junglelaw-admin | tr ' ' '\n' | grep -Fxq junglelaw; then
	fail 'junglelaw-admin must never join the authoritative junglelaw group'
fi
pass "service users and supplemental groups"

[[ "$(stat -c '%U:%G' "${GAME_DROPIN_FILE}")" == 'root:root' ]] \
	|| fail "game-server drop-in owner must be root:root"
[[ "$(stat -c '%a' "${GAME_DROPIN_FILE}")" == '644' ]] \
	|| fail "game-server drop-in mode must be 0644"
require_exact_line "${GAME_DROPIN_FILE}" '[Service]'
require_exact_line "${GAME_DROPIN_FILE}" 'SupplementaryGroups=junglelaw-admin-read junglelaw-admin-command'
require_exact_line "${GAME_DROPIN_FILE}" 'UMask=0007'
require_exact_line "${GAME_DROPIN_FILE}" 'Environment=ZHANCHENG_DASHBOARD_SNAPSHOT_PATH=/var/lib/junglelaw/admin_exports/dashboard_snapshot.json'
require_exact_line "${GAME_DROPIN_FILE}" 'Environment=ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH=/var/lib/junglelaw/admin_exports/admin_accounts_snapshot.json'
require_exact_line "${GAME_DROPIN_FILE}" 'Environment=ZHANCHENG_DASHBOARD_COMMAND_ROOT=/var/lib/junglelaw/admin_commands'
require_exact_line "${GAME_DROPIN_FILE}" 'ReadWritePaths=/var/lib/junglelaw/admin_exports'
require_exact_line "${GAME_DROPIN_FILE}" 'ReadWritePaths=/var/lib/junglelaw/admin_commands'
require_exact_line "${UNIT_FILE}" 'SupplementaryGroups=junglelaw-admin-read junglelaw-admin-command'
require_exact_line "${UNIT_FILE}" 'CapabilityBoundingSet='
require_exact_line "${UNIT_FILE}" 'AmbientCapabilities='
for unsupported_directive in \
	ProtectClock ProtectHostname ProtectKernelLogs ProtectProc ProcSubset RestrictSUIDSGID; do
	if grep -Eq "^[[:space:]]*${unsupported_directive}=" "${UNIT_FILE}"; then
		fail "systemd 239-incompatible directive remains in ${UNIT_FILE}: ${unsupported_directive}"
	fi
done
CERT_WEBROOT="$(read_setting_from "${CERT_RENEW_CONFIG}" JUNGLELAW_CERT_WEBROOT)"
[[ "${CERT_WEBROOT}" == /* && -d "${CERT_WEBROOT}" ]] \
	|| fail "configured ACME webroot is not an absolute existing directory: ${CERT_WEBROOT}"
require_exact_line "${CERT_RENEW_UNIT}" "ReadWritePaths=${CERT_WEBROOT}"
if grep -Fq '/JUNGLELAW_CERT_WEBROOT_MUST_BE_REPLACED' "${CERT_RENEW_UNIT}"; then
	fail 'certificate-renewal unit still contains the ACME webroot placeholder'
fi
CERTBOT_BIN="$(read_setting_from "${CERT_RENEW_CONFIG}" JUNGLELAW_CERTBOT_BIN)"
CERTBOT_PYTHON_BIN="$(read_setting_from "${CERT_RENEW_CONFIG}" JUNGLELAW_CERTBOT_PYTHON_BIN)"
CERT_NAME="$(read_setting_from "${CERT_RENEW_CONFIG}" JUNGLELAW_CERT_NAME)"
CERT_IP="$(read_setting_from "${CERT_RENEW_CONFIG}" JUNGLELAW_CERT_IP)"
[[ "${CERTBOT_BIN}" == /* && -x "${CERTBOT_BIN}" ]] || fail 'configured Certbot executable is unavailable'
[[ "${CERTBOT_PYTHON_BIN}" == /* && -x "${CERTBOT_PYTHON_BIN}" ]] || fail 'configured Certbot Python is unavailable'
"${CERTBOT_PYTHON_BIN}" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' \
	|| fail 'Certbot virtual environment must use Python 3.10 or newer'
CERTBOT_VERSION_OUTPUT="$("${CERTBOT_BIN}" --version 2>&1)" || fail 'unable to query Certbot version'
if ! python3 - "${CERTBOT_VERSION_OUTPUT}" <<'PY'
import re
import sys

match = re.search(r"([0-9]+)\.([0-9]+)(?:\.([0-9]+))?", sys.argv[1])
if not match:
    raise SystemExit(1)
version = tuple(int(part or 0) for part in match.groups())
raise SystemExit(0 if version == (5, 7, 0) else 1)
PY
then
	fail "Certbot must be pinned to 5.7.0 (found: ${CERTBOT_VERSION_OUTPUT})"
fi
[[ "${CERT_NAME}" =~ ^[A-Za-z0-9._-]+$ ]] || fail 'configured certificate lineage name is invalid'
RENEWAL_CONFIG="/etc/letsencrypt/renewal/${CERT_NAME}.conf"
[[ -f "${RENEWAL_CONFIG}" ]] || fail "Certbot renewal configuration is missing: ${RENEWAL_CONFIG}"
[[ "$(stat -c '%U:%G:%a' "${CERT_DEPLOY_HOOK}")" == 'root:root:755' ]] \
	|| fail 'certificate deploy hook must be root:root 0755'
bash -n "${CERT_DEPLOY_HOOK}"
require_exact_line "${CERT_DEPLOY_HOOK}" "APPROVED_LINEAGE='/etc/letsencrypt/live/junglelaw-admin-ip'"
require_exact_line "${CERT_DEPLOY_HOOK}" 'exec /usr/local/libexec/junglelaw-admin-dashboard-cert-renew deploy'
if grep -Fq 'certbot' "${CERT_DEPLOY_HOOK}"; then
	fail 'certificate deploy hook must not invoke Certbot recursively'
fi
require_exact_line "${CERT_RENEW_UNIT}" 'ExecStart=/usr/local/libexec/junglelaw-admin-dashboard-cert-renew renew'
[[ "$(grep -Fxc 'OnCalendar=*-*-* 00:00:00 UTC' "${CERT_RENEW_TIMER}")" -eq 1 ]] \
	|| fail 'certificate timer must include the UTC midnight renewal check'
[[ "$(grep -Fxc 'OnCalendar=*-*-* 12:00:00 UTC' "${CERT_RENEW_TIMER}")" -eq 1 ]] \
	|| fail 'certificate timer must include the UTC noon renewal check'
require_exact_line "${CERT_RENEW_TIMER}" 'RandomizedDelaySec=1h'
pass "game-server admin-dashboard drop-in contract"

ENV_OWNER="$(stat -c '%U:%G' "${ENV_FILE}")"
ENV_MODE="$(stat -c '%a' "${ENV_FILE}")"
[[ "${ENV_OWNER}" == 'root:junglelaw-admin' ]] \
	|| fail "environment file owner must be root:junglelaw-admin (found ${ENV_OWNER})"
[[ "${ENV_MODE}" == '640' || "${ENV_MODE}" == '440' ]] \
	|| fail "environment file mode must be 0640 or 0440 (found ${ENV_MODE})"
[[ "$(stat -c '%U:%G' "${CERT_RENEW_CONFIG}")" == 'root:root' ]] \
	|| fail 'certificate-renewal configuration owner must be root:root'
[[ "$(stat -c '%a' "${CERT_RENEW_CONFIG}")" == '600' ]] \
	|| fail 'certificate-renewal configuration mode must be 0600'
[[ "$(stat -c '%U' "${RELEASE_ROOT}/tools/admin_dashboard/server.mjs")" == 'root' ]] \
	|| fail "release entrypoint is not root-owned"
[[ "$(stat -Lc '%U:%G:%a' "${RELEASE_ROOT}")" == 'root:root:755' ]] \
	|| fail 'immutable release root must be root:root 0755'
run_as junglelaw-admin test -r "${RELEASE_ROOT}/tools/admin_dashboard/server.mjs" \
	|| fail 'release entrypoint is not readable by junglelaw-admin'
run_as junglelaw-admin node --check "${RELEASE_ROOT}/tools/admin_dashboard/server.mjs"
run_as junglelaw-admin node "${RELEASE_ROOT}/tools/admin_dashboard/server.mjs" --help >/dev/null
if run_as junglelaw-admin test -w "${RELEASE_ROOT}/tools/admin_dashboard/server.mjs"; then
	fail "release entrypoint is writable by junglelaw-admin"
fi
pass "environment and immutable release ownership"

DASHBOARD_SNAPSHOT="$(read_env_value ZHANCHENG_DASHBOARD_SNAPSHOT_PATH)"
ACCOUNT_SNAPSHOT="$(read_env_value ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH)"
STATE_DIR="$(read_env_value ZHANCHENG_DASHBOARD_STATE_DIR)"
COMMAND_ROOT="$(read_env_value ZHANCHENG_DASHBOARD_COMMAND_ROOT)"
TLS_KEY="$(read_env_value ZHANCHENG_DASHBOARD_TLS_KEY_PATH)"
TLS_CERT="$(read_env_value ZHANCHENG_DASHBOARD_TLS_CERT_PATH)"
DASHBOARD_ENV_PORT="$(read_env_value ZHANCHENG_DASHBOARD_PORT)"
AUTHORITY_PATH="$(read_setting_from "${CERT_RENEW_CONFIG}" JUNGLELAW_AUTHORITY_PATH)"
HEALTH_PORT="$(read_setting_from "${CERT_RENEW_CONFIG}" JUNGLELAW_CERT_HEALTH_PORT)"

[[ "${DASHBOARD_SNAPSHOT}" == '/var/lib/junglelaw/admin_exports/dashboard_snapshot.json' ]] \
	|| fail "unexpected dashboard snapshot path: ${DASHBOARD_SNAPSHOT}"
[[ "${ACCOUNT_SNAPSHOT}" == '/var/lib/junglelaw/admin_exports/admin_accounts_snapshot.json' ]] \
	|| fail "unexpected account snapshot path: ${ACCOUNT_SNAPSHOT}"
[[ "${COMMAND_ROOT}" == '/var/lib/junglelaw/admin_commands' ]] \
	|| fail "unexpected command root: ${COMMAND_ROOT}"
[[ "${AUTHORITY_PATH}" == /* && -f "${AUTHORITY_PATH}" ]] \
	|| fail 'configured authority path must be an absolute existing file'
AUTHORITY_PATH="$(realpath -e -- "${AUTHORITY_PATH}")"
case "${AUTHORITY_PATH}" in
	/var/lib/junglelaw/*/server/player_accounts.json) ;;
	*) fail 'configured authority path is outside the approved server boundary' ;;
esac
SERVER_STATE_DIRECTORY="$(realpath -e -- "$(dirname -- "${AUTHORITY_PATH}")")"
[[ "${AUTHORITY_PATH}" == "${SERVER_STATE_DIRECTORY}/player_accounts.json" ]] \
	|| fail 'configured authority path is not canonical inside its server directory'
[[ "${HEALTH_PORT}" == '8443' || "${HEALTH_PORT}" == '443' ]] \
	|| fail 'configured dashboard health port must be exactly 8443 or 443'
[[ "${DASHBOARD_ENV_PORT}" == "${HEALTH_PORT}" ]] \
	|| fail 'dashboard runtime port must exactly match the certificate health port'
if [[ "${HEALTH_PORT}" == '443' ]]; then
	[[ -f "${PUBLIC_443_DROPIN}" ]] || fail '443 is configured but its systemd drop-in is missing'
	[[ "$(stat -c '%U:%G' "${PUBLIC_443_DROPIN}")" == 'root:root' ]] \
		|| fail '443 systemd drop-in owner must be root:root'
	[[ "$(stat -c '%a' "${PUBLIC_443_DROPIN}")" == '644' ]] \
		|| fail '443 systemd drop-in mode must be 0644'
	require_exact_line "${PUBLIC_443_DROPIN}" 'Environment=ZHANCHENG_DASHBOARD_PORT=443'
	require_exact_line "${PUBLIC_443_DROPIN}" 'CapabilityBoundingSet=CAP_NET_BIND_SERVICE'
	require_exact_line "${PUBLIC_443_DROPIN}" 'AmbientCapabilities=CAP_NET_BIND_SERVICE'
else
	[[ ! -e "${PUBLIC_443_DROPIN}" && ! -L "${PUBLIC_443_DROPIN}" ]] \
		|| fail '8443 is configured but the public-443 capability drop-in remains installed'
fi
check_authoritative_root_acl

check_setgid_group_rw_directory /var/lib/junglelaw/admin_exports junglelaw-admin-read
check_setgid_group_rw_directory "${COMMAND_ROOT}" junglelaw-admin-command
check_setgid_group_rw_directory "${COMMAND_ROOT}/pending" junglelaw-admin-command
check_setgid_group_rw_directory "${COMMAND_ROOT}/processed" junglelaw-admin-command
check_setgid_group_rw_directory "${COMMAND_ROOT}/failed" junglelaw-admin-command
check_group_rw_file "${DASHBOARD_SNAPSHOT}" junglelaw-admin-read
check_group_rw_file "${ACCOUNT_SNAPSHOT}" junglelaw-admin-read
require_exact_line "${UNIT_FILE}" 'ReadOnlyPaths=/var/lib/junglelaw/admin_exports'
require_exact_line "${UNIT_FILE}" 'ReadOnlyPaths=/var/lib/junglelaw/admin_commands/processed'
require_exact_line "${UNIT_FILE}" 'ReadOnlyPaths=/var/lib/junglelaw/admin_commands/failed'
pass "setgid directories, generated-file groups, and dashboard read-only mounts"

run_as junglelaw-admin test -r "${DASHBOARD_SNAPSHOT}" \
	|| fail "dashboard snapshot is not readable by junglelaw-admin"
run_as junglelaw-admin test -r "${ACCOUNT_SNAPSHOT}" \
	|| fail "account snapshot is not readable by junglelaw-admin"
if run_as junglelaw-admin test -r "${SERVER_STATE_DIRECTORY}"; then
	fail 'junglelaw-admin must not be able to list the authoritative server directory'
fi
if run_as junglelaw-admin test -r "${AUTHORITY_PATH}"; then
	fail 'junglelaw-admin must not be able to read player_accounts.json'
fi
run_as junglelaw-admin test -w "${STATE_DIR}" \
	|| fail "dashboard state directory is not writable by junglelaw-admin"
[[ "$(stat -c '%U:%G' "${STATE_DIR}")" == 'junglelaw-admin:junglelaw-admin' ]] \
	|| fail "dashboard state directory has unexpected owner/group"
[[ "$(stat -c '%a' "${STATE_DIR}")" == '700' ]] \
	|| fail "dashboard state directory mode must be 0700"
run_as junglelaw-admin test -w "${COMMAND_ROOT}/pending" \
	|| fail "pending command directory is not writable by junglelaw-admin"
run_as junglelaw test -r "${COMMAND_ROOT}/pending" \
	|| fail "pending command directory is not readable by junglelaw"
run_as junglelaw test -w "${COMMAND_ROOT}/pending" \
	|| fail "pending command directory is not consumable by junglelaw"
run_as junglelaw-admin test -r "${COMMAND_ROOT}/processed" \
	|| fail "processed receipts are not readable by junglelaw-admin"
run_as junglelaw-admin test -r "${COMMAND_ROOT}/failed" \
	|| fail "failed receipts are not readable by junglelaw-admin"
run_as junglelaw test -w "${COMMAND_ROOT}/processed" \
	|| fail "processed receipt directory is not writable by junglelaw"
run_as junglelaw test -w "${COMMAND_ROOT}/failed" \
	|| fail "failed receipt directory is not writable by junglelaw"
pass "snapshot, state, and command-directory permissions"

run_as junglelaw-admin test -r "${TLS_KEY}" || fail "TLS key is not readable by junglelaw-admin"
run_as junglelaw-admin test -r "${TLS_CERT}" || fail "TLS certificate is not readable by junglelaw-admin"
KEY_OWNER="$(stat -c '%U:%G' "${TLS_KEY}")"
KEY_MODE="$(stat -c '%a' "${TLS_KEY}")"
CERT_OWNER="$(stat -c '%U:%G' "${TLS_CERT}")"
CERT_MODE="$(stat -c '%a' "${TLS_CERT}")"
[[ "${KEY_OWNER}" == 'root:junglelaw-admin' ]] \
	|| fail "TLS private key owner must be root:junglelaw-admin (found ${KEY_OWNER})"
[[ "${KEY_MODE}" == '640' ]] \
	|| fail "TLS private key mode must be 0640 (found ${KEY_MODE})"
[[ "${CERT_OWNER}" == 'root:junglelaw-admin' ]] \
	|| fail "TLS full chain owner must be root:junglelaw-admin (found ${CERT_OWNER})"
[[ "${CERT_MODE}" == '640' ]] \
	|| fail "TLS full chain mode must be 0640 (found ${CERT_MODE})"
run_as junglelaw-admin openssl pkey -in "${TLS_KEY}" -noout \
	|| fail "TLS private key cannot be parsed non-interactively by junglelaw-admin"
openssl x509 -in "${TLS_CERT}" -noout -checkend 86400 \
	|| fail "TLS certificate is invalid or expires within 24 hours"
openssl x509 -in "${TLS_CERT}" -noout -ext subjectAltName \
	| grep -Fq "IP Address:${CERT_IP}" \
	|| fail "TLS certificate SAN does not contain the approved IP address ${CERT_IP}"
pass "TLS file access and short-lived certificate lifetime"

node --check "${RELEASE_ROOT}/tools/admin_dashboard/server.mjs"
pass "Node entrypoint syntax"

verify_systemd_units_fail_on_unknown \
	"${UNIT_FILE}" \
	"${GAME_UNIT_FILE}" \
	"${CERT_RENEW_UNIT}" \
	"${CERT_RENEW_TIMER}"
pass "systemd unit verification with unknown-lvalue fail gate"

printf 'READY FOR STAGING START ONLY: read-only preflight passed.\n'
