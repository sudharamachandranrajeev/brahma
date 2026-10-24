import { test } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.ts";
import { metaSignatureOk, mediaSignatureOk, open, seal, signMedia, webhookVerifyToken } from "../src/social/crypto.ts";
import { ebayFilter, keywordsMatch, parseDoneDeal, runWatch } from "../src/social/discovery.ts";
import { Budget, PlatformError } from "../src/social/http.ts";
import { pollAccount } from "../src/social/inbox.ts";
import type { Adapter, Ctx } from "../src/social/platforms/adapter.ts";
import { facets } from "../src/social/platforms/bluesky.ts";
import { adapters } from "../src/social/platforms/index.ts";
import { littleText } from "../src/social/platforms/linkedin.ts";
import { problemsWith, publishDue, publishPost, retryPost, savePost, type PostInput } from "../src/social/publish.ts";
import { nextSlot, zonedToUtc } from "../src/social/schedule.ts";
import { bestTimes } from "../src/social/stats.ts";
import { Store } from "../src/social/store.ts";
import type { Account, Content, DiscoveryWatch, InboxItem } from "../src/social/types.ts";
import { mockFetch, testEnv, tokenKey } from "./shims.ts";

function setup(now = new Date("2026-10-24T12:00:00Z")) {
  const env = testEnv();
  const store = new Store(env);
  const ctx: Ctx = { env, store, budget: new Budget(45), now };
  return { env, store, ctx };
}

const accountFields = (platform: Account["platform"], remoteId: string): Omit<Account, "id"> => ({
  platform,
  name: `Test ${platform}`,
  handle: `@test-${platform}`,
  avatar: null,
  remoteId,
  status: "ok",
  statusMessage: null,
  expiresAt: null,
  capabilities: ["publish", "comments", "private_reply"],
  connectedAt: "2026-10-01T00:00:00.000Z",
  checkedAt: null,
});

/** Swaps one platform's adapter for a test double; returns a restore function. */
function fake(platform: Account["platform"], parts: Partial<Adapter>) {
  const real = adapters[platform];
  adapters[platform] = { ...real, ...parts } as Adapter;
  return () => void (adapters[platform] = real);
}

// ---- crypto ----

test("sealed secrets round-trip and resist tampering", async () => {
  const sealed = await seal(tokenKey, { token: "abc", n: 1 });
  assert.match(sealed, /^v1\./);
  assert.deepEqual(await open(tokenKey, sealed), { token: "abc", n: 1 });
  const [v, iv, ct] = sealed.split(".");
  const flipped = `${v}.${iv}.${ct.slice(0, -2)}${ct.endsWith("A") ? "B" : "A"}=`;
  await assert.rejects(open(tokenKey, flipped));
});

test("media links expire and can't be forged", async () => {
  const now = Date.UTC(2026, 9, 24);
  const exp = now / 1000 + 3600;
  const sig = await signMedia(tokenKey, "m1", exp);
  assert.equal(await mediaSignatureOk(tokenKey, "m1", String(exp), sig, now), true);
  assert.equal(await mediaSignatureOk(tokenKey, "m2", String(exp), sig, now), false);
  assert.equal(await mediaSignatureOk(tokenKey, "m1", String(exp), sig, now + 2 * 3600_000), false);
});

test("Meta webhook signatures", async () => {
  const body = '{"object":"instagram"}';
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode("app-secret"), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const hex = Buffer.from(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body))).toString("hex");
  assert.equal(await metaSignatureOk("app-secret", body, `sha256=${hex}`), true);
  assert.equal(await metaSignatureOk("app-secret", body + " ", `sha256=${hex}`), false);
  assert.equal(await metaSignatureOk("app-secret", body, null), false);
});

// ---- scheduling ----

