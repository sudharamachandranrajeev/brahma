# Brahma Watch

Cloud watcher for the Brahma life-management apps. A Cloudflare Worker runs
every 10 minutes, checks saved searches, and pushes changes to your phone
through [ntfy](https://ntfy.sh). Anveshana reads the same searches and events
over a small authenticated API.

Today it watches PropertyPal / PropertyNews searches: new listings that match,
price changes, and let-agreed / sale-agreed status changes. Searches are not
in code: Anveshana edits them through `PUT /watches`. `npm run setup` also
loads `~/.config/brahma/watches.json` when it exists (a JSON array of
watches; see `Watch` in `src/watch.ts`).

## Deploy

```sh
npx wrangler login   # once, opens the browser
npm run setup        # KV, secrets, deploy, first run, test push
```

`setup` keeps the ntfy topic, API token and worker URL in
`~/.config/brahma/watch.env` (mode 600). Re-running it reuses them. On the
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
npm test           # parser, filters, change detection, push format
npx tsc --noEmit
npx wrangler dev --test-scheduled   # .dev.vars: NTFY_TOPIC=..., API_TOKEN=...
```
