# 07 – RAM and SSD upgrade, and a clean rebuild

Parts bought Tue 3 Nov 2026. RAM fitted and tested the same week. SSD swapped and server rebuilt Fri 6 Nov 2026.

## Goal

Make the server faster and more reliable with cheap used parts, then rebuild it from a backup without losing any of the security work.

## Parts

| Part | Price |
|------|-------|
| 240 GB 2.5" SATA SSD | £20 |
| 8 GB DDR3 SODIMM, 1600 MHz | £12 |
| 4 GB DDR3 SODIMM, 1600 MHz | £1 |
| **Total** | **£33** |

## Before buying: what does the laptop accept?

`sudo dmidecode -t memory | grep -E "Type:|Speed|Size"` showed one 4 GB DDR3 stick (rated 1600, running at 1333), free slots, and a maximum of 8 GB per module. The BIOS "Information" tab gave the CPU and drive. The model label gave the exact laptop. A 2.5" SATA SSD fits, and an M.2 drive would not.

## RAM (done first, so any fault could be traced to it)

1. Shut down, unplug, remove the battery, and hold the power button to drain leftover charge.
2. Touch bare metal, handle the sticks by the edges, and seat each stick at an angle until the clips click.
3. **BIOS Main tab:** Total Memory 12288 MB, so both sticks were detected.
4. **In Linux:** `free -h` shows about 10 GiB. That is lower than 12 because the integrated graphics and kernel take a share, which is normal.
5. **Test the memory:** `sudo memtester 8G 1`. Every test reported `ok` and there was no `FAILURE`. Used RAM is a gamble, so this is worth the wait.

## Back up before touching the drive

Saved to my laptop (outside the Git repo): the netplan file, the SSH hardening file, the lid and dashboard service files, `ufw status verbose`, and the Kuma data volume:

```bash
sudo docker stop uptime-kuma
sudo docker run --rm -v uptime-kuma:/data -v ~/backup:/backup busybox \
  tar czf /backup/kuma-data.tgz -C /data .
sudo docker start uptime-kuma
```

Then `scp -r` the folder to the laptop and `tar tzf` the archive to prove it opens. The Kuma backup contains the Telegram token, so it must never go into Git.

## SSD swap and reinstall

1. Shut down, unplug, and take the battery out.
2. Slide the old drive out of its SATA connector, move the mounting screws and bracket to the SSD, and slide it in. The connector only fits one way.
3. Boot the Ubuntu installer USB. **Keyboard: English (UK).** On the storage screen, check it names the **SSD, not the old drive**, before confirming. This time the installer used the whole disk (about 216 GB), so the extra volume-extend step from the first install was not needed.
4. Same hostname and username, a long password, and tick *Install OpenSSH server*.
5. Keep the old drive in a labelled bag as a fallback until the new setup is proven, and wipe it before disposing of it.

## Restore, in this order

1. SSH key login, then the hardening drop-in (`configs/sshd-hardening.conf`)
2. Firewall (`ufw`), including `grep IPV6 /etc/default/ufw` to confirm IPv6 is filtered too
3. Static address (`configs/netplan-example.yaml`) and the lid setting
4. Docker, then restore the Kuma volume from the backup and recreate the container
5. Console dashboard service
6. Tailscale (after deleting the old machine entry in the admin console)

The order matters: access control first, then the firewall, then services, so nothing is exposed while I rebuild.

## Problem: a key I did not add was in `authorized_keys`

| | |
|---|---|
| Symptom | I logged in without a password or passphrase prompt on a brand-new server |
| Cause | The installer has an option to import SSH keys from GitHub. My GitHub key was copied onto the server, and the installer turned password login off |
| Why it matters | The GitHub key should only prove who I am to GitHub. Anyone able to add a key to my GitHub account could have logged in to the server |
| How I checked | `ssh-keygen -lf` on the key file on each machine. The fingerprints matched, so it really was my own key, not a stranger's |
| Fix | Added the dedicated server key with `ssh-copy-id -i`, proved it worked on its own with `ssh -i <key> -o IdentitiesOnly=yes`, deleted the GitHub key line from `authorized_keys`, then proved the GitHub key was refused |

After the hardening file went in, `sudo sshd -T | grep -iE "passwordauthentication|permitrootlogin|maxauthtries"` printed `no`, `no` and `3`. A `Permission denied` message about `50-cloud-init.conf` is harmless: that file is root-only, so I needed `sudo` to read it.

## SSD health (a used drive)

`sudo smartctl -a /dev/sda` on the new SSD: overall health `PASSED`, zero retired blocks, zero uncorrectable errors, about 95 % life left. It is a **used** drive (about 10,100 power-on hours and roughly 11.5 TiB written), which is fine for £20, but it is a reason to keep backups and shut down cleanly.

## Troubleshooting log

| Symptom | Cause | Fix |
|---------|-------|-----|
| `ssh-copy-id: No identities found` | Run on the server instead of the laptop | Run it from the machine that holds the key |
| Mac warning `REMOTE HOST IDENTIFICATION HAS CHANGED` | A new install has a new fingerprint on the same address | Expected after a rebuild. `ssh-keygen -R <server-ip>` |
| `sh-keygen: command not found` | A missing first letter | Read the command before pressing Enter |
| Prompt stuck on `>` | Missing closing quote mark | Ctrl+C and retype |

## What I learned

- Back up first, restore in a deliberate order, and delete backup copies of secrets afterwards.
- Check what an installer did on its own. A convenient option had quietly changed who could log in.
- Fingerprints let me check a key without exposing it.
