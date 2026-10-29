# Changelog

Releases of Brahma, the suite app in `app/`. Each app keeps its own
changelog in `apps/<name>`.

## 0.3.1 (2026-10-28)

- Windows builds again with Visual Studio 2026: 0.3.0 was never published because the Windows
  build failed.

## 0.3.0 (2026-10-28)

- More Brahma apps on the home screen: Vastra (fashion and personal care), Arogya (health
  records), Bhandara (storage and disk health) and Ganana (AI tokens, costs and limits). They run
  on their own for now; each card opens the app's download page.
- One sync server for every Brahma app (`server/`): at home on any Linux computer that stays on
  (`server/home/install.sh` sets up the service, daily backups, the firewall and prints a setup
  link and QR code), or on Cloudflare's free plan (`npm run setup`). Same protocol, owner and
  invites in both.
- First start asks where your data lives: on this device only, or synced through a home or cloud
  server, with step-by-step guides in plain words.
- "Find my home server" looks for a home server on your Wi-Fi; connection problems are explained
  in everyday words with what to try; Settings, Sync shows the server's health and last backup.
- At start-up, once a day, each app says when a newer version is out, with What's new, a one-tap
  download (Android APK, Windows setup) and Later.
- Apps can add a header, a footer and a floating panel to their side rail.
- Apps updated: Bhojana 0.9.0, Udyoga 0.4.5, and the latest work from Graha Anveshana, Vahana
  Anveshana, Artha, Vani and Vidya.

## 0.2.0 (2026-10-25)

- New app: Bhojana (shopping, `apps/bhojana`), with UK shopping lists, price comparison across
  shops, live prices through your own shop logins and basket filling (Bhojana 0.1.0).
- Anveshana splits in two: Graha Anveshana (property, still `apps/anveshana`) and the new
  Vahana Anveshana (cars, `apps/vahana`), each with its own card, look and database.
- A redesigned home dashboard: a dusk-to-saffron header, cards tinted by each app's colour, and
  each card's figures in equal columns with the next thing to do.
- Every app's phone navigation is a scrolling dock plus a side panel (swipe right on any page);
  the bottom bar and its More sheet are gone. Vani keeps its own bar for now.
- Apps updated: Udyoga 0.4.1 (LinkedIn studio, humanizer), Vani 0.2.0 (Telegram, AI inbox tools,
  moderation), Graha Anveshana 0.4.1 (postcode lookups fixed), Vahana Anveshana 0.2.1,
  Artha 0.2.0-beta.15, Vidya 0.2.1.

## 0.1.0 (2026-10-24)

First test release.

- One app for Artha (money), Anveshana (property), Udyoga (career), Vani (social media) and
  Vidya (learning), each in its own look.
- Home is a life dashboard: a live card per app with its key figures and the next thing to do;
  a card opens the app and "All apps" comes back.
- One sign-in, one encryption key and one sync account cover every app; each app keeps its own
  encrypted database.
- Linux, Windows and Android builds.
