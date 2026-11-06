import { test } from "node:test";
import assert from "node:assert/strict";
import {
  advertIn,
  decodeEntities,
  parseAlertEmail,
  placeToFind,
  portalForSender,
  readPrice,
} from "../src/email.ts";
import { locate } from "../src/geo.ts";
import {
  forwarderAllowed,
  handleAlert,
  mailbox,
  statusWorthWriting,
  validWatch,
  type Env,
  type WatchStatus,
} from "../src/index.ts";
import { diffEmail, keywordsMatch, sameHomeKey, type Watch } from "../src/watch.ts";
import { ntfyMessage } from "../src/notify.ts";
import type { Listing } from "../src/propertypal.ts";

// These emails are MADE UP to the shape portals are known to use (advert
// links, a photo, price, beds, type and address near each link, a footer).
// They are not copies of real alerts. Replace them with the user's own first
// forwarded emails (GET /email keeps any the reader could not handle).
const rightmoveLike = `
<html><head><style>.x{}</style></head><body>
<img src="https://media.example/logo.png">
<p>We found 2 new properties for your alert "Leeds rent"</p>
<table>
<tr><td><a href="https://www.rightmove.co.uk/properties/151234567?utm_source=alert&amp;utm_medium=email">
<img src="https://media.rightmove.co.uk/photo-1.jpeg"></a></td>
<td><a href="https://www.rightmove.co.uk/properties/151234567?utm_source=alert">£950 pcm</a><br>
2 bedroom flat<br>Cardigan Road, Leeds, LS6 1LF<br>Pets considered, parking. Added today</td></tr>
<tr><td><a href="https://click.example.net/track?u=https%3A%2F%2Fwww.rightmove.co.uk%2Fproperties%2F152000111">
View property</a></td>
<td>£1,150 pcm<br>3 bedroom terraced house<br>Ash Road, Headingley, Leeds LS6<br>Reduced today</td></tr>
</table>
<p><a href="https://www.rightmove.co.uk/alerts/manage">Manage your alerts</a> · Unsubscribe · Rightmove plc, registered in England</p>
</body></html>`;

const spareRoomLike = `<p>New rooms in Hyde Park, Leeds</p>
<a href="https://www.spareroom.co.uk/flatshare/flatshare_detail.pl?flatshare_id=17654321&amp;mode=list">
Double room, bills included</a><br>£150 pw · Hyde Park, Leeds, LS6<br>
<a href="https://www.spareroom.co.uk/unsubscribe">Unsubscribe</a>`;

const env = (watches: Watch[]) => {
  const kv = new Map<string, string>();
  kv.set("watches", JSON.stringify(watches));
  const pushes: any[] = [];
  const e = {
    KV: {
      get: async (k: string, type?: string) => {
        const v = kv.get(k);
        return v == null ? null : type === "json" ? JSON.parse(v) : v;
      },
      put: async (k: string, v: string) => void kv.set(k, v),
    },
    NTFY_TOPIC: "t",
    API_TOKEN: "x",
  } as unknown as Env;
  return { env: e, kv, pushes };
};

test("finds the portal from the sender", () => {
  assert.equal(portalForSender("Rightmove <autoresponder@rightmove.com>")?.source, "rightmove");
  assert.equal(portalForSender("alerts@mail.zoopla.co.uk")?.source, "zoopla");
  assert.equal(portalForSender("someone@evil-rightmove.com"), null);
  assert.equal(portalForSender("x@example.com"), null);
});

test("unwraps tracking links without following them", () => {
  assert.deepEqual(
    advertIn("https://click.example.net/t?u=https%3A%2F%2Fwww.rightmove.co.uk%2Fproperties%2F152000111")?.id,
    "152000111",
  );
  assert.equal(advertIn("https://www.zoopla.co.uk/to-rent/details/71234567/")?.portal.source, "zoopla");
  assert.equal(advertIn("https://www.onthemarket.com/details/15123456/")?.portal.source, "onTheMarket");
  assert.equal(advertIn("https://www.openrent.co.uk/property-to-rent/leeds/2-bed-flat/2345678")?.id, "2345678");
  assert.equal(advertIn("https://www.rightmove.co.uk/alerts/manage"), null);
});

