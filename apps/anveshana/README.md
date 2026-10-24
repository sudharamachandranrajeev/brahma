# Anveshana

Property search, renting, buying, investment, development and lettings for Linux, Windows 11 and
Android. Part of **Brahma**, a suite of life-management apps that share one encrypted account
(with [Artha](https://github.com/sudharamachandranrajeev/artha) for money). The shared core and the
cloud alert service live in [brahma](https://github.com/sudharamachandranrajeev/brahma).

Status: first release, for testing. Built with Flutter 3.47.7; local data in an encrypted SQLite
database (SQLite3MultipleCiphers); optional sync through your own PocketBase server with end-to-end
encryption.

## What it does

- **Hunt.** Every property you are considering, to rent or to buy, grouped by stage (new,
  shortlisted, enquired, viewing, applied, agreed). Add one from a PropertyPal link (an advert or a
  whole search page) or by hand. Distances are measured from your home point. Adverts that go let
  or sold are flagged.
- **Contact.** Call, text, WhatsApp or e-mail agents and landlords from the app; each is logged
  against the property and moves it along. A ready-made first enquiry (is it free, what next, when
  to view) is signed with your details from Settings. Viewings and follow-ups are kept with it.
- **Alerts.** Saved searches run in the cloud on [Brahma Watch](https://github.com/sudharamachandranrajeev/brahma/tree/main/watch),
  a Cloudflare Worker on your own account, which pushes new listings, price drops and status
  changes to your phone through ntfy. The app sends it your searches and pulls in what it found.
- **Invest.** Appraisals with current UK rules: buy-to-let (purchase tax with the surcharges,
  yields, cash flow, Section 24, company ownership, lender stress test, break-even rent, equity
  over time), buying a home (affordability, stressed payments, cost of owning against renting,
  letting later) and small developments (GDV, build, finance, profit and residual land value).
  Save them to compare.
- **Research.** A report for any UK postcode from open data: UK House Price Index for the council
  area and the nation, street-level crime (police.uk; not Scotland) and sold prices (Price Paid;
  England and Wales). Links for flood risk, EPCs, planning, broadband and rents, per nation. A
  purchase tax calculator (SDLT, LBTT, LTT) and a development checklist.
- **Lettings.** Tenancies as landlord or tenant, rent due and received with arrears, deposits, and
  landlord checks (gas, EICR, EPC, alarms, registration...) that come round again when done.

Tax rates are as of October 2026 and are a starting point for your own checks, not advice.

## Install a test build

Builds are on the [releases page](https://github.com/sudharamachandranrajeev/anveshana/releases),
each with `SHA256SUMS.txt`.

- **Linux (x86-64):** unpack `Anveshana-<version>-linux-x64.tar.gz` and run `./install.sh` (for
  your user only; `./install.sh --uninstall` removes it). Needs GTK 3, libsecret and a running
  keyring, which holds the database key.
- **Windows 10/11:** run `Anveshana-<version>-windows-x64-setup.exe` (no admin rights), or unzip
  the portable build. SmartScreen warns because the build is not code-signed: *More info > Run
  anyway*.
- **Android 7+:** install `Anveshana-<version>-android.apk`.

Your data stays on the device, encrypted, until you turn on sync. An account made in any Brahma
app works in all of them.

## Brahma Watch (phone alerts)

1. In a checkout of [brahma](https://github.com/sudharamachandranrajeev/brahma): `cd watch`,
   `npm install`, `npx wrangler login`, `npm run setup`. It deploys the Worker to your Cloudflare
   account and keeps its address, API token and ntfy topic in `~/.config/brahma/watch.env`.
2. Install ntfy on your phone and subscribe to that topic.
3. In Anveshana: *Settings > Brahma Watch*, enter the address and the API token. Then *Searches* to send
   or copy searches, and *Test alert* to check the phone gets it.

## Develop

```sh
flutter pub get
flutter run -d linux
```

`brahma_core` comes from the brahma repository. To work on both at once, add a
`pubspec_overrides.yaml` (ignored by git):

```yaml
dependency_overrides:
  brahma_core:
    path: ../brahma/core
```

## Test

```sh
flutter analyze && flutter test
```

CI runs both on each push; a `v*` tag builds, smoke-tests and publishes the Android, Windows and
Linux builds (`.github/workflows/release.yml`). `scripts/make-icons.sh` regenerates the icons from
`branding/anveshana.svg`.
