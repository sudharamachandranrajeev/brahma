# Changelog

## 0.9.0

- Running total and budget: the list shows what is in the basket and what the whole list comes to at
  each item's best price. Set a budget for a list to see the basket fill against it, what is left to
  spare, and a warning when the list or the basket goes over.

## 0.8.0

- Group by aisle: the button on the list sorts it into aisles in the order a shop is walked (fruit and
  veg, bakery, meat, fish, dairy, frozen, cupboard and so on), each with how many are left.
- Add again: things you have bought before, and are not on the list now, sit above it as one-tap chips.

## 0.7.0

- Asda (and any shop behind Cloudflare's "Just a moment…" check) no longer fails to load. The check
  comes with an error status, which the Windows web view treated as a failed page: searches now read
  it as a bot check and ask you to answer it, and the in-app browser shows it. If a page really does
  not load, the browser says so, with Try again and Open in your browser, which is also in its toolbar.
- Every item has its own page: tap it on the list. It shows the aisle, how many, whether it is in the
  basket, the price at each shop as bars, the best and lowest prices seen, and a chart of how the
  price has moved. Compare, edit or delete it from there.
- Compare can add a search result straight to the list, with its price, and opens the new item.
- Price drops: tap Watch the price on an item and, when its best price falls below the last day it was
  priced, the list shows it ("£1.39 at Aldi, down 10p from £1.49 on 18 Oct") and so does the item.
- Items are drawn with an icon for their aisle (fruit and veg, dairy, bakery, household and more),
  guessed from the name.
- A fuller new look: the rounded Nunito typeface, rounded icons, a floating sage rail with a card to
  search every shop again, coral for the main action, and what the list costs at each shop drawn as
  pastel bars.

## 0.6.0

- A new look: warm cream and pastel clay cards with soft shadows, a sage-green rail and bar, and coral
  for prices.
- The list opens with a greeting and tiles for what is left to buy, what is in the basket, the shops
  compared and the multi-buys found.

## 0.5.1

- Windows: searching shops for list items no longer closes the app. A shop page calling the web view's
  script bridge crashed the Windows web view plugin; Bhojana does not use the bridge, so it is now off.

## 0.5.0

Multi-buy deals, with your say (Tesco, Asda and Iceland for now).

- A price is always the single-purchase price. A multi-buy (*Any 2 for £5*, *10 for £10*, *Buy 2 get 1
  free*, *3 for 2*) is read separately and shown next to it, never mixed in.
- The list's *Multi-buy deals* card shows each deal with what one costs alone, what one costs on the
  deal, and what your quantity costs both ways. *Take deal* or *Single price* decides how the shop is
  costed and how many *Fill a basket* adds. The choice syncs.
- Meal deals, "mix & match from" and "was" prices are no longer read as a product's price.
- Searches wait until the shop page stops changing, so late deal badges (Iceland) are read, and a load
  cut short by a shop's redirect no longer fails the search.
- When a shop shows its "are you a person" check instead of results, *Where to shop* says so and opens
  the shop to answer it, instead of the item looking unsold there.
- Live shop tests save the pages they read; `flutter test` replays the reader over them offline, so
  reader changes are checked without loading the shops again.

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
