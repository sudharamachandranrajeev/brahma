# Bhojana browser extension

Lets your own Bhojana web app read live prices from the shop sites you are signed in to, and press a
shop's Add button while it fills a basket. It is the web equivalent of the app's hidden web view:
a website cannot read another site's pages, so the extension does it in your browser, with your
Clubcard, Nectar or postcode, and hands the prices to your Bhojana page.

- Works in Chrome, Edge, Brave and Firefox 128+ on a computer. Phone browsers cannot run it; the
  Android app does the same job there.
- It opens only the shop sites Bhojana knows (`hosts.js`), and only when the Bhojana page on **your**
  server asks. It never sees your shop passwords and sends nothing to anyone but that page.
- Permissions are asked when you save your server address on the options page, not at install.

## Install

1. `cd extension && npm run pack` (needs `zip`), or load this folder as is.
2. Chrome: `chrome://extensions`, Developer mode, **Load unpacked**, choose this folder.
   Firefox: `about:debugging`, This Firefox, **Load Temporary Add-on**, choose `manifest.json`.
3. The options page opens. Enter your server address and allow the permissions.
4. Open your Bhojana web app and use Compare: shops are searched through the extension.

## Page protocol

The web app posts `{source: 'bhojana-web', id, type, …}` and receives
`{source: 'bhojana-ext', id, type, ok, …}` on `window`:

| type     | request                      | reply                                 |
|----------|------------------------------|---------------------------------------|
| `hello`  |                              | `version`                             |
| `search` | `url` of a shop search page  | `offers`: `{title, pence, unit, offer, url, inStock}[]` |
| `open`   | `url`, `addFirst` (boolean)  | `result`: `opened`, `added` or `none` |

## Develop

`npm test` checks that the shop list and the page scripts match `lib/domain/shops.dart` and
`lib/domain/reader.dart`, so a shop fix in the app is one copy-paste here.
