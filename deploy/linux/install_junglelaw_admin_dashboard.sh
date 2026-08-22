#!/usr/bin/env bash
# Transaction-oriented staging installer for the Jungle Law admin dashboard.
# It supports first-install rollback by recording both existing and absent
# paths before any deployment mutation. It never initializes an Owner password,
# changes Alibaba Cloud firewall rules, edits nginx, or promotes production.
set -Eeuo pipefail

ACTION="${1:-}"
[[ -n "${ACTION}" ]] && shift || true

RELEASE_VERSION=''
RELEASE_SOURCE=''
NODE_ARCHIVE=''
NODE_MANIFEST=''
EXPECTED_NODE_SHA256=''
GAME_RELEASE_SOURCE=''
GAME_ARCHIVE=''
EXPECTED_GAME_SHA256=''
EXPECTED_GAME_ARCHIVE_SHA256=''
BACKUP_ROOT=''
AUTHORITY_PATH=''
ACME_WEBROOT=''
PUBLIC_IP=''
DASHBOARD_PORT='8443'
FISHER_UNIT=''
NGINX_UNIT=''
BACKUP_DIRECTORY=''
CONFIRM_BACKUP_ID=''
AUTHORIZE_STATE_DIRECTORY_QUARANTINE=0
CERT_NAME='junglelaw-admin-ip'
CERTBOT_BIN='/opt/junglelaw-admin-certbot/venv/bin/certbot'
CERTBOT_PYTHON_BIN='/opt/junglelaw-admin-certbot/venv/bin/python'
NODE_BIN='/usr/bin/node'
APPROVED_GAME_ARTIFACT_ID='JungleLawServer-v1.2.0-local-linux-rc1'
APPROVED_GAME_VERSION='v1.2.0-local-linux-rc1'
APPROVED_GAME_ARCHIVE_SHA256='CB94723498D7E7A175304686F5CA72B0CF66745482A5DC89D9CB1D15D5F20267'
APPROVED_GAME_SHA256='7F11BC743A3573C8F9EAB7ECF6AADD65C74E7C8720DE80F7FA03ACC8BF1F2B94'
APPROVED_GAME_UNIT_SHA256='79B72AA23785DCE2C2C551A2AC26D835BB4C89FB7B1E0392396B3CE568E24BD6'
APPROVED_GAME_STOP_HELPER_SHA256='043881EB11D44BA582A3EBEB669FB755E63B77C90E52F4C5F6277EE548A401A9'
APPROVED_GAME_DROPIN_SHA256='12D08A7B47816517BEEE46EF1C0D939D49F796D692425A1F9E23709D5E3B0BF1'
APPROVED_PUBLIC_443_DROPIN_SHA256='17A19A8EB008AB094ADC22C6F5E743DFB3F0A33D3614A892DBF356DBA3F2655A'
DEPLOY_TRANSACTION_READY='1'
TRANSACTION_ACTION=''
TRANSACTION_BASELINE_CAPTURED=0
TRANSACTION_BACKUP_COMPLETE=0
TRANSACTION_MUTATED=0
TRANSACTION_ROLLING_BACK=0
BACKUP_DIRECTORY_CREATED=''
ROLLBACK_STAGE_ROOT=''
STAGED_RESTORE_ROOT=''
GAME_WAS_ACTIVE=0
GAME_WAS_ENABLED=0
DASHBOARD_WAS_ACTIVE=0
DASHBOARD_WAS_ENABLED=0
CERT_TIMER_WAS_ACTIVE=0
CERT_TIMER_WAS_ENABLED=0
CERT_RENEW_WAS_ACTIVE=0

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	return 1
}

usage() {
	cat >&2 <<'EOF'
Usage:
  install_junglelaw_admin_dashboard.sh prepare \
    --release-version VERSION --release-source ABSOLUTE_DIR \
    --node-archive ABSOLUTE_RUNTIME_ZIP --node-manifest ABSOLUTE_MANIFEST_JSON \
    --expected-node-sha256 APPROVED_RUNTIME_ZIP_SHA256 \
    --game-release-source ABSOLUTE_VERIFIED_V1_2_0_DIR \
    --game-archive ABSOLUTE_V1_2_0_TAR_GZ \
    --expected-game-archive-sha256 CB94723498D7E7A175304686F5CA72B0CF66745482A5DC89D9CB1D15D5F20267 \
    --expected-game-sha256 7F11BC743A3573C8F9EAB7ECF6AADD65C74E7C8720DE80F7FA03ACC8BF1F2B94 \
    --backup-root ABSOLUTE_DIR --authority-path ABSOLUTE_PLAYER_ACCOUNTS_JSON \
    --acme-webroot ABSOLUTE_EXISTING_NGINX_WEBROOT --public-ip PUBLIC_IPV4 \
    --dashboard-port 8443|443 \
    --fisher-unit EXACT_READ_ONLY_OBSERVED_SERVICE \
    --nginx-unit EXACT_READ_ONLY_OBSERVED_SERVICE \
    --authorize-state-directory-quarantine \
    [--cert-name SAFE_LINEAGE_NAME] [--certbot-bin ABSOLUTE_CERTBOT_5_7_0] \
    [--certbot-python-bin ABSOLUTE_PYTHON_3_10_PLUS]

  install_junglelaw_admin_dashboard.sh activate

  install_junglelaw_admin_dashboard.sh rollback \
    --backup-dir ABSOLUTE_BACKUP_DIR --confirm-backup-id BACKUP_ID \
    [--authorize-state-directory-quarantine]

prepare creates a coherent, checksummed pre-deploy backup, installs the immutable
release and systemd overlay, and restarts only the game service. Run interactive
Owner initialization and the certificate helper in initial mode before activate.
EOF
	exit 2
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--release-version) [[ "$#" -ge 2 ]] || usage; RELEASE_VERSION="$2"; shift 2 ;;
		--release-source) [[ "$#" -ge 2 ]] || usage; RELEASE_SOURCE="$2"; shift 2 ;;
		--node-archive) [[ "$#" -ge 2 ]] || usage; NODE_ARCHIVE="$2"; shift 2 ;;
		--node-manifest) [[ "$#" -ge 2 ]] || usage; NODE_MANIFEST="$2"; shift 2 ;;
		--expected-node-sha256) [[ "$#" -ge 2 ]] || usage; EXPECTED_NODE_SHA256="$2"; shift 2 ;;
		--game-release-source) [[ "$#" -ge 2 ]] || usage; GAME_RELEASE_SOURCE="$2"; shift 2 ;;
		--game-archive) [[ "$#" -ge 2 ]] || usage; GAME_ARCHIVE="$2"; shift 2 ;;
		--expected-game-archive-sha256) [[ "$#" -ge 2 ]] || usage; EXPECTED_GAME_ARCHIVE_SHA256="$2"; shift 2 ;;
		--expected-game-sha256) [[ "$#" -ge 2 ]] || usage; EXPECTED_GAME_SHA256="$2"; shift 2 ;;
		--backup-root) [[ "$#" -ge 2 ]] || usage; BACKUP_ROOT="$2"; shift 2 ;;
		--authority-path) [[ "$#" -ge 2 ]] || usage; AUTHORITY_PATH="$2"; shift 2 ;;
		--acme-webroot) [[ "$#" -ge 2 ]] || usage; ACME_WEBROOT="$2"; shift 2 ;;
		--public-ip) [[ "$#" -ge 2 ]] || usage; PUBLIC_IP="$2"; shift 2 ;;
		--dashboard-port) [[ "$#" -ge 2 ]] || usage; DASHBOARD_PORT="$2"; shift 2 ;;
		--fisher-unit) [[ "$#" -ge 2 ]] || usage; FISHER_UNIT="$2"; shift 2 ;;
		--nginx-unit) [[ "$#" -ge 2 ]] || usage; NGINX_UNIT="$2"; shift 2 ;;
		--cert-name) [[ "$#" -ge 2 ]] || usage; CERT_NAME="$2"; shift 2 ;;
		--certbot-bin) [[ "$#" -ge 2 ]] || usage; CERTBOT_BIN="$2"; shift 2 ;;
		--certbot-python-bin) [[ "$#" -ge 2 ]] || usage; CERTBOT_PYTHON_BIN="$2"; shift 2 ;;
		--backup-dir) [[ "$#" -ge 2 ]] || usage; BACKUP_DIRECTORY="$2"; shift 2 ;;
		--confirm-backup-id) [[ "$#" -ge 2 ]] || usage; CONFIRM_BACKUP_ID="$2"; shift 2 ;;
		--authorize-state-directory-quarantine) AUTHORIZE_STATE_DIRECTORY_QUARANTINE=1; shift ;;
		*) usage ;;
	esac
done

[[ "${EUID}" -eq 0 ]] || fail 'run as root'

SOURCE_DIRECTORY="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ADMIN_ROOT='/opt/junglelaw-admin'
ADMIN_RELEASE_ROOT='/opt/junglelaw-admin/releases'
ADMIN_CURRENT_LINK='/opt/junglelaw-admin/current'
ADMIN_STATE='/var/lib/junglelaw-admin-dashboard'
ADMIN_CONFIG_ROOT='/etc/junglelaw-admin-dashboard'
ADMIN_ENV='/etc/junglelaw-admin-dashboard/dashboard.env'
CERT_ENV='/etc/junglelaw-admin-dashboard/cert-renew.env'
ADMIN_UNIT='/etc/systemd/system/junglelaw-admin-dashboard.service'
CERT_SERVICE='/etc/systemd/system/junglelaw-admin-dashboard-cert-renew.service'
CERT_TIMER='/etc/systemd/system/junglelaw-admin-dashboard-cert-renew.timer'
CERT_HELPER='/usr/local/libexec/junglelaw-admin-dashboard-cert-renew'
PUBLIC_443_DROPIN='/etc/systemd/system/junglelaw-admin-dashboard.service.d/public-443.conf'
GAME_UNIT='/etc/systemd/system/junglelaw-server.service'
GAME_ELF='/opt/junglelaw/JungleLawServer.x86_64'
GAME_STOP_HELPER='/usr/local/libexec/junglelaw-server-stop'
GAME_DROPIN='/etc/systemd/system/junglelaw-server.service.d/admin-dashboard.conf'
JUNGLELAW_ROOT='/var/lib/junglelaw'
COMMAND_ROOT='/var/lib/junglelaw/admin_commands'
EXPORT_ROOT='/var/lib/junglelaw/admin_exports'
LE_RENEWAL_CONFIG="/etc/letsencrypt/renewal/${CERT_NAME}.conf"
LE_LIVE_LINEAGE="/etc/letsencrypt/live/${CERT_NAME}"
LE_ARCHIVE_LINEAGE="/etc/letsencrypt/archive/${CERT_NAME}"
LE_STAGING_RENEWAL_CONFIG="/etc/letsencrypt/renewal/${CERT_NAME}-staging.conf"
LE_STAGING_LIVE_LINEAGE="/etc/letsencrypt/live/${CERT_NAME}-staging"
LE_STAGING_ARCHIVE_LINEAGE="/etc/letsencrypt/archive/${CERT_NAME}-staging"
LE_DEPLOY_HOOK='/etc/letsencrypt/renewal-hooks/deploy/junglelaw-admin-dashboard-cert-deploy'

