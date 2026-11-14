# 04 – Tailscale: private access from anywhere

Built Sun 1 Nov 2026. The server re-joined after the SSD rebuild on Fri 6 Nov 2026.

## Goal

Reach SSH, the Pi-hole dashboard and Uptime Kuma from outside my home, with **no port forwarding** and nothing exposed to the internet.

## Why Tailscale and not a plain WireGuard VPN

My ISP's newest hub is managed only through its app, shares IPv4 addresses between customers (a method called MAP-T), and port forwarding there is unreliable. Forum reports say the app may not even list devices with a static IP set on the device. A WireGuard server needs an inbound port. Tailscale makes outbound connections only, so it works regardless of what the router allows.

## Steps

1. **Account:** sign up with an identity provider that has two-step verification on. That account is the key to the whole private network.
2. **Apps:** install Tailscale on the laptop and phone and sign in.
3. **Server and Pi:** download the install script, read it, then run it:
   ```bash
   curl -fsSL https://tailscale.com/install.sh -o tailscale-install.sh
   less tailscale-install.sh
   sh tailscale-install.sh
   sudo tailscale up        # prints a link, approve it in the browser
   ```
4. **Firewall:** allow SSH, and on the Pi the dashboard and DNS, on the Tailscale interface only:
   ```bash
   sudo ufw allow in on tailscale0 to any port 22 proto tcp
   # Pi only:
   sudo ufw allow in on tailscale0 to any port 80 proto tcp
   sudo ufw allow in on tailscale0 to any port 53
   ```
5. **Key expiry:** disabled for the always-on machines in the admin console, so they do not silently drop off later.
6. **Subnet router on the Pi**, so remote devices can reach my home addresses (including Kuma):
   ```bash
   echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-tailscale.conf
   echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
   sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
   sudo tailscale up --advertise-routes=<lan-subnet>
   ```
   Then approve the route in the admin console (it does nothing until approved).
7. **Test from mobile data** (Wi-Fi off): the Pi-hole dashboard, and Kuma at its LAN address, both loaded.
8. **Pi-hole as DNS for every Tailscale device:** in the admin console's DNS page, add the Pi's Tailscale address as a nameserver and turn on "Override DNS servers". This blocks ads on mobile data too.

## Problem: the network felt like 2G with Tailscale on

| | |
|---|---|
| Symptom | Websites barely loaded and video crawled, but only with Tailscale on. Switching it off fixed it |
| Clue | `dig @<pi-tailscale-ip> <site>` printed `connection timed out; no servers could be reached` |
| Checked | The firewall had port 53 open on `tailscale0`, and `ss` showed Pi-hole listening on all addresses, so the packets were not being blocked |
| Cause | Pi-hole's default setting ("allow only local requests") ignores queries from Tailscale addresses. Every lookup waited for a timeout |
| Fix | In Pi-hole's DNS settings, allow all origins. After that `dig` answered in milliseconds, and I turned the override back on |

This is safe only because the firewall limits port 53 to the home network and the Tailscale interface. Port 53 is never forwarded on the router.

I turned the override off while diagnosing, so my devices stayed usable.

## Troubleshooting log

| Symptom | Cause | Fix |
|---------|-------|-----|
| Dashboard link would not open | I typed the placeholder text instead of the real Tailscale address | Replace placeholders with real values |
| `tailscale: command not found` on the laptop | The Mac app does not add a command to the path | Use the full path inside the app bundle, or make an alias |
| Pasted three commands separated by commas | Terminal treated them as one command | Run commands one at a time |

## Security notes

- Everything in the Tailscale account can now reach my home network, so the account has two-step verification on and holds only my own devices.
- The Pi is a dependency for DNS across the tailnet. If it is off, I can switch the override off in the admin console.

## What I learned

- Check each layer in order: firewall, then the listener, then the service's own access settings.
- A slow connection after a DNS change is usually DNS timing out, and `dig @server name` with its `Query time` line isolates it quickly.