test("prices: monthly, weekly and sale", () => {
  assert.deepEqual(readPrice("£950 pcm"), { price: 950, suffix: "pcm", weekly: false });
  assert.deepEqual(readPrice("£150 pw"), { price: 650, suffix: "pcm (from weekly)", weekly: true });
  assert.equal(readPrice("Offers over £235,000").price, 235000);
  assert.equal(readPrice("POA").price, null);
  assert.equal(decodeEntities("&pound;5 &amp; &#163;6"), "£5 & £6");
});

test("reads a Rightmove-like alert", () => {
  const p = parseAlertEmail({ from: "Rightmove <autoresponder@rightmove.com>", subject: "New homes to rent", html: rightmoveLike });
  assert.equal(p.portal?.source, "rightmove");
  assert.equal(p.listings.length, 2);
  const [a, b] = p.listings;
  assert.equal(a.id, "rightmove:151234567");
  assert.equal(a.url, "https://www.rightmove.co.uk/properties/151234567");
  assert.equal(a.price, 950);
  assert.equal(a.beds, 2);
  assert.equal(a.style, "flat");
  assert.equal(a.address, "Cardigan Road, Leeds, LS6 1LF");
  assert.equal(a.status, "toLet");
  assert.equal(a.image, "https://media.rightmove.co.uk/photo-1.jpeg");
  assert.match(a.text!, /Pets considered/);
  assert.equal(b.sourceId, "152000111");
  assert.equal(b.price, 1150);
  assert.equal(b.style, "terraced");
  assert.equal(b.address, "Ash Road, Headingley, Leeds LS6");
  assert.doesNotMatch(b.text!, /registered in England/, "footer cut off");
});

test("reads a SpareRoom-like alert: weekly rent, a room", () => {
  const p = parseAlertEmail({ from: "SpareRoom <alerts@spareroom.co.uk>", subject: "New rooms", html: spareRoomLike });
  assert.equal(p.listings.length, 1);
  assert.equal(p.listings[0].price, 650);
  assert.equal(p.listings[0].status, "toLet");
  assert.equal(p.listings[0].style, "room");
});

test("plain-text alerts work too", () => {
  const p = parseAlertEmail({
    from: "alerts@onthemarket.com",
    subject: "New property for sale",
    text: "3 bed semi-detached house\nOffers over £235,000\nCarleton Road, Pontefract, WF8 3NB\nhttps://www.onthemarket.com/details/15123456/",
  });
  // The link comes after the facts here, so its block is empty: the reader
  // still yields the advert, with what little follows the link.
  assert.equal(p.listings.length, 1);
  assert.equal(p.listings[0].status, "forSale");
});

test("place to look up", () => {
  assert.deepEqual(placeToFind("Cardigan Road, Leeds, LS6 1LF"), { postcode: "LS6 1LF" });
  assert.deepEqual(placeToFind("Ash Road, Leeds LS6"), { outcode: "LS6" });
  assert.deepEqual(placeToFind("High Street, Pontefract"), { town: "Pontefract" });
  assert.deepEqual(placeToFind("Somewhere"), {});
});

test("locates by postcode, outcode or town, once each", async () => {
  const asked: string[] = [];
  const fake = async (url: string) => {
    asked.push(url);
    const result = url.includes("/places")
      ? [{ latitude: 53.69, longitude: -1.31 }]
      : { latitude: 53.82, longitude: -1.57 };
    return new Response(JSON.stringify({ result }));
  };
  const ls = [
    { address: "Ash Road, Leeds LS6", lat: null, lon: null },
    { address: "Kirkstall Lane, Leeds, LS6", lat: null, lon: null },
    { address: "High Street, Pontefract", lat: null, lon: null },
    { address: "Nowhere", lat: null, lon: null },
  ] as Listing[];
  await locate(ls, fake);
  assert.equal(asked.length, 2);
  assert.equal(ls[0].lat, 53.82);
  assert.equal(ls[2].lon, -1.31);
  assert.equal(ls[3].lat, null);
});