test("queue slots follow the owner's clock across the DST change", () => {
  const slots = [{ day: 0, time: "09:00" }];
  // Before the clocks go back (BST, UTC+1) and after (GMT).
  assert.equal(nextSlot("Europe/London", slots, [], new Date("2026-10-18T12:00:00Z"))!.toISOString(), "2026-10-19T08:00:00.000Z");
  assert.equal(nextSlot("Europe/London", slots, [], new Date("2026-10-24T12:00:00Z"))!.toISOString(), "2026-10-26T09:00:00.000Z");
  // A taken slot moves to the next week.
  assert.equal(
    nextSlot("Europe/London", slots, ["2026-10-26T09:02:00.000Z"], new Date("2026-10-24T12:00:00Z"))!.toISOString(),
    "2026-11-02T09:00:00.000Z",
  );
  assert.equal(nextSlot("Europe/London", [], [], new Date()), null);
  assert.equal(zonedToUtc("America/New_York", 2026, 7, 1, 9, 30).toISOString(), "2026-07-01T13:30:00.000Z");
});

// ---- platform text ----

test("LinkedIn little text escapes reserved characters and keeps hashtags", () => {
  assert.equal(littleText("Hi (all) @you #launch_day!"), "Hi \\(all\\) \\@you {hashtag|\\#|launch_day}!");
});

test("Bluesky facets use byte offsets", () => {
  const f = facets("café #news https://x.io/a") as any[];
  const tag = f.find((x) => x.features[0].tag);
  const link = f.find((x) => x.features[0].uri);
  assert.deepEqual(tag.index, { byteStart: 6, byteEnd: 11 });
  assert.equal(link.features[0].uri, "https://x.io/a");
  assert.equal(link.index.byteStart, 12);
});

// ---- discovery parsing ----

const doneDealPage = `<html><script id="__NEXT_DATA__" type="application/json">${JSON.stringify({
  props: {
    pageProps: {
      ads: [
        {
          id: 43043439,
          title: "Peugeot 5008 157kW GT 73kWh 5dr Auto",
          publishDate: 1792792740075,
          county: "Fermanagh",
          countyTown: "Enniskillen",
          friendlyUrl: "https://www.donedeal.ie/cars-for-sale/peugeot-5008-157kw-gt-73kwh-5dr-auto/43043439",
          metaInfo: ["2026", " Electric", "10,845 km"],
          priceInfo: { price: "£31,995", priceOnRequest: false, priceInEuro: 38212 },
          imageAlt: "Peugeot 5008 SUV, Electric, 2026, White",
          gallery: { coverImage: { small: "https://media.donedeal.ie/x.jpg" } },
        },
        { id: 2, title: "Toyota Yaris 1.0", relativeUrl: "/cars-for-sale/toyota-yaris/2", priceInfo: { price: "€4,500" }, county: "Cavan", metaInfo: ["2012"] },
      ],
    },
  },
})}</script></html>`;

test("parses DoneDeal results", () => {
  const [peugeot, yaris] = parseDoneDeal(doneDealPage);
  assert.equal(peugeot.id, "donedeal:43043439");
  assert.equal(peugeot.price, 31995);
  assert.equal(peugeot.currency, "GBP");
  assert.equal(peugeot.location, "Enniskillen, Fermanagh");
  assert.match(peugeot.text, /Electric/);
  assert.equal(yaris.url, "https://www.donedeal.ie/cars-for-sale/toyota-yaris/2");
  assert.equal(yaris.currency, "EUR");
  assert.throws(() => parseDoneDeal("<html>blocked</html>"), PlatformError);
});

test("eBay filter and keyword matching", () => {
  assert.equal(
    ebayFilter({ type: "ebay", query: "yaris", maxPrice: 8000, postcode: "bt74 6aa", radiusKm: 40 }),
    "price:[..8000],priceCurrency:GBP,deliveryOptions:{SELLER_ARRANGED_LOCAL_PICKUP},pickupCountry:GB,pickupPostalCode:BT746AA,pickupRadius:40,pickupRadiusUnit:km",
  );
  assert.equal(ebayFilter({ type: "ebay", query: "yaris" }), "");
  const find = parseDoneDeal(doneDealPage)[1];
  assert.equal(keywordsMatch(find, ["toyota", "YARIS"]), true);
  assert.equal(keywordsMatch(find, ["toyota", "corolla"]), false);
});

