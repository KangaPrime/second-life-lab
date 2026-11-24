#!/bin/bash
# /usr/local/sbin/homelab-backup.sh  (owner root, mode 700)
# Nightly backup of server configs, Uptime Kuma data and Jellyfin config. Runs as root from a systemd timer.
# Deliberately NOT backed up: /etc/ssh-login-alert.conf (holds a bot token; reissue after a rebuild)
# and the media drive (replaceable, and large).
set -euo pipefail
OWNER="<user>"
DEST="/home/${OWNER}/backups"
D=$(date +%F)
mkdir -p "$DEST"

tar czf "$DEST/configs-$D.tgz" /etc/netplan /etc/ssh/sshd_config.d \
  /etc/systemd/logind.conf.d /etc/systemd/system/console-dashboard.service \
  /etc/ufw/user.rules /etc/ufw/user6.rules /etc/pam.d/sshd \
  /usr/local/bin/ssh-login-alert.sh /usr/local/sbin/homelab-backup.sh 2>/dev/null

# Stop both databases so nothing is copied half-written; always restart them, even on error.
docker stop uptime-kuma jellyfin >/dev/null
trap 'docker start uptime-kuma jellyfin >/dev/null' EXIT
docker run --rm -v uptime-kuma:/data -v "$DEST":/backup busybox \
  tar czf "/backup/kuma-$D.tgz" -C /data .
tar czf "$DEST/jellyfin-config-$D.tgz" -C /srv/jellyfin config

chown "$OWNER": "$DEST"/*.tgz
chmod 600 "$DEST"/*.tgz
( cd "$DEST" && sha256sum "configs-$D.tgz" "kuma-$D.tgz" "jellyfin-config-$D.tgz" > "SHA256SUMS-$D.txt" )
chown "$OWNER": "$DEST/SHA256SUMS-$D.txt"
find "$DEST" \( -name '*.tgz' -o -name 'SHA256SUMS-*.txt' \) -mtime +7 -delete
