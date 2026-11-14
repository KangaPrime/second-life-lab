# 02 – Docker and Uptime Kuma

Built Fri 23 Oct 2026. Fixed after a reboot on Tue 27 Oct 2026.

## Goal

Run a monitoring dashboard on the server, inside a container, reachable from my home network only.

## Why Docker

A container is a sealed box for one program. I can add, update or delete a service without touching the rest of the server, and nearly every project I plan (Home Assistant, a local AI model, more monitoring) runs this way. Uptime Kuma is the first one: it checks whether devices and websites are up and alerts me when they are not.

## Check capacity first

| Check | Result |
|-------|--------|
| `free -h` | 3.3 GiB usable RAM (one 4 GB stick), 3.6 GiB swap |
| `nproc` | 4 threads |

That is enough for light services. (Upgraded later, see [07](07-ram-ssd-upgrade.md).)

## Router findings (Fri 23 Oct)

- My ISP's hub has **no web admin page**. It is managed only through the ISP's phone app, so the "admin" logins I tried could never work. I lost time on this, so check the router model before guessing passwords.
- The app cannot reserve an IP address for a device. That mattered later (see the reboot problem below).
- Wi-Fi security was already WPA3. The app's port-forwarding list should stay empty, so nothing from the internet can reach the server.

## Steps

1. Install Docker and test it:
   ```bash
   sudo apt install -y docker.io docker-compose-v2
   sudo docker run hello-world
   ```
2. Run Uptime Kuma, publishing the port on the server's LAN address only:
   ```bash
   sudo docker run -d --restart=unless-stopped \
     -p <server-ip>:3001:3001 \
     -v uptime-kuma:/app/data \
     --name uptime-kuma louislam/uptime-kuma:1
   ```
3. Allow the port from the home network only:
   ```bash
   sudo ufw allow from <lan-subnet> to any port 3001 proto tcp
   ```
4. Check what is published. `sudo docker ps` should show `<server-ip>:3001->3001/tcp`, and `sudo ss -tulpn | grep 3001` should show the same address, not `0.0.0.0`.
5. Open `http://<server-ip>:3001`, create an admin account with a strong, unique password, and add monitors:

   | Name | Type | Target |
   |------|------|--------|
   | Router | Ping | `<router-ip>` |
   | Home server | Ping | `<server-ip>` |
   | Internet check | HTTP(s) | a well-known website |

6. Check the cost with `sudo docker stats --no-stream`: about 107 MiB of RAM and about 1.4 % CPU.

A Compose version of the same container is in `configs/uptime-kuma-compose.yaml`.

## Two security lessons

- **Docker can bypass the firewall.** Publishing a port with `-p 3001:3001` makes Docker add its own firewall rules that skip `ufw`. Binding the port to the LAN address (`-p <server-ip>:3001:3001`) keeps it on the home network.
- **Do not join the `docker` group.** It is equivalent to root without a password prompt. I use `sudo docker`.

## Problem: Kuma unreachable after a reboot (Tue 27 Oct)

| | |
|---|---|
| Symptom | Page would not load. `docker ps` was empty, then after `docker start` it showed `Up (healthy)` with an **empty PORTS column** |
| Clue | `docker ps -a` had shown `Exited (128)`, and `ss` found nothing listening on 3001 |
| Cause | After the reboot the router handed the server a **different IP**. The container was bound to the old one, so Docker opened no port |
| Fix | Pinned a static IP with netplan (`configs/netplan-example.yaml`), then recreated the container on the new address. The data lives in the `uptime-kuma` volume, so nothing was lost |

Details of the fix:

- `sudo netplan try` applies a change and **rolls back by itself** if I do not press Enter in time. My first attempt reverted because I was too slow, which is the safety net working.
- I told cloud-init not to rewrite the network config: `echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg`.
- I changed the restart policy from `always` to `unless-stopped`.

## Troubleshooting log

| Symptom | Cause | Fix |
|---------|-------|-----|
| `udo: command not found`, then a package got installed | Typo for `sudo`, and I followed the "install this package" suggestion | Read the command before accepting suggestions, then `sudo apt remove` the stray package |
| Shell prompt stuck on `>` | Missing closing quote mark | Ctrl+C and retype the command |
| Router login failed | The hub has no web login | Use the app, and skip the router for IP reservation |

## What I learned

- A running container is not the same as a reachable service. Check the published ports.
- A DHCP address is not a stable address. Pin the ones other things depend on.
- Docker and the firewall are separate systems, so audit what is actually listening.
