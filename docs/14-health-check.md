# 14 – Daily health check and the reboot lesson

Done Tue 24 Nov 2026.

## Goal

Stop relying on me to notice problems. A script checks the important things each morning and messages my phone **only when something is wrong**.

## What triggered it

After five days away, a routine check showed `/var/run/reboot-required` on the server: a kernel security update (`linux-image-7.0.0-44`) was installed but **not active until a restart**. I keep automatic reboots off on purpose (a surprise reboot would silently pause Kuma and my alerts), so nobody would have told me. That is a gap a script should cover.

## What it checks (`configs/homelab-health.sh`)

| Check | Why |
|-------|-----|
| Newest backup under 36 hours old | Catches "the backup silently stopped" |
| No reboot pending | The lesson above |
| Media drive mounted | A USB drive can drop out |
| `uptime-kuma` and `jellyfin` running | A container could crash |
| `/` and `/srv/media` under 85 % full | Warns before a full disk breaks things |
| SSD SMART health `PASSED` | The system disk is a used drive |

A **Monday "all OK" heartbeat** proves the check itself is alive. Silence on other days means healthy, which only works if the checker is known to be running.

## Design choices

- **Alerts only on problems**, so a message always means something.
- Reuses the secret file and bot from the SSH login alerts, so no new secret is stored. If the token is ever rotated, one file changes.
- Scheduled with a **systemd timer** (09:00 daily, `Persistent=true` so a missed run happens at the next boot). Exits non-zero on a problem, so `systemctl --failed` shows it too.
- Root-owned, mode 700, like the other scripts that root runs.

## Testing it

An alert I have never seen fire is one I cannot trust, so I tested both paths:

1. **Happy path:** run by hand, it printed `all OK`.
2. **Alert path:** I created a fake `/var/run/reboot-required`, ran the script, saw the Telegram message arrive, then deleted the fake file and confirmed it was gone.

## Related changes the same day

- **Jellyfin's config added to the nightly backup** (see [10](10-backups.md)). Both databases are stopped for about 15 seconds at 03:31 so nothing is copied half-written, and a `trap` always restarts them.
- **Kernel update applied with a reboot:** the media drive and both containers came back by themselves (the second successful reboot test).
- **11 ordinary updates applied** (fwupd, snapd, Tailscale and others). No restart needed, and nothing was disturbed.

## Limits (honest)

- If the whole server is down, this script cannot run. Kuma, watching from outside, covers that case.
- It uses one bot and one chat. If Telegram is unreachable, the warning does not arrive.
- It checks that backups are fresh, not that they could be restored. A periodic restore test is still on the list.
- The 36-hour threshold and 85 % disk limit are my own choices and may need tuning.

## What I learned

- "Automatic updates are on" does not mean the update is *active*. A restart can be pending, and nothing says so unless something checks.
- Alert only on problems, plus a regular heartbeat, so silence means something.
- Test the alert path on purpose. A check that has never fired might never fire.