require_command() {
	command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

for required_command in awk basename bash cat chmod chown cmp cp curl cut date dirname find getent getfacl grep groupadd id install ln mv openssl python3 readlink realpath rm runuser sed setfacl sha256sum sort ss stat systemctl systemd-analyze tail tar tr unzip useradd usermod; do
	require_command "${required_command}"
done

validate_node_runtime() {
	[[ -x "${NODE_BIN}" ]] || fail "required Node executable is missing: ${NODE_BIN}"
	[[ "$("${NODE_BIN}" --version)" == 'v24.14.0' ]] \
		|| fail 'approved staging Node runtime must be exactly v24.14.0 at /usr/bin/node'
}

sha256_file_lower() {
	local output
	local digest
	output="$(sha256sum -- "$1")" || return 1
	digest="${output%% *}"
	[[ "${digest}" =~ ^[a-f0-9]{64}$ ]] || return 1
	printf '%s' "${digest}"
}

sha256_file_upper() {
	local digest
	digest="$(sha256_file_lower "$1")" || return 1
	printf '%s' "${digest^^}"
}

validate_public_ipv4() {
	python3 - "$1" <<'PY'
import ipaddress
import sys

try:
    value = ipaddress.ip_address(sys.argv[1])
except ValueError:
    raise SystemExit(1)
raise SystemExit(0 if value.version == 4 and value.is_global else 1)
PY
}

manifest_value() {
	local manifest="$1"
	local key="$2"
	local count
	count="$(awk -F '\t' -v key="${key}" '$1 == key {count += 1} END {print count + 0}' "${manifest}")"
	if [[ "${count}" -ne 1 ]]; then
		printf 'FAIL: manifest must contain exactly one %s entry\n' "${key}" >&2
		return 1
	fi
	awk -F '\t' -v key="${key}" '$1 == key {sub(/^[^\t]*\t/, ""); print}' "${manifest}" \
		|| return 1
}

verify_units_fail_on_unknown() {
	local output
	local status
	set +e
	output="$(LC_ALL=C systemd-analyze verify "$@" 2>&1)"
	status=$?
	set -e
	printf '%s\n' "${output}"
	if printf '%s\n' "${output}" \
		| grep -Eiq 'Unknown lvalue|Unknown key name|Unknown assignment'; then
		fail 'systemd unit contains a directive unknown to the target systemd'
	fi
	[[ "${status}" -eq 0 ]] || fail "systemd-analyze verify failed with status ${status}"
}

validate_backup_archive() {
	local manifest="$1"
	local archive="$2"
	python3 - "${manifest}" "${archive}" <<'PY'
import posixpath
from pathlib import PurePosixPath
import sys
import tarfile

manifest_path, archive_path = sys.argv[1:]
allowed_roots = []
allowed_live_roots = []
allowed_archive_roots = []
with open(manifest_path, "r", encoding="utf-8") as source:
    for raw in source:
        fields = raw.rstrip("\n").split("\t")
        if len(fields) == 3 and fields[0] == "path" and fields[1] == "present":
            absolute = fields[2]
            if not absolute.startswith("/") or "\n" in absolute or "\r" in absolute:
                raise SystemExit("unsafe manifest path")
            allowed_roots.append(absolute.lstrip("/"))
            if absolute.startswith("/etc/letsencrypt/live/"):
                allowed_live_roots.append(absolute.lstrip("/"))
            if absolute.startswith("/etc/letsencrypt/archive/"):
                allowed_archive_roots.append(absolute.lstrip("/"))

if not allowed_roots:
    raise SystemExit("backup has no present allowlisted paths")

def is_allowed(name):
    return any(name == root or name.startswith(root.rstrip("/") + "/") for root in allowed_roots)

with tarfile.open(archive_path, mode="r:") as archive:
    for member in archive.getmembers():
        normalized = member.name.rstrip("/")
        parsed = PurePosixPath(normalized)
        if not normalized or parsed.is_absolute() or ".." in parsed.parts or not is_allowed(normalized):
            raise SystemExit("archive member outside manifest allowlist: {}".format(member.name))
        if member.isdev() or member.isfifo() or member.islnk():
            raise SystemExit("unsafe archive member type: {}".format(member.name))
        if member.issym():
            target = PurePosixPath(member.linkname)
            if normalized == "opt/junglelaw-admin/current":
                if not target.is_absolute() or ".." in target.parts:
                    raise SystemExit("unsafe current symlink target")
                if not str(target).startswith("/opt/junglelaw-admin/releases/"):
                    raise SystemExit("current symlink target is outside release root")
            elif any(normalized == root or normalized.startswith(root.rstrip("/") + "/")
                     for root in allowed_live_roots):
                if target.is_absolute():
                    resolved = posixpath.normpath(str(target)).lstrip("/")
                else:
                    resolved = posixpath.normpath(posixpath.join(posixpath.dirname(normalized), str(target)))
                lineage = next(root for root in allowed_live_roots
                               if normalized == root or normalized.startswith(root.rstrip("/") + "/"))
                expected_archive = "etc/letsencrypt/archive/" + lineage.split("/")[-1]
                if (expected_archive not in allowed_archive_roots
                        or not (resolved == expected_archive
                                or resolved.startswith(expected_archive.rstrip("/") + "/"))):
                    raise SystemExit("certificate live symlink escapes the certificate archive")
            else:
                raise SystemExit("unexpected archive symlink: {}".format(member.name))
        elif not (member.isfile() or member.isdir()):
            raise SystemExit("unsupported archive member type: {}".format(member.name))
PY
}

service_was_active() {
	if systemctl is-active --quiet "$1"; then
		printf '1'
	else
		printf '0'
	fi
}

service_was_enabled() {
	if systemctl is-enabled --quiet "$1" 2>/dev/null; then
		printf '1'
	else
		printf '0'
	fi
}

restore_enable_state() {
	local unit_name="$1"
	local enabled_state="$2"
	if [[ "${enabled_state}" == '1' ]]; then
		systemctl enable "${unit_name}"
	else
		systemctl disable "${unit_name}" >/dev/null 2>&1 || true
	fi
}

stop_if_active() {
	if systemctl is-active --quiet "$1"; then
		systemctl stop "$1"
	fi
	if systemctl is-active --quiet "$1"; then
		fail "service remains active after stop: $1"
	fi
}

assert_admin_not_in_authority_group() {
	if id -u junglelaw-admin >/dev/null 2>&1 \
		&& id -nG junglelaw-admin | tr ' ' '\n' | grep -Fxq junglelaw; then
		fail 'junglelaw-admin must never join the authoritative junglelaw group'
	fi
}

validate_junglelaw_root_acl() {
	local require_admin_traverse="$1"
	local acl_text
	[[ -d "${JUNGLELAW_ROOT}" ]] || fail "authoritative root is missing: ${JUNGLELAW_ROOT}"
	[[ "$(realpath -e -- "${JUNGLELAW_ROOT}")" == "${JUNGLELAW_ROOT}" ]] \
		|| fail "authoritative root is not canonical: ${JUNGLELAW_ROOT}"
	acl_text="$(getfacl -cp -- "${JUNGLELAW_ROOT}")"
	if printf '%s\n' "${acl_text}" | grep -Eq '^default:'; then
		fail 'authoritative root must not carry inheritable default ACL entries'
	fi
	for required_acl_line in 'user::rwx' 'group::r-x' 'other::---'; do
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
	if [[ "${require_admin_traverse}" == '1' ]]; then
		[[ "$(printf '%s\n' "${acl_text}" | grep -Fxc 'user:junglelaw-admin:--x')" -eq 1 ]] \
			|| fail 'junglelaw-admin must have only traverse (--x) on the authoritative root'
		[[ "$(printf '%s\n' "${acl_text}" | grep -Fxc 'mask::r-x')" -eq 1 ]] \
			|| fail 'authoritative root ACL mask must remain r-x after adding traverse access'
	fi
}

apply_admin_traverse_acl() {
	assert_admin_not_in_authority_group
	setfacl -m 'u:junglelaw-admin:--x' -- "${JUNGLELAW_ROOT}"
	validate_junglelaw_root_acl 1
	runuser -u junglelaw-admin -- test -x "${JUNGLELAW_ROOT}" \
		|| fail 'junglelaw-admin cannot traverse the authoritative root after ACL installation'
}

validate_admin_data_boundary_before_start() {
	local server_state_directory="$1"
	assert_admin_not_in_authority_group
	runuser -u junglelaw-admin -- test -x "${JUNGLELAW_ROOT}" \
		|| fail 'junglelaw-admin cannot traverse the shared-data parent'
	runuser -u junglelaw-admin -- test -x "${EXPORT_ROOT}" \
		|| fail 'junglelaw-admin cannot traverse the snapshot projection directory'
	runuser -u junglelaw-admin -- test -w "${COMMAND_ROOT}/pending" \
		|| fail 'junglelaw-admin cannot write the pending command directory'
	if runuser -u junglelaw-admin -- test -r "${server_state_directory}"; then
		fail 'junglelaw-admin must not be able to list the authoritative server directory'
	fi
	if runuser -u junglelaw-admin -- test -r "${AUTHORITY_PATH}"; then
		fail 'junglelaw-admin must not be able to read player_accounts.json'
	fi
}

record_backup_path() {
	local manifest="$1"
	local list_file="$2"
	local path="$3"
	local state='absent'
	if [[ -e "${path}" || -L "${path}" ]]; then
		state='present'
		printf '%s\0' "${path#/}" >> "${list_file}"
	fi
	printf 'path\t%s\t%s\n' "${state}" "${path}" >> "${manifest}"
}

assert_safe_unit_name() {
	[[ "$1" =~ ^[A-Za-z0-9_.@-]+\.service$ ]] || fail "unsafe systemd service name: $1"
}

assert_pending_empty() {
	local phase="$1"
	if [[ -d "${COMMAND_ROOT}/pending" ]] \
		&& find "${COMMAND_ROOT}/pending" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
		fail "pending resource commands remain during ${phase}; reconcile before continuing"
	fi
}

capture_shared_host_fingerprint() {
	local output_path="$1"
	local temporary_path="${output_path}.new"
	local unit_name
	local main_pid
	: > "${temporary_path}"
	chmod 0600 "${temporary_path}"
	for unit_name in "${FISHER_UNIT}" "${NGINX_UNIT}"; do
		assert_safe_unit_name "${unit_name}"
		systemctl is-active --quiet "${unit_name}" || fail "shared service is not active: ${unit_name}"
		printf 'unit\t%s\n' "${unit_name}" >> "${temporary_path}"
		systemctl show "${unit_name}" \
			--property=ActiveState,SubState,MainPID,ExecMainStartTimestampMonotonic \
			--no-pager >> "${temporary_path}"
		systemctl cat "${unit_name}" --no-pager | sha256sum | awk '{print "unit_cat_sha256\t" $1}' \
			>> "${temporary_path}"
		main_pid="$(systemctl show "${unit_name}" --property=MainPID --value)"
		[[ "${main_pid}" =~ ^[1-9][0-9]*$ && -e "/proc/${main_pid}/exe" ]] \
			|| fail "shared service has no stable MainPID: ${unit_name}"
		sha256sum "$(readlink -f -- "/proc/${main_pid}/exe")" \
			| awk '{print "executable_sha256\t" $1}' >> "${temporary_path}"
	done
	ss -H -lunp 'sport = :24568' | grep -q . || fail 'Fisher UDP 24568 listener is missing'
	ss -H -lntp 'sport = :80' | grep -q . || fail 'nginx TCP 80 listener is missing'
	ss -H -lunp 'sport = :24568' | sha256sum | awk '{print "fisher_listener_sha256\t" $1}' \
		>> "${temporary_path}"
	ss -H -lntp 'sport = :80' | sha256sum | awk '{print "nginx_listener_sha256\t" $1}' \
		>> "${temporary_path}"
	find /etc/nginx -xdev -type f -exec sha256sum {} + | LC_ALL=C sort | sha256sum \
		| awk '{print "nginx_config_tree_sha256\t" $1}' >> "${temporary_path}"
	mv -T -- "${temporary_path}" "${output_path}"
}

verify_shared_host_unchanged() {
	local expected_path="$1"
	local observed_path="${expected_path}.observed"
	capture_shared_host_fingerprint "${observed_path}"
	cmp -s "${expected_path}" "${observed_path}" \
		|| fail 'Fisher or nginx changed during the JungleLaw deployment transaction'
	rm -f -- "${observed_path}"
}

write_tree_receipt() {
	local tree_root="$1"
	local output_path="$2"
	python3 - "${tree_root}" "${output_path}" <<'PY'
import hashlib
import os
import stat
import sys

root, output = sys.argv[1:]
root = os.path.realpath(root)
rows = []
for current, directories, files in os.walk(root, topdown=True, followlinks=False):
    directories.sort()
    files.sort()
    names = (["."] if current == root else []) + directories + files
    for name in names:
        path = current if name == "." else os.path.join(current, name)
        relative = os.path.relpath(path, root).replace(os.sep, "/")
        if relative == "." and current != root:
            continue
        metadata = os.lstat(path)
        if stat.S_ISLNK(metadata.st_mode) or not (stat.S_ISDIR(metadata.st_mode) or stat.S_ISREG(metadata.st_mode)):
            raise SystemExit("server tree contains a symlink or special file")
        kind = "dir" if stat.S_ISDIR(metadata.st_mode) else "file"
        digest = "-"
        if kind == "file":
            value = hashlib.sha256()
            with open(path, "rb") as source:
                for chunk in iter(lambda: source.read(1024 * 1024), b""):
                    value.update(chunk)
            digest = value.hexdigest()
        xattrs = []
        for attr_name in sorted(os.listxattr(path, follow_symlinks=False)):
            attr_value = os.getxattr(path, attr_name, follow_symlinks=False)
            xattrs.append(attr_name + "=" + hashlib.sha256(attr_value).hexdigest())
        rows.append("\t".join((relative, kind, format(stat.S_IMODE(metadata.st_mode), "04o"),
                              str(metadata.st_uid), str(metadata.st_gid), str(metadata.st_size),
                              digest, ",".join(xattrs))))
with open(output, "w", encoding="utf-8", newline="\n") as destination:
    destination.write("\n".join(rows) + "\n")
PY
	chmod 0600 "${output_path}"
}

write_acl_receipt() {
	local tree_root="$1"
	local output_path="$2"
	(
		cd "$(dirname -- "${tree_root}")"
		getfacl -R -p -n -- "$(basename -- "${tree_root}")"
	) > "${output_path}"
	chmod 0600 "${output_path}"
}

verify_server_tree_receipts() {
	local tree_root="$1"
	local expected_tree="$2"
	local expected_acl="$3"
	local scratch_root="$4"
	local observed_tree="${scratch_root}/server-tree.observed.tsv"
	local observed_acl="${scratch_root}/server-tree.observed.acl"
	write_tree_receipt "${tree_root}" "${observed_tree}"
	write_acl_receipt "${tree_root}" "${observed_acl}"
	cmp -s "${expected_tree}" "${observed_tree}" || fail 'canonical server tree receipt mismatch'
	cmp -s "${expected_acl}" "${observed_acl}" || fail 'canonical server recursive ACL receipt mismatch'
}

is_sensitive_restore_target() {
	case "$1" in
		"${ADMIN_STATE}"|"${ADMIN_CONFIG_ROOT}"|"${COMMAND_ROOT}"|"${EXPORT_ROOT}"|\
		"${SERVER_STATE_DIRECTORY:-__unset__}"|"${LE_RENEWAL_CONFIG}"|"${LE_LIVE_LINEAGE}"|\
		"${LE_ARCHIVE_LINEAGE}"|"${LE_STAGING_RENEWAL_CONFIG}"|"${LE_STAGING_LIVE_LINEAGE}"|\
		"${LE_STAGING_ARCHIVE_LINEAGE}"|"${LE_DEPLOY_HOOK}") return 0 ;;
		*) return 1 ;;
	esac
}

