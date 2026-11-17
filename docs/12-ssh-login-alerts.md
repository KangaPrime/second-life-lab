# 12 – SSH login alerts to Telegram

Done Tue 17 Nov 2026.

## Goal

A phone notification every time someone logs in over SSH, naming the user, where from, which machine and when. A login I did not make would stand out immediately. Done on both the server and the Pi.

## Design choices

- **A separate Telegram bot** just for this. Its token sits on the server, so if it ever leaked, the worst case is fake alerts, not access to my Kuma setup.
- The token lives in a root-only file (`/etc/ssh-login-alert.conf`, mode 600), never in the script and never in Git.
- The alert can **never block a login**: the PAM line is `optional`, the message is sent in the background, and `curl` has a 5-second timeout.
- The token is passed to `curl` through its config input, so it does not appear in the process list.
- Only successful logins alert. With password login off, failed attempts are just noise.

## Steps

1. **New bot:** BotFather, `/newbot`, copy the token (treat it like a password), open the bot and press Start, then send it a message (a bot cannot message me first).
2. **Store the secrets safely.** The token is typed with `read -rs`, so it never appears on screen or in shell history:
   ```bash
   sudo install -m 600 -o root -g root /dev/null /etc/ssh-login-alert.conf
   read -rsp "Bot token: " T; echo
   C=$(curl -s -m 10 "https://api.telegram.org/bot${T}/getUpdates" \
       | grep -o '"chat":{"id":[0-9-]*' | head -1 | grep -o '[0-9-]*$')
   printf 'TOKEN=%s\nCHAT=%s\n' "$T" "$C" | sudo tee /etc/ssh-login-alert.conf >/dev/null
   unset T C
   ```
   The chat ID came from asking Telegram for the bot's recent messages. I check with `ls -l` and `wc -c`, never `cat`.
3. **The script** is in `configs/ssh-login-alert.sh`, installed root-owned and mode 755 so nobody else can edit what root runs.
4. **Test it by hand** before wiring it in:
   ```bash
   sudo env PAM_TYPE=open_session PAM_USER=test PAM_RHOST=manual-test \
     /usr/local/bin/ssh-login-alert.sh
   ```
5. **Wire it into SSH** (keeping a second session open as a safety net, and a backup of the original):
   ```bash
   sudo sshd -T | grep -i usepam
   sudo cp /etc/pam.d/sshd ~/pam-sshd.backup
   echo 'session optional pam_exec.so quiet /usr/local/bin/ssh-login-alert.sh' | sudo tee -a /etc/pam.d/sshd
   ```
6. **Real test:** a new terminal tab, a fresh SSH login, and the phone buzzed. Repeated on the Pi.

**Undo:** `sudo cp ~/pam-sshd.backup /etc/pam.d/sshd`.

## Troubleshooting log

| Symptom | Cause | Fix |
|---------|-------|-----|
| Could not find the chat ID in Kuma | It is not always easy to find in the UI | Ask Telegram directly with `getUpdates` using the new bot's token |

## Limits (honest)

- Alerts depend on Telegram being reachable. If it is down I get no message, but I can still log in.
- It does not alert on failed logins, console logins at the laptop, or Tailscale SSH sessions that bypass PAM, if I ever enable them.
- The token exists in one place per machine. If either machine is compromised, rotate the bot token in BotFather.

## What I learned

- Security tools must fail open for the user (`optional`) and fail loudly for attackers.
- Test each half separately before connecting them.
- Keep a way back before editing a login path.