test("discovery records a baseline, then alerts only on new matches", async () => {
  const { store, ctx } = setup();
  const watch: DiscoveryWatch = {
    id: "cars",
    name: "Cheap Toyota",
    description: "a Toyota",
    sources: [{ type: "donedeal", path: "/cars?area=Fermanagh" }],
    keywords: ["toyota"],
    ai: false,
    everyMinutes: 30,
    paused: false,
  };
  let page = doneDealPage;
  const net = mockFetch({ "https://www.donedeal.ie/": () => new Response(page) });
  try {
    const first = await runWatch(ctx, watch);
    assert.equal(first.finds.length, 1);
    assert.equal(first.alerts.length, 0);
    page = page.replace('"id":2,', '"id":3,');
    const second = await runWatch(ctx, watch);
    assert.equal(second.alerts.length, 1);
    assert.match(second.alerts[0].title, /Cheap Toyota: Toyota Yaris/);
    assert.match(second.alerts[0].body, /€4,500/);
    assert.equal(net.pushes.length, 1);
    assert.equal((await runWatch(ctx, watch)).alerts.length, 0);
    assert.equal((await store.alerts()).length, 1);
  } finally {
    net.restore();
  }
});

// ---- publishing ----

const textPost = (accountId: string, extra: Partial<PostInput> = {}): PostInput => ({
  text: "Hello from the test",
  media: [],
  targets: [{ accountId, format: "post" }],
  scheduledAt: "2026-10-24T11:59:00Z",
  ...extra,
});

test("validation finds what platforms would reject", async () => {
  const { store } = setup();
  const bsky = await store.saveAccount(accountFields("bluesky", "did:plc:1"), {});
  const ig = await store.saveAccount(accountFields("instagram", "17841"), {});
  const yt = await store.saveAccount(accountFields("youtube", "UC1"), {});
  const problems = await problemsWith(store, {
    text: "x".repeat(301),
    media: [],
    targets: [
      { accountId: bsky.id, format: "post" },
      { accountId: ig.id, format: "post" },
      { accountId: yt.id, format: "video" },
      { accountId: "nope", format: "post" },
    ],
  });
  assert.ok(problems.some((p) => /Bluesky.*301 characters, the limit is 300/.test(p)));
  assert.ok(problems.some((p) => /Instagram.*needs a photo or video/.test(p)));
  assert.ok(problems.some((p) => /YouTube.*title is needed/.test(p)));
  assert.ok(problems.some((p) => /account nope is not connected/.test(p)));
  // Emoji count as one character on Bluesky.
  assert.deepEqual(await problemsWith(store, { text: "👍🏽".repeat(300), media: [], targets: [{ accountId: bsky.id, format: "post" }] }), []);
});

test("publishes a due post once and records where it went", async () => {
  const { store, ctx } = setup();
  const a = await store.saveAccount(accountFields("mastodon", "m1"), {});
  let calls = 0;
  const restore = fake("mastodon", {
    publish: async (_c, _a, input, progress) => {
      calls++;
      assert.equal(input.text, "Hello from the test");
      progress.commit();
      return { remoteId: "status-1", permalink: "https://masto.test/@me/1" };
    },
  });
  try {
    const post = await savePost(store, textPost(a.id), null, ctx.now);
    assert.equal(post.status, "scheduled");
    assert.equal(await publishDue(ctx), 1);
    const done = (await store.post(post.id))!;
    assert.equal(done.status, "published");
    assert.equal(done.targets[0].remoteId, "status-1");
    assert.equal(done.targets[0].permalink, "https://masto.test/@me/1");
    assert.equal(await publishDue(ctx), 0);
    assert.equal(calls, 1);
  } finally {
    restore();
  }
});

