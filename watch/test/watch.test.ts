import { test } from "node:test";
import assert from "node:assert/strict";
import { parseSearchPage, type Listing } from "../src/propertypal.ts";
import { diff, distanceKm, matches, type Watch } from "../src/watch.ts";
import { ntfyMessage } from "../src/notify.ts";
import { sampleCentre, samplePage } from "./sample.ts";

const watch: Watch = {
  id: "rent",
  name: "Rent ≤ £700, 1–3 bed, 2 km",
  source: "propertypal",
  path: "/property-to-rent/enniskillen",
  maxPrice: 700,
  minBeds: 1,
  maxBeds: 3,
  centre: sampleCentre,
  radiusKm: 2,
  includeUnpriced: true,
};
const page = parseSearchPage(samplePage);
const byAddress = (s: string) => page.listings.find((l) => l.address.includes(s))!;

test("parses the saved results page", () => {
  assert.equal(page.totalPages, 2);
  assert.equal(page.listings.length, 6);
  const flat = byAddress("Apt 1 Sample Street");
  assert.equal(flat.price, 650);
  assert.equal(flat.beds, 1);
  assert.equal(flat.agent, "Example Lettings");
  assert.equal(flat.agentPhone, "+44 28 9649 6000");
  assert.equal(flat.status, "toLet");
  assert.equal(flat.url, "https://www.propertypal.com/apt-1-sample-street-enniskillen/101");
  assert.equal(byAddress("Quiet Court").price, null, "hidden price");
});

test("rejects a page without results (e.g. a bot challenge)", () => {
  assert.throws(() => parseSearchPage("<html><title>Just a moment...</title></html>"), /__NEXT_DATA__/);
});

test("distance from the centre", () => {
  const flat = byAddress("Apt 1 Sample Street");
  const d = distanceKm(watch.centre!, { lat: flat.lat!, lon: flat.lon! });
  assert.ok(d > 0.4 && d < 1, `got ${d}`);
});

test("filters by price, beds and radius", () => {
  assert.ok(matches(watch, byAddress("Apt 1 Sample Street")), "£650, 0.5 km");
  assert.ok(!matches(watch, byAddress("Sample Road")), "£750 is over budget");
  assert.ok(!matches(watch, byAddress("Brookeborough")), "15 km away");
  assert.ok(!matches(watch, byAddress("Big House")), "4 bed, £1,200");
});

test("unpriced listings match only when asked", () => {
  const l: Listing = { ...byAddress("Apt 1 Sample Street"), price: null };
  assert.ok(matches(watch, l));
  assert.ok(!matches({ ...watch, includeUnpriced: false }, l));
});

test("let-agreed listings never match", () => {
  assert.ok(!matches(watch, { ...byAddress("Apt 1 Sample Street"), status: "letAgreed" }));
});

test("first run records silently, later runs alert on changes", () => {
  const first = diff(watch, page.listings, null, "t1");
  assert.equal(first.events.length, 0);
  assert.equal(Object.keys(first.seen).length, 6);

  const flat = byAddress("Apt 1 Sample Street");
  const road = byAddress("Sample Road");
  const fresh: Listing = { ...flat, id: "999", address: "1 New Street, Enniskillen" };
  const listings = page.listings
    .map((l) =>
      l.id === road.id ? { ...l, price: 695 } : l.id === flat.id ? { ...l, status: "letAgreed" } : l,
    )
    .concat(fresh);
  const second = diff(watch, listings, first.seen, "t2");
  const kinds = Object.fromEntries(second.events.map((e) => [e.listing.id, e.kind]));
  assert.deepEqual(kinds, { [road.id]: "price", [flat.id]: "status", "999": "new" });

  // Nothing changed: nothing to say.
  assert.equal(diff(watch, listings, second.seen, "t3").events.length, 0);
});

test("listings that left the search are forgotten", () => {
  const first = diff(watch, page.listings, null, "t1");
  const second = diff(watch, page.listings.slice(1), first.seen, "t2");
  assert.equal(Object.keys(second.seen).length, 5);
});

test("push message carries the listing and a call button", () => {
  const flat = byAddress("Apt 1 Sample Street");
  const msg = ntfyMessage("topic", { at: "t", watchId: watch.id, kind: "new", listing: flat, distanceKm: 0.5 }, watch.name);
  assert.equal(msg.title, "New: Apt 1 Sample Street, Enniskillen");
  assert.match(msg.message, /£650 per month · 1 bed .* 0\.5 km/);
  assert.equal(msg.click, flat.url);
  assert.deepEqual(msg.actions[1], { action: "view", label: "Call Example Lettings", url: "tel:+44 28 9649 6000" });
});
