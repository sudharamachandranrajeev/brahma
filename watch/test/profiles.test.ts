// Profiles: separate workspaces on one hub, picked per request by header.

import { test } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.ts";
import { raise } from "../src/social/alerts.ts";
import { Budget } from "../src/social/http.ts";
import type { Ctx } from "../src/social/platforms/adapter.ts";
import { eachProfile } from "../src/social/profiles.ts";
import { Store } from "../src/social/store.ts";
import type { Account } from "../src/social/types.ts";
import { mockFetch, testEnv } from "./shims.ts";

const env = () => ({ ...testEnv(), SUBREQUEST_BUDGET: "45" });
const exec = { waitUntil: () => {}, passThroughOnException: () => {} } as unknown as ExecutionContext;

async function call(e: ReturnType<typeof env>, path: string, init: { method?: string; body?: unknown; profile?: string } = {}) {
  const r = await worker.fetch(
    new Request(`https://hub.test${path}`, {
      method: init.method ?? "GET",
      headers: {
        authorization: "Bearer test-token",
        "content-type": "application/json",
        ...(init.profile ? { "x-vani-profile": init.profile } : {}),
      },
      body: init.body === undefined ? undefined : JSON.stringify(init.body),
    }),
    e as never,
    exec,
  );
  return { status: r.status, body: (await r.json()) as any };
}

const account = (platform: Account["platform"], remoteId: string): Omit<Account, "id"> => ({
  platform,
  name: `Test ${platform}`,
  handle: `@test-${remoteId}`,
  avatar: null,
  remoteId,
  status: "ok",
  statusMessage: null,
  expiresAt: null,
  capabilities: ["publish"],
  connectedAt: "2026-10-01T00:00:00.000Z",
  checkedAt: null,
});

test("profiles are made, renamed and listed; the main one always exists", async () => {
  const e = env();
  assert.deepEqual((await call(e, "/social/profiles")).body.map((p: any) => [p.id, p.name]), [["default", "Main"]]);
  const shop = (await call(e, "/social/profiles", { method: "POST", body: { name: "Pottery shop" } })).body;
  assert.equal(shop.name, "Pottery shop");
  assert.equal((await call(e, "/social/profiles", { method: "POST", body: { name: "pottery SHOP" } })).status, 409);
  assert.equal((await call(e, "/social/profiles", { method: "POST", body: { name: " " } })).status, 400);
  assert.equal((await call(e, `/social/profiles/${shop.id}`, { method: "PATCH", body: { name: "Studio" } })).body.name, "Studio");
  assert.deepEqual((await call(e, "/social/profiles")).body.map((p: any) => p.name), ["Main", "Studio"]);
  assert.equal((await call(e, "/social/profiles/default", { method: "DELETE" })).status, 409);
});

test("each profile sees only its own accounts, posts, settings, rules and alerts", async () => {
  const e = env();
  const shop = (await call(e, "/social/profiles", { method: "POST", body: { name: "Shop" } })).body;
  const main = new Store(e);
  const inShop = main.forProfile(shop.id);
  const mine = await main.saveAccount(account("bluesky", "did:main"), {});
  const theirs = await inShop.saveAccount(account("bluesky", "did:shop"), {});
  await inShop.addAlerts([{ id: "al1", at: "2026-10-24T10:00:00Z", kind: "system", title: "Shop alert", body: "", url: null, image: null, ref: null, read: false }]);

  assert.deepEqual((await call(e, "/social/accounts")).body.map((a: any) => a.id), [mine.id]);
  assert.deepEqual((await call(e, "/social/accounts", { profile: shop.id })).body.map((a: any) => a.id), [theirs.id]);
  assert.equal((await call(e, "/social/alerts")).body.length, 0);
  assert.equal((await call(e, "/social/alerts", { profile: shop.id })).body[0].title, "Shop alert");

  // A post can only target the profile's own accounts.
  const post = (target: string, profile?: string) =>
    call(e, "/social/posts", { method: "POST", profile, body: { text: "hi", media: [], targets: [{ accountId: target, format: "post" }], draft: true } });
  assert.equal((await post(theirs.id)).status, 400);
  const draft = (await post(theirs.id, shop.id)).body;
  assert.equal((await call(e, "/social/posts")).body.length, 0);
  assert.equal((await call(e, `/social/posts/${draft.id}`, { method: "DELETE" })).status, 404);
  assert.equal((await call(e, "/social/posts", { profile: shop.id })).body.length, 1);

  // Settings and rules are per profile; the main profile keeps its old keys.
  const settings = (await call(e, "/social/settings", { profile: shop.id })).body;
  await call(e, "/social/settings", { method: "PUT", profile: shop.id, body: { ...settings, language: "Malayalam" } });
  assert.equal((await call(e, "/social/settings")).body.language, "English");
  assert.equal((await call(e, "/social/settings", { profile: shop.id })).body.language, "Malayalam");
  assert.equal((await main.doc<any>("settings", {})).language, undefined);
  assert.ok(await e.DB.prepare("SELECT 1 FROM docs WHERE key = ?").bind(`p:${shop.id}:settings`).first());

  // Credentials are the hub's, whichever profile asks.
  await call(e, "/social/credentials/anthropic", { method: "PUT", profile: shop.id, body: { secret: "sk-test" } });
  assert.equal((await call(e, "/social/meta")).body.ai, true);

  assert.equal((await call(e, "/social/accounts", { profile: "nope" })).status, 404);
});