const leeds: Watch = {
  id: "leeds-rent",
  name: "Leeds rent",
  source: "email",
  path: "",
  kind: "rent",
  maxPrice: 1000,
  minBeds: 2,
  centre: { lat: 53.8, lon: -1.55, label: "Leeds" },
  radiusKm: 8,
  keywords: ["-retirement"],
};

const home = (over: Partial<Listing>): Listing => ({
  id: "rightmove:1",
  source: "rightmove",
  sourceId: "1",
  url: "https://www.rightmove.co.uk/properties/1",
  address: "Cardigan Road, Leeds, LS6 1LF",
  price: 950,
  priceSuffix: "pcm",
  beds: 2,
  baths: null,
  style: "flat",
  furnished: "",
  heating: "",
  availableFrom: null,
  lat: 53.82,
  lon: -1.57,
  agent: "",
  agentPhone: "",
  image: null,
  status: "toLet",
  text: "",
  ...over,
});

test("keywords: must have, must not have", () => {
  assert.ok(keywordsMatch(["pets"], home({ text: "Pets considered" })));
  assert.ok(!keywordsMatch(["pets"], home({})));
  assert.ok(!keywordsMatch(["-retirement"], home({ text: "Retirement flat" })));
  assert.ok(keywordsMatch(["-", ""], home({})));
});

test("email searches: new alerts at once, cuts alert, twins and misses do not", () => {
  const first = diffEmail(leeds, [home({})], null, "2026-11-05T10:00:00.000Z");
  assert.deepEqual(first.events.map((e) => e.kind), ["new"], "no silent first run for email");
  // The same flat from Zoopla, £10 dearer: a twin, recorded without a push.
  const twin = home({ id: "zoopla:9", source: "zoopla", sourceId: "9", price: 960 });
  const second = diffEmail(leeds, [twin], first.seen, "2026-11-05T11:00:00.000Z");
  assert.equal(second.events.length, 0);
  assert.ok(second.seen["zoopla:9"]);
  // Rightmove emails it again, reduced.
  const third = diffEmail(leeds, [home({ price: 900 })], second.seen, "2026-11-06T10:00:00.000Z");
  assert.deepEqual(third.events.map((e) => [e.kind, e.previousPrice]), [["price", 950]]);
  // Too dear, too far, for sale, or a retirement flat: no push.
  const misses = [
    home({ id: "rightmove:2", price: 1200 }),
    home({ id: "rightmove:3", lat: 53.5, lon: -1.1 }),
    home({ id: "rightmove:4", status: "forSale", price: 900 }),
    home({ id: "rightmove:5", text: "retirement apartment" }),
    home({ id: "rightmove:6", lat: null, lon: null }),
  ];
  assert.equal(diffEmail(leeds, misses, third.seen, "2026-11-06T11:00:00.000Z").events.length, 0);
  // Two months later the flat is forgotten.
  const later = diffEmail(leeds, [], third.seen, "2027-01-10T00:00:00.000Z");
  assert.deepEqual(Object.keys(later.seen), []);
});

test("same-home key", () => {
  assert.equal(sameHomeKey(home({})), "toLet|ls6|2|950");
  assert.equal(sameHomeKey(home({ beds: null })), null);
});

test("push for an email advert names the portal and attaches no photo", () => {
  const m = ntfyMessage("t", { at: "", watchId: "w", kind: "new", listing: home({ image: "https://x/p.jpg" }), distanceKm: 2 }, "Leeds rent") as any;
  assert.equal(m.title, "New on Rightmove: Cardigan Road, Leeds, LS6 1LF");
  assert.equal(m.attach, undefined);
  assert.equal(m.actions[0].label, "Open on Rightmove");
  assert.equal(m.message, "£950 pcm · 2 bed · flat · 2.0 km\nLeeds rent");
});

