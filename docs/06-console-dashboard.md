# 06 – Console dashboard and running with the lid closed

Built Sun 1 Nov 2026.

## Goal

Make the server's own screen show live system stats without leaving a logged-in session sitting on the keyboard.

## The idea, and why it is the safe version

The obvious way is to log in at the laptop and run a dashboard. That leaves a logged-in shell on the screen, and anyone who touches the keyboard gets my account. Instead, a systemd service runs `btop` on the first console as a locked-down user that has **no password and no sudo**. The screen shows stats, and there is no shell to reach.

## Steps

1. Install and create the user:
   ```bash
   sudo apt install -y btop
   sudo adduser --disabled-password --gecos "" display
   ```
2. Create `/etc/systemd/system/console-dashboard.service`. The tested version is in `configs/console-dashboard.service`.
3. Start it:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now console-dashboard
   ```
4. **Lid closed.** Without a setting, a laptop sleeps when the lid closes. A drop-in file (`configs/logind-lid.conf`, copied to `/etc/systemd/logind.conf.d/`) makes the lid do nothing. I rebooted to apply it, then tested by pinging the server with the lid shut. Replies kept coming.
5. **Dim the screen** by writing a low value to the backlight file under `/sys/class/backlight/`.
6. **Heat and power:** the laptop sits on a cooler stand on a hard surface, because a closed lid on a soft surface traps heat. I removed the battery to avoid long-term swelling from being plugged in constantly. If the BIOS has a "power on after AC loss" setting, enable it, otherwise a power cut means pressing the power button.

## Problem: the service crash-looped

| | |
|---|---|
| Symptom | `journalctl` showed `status=1/FAILURE` and a restart counter climbing |
| Clue | The journal gave no reason. `btop` prints its error on the screen it is drawing to, not into the log |
| Cause | I had used a flag that does not exist (`--tty_mode`) |
| Fix | `btop --help \| grep -i tty` showed the real option, `-t`. I changed the `ExecStart` line to `/usr/bin/btop -t` |

When the log is silent, run the program by hand as the same user to see the real message: `sudo -u display TERM=linux btop -t`.

## Other small lessons

- A reboot ends every SSH session. My "dropped connection" after setting the lid option was just the reboot, and `uptime` ("up 8 min") proved it.
- `who` shows who is really logged in. Entries on the laptop's own console (`tty1`, `tty2`) are worth checking on a machine left unattended.

## What I learned

- Security can shape even a cosmetic feature. Showing stats does not require leaving a shell open.
- Always check a flag with `--help` before putting it in a service file.
