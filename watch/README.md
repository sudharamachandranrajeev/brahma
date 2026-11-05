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

It also reads the property alert emails that Rightmove, Zoopla, OnTheMarket,
OpenRent and SpareRoom send you, so England searches work too. Those sites
do not allow programs to read their pages, so Watch never fetches them. You
set up alerts on each site; your mailbox forwards the alert emails to Watch;
Watch applies your own limits (place and distance, price, bedrooms, words
such as "pets" or "-retirement"), drops the same home sent by a second site,
and pushes one alert per home. Keep it for your own use.

## Deploy

```sh
npx wrangler login   # once, opens the browser
npm run setup        # KV, secrets, deploy, first run, test push
```

`setup` keeps the ntfy topic, API token and worker URL in
`~/.config/brahma/watch.env` (mode 600). Re-running it reuses them. On the
phone, install ntfy and subscribe to the printed topic (QR code shown).

## Alert emails (England)

You need a domain on your Cloudflare account (Email Routing works only on a
domain you own there) and a mailbox that can forward, such as Gmail.

1. Redeploy with the mailbox that will forward the alerts. Email from any
   other sender is refused, so strangers cannot push fake adverts to you:
   ```sh
   ALLOWED_FORWARDERS=you@gmail.com npm run setup
   ```
2. In the Cloudflare dashboard, open your domain, then **Email → Email
   Routing**. Turn it on, and add a custom address such as `homes@` with the
   action **Send to a Worker**, choosing `brahma-watch`.
3. In Gmail, open **Settings → Forwarding and POP/IMAP → Add a forwarding
   address** and enter `homes@your-domain`. Gmail sends a confirmation code
   there; Watch pushes the code to your phone. Type it into Gmail yourself.
4. In Gmail, create a filter for each site's alert sender (for example
   `from:(rightmove.com OR rightmove.co.uk OR zoopla.co.uk OR onthemarket.com
   OR openrent.co.uk OR spareroom.co.uk)`) with **Forward it to** that
   address. Keep a copy in your inbox.
5. On each site, save your searches with **instant** email alerts.
6. In Anveshana, add an email search on the **Searches** page (place or
   postcode, distance, price, bedrooms, words) and tap **Send to Watch**.

Limits: an alert is only as fast as the site sends it. Rightmove puts at most
14 homes in one email and does not email cuts under 2%. Let-agreed and sold
changes do not come by email. The sites change their emails without notice:
when Watch finds no adverts in an alert, it pushes a warning and keeps a copy
(`GET /email`) so the reader can be fixed. The place of an advert comes from
its postcode or town through [postcodes.io](https://postcodes.io); one without
a findable place does not match a search with a distance.

## API

All calls need `Authorization: Bearer $API_TOKEN`.

| Call | Does |
|---|---|
| `GET /watches`, `PUT /watches` | Read or replace the saved searches (validated, max 50) |
| `GET /events?since=<ISO time>` | Alerts raised since a time (last 500 kept) |
| `GET /status` | Last run, last success and error per search (rewritten at most hourly while healthy) |
| `GET /email` | The last alert email read, and the last one the reader could not handle |
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