test("only the owner's mailbox may forward", () => {
  assert.equal(mailbox("You+caf_=homes=example.org@Gmail.com"), "you@gmail.com");
  assert.ok(forwarderAllowed("you+caf_=homes=example.org@gmail.com", "you@gmail.com, other@x.org"));
  assert.ok(!forwarderAllowed("stranger@gmail.com", "you@gmail.com"));
  assert.ok(!forwarderAllowed("you@gmail.com", undefined), "nothing allowed until set");
});

test("status is written when health changes or hourly", () => {
  const ok: WatchStatus = { lastRun: "2026-11-05T10:00:00.000Z", lastOk: "2026-11-05T10:00:00.000Z", failures: 0, lastError: null, listings: 5 };
  const at = (t: string, over: Partial<WatchStatus> = {}) => ({ ...ok, lastRun: t, lastOk: t, ...over });
  assert.ok(statusWorthWriting(null, ok));
  assert.ok(!statusWorthWriting(ok, at("2026-11-05T10:10:00.000Z")));
  assert.ok(statusWorthWriting(ok, at("2026-11-05T11:00:00.000Z")));
  assert.ok(statusWorthWriting(ok, at("2026-11-05T10:10:00.000Z", { listings: 6 })));
  assert.ok(statusWorthWriting(ok, { ...ok, lastRun: "2026-11-05T10:10:00.000Z", failures: 1, lastError: "x" }));
  // 144 healthy runs a day now cost 24 writes, not 144.
  let prev = ok, writes = 0;
  for (let i = 1; i <= 144; i++) {
    const next = at(new Date(Date.parse(ok.lastRun) + i * 600_000).toISOString());
    if (statusWorthWriting(prev, next)) {
      writes++;
      prev = next;
    }
  }
  assert.equal(writes, 24);
});

test("email searches validate", () => {
  assert.ok(validWatch(leeds));
  assert.ok(!validWatch({ ...leeds, path: "/property-to-rent/leeds" }));
  assert.ok(!validWatch({ ...leeds, kind: "lease" }));
  assert.ok(!validWatch({ ...leeds, keywords: ["x".repeat(41)] }));
  assert.ok(validWatch({ id: "pp", name: "PP", source: "propertypal", path: "/property-to-rent/enniskillen" }));
});

test("an alert email becomes events; a puzzling one is kept", async () => {
  const { env: e, kv } = env([leeds, { ...leeds, id: "paused", paused: true }]);
  const realFetch = globalThis.fetch;
  const sent: any[] = [];
  globalThis.fetch = (async (_u: any, init: any) => {
    sent.push(JSON.parse(init.body));
    return new Response("{}");
  }) as typeof fetch;
  try {
    const noLookup = async (ls: Listing[]) => {
      for (const l of ls) Object.assign(l, { lat: 53.82, lon: -1.57 });
    };
    const s = await handleAlert(
      e,
      { from: "autoresponder@rightmove.com", subject: "New homes to rent", html: rightmoveLike },
      "2026-11-05T10:00:00.000Z",
      noLookup,
    );
    assert.equal(s.adverts, 2);
    assert.equal(s.events, 1, "the £1,150 house is over budget");
    assert.equal(JSON.parse(kv.get("events")!).length, 1);
    assert.ok(kv.get("seen:leeds-rent"));
    assert.ok(!kv.get("seen:paused"));
    assert.equal(sent[0].title, "New on Rightmove: Cardigan Road, Leeds, LS6 1LF");

    const bad = await handleAlert(e, { from: "autoresponder@rightmove.com", subject: "Hello", html: "<p>No adverts</p>" });
    assert.match(bad.error!, /No adverts/);
    assert.equal(JSON.parse(kv.get("email:puzzling")!).subject, "Hello");
    assert.match(sent[sent.length - 1].title, /could not read/);
  } finally {
    globalThis.fetch = realFetch;
  }
});
