#!/bin/bash
# ~/bin/homelab-pull.sh on the Mac (mode 700). Pulls the server's backups and verifies checksums.
SRC='<user>@<server-ip>'
DEST="$HOME/homelab-backup/server"
LOG="$HOME/homelab-backup/pull.log"
ts() { date '+%F %T'; }
notify() { osascript -e "display notification \"$1\" with title \"Homelab backup\""; }
mkdir -p "$DEST"
# BatchMode: fail at once instead of waiting for a passphrase nobody can type.
# -p keeps original file dates so the 30-day cleanup counts from when each backup was made.
if ! scp -p -q -o ConnectTimeout=10 -o BatchMode=yes "$SRC:backups/*" "$DEST/"; then
  echo "$(ts) FAIL copy" >> "$LOG"; notify "Pull failed (not on home network?)"; exit 1
fi
cd "$DEST" || exit 1
LATEST=$(ls SHA256SUMS-*.txt | sort | tail -1)
if shasum -a 256 -c "$LATEST" >> "$LOG" 2>&1; then
  echo "$(ts) OK $LATEST" >> "$LOG"
else
  echo "$(ts) FAIL checksum $LATEST" >> "$LOG"; notify "Checksum mismatch!"; exit 1
fi
find "$DEST" -type f -mtime +30 -delete
