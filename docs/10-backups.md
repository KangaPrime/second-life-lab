# 10 – Backups

Done Tue 17 Nov 2026.

## Goal

If the SSD dies, rebuild from a backup, not from memory. Prove the backup is good before trusting it.

## What is backed up

| Item | How | Contains secrets? |
|------|-----|-------------------|
| Server config files (netplan, SSH hardening, lid, dashboard service, ufw rules) | `tar` archive | Mostly no, but treat as private |
| Uptime Kuma data (monitors, settings, Telegram setup) | Docker volume copied with a throwaway container | **Yes** (bot token) |
| Jellyfin config (accounts, library settings; added 24 Nov) | Folder archive, with Jellyfin stopped for a few seconds | **Yes** (password hashes, API keys) |
| Pi-hole settings | Teleporter export from the web dashboard | Treat as private |

All archives live on my laptop in a folder **outside** the Git repo.

## Steps

1. **Make the archives on the server** (Kuma is stopped for a few seconds so its database is not copied half-written):
   ```bash
   mkdir -p ~/backups
   sudo tar czf ~/backups/configs-$(date +%F).tgz /etc/netplan /etc/ssh/sshd_config.d \
     /etc/systemd/logind.conf.d /etc/systemd/system/console-dashboard.service \
     /etc/ufw/user.rules /etc/ufw/user6.rules
   sudo docker stop uptime-kuma
   sudo docker run --rm -v uptime-kuma:/data -v ~/backups:/backup busybox \
     tar czf /backup/kuma-$(date +%F).tgz -C /data .
   sudo docker start uptime-kuma
   sudo chown $USER: ~/backups/*
   chmod 600 ~/backups/*
   ```
2. **Look inside without extracting:** `tar tzf <file>`. The config archive listed every expected file, and the Kuma one contained `kuma.db`. A file's size alone proves nothing (the config archive was only 1.5 KB, which looked suspiciously small).
3. **Pull to the laptop** (the laptop pulls, so the server never holds a key to my laptop):
   ```bash
   scp 'user@<server-ip>:backups/*.tgz' ~/homelab-backup/
   ```
4. **Prove the copy is identical** with checksums on both ends: `sha256sum` on the server and `shasum -a 256` on the Mac. The strings matched.
5. **Pi-hole:** Settings > Teleporter > Export, saved as `pihole-teleporter-<date>.zip` next to the others.
6. Old backups moved into a dated sub-folder so they cannot be mistaken for the current set.

## Troubleshooting log

| Symptom | Cause | Fix |
|---------|-------|-----|
| `zsh: no matches found: ...*.tgz` | The Mac's shell tried to expand the `*` locally before `scp` ran | Quote the remote path: `'user@host:backups/*.tgz'` |
| Key name and address glued together after `-i` | `-i` needs a key file, then a space, then `user@host` | Without `-i`, `scp` used my normal key |
| Typing `~/.ssh/` gave "permission denied" | I tried to run a folder | Use `ls ~/.ssh` to list it |
| `grep /etc/default/ufw` and `curl -6` run on the Mac gave nothing | Commands belong on the server | Read which machine the prompt names |

## Automating it (Thu 19 Nov)

Manual backups depend on remembering, so I scheduled both halves.

**Server (systemd timer, 03:30 nightly).** `configs/homelab-backup.sh` makes the archives and a `SHA256SUMS` file, keeps 7 days, and always restarts Kuma (a `trap` runs even if a step fails). `Persistent=true` on the timer means a night the server was off is caught up at the next boot. I used a timer rather than cron because it is built in and I already use systemd. The script leaves out `/etc/ssh-login-alert.conf`, because it holds a bot token and can be reissued.

**Mac (launchd, 10:00 daily).** `configs/mac-homelab-pull.sh` pulls the files, runs `shasum -c` against the server's checksum list, logs the result and shows a macOS notification on failure. A job missed while the laptop slept runs when it wakes. The server never holds a key to the Mac.

Tested in three stages: by hand, through `systemctl start` (the way the timer runs it), and through `launchctl kickstart` (the way the scheduler runs it). Both halves logged success.

| Symptom | Cause | Fix |
|---------|-------|-----|
| Script printed only `scp: Connection closed` | My `-q` flag hid the real error (`Permission denied (publickey)`) | Drop `-q` when diagnosing |
| Background pull could not log in | The Mac's agent held only the GitHub key. The server key needed a passphrase, and `BatchMode` cannot type one | `ssh-add --apple-use-keychain ~/.ssh/id_ed25519`, plus a `Host` block with `UseKeychain yes` and `IdentitiesOnly yes` in `~/.ssh/config` |

**Added 24 Nov: Jellyfin's config.** Without it, a dead SSD would mean redoing the first-run setup and every account. Both Kuma and Jellyfin are stopped together for about 15 seconds so neither database is copied half-written, and the `trap` restarts both even if a step fails. The same checksum list covers all three archives, and the Mac pull needed no change, because it fetches `backups/*` and verifies every file listed. The media drive is deliberately not backed up (replaceable and large).

**Observed:** after five days of running, every night's files were present on the Mac. One pull failed on 23 Nov (the Mac could not reach the server), and the next day's pull caught up. That is the design working: a failure is logged and notified, and the next run fills the gap. A daily health check now alerts if the newest backup gets older than 36 hours (see [14](14-health-check.md)).

## Limits (honest)

- The Pi-hole Teleporter export is still a manual click. Pi-hole v6 has an API that could automate it.
- The Mac pull only succeeds at home or over Tailscale, and fails with a notification otherwise. It tries again the next day.
- A backup failing on the server side is only noticed when the checksum or the file is missing. A "backup older than 2 days" alert would close that gap.
- I have not yet done a full restore test on a spare disk. The checksum and `tar tzf` checks prove the files are intact, not that a rebuild works end to end. The 6 Nov rebuild did prove the restore order for the server.
- The laptop is the only off-server copy. A second location (the planned NAS) would complete the 3-2-1 rule.

## What I learned

- A backup is only real once you have opened it and compared it.
- Pull backups from the safe machine, rather than giving the server a key to it.
- Archives that hold tokens get `chmod 600` and stay out of Git.
