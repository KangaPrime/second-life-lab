# 10 – Backups

Done Tue 17 Nov 2026.

## Goal

If the SSD dies, rebuild from a backup, not from memory. Prove the backup is good before trusting it.

## What is backed up

| Item | How | Contains secrets? |
|------|-----|-------------------|
| Server config files (netplan, SSH hardening, lid, dashboard service, ufw rules) | `tar` archive | Mostly no, but treat as private |
| Uptime Kuma data (monitors, settings, Telegram setup) | Docker volume copied with a throwaway container | **Yes** (bot token) |
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

## Limits (honest)

- Backups are manual for now. Automating them (a scheduled pull) is a future step.
- I have not yet done a full restore test on a spare disk. The checksum and `tar tzf` checks prove the files are intact, not that a rebuild works end to end. The 6 Nov rebuild did prove the restore order for the server.
- The laptop is the only copy. A second location (the planned NAS) would complete the 3-2-1 rule.

## What I learned

- A backup is only real once you have opened it and compared it.
- Pull backups from the safe machine, rather than giving the server a key to it.
- Archives that hold tokens get `chmod 600` and stay out of Git.
