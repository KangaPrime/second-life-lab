# 05 – Telegram alerts from Uptime Kuma

Built Sun 1 Nov 2026. Tuned Sat 14 Nov 2026.

## Goal

Get a message on my phone when something at home goes down, and another when it recovers.

## Steps

1. **Create a bot.** In Telegram, message BotFather, send `/newbot`, and choose a name and a username ending in `bot`. BotFather returns a **bot token**. Treat it like a password.
2. **Message the bot.** Open the new bot, press Start and send "hi". A bot cannot message me until I have messaged it.
3. **Find my chat ID** by opening `https://api.telegram.org/bot<token>/getUpdates` in a browser and reading `"chat":{"id": ...`. My first try returned `{"ok":true,"result":[]}`. That meant the token was valid but the bot had received no message yet, so I messaged the right bot and refreshed. Then I cleared the URL from my browser history, because it contains the token.
4. **Add it to Kuma:** Settings > Notifications > Setup Notification > Telegram, enter the token and chat ID, press **Test**, tick "Default enabled" and apply to all monitors.
5. **Test a real alert.** I added a temporary Ping monitor for an address nobody uses, with a short interval. It went red, Telegram messaged me, and I deleted the monitor afterwards.

## Tuning noisy alerts (Sat 14 Nov)

| | |
|---|---|
| Symptom | A burst of messages: "Internet check: Down, read ECONNRESET", then "Up" a minute later, repeating for days |
| What it means | `ECONNRESET` is a connection to that website being cut off partway. It is an error on an outbound check, not a sign of intrusion |
| What I checked | Only the website monitor flapped. The router and server pings did not. The Down alert itself reached my phone, so the server's internet was working at that moment |
| Likely cause | One site occasionally resetting automated requests, or a brief blip on the ISP link. I cannot prove which |
| Fix | Retries set to 3 and retry interval to 20 seconds, so it only alerts after several failures in a row. I also added a second monitor, a ping to a public DNS address, to compare a plain connectivity test with the website check |
| Result | Both monitors stayed green afterwards |

I also checked that nobody had logged in unexpectedly (see [09](09-network-audit.md)).

## Limits

- Kuma lives in my house. If my internet or the server is down, it cannot message me, so silence is not proof that everything is fine. An outside monitoring service could cover that later.
- The server's own ping monitor tells me little if the server itself is the thing that has failed.

## Security notes

- The bot token is a secret. If it leaks, send `/revoke` to BotFather and put the new token in Kuma.
- The Kuma backup contains the token, so backups stay out of Git and off the server once used.

## What I learned

- An alarm that cries wolf gets ignored. Retries make alerts trustworthy.
- Read an error name before assuming the worst. `ECONNRESET` on one monitor, with everything else green, is a very different story from an outage.
