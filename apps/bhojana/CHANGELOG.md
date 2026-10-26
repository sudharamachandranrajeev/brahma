# Changelog

## 0.4.0

Lists price themselves, and baskets fill themselves.

- Each item added to a list is searched at every starred shop, and the best match at each is kept, in
  the same pack size across shops where they sell it. *Check prices* re-runs it for the whole list.
- *Where to shop* names the cheapest shop for the list (whole list, or like for like on the items every
  shop has) and what it saves over the next cheapest.
- *Fill a basket* adds the whole list to the shop's basket: it finds the priced product on each search
  page and presses Add, and the plus button for quantities. Items it could not add are listed.
- A product picked by hand replaces the automatic pick for that shop that day.
- Linux: the in-app browser (sign-in, live prices, baskets) works in builds on a system with WPE WebKit.

## 0.3.0

Bhojana on the web, and a browser extension for live prices.

- Web app (`web/`), served by your own sync server: lists, typed and synced prices, costing per shop,
  starred shops and postcode, sync status, add a device by QR code, owner tools. Works offline as an
  installable app. Same end-to-end encryption and account as the native apps.
- Browser extension (`extension/`, Chrome, Edge and Firefox 128+): the web app's Compare page searches
  your starred shops through it, in your signed-in browser, and keeps the prices you choose. Attached to
  this release as a zip.
- The setup wizard and the web app can pair with each other: a phone can add a browser and the other way round.

## 0.2.0

Self-hosted sync and a guided setup.

- Sync server: a Cloudflare Worker + D1 in `server/`, deployed with `npm run setup`. End-to-end encrypted;
  the server holds only ciphertext. Owner creates the first account, invites others with one-time codes.
- Setup wizard on a fresh install: server address or setup link, account, recovery key, or join from a
  device you already use. Skippable, and available later in Settings.
- Settings, Sync: owner tools to invite people and reset a member's login.
- Still works with a PocketBase sync server.

## 0.1.0

First release.

- Shopping lists: add items with quantity, tick them off, reorder by aisle-free simple order.
- Shops: 20 UK grocers, discounters and high-street stores, from Tesco to Primark.
- Compare: search one item across shops in the in-app browser and keep every price found.
- Live prices: sign in to a shop and set your postcode inside the app; prices, offers and stock come from your own session.
- Basket: fill a shop's basket from your list, one item at a time; you check out yourself.
- Delivery slots: open the shop's slot page signed in.
