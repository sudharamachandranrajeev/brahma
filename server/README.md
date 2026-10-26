# Brahma sync server

Your own server for every Brahma app: Brahma, Artha, Vidya, Graha Anveshana, Vahana Anveshana,
Bhojana, Vani and the apps that join later. It passes your data between your phone and computers.
Each device locks (encrypts) the data before sending it, so the server only ever holds data it
cannot read. One account works in every app.

You choose where it runs:

| | Home server | Cloud server |
| --- | --- | --- |
| Runs on | a Linux computer at home that stays on (an old laptop is fine) | Cloudflare's free plan |
| Costs | nothing | nothing for a household |
| Away from home | with [Tailscale](https://tailscale.com/download) (free) | works anywhere |
| You need | Git and Node.js 24+ on that computer | a free Cloudflare account; Git and Node.js 24+ on any computer |

Both run the same program (`src/app.ts`) and behave the same in the apps: the first account is the
owner, who can invite other people from **Settings → Sync → Invite someone**.

You don't need a server at all: on first start each app asks whether to keep everything on that
device only. Sync can be turned on later in Settings.

## Home server

On the computer that will be the server, open a terminal and paste:

```sh
git clone https://github.com/sudharamachandranrajeev/brahma.git
cd brahma/server/home
./install.sh
```

The installer checks the computer, installs the server as a background service that starts with
the computer, sets up a daily backup, offers to open the firewall for your home network (never the
internet), and prints a **setup link** plus a QR code. In any Brahma app choose **Sync across my
devices → Home server**, then paste the link or scan the code, and create your account. On the same
Wi-Fi, **Find my home server** in the app finds it for you.

Write down the **recovery key** the app shows. With your password it is the only way to unlock your
synced data.

Good to know:

- Keep the computer plugged in, and set it never to sleep, also with the lid closed.
- Give it a fixed address in your router ("DHCP reservation") so the address in your apps keeps working.
- To sync away from home, install Tailscale on the server and on each device, then run
  `./install.sh --link` for an address that works anywhere.

Looking after it:

| Command | What it does |
| --- | --- |
| `./install.sh --status` | Is it running? Accounts, devices, last backup, database check |
| `./install.sh --link` | Addresses and setup link again (with QR code if `qrencode` is installed) |
| `./install.sh --backup` | Back up now (a daily backup runs by itself; the newest 14 are kept) |
| `./install.sh --restore FILE` | Put a backup back (the current data is saved first) |
| `git pull && ./install.sh --update` | Update to the newest version |
| `./install.sh --port 8091` | Use another port (default 8090) |
| `./install.sh --uninstall` | Remove the server (asks before deleting data) |

The data lives in `~/.local/share/brahma-server` (`brahma.db`, `backups/`, and `server.env`, which
holds the signing key: keep it private, mode 600).

## Cloud server

On any computer with Git and Node.js 24 or newer:

```sh
git clone https://github.com/sudharamachandranrajeev/brahma.git
cd brahma/server
npm install
npx wrangler login      # once; opens the browser to allow your Cloudflare account
npm run setup
```

`npm run setup` creates the database, deploys the server, stores its signing key as a Cloudflare
secret, and prints your server address (`https://brahma-sync.<you>.workers.dev`) and a one-time
setup link. In any Brahma app choose **Sync across my devices → Cloud server**, paste the link,
and create your account. Running it again updates the server and keeps everyone's data.

The database id goes into your local `wrangler.toml`: don't commit it to a public fork.

## Security

- Passwords never reach the server: apps send a secret derived from the password with Argon2id.
  The server stores a keyed hash of it. Data is encrypted on the device with XChaCha20-Poly1305.
- The server can read e-mail addresses, device ids and when each device synced, nothing else.
- Sign-ups need the one-time setup code (the owner) or an invite code (everyone else, one use,
  7 days). Sign-in, sign-up, reset and pairing are rate limited per address.
- A home server serves plain `http` on your home network and Tailscale only; the apps refuse plain
  `http` to anything else, and Tailscale encrypts its traffic.

## Develop

```sh
npm ci
npm test            # protocol tests on node:sqlite, and the home server as a real process
npm run typecheck
npm run dev         # wrangler dev, local D1
```

The Dart client is `WorkerApi` in `core/lib/src/sync/worker_api.dart`; core's
`test/home_server_test.dart` drives it against the home server.
