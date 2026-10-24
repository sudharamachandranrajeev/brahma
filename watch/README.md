# Brahma Watch

Cloud watcher for the Brahma life-management apps. A Cloudflare Worker checks
saved searches every 10 minutes and pushes changes to your phone through
[ntfy](https://ntfy.sh). Anveshana reads the same searches and events over a
small authenticated API.

It is also the social hub behind Vani: connected Instagram, Facebook Page,
YouTube, LinkedIn, Threads, Bluesky and Mastodon accounts, scheduled
publishing, a unified inbox with rules, discovery alerts and stats. See
[SOCIAL.md](SOCIAL.md).

Today it watches PropertyPal / PropertyNews searches: new listings that match,
price changes, and let-agreed / sale-agreed status changes. Searches are not
in code: Anveshana edits them through `PUT /watches`. `npm run setup` also
loads `~/.config/brahma/watches.json` when it exists (a JSON array of
watches; see `Watch` in `src/watch.ts`).

## Deploy

```sh
npx wrangler login   # once, opens the browser
npm run setup        # KV, D1, R2, secrets, deploy, first run, test push
```

`setup` keeps the ntfy topic, API token, TOKEN_KEY and worker URL in
`~/.config/brahma/watch.env` (mode 600). Re-running it reuses them; never
delete TOKEN_KEY, it decrypts the stored platform tokens. R2 has to be
enabled once in the Cloudflare dashboard first. On the
phone, install ntfy and subscribe to the printed topic (QR code shown).

## API

All calls need `Authorization: Bearer $API_TOKEN`.

| Call | Does |
|---|---|
| `GET /watches`, `PUT /watches` | Read or replace the saved searches (validated, max 50) |
| `GET /events?since=<ISO time>` | Alerts raised since a time (last 500 kept) |
| `GET /status` | Last run, last success and error per search |
| `POST /run` | Run now |
| `POST /test-notify` | Send a test push |

A search's first run records what is listed without alerting. Six failed runs
in a row (about an hour) push a warning, so a blocked or changed site is noticed.

## Develop

```sh
npm test           # property watches and the social hub (in-memory D1/KV/R2)
npx tsc --noEmit
npx wrangler d1 migrations apply brahma-watch --local
npx wrangler dev --test-scheduled   # .dev.vars: NTFY_TOPIC, API_TOKEN, TOKEN_KEY, PUBLIC_URL
```
