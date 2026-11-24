#!/bin/bash
# /usr/local/sbin/homelab-health.sh  (owner root, mode 700)
# Daily health check. Messages Telegram only on problems (plus a Monday "all OK" heartbeat).
# Uses the bot token in /etc/ssh-login-alert.conf (root-only, mode 600), so nothing new is stored.
. /etc/ssh-login-alert.conf || exit 1
OWNER="<user>"
BK="/home/${OWNER}/backups"
HOST=$(hostname)
P=()

newest=$(ls -t "$BK"/SHA256SUMS-*.txt 2>/dev/null | head -1)
if [ -z "$newest" ]; then
  P+=("No backup checksum file found")
else
  age=$(( ( $(date +%s) - $(stat -c %Y "$newest") ) / 3600 ))
  [ "$age" -gt 36 ] && P+=("Newest backup is ${age} hours old")
fi
[ -f /var/run/reboot-required ] && P+=("Reboot pending: $(tr '\n' ' ' < /var/run/reboot-required.pkgs 2>/dev/null)")
mountpoint -q /srv/media || P+=("Media drive is not mounted")
for c in uptime-kuma jellyfin; do
  [ "$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null)" = true ] || P+=("Container $c is not running")
done
for m in / /srv/media; do
  u=$(df --output=pcent "$m" | tail -1 | tr -dc 0-9)
  [ "${u:-0}" -ge 85 ] && P+=("Disk $m is ${u}% full")
done
smartctl -H /dev/sda 2>/dev/null | grep -q PASSED || P+=("SSD SMART health is not PASSED")

send() {
  echo "url = \"https://api.telegram.org/bot${TOKEN}/sendMessage\"" |
    curl -s -m 10 -K - --data-urlencode "chat_id=${CHAT}" --data-urlencode "text=$1" >/dev/null 2>&1
}

if [ "${#P[@]}" -gt 0 ]; then
  msg="WARNING on ${HOST}:$(printf '\n- %s' "${P[@]}")"
  send "$msg"
  echo "$msg"
  exit 1          # a failed unit is also visible in systemctl
fi
[ "$(date +%u)" = 1 ] && send "${HOST} weekly check: all OK"
echo "all OK"