test("a transient failure before the commit point retries with backoff", async () => {
  const { store, ctx } = setup();
  const a = await store.saveAccount(accountFields("mastodon", "m1"), {});
  const restore = fake("mastodon", {
    publish: async () => {
      throw new PlatformError("Mastodon: 503", 503, true, false);
    },
  });
  try {
    const post = await savePost(store, textPost(a.id), null, ctx.now);
    const after = (await publishPost(ctx, post.id))!;
    assert.equal(after.status, "scheduled");
    assert.equal(after.targets[0].attempts, 1);
    assert.match(after.targets[0].error!, /503/);
    // Held back for 2 minutes: not due a minute later, due after.
    assert.equal((await store.duePosts(new Date(ctx.now.getTime() + 60_000).toISOString())).length, 0);
    assert.equal((await store.duePosts(new Date(ctx.now.getTime() + 121_000).toISOString())).length, 1);
  } finally {
    restore();
  }
});

test("a failure after the commit point is never retried blindly", async () => {
  const { store, ctx, env } = setup();
  const a = await store.saveAccount(accountFields("mastodon", "m1"), {});
  let fail = true;
  const restore = fake("mastodon", {
    publish: async (_c, _a, _i, progress) => {
      progress.commit();
      if (fail) throw new PlatformError("Mastodon: timeout", 504, true, false);
      return { remoteId: "s2", permalink: null };
    },
  });
  const net = mockFetch({});
  try {
    const post = await savePost(store, textPost(a.id), null, ctx.now);
    const after = (await publishPost(ctx, post.id))!;
    assert.equal(after.status, "failed");
    assert.equal(after.targets[0].maybePosted, true);
    assert.match(net.pushes[0].message, /may have gone out anyway/);
    await assert.rejects(retryPost(store, after, false, ctx.now), /need force/);
    fail = false;
    await retryPost(store, after, true, ctx.now);
    assert.equal((await publishPost(ctx, post.id))!.status, "published");
    assert.equal(env.NTFY_TOPIC, net.pushes[0].topic);
  } finally {
    net.restore();
    restore();
  }
});

test("an auth failure marks the account broken and alerts once", async () => {
  const { store, ctx } = setup();
  const a = await store.saveAccount(accountFields("mastodon", "m1"), {});
  const restore = fake("mastodon", {
    publish: async () => {
      throw new PlatformError("token revoked", 401, false, true);
    },
  });
  const net = mockFetch({});
  try {
    const post = await savePost(store, textPost(a.id), null, ctx.now);
    assert.equal((await publishPost(ctx, post.id))!.status, "failed");
    assert.equal((await store.account(a.id))!.status, "broken");
    const kinds = (await store.alerts()).map((x) => x.kind).sort();
    assert.deepEqual(kinds, ["account", "publish"]);
  } finally {
    net.restore();
    restore();
  }
});

test("a post held by one run is not published by another", async () => {
  const { store, ctx } = setup();
  const a = await store.saveAccount(accountFields("mastodon", "m1"), {});
  const post = await savePost(store, textPost(a.id), null, ctx.now);
  assert.equal(await store.lockPost(post.id, ctx.now.toISOString(), new Date(ctx.now.getTime() + 600_000).toISOString()), true);
  assert.equal(await publishPost(ctx, post.id), null);
});

// ---- inbox ----

const comment = (a: Account, n: number, text: string, at = "2026-10-24T11:50:00.000Z"): InboxItem => ({
  id: `item-${n}`,
  accountId: a.id,
  platform: a.platform,
  kind: "comment",
  context: { type: "post", id: "p1", title: "Launch post", url: "https://x.test/p1", thumbnail: null },
  author: { id: `u${n}`, name: `Sam Person${n}`, handle: `sam${n}`, avatar: null },
  text,
  at,
  remoteId: `c${n}`,
  parentRemoteId: null,
  status: "new",
  labels: [],
});

