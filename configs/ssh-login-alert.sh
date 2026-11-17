#!/bin/bash
# /usr/local/bin/ssh-login-alert.sh  (owner root, mode 755)
# Sends a Telegram message when an SSH session opens. Never blocks the login.
# Secrets live in /etc/ssh-login-alert.conf (root-only, mode 600), NOT here:
#   TOKEN=<bot token>
#   CHAT=<chat id>
[ "$PAM_TYPE" = "open_session" ] || exit 0
. /etc/ssh-login-alert.conf || exit 0
MSG="SSH login: ${PAM_USER} from ${PAM_RHOST} on $(hostname) at $(date '+%a %d %b %H:%M:%S')"
(
  echo "url = \"https://api.telegram.org/bot${TOKEN}/sendMessage\"" |
    curl -s -m 5 -K - \
      --data-urlencode "chat_id=${CHAT}" \
      --data-urlencode "text=${MSG}" >/dev/null 2>&1
) &
exit 0
