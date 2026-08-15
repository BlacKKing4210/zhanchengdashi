#!/usr/bin/env bash
# Installs a pre-exported Linux dedicated-server binary and systemd unit.
# Run as root on the target Linux server. This script deliberately does not
# transfer player account or analytics data; those require a separate approval.
set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then
	printf '%s\n' 'Run this installer as root.' >&2
	exit 1
fi

SOURCE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BINARY_PATH="${1:-${SOURCE_DIR}/JungleLawServer.x86_64}"
SERVICE_PATH="${2:-${SOURCE_DIR}/junglelaw-server.service}"
STOP_HELPER_PATH="${3:-${SOURCE_DIR}/junglelaw-server-stop.sh}"

if [[ ! -f "${BINARY_PATH}" ]]; then
	printf 'Dedicated-server binary not found: %s\n' "${BINARY_PATH}" >&2
	exit 1
fi

if [[ ! -f "${SERVICE_PATH}" ]]; then
	printf 'Systemd unit not found: %s\n' "${SERVICE_PATH}" >&2
	exit 1
fi

if [[ ! -f "${STOP_HELPER_PATH}" ]]; then
	printf 'Synchronous stop helper not found: %s\n' "${STOP_HELPER_PATH}" >&2
	exit 1
fi

if [[ ! -x /usr/bin/python3 ]]; then
	printf '%s\n' 'Required runtime dependency is missing: /usr/bin/python3' >&2
	exit 1
fi

if ! /usr/bin/python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 6) else 1)'; then
	printf '%s\n' 'Required runtime dependency is too old: Python 3.6 or newer is required.' >&2
	exit 1
fi

bash -n "${STOP_HELPER_PATH}"

if ! id -u junglelaw >/dev/null 2>&1; then
	useradd --system --home-dir /var/lib/junglelaw --create-home --shell /usr/sbin/nologin junglelaw
fi

install -d -o root -g root -m 0755 /opt/junglelaw
install -d -o root -g root -m 0755 /usr/local/libexec
install -d -o junglelaw -g junglelaw -m 0750 /var/lib/junglelaw
install -o root -g root -m 0755 "${BINARY_PATH}" /opt/junglelaw/JungleLawServer.x86_64
install -o root -g root -m 0755 "${STOP_HELPER_PATH}" /usr/local/libexec/junglelaw-server-stop
install -o root -g root -m 0644 "${SERVICE_PATH}" /etc/systemd/system/junglelaw-server.service

systemctl daemon-reload
systemctl enable --now junglelaw-server.service
systemctl --no-pager --full status junglelaw-server.service