test("an account belongs to one profile", async () => {
  const e = env();
  const shop = (await call(e, "/social/profiles", { method: "POST", body: { name: "Shop" } })).body;
  const main = new Store(e);
  await main.saveAccount(account("bluesky", "did:same"), {});
  await assert.rejects(main.forProfile(shop.id).saveAccount(account("bluesky", "did:same"), {}), /already connected in the profile "Main"/);
  // Reconnecting in its own profile still works.
  await main.saveAccount(account("bluesky", "did:same"), { fresh: true });
  assert.deepEqual(await main.secretOf((await main.accounts())[0].id), { fresh: true });
});

test("OAuth sign-ins land in the profile they started in", async () => {
  const e = env();
  const shop = (await call(e, "/social/profiles", { method: "POST", body: { name: "Shop" } })).body;
  await call(e, "/social/credentials/linkedin", { method: "PUT", body: { publicId: "client", secret: "shh" } });
  const { url } = (await call(e, "/social/connect/linkedin", { method: "POST", profile: shop.id })).body;
  const state = new URL(url).searchParams.get("state");
  const net = mockFetch({
    "https://www.linkedin.com/oauth/v2/accessToken": () => ({ access_token: "tok", expires_in: 5000000 }),
    "https://api.linkedin.com/v2/userinfo": () => ({ sub: "abc", name: "Sam Example", picture: null }),
  });
  try {
    const r = await worker.fetch(new Request(`https://hub.test/oauth/linkedin/callback?state=${state}&code=c`), e as never, exec);
    assert.equal(r.status, 200, await r.text());
  } finally {
    net.restore();
  }
  assert.equal((await call(e, "/social/accounts")).body.length, 0);
  assert.equal((await call(e, "/social/accounts", { profile: shop.id })).body[0].platform, "linkedin");
});

test("deleting a profile needs its accounts gone, then removes everything in it", async () => {
  const e = env();
  const shop = (await call(e, "/social/profiles", { method: "POST", body: { name: "Shop" } })).body;
  const inShop = new Store(e).forProfile(shop.id);
  const a = await inShop.saveAccount(account("bluesky", "did:shop"), {});
  await inShop.putMedia({ id: "m1", filename: "a.jpg", contentType: "image/jpeg", size: 3, status: "ready", createdAt: "2026-10-24T00:00:00Z" }, null);
  await e.MEDIA.put("media/m1", "abc");
  await inShop.putDoc("rules", [{ id: "r" }]);

  const refused = await call(e, `/social/profiles/${shop.id}`, { method: "DELETE" });
  assert.equal(refused.status, 409);
  assert.match(refused.body.error, /remove this profile's accounts first/);
  await call(e, `/social/accounts/${a.id}`, { method: "DELETE", profile: shop.id });
  assert.equal((await call(e, `/social/profiles/${shop.id}`, { method: "DELETE" })).status, 200);

  assert.deepEqual((await call(e, "/social/profiles")).body.map((p: any) => p.id), ["default"]);
  assert.deepEqual((e.MEDIA as any).keys(), []);
  assert.equal(await e.DB.prepare("SELECT 1 FROM docs WHERE key LIKE ?").bind(`p:${shop.id}:%`).first(), null);
  assert.equal(await e.DB.prepare("SELECT 1 FROM media").first(), null);
});

test("the cron visits every profile, starting from a different one each 10 minutes", async () => {
  const e = env();
  const store = new Store(e);
  for (const name of ["B", "C"]) await store.putProfile({ id: name.toLowerCase(), name, createdAt: `2026-10-0${name === "B" ? 1 : 2}T00:00:00Z` });
  const order = async (now: string) => {
    const seen: string[] = [];
    const ctx: Ctx = { env: e, store, budget: new Budget(45), now: new Date(now) };
    await eachProfile(ctx, "test", async (c) => void seen.push(c.store.profile));
    return seen;
  };
  const first = await order("2026-10-24T10:00:00Z");
  const next = await order("2026-10-24T10:10:00Z");
  assert.deepEqual([...first].sort(), ["b", "c", "default"]);
  assert.notDeepEqual(first, next);
  assert.deepEqual([...next].sort(), ["b", "c", "default"]);
});

test("with more than one profile, pushes say whose they are", async () => {
  const e = env();
  const main = new Store(e);
  const net = mockFetch({});
  try {
    await raise(e, main, [{ kind: "system", title: "Hello", body: "", url: null, image: null, ref: null }]);
    await main.putProfile({ id: "shop", name: "Shop", createdAt: "2026-10-24T00:00:00Z" });
    await raise(e, main.forProfile("shop"), [{ kind: "system", title: "Hello", body: "", url: null, image: null, ref: null }]);
  } finally {
    net.restore();
  }
  assert.deepEqual(net.pushes.map((p) => p.title), ["Hello", "Shop: Hello"]);
});
