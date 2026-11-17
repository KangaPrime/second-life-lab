# 11 – Automatic security updates

Done Tue 17 Nov 2026.

## Goal

Install security fixes without relying on me to remember, while avoiding surprise reboots that would silently take down alerts and DNS.

## Server (Ubuntu)

Already correct out of the box. Checked, not assumed:

```bash
dpkg -l unattended-upgrades | tail -1        # "ii" = installed
cat /etc/apt/apt.conf.d/20auto-upgrades      # both lines "1" = check and install daily
sudo unattended-upgrade --dry-run -v        # pretend to upgrade, show allowed sources
ls /var/run/reboot-required                 # "No such file" = no restart waiting
```

Decision: **automatic reboot stays off.** A surprise reboot would pause Kuma and my alerts. I check for `/var/run/reboot-required` instead.

## Pi (Raspberry Pi OS, Debian trixie)

The tool was installed and switched on, but a dry run showed a gap:

- Allowed sources were **Debian archives only**.
- The OpenSSL package on the Pi had come from `archive.raspberrypi.com` (the `+rpt` in the version). Raspberry Pi rebuilds some Debian packages, apt prefers their version, and the updater ignored that source. So some security fixes would not install by themselves.

**Fix:** a separate drop-in file, so the packaged config is never edited and a future update cannot overwrite it:

```
# /etc/apt/apt.conf.d/52unattended-upgrades-rpi
Unattended-Upgrade::Origins-Pattern {
    "origin=Raspberry Pi Foundation,codename=${distro_codename},label=Raspberry Pi Foundation";
};
```

I copied the exact origin and label from `apt-cache policy | grep -A1 raspberrypi` instead of guessing, and a dry run then listed the new entry under "Allowed origins".

## Clearing the backlog on the Pi

`apt` reported 25 packages not upgraded. Automatic updates only handle security fixes, so ordinary updates wait for me. After a fresh Teleporter backup I ran `sudo apt upgrade -y` and rebooted. The list included OpenSSL, a kernel (`6.18.50` to `6.18.60`), Tailscale and the Pi's boot firmware. Afterwards: `uname -r` showed the new kernel, DNS was listening on 53 (IPv4 and IPv6), and `pihole status` showed blocking enabled.

Expected side effect: the Pi is the home DNS, so websites failed for about a minute and Kuma sent Telegram alerts, then recovered.

## Not automatic (on purpose)

- **Pi-hole itself** updates only with `pihole -up`. Back up with Teleporter first.
- **Laptop firmware** (`fwupdmgr`): a failed firmware update can brick a laptop, so it is a deliberate, supervised job.
- **Docker images** (Uptime Kuma): updated by hand after a backup.

## Troubleshooting log

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Please install powermgmt-base..." | Only relevant to battery-powered machines | Ignore |
| `pihole status` warns it cannot read `pihole.toml` | The file is root-only (good) | Use `sudo pihole status` |
| `Sorry, try again` at sudo | Mistyped password | Retype |

## What I learned

- "Automatic updates are on" is a claim to test, not a fact. A dry run showed what was really covered.
- Change behaviour with a drop-in file, not by editing the packaged one.
- Decide deliberately what stays manual.