test("inbox: history is stored quietly, then rules act on new items", async () => {
  const { store, ctx } = setup();
  const a = await store.saveAccount(accountFields("instagram", "17841"), {});
  await store.putDoc("rules", [
    { id: "price", name: "Price question", enabled: true, accountIds: null, keywords: ["how much"], reply: "Hi {name}, sent you a DM!", privateReply: "Hi {name}, it's £20.", alert: true },
  ]);
  let batch: InboxItem[] = [comment(a, 1, "How much is it?")];
  const replies: { text: string; privately: boolean }[] = [];
  const restore = fake("instagram", {
    poll: async () => ({ items: batch, content: [], state: { cursor: 1 } }),
    reply: async (_c, _a, _item, text, privately) => {
      replies.push({ text, privately });
      return "r1";
    },
  });
  const net = mockFetch({});
  try {
    assert.equal((await pollAccount(ctx, a)).length, 1);
    assert.equal(replies.length, 0);
    batch = [comment(a, 1, "How much is it?"), comment(a, 2, "how much for two?"), comment(a, 3, "Lovely")];
    const fresh = await pollAccount(ctx, a);
    assert.deepEqual(fresh.map((x) => x.id), ["item-2", "item-3"]);
    assert.deepEqual(replies, [
      { text: "Hi Sam, it's £20.", privately: true },
      { text: "Hi Sam, sent you a DM!", privately: false },
    ]);
    const item = (await store.inboxItem("item-2"))!;
    assert.deepEqual(item.labels, ["Price question"]);
    assert.equal(item.status, "done");
    assert.equal((await store.inboxItem("item-3"))!.labels.length, 0);
    assert.equal(net.pushes.length, 1);
    assert.match(net.pushes[0].title, /Price question: Sam Person2/);
  } finally {
    net.restore();
    restore();
  }
});

test("inbox: rules don't auto-reply to old items after an outage", async () => {
  const { store, ctx } = setup();
  const a = await store.saveAccount(accountFields("instagram", "17841"), {});
  await store.putDoc("rules", [{ id: "all", name: "Thanks", enabled: true, accountIds: null, keywords: [], reply: "Thanks!", alert: false }]);
  let batch: InboxItem[] = [];
  let replied = 0;
  const restore = fake("instagram", {
    poll: async () => ({ items: batch, content: [], state: {} }),
    reply: async () => (replied++, "r"),
  });
  try {
    await pollAccount(ctx, a);
    batch = [comment(a, 1, "old one", "2026-10-22T10:00:00.000Z"), comment(a, 2, "new one")];
    await pollAccount(ctx, a);
    assert.equal(replied, 1);
    assert.deepEqual((await store.inboxItem("item-1"))!.labels, ["Thanks"]);
  } finally {
    restore();
  }
});

// ---- stats ----

test("best times weigh each post against its own account", () => {
  const c = (accountId: string, at: string, likes: number): Content => ({
    id: `${accountId}${at}`,
    accountId,
    platform: "instagram",
    remoteId: at,
    type: "post",
    caption: "",
    url: null,
    thumbnail: null,
    at,
    likes,
    comments: 0,
    views: null,
  });
  const times = bestTimes([
    // A big account posting Monday 09:00 at its usual level...
    c("big", "2026-10-19T09:00:00Z", 1000),
    c("big", "2026-10-20T09:00:00Z", 1000),
    // ...and a small account doing three times its usual on Friday 18:00.
    c("small", "2026-10-23T18:00:00Z", 30),
    c("small", "2026-10-22T10:00:00Z", 10),
    c("small", "2026-10-21T10:00:00Z", 10),
  ]);
  assert.deepEqual(times[0], { day: 4, hour: 18, score: 1, posts: 1 });
});

// ---- HTTP ----

