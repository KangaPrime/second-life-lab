# Journal

A dated log of what I did and what I learned. Details are on the project pages.

## Thu 22 Oct 2026: Day 1 – Ubuntu on the old laptop
Made a bootable USB, got past a disabled F12 boot menu (Windows kept starting), installed Ubuntu Server, and fixed a US/UK keyboard mix-up. Checked the old hard drive with `smartctl` (healthy, zero bad sectors) and grew the volume to use the whole disk. Set up SSH key login from my laptop. Mistake: I generated my first key on the server instead of the laptop. See [01](01-ubuntu-server.md).

## Fri 23 Oct 2026: Day 2 – Hardening and Docker
Turned off SSH password and root login, enabled a default-deny firewall, audited open ports, installed Docker and ran Uptime Kuma bound to the LAN address. Found that my ISP hub has no web admin page. See [02](02-docker-uptime-kuma.md).

## Tue 27 Oct 2026: Day 3 – Raspberry Pi and Pi-hole
Flashed and hardened a Pi, pinned its IP, installed Pi-hole, and tested on one device before rolling out. The server's IP changed after a reboot and Kuma went quiet, so I pinned the server's IP with netplan. See [03](03-pihole.md) and [02](02-docker-uptime-kuma.md).

## Sun 1 Nov 2026: Day 4 – Tailscale, alerts and a console dashboard
Private access from anywhere with no port forwarding, a subnet router on the Pi, Pi-hole as DNS for all my devices (after fixing a DNS timeout that made everything crawl), Telegram alerts from Kuma, and a locked-down dashboard on the server's own screen. See [04](04-tailscale.md), [05](05-telegram-alerts.md), [06](06-console-dashboard.md).

## Mon 2 Nov 2026: GitHub
Set up GitHub with two-factor, a private commit email and a dedicated SSH key. Created this repo and made my first commit. See [08](08-git-and-github-setup.md).

## Tue 3 Nov 2026: RAM
Bought £33 of used parts. Fitted 8 GB + 4 GB DDR3, confirmed 12 GB in the BIOS and tested it with `memtester`. See [07](07-ram-ssd-upgrade.md).

## Fri 6 Nov 2026: Day 5 – SSD swap and rebuild
Backed up, swapped in a 240 GB SSD, reinstalled and restored everything in a deliberate order. Found my GitHub key on the server (copied by the installer), checked its fingerprint, and replaced it with the proper server key. See [07](07-ram-ssd-upgrade.md).

## Sat 7 Nov 2026: Day 6 – Portfolio goes live
First README, the server page and a `.gitignore` that blocks keys, tokens and backups.

## Sat 14 Nov 2026: Day 7 – Alerts and an audit
Investigated flapping website alerts (a flaky check, not a breach), tuned retries, and audited my own network with Nmap. A version-detection scan briefly made the Pi-hole dashboard unresponsive, and a restart fixed it. See [05](05-telegram-alerts.md) and [09](09-network-audit.md).

## Tue 17 Nov 2026: Day 8 – Backups, updates and login alerts
Checked IPv6 exposure from the inside (the mobile network had no IPv6, so a real outside scan is still to do). Made, verified and pulled backups of the server configs, Kuma data and Pi-hole settings. Confirmed automatic security updates on both machines, found and fixed a gap on the Pi (the Raspberry Pi archive was not covered), and cleared 25 waiting packages, including OpenSSL and a new kernel. Added Telegram alerts for every SSH login, on the server and the Pi. See [10](10-backups.md), [11](11-automatic-updates.md), [12](12-ssh-login-alerts.md) and [09](09-network-audit.md).

## Thu 19 Nov 2026: Day 9 – Scheduled backups and Jellyfin
Automated the backups: a nightly systemd timer on the server, and a launchd job on the Mac that pulls and verifies them (it failed first because the Mac's agent held only the GitHub key, then worked after loading the server key into the keychain). Wiped and health-tested the old 500 GB hard drive through a USB adapter that cannot report SMART (a 4-hour full-surface write, clean), formatted it, mounted it permanently, and set up Jellyfin on it: LAN-only, read-only media, reachable away from home only through Tailscale. Reboot test passed. See [10](10-backups.md) and [13](13-jellyfin.md).

## Tue 24 Nov 2026: Day 10 – A pending reboot and a health check
Backups had run unattended for five nights (one Mac pull failed and recovered the next day). A routine check found a kernel update waiting for a restart, so I rebooted (everything came back by itself) and applied 11 other updates. Added Jellyfin's config to the nightly backup, and built a daily health check that messages Telegram only when something is wrong: stale backup, pending reboot, missing drive, dead container, full disk, SSD health. Tested the alert by faking a problem. Also fixed a Git problem: pushes had been rejected for days because the README was edited on GitHub. See [10](10-backups.md), [11](11-automatic-updates.md), [14](14-health-check.md) and [08](08-git-and-github-setup.md).

## Habits I have built

- Make one change, test it, and keep a second session open as a safety net.
- Read the prompt and the whole command before pressing Enter. Most of my mistakes were a missing letter, a stray character or the wrong machine.
- Back up before changing hardware, and delete copies of secrets afterwards.
- End every session with a `git push`.
- Use a drive's permanent name and a guard condition before any command that destroys data.
- Read the output of every push. A rejected push is not a pushed commit.
- A check is not trusted until I have seen its alert fire.
- Test claims instead of assuming them: a backup is real once opened and compared, and "updates are on" is real once a dry run shows what is covered.
