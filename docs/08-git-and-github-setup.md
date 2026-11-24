# 08 – Git and GitHub setup

Set up Mon 2 Nov 2026. First portfolio push Sat 7 Nov 2026.

## Goal

Keep this lab documented in a public repository, without leaking anything private.

## Git in plain words

Git is a game with save points, and GitHub is the website that keeps an online copy.

| Word | Meaning |
|------|---------|
| Repository | A project folder that remembers every save point |
| Commit | One save point, with a short note |
| Push | Upload new commits to GitHub |
| Clone | Download a repository for the first time |

The daily loop is always the same:

```bash
git status                      # what changed?
git add <files>                 # put these in the box
git commit -m "short note"      # seal the box with a label
git push                        # upload it
```

`git status` is safe to run at any time.

## Steps

1. **Protect the account.** Two-factor authentication on. In Settings > Emails, keep my email private and block command-line pushes that expose it. Use my real name in the profile's display name field, so a recruiter can match it to my CV.
2. **Install and introduce myself:**
   ```bash
   git --version
   git config --global user.name "<Your Name>"
   git config --global user.email "<id>+<username>@users.noreply.github.com"
   git config --global init.defaultBranch main
   ```
3. **A separate SSH key for GitHub**, with its own passphrase:
   ```bash
   ssh-keygen -t ed25519 -C "github" -f ~/.ssh/id_ed25519_github
   pbcopy < ~/.ssh/id_ed25519_github.pub      # macOS: copy the PUBLIC half
   ```
   Paste it into GitHub under Settings > SSH and GPG keys. The file **without** `.pub` never leaves my laptop.
4. **Tell SSH to use that key for GitHub** by adding this to `~/.ssh/config`:
   ```
   Host github.com
     IdentityFile ~/.ssh/id_ed25519_github
     AddKeysToAgent yes
     UseKeychain yes
   ```
5. **Test it:** `ssh -T git@github.com`. The reply "successfully authenticated, but GitHub does not provide shell access" sounds like an error, but it is the success message.
6. **Create the repo** on GitHub (public, with a README and the MIT licence), then `git clone git@github.com:<username>/second-life-lab.git`.
7. **First save point:** edit the README title, `git add`, `git commit`, `git push`, refresh the page.

## Safety rules for a public repo

- Never commit passwords, passphrases, private keys, the Telegram bot token, Tailscale auth keys or backups.
- Use placeholders (`<server-ip>`, `<user>`) for addresses and usernames, and blur screenshots. My public IPv6 prefix, Tailscale addresses, MAC addresses and serial numbers stay out too.
- `.gitignore` blocks key files, `.env` files, archives and backup folders as a second safety net.
- Run `git status` and `git diff` before every commit, and read them.
- If a secret is committed by mistake, deleting the file is not enough because it stays in the history. Revoke the secret first, then clean the history.

## Troubleshooting log

| Symptom | Cause | Fix |
|---------|-------|-----|
| Could not find the "public" key | The `ssh-keygen` output prints a path, a fingerprint and a picture, none of which is the key | `cat` the `.pub` file. The key is one long line starting `ssh-ed25519` |
| Not sure which of two similar files to copy | Public and private files differ only by `.pub` | Only the `.pub` goes online |
| `(base)` in the terminal prompt | An Anaconda Python environment is active | Harmless, nothing to do with Git |
| `! [rejected] main -> main (fetch first)` | GitHub had commits my Mac lacked (I had edited the README in the browser) | `git fetch origin`, look at `git log --oneline HEAD..origin/main`, then `git pull --rebase origin main` and push. Never force-push over someone else's work |

## What I learned

- Small, frequent commits with plain notes show how I work.
- A public repo is a shop window, and I decide what goes in it.
- Separate keys for separate jobs: one for GitHub, another for my servers.
- Run `git pull --rebase` before starting or pushing. Five commits sat unpushed for two days because I did not notice the pushes were being rejected, so I now read the output of every push.
