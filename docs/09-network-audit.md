# 09 – Network audit with Nmap

Done Sat 14 Nov 2026.

## Goal

Check my own network the way an attacker would, and compare what I find with what I **intended** to expose.

**Rule: only scan devices you own.** Scanning other people's networks is illegal.

## What I expected

| Device | Should be reachable from the home network |
|--------|-------------------------------------------|
| Server | SSH (22) and Uptime Kuma (3001) only |
| Raspberry Pi | SSH (22), DNS (53), Pi-hole dashboard (80, 443) |
| Everything else | Nothing |

## Commands

```bash
nmap -sn <lan-subnet>                         # who is on the network?
nmap -Pn --top-ports 1000 <server-ip>         # gentle port scan, skip the "is it up?" check
nmap -sV --top-ports 1000 <pi-ip>             # also detect service versions
sudo nmap -sU -p 53 <pi-ip>                   # DNS uses UDP too
```

## Results

| Check | Result | Matches plan? |
|-------|--------|---------------|
| Devices on the network | 7 hosts. I identified every one against the ISP app's device list and my own notes | Yes |
| Server | `22/tcp` and `3001/tcp` open, everything else filtered | Yes |
| Pi, TCP | `22` (OpenSSH), `53` (Pi-hole's DNS engine), `80`, `443` open. 996 other ports filtered | Yes |
| Pi, UDP | `53/udp` open | Yes |

**Finding 1: the firewall hides the server.** My first scan of the server said "Host seems down" after three seconds, although it was running. Without `sudo`, Nmap decides whether a host is up by trying ports 80 and 443. The default-deny firewall silently drops those, so Nmap gave up. That is the firewall doing its job. `-Pn` skips that check.

**Finding 2: a version-detection scan upset the Pi-hole web page.**

| | |
|---|---|
| Symptom | During and after the 4.5-minute `-sV` scan, the dashboard stopped answering and a Kuma alert arrived on my phone |
| What still worked | Ping, SSH and DNS answering, so the Pi had not crashed |
| Fix | `sudo systemctl restart pihole-FTL`, after which the dashboard returned and Kuma reported recovery |
| Likely cause | `-sV` sends many odd probe requests, and Nmap labelled the web ports `http?` and `https?`, meaning it never got a clean answer. The small web server was probably tied up handling the backlog. I did not confirm this from logs, so it is my best reading, not proven |
| How to strengthen it | Compare the Kuma history of the DNS monitor (stayed green) and the dashboard monitor (went red) over the scan window |

## Login audit

`last -a` on the server showed every login coming from my own laptop's address, dated to my work sessions, with nothing in the days when the website monitor was flapping (see [05](05-telegram-alerts.md)).

## IPv6 check from the inside (17 Nov)

The server has a public IPv6 address, so I checked IPv6 as well as IPv4:

- `grep IPV6 /etc/default/ufw` showed `IPV6=yes`.
- `ufw status verbose`: default `deny (incoming)`. The only IPv6 rule is SSH on the Tailscale interface. There is no rule allowing the public IPv6 address in.
- `ss -6 -tulpn`: SSH listens on all addresses (the firewall blocks it from the internet), Tailscale ports are on the tunnel, the clock-sync port is loopback-only and the DHCPv6 client port is link-local. Nothing unexpected.

This verifies the **rules**. It is good evidence but not proof, and I record it as "IPv6 rules verified, real outside scan still to do".

## Not tested yet

- A real scan **from outside** my home. I tried from mobile data, but the carrier gave no IPv6 (`curl -6` returned nothing), so the test could not run. Retry from any IPv6-enabled network with `nmap -6 -Pn -p 22,53,80,443,3001 <public-ipv6>`.
- The router itself.
- Repeating the scan on a schedule and comparing the results.

## What I learned

- Scan gently first (`-Pn`, a plain port scan) and use version detection sparingly on small devices.
- Compare results against intent. A "match" is a result, and so is a mismatch.
- A silent firewall can make a running host look dead to a simple scan.
