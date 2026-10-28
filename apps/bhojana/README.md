# Bhojana

Grocery and shopping for the UK: shopping lists, price comparison across shops, live prices through
your own shop logins, and basket filling. Part of the [Brahma](https://github.com/sudharamachandranrajeev/brahma)
suite. Linux, Windows and Android, plus a web app served by your sync server.

<p>
  <img src="docs/screenshots/list-light.png" width="260" alt="A shopping list costed per shop">
  <img src="docs/screenshots/list-dark.png" width="260" alt="The list in dark mode">
</p>
<img src="docs/screenshots/shops-desktop.png" width="800" alt="The shops page on a desktop">

## What it does

- **Lists.** Type `2 milk` to add two of milk. Tick items off; untick everything for next week.
- **Priced as you type.** Each item you add is searched at every starred shop. Bhojana keeps the best
  match at each, in the same pack size everywhere it can (4 pints against 4 pints), and *Where to shop*
  names the cheapest shop for the list and what it saves over the next one. Put a size in the item
  (`milk 4 pints`) to choose it yourself.
- **Multi-buys, your call.** At Tesco, Asda and Iceland, a deal like *Any 2 for £5* is shown beside the
  single-purchase price, never instead of it. You choose *Take deal* or *Single price* for each one;
  that sets the list's cost at the shop and how many go in the basket.
- **Compare.** Search one product across your starred shops and keep a different product than the one
  Bhojana picked. Your pick replaces its pick for that shop.
- **Live prices with your login.** Sign in to a shop and set your postcode inside the in-app browser.
  Searches share that browser's cookies, so you see your Clubcard, Nectar or Lidl Plus prices, stock and
  local prices. Bhojana never sees your password and never stores card details.
- **Fill a basket.** Pick a shop (the cheapest comes first) and *Add all*: Bhojana searches each item in
  the shop's site, finds the product it priced and presses its Add button, then its plus button for each
  extra one. Anything it could not add is listed to add by hand. You check out yourself.
- **Delivery slots.** One tap opens a grocer's slot page, signed in.
- **22 shops:** Tesco, Sainsbury's, Asda, Morrisons, Ocado, Waitrose, Iceland, Co-op, Aldi, Lidl, Poundland,
  Poundstretcher, Home Bargains, B&M, HomeSense, TK Maxx, Matalan, Primark, Boots, Superdrug, The Body Shop
  and Sports Direct.

## Platform notes

- Android and Windows have the in-app browser and search for you.
- Linux: a build from source on a system with WPE WebKit (`pacman -S wpewebkit` on Arch, `wpewebkit` on
  Fedora) has the in-app browser too. The release tarball is built without it, because Ubuntu ships no
  WPE WebKit: there shops open in your normal browser and you type in the prices you find.
- Big supermarkets block automated browsers. Reading a page you are signed in to usually works. When a
  search comes back empty, open the shop, accept its cookie banner or sign in, and search again.
- Shop sites change. The search addresses live in `lib/domain/shops.dart`, and the price reader is one
  site-agnostic script in `lib/domain/reader.dart`. The script reads schema.org Product data, or product
  links with a £ price on their tile.

## Sync

Sync is optional and goes to a server you deploy yourself: [`server/`](server/README.md) is a Cloudflare
Worker (free plan is enough). On a fresh install the setup wizard walks you through it: server address
or setup link, your account, and the recovery key. Everything is end-to-end encrypted before it leaves the
device, and nothing about you or your server is in this repository.

The same server also serves **Bhojana on the web** ([`web/`](web/README.md)): open your server's address
in any browser, sign in or pair it like another device, and your lists, typed prices and starred shops are
there. A web page cannot read shop sites, so on a computer the [browser extension](extension/README.md) reads
live prices in your own signed-in browser for the web app's Compare page. The Android and Windows apps
read them too, and everything syncs.

## Privacy

The database is encrypted on the device. Sync is optional, to your own server, end-to-end encrypted.
Bhojana contacts shop websites only when you search or open one.

## Development

```sh
flutter pub get
flutter test                       # reader_test runs the page scripts in headless Chromium if installed
flutter test integration_test/live_app_test.dart -d linux   # the whole flow against the real shops
flutter test integration_test/live_shops_test.dart -d linux --dart-define=SHOPS=asda,iceland
                                   # reads real shop pages and saves them to test/live_pages (not committed);
                                   # flutter test then replays the reader over them offline (live_pages_test)
BHOJANA_SHOTS=/tmp/shots FLUTTER_ROOT=... flutter test test/screenshots_test.dart
flutter build linux --release && scripts/install-linux.sh
(cd server && npm ci && npm test)  # sync server; sync_worker_test.dart also needs Node 24
(cd web && npm ci && npm test)     # web app; web_interop_test.dart runs Dart against it
```
