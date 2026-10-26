# Bhojana sync server

> **Moved:** every Brahma app, Bhojana included, now shares one server: the
> [Brahma sync server](https://github.com/sudharamachandranrajeev/brahma/tree/main/server), which
> runs at home (one installer) or on Cloudflare's free plan, and which the app's first-run setup
> walks you through. This copy still works and Bhojana still syncs with servers set up from it, but
> new fixes land in the Brahma server only, and this folder will go in a later release.

Your own sync server for Bhojana: a Cloudflare Worker with a D1 database. It keeps your lists in step
across the Android, Windows and Linux apps, and serves the web app ([`../web`](../web/README.md)) at the
same address. The server stores only ciphertext and wrapped keys, so it
cannot read your lists. The free Cloudflare plan is enough for a household.

## Deploy

You need a free Cloudflare account and Node 24 or newer.

```sh
cd server
npm install
npx wrangler login      # once; opens the browser
npm run setup
```

`npm run setup` creates the database, builds the web app into `public/`, deploys the Worker with it,
stores a signing key as a secret and prints:

- the address of your server, like `https://bhojana.<your-subdomain>.workers.dev`;
- a one-time setup link, `bhojana://setup?s=…&i=…`, shown only once.

Nothing personal is written to the repository: the database id goes into your local `wrangler.toml`
(do not commit it to a public fork) and the secrets live in Cloudflare.

## Set up the apps

Install Bhojana. On first start the setup wizard asks about sync. Choose **Set up sync**, paste the setup
link, and create the owner account (or open the server's address in a browser and use the setup code
there). Write down the recovery key it shows: with the password it is the only
way to unlock your synced data.

Add more devices from Settings, Sync, **Add a device** (a QR code the new device scans), or sign in with
the same e-mail and password.

## Other people

The first account is the owner. In Settings, Sync, the owner sees **Invite someone**: a one-time code,
valid for 7 days, that lets one more person create their own account. Nobody else can sign up.
A member who forgets their password gets a one-time reset code from **Reset a member's login**; they still
need their recovery key.

## Develop

```sh
npm test            # runs the handler on node:sqlite
npm run typecheck
npm run build:web   # the web app into public/ (wrangler needs the folder)
npm run dev         # wrangler dev, local D1
npm run deploy      # builds the web app, then wrangler deploy
```

`/api/*` always runs the Worker (`run_worker_first` in `wrangler.toml`); every other path is a file from
`public/`, and unknown paths get `index.html` so the web app's routes survive a reload.

The protocol is in `src/app.ts`; the Dart client is `WorkerApi` in `brahma_core`
(`core/lib/src/sync/worker_api.dart` in the Brahma repository).
