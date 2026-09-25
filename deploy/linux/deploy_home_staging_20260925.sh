#!/usr/bin/env bash
# Authorized home-only overlay of the verified existing staging game service.
set -Eeuo pipefail
umask 077
UPLOAD=/root/junglelaw-home-20260925
BACKUP=/var/backups/junglelaw/home-20260925
ELF=/opt/junglelaw/JungleLawServer.x86_64
AUTHORITY=/var/lib/junglelaw/.local/share/godot/app_userdata/丛林法则/server/player_accounts.json
CANDIDATE=$UPLOAD/JungleLawServer-home-v1.0.0-staging.x86_64
COMPAT=$UPLOAD/JungleLawServer-home-compatible-rollback.x86_64
BASE_SHA=69c33449882ac2409c444af4b9d1e19edfd8e491fa578f2de46a5766e47f7d58
NEW_SHA=c54b4c8f1bd395e55a91f2c7f25e35f515d5dc6238d39fc2c24e4d88800c5fd3
COMPAT_SHA=686f7920244f0974f001155533cde3771e8db0a85c5e13f689c2c5abdbd8ccce
[[ $(hostname) == iZuf6h2p4ec532poqdbp8kZ ]]
[[ $(sha256sum "$ELF" | cut -d' ' -f1) == "$BASE_SHA" ]]
[[ $(sha256sum "$CANDIDATE" | cut -d' ' -f1) == "$NEW_SHA" ]]
[[ $(sha256sum "$COMPAT" | cut -d' ' -f1) == "$COMPAT_SHA" ]]
[[ -f "$AUTHORITY" && ! -e "$BACKUP" ]]
[[ -f /run/junglelaw/junglelaw-server.shutdown/ready.json ]]
[[ $(find /var/lib/junglelaw/admin_commands/pending -maxdepth 1 -name '*.json' -type f | wc -l) == 0 ]]
grep -q '"checks":12382,"failures":0' "$UPLOAD/economy-linux.log"
grep -q 'HOME_ROLLBACK_COMPATIBILITY {"checks":21,.*"failures":0' "$UPLOAD/rollback-linux.log"
for unit in junglelaw-server junglelaw-admin-dashboard fisher-server nginx; do systemctl is-active --quiet "$unit"; done
install -d -o root -g root -m 0700 "$BACKUP"
systemctl show junglelaw-admin-dashboard fisher-server nginx -p MainPID -p ActiveEnterTimestampMonotonic -p NRestarts -p ExecMainStatus > "$BACKUP/shared.before"
systemctl cat junglelaw-server > "$BACKUP/service.before"
cp -a "$ELF" "$BACKUP/original-pre-home-ELF"
install -o root -g root -m 0700 "$COMPAT" "$BACKUP/compatible-rollback-ELF"
sha256sum "$BACKUP/original-pre-home-ELF" "$BACKUP/compatible-rollback-ELF" > "$BACKUP/binaries.sha256"
sha256sum -c "$BACKUP/binaries.sha256"
date -u +%FT%TZ > "$BACKUP/start-time"
wait_ready() {
  for attempt in $(seq 1 20); do
    if systemctl is-active --quiet junglelaw-server && [[ -f /run/junglelaw/junglelaw-server.shutdown/ready.json ]]; then return 0; fi
    sleep 1
  done
  return 1
}
rollback() {
  trap - ERR
  # Compatibility code keeps new fields even when old clients save profiles.
  # The pre-home ELF must never reopen authority containing home progress.
  systemctl stop junglelaw-server || return 1
  install -o root -g root -m 0755 "$BACKUP/compatible-rollback-ELF" /opt/junglelaw/JungleLawServer.next
  mv -f /opt/junglelaw/JungleLawServer.next "$ELF"
  systemctl start junglelaw-server
  wait_ready
  printf '%s\n' ROLLED_BACK_COMPATIBLE_CODE > "$BACKUP/status"
}
trap rollback ERR
systemctl stop junglelaw-server
[[ $(systemctl show junglelaw-server -p ExecMainStatus --value) == 0 ]]
sha256sum "$AUTHORITY" > "$BACKUP/authority.before.sha256"
tar --acls --xattrs -cpf "$BACKUP/state.tar" -C / var/lib/junglelaw
sha256sum "$BACKUP/state.tar" > "$BACKUP/state.tar.sha256"
sha256sum -c "$BACKUP/state.tar.sha256"
install -o root -g root -m 0755 "$CANDIDATE" /opt/junglelaw/JungleLawServer.next
mv -f /opt/junglelaw/JungleLawServer.next "$ELF"
systemctl start junglelaw-server
wait_ready
[[ $(sha256sum "$ELF" | cut -d' ' -f1) == "$NEW_SHA" ]]
systemctl cat junglelaw-server > "$BACKUP/service.after"
cmp "$BACKUP/service.before" "$BACKUP/service.after"
systemctl show junglelaw-admin-dashboard fisher-server nginx -p MainPID -p ActiveEnterTimestampMonotonic -p NRestarts -p ExecMainStatus > "$BACKUP/shared.after"
cmp "$BACKUP/shared.before" "$BACKUP/shared.after"
sha256sum "$AUTHORITY" > "$BACKUP/authority.after.sha256"
systemctl show junglelaw-server -p MainPID -p ActiveState -p SubState -p NRestarts -p ExecMainStatus
printf '%s\n' DEPLOYED_HOME_STAGING > "$BACKUP/status"
trap - ERR
printf 'DEPLOYED home-v1.0.0-staging\nBACKUP %s\nSHA256 %s\n' "$BACKUP" "$NEW_SHA"
