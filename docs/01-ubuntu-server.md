# 01 – Ubuntu home server

Turning a 2013 Acer laptop (Core i3) into a hardened, always-on home server.

## Goal

A small, reliable Linux server for monitoring and Docker services, built from hardware I already owned, with security set up before anything else was installed.

## Hardware

| Part | Before | After |
|------|--------|-------|
| RAM | 4 GB DDR3 | 12 GB (8 GB + 4 GB DDR3 SODIMM, 1600 MHz) |
| Storage | 500 GB 5400 rpm hard drive | 240 GB SATA SSD |
| OS | Windows (unsupported) | Ubuntu Server LTS |

Hardware checks I ran:

- `smartctl -a /dev/sda` on both drives. Key values to look at: overall health `PASSED`, and the raw counts for reallocated sectors, pending sectors, and uncorrectable errors should all be 0.
- `memtester` for the new RAM (every test `ok`).
- BIOS Main tab to confirm the total memory (12288 MB).

## Build steps

1. **Make the install USB.** Download the Ubuntu Server LTS ISO (amd64) and write it to a USB stick with Rufus (Windows) or Balena Etcher (Mac).
2. **Boot from USB.** Enable the F12 boot menu in the BIOS if it does not appear.
3. **Install.** Use the whole disk, UK keyboard layout, a custom username, and tick *Install OpenSSH server*. Do not import SSH keys from GitHub.
4. **Update.**
   ```bash
   sudo apt update && sudo apt full-upgrade -y
   ```
5. **Key-based SSH.** On the admin machine (not the server):
   ```bash
   ssh-keygen -t ed25519
   ssh-copy-id <user>@<server-ip>
   ```
6. **Harden SSH.** Create `/etc/ssh/sshd_config.d/01-hardening.conf`:
   ```
   PasswordAuthentication no
   KbdInteractiveAuthentication no
   PermitRootLogin no
   MaxAuthTries 3
   ```
   The `01` prefix matters: SSH uses the first value it reads, and another file may otherwise override mine. Test it with a second session open before closing the first:
   ```bash
   sudo sshd -t && sudo systemctl restart ssh
   sudo sshd -T | grep -iE "passwordauthentication|permitrootlogin|maxauthtries"
   ```
7. **Firewall.**
   ```bash
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw allow from <lan-subnet> to any port 22 proto tcp
   sudo ufw enable
   ```
   The SSH rule goes in before `enable`, otherwise the firewall cuts off my own session.
8. **Fixed IP with netplan.** The ISP router could not reserve addresses, and a DHCP lease changed after a reboot. See `configs/netplan-example.yaml` (to be added, sanitised) and use `sudo netplan try`, which rolls back by itself if I lose the connection.
9. **Automatic security updates.** `unattended-upgrades`.
10. **Run with the lid closed.** Set `HandleLidSwitch=ignore` in `/etc/systemd/logind.conf.d/lid.conf`, and put the laptop on a cooler stand.
11. **Docker and Uptime Kuma.** Publish the port on the LAN address only, because Docker can bypass `ufw` when it binds to all addresses:
    ```bash
    sudo docker run -d --restart=unless-stopped \
      -p <server-ip>:3001:3001 -v uptime-kuma:/app/data \
      --name uptime-kuma louislam/uptime-kuma:1
    ```
12. **Audit what is listening.** `sudo ss -tulpn` should show only SSH, the Kuma port on the LAN address, and system services.

## Upgrade and rebuild (RAM + SSD)

1. Backed up the configs (netplan, SSH hardening, lid setting, service file, `ufw status`) and the Kuma data volume to my laptop.
2. Fitted the RAM, checked the BIOS and `free -h`, then ran `memtester`.
3. Swapped in the SSD and did a clean install, then restored each piece in order: SSH key login and hardening, firewall, fixed IP, Docker and Kuma, then Tailscale.
4. Kept the old drive as a fallback and deleted the backup copies from the server afterwards, because the Kuma backup contains a Telegram token.

## Troubleshooting log

| Symptom | Cause | Fix |
|---------|-------|-----|
| Windows disk check ran instead of the installer | F12 boot menu disabled | Enabled it in the BIOS |
| `"` typed instead of `@` | Installer layout was US | Set the keyboard to English (UK) |
| Login failed on the first boot | Wrong keyboard layout while typing the password | Typed the symbols using the US positions, then fixed the layout |
| `ssh-keygen` created the key on the server | Command run on the wrong machine | Keys must be created on the machine you log in from |
| Router admin page would not open | The router is app-managed, no web login | Used the app, then solved the IP problem on the server |
| Kuma container `Up` but unreachable after a reboot | The router gave the server a new IP, and the container was bound to the old one | Static IP with netplan, container recreated |
| `ssh-copy-id: No identities found` | Run on the server instead of the Mac | Run it from the admin machine |
| An unexpected key in `authorized_keys` | Installer imported my GitHub key | Compared fingerprints, added the correct key, removed the GitHub one |
| Shell stuck on `>` | Missing closing quote | Ctrl+C and retype |

## What I learned

- Make one change, test it, then move on, and keep a second session open as a safety net.
- A running container is not the same as a reachable service. Check the published ports.
- A DHCP address is not a stable address. Pin the ones that other things depend on.
- Used hardware is fine if it passes the checks, but back up anyway.
- Most of my errors were a missing letter, a stray character, or the wrong machine. Read the prompt and the whole command first.

## Security checklist for this server

- [x] Key-only SSH, password and root login off
- [x] Default-deny firewall, rules limited to the home network
- [x] No port forwarding on the router
- [x] Services bound to a specific address
- [x] Automatic security updates
- [x] Open ports audited
- [x] Backups kept off the server and out of Git
