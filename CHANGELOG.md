# Changelog

Releases of Brahma, the suite app in `app/`. Each app keeps its own
changelog in `apps/<name>`.

## Unreleased

- New app: Bhojana (shopping, `apps/bhojana`), with UK shopping lists, price comparison across
  shops, live prices through your own shop logins and basket filling.
- Anveshana splits in two: Graha Anveshana (property, still `apps/anveshana`) and the new
  Vahana Anveshana (cars, `apps/vahana`), each with its own card, look and database.
- Every app's phone navigation is a scrolling dock plus a side panel (swipe right on any page);
  the bottom bar and its More sheet are gone. Vani keeps its own bar for now.
- Apps updated: Graha Anveshana 0.4.1 (postcode lookups fixed), Vahana Anveshana 0.2.1,
  Artha 0.2.0-beta.15, Udyoga 0.3.1, Vidya 0.2.1.

## 0.1.0 (2026-10-24)

First test release.

- One app for Artha (money), Anveshana (property), Udyoga (career), Vani (social media) and
  Vidya (learning), each in its own look.
- Home is a life dashboard: a live card per app with its key figures and the next thing to do;
  a card opens the app and "All apps" comes back.
- One sign-in, one encryption key and one sync account cover every app; each app keeps its own
  encrypted database.
- Linux, Windows and Android builds.