const env = () => ({ ...testEnv(), SUBREQUEST_BUDGET: "45" });
const exec = { waitUntil: () => {}, passThroughOnException: () => {} } as unknown as ExecutionContext;
const call = (e: ReturnType<typeof env>, path: string, init: RequestInit & { auth?: boolean } = {}) =>
  worker.fetch(
    new Request(`https://hub.test${path}`, {
      ...init,
      headers: { ...(init.auth === false ? {} : { authorization: "Bearer test-token" }), "content-type": "application/json" },
    }),
    e as never,
    exec,
  );

test("API needs the bearer token", async () => {
  const e = env();
  assert.equal((await call(e, "/social/accounts", { auth: false })).status, 401);
  assert.equal((await call(e, "/social/accounts")).status, 200);
  assert.equal((await call(e, "/social/nope")).status, 404);
  assert.equal((await call(e, "/social/accounts", { method: "PATCH" })).status, 405);
});

test("API validates bodies and reports problems", async () => {
  const e = env();
  const bad = await call(e, "/social/posts", { method: "POST", body: JSON.stringify({ text: 5 }) });
  assert.equal(bad.status, 400);
  assert.ok(((await bad.json()) as any).problems.length > 0);
  const missing = await call(e, "/social/posts", { method: "POST", body: JSON.stringify({ text: "hi", media: [], targets: [{ accountId: "x", format: "post" }] }) });
  assert.equal(missing.status, 400);
  assert.deepEqual(((await missing.json()) as any).problems, ["account x is not connected"]);
  const meta = (await (await call(e, "/social/meta")).json()) as any;
  assert.equal(meta.platforms.bluesky.maxText, 300);
  assert.equal(meta.redirectUris.google, "https://hub.test/oauth/google/callback");
  assert.equal(meta.ai, false);
});

test("API stores credentials without ever returning secrets", async () => {
  const e = env();
  const put = await call(e, "/social/credentials/meta", { method: "PUT", body: JSON.stringify({ publicId: "123", secret: "shh" }) });
  assert.equal(put.status, 200);
  const list = await (await call(e, "/social/credentials")).text();
  assert.match(list, /"publicId":"123"/);
  assert.doesNotMatch(list, /shh/);
  const connect = (await (await call(e, "/social/connect/meta", { method: "POST" })).json()) as any;
  assert.match(connect.url, /^https:\/\/www\.facebook\.com\/v24\.0\/dialog\/oauth\?client_id=123/);
  const state = new URL(connect.url).searchParams.get("state")!;
  assert.ok(e.KV.data.has(`social:oauth:${state}`));
  // A callback with a wrong state is refused.
  const cb = await call(e, "/oauth/meta/callback?state=forged&code=x", { auth: false });
  assert.equal(cb.status, 400);
});

test("webhook verification and signatures", async () => {
  const e = env();
  const token = await webhookVerifyToken(tokenKey);
  const ok = await call(e, `/webhooks/meta?hub.mode=subscribe&hub.verify_token=${token}&hub.challenge=42`, { auth: false });
  assert.equal(await ok.text(), "42");
  assert.equal((await call(e, `/webhooks/meta?hub.mode=subscribe&hub.verify_token=wrong&hub.challenge=42`, { auth: false })).status, 403);
  await new Store(e).putCredential("meta", "123", "app-secret");
  const post = await call(e, "/webhooks/meta", { method: "POST", body: "{}", auth: false });
  assert.equal(post.status, 401);
});

test("signed media links serve files; unsigned ones don't", async () => {
  const e = env();
  await e.MEDIA.put("media/m1", new TextEncoder().encode("hello"), { httpMetadata: { contentType: "image/png" } });
  const exp = Math.floor(Date.now() / 1000) + 600;
  const sig = await signMedia(tokenKey, "m1", exp);
  const res = await call(e, `/media/m1?exp=${exp}&sig=${sig}`, { auth: false });
  assert.equal(res.status, 200);
  assert.equal(await res.text(), "hello");
  assert.equal((await call(e, `/media/m1?exp=${exp}&sig=bad`, { auth: false })).status, 403);
});
