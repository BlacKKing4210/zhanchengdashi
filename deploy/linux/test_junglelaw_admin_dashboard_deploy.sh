#!/usr/bin/env bash
# Local/static contract tests for the Alibaba Cloud staging deployment overlay.
# The embedded directive table is intentionally capped at systemd 239 and the
# injected ProtectClock fixture proves that unknown directives fail the gate.
set -Eeuo pipefail

SOURCE_DIRECTORY="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(CDPATH= cd -- "${SOURCE_DIRECTORY}/../.." && pwd)"
ADMIN_UNIT="${SOURCE_DIRECTORY}/junglelaw-admin-dashboard.service.example"
CERT_SERVICE="${SOURCE_DIRECTORY}/junglelaw-admin-dashboard-cert-renew.service.example"
CERT_TIMER="${SOURCE_DIRECTORY}/junglelaw-admin-dashboard-cert-renew.timer.example"
PUBLIC_443_DROPIN="${SOURCE_DIRECTORY}/junglelaw-admin-dashboard-public-443.conf.example"
INSTALLER="${SOURCE_DIRECTORY}/install_junglelaw_admin_dashboard.sh"
CERT_HELPER="${SOURCE_DIRECTORY}/junglelaw-admin-dashboard-cert-renew"
PREFLIGHT="${SOURCE_DIRECTORY}/admin_dashboard_preflight.sh"
PROFILE="${PROJECT_ROOT}/production/deployment/aliyun-profile.yaml"

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

for script in "${INSTALLER}" "${CERT_HELPER}" "${PREFLIGHT}"; do
	bash -n "${script}"
done

python3 - "${INSTALLER}" "${CERT_HELPER}" "${PREFLIGHT}" <<'PY'
import ast
from pathlib import Path
import sys

blocks = []
for source_path in sys.argv[1:]:
    current = None
    for line in Path(source_path).read_text(encoding="utf-8").splitlines():
        if line.rstrip().endswith("<<'PY'"):
            if current is not None:
                raise SystemExit("nested Python heredoc in {}".format(source_path))
            current = []
        elif line == "PY" and current is not None:
            blocks.append("\n".join(current) + "\n")
            current = None
        elif current is not None:
            current.append(line)
    if current is not None:
        raise SystemExit("unterminated Python heredoc in {}".format(source_path))

if len(blocks) != 9:
    raise SystemExit("expected nine embedded Python blocks, found {}".format(len(blocks)))
for block in blocks:
    if sys.version_info >= (3, 8):
        ast.parse(block, feature_version=6)
    else:
        ast.parse(block)
PY

python3 - "${ADMIN_UNIT}" "${CERT_SERVICE}" "${CERT_TIMER}" "${PUBLIC_443_DROPIN}" <<'PY'
from pathlib import Path
import sys

allowed = {
    "Unit": {
        "After", "ConditionPathExists", "ConditionPathIsDirectory",
        "Description", "Documentation", "Wants",
    },
    "Service": {
        "AmbientCapabilities", "CapabilityBoundingSet", "Environment",
        "EnvironmentFile", "ExecStart", "ExecStartPre", "Group",
        "KillSignal", "LockPersonality", "NoNewPrivileges", "PrivateDevices",
        "PrivateTmp", "ProtectControlGroups", "ProtectHome",
        "ProtectKernelModules", "ProtectKernelTunables", "ProtectSystem",
        "ReadOnlyPaths", "ReadWritePaths", "Restart", "RestartSec",
        "RestrictAddressFamilies", "RestrictNamespaces", "RestrictRealtime",
        "StandardError", "StandardOutput", "StateDirectory",
        "StateDirectoryMode", "SupplementaryGroups", "SyslogIdentifier",
        "SystemCallArchitectures", "TimeoutStartSec", "TimeoutStopSec", "Type",
        "UMask", "User", "WorkingDirectory",
    },
    "Timer": {
        "AccuracySec", "OnCalendar", "Persistent", "RandomizedDelaySec", "Unit",
    },
    "Install": {"WantedBy"},
}

banned_239 = {
    "ProtectClock", "ProtectHostname", "ProtectKernelLogs", "ProtectProc",
    "ProcSubset", "RestrictSUIDSGID",
}

