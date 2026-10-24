# Changelog

## 0.3.0

Anveshana is now two apps. This one, Graha Anveshana, keeps the homes: hunt, searches, invest,
research and lettings. The cars (added in 0.2.0) moved to Vahana Anveshana. App ids, the data folder
and the encryption key are unchanged, so it upgrades in place; cars you saved in 0.2.0 stay in the
database but are no longer shown (add them again in Vahana Anveshana from their advert links).

## 0.2.0

Added the Cars module, since moved to Vahana Anveshana.

## 0.1.0

First release, for Linux, Windows and Android.

- Hunt: properties to rent or buy by stage, from PropertyPal links or typed in, with distance from
  a home point and adverts that go let or sold flagged.
- Contact agents and landlords by call, text, WhatsApp or e-mail, logged against the property;
  a first enquiry signed with your details; viewings and follow-ups.
- Saved searches sent to Brahma Watch (Cloudflare Worker) for phone alerts; its finds come into
  the hunt.
- Appraisals: buy-to-let, buying a home and development (residual land value), with SDLT, LBTT
  and LTT, Section 24 and April 2027 property income rates.
- Area research for any UK postcode: house price index, crime, sold prices and links per nation.
- Lettings: tenancies, rent and arrears, deposits and recurring landlord checks.
- Encrypted on the device; optional end-to-end encrypted sync on the shared Brahma account.
- Hints on every screen, which can be hidden and brought back in Settings.