assert_allowlisted_restore_target() {
	case "$1" in
		"${ADMIN_CURRENT_LINK}"|"${ADMIN_STATE}"|"${ADMIN_CONFIG_ROOT}"|"${ADMIN_UNIT}"|\
		"${CERT_SERVICE}"|"${CERT_TIMER}"|"${CERT_HELPER}"|"${PUBLIC_443_DROPIN}"|\
		"${GAME_ELF}"|"${GAME_UNIT}"|"${GAME_STOP_HELPER}"|"${GAME_DROPIN}"|\
		"${COMMAND_ROOT}"|"${EXPORT_ROOT}"|"${SERVER_STATE_DIRECTORY:-__unset__}"|\
		"${LE_RENEWAL_CONFIG}"|"${LE_LIVE_LINEAGE}"|"${LE_ARCHIVE_LINEAGE}"|\
		"${LE_STAGING_RENEWAL_CONFIG}"|"${LE_STAGING_LIVE_LINEAGE}"|\
		"${LE_STAGING_ARCHIVE_LINEAGE}"|"${LE_DEPLOY_HOOK}") ;;
		*) fail "manifest contains a non-allowlisted restore target: $1" ;;
	esac
}

quarantine_target() {
	local target="$1"
	local backup_directory="$2"
	local quarantine_root="${backup_directory}/quarantine"
	local target_key
	local quarantine_path
	[[ -e "${target}" || -L "${target}" ]] || return 0
	install -d -o root -g root -m 0700 "${quarantine_root}"
	[[ "$(stat -c '%d' "${backup_directory}")" == "$(stat -c '%d' "$(dirname -- "${target}")")" ]] \
		|| fail 'backup quarantine and managed target must share one filesystem for atomic move-only preservation'
	target_key="$(printf '%s' "${target}" | sha256sum | awk '{print $1}')"
	quarantine_path="${quarantine_root}/${target_key}.$(date -u +%Y%m%dT%H%M%SZ).${BASHPID}"
	[[ ! -e "${quarantine_path}" && ! -L "${quarantine_path}" ]] \
		|| fail "quarantine path collision: ${quarantine_path}"
	mv -T -- "${target}" "${quarantine_path}"
	chown -h root:root "${quarantine_path}"
	if [[ -d "${quarantine_path}" && ! -L "${quarantine_path}" ]]; then
		chmod 0700 "${quarantine_path}"
	fi
}

remove_stateless_target() {
	local target="$1"
	if [[ -d "${target}" && ! -L "${target}" ]]; then
		fail "refusing recursive removal of unexpected directory at stateless path: ${target}"
	fi
	rm -f -- "${target}"
}

