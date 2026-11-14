# 03 – Pi-hole on a Raspberry Pi

Built Tue 27 Oct 2026.

## Goal

Block ads and trackers for devices on my network, on a Raspberry Pi that is hardened before anything else is installed.

## How it works

Every website lookup is a DNS question: "where is this domain?". Pi-hole sits in the middle.

1. A device asks Pi-hole for a domain.
2. If the domain is on a blocklist, Pi-hole answers `0.0.0.0`, which goes nowhere, so the ad never loads.
3. If not, Pi-hole asks an upstream DNS provider (Cloudflare, with DNSSEC) and passes the answer back.

The Pi is **not a router**. It plugs into the router like any other device.

What it cannot do: ads served from the same domain as the content (such as video ads on big platforms), and devices that ignore my DNS setting (browsers with their own "secure DNS", phones with Private DNS or Private Relay).

## Hardware

Raspberry Pi 4 (4 GB), 32 GB microSD, wired Ethernet, and a 5 V / 2 A phone charger. `vcgencmd get_throttled` printed `throttled=0x0`, so there was no under-voltage.

## Steps

1. **Flash the card** with Raspberry Pi Imager: Raspberry Pi OS Lite (64-bit). In the settings: a hostname, a **non-default username**, a long password, UK timezone and keyboard, SSH enabled with **public-key login only**, and my public key pasted in (never the private one).
2. **First boot**, then `ssh <pi-user>@pihole.local`.
3. **Update and harden:**
   ```bash
   sudo apt update && sudo apt full-upgrade -y
   sudo apt install -y ufw unattended-upgrades
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw allow from <lan-subnet> to any port 22 proto tcp
   sudo ufw enable
   ```
   I kept a second SSH session open while enabling the firewall, then tested a new login.
4. **Fixed address.** The ISP hub cannot reserve IPs, and a DNS server must not move, so I set it on the Pi with NetworkManager:
   ```bash
   nmcli -t -f NAME,DEVICE connection show --active
   sudo nmcli con mod "<connection-name>" ipv4.method manual \
     ipv4.addresses <pi-ip>/24 ipv4.gateway <router-ip> ipv4.dns "1.1.1.1 9.9.9.9"
   sudo nmcli con up "<connection-name>"
   ```
   Note: unlike `netplan try`, `nmcli` changes are **saved permanently**, so I kept the undo command ready (`ipv4.method auto`).
5. **Install Pi-hole** from the official repository so I could see what I was running, rather than piping a script straight into a shell:
   ```bash
   sudo apt install -y git
   git clone --depth 1 https://github.com/pi-hole/pi-hole.git Pi-hole
   cd "Pi-hole/automated install/"
   sudo bash basic-install.sh
   ```
   Choices: Cloudflare as upstream DNS with DNSSEC, default blocklist, admin web interface. Then I set my own admin password with `sudo pihole setpassword`.
6. **Verify on the Pi:**
   ```bash
   dig @127.0.0.1 <normal-site> +short        # returns an IP
   dig @127.0.0.1 <ad-domain> +short          # returns 0.0.0.0
   ```
7. **Open the firewall for the home network only:**
   ```bash
   sudo ufw allow from <lan-subnet> to any port 53
   sudo ufw allow from <lan-subnet> to any port 80 proto tcp
   sudo ufw allow from <lan-subnet> to any port 443 proto tcp
   ```
   Port 53 must **never** be forwarded on the router. An open DNS server on the internet gets abused.
8. **Test on one device first.** I pointed only my laptop's DNS at the Pi, flushed the cache, browsed, and watched the query counter climb on the dashboard. Then I set the DNS by hand on my phone's Wi-Fi settings. The ISP hub cannot change the network-wide DNS, so each device is set individually.
9. **Back it up** with Settings > Teleporter. The file stays outside the repo, because it holds settings including the admin password hash.

## Troubleshooting log

| Symptom | Cause | Fix |
|---------|-------|-----|
| `pihole status` warned the settings file "cannot be read" | The file is root-only on purpose | Run `sudo pihole status`. Do not loosen the permissions |
| `dscacheutil: command not found` on the Pi | A macOS command run on the wrong machine | Check the prompt before pasting |
| Some redirects and pop-ups still appear | DNS blocking only sees domain names, not page contents | Add a browser ad-blocker as a second layer |

## What I learned

- Test on one device before changing everything.
- A DNS server is a single point of failure. If the Pi is off, devices using it look "offline".
- My public IPv6 prefix identifies my connection, so I blank it out before pasting output anywhere public.