def validate(path, injected=None):
    section = None
    lines = Path(path).read_text(encoding="utf-8").splitlines()
    if injected:
        lines.append(injected)
    for number, raw in enumerate(lines, 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            if section not in allowed:
                raise ValueError("{}:{}: unsupported section {}".format(path, number, section))
            continue
        if "=" not in line or section is None:
            raise ValueError("{}:{}: malformed unit line".format(path, number))
        directive = line.split("=", 1)[0]
        if directive in banned_239 or directive not in allowed[section]:
            raise ValueError("{}:{}: unknown for systemd 239: {}".format(path, number, directive))

for candidate in sys.argv[1:]:
    validate(candidate)

try:
    validate(sys.argv[1], "ProtectClock=true")
except ValueError as exc:
    if "ProtectClock" not in str(exc):
        raise
else:
    raise SystemExit("injected unknown-lvalue fixture was not rejected")
PY

for unsupported in ProtectClock ProtectHostname ProtectKernelLogs ProtectProc ProcSubset RestrictSUIDSGID; do
	if grep -R -E "^[[:space:]]*${unsupported}=" \
		"${ADMIN_UNIT}" "${CERT_SERVICE}" "${CERT_TIMER}" "${PUBLIC_443_DROPIN}" >/dev/null; then
		fail "systemd 239-incompatible directive remains: ${unsupported}"
	fi
done

[[ "$(grep -Fxc 'CapabilityBoundingSet=' "${ADMIN_UNIT}")" -eq 1 ]] \
	|| fail 'base dashboard unit must keep an empty capability bounding set'
[[ "$(grep -Fxc 'AmbientCapabilities=' "${ADMIN_UNIT}")" -eq 1 ]] \
	|| fail 'base dashboard unit must keep an empty ambient capability set'
for expected_443_line in \
	'Environment=ZHANCHENG_DASHBOARD_PORT=443' \
	'CapabilityBoundingSet=CAP_NET_BIND_SERVICE' \
	'AmbientCapabilities=CAP_NET_BIND_SERVICE'; do
	[[ "$(grep -Fxc "${expected_443_line}" "${PUBLIC_443_DROPIN}")" -eq 1 ]] \
		|| fail "443 drop-in is missing exact line: ${expected_443_line}"
done

for gate_script in "${INSTALLER}" "${PREFLIGHT}"; do
	grep -Fq 'Unknown lvalue' "${gate_script}" \
		|| fail "unknown-lvalue fail gate missing from ${gate_script}"
done

grep -Fq "DEPLOY_TRANSACTION_READY='1'" "${INSTALLER}" \
	|| fail 'authorized staging deployment transaction is not enabled'

grep -Fq 'installer must execute from the deployment overlay inside the verified Node release source' "${INSTALLER}" \
	|| fail 'verified Node release and executed deployment overlay are not provenance-bound'
grep -Fq 'Node ZIP file set does not match manifest entries' "${INSTALLER}" \
	|| fail 'Node ZIP entries are not bound to the external manifest'
grep -Fq 'Node ZIP entry SHA-256 mismatch' "${INSTALLER}" \
	|| fail 'Node ZIP entry hashes are not verified against the manifest'
grep -Fq '"${NODE_BIN}" "${RELEASE_SOURCE}/tools/admin_dashboard/server.mjs" --help' "${INSTALLER}" \
	|| fail 'verified remote release help invocation is missing'
grep -Fq 'chmod 0755 "${RELEASE_TARGET}"' "${INSTALLER}" \
	|| fail 'installed release root does not restore service-readable traversal after cp -a'
grep -Fq 'runuser -u junglelaw-admin -- "${NODE_BIN}" --check' "${INSTALLER}" \
	|| fail 'installed release syntax is not verified as the actual service account'
grep -Fq 'runuser -u junglelaw-admin -- "${NODE_BIN}"' "${INSTALLER}" \
	|| fail 'installed release help is not verified as the actual service account'
grep -Fq 'immutable release root must be root:root 0755' "${PREFLIGHT}" \
	|| fail 'preflight does not enforce the immutable release traversal contract'
grep -Fq 'stat -Lc' "${PREFLIGHT}" \
	|| fail 'preflight checks the current symlink itself instead of following it to the immutable release root'
grep -Fq 'run_as junglelaw-admin node --check' "${PREFLIGHT}" \
	|| fail 'preflight does not parse the entrypoint as the actual service account'
grep -Fq "approved staging Node runtime must be exactly v24.14.0 at /usr/bin/node" "${INSTALLER}" \
	|| fail 'installer does not bind the profile Node path and exact runtime version'
grep -Fq "junglelaw-admin must never join the authoritative junglelaw group" "${INSTALLER}" \
	|| fail 'installer lacks the authoritative-group membership fail gate'
grep -Fq "junglelaw-admin must never join the authoritative junglelaw group" "${PREFLIGHT}" \
	|| fail 'preflight lacks the authoritative-group membership fail gate'
grep -Fq "user:junglelaw-admin:--x" "${PREFLIGHT}" \
	|| fail 'preflight lacks the minimum authoritative-root traverse ACL check'
if grep -Fq -- '--numeric-names' "${INSTALLER}"; then
	fail 'installer uses a getfacl long option unsupported by Alibaba Cloud Linux acl 2.2.53'
fi
grep -Fq 'getfacl -R -p -n -- "$(basename -- "${tree_root}")"' "${INSTALLER}" \
	|| fail 'recursive server ACL receipt must use the target-compatible numeric getfacl form'
[[ "$(grep -Fc 'getfacl -p -n -- "${JUNGLELAW_ROOT}"' "${INSTALLER}")" -eq 2 ]] \
	|| fail 'authoritative-root backup and rollback ACL receipts must use the target-compatible numeric getfacl form'
grep -Fq "authoritative root must not carry inheritable default ACL entries" "${PREFLIGHT}" \
	|| fail 'preflight lacks the default-ACL fail gate'
grep -Fq "dashboard health port must be exactly 8443 or 443" "${PREFLIGHT}" \
	|| fail 'preflight does not constrain the transactional public port'

if grep -Fq 'certonly' "${CERT_HELPER}"; then
	fail 'renew/deploy helper must not issue certificates or recurse through certonly'
fi
grep -Fq 'renew --quiet --cert-name "${CERT_NAME}"' "${CERT_HELPER}" \
	|| fail 'renew mode is not scoped to the approved Certbot lineage'
grep -Fq 'deploy mode requires RENEWED_LINEAGE from Certbot' "${CERT_HELPER}" \
	|| fail 'deploy hook lineage fail gate is missing'
grep -Fq "LE_DEPLOY_HOOK='/etc/letsencrypt/renewal-hooks/deploy/junglelaw-admin-dashboard-cert-deploy'" "${INSTALLER}" \
	|| fail 'installer does not bind the approved Certbot directory deploy hook path'
grep -Fq "APPROVED_LINEAGE='/etc/letsencrypt/live/junglelaw-admin-ip'" "${INSTALLER}" \
	|| fail 'directory deploy hook does not filter to the approved production lineage'
grep -Fq 'exec /usr/local/libexec/junglelaw-admin-dashboard-cert-renew deploy' "${INSTALLER}" \
	|| fail 'directory deploy hook does not invoke the non-recursive deploy mode'
grep -Fq 'certificate deploy hook must be root:root 0755' "${PREFLIGHT}" \
	|| fail 'preflight does not validate the directory deploy hook ownership and mode'
if grep -Fq 'deploy_hook = /usr/local/libexec/junglelaw-admin-dashboard-cert-renew deploy' "${PREFLIGHT}"; then
	fail 'preflight still requires a per-lineage hook instead of the installed directory hook'
fi
grep -Fq 'RENEWED_DOMAINS does not contain the approved public IP' "${CERT_HELPER}" \
	|| fail 'deploy hook public-IP fail gate is missing'
grep -Fq "version == (5, 7, 0)" "${CERT_HELPER}" \
	|| fail 'Certbot exact 5.7.0 version gate is missing'
grep -Fq "sys.version_info >= (3, 10)" "${CERT_HELPER}" \
	|| fail 'Certbot Python 3.10 minimum-version gate is missing'
grep -Fq 'previous pair restored' "${CERT_HELPER}" \
	|| fail 'certificate health-failure rollback is missing'
grep -Fq 'ReadWritePaths=/JUNGLELAW_CERT_WEBROOT_MUST_BE_REPLACED' "${CERT_SERVICE}" \
	|| fail 'parameterized ACME webroot placeholder is missing from service template'
grep -Fq "certificate service webroot substitution did not occur exactly once" "${INSTALLER}" \
	|| fail 'installer does not fail closed on ACME webroot substitution'
grep -Fq "printf 'JUNGLELAW_AUTHORITY_PATH=%s" "${INSTALLER}" \
	|| fail 'installer does not bind the canonical authority path into renewal/preflight configuration'
grep -Fq 'dashboard runtime port must exactly match the certificate health port' "${PREFLIGHT}" \
	|| fail 'preflight does not bind the runtime port to the certificate health port'
[[ "$(grep -Fxc 'OnCalendar=*-*-* 00:00:00 UTC' "${CERT_TIMER}")" -eq 1 ]] \
	|| fail 'midnight renewal check is missing'
[[ "$(grep -Fxc 'OnCalendar=*-*-* 12:00:00 UTC' "${CERT_TIMER}")" -eq 1 ]] \
	|| fail 'noon renewal check is missing'
[[ "$(grep -Fxc 'RandomizedDelaySec=1h' "${CERT_TIMER}")" -eq 1 ]] \
	|| fail 'renewal random delay must be at most one hour'
if grep -Eiq 'systemctl[[:space:]]+(reload|restart)[[:space:]]+nginx|nginx[[:space:]]+-s' "${CERT_HELPER}"; then
	fail 'certificate helper must not edit or reload nginx'
fi
if grep -Eq -- '(^|[[:space:]])-k([[:space:]]|$)|--insecure' "${CERT_HELPER}"; then
	fail 'certificate helper must not bypass TLS verification'
fi

for protected_path in \
	'/opt/junglelaw/JungleLawServer.x86_64' \
	'/etc/systemd/system/junglelaw-server.service' \
	'/usr/local/libexec/junglelaw-server-stop' \
	'/etc/systemd/system/junglelaw-server.service.d/admin-dashboard.conf' \
	'authority_sha256'; do
	grep -Fq "${protected_path}" "${INSTALLER}" \
		|| fail "backup/restore contract is missing ${protected_path}"
done

grep -Fq 'mv -T -- "${NEXT_LINK}" "${ADMIN_CURRENT_LINK}"' "${INSTALLER}" \
	|| fail 'atomic current switch is missing'
if grep -Fq 'test -L "${ADMIN_CURRENT_LINK}"' "${INSTALLER}"; then
	fail 'first deployment must not require an existing current symlink'
fi

grep -Fq 'port: 8443' "${PROFILE}" || fail 'approved public staging port is missing from profile'
grep -Fq 'source_cidr: 0.0.0.0/0' "${PROFILE}" || fail 'approved public source CIDR is missing from profile'
grep -Fq 'production_remote_writes: false' "${PROFILE}" || fail 'production write prohibition is missing'

if grep -Fq 'rm -rf' "${INSTALLER}"; then
	fail 'installer must never recursively delete state or account data'
fi
for protected_contract in \
	"write_tree_receipt \"\${server_state_directory}\"" \
	"tar --create --acls --xattrs --xattrs-include='*' --numeric-owner" \
	'--authorize-state-directory-quarantine' \
	'quarantine_target "${entry_path}" "${backup_directory}"' \
	"user:junglelaw-admin:--x" \
	'Fisher or nginx changed during the JungleLaw deployment transaction' \
	'game service is inactive; activation must not perform the prepare-only game restart'; do
	grep -Fq -- "${protected_contract}" "${INSTALLER}" \
		|| fail "deployment transaction contract is missing: ${protected_contract}"
done

# Exercise the exact game-archive validator embedded in the installer against
# the frozen real release tarball, then prove that identity/root and unsafe tar
# counterexamples fail closed. This prevents a structural grep test from
# passing while the approved archive itself remains undeployable.
REAL_GAME_ARCHIVE="${PROJECT_ROOT}/build/linux/JungleLawServer-v1.1.3-local-linux-rc1.tar.gz"
REAL_GAME_MANIFEST="${PROJECT_ROOT}/build/linux/candidates/v1.1.3-local-linux-rc1/manifest.json"
[[ -f "${REAL_GAME_ARCHIVE}" ]] || fail 'frozen real game archive fixture is missing'
[[ -f "${REAL_GAME_MANIFEST}" ]] || fail 'frozen real game manifest fixture is missing'
python3 - "${INSTALLER}" "${REAL_GAME_ARCHIVE}" "${REAL_GAME_MANIFEST}" <<'PY'
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import tempfile

installer_path, real_archive_path, real_manifest_path = map(Path, sys.argv[1:])
installer_source = installer_path.read_text(encoding="utf-8")

def shell_literal(name):
    match = re.search(r"^{}='([^']+)'$".format(re.escape(name)), installer_source, re.MULTILINE)
    if match is None:
        raise SystemExit("missing installer constant: " + name)
    return match.group(1)

approved_artifact = shell_literal("APPROVED_GAME_ARTIFACT_ID")
approved_version = shell_literal("APPROVED_GAME_VERSION")
approved_archive_hash = shell_literal("APPROVED_GAME_ARCHIVE_SHA256")
approved_elf_hash = shell_literal("APPROVED_GAME_SHA256")
approved_unit_hash = shell_literal("APPROVED_GAME_UNIT_SHA256")
approved_helper_hash = shell_literal("APPROVED_GAME_STOP_HELPER_SHA256")
approved_dropin_hash = shell_literal("APPROVED_GAME_DROPIN_SHA256")

function_start = installer_source.index("validate_game_release_source() {")
function_end = installer_source.index("atomic_install_game_component() {", function_start)
function_source = installer_source[function_start:function_end]
heredoc_marker = "<<'PY'\n"
validator_start = function_source.index(heredoc_marker) + len(heredoc_marker)
validator_end = function_source.index("\nPY\n", validator_start)
validator_source = function_source[validator_start:validator_end] + "\n"

def run_validator(manifest_path, archive_path, expected_status, expected_error=None):
    command = [
        sys.executable,
        "-",
        str(manifest_path),
        str(archive_path),
        approved_artifact,
        approved_version,
        approved_elf_hash,
        approved_unit_hash,
        approved_helper_hash,
        approved_dropin_hash,
    ]
    result = subprocess.run(
        command,
        input=validator_source,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )
    combined = result.stdout + result.stderr
    if expected_status == 0 and result.returncode != 0:
        raise SystemExit("approved real game archive was rejected:\n" + combined)
    if expected_status != 0 and result.returncode == 0:
        raise SystemExit("invalid game archive fixture was accepted")
    if expected_error is not None and expected_error not in combined:
        raise SystemExit(
            "invalid fixture failed for the wrong reason; expected {!r}, got:\n{}".format(
                expected_error, combined
            )
        )

real_archive_bytes = real_archive_path.read_bytes()
if hashlib.sha256(real_archive_bytes).hexdigest().upper() != approved_archive_hash:
    raise SystemExit("frozen real game archive hash drifted")

expected_real_members = [
    approved_version,
    approved_version + "/ADMIN_DASHBOARD_DEPLOYMENT.md",
    approved_version + "/JungleLawServer.x86_64",
    approved_version + "/JungleLawServer.x86_64.sha256",
    approved_version + "/LOCAL_ARTIFACT_STATUS.txt",
    approved_version + "/PROVENANCE.md",
    approved_version + "/admin_dashboard_preflight.sh",
    approved_version + "/install_junglelaw_server.sh",
    approved_version + "/junglelaw-server-admin-dashboard.conf.example",
    approved_version + "/junglelaw-server-stop.sh",
    approved_version + "/junglelaw-server.service",
    approved_version + "/manifest.json",
    approved_version + "/test_junglelaw_server_deploy.sh",
    approved_version + "/test_junglelaw_server_stop.py",
    approved_version + "/verify_candidate_local.sh",
    approved_version + "/verify_junglelaw_server_candidate.sh",
]
with tarfile.open(str(real_archive_path), mode="r:gz") as archive:
    real_members = archive.getmembers()
if [member.name for member in real_members] != expected_real_members:
    raise SystemExit("frozen real game archive member list drifted")
if not real_members[0].isdir() or any(not member.isfile() for member in real_members[1:]):
    raise SystemExit("frozen real game archive member types drifted")

run_validator(real_manifest_path, real_archive_path, 0)
real_manifest = json.loads(real_manifest_path.read_text(encoding="utf-8"))

def add_directory(archive, name):
    entry = tarfile.TarInfo(name)
    entry.type = tarfile.DIRTYPE
    entry.mode = 0o755
    archive.addfile(entry)

def add_bytes(archive, name, content):
    entry = tarfile.TarInfo(name)
    entry.size = len(content)
    entry.mode = 0o644
    archive.addfile(entry, io.BytesIO(content))

def write_manifest(path, artifact=approved_artifact, version=approved_version):
    manifest = dict(real_manifest)
    manifest["artifact_id"] = artifact
    manifest["version"] = version
    content = (json.dumps(manifest, sort_keys=True) + "\n").encode("utf-8")
    path.write_bytes(content)
    return content

def write_archive(path, manifest_bytes, root=approved_version, mutations=()):
    with tarfile.open(str(path), mode="w:gz") as archive:
        add_directory(archive, root)
        add_bytes(archive, root + "/manifest.json", manifest_bytes)
        for mutation in mutations:
            kind, name = mutation
            if kind == "file":
                add_bytes(archive, name, b"fixture")
            elif kind == "duplicate_manifest":
                add_bytes(archive, root + "/manifest.json", manifest_bytes)
            elif kind == "symlink":
                entry = tarfile.TarInfo(name)
                entry.type = tarfile.SYMTYPE
                entry.linkname = "manifest.json"
                archive.addfile(entry)
            elif kind == "hardlink":
                entry = tarfile.TarInfo(name)
                entry.type = tarfile.LNKTYPE
                entry.linkname = root + "/manifest.json"
                archive.addfile(entry)
            elif kind == "fifo":
                entry = tarfile.TarInfo(name)
                entry.type = tarfile.FIFOTYPE
                archive.addfile(entry)
            else:
                raise AssertionError("unknown fixture mutation: " + kind)

with tempfile.TemporaryDirectory(prefix="junglelaw-game-archive-") as temporary:
    temporary_path = Path(temporary)

    wrong_artifact_manifest = temporary_path / "wrong-artifact.json"
    wrong_artifact_bytes = write_manifest(wrong_artifact_manifest, artifact="wrong-artifact")
    wrong_artifact_archive = temporary_path / "wrong-artifact.tar.gz"
    write_archive(wrong_artifact_archive, wrong_artifact_bytes)
    run_validator(wrong_artifact_manifest, wrong_artifact_archive, 1, "unexpected game artifact identity")

    wrong_version = "v1.1.3-wrong-version"
    wrong_version_manifest = temporary_path / "wrong-version.json"
    wrong_version_bytes = write_manifest(wrong_version_manifest, version=wrong_version)
    wrong_version_archive = temporary_path / "wrong-version.tar.gz"
    write_archive(wrong_version_archive, wrong_version_bytes, root=wrong_version)
    run_validator(wrong_version_manifest, wrong_version_archive, 1, "unexpected game artifact identity")

    approved_manifest = temporary_path / "approved.json"
    approved_manifest_bytes = write_manifest(approved_manifest)

    wrong_root_archive = temporary_path / "wrong-root.tar.gz"
    write_archive(wrong_root_archive, approved_manifest_bytes, root=approved_artifact)
    run_validator(
        approved_manifest,
        wrong_root_archive,
        1,
        "game archive member is outside the exact version root",
    )

    invalid_fixtures = [
        (
            "extra-root",
            (("file", "unapproved-root/file"),),
            "game archive member is outside the exact version root",
        ),
        (
            "unsafe-parent",
            (("file", approved_version + "/../escape"),),
            "unsafe game archive member",
        ),
        (
            "duplicate",
            (("duplicate_manifest", ""),),
            "unsafe game archive member",
        ),
        (
            "symlink",
            (("symlink", approved_version + "/link"),),
            "unsafe game archive member",
        ),
        (
            "hardlink",
            (("hardlink", approved_version + "/hardlink"),),
            "unsafe game archive member",
        ),
        (
            "special",
            (("fifo", approved_version + "/pipe"),),
            "unsafe game archive member",
        ),
    ]
    for name, mutations, expected_error in invalid_fixtures:
        archive_path = temporary_path / (name + ".tar.gz")
        write_archive(archive_path, approved_manifest_bytes, mutations=mutations)
        run_validator(approved_manifest, archive_path, 1, expected_error)
PY

python3 - "${INSTALLER}" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")

def function_body(name, next_name):
    start = source.index(name + "() {")
    end = source.index(next_name + "() {", start)
    return source[start:end]

freeze = function_body("freeze_managed_services", "restore_service_baseline")
ordered_freeze = [
    "stop_if_active junglelaw-admin-dashboard-cert-renew.timer",
    "stop_if_active junglelaw-admin-dashboard-cert-renew.service",
    "stop_if_active junglelaw-admin-dashboard.service",
    "assert_pending_empty 'pre-game-stop freeze'",
    "stop_if_active junglelaw-server.service",
    "assert_pending_empty 'post-game-stop freeze'",
]
positions = [freeze.index(token) for token in ordered_freeze]
if positions != sorted(positions):
    raise SystemExit("managed-service freeze order is unsafe")

prepare = function_body("prepare_install", "activate_install")
for token in [
    "approved staging upgrade requires the pre-change game service to be active",
    "prepare requires explicit state-directory quarantine authorization for ERR recovery",
    "create_backup \"${BACKUP_ROOT}\"",
    "${GAME_RELEASE_SOURCE}/JungleLawServer.x86_64",
    "${GAME_RELEASE_SOURCE}/junglelaw-server.service",
    "${GAME_RELEASE_SOURCE}/junglelaw-server-stop.sh",
    "${GAME_RELEASE_SOURCE}/junglelaw-server-admin-dashboard.conf.example",
    "apply_admin_traverse_acl",
    "verify_shared_host_unchanged",
    "ADMIN_ENV_SOURCE=\"${SOURCE_DIRECTORY}/junglelaw-admin-dashboard.env.example\"",
    "ZHANCHENG_DASHBOARD_PORT=${DASHBOARD_PORT}",
    "selected dashboard environment port was not written exactly once",
    "mv -T -- \"${ADMIN_ENV_TEMP}\" \"${ADMIN_ENV}\"",
]:
    if token not in prepare:
        raise SystemExit("prepare contract missing: " + token)
if prepare.index("prepare requires explicit state-directory quarantine authorization") > prepare.index("freeze_managed_services"):
    raise SystemExit("prepare authorization is checked after service mutation")

activate = function_body("activate_install", "rollback_install")
if "systemctl start junglelaw-server.service" in activate:
    raise SystemExit("activate is forbidden from starting the game service")
for token in [
    "for _ in {1..30}",
    "systemctl is-active --quiet junglelaw-admin-dashboard.service",
    "certificate-verified public-IP health check failed after bounded startup wait",
]:
    if token not in activate:
        raise SystemExit("activate readiness polling contract missing: " + token)
if activate.index("systemctl enable --now junglelaw-admin-dashboard.service") > activate.index("for _ in {1..30}"):
    raise SystemExit("activate readiness polling starts before the dashboard start request")

rollback = source[source.index("rollback_install() {"):source.index("case \"${ACTION}\" in")]
ordered_rollback = [
    "rollback confirmation must equal backup id",
    "rollback requires --authorize-state-directory-quarantine",
    "validate_backup_receipt",
    "stage_backup_for_restore",
    "freeze_managed_services",
    "restore_backup_transaction",
]
positions = [rollback.index(token) for token in ordered_rollback]
if positions != sorted(positions):
    raise SystemExit("rollback validates or mutates in an unsafe order")

handler = function_body("transaction_error_handler", "prepare_install")
if "if (set -Eeuo pipefail" in handler:
    raise SystemExit("ERR recovery subshell is incorrectly placed in an if condition")
if "(set -Eeuo pipefail; freeze_managed_services; restore_backup_transaction" not in handler:
    raise SystemExit("standalone fail-fast prepare recovery subshell is missing")
if '$(stage_backup_for_restore' in source:
    raise SystemExit("restore stage must not run inside command substitution where Bash clears errexit")
stage = function_body("stage_backup_for_restore", "restore_backup_transaction")
if 'STAGED_RESTORE_ROOT="${stage_root}"' not in stage:
    raise SystemExit("restore stage does not return through the explicit global result slot")
manifest_reader = function_body("manifest_value", "verify_units_fail_on_unknown")
if "return 1" not in manifest_reader:
    raise SystemExit("manifest reader must explicitly return failure inside command substitution")

validator = function_body("validate_backup_archive", "service_was_active")
for token in ["allowed_live_roots", "allowed_archive_roots", "expected_archive"]:
    if token not in validator:
        raise SystemExit("exact Certbot lineage symlink boundary is missing")

# Deterministic state-machine mocks exercise the intended prepare, activate,
# failed-prepare recovery and rollback outcomes without touching a workstation.
class MockHost:
    def __init__(self):
        self.active = {"game": True, "admin": False, "timer": False, "renew": False}
        self.enabled = {"game": True, "admin": False, "timer": False}
        self.components = "old"
        self.data = "old"
        self.deleted = []
        self.quarantine = []

    def prepare(self, authorized, inject_failure=False):
        if not authorized or not self.active["game"]:
            raise RuntimeError("fail closed before mutation")
        baseline = (dict(self.active), dict(self.enabled), self.components, self.data)
        self.active.update(timer=False, renew=False, admin=False, game=False)
        self.components = "v1.1.3"
        self.active["game"] = True
        if inject_failure:
            self.quarantine.append(self.data)
            self.active, self.enabled, self.components, self.data = baseline
            raise RuntimeError("recovered exact backup")

    def activate(self):
        if not self.active["game"]:
            raise RuntimeError("no implicit game start")
        self.active["admin"] = True
        self.enabled["admin"] = True
        self.active["timer"] = True
        self.enabled["timer"] = True

    def rollback(self, exact_id, authorized):
        if exact_id != "exact" or not authorized:
            raise RuntimeError("no mutation")
        self.active.update(timer=False, renew=False, admin=False, game=False)
        self.quarantine.extend(["server", "admin_state", "commands", "exports", "tls"])
        self.components = "old"
        self.data = "old"
        self.active["game"] = True
        self.enabled.update(game=True, admin=False, timer=False)

host = MockHost()
try:
    host.prepare(True, inject_failure=True)
except RuntimeError:
    pass
assert host.components == "old" and host.data == "old" and host.active["game"]
assert host.deleted == [] and host.quarantine
host.prepare(True)
host.activate()
assert host.components == "v1.1.3" and host.active["admin"] and host.active["timer"]
host.rollback("exact", True)
assert host.components == "old" and host.data == "old" and host.active["game"]
assert not host.active["admin"] and not host.active["timer"] and host.deleted == []
PY

# A real Bash probe guards the subtle errexit rule used by the ERR recovery:
# the recovery subshell must be a standalone command, never the condition of an
# if/while/or-list where Bash suppresses -e inside called functions.
ERREXIT_PROBE="$(mktemp -d)"
set +e
(
	set -Eeuo pipefail
	false
	printf '%s\n' 'unsafe continuation' > "${ERREXIT_PROBE}/continued"
)
ERREXIT_STATUS=$?
set -e
[[ "${ERREXIT_STATUS}" -ne 0 ]] || fail 'standalone recovery subshell did not propagate failure'
[[ ! -e "${ERREXIT_PROBE}/continued" ]] || fail 'standalone recovery subshell continued after failure'
rmdir "${ERREXIT_PROBE}"

# Bash deliberately clears errexit inside command substitution. This live probe
# documents the hazard and pairs with the structural ban above.
set +e
COMMAND_SUBSTITUTION_PROBE="$(
	bash <<'BASH'
set -e
value="$(false; printf '%s' 'unsafe-continuation')"
printf '%s' "${value}"
BASH
)"
COMMAND_SUBSTITUTION_STATUS=$?
set -e
[[ "${COMMAND_SUBSTITUTION_STATUS}" -eq 0 && "${COMMAND_SUBSTITUTION_PROBE}" == 'unsafe-continuation' ]] \
	|| fail 'Bash command-substitution errexit hazard probe changed unexpectedly'

printf '%s\n' 'Jungle Law admin deployment overlay static verification: PASS'