validate_node_release_source() {
	[[ "${NODE_ARCHIVE}" == /* && -f "${NODE_ARCHIVE}" ]] \
		|| fail 'Node archive must be an absolute existing ZIP file'
	[[ "${NODE_MANIFEST}" == /* && -f "${NODE_MANIFEST}" ]] \
		|| fail 'Node manifest must be an absolute existing JSON file'
	NODE_ARCHIVE="$(realpath -e -- "${NODE_ARCHIVE}")"
	NODE_MANIFEST="$(realpath -e -- "${NODE_MANIFEST}")"
	for node_receipt_file in "${NODE_ARCHIVE}" "${NODE_MANIFEST}"; do
		[[ "$(stat -c '%U' "${node_receipt_file}")" == 'root' ]] \
			|| fail "Node receipt must be root-owned: ${node_receipt_file}"
		node_receipt_mode="$(stat -c '%a' "${node_receipt_file}")"
		(( (8#${node_receipt_mode} & 022) == 0 )) \
			|| fail "Node receipt must not be group/other writable: ${node_receipt_file}"
	done
	[[ "${EXPECTED_NODE_SHA256}" =~ ^[A-Fa-f0-9]{64}$ ]] \
		|| fail 'expected Node ZIP SHA-256 is malformed'
	EXPECTED_NODE_SHA256="${EXPECTED_NODE_SHA256^^}"
	[[ "$(sha256sum "${NODE_ARCHIVE}" | awk '{print toupper($1)}')" == "${EXPECTED_NODE_SHA256}" ]] \
		|| fail 'Node ZIP SHA-256 does not match the explicitly approved value'
	unzip -tq "${NODE_ARCHIVE}" >/dev/null
	python3 - \
		"${NODE_MANIFEST}" \
		"${NODE_ARCHIVE}" \
		"${RELEASE_SOURCE}" \
		"${RELEASE_VERSION}" \
		"${EXPECTED_NODE_SHA256}" <<'PY'
import hashlib
import json
from pathlib import Path, PurePosixPath
import sys
import zipfile

manifest_path, archive_path, source_path, release_version, expected_archive_hash = sys.argv[1:]
manifest = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
if manifest.get("schema_version") != 1:
    raise SystemExit("unsupported Node manifest schema")
artifact = manifest.get("artifact", {})
if artifact.get("name") != release_version:
    raise SystemExit("release-version does not match Node manifest artifact name")
if artifact.get("version") != "1.2.0":
    raise SystemExit("Node manifest is not version 1.2.0")
if artifact.get("file") != Path(archive_path).name:
    raise SystemExit("Node manifest archive filename mismatch")
if str(artifact.get("sha256", "")).upper() != expected_archive_hash:
    raise SystemExit("Node manifest archive SHA-256 mismatch")
if int(artifact.get("size_bytes", -1)) != Path(archive_path).stat().st_size:
    raise SystemExit("Node manifest archive size mismatch")
if manifest.get("provenance", {}).get("project") != "zhanchengdashi":
    raise SystemExit("Node manifest project provenance mismatch")
runtime = manifest.get("runtime", {})
if runtime.get("test_files_included") is not False or runtime.get("npm_install_required") is not False:
    raise SystemExit("Node runtime manifest boundaries are invalid")

source_root = Path(source_path)
entries = manifest.get("entries", [])
if not entries:
    raise SystemExit("Node manifest has no runtime entries")
expected = {}
for entry in entries:
    raw_path = entry.get("path", "")
    parsed = PurePosixPath(raw_path)
    if not raw_path or parsed.is_absolute() or ".." in parsed.parts or raw_path in expected:
        raise SystemExit("unsafe or duplicate Node manifest entry")
    if (not isinstance(entry.get("size_bytes"), int) or entry["size_bytes"] < 0
            or len(str(entry.get("sha256", ""))) != 64
            or any(character not in "0123456789abcdefABCDEF" for character in entry["sha256"])):
        raise SystemExit("invalid Node manifest entry metadata")
    expected[raw_path] = entry
if "tools/admin_dashboard/server.mjs" not in expected:
    raise SystemExit("Node manifest is missing the dashboard entrypoint")

actual = {
    path.relative_to(source_root).as_posix(): path
    for path in source_root.rglob("*")
    if path.is_file()
}
if set(actual) != set(expected):
    raise SystemExit("extracted Node file set does not match manifest entries")

with zipfile.ZipFile(archive_path, mode="r") as archive:
    archive_entries = {}
    for info in archive.infolist():
        if info.is_dir():
            continue
        parsed = PurePosixPath(info.filename)
        unix_mode = (info.external_attr >> 16) & 0xFFFF
        if (not info.filename or parsed.is_absolute() or ".." in parsed.parts
                or info.filename in archive_entries or (unix_mode & 0o170000) == 0o120000):
            raise SystemExit("unsafe or duplicate Node ZIP entry")
        archive_entries[info.filename] = info
    if set(archive_entries) != set(expected):
        raise SystemExit("Node ZIP file set does not match manifest entries")
    for relative, info in archive_entries.items():
        content = archive.read(info)
        entry = expected[relative]
        if len(content) != int(entry.get("size_bytes", -1)):
            raise SystemExit("Node ZIP entry size mismatch: {}".format(relative))
        digest = hashlib.sha256(content).hexdigest().lower()
        if digest != str(entry.get("sha256", "")).lower():
            raise SystemExit("Node ZIP entry SHA-256 mismatch: {}".format(relative))

for relative, path in actual.items():
    content = path.read_bytes()
    entry = expected[relative]
    if len(content) != int(entry.get("size_bytes", -1)):
        raise SystemExit("Node entry size mismatch: {}".format(relative))
    digest = hashlib.sha256(content).hexdigest().lower()
    if digest != str(entry.get("sha256", "")).lower():
        raise SystemExit("Node entry SHA-256 mismatch: {}".format(relative))
PY
	"${NODE_BIN}" --check "${RELEASE_SOURCE}/tools/admin_dashboard/server.mjs"
	"${NODE_BIN}" "${RELEASE_SOURCE}/tools/admin_dashboard/server.mjs" --help >/dev/null
}

validate_game_release_source() {
	[[ "${GAME_ARCHIVE}" == /* && -f "${GAME_ARCHIVE}" ]] \
		|| fail 'game archive must be an absolute existing tar.gz file'
	GAME_ARCHIVE="$(realpath -e -- "${GAME_ARCHIVE}")"
	[[ "$(stat -c '%U' "${GAME_ARCHIVE}")" == 'root' ]] || fail 'game archive must be root-owned'
	game_archive_mode="$(stat -c '%a' "${GAME_ARCHIVE}")"
	(( (8#${game_archive_mode} & 022) == 0 )) || fail 'game archive must not be group/other writable'
	[[ "${EXPECTED_GAME_ARCHIVE_SHA256}" =~ ^[A-Fa-f0-9]{64}$ ]] \
		|| fail 'expected game archive SHA-256 is malformed'
	EXPECTED_GAME_ARCHIVE_SHA256="${EXPECTED_GAME_ARCHIVE_SHA256^^}"
	[[ "${EXPECTED_GAME_ARCHIVE_SHA256}" == "${APPROVED_GAME_ARCHIVE_SHA256}" ]] \
		|| fail 'expected game archive SHA-256 does not identify the approved v1.2.0 bundle'
	[[ "$(sha256sum "${GAME_ARCHIVE}" | awk '{print toupper($1)}')" == "${APPROVED_GAME_ARCHIVE_SHA256}" ]] \
		|| fail 'game archive SHA-256 does not match the approved v1.2.0 bundle'
	[[ "${GAME_RELEASE_SOURCE}" == /* && -d "${GAME_RELEASE_SOURCE}" ]] \
		|| fail 'game release source must be an absolute existing directory'
	GAME_RELEASE_SOURCE="$(realpath -e -- "${GAME_RELEASE_SOURCE}")"
	for required_game_file in \
		JungleLawServer.x86_64 \
		junglelaw-server.service \
		junglelaw-server-stop.sh \
		junglelaw-server-admin-dashboard.conf.example \
		manifest.json; do
		[[ -f "${GAME_RELEASE_SOURCE}/${required_game_file}" ]] \
			|| fail "game release source is missing ${required_game_file}"
	done
	if find "${GAME_RELEASE_SOURCE}" \( -type l -o -type b -o -type c -o -type p -o -type s \) \
		-print -quit | grep -q .; then
		fail 'game release source contains a symlink or special file'
	fi
	if find "${GAME_RELEASE_SOURCE}" ! -user root -print -quit | grep -q .; then
		fail 'game release source must be entirely root-owned after bundle verification'
	fi
	if find "${GAME_RELEASE_SOURCE}" -perm /0022 -print -quit | grep -q .; then
		fail 'game release source must not be writable by group or other users'
	fi
	[[ "${EXPECTED_GAME_SHA256}" =~ ^[A-Fa-f0-9]{64}$ ]] || fail 'expected game SHA-256 is malformed'
	EXPECTED_GAME_SHA256="${EXPECTED_GAME_SHA256^^}"
	[[ "${EXPECTED_GAME_SHA256}" == "${APPROVED_GAME_SHA256}" ]] \
		|| fail 'expected game SHA-256 does not identify the approved v1.2.0 candidate'
	[[ "$(sha256sum "${GAME_RELEASE_SOURCE}/JungleLawServer.x86_64" | awk '{print toupper($1)}')" == "${APPROVED_GAME_SHA256}" ]] \
		|| fail 'game ELF SHA-256 does not match the approved v1.2.0 candidate'
	[[ "$(sha256sum "${GAME_RELEASE_SOURCE}/junglelaw-server.service" | awk '{print toupper($1)}')" == "${APPROVED_GAME_UNIT_SHA256}" ]] \
		|| fail 'game systemd unit SHA-256 does not match the approved v1.2.0 candidate'
	[[ "$(sha256sum "${GAME_RELEASE_SOURCE}/junglelaw-server-stop.sh" | awk '{print toupper($1)}')" == "${APPROVED_GAME_STOP_HELPER_SHA256}" ]] \
		|| fail 'game stop helper SHA-256 does not match the approved v1.2.0 candidate'
	[[ "$(sha256sum "${GAME_RELEASE_SOURCE}/junglelaw-server-admin-dashboard.conf.example" | awk '{print toupper($1)}')" == "${APPROVED_GAME_DROPIN_SHA256}" ]] \
		|| fail 'game admin drop-in SHA-256 does not match the approved v1.2.0 candidate'
	bash -n "${GAME_RELEASE_SOURCE}/junglelaw-server-stop.sh"
	python3 - \
		"${GAME_RELEASE_SOURCE}/manifest.json" \
		"${GAME_ARCHIVE}" \
		"${APPROVED_GAME_ARTIFACT_ID}" \
		"${APPROVED_GAME_VERSION}" \
		"${APPROVED_GAME_SHA256}" \
		"${APPROVED_GAME_UNIT_SHA256}" \
		"${APPROVED_GAME_STOP_HELPER_SHA256}" \
		"${APPROVED_GAME_DROPIN_SHA256}" <<'PY'
import json
from pathlib import Path, PurePosixPath
import sys
import tarfile

manifest_path, archive_path, artifact_id, approved_version, elf_hash, unit_hash, helper_hash, dropin_hash = sys.argv[1:]
manifest_bytes = Path(manifest_path).read_bytes()
manifest = json.loads(manifest_bytes.decode("utf-8"))
if manifest.get("artifact_id") != artifact_id or manifest.get("version") != approved_version:
    raise SystemExit("unexpected game artifact identity")
if manifest.get("local_release_gate_passed") is not True:
    raise SystemExit("game artifact local release gate is not passed")
files = {entry.get("path"): entry.get("sha256", "").upper() for entry in manifest.get("files", [])}
expected = {
    "JungleLawServer.x86_64": elf_hash,
    "junglelaw-server.service": unit_hash,
    "junglelaw-server-stop.sh": helper_hash,
    "junglelaw-server-admin-dashboard.conf.example": dropin_hash,
}
if any(files.get(path) != value for path, value in expected.items()):
    raise SystemExit("game artifact manifest hash mismatch")
expected_root = approved_version
expected_manifest_member = expected_root + "/manifest.json"
with tarfile.open(archive_path, mode="r:gz") as archive:
    manifest_member = None
    root_member = None
    seen_members = set()
    for member in archive.getmembers():
        parsed = PurePosixPath(member.name)
        if (not member.name or parsed.is_absolute() or ".." in parsed.parts
                or str(parsed) != member.name or member.name in seen_members
                or member.isdev() or member.isfifo() or member.islnk() or member.issym()):
            raise SystemExit("unsafe game archive member")
        seen_members.add(member.name)
        if not (member.isfile() or member.isdir()):
            raise SystemExit("unsupported game archive member type")
        if member.name == expected_root:
            if not member.isdir():
                raise SystemExit("game archive exact version root is not a directory")
            root_member = member
        elif not member.name.startswith(expected_root + "/"):
            raise SystemExit("game archive member is outside the exact version root")
        if member.name == expected_manifest_member:
            manifest_member = member
    if root_member is None:
        raise SystemExit("game archive exact version root is missing")
    if manifest_member is None or not manifest_member.isfile():
        raise SystemExit("game archive manifest member is missing")
    extracted = archive.extractfile(manifest_member)
    if extracted is None or extracted.read() != manifest_bytes:
        raise SystemExit("extracted game manifest is not bound to the approved archive")
PY
}

atomic_install_game_component() {
	local source_path="$1"
	local destination_path="$2"
	local mode="$3"
	local expected_sha="$4"
	local temporary_path="${destination_path}.junglelaw-v1.2.0.new"
	[[ ! -e "${temporary_path}" && ! -L "${temporary_path}" ]] \
		|| fail "temporary game component already exists: ${temporary_path}"
	install -o root -g root -m "${mode}" "${source_path}" "${temporary_path}"
	[[ "$(sha256sum "${temporary_path}" | awk '{print toupper($1)}')" == "${expected_sha}" ]] \
		|| fail "staged game component hash mismatch: ${destination_path}"
	mv -T -- "${temporary_path}" "${destination_path}"
	[[ "$(sha256sum "${destination_path}" | awk '{print toupper($1)}')" == "${expected_sha}" ]] \
		|| fail "installed game component hash mismatch: ${destination_path}"
}

create_backup() {
	local backup_root="$1"
	local release_version="$2"
	local authority="$3"
	local server_state_directory="$4"
	local game_active="$5"
	local dashboard_active="$6"
	local game_enabled="$7"
	local dashboard_enabled="$8"
	local timer_active="$9"
	local timer_enabled="${10}"
	local renew_active="${11}"
	local stamp
	local backup_id
	local backup_directory
	local manifest
	local list_file
	local archive
	local junglelaw_root_acl
	local server_tree_receipt
	local server_acl_receipt
	local shared_fingerprint
	local restore_drill
	local restored_server
	local receipt_hash
	stamp="$(date -u +%Y%m%dT%H%M%SZ)"
	backup_id="admin-dashboard-predeploy-${release_version}-${stamp}"
	backup_directory="${backup_root}/${backup_id}"
	[[ ! -e "${backup_directory}" ]] || fail "backup directory already exists: ${backup_directory}"
	install -d -o root -g root -m 0700 "${backup_directory}"
	manifest="${backup_directory}/manifest.tsv"
	list_file="${backup_directory}/archive-paths.bin"
	archive="${backup_directory}/payload.tar"
	junglelaw_root_acl="${backup_directory}/junglelaw-root.acl"
	: > "${manifest}"
	: > "${list_file}"
	chmod 0600 "${manifest}" "${list_file}"
	printf 'schema\t2\n' >> "${manifest}"
	printf 'backup_id\t%s\n' "${backup_id}" >> "${manifest}"
	printf 'release_version\t%s\n' "${release_version}" >> "${manifest}"
	printf 'authority_path\t%s\n' "${authority}" >> "${manifest}"
	printf 'server_state_directory\t%s\n' "${server_state_directory}" >> "${manifest}"
	printf 'game_was_active\t%s\n' "${game_active}" >> "${manifest}"
	printf 'dashboard_was_active\t%s\n' "${dashboard_active}" >> "${manifest}"
	printf 'game_was_enabled\t%s\n' "${game_enabled}" >> "${manifest}"
	printf 'dashboard_was_enabled\t%s\n' "${dashboard_enabled}" >> "${manifest}"
	printf 'cert_timer_was_active\t%s\n' "${timer_active}" >> "${manifest}"
	printf 'cert_timer_was_enabled\t%s\n' "${timer_enabled}" >> "${manifest}"
	printf 'cert_renew_was_active\t%s\n' "${renew_active}" >> "${manifest}"
	printf 'fisher_unit\t%s\n' "${FISHER_UNIT}" >> "${manifest}"
	printf 'nginx_unit\t%s\n' "${NGINX_UNIT}" >> "${manifest}"
	getfacl -p -n -- "${JUNGLELAW_ROOT}" > "${junglelaw_root_acl}"
	chmod 0600 "${junglelaw_root_acl}"
	receipt_hash="$(sha256_file_lower "${junglelaw_root_acl}")"
	printf 'junglelaw_root_acl_sha256\t%s\n' "${receipt_hash}" >> "${manifest}"

	record_backup_path "${manifest}" "${list_file}" "${ADMIN_CURRENT_LINK}"
	record_backup_path "${manifest}" "${list_file}" "${ADMIN_STATE}"
	record_backup_path "${manifest}" "${list_file}" "${ADMIN_CONFIG_ROOT}"
	record_backup_path "${manifest}" "${list_file}" "${ADMIN_UNIT}"
	record_backup_path "${manifest}" "${list_file}" "${CERT_SERVICE}"
	record_backup_path "${manifest}" "${list_file}" "${CERT_TIMER}"
	record_backup_path "${manifest}" "${list_file}" "${CERT_HELPER}"
	record_backup_path "${manifest}" "${list_file}" "${PUBLIC_443_DROPIN}"
	record_backup_path "${manifest}" "${list_file}" "${GAME_ELF}"
	record_backup_path "${manifest}" "${list_file}" "${GAME_UNIT}"
	record_backup_path "${manifest}" "${list_file}" "${GAME_STOP_HELPER}"
	record_backup_path "${manifest}" "${list_file}" "${GAME_DROPIN}"
	record_backup_path "${manifest}" "${list_file}" "${COMMAND_ROOT}"
	record_backup_path "${manifest}" "${list_file}" "${EXPORT_ROOT}"
	record_backup_path "${manifest}" "${list_file}" "${server_state_directory}"
	record_backup_path "${manifest}" "${list_file}" "${LE_RENEWAL_CONFIG}"
	record_backup_path "${manifest}" "${list_file}" "${LE_LIVE_LINEAGE}"
	record_backup_path "${manifest}" "${list_file}" "${LE_ARCHIVE_LINEAGE}"
	record_backup_path "${manifest}" "${list_file}" "${LE_STAGING_RENEWAL_CONFIG}"
	record_backup_path "${manifest}" "${list_file}" "${LE_STAGING_LIVE_LINEAGE}"
	record_backup_path "${manifest}" "${list_file}" "${LE_STAGING_ARCHIVE_LINEAGE}"
	record_backup_path "${manifest}" "${list_file}" "${LE_DEPLOY_HOOK}"

	receipt_hash="$(sha256_file_lower "${authority}")"
	printf 'authority_sha256\t%s\n' "${receipt_hash}" >> "${manifest}"
	server_tree_receipt="${backup_directory}/server-tree.tsv"
	server_acl_receipt="${backup_directory}/server-tree.acl"
	write_tree_receipt "${server_state_directory}" "${server_tree_receipt}"
	write_acl_receipt "${server_state_directory}" "${server_acl_receipt}"
	receipt_hash="$(sha256_file_lower "${server_tree_receipt}")"
	printf 'server_tree_sha256\t%s\n' "${receipt_hash}" >> "${manifest}"
	receipt_hash="$(sha256_file_lower "${server_acl_receipt}")"
	printf 'server_acl_sha256\t%s\n' "${receipt_hash}" >> "${manifest}"
	if [[ -f "${GAME_ELF}" ]]; then
		receipt_hash="$(sha256_file_lower "${GAME_ELF}")"
		printf 'game_elf_sha256\t%s\n' "${receipt_hash}" >> "${manifest}"
	else
		printf 'game_elf_sha256\tabsent\n' >> "${manifest}"
	fi
	for critical_spec in \
		"game_unit_sha256|${GAME_UNIT}" \
		"game_stop_helper_sha256|${GAME_STOP_HELPER}" \
		"game_dropin_sha256|${GAME_DROPIN}"; do
		critical_key="${critical_spec%%|*}"
		critical_path="${critical_spec#*|}"
		if [[ -f "${critical_path}" ]]; then
			receipt_hash="$(sha256_file_lower "${critical_path}")"
			printf '%s\t%s\n' "${critical_key}" "${receipt_hash}" >> "${manifest}"
		else
			printf '%s\tabsent\n' "${critical_key}" >> "${manifest}"
		fi
	done

	tar --create --acls --xattrs --xattrs-include='*' --numeric-owner --directory / \
		--null --files-from "${list_file}" --file "${archive}"
	chmod 0600 "${archive}"
	(cd "${backup_directory}" && sha256sum payload.tar > payload.tar.sha256)
	chmod 0600 "${backup_directory}/payload.tar.sha256"
	tar --list --file "${archive}" >/dev/null
	validate_backup_archive "${manifest}" "${archive}"
	shared_fingerprint="${backup_directory}/shared-host.fingerprint"
	capture_shared_host_fingerprint "${shared_fingerprint}"
	receipt_hash="$(sha256_file_lower "${shared_fingerprint}")"
	printf 'shared_host_fingerprint_sha256\t%s\n' "${receipt_hash}" >> "${manifest}"

	restore_drill="${backup_directory}/restore-drill"
	install -d -o root -g root -m 0700 "${restore_drill}"
	tar --extract --acls --xattrs --xattrs-include='*' --numeric-owner --directory "${restore_drill}" --file "${archive}"
	restored_server="${restore_drill}/${server_state_directory#/}"
	[[ -d "${restored_server}" ]] || fail 'isolated backup restore drill did not restore the canonical server directory'
	verify_server_tree_receipts "${restored_server}" "${server_tree_receipt}" "${server_acl_receipt}" "${backup_directory}"
	[[ "$(sha256sum "${restore_drill}/${authority#/}" | awk '{print $1}')" == \
		"$(manifest_value "${manifest}" authority_sha256)" ]] \
		|| fail 'isolated backup restore drill authority checksum mismatch'
	(
		cd "${backup_directory}"
		sha256sum manifest.tsv payload.tar payload.tar.sha256 junglelaw-root.acl \
			server-tree.tsv server-tree.acl shared-host.fingerprint > receipt.sha256
		sha256sum --check receipt.sha256 >/dev/null
	)
	chmod 0600 "${backup_directory}/receipt.sha256"
	rm -f -- "${list_file}"
	printf '%s\n' "${backup_id}" > "${backup_directory}/BACKUP_COMPLETE"
	chmod 0600 "${backup_directory}/BACKUP_COMPLETE"
	BACKUP_DIRECTORY_CREATED="${backup_directory}"
	TRANSACTION_BACKUP_COMPLETE=1
}

validate_backup_receipt() {
	local backup_directory="$1"
	local manifest="${backup_directory}/manifest.tsv"
	local archive="${backup_directory}/payload.tar"
	local checksum="${backup_directory}/payload.tar.sha256"
	local receipt_checksum="${backup_directory}/receipt.sha256"
	[[ -f "${manifest}" && -f "${archive}" && -f "${checksum}" \
		&& -f "${receipt_checksum}" && -f "${backup_directory}/BACKUP_COMPLETE" ]] \
		|| fail 'backup receipt is incomplete'
	[[ "$(manifest_value "${manifest}" schema)" == '2' ]] || fail 'unsupported backup schema'
	[[ "$(basename -- "${backup_directory}")" == "$(manifest_value "${manifest}" backup_id)" ]] \
		|| fail 'backup directory name does not match the exact manifest backup id'
	[[ "$(tr -d '\r\n' < "${backup_directory}/BACKUP_COMPLETE")" == \
		"$(manifest_value "${manifest}" backup_id)" ]] || fail 'backup completion sentinel mismatch'
	(cd "${backup_directory}" && sha256sum --check "$(basename -- "${checksum}")" >/dev/null)
	(cd "${backup_directory}" && sha256sum --check "$(basename -- "${receipt_checksum}")" >/dev/null)
	[[ "$(sha256sum "${backup_directory}/junglelaw-root.acl" | awk '{print $1}')" == \
		"$(manifest_value "${manifest}" junglelaw_root_acl_sha256)" ]] \
		|| fail 'authoritative-root ACL receipt hash mismatch'
	[[ "$(sha256sum "${backup_directory}/server-tree.tsv" | awk '{print $1}')" == \
		"$(manifest_value "${manifest}" server_tree_sha256)" ]] \
		|| fail 'server tree receipt hash mismatch'
	[[ "$(sha256sum "${backup_directory}/server-tree.acl" | awk '{print $1}')" == \
		"$(manifest_value "${manifest}" server_acl_sha256)" ]] \
		|| fail 'server ACL receipt hash mismatch'
	[[ "$(sha256sum "${backup_directory}/shared-host.fingerprint" | awk '{print $1}')" == \
		"$(manifest_value "${manifest}" shared_host_fingerprint_sha256)" ]] \
		|| fail 'shared-host fingerprint receipt hash mismatch'
	tar --list --file "${archive}" >/dev/null
	validate_backup_archive "${manifest}" "${archive}"
}

freeze_managed_services() {
	stop_if_active junglelaw-admin-dashboard-cert-renew.timer
	stop_if_active junglelaw-admin-dashboard-cert-renew.service
	stop_if_active junglelaw-admin-dashboard.service
	assert_pending_empty 'pre-game-stop freeze'
	stop_if_active junglelaw-server.service
	assert_pending_empty 'post-game-stop freeze'
	for frozen_unit in \
		junglelaw-admin-dashboard-cert-renew.timer \
		junglelaw-admin-dashboard-cert-renew.service \
		junglelaw-admin-dashboard.service \
		junglelaw-server.service; do
		if systemctl is-active --quiet "${frozen_unit}"; then
			fail "managed unit is still active after freeze: ${frozen_unit}"
		fi
	done
}

restore_service_baseline() {
	local unit_name="$1"
	local active_state="$2"
	local enabled_state="$3"
	restore_enable_state "${unit_name}" "${enabled_state}"
	if [[ "${active_state}" == '1' ]]; then
		systemctl start "${unit_name}"
		systemctl is-active --quiet "${unit_name}" \
			|| fail "restored service failed to start: ${unit_name}"
	else
		stop_if_active "${unit_name}"
	fi
}

restore_prechange_service_states() {
	systemctl daemon-reload
	restore_service_baseline junglelaw-server.service "${GAME_WAS_ACTIVE}" "${GAME_WAS_ENABLED}"
	restore_service_baseline junglelaw-admin-dashboard.service "${DASHBOARD_WAS_ACTIVE}" "${DASHBOARD_WAS_ENABLED}"
	restore_service_baseline junglelaw-admin-dashboard-cert-renew.timer \
		"${CERT_TIMER_WAS_ACTIVE}" "${CERT_TIMER_WAS_ENABLED}"
	if [[ "${CERT_RENEW_WAS_ACTIVE}" == '1' ]]; then
		systemctl start junglelaw-admin-dashboard-cert-renew.service
	fi
}

force_fail_closed_managed_services() {
	local failure=0
	local unit_name
	for unit_name in \
		junglelaw-admin-dashboard-cert-renew.timer \
		junglelaw-admin-dashboard-cert-renew.service \
		junglelaw-admin-dashboard.service \
		junglelaw-server.service; do
		if systemctl is-active --quiet "${unit_name}"; then
			systemctl stop "${unit_name}" >/dev/null 2>&1 || failure=1
		fi
		if systemctl is-active --quiet "${unit_name}"; then
			failure=1
		fi
	done
	return "${failure}"
}

stage_backup_for_restore() {
	local backup_directory="$1"
	local manifest="${backup_directory}/manifest.tsv"
	local stage_root="${backup_directory}/rollback-stage.$(date -u +%Y%m%dT%H%M%SZ).${BASHPID}"
	local staged_server
	STAGED_RESTORE_ROOT=''
	install -d -o root -g root -m 0700 "${stage_root}"
	tar --extract --acls --xattrs --xattrs-include='*' --numeric-owner --directory "${stage_root}" \
		--file "${backup_directory}/payload.tar"
	staged_server="${stage_root}/${SERVER_STATE_DIRECTORY#/}"
	[[ -d "${staged_server}" ]] || fail 'rollback stage is missing the canonical server directory'
	verify_server_tree_receipts "${staged_server}" \
		"${backup_directory}/server-tree.tsv" "${backup_directory}/server-tree.acl" "${stage_root}"
	[[ "$(sha256sum "${stage_root}/${AUTHORITY_PATH#/}" | awk '{print $1}')" == \
		"$(manifest_value "${manifest}" authority_sha256)" ]] \
		|| fail 'rollback stage authority checksum mismatch'
	STAGED_RESTORE_ROOT="${stage_root}"
}

restore_backup_transaction() {
	local backup_directory="$1"
	local manifest="${backup_directory}/manifest.tsv"
	local stage_root
	local entry_type
	local entry_state
	local entry_path
	local staged_path
	local observed_root_acl="${backup_directory}/junglelaw-root.observed.acl"
	[[ "${AUTHORIZE_STATE_DIRECTORY_QUARANTINE}" == '1' ]] \
		|| fail 'state-directory quarantine authorization is required for restore'
	validate_backup_receipt "${backup_directory}"
	AUTHORITY_PATH="$(manifest_value "${manifest}" authority_path)"
	SERVER_STATE_DIRECTORY="$(manifest_value "${manifest}" server_state_directory)"
	case "${AUTHORITY_PATH}|${SERVER_STATE_DIRECTORY}" in
		/var/lib/junglelaw/*/server/player_accounts.json\|/var/lib/junglelaw/*/server) ;;
		*) fail 'backup authority or server directory is outside the approved boundary' ;;
	esac
	[[ "${AUTHORITY_PATH}" == "${SERVER_STATE_DIRECTORY}/player_accounts.json" ]] \
		|| fail 'backup authority is not inside its canonical server directory'
	FISHER_UNIT="$(manifest_value "${manifest}" fisher_unit)"
	NGINX_UNIT="$(manifest_value "${manifest}" nginx_unit)"
	assert_safe_unit_name "${FISHER_UNIT}"
	assert_safe_unit_name "${NGINX_UNIT}"
	if [[ -n "${ROLLBACK_STAGE_ROOT}" && -d "${ROLLBACK_STAGE_ROOT}" ]]; then
		stage_root="${ROLLBACK_STAGE_ROOT}"
	else
		stage_backup_for_restore "${backup_directory}"
		stage_root="${STAGED_RESTORE_ROOT}"
	fi

	while IFS=$'\t' read -r entry_type entry_state entry_path; do
		[[ "${entry_type}" == 'path' ]] || continue
		[[ "${entry_state}" == 'present' || "${entry_state}" == 'absent' ]] \
			|| fail "invalid path state in manifest: ${entry_state}"
		assert_allowlisted_restore_target "${entry_path}"
		staged_path="${stage_root}/${entry_path#/}"
		if is_sensitive_restore_target "${entry_path}"; then
			quarantine_target "${entry_path}" "${backup_directory}"
		else
			remove_stateless_target "${entry_path}"
		fi
		if [[ "${entry_state}" == 'present' ]]; then
			[[ -e "${staged_path}" || -L "${staged_path}" ]] \
				|| fail "rollback stage is missing a present path: ${entry_path}"
			[[ -d "$(dirname -- "${entry_path}")" ]] \
				|| install -d -o root -g root -m 0755 "$(dirname -- "${entry_path}")"
			mv -T -- "${staged_path}" "${entry_path}"
		fi
	done < "${manifest}"

	setfacl --restore="${backup_directory}/junglelaw-root.acl"
	getfacl -p -n -- "${JUNGLELAW_ROOT}" > "${observed_root_acl}"
	chmod 0600 "${observed_root_acl}"
	cmp -s "${backup_directory}/junglelaw-root.acl" "${observed_root_acl}" \
		|| fail 'authoritative-root ACL was not restored exactly'
	[[ -f "${AUTHORITY_PATH}" ]] || fail 'authority file was not restored'
	[[ "$(sha256sum "${AUTHORITY_PATH}" | awk '{print $1}')" == \
		"$(manifest_value "${manifest}" authority_sha256)" ]] \
		|| fail 'restored authority checksum does not match the backup receipt'
	verify_server_tree_receipts "${SERVER_STATE_DIRECTORY}" \
		"${backup_directory}/server-tree.tsv" "${backup_directory}/server-tree.acl" "${backup_directory}"

	for critical_spec in \
		"game_elf_sha256|${GAME_ELF}" \
		"game_unit_sha256|${GAME_UNIT}" \
		"game_stop_helper_sha256|${GAME_STOP_HELPER}" \
		"game_dropin_sha256|${GAME_DROPIN}"; do
		critical_key="${critical_spec%%|*}"
		critical_path="${critical_spec#*|}"
		expected_critical_sha="$(manifest_value "${manifest}" "${critical_key}")"
		if [[ "${expected_critical_sha}" == 'absent' ]]; then
			[[ ! -e "${critical_path}" && ! -L "${critical_path}" ]] \
				|| fail "path expected absent after rollback: ${critical_path}"
		else
			[[ -f "${critical_path}" ]] || fail "critical game file was not restored: ${critical_path}"
			[[ "$(sha256sum "${critical_path}" | awk '{print $1}')" == "${expected_critical_sha}" ]] \
				|| fail "critical game file checksum mismatch after rollback: ${critical_path}"
		fi
	done

	verify_shared_host_unchanged "${backup_directory}/shared-host.fingerprint"
	systemctl daemon-reload
	restore_service_baseline junglelaw-server.service \
		"$(manifest_value "${manifest}" game_was_active)" \
		"$(manifest_value "${manifest}" game_was_enabled)"
	restore_service_baseline junglelaw-admin-dashboard.service \
		"$(manifest_value "${manifest}" dashboard_was_active)" \
		"$(manifest_value "${manifest}" dashboard_was_enabled)"
	if [[ "$(manifest_value "${manifest}" dashboard_was_active)" == '1' ]]; then
		[[ -f "${CERT_ENV}" ]] || fail 'restored active dashboard has no certificate health configuration'
		RESTORED_PUBLIC_IP="$(grep -E '^JUNGLELAW_CERT_IP=' "${CERT_ENV}" | tail -n 1 | cut -d= -f2-)"
		RESTORED_DASHBOARD_PORT="$(grep -E '^JUNGLELAW_CERT_HEALTH_PORT=' "${CERT_ENV}" | tail -n 1 | cut -d= -f2-)"
		validate_public_ipv4 "${RESTORED_PUBLIC_IP}" || fail 'restored dashboard certificate IP is invalid'
		[[ "${RESTORED_DASHBOARD_PORT}" == '8443' || "${RESTORED_DASHBOARD_PORT}" == '443' ]] \
			|| fail 'restored dashboard health port is not approved'
		curl --fail --silent --show-error --max-time 15 --output /dev/null \
			--connect-to "${RESTORED_PUBLIC_IP}:${RESTORED_DASHBOARD_PORT}:127.0.0.1:${RESTORED_DASHBOARD_PORT}" \
			"https://${RESTORED_PUBLIC_IP}:${RESTORED_DASHBOARD_PORT}/api/health" \
			|| fail 'restored dashboard failed certificate-verified health acceptance'
	fi
	restore_service_baseline junglelaw-admin-dashboard-cert-renew.timer \
		"$(manifest_value "${manifest}" cert_timer_was_active)" \
		"$(manifest_value "${manifest}" cert_timer_was_enabled)"
	if [[ "$(manifest_value "${manifest}" cert_renew_was_active)" == '1' ]]; then
		systemctl start junglelaw-admin-dashboard-cert-renew.service
	fi
}

transaction_error_handler() {
	local status="$1"
	local line_number="$2"
	trap - ERR
	set +e
	printf 'FAIL: %s transaction failed at line %s (status %s)\n' \
		"${TRANSACTION_ACTION:-unknown}" "${line_number}" "${status}" >&2
	if [[ "${TRANSACTION_ACTION}" == 'prepare' && "${TRANSACTION_BASELINE_CAPTURED}" == '1' ]]; then
		if [[ "${TRANSACTION_BACKUP_COMPLETE}" == '1' && -n "${BACKUP_DIRECTORY_CREATED}" ]]; then
			TRANSACTION_ROLLING_BACK=1
			(set -Eeuo pipefail; freeze_managed_services; restore_backup_transaction "${BACKUP_DIRECTORY_CREATED}")
			recovery_status=$?
			if [[ "${recovery_status}" -eq 0 ]]; then
				printf 'RECOVERED: failed prepare restored exact backup %s\n' \
					"${BACKUP_DIRECTORY_CREATED}" >&2
			else
				if force_fail_closed_managed_services; then
					printf 'NOT READY: automatic prepare recovery failed; managed services are fail-closed; receipt=%s\n' \
						"${BACKUP_DIRECTORY_CREATED}" >&2
				else
					printf 'CRITICAL: automatic prepare recovery and fail-closed stop both failed; receipt=%s\n' \
						"${BACKUP_DIRECTORY_CREATED}" >&2
				fi
			fi
		else
			(set -Eeuo pipefail; restore_prechange_service_states)
			recovery_status=$?
			if [[ "${recovery_status}" -eq 0 ]]; then
				printf '%s\n' 'RECOVERED: pre-backup service baseline restored' >&2
			else
				if force_fail_closed_managed_services; then
					printf '%s\n' 'NOT READY: pre-backup baseline recovery failed; managed services are fail-closed' >&2
				else
					printf '%s\n' 'CRITICAL: pre-backup recovery and fail-closed stop both failed' >&2
				fi
			fi
		fi
	elif [[ "${TRANSACTION_ACTION}" == 'activate' && "${TRANSACTION_BASELINE_CAPTURED}" == '1' ]]; then
		stop_if_active junglelaw-admin-dashboard-cert-renew.timer
		stop_if_active junglelaw-admin-dashboard.service
		(set -Eeuo pipefail; restore_prechange_service_states)
		recovery_status=$?
		if [[ "${recovery_status}" -eq 0 ]]; then
			printf '%s\n' 'RECOVERED: activation failure restored service enabled/active baselines; state retained' >&2
		else
			if force_fail_closed_managed_services; then
				printf '%s\n' 'NOT READY: activation baseline recovery failed; managed services are fail-closed and state is retained' >&2
			else
				printf '%s\n' 'CRITICAL: activation recovery and fail-closed stop both failed; state is retained' >&2
			fi
		fi
	else
		if force_fail_closed_managed_services; then
			printf '%s\n' 'NOT READY: rollback failed; quarantine and failed scene retained; managed services are fail-closed' >&2
		else
			printf '%s\n' 'CRITICAL: rollback and fail-closed stop both failed; quarantine and failed scene retained' >&2
		fi
	fi
	exit "${status}"
}

prepare_install() {
	validate_node_runtime
	[[ "${RELEASE_VERSION}" =~ ^[A-Za-z0-9._-]+$ ]] || fail 'invalid release version'
	[[ "${DASHBOARD_PORT}" == '8443' || "${DASHBOARD_PORT}" == '443' ]] \
		|| fail 'dashboard port must be exactly 8443 or 443'
	[[ "${RELEASE_SOURCE}" == /* && -d "${RELEASE_SOURCE}" ]] || fail 'release source must be an absolute existing directory'
	RELEASE_SOURCE="$(realpath -e -- "${RELEASE_SOURCE}")"
	[[ -f "${RELEASE_SOURCE}/tools/admin_dashboard/server.mjs" ]] || fail 'release source is missing tools/admin_dashboard/server.mjs'
	[[ -d "${RELEASE_SOURCE}/deploy/linux" ]] || fail 'release source is missing its deployment overlay'
	[[ "$(realpath -e -- "${RELEASE_SOURCE}/deploy/linux")" == "${SOURCE_DIRECTORY}" ]] \
		|| fail 'installer must execute from the deployment overlay inside the verified Node release source'
	if find "${RELEASE_SOURCE}" \( -type l -o -type b -o -type c -o -type p -o -type s \) \
		-print -quit | grep -q .; then
		fail 'release source contains a symlink or special file'
	fi
	if find "${RELEASE_SOURCE}" ! -user root -print -quit | grep -q .; then
		fail 'release source must be entirely root-owned after artifact verification'
	fi
	if find "${RELEASE_SOURCE}" -perm /0022 -print -quit | grep -q .; then
		fail 'release source must not be writable by group or other users'
	fi
	for source_file in \
		junglelaw-admin-dashboard.env.example \
		junglelaw-admin-dashboard.service.example \
		junglelaw-admin-dashboard-cert-renew \
		junglelaw-admin-dashboard-cert-renew.service.example \
		junglelaw-admin-dashboard-cert-renew.timer.example \
		junglelaw-admin-dashboard-public-443.conf.example; do
		[[ -f "${SOURCE_DIRECTORY}/${source_file}" ]] || fail "deployment source is missing: ${source_file}"
	done
	[[ "$(sha256sum "${SOURCE_DIRECTORY}/junglelaw-admin-dashboard-public-443.conf.example" \
		| awk '{print toupper($1)}')" == "${APPROVED_PUBLIC_443_DROPIN_SHA256}" ]] \
		|| fail 'public 443 drop-in template hash does not match the approved deployment overlay'
	bash -n "${SOURCE_DIRECTORY}/junglelaw-admin-dashboard-cert-renew"
	validate_node_release_source
	validate_game_release_source

	[[ "${BACKUP_ROOT}" == /* && -d "${BACKUP_ROOT}" ]] || fail 'backup root must be an absolute existing directory'
	BACKUP_ROOT="$(realpath -e -- "${BACKUP_ROOT}")"
	[[ "${BACKUP_ROOT}" == '/var/backups/junglelaw-admin-dashboard' ]] \
		|| fail 'backup root must equal the approved staging backup root'
	case "${BACKUP_ROOT}" in
		/|/opt/junglelaw-admin|/opt/junglelaw-admin/*|/var/lib/junglelaw|/var/lib/junglelaw/*|/etc|/etc/*)
			fail "unsafe backup root: ${BACKUP_ROOT}" ;;
	esac
	[[ "$(stat -c '%U' "${BACKUP_ROOT}")" == 'root' ]] || fail 'backup root must be owned by root'
	backup_mode="$(stat -c '%a' "${BACKUP_ROOT}")"
	(( (8#${backup_mode} & 077) == 0 )) || fail 'backup root must not grant group/other access'
	[[ "$(stat -c '%d' "${BACKUP_ROOT}")" == "$(stat -c '%d' /)" ]] \
		|| fail 'backup root must share the root filesystem for atomic quarantine and restore moves'

	[[ "${AUTHORITY_PATH}" == /* && -f "${AUTHORITY_PATH}" ]] || fail 'authority path must be an absolute existing file'
	AUTHORITY_PATH="$(realpath -e -- "${AUTHORITY_PATH}")"
	case "${AUTHORITY_PATH}" in
		/var/lib/junglelaw/*/server/player_accounts.json) ;;
		*) fail 'authority path must resolve below /var/lib/junglelaw and end in /server/player_accounts.json' ;;
	esac
	SERVER_STATE_DIRECTORY="$(realpath -e -- "$(dirname -- "${AUTHORITY_PATH}")")"
	case "${SERVER_STATE_DIRECTORY}" in
		/var/lib/junglelaw/*/server) ;;
		*) fail 'authoritative server directory is outside the approved /var/lib/junglelaw boundary' ;;
	esac
	[[ "${AUTHORITY_PATH}" == "${SERVER_STATE_DIRECTORY}/player_accounts.json" ]] \
		|| fail 'authority path is not the canonical player_accounts.json inside the server directory'
	[[ "${ACME_WEBROOT}" == /* && -d "${ACME_WEBROOT}" ]] || fail 'ACME webroot must be an absolute existing directory'
	ACME_WEBROOT="$(realpath -e -- "${ACME_WEBROOT}")"
	[[ "${ACME_WEBROOT}" != '/' ]] || fail 'ACME webroot must not be /'
	[[ "${ACME_WEBROOT}" =~ ^/[A-Za-z0-9._/-]+$ ]] \
		|| fail 'ACME webroot contains characters unsafe for a systemd path directive'
	validate_public_ipv4 "${PUBLIC_IP}" || fail 'public IP must be a globally routable IPv4 address'
	validate_junglelaw_root_acl 0
	[[ "${CERT_NAME}" =~ ^[A-Za-z0-9._-]+$ ]] || fail 'invalid certificate lineage name'
	[[ "${CERT_NAME}" == 'junglelaw-admin-ip' ]] || fail 'certificate lineage must equal the approved staging lineage'
	[[ "${CERTBOT_BIN}" == /* && -x "${CERTBOT_BIN}" ]] \
		|| fail 'Certbot must be an absolute executable path before prepare'
	[[ "${CERTBOT_BIN}" =~ ^/[A-Za-z0-9._/-]+$ ]] \
		|| fail 'Certbot path contains characters unsafe for EnvironmentFile'
	[[ "${CERTBOT_PYTHON_BIN}" == /* && -x "${CERTBOT_PYTHON_BIN}" ]] \
		|| fail 'Certbot Python must be an absolute executable path before prepare'
	[[ "${CERTBOT_PYTHON_BIN}" =~ ^/[A-Za-z0-9._/-]+$ ]] \
		|| fail 'Certbot Python path contains characters unsafe for EnvironmentFile'
	if ! "${CERTBOT_PYTHON_BIN}" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)'; then
		fail 'Certbot virtual environment must use Python 3.10 or newer'
	fi
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
		fail "Certbot must be pinned to 5.7.0 before prepare (found: ${CERTBOT_VERSION_OUTPUT})"
	fi
	if [[ -e "${ADMIN_ENV}" ]]; then
		[[ -f "${ADMIN_ENV}" && ! -L "${ADMIN_ENV}" ]] \
			|| fail 'existing dashboard environment path must be a regular file'
		EXISTING_DASHBOARD_PORT_LINES="$(awk -F= '
			$1 == "ZHANCHENG_DASHBOARD_PORT" { count += 1; value = $2 }
			END { printf "%d:%s", count, value }
		' "${ADMIN_ENV}")"
		case "${EXISTING_DASHBOARD_PORT_LINES}" in
			1:8443|1:443) ;;
			*) fail 'existing dashboard environment must contain exactly one approved port value' ;;
		esac
	fi
	id -u junglelaw >/dev/null 2>&1 || fail 'missing game service account: junglelaw'
	assert_admin_not_in_authority_group
	[[ "${DEPLOY_TRANSACTION_READY}" == '1' ]] \
		|| fail 'deployment transaction is disabled'
	[[ "${AUTHORIZE_STATE_DIRECTORY_QUARANTINE}" == '1' ]] \
		|| fail 'prepare requires explicit state-directory quarantine authorization for ERR recovery'
	assert_safe_unit_name "${FISHER_UNIT}"
	assert_safe_unit_name "${NGINX_UNIT}"
	[[ "${FISHER_UNIT}" != "${NGINX_UNIT}" ]] || fail 'Fisher and nginx units must be distinct'
	case "${FISHER_UNIT} ${NGINX_UNIT}" in
		*junglelaw-server.service*|*junglelaw-admin-dashboard*)
			fail 'shared-host evidence units must not be a JungleLaw managed unit' ;;
	esac

	TRANSACTION_ACTION='prepare'
	GAME_WAS_ACTIVE="$(service_was_active junglelaw-server.service)"
	GAME_WAS_ENABLED="$(service_was_enabled junglelaw-server.service)"
	[[ "${GAME_WAS_ACTIVE}" == '1' ]] \
		|| fail 'approved staging upgrade requires the pre-change game service to be active'
	DASHBOARD_WAS_ACTIVE="$(service_was_active junglelaw-admin-dashboard.service)"
	DASHBOARD_WAS_ENABLED="$(service_was_enabled junglelaw-admin-dashboard.service)"
	CERT_TIMER_WAS_ACTIVE="$(service_was_active junglelaw-admin-dashboard-cert-renew.timer)"
	CERT_TIMER_WAS_ENABLED="$(service_was_enabled junglelaw-admin-dashboard-cert-renew.timer)"
	CERT_RENEW_WAS_ACTIVE="$(service_was_active junglelaw-admin-dashboard-cert-renew.service)"
	TRANSACTION_BASELINE_CAPTURED=1
	trap 'transaction_error_handler "$?" "$LINENO"' ERR
	freeze_managed_services

	create_backup "${BACKUP_ROOT}" "${RELEASE_VERSION}" "${AUTHORITY_PATH}" \
		"${SERVER_STATE_DIRECTORY}" "${GAME_WAS_ACTIVE}" "${DASHBOARD_WAS_ACTIVE}" \
		"${GAME_WAS_ENABLED}" "${DASHBOARD_WAS_ENABLED}" \
		"${CERT_TIMER_WAS_ACTIVE}" "${CERT_TIMER_WAS_ENABLED}" "${CERT_RENEW_WAS_ACTIVE}"
	printf 'Coherent pre-deploy backup created: %s\n' "${BACKUP_DIRECTORY_CREATED}"
	TRANSACTION_MUTATED=1

	getent group junglelaw-admin-read >/dev/null 2>&1 || groupadd --system junglelaw-admin-read
	getent group junglelaw-admin-command >/dev/null 2>&1 || groupadd --system junglelaw-admin-command
	if ! id -u junglelaw-admin >/dev/null 2>&1; then
		useradd --system --home-dir "${ADMIN_STATE}" --no-create-home --shell /usr/sbin/nologin junglelaw-admin
	fi
	id -u junglelaw >/dev/null 2>&1 || fail 'missing game service account: junglelaw'
	usermod --append --groups junglelaw-admin-read,junglelaw-admin-command junglelaw
	usermod --append --groups junglelaw-admin-read,junglelaw-admin-command junglelaw-admin

	install -d -o root -g root -m 0755 "${ADMIN_ROOT}" "${ADMIN_RELEASE_ROOT}" /usr/local/libexec
	install -d -o junglelaw-admin -g junglelaw-admin -m 0700 "${ADMIN_STATE}"
	install -d -o root -g junglelaw-admin -m 0750 "${ADMIN_CONFIG_ROOT}"
	install -d -o root -g junglelaw-admin -m 0750 "${ADMIN_CONFIG_ROOT}/tls"
	install -d -o junglelaw -g junglelaw-admin-read -m 2770 "${EXPORT_ROOT}"
	install -d -o junglelaw -g junglelaw-admin-command -m 2770 "${COMMAND_ROOT}"
	install -d -o junglelaw-admin -g junglelaw-admin-command -m 2770 "${COMMAND_ROOT}/pending"
	install -d -o junglelaw -g junglelaw-admin-command -m 2770 "${COMMAND_ROOT}/processed" "${COMMAND_ROOT}/failed"
	apply_admin_traverse_acl
	validate_admin_data_boundary_before_start "${SERVER_STATE_DIRECTORY}"

	install -d -o root -g root -m 0755 "$(dirname -- "${GAME_DROPIN}")"
	atomic_install_game_component \
		"${GAME_RELEASE_SOURCE}/JungleLawServer.x86_64" "${GAME_ELF}" 0755 "${APPROVED_GAME_SHA256}"
	atomic_install_game_component \
		"${GAME_RELEASE_SOURCE}/junglelaw-server.service" "${GAME_UNIT}" 0644 "${APPROVED_GAME_UNIT_SHA256}"
	atomic_install_game_component \
		"${GAME_RELEASE_SOURCE}/junglelaw-server-stop.sh" "${GAME_STOP_HELPER}" 0755 "${APPROVED_GAME_STOP_HELPER_SHA256}"
	atomic_install_game_component \
		"${GAME_RELEASE_SOURCE}/junglelaw-server-admin-dashboard.conf.example" \
		"${GAME_DROPIN}" 0644 "${APPROVED_GAME_DROPIN_SHA256}"

	RELEASE_TARGET="${ADMIN_RELEASE_ROOT}/${RELEASE_VERSION}"
	[[ ! -e "${RELEASE_TARGET}" ]] || fail "immutable release already exists: ${RELEASE_TARGET}"
	install -d -o root -g root -m 0755 "${RELEASE_TARGET}"
	cp -a -- "${RELEASE_SOURCE}/." "${RELEASE_TARGET}/"
	chown -R root:root "${RELEASE_TARGET}"
	chmod -R go-w "${RELEASE_TARGET}"
	# cp -a of SOURCE/. may copy the root-only upload staging directory's
	# 0700 mode onto the already-created target. Restore the immutable release
	# root's service-readable traversal contract explicitly.
	chmod 0755 "${RELEASE_TARGET}"
	[[ "$(stat -c '%U:%G:%a' "${RELEASE_TARGET}")" == 'root:root:755' ]] \
		|| fail 'installed release root must be root:root 0755'
	runuser -u junglelaw-admin -- test -r "${RELEASE_TARGET}/tools/admin_dashboard/server.mjs" \
		|| fail 'installed release entrypoint is not readable by junglelaw-admin'
	runuser -u junglelaw-admin -- "${NODE_BIN}" --check \
		"${RELEASE_TARGET}/tools/admin_dashboard/server.mjs"
	runuser -u junglelaw-admin -- "${NODE_BIN}" \
		"${RELEASE_TARGET}/tools/admin_dashboard/server.mjs" --help >/dev/null

	ADMIN_ENV_SOURCE="${SOURCE_DIRECTORY}/junglelaw-admin-dashboard.env.example"
	if [[ -e "${ADMIN_ENV}" ]]; then
		ADMIN_ENV_SOURCE="${ADMIN_ENV}"
	fi
	ADMIN_ENV_TEMP="${ADMIN_CONFIG_ROOT}/.dashboard.env.${RELEASE_VERSION}.new"
	[[ ! -e "${ADMIN_ENV_TEMP}" && ! -L "${ADMIN_ENV_TEMP}" ]] \
		|| fail "temporary dashboard environment already exists: ${ADMIN_ENV_TEMP}"
	sed -E "s/^ZHANCHENG_DASHBOARD_PORT=.*/ZHANCHENG_DASHBOARD_PORT=${DASHBOARD_PORT}/" \
		"${ADMIN_ENV_SOURCE}" > "${ADMIN_ENV_TEMP}"
	[[ "$(awk -F= '
		$1 == "ZHANCHENG_DASHBOARD_PORT" { count += 1; value = $2 }
		END { printf "%d:%s", count, value }
	' "${ADMIN_ENV_TEMP}")" == "1:${DASHBOARD_PORT}" ]] \
		|| fail 'selected dashboard environment port was not written exactly once'
	chown root:junglelaw-admin "${ADMIN_ENV_TEMP}"
	chmod 0640 "${ADMIN_ENV_TEMP}"
	mv -T -- "${ADMIN_ENV_TEMP}" "${ADMIN_ENV}"
	install -o root -g root -m 0644 \
		"${SOURCE_DIRECTORY}/junglelaw-admin-dashboard.service.example" "${ADMIN_UNIT}"
	install -o root -g root -m 0755 \
		"${SOURCE_DIRECTORY}/junglelaw-admin-dashboard-cert-renew" "${CERT_HELPER}"
	install -d -o root -g root -m 0755 /etc/letsencrypt/renewal-hooks/deploy
	DEPLOY_HOOK_TEMP="${ADMIN_CONFIG_ROOT}/.cert-deploy-hook.${RELEASE_VERSION}.new"
	[[ ! -e "${DEPLOY_HOOK_TEMP}" ]] \
		|| fail "temporary certificate deploy hook already exists: ${DEPLOY_HOOK_TEMP}"
	cat > "${DEPLOY_HOOK_TEMP}" <<'HOOK'
#!/usr/bin/env bash
set -Eeuo pipefail

APPROVED_LINEAGE='/etc/letsencrypt/live/junglelaw-admin-ip'
if [[ -z "${RENEWED_LINEAGE:-}" ]]; then
	exit 0
fi
[[ -d "${RENEWED_LINEAGE}" ]] || {
	printf 'invalid Certbot RENEWED_LINEAGE: %s\n' "${RENEWED_LINEAGE}" >&2
	exit 1
}
if [[ "$(realpath -e -- "${RENEWED_LINEAGE}")" != "$(realpath -e -- "${APPROVED_LINEAGE}")" ]]; then
	exit 0
fi
exec /usr/local/libexec/junglelaw-admin-dashboard-cert-renew deploy
HOOK
	bash -n "${DEPLOY_HOOK_TEMP}"
	install -o root -g root -m 0755 "${DEPLOY_HOOK_TEMP}" "${LE_DEPLOY_HOOK}"
	rm -f -- "${DEPLOY_HOOK_TEMP}"
	CERT_SERVICE_TEMP="${ADMIN_CONFIG_ROOT}/.cert-renew.service.${RELEASE_VERSION}.new"
	[[ ! -e "${CERT_SERVICE_TEMP}" ]] || fail "temporary certificate service already exists: ${CERT_SERVICE_TEMP}"
	sed "s#^ReadWritePaths=/JUNGLELAW_CERT_WEBROOT_MUST_BE_REPLACED\$#ReadWritePaths=${ACME_WEBROOT}#" \
		"${SOURCE_DIRECTORY}/junglelaw-admin-dashboard-cert-renew.service.example" > "${CERT_SERVICE_TEMP}"
	[[ "$(grep -Fxc "ReadWritePaths=${ACME_WEBROOT}" "${CERT_SERVICE_TEMP}")" -eq 1 ]] \
		|| fail 'certificate service webroot substitution did not occur exactly once'
	if grep -Fq '/JUNGLELAW_CERT_WEBROOT_MUST_BE_REPLACED' "${CERT_SERVICE_TEMP}"; then
		fail 'certificate service still contains the ACME webroot placeholder'
	fi
	install -o root -g root -m 0644 "${CERT_SERVICE_TEMP}" "${CERT_SERVICE}"
	rm -f -- "${CERT_SERVICE_TEMP}"
	install -o root -g root -m 0644 \
		"${SOURCE_DIRECTORY}/junglelaw-admin-dashboard-cert-renew.timer.example" "${CERT_TIMER}"
	if [[ "${DASHBOARD_PORT}" == '443' ]]; then
		install -d -o root -g root -m 0755 "$(dirname -- "${PUBLIC_443_DROPIN}")"
		atomic_install_game_component \
			"${SOURCE_DIRECTORY}/junglelaw-admin-dashboard-public-443.conf.example" \
			"${PUBLIC_443_DROPIN}" 0644 "${APPROVED_PUBLIC_443_DROPIN_SHA256}"
	else
		remove_stateless_target "${PUBLIC_443_DROPIN}"
	fi

	CERT_ENV_TEMP="${ADMIN_CONFIG_ROOT}/.cert-renew.env.${RELEASE_VERSION}.new"
	[[ ! -e "${CERT_ENV_TEMP}" ]] || fail "temporary certificate config already exists: ${CERT_ENV_TEMP}"
	{
		printf 'JUNGLELAW_CERT_IP=%s\n' "${PUBLIC_IP}"
		printf 'JUNGLELAW_CERT_WEBROOT=%s\n' "${ACME_WEBROOT}"
		printf 'JUNGLELAW_CERT_NAME=%s\n' "${CERT_NAME}"
		printf 'JUNGLELAW_CERTBOT_BIN=%s\n' "${CERTBOT_BIN}"
		printf 'JUNGLELAW_CERTBOT_PYTHON_BIN=%s\n' "${CERTBOT_PYTHON_BIN}"
		printf 'JUNGLELAW_AUTHORITY_PATH=%s\n' "${AUTHORITY_PATH}"
		printf 'JUNGLELAW_CERT_HEALTH_PORT=%s\n' "${DASHBOARD_PORT}"
	} > "${CERT_ENV_TEMP}"
	chown root:root "${CERT_ENV_TEMP}"
	chmod 0600 "${CERT_ENV_TEMP}"
	mv -T -- "${CERT_ENV_TEMP}" "${CERT_ENV}"

	NEXT_LINK="${ADMIN_ROOT}/.current-${RELEASE_VERSION}.new"
	[[ ! -e "${NEXT_LINK}" && ! -L "${NEXT_LINK}" ]] || fail "temporary current link already exists: ${NEXT_LINK}"
	if [[ -e "${ADMIN_CURRENT_LINK}" && ! -L "${ADMIN_CURRENT_LINK}" ]]; then
		fail "current path exists but is not a symbolic link: ${ADMIN_CURRENT_LINK}"
	fi
	ln -s "${RELEASE_TARGET}" "${NEXT_LINK}"
	# mv -T is atomic both when current is an existing symlink and when this is
	# the first deployment and current is absent.
	mv -T -- "${NEXT_LINK}" "${ADMIN_CURRENT_LINK}"
	[[ "$(readlink -f -- "${ADMIN_CURRENT_LINK}")" == "${RELEASE_TARGET}" ]] \
		|| fail 'current link did not resolve to the prepared release'

	verify_units_fail_on_unknown "${ADMIN_UNIT}" "${GAME_UNIT}" "${CERT_SERVICE}" "${CERT_TIMER}"
	systemctl daemon-reload
	if [[ "${GAME_WAS_ACTIVE}" == '1' ]]; then
		systemctl start junglelaw-server.service
		systemctl is-active --quiet junglelaw-server.service || fail 'game service failed to restart after overlay installation'
	fi
	[[ "$(sha256sum "${GAME_ELF}" | awk '{print toupper($1)}')" == "${APPROVED_GAME_SHA256}" ]] \
		|| fail 'installed game ELF drifted after service start'
	verify_shared_host_unchanged "${BACKUP_DIRECTORY_CREATED}/shared-host.fingerprint"
	trap - ERR
	TRANSACTION_ACTION=''

	printf '%s\n' 'PREPARED: initialize the Owner interactively, run the certificate helper in initial mode, then run activate.'
	printf 'Rollback receipt: %s\n' "${BACKUP_DIRECTORY_CREATED}"
}

activate_install() {
	validate_node_runtime
	[[ -L "${ADMIN_CURRENT_LINK}" ]] || fail 'current release link is missing'
	[[ -f "${ADMIN_STATE}/dashboard_admin_state.json" ]] \
		|| fail 'Owner state is missing; initialize the Owner interactively before activation'
	[[ -f "${ADMIN_CONFIG_ROOT}/tls/privkey.pem" && -f "${ADMIN_CONFIG_ROOT}/tls/fullchain.pem" ]] \
		|| fail 'TLS pair is missing; run the certificate helper in initial mode before activation'
	[[ -f "${CERT_ENV}" ]] || fail 'certificate renewal configuration is missing'
	PUBLIC_IP="$(grep -E '^JUNGLELAW_CERT_IP=' "${CERT_ENV}" | tail -n 1 | cut -d= -f2-)"
	validate_public_ipv4 "${PUBLIC_IP}" || fail 'invalid public IP in certificate renewal configuration'
	DASHBOARD_PORT="$(grep -E '^JUNGLELAW_CERT_HEALTH_PORT=' "${CERT_ENV}" | tail -n 1 | cut -d= -f2-)"
	[[ "${DASHBOARD_PORT}" == '8443' || "${DASHBOARD_PORT}" == '443' ]] \
		|| fail 'dashboard port must be exactly 8443 or 443'
	if [[ "${DASHBOARD_PORT}" == '443' ]]; then
		[[ -f "${PUBLIC_443_DROPIN}" ]] || fail '443 transaction drop-in is missing'
		[[ "$(sha256sum "${PUBLIC_443_DROPIN}" | awk '{print toupper($1)}')" == \
			"${APPROVED_PUBLIC_443_DROPIN_SHA256}" ]] || fail '443 transaction drop-in hash mismatch'
	else
		[[ ! -e "${PUBLIC_443_DROPIN}" && ! -L "${PUBLIC_443_DROPIN}" ]] \
			|| fail '8443 transaction must not retain the 443 capability drop-in'
	fi
	[[ "$(sha256sum "${GAME_ELF}" | awk '{print toupper($1)}')" == "${APPROVED_GAME_SHA256}" ]] \
		|| fail 'prepared game ELF hash mismatch before activation'
	[[ "$(sha256sum "${GAME_UNIT}" | awk '{print toupper($1)}')" == "${APPROVED_GAME_UNIT_SHA256}" ]] \
		|| fail 'prepared game unit hash mismatch before activation'
	[[ "$(sha256sum "${GAME_STOP_HELPER}" | awk '{print toupper($1)}')" == "${APPROVED_GAME_STOP_HELPER_SHA256}" ]] \
		|| fail 'prepared game stop-helper hash mismatch before activation'
	[[ "$(sha256sum "${GAME_DROPIN}" | awk '{print toupper($1)}')" == "${APPROVED_GAME_DROPIN_SHA256}" ]] \
		|| fail 'prepared game admin drop-in hash mismatch before activation'
	"${NODE_BIN}" --check "${ADMIN_CURRENT_LINK}/tools/admin_dashboard/server.mjs"
	"${NODE_BIN}" "${ADMIN_CURRENT_LINK}/tools/admin_dashboard/server.mjs" --help >/dev/null
	verify_units_fail_on_unknown "${ADMIN_UNIT}" "${GAME_UNIT}" "${CERT_SERVICE}" "${CERT_TIMER}"

	TRANSACTION_ACTION='activate'
	GAME_WAS_ACTIVE="$(service_was_active junglelaw-server.service)"
	GAME_WAS_ENABLED="$(service_was_enabled junglelaw-server.service)"
	DASHBOARD_WAS_ACTIVE="$(service_was_active junglelaw-admin-dashboard.service)"
	DASHBOARD_WAS_ENABLED="$(service_was_enabled junglelaw-admin-dashboard.service)"
	CERT_TIMER_WAS_ACTIVE="$(service_was_active junglelaw-admin-dashboard-cert-renew.timer)"
	CERT_TIMER_WAS_ENABLED="$(service_was_enabled junglelaw-admin-dashboard-cert-renew.timer)"
	CERT_RENEW_WAS_ACTIVE="$(service_was_active junglelaw-admin-dashboard-cert-renew.service)"
	TRANSACTION_BASELINE_CAPTURED=1
	trap 'transaction_error_handler "$?" "$LINENO"' ERR

	systemctl daemon-reload
	systemctl is-active --quiet junglelaw-server.service \
		|| fail 'game service is inactive; activation must not perform the prepare-only game restart'
	bash "${ADMIN_CURRENT_LINK}/deploy/linux/admin_dashboard_preflight.sh"
	systemctl enable --now junglelaw-admin-dashboard.service
	local health_ready='0'
	for _ in {1..30}; do
		if curl --fail --silent --max-time 3 --output /dev/null \
			--connect-to "${PUBLIC_IP}:${DASHBOARD_PORT}:127.0.0.1:${DASHBOARD_PORT}" \
			"https://${PUBLIC_IP}:${DASHBOARD_PORT}/api/health"; then
			health_ready='1'
			break
		fi
		systemctl is-active --quiet junglelaw-admin-dashboard.service \
			|| break
		sleep 1
	done
	[[ "${health_ready}" == '1' ]] \
		|| fail 'certificate-verified public-IP health check failed after bounded startup wait'
	systemctl enable --now junglelaw-admin-dashboard-cert-renew.timer
	systemctl is-active --quiet junglelaw-admin-dashboard.service || fail 'dashboard is not active'
	systemctl is-active --quiet junglelaw-admin-dashboard-cert-renew.timer || fail 'certificate renewal timer is not active'
	trap - ERR
	TRANSACTION_ACTION=''
	printf 'ACTIVE: https://%s:%s/\n' "${PUBLIC_IP}" "${DASHBOARD_PORT}"
}

rollback_install() {
	[[ "${BACKUP_DIRECTORY}" == /* && -d "${BACKUP_DIRECTORY}" ]] || fail 'backup directory must be an absolute existing directory'
	BACKUP_DIRECTORY="$(realpath -e -- "${BACKUP_DIRECTORY}")"
	case "${BACKUP_DIRECTORY}" in
		/var/backups/junglelaw-admin-dashboard/admin-dashboard-predeploy-*) ;;
		*) fail 'backup directory is outside the approved root-only staging backup namespace' ;;
	esac
	[[ "$(stat -c '%U:%G' "${BACKUP_DIRECTORY}")" == 'root:root' ]] \
		|| fail 'backup receipt directory must be root-owned'
	backup_directory_mode="$(stat -c '%a' "${BACKUP_DIRECTORY}")"
	(( (8#${backup_directory_mode} & 077) == 0 )) \
		|| fail 'backup receipt directory must not grant group/other access'
	[[ "$(stat -c '%d' "${BACKUP_DIRECTORY}")" == "$(stat -c '%d' /)" ]] \
		|| fail 'backup receipt must share the root filesystem for atomic quarantine and restore moves'
	MANIFEST="${BACKUP_DIRECTORY}/manifest.tsv"
	[[ -f "${MANIFEST}" ]] || fail 'backup manifest is missing'
	BACKUP_ID="$(manifest_value "${MANIFEST}" backup_id)"
	[[ "${CONFIRM_BACKUP_ID}" == "${BACKUP_ID}" ]] \
		|| fail "rollback confirmation must equal backup id: ${BACKUP_ID}"
	[[ "${AUTHORIZE_STATE_DIRECTORY_QUARANTINE}" == '1' ]] \
		|| fail 'rollback requires --authorize-state-directory-quarantine before any service stop or path mutation'
	validate_backup_receipt "${BACKUP_DIRECTORY}"
	AUTHORITY_PATH="$(manifest_value "${MANIFEST}" authority_path)"
	SERVER_STATE_DIRECTORY="$(manifest_value "${MANIFEST}" server_state_directory)"
	case "${AUTHORITY_PATH}|${SERVER_STATE_DIRECTORY}" in
		/var/lib/junglelaw/*/server/player_accounts.json\|/var/lib/junglelaw/*/server) ;;
		*) fail 'manifest authority or server directory is outside the approved authority boundary' ;;
	esac
	[[ "${AUTHORITY_PATH}" == "${SERVER_STATE_DIRECTORY}/player_accounts.json" ]] \
		|| fail 'manifest authority is not inside the canonical server directory'
	FISHER_UNIT="$(manifest_value "${MANIFEST}" fisher_unit)"
	NGINX_UNIT="$(manifest_value "${MANIFEST}" nginx_unit)"
	assert_safe_unit_name "${FISHER_UNIT}"
	assert_safe_unit_name "${NGINX_UNIT}"
	stage_backup_for_restore "${BACKUP_DIRECTORY}"
	ROLLBACK_STAGE_ROOT="${STAGED_RESTORE_ROOT}"

	TRANSACTION_ACTION='rollback'
	TRANSACTION_BASELINE_CAPTURED=1
	trap 'transaction_error_handler "$?" "$LINENO"' ERR
	freeze_managed_services
	restore_backup_transaction "${BACKUP_DIRECTORY}"
	trap - ERR
	TRANSACTION_ACTION=''
	printf 'ROLLBACK RESTORED: %s\n' "${BACKUP_ID}"
	printf 'Rollback quarantine retained under: %s/quarantine\n' "${BACKUP_DIRECTORY}"
}

case "${ACTION}" in
	prepare) prepare_install ;;
	activate) activate_install ;;
	rollback) rollback_install ;;
	*) usage ;;
esac
