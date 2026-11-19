# 13 – Jellyfin media server on a reused hard drive

Done Thu 19 Nov 2026.

## Goal

Stream my own music (and a few films) to my phone, at home and away, using the old 500 GB laptop hard drive, with no exposure to the internet.

## Plan

1. Read the drive's details (read-only).
2. Test its health. Wipe it securely at the same time.
3. Partition, format and mount it permanently.
4. Run Jellyfin in Docker, LAN-only, with the media mounted read-only.
5. Firewall rule, first-run setup, phone tests, reboot test.

## Why this hardware works

The server's i3 can **direct play** files (send them unchanged) but is too weak to **transcode** (convert on the fly). Music direct-plays on every device, which suits it. The drive holds only replaceable media: it is old and has no redundancy.

## Steps

### 1. Identify the drive (read-only)
```bash
lsblk -o NAME,SIZE,MODEL,TRAN,FSTYPE,MOUNTPOINT
sudo dmesg | tail -15
```
The USB adapter appeared as `sdb`, 465.5 GB, `TRAN usb`. The system SSD is `sda`. `lsblk` showed **no partitions**, although the drive had old Windows and Linux ones. `fdisk -l` explained it: the adapter reports the disk about 240 MB smaller than it is, so the kernel rejected the partition table's copy at the start ("GPT PMBR size mismatch").

### 2. Health check
SMART needs the adapter to pass the commands through. It did not. I tried `-d sat`, `sat,12`, `usbjmicron`, `usbsunplus` and `usbcypress`, and every one failed ("unsupported scsi opcode"). So I used a **full-surface write test** instead, which doubles as a secure erase.

### 3. Wipe and test, safely
A device letter can change, and the SSD must never be hit, so the target was the drive's permanent name under `/dev/disk/by-id/`, with a guard that refuses to run unless it still resolves to `sdb`:
```bash
ID=$(ls /dev/disk/by-id/ | grep -i '^usb-Land' | grep -v part | head -1)
[ "$(readlink -f /dev/disk/by-id/$ID)" = /dev/sdb ] && sudo systemd-run --unit=hdd-wipe \
  /bin/dd if=/dev/zero of=/dev/disk/by-id/$ID bs=4M conv=fsync status=progress
```
It runs as a systemd service, so closing the SSH session does not kill it. Progress on demand: `sudo pkill -USR1 -x dd; journalctl -u hdd-wipe -n 2`.

**Result:** 499,856,179,200 bytes written (the whole disk) in 4 h 6 min at about 34 MB/s, ending with `No space left on device` (the normal ending when writing zeros to a full disk), no `Input/output error`, and nothing in `dmesg`. The first speed readings (75 MB/s) were RAM caching, and the real speed was about half.

### 4. Partition, format, mount
```bash
echo ',,L' | sudo sfdisk --label gpt /dev/disk/by-id/$ID
sudo mkfs.ext4 -L media -m 0 /dev/disk/by-id/${ID}-part1
```
`-m 0` drops the 5 % reserve that only matters on a system disk (about 23 GB gained). The mount uses the UUID in `/etc/fstab` (see `configs/fstab-media-line.txt`) with `nofail`, so a missing drive cannot stop the server booting. I backed up `fstab` first and ran `sudo findmnt --verify` before mounting.

### 5. Jellyfin (`configs/jellyfin-compose.yaml`)
- Runs as my normal user, not root, with `no-new-privileges`.
- The web port is bound to the **LAN address only**, because Docker bypasses ufw for published ports.
- Media is mounted **read-only**, so a Jellyfin bug or compromise cannot alter the files.
- `create_host_path: false`: if the drive is not mounted, the container refuses to start instead of quietly creating an empty folder on the SSD.
- Config and cache sit on the SSD, which is faster and keeps the HDD for media only.

Firewall: `sudo ufw allow from <lan-subnet> to any port 8096 proto tcp`.

### 6. First-run setup
Done immediately after starting, because until the wizard finishes anyone on the Wi-Fi could claim the server. A separate admin name (not my server login) with a long unique password, libraries for `/media/music` and `/media/movies`, "allow remote connections" **off**, and automatic port mapping **off** (it would ask the router to open a hole to the internet).

## Tests

| Test | Result |
|------|--------|
| Music appears in the web UI | Pass |
| Container can see the drive (`docker exec jellyfin ls /media`) | Pass |
| Phone, away from home, **Tailscale on** (the Pi forwards traffic into the LAN) | Plays |
| Phone, away from home, **Tailscale off** | Cannot connect (the intended result) |
| Reboot: drive remounted, Jellyfin and Kuma back by themselves | Pass |

## Troubleshooting log

| Symptom | Cause | Fix |
|---------|-------|-----|
| Drive showed no partitions in `lsblk` | Adapter reports a slightly smaller size, so the partition table copy looked corrupt | Expected. The wipe and a new table fixed it |
| `smartctl` could not read the drive | Adapter does not pass SMART commands | Full-surface write test instead |
| Wipe service showed "Failed" | `dd` always errors at the end of a block device | Read the real last line: `No space left on device` |
| `journalctl` showed `[48K blob data]` and my error count read 0 | `dd` progress uses carriage returns, which journalctl treats as binary | `journalctl -a \| tr '\r' '\n'` before searching |
| Error pattern missed the ending | `dd` words it "IO error", not "error writing" | Match the actual text |

## Limits (honest)

- **One old drive, no redundancy.** Only replaceable media belongs on it.
- The write test is good evidence of health but not a guarantee, because the drive is old and there is no SMART data.
- `jellyfin:latest` is not pinned, so an image update can change behaviour. Pin a known-good version once it is stable.
- **The Jellyfin config (accounts, library settings) is not in the nightly backup yet.** To do.
- No transcoding: a device that cannot play a file natively will fail.
- Jellyfin is for media I own.

## What I learned

- Use permanent names and a guard condition before any destructive command.
- When a diagnostic tool cannot see inside a device, find another test that can.
- Defence in layers: LAN-only bind, firewall rule, remote access off, port mapping off, read-only media, non-root user.
- Test the reboot, not just the happy path.
