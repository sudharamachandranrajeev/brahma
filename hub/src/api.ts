// The /social/* HTTP API (Vani's backend). The caller has already checked the
// bearer token. Every body is validated with zod before it touches storage.

import { z } from "zod";
import { checkAccount } from "./accounts.ts";
import { caption, describeImage, hasAi, listModels, NeedsDeviceAi, suggestReplies, suggestWatch, translate, useDeviceAi } from "./ai.ts";
import { raise, type NewAlert } from "./alerts.ts";
import { checkCredential, type CheckedProvider } from "./credcheck.ts";
import { webhookVerifyToken } from "./crypto.ts";
import { runState, runWatch, saveRunState } from "./discovery.ts";
import { InputError, PlatformError } from "./http.ts";
import { moderate, pollAll, replyTo, translateItem } from "./inbox.ts";
import { completeUpload, deleteMedia, setAlt, signedUrl, startUpload, uploadPart, withUrl } from "./media.ts";
import { redirectUri, startConnect } from "./oauth.ts";
import { platformInfo, type Ctx } from "./platforms/adapter.ts";
import { connectBluesky } from "./platforms/bluesky.ts";
import { connectMastodon, startMastodon } from "./platforms/mastodon.ts";
import { connectTelegram } from "./platforms/telegram.ts";
import { addProfile, deleteProfile, profileInput, renameProfile, requestProfile } from "./profiles.ts";
import { overall, postInput, publishPost, retryPost, savePost } from "./publish.ts";
import { discoveryInput, getRules, getSettings, getWatches, rulesInput, settingsInput } from "./settings.ts";
import { cachedIdeas, getStats, refreshIdeas, weeklySummary } from "./stats.ts";
import { aiProviders, type AiProvider, type CredentialProvider, type Platform, type Provider } from "./types.ts";
import { hubVersion } from "./version.ts";

const providers = ["meta", "threads", "google", "linkedin"] as const satisfies readonly Provider[];
const credentialProviders = [...providers, "ebay", ...aiProviders] as const satisfies readonly CredentialProvider[];
const isAi = (p: CredentialProvider): p is AiProvider => (aiProviders as readonly string[]).includes(p);
const platforms = Object.keys(platformInfo) as [Platform, ...Platform[]];
const inboxStatus = z.enum(["new", "read", "done"]);

interface Req {
  ctx: Ctx;
  req: Request;
  params: Record<string, string>;
  query: URLSearchParams;
  body<T extends z.ZodType>(schema: T): Promise<z.infer<T>>;
}

type Handler = (r: Req) => Promise<unknown>;

const routes: { method: string; pattern: RegExp; keys: string[]; handler: Handler }[] = [];

function route(method: string, path: string, handler: Handler) {
  const keys: string[] = [];
  const pattern = new RegExp(`^${path.replace(/:(\w+)/g, (_, k) => (keys.push(k), "([^/]+)"))}$`);
  routes.push({ method, pattern, keys, handler });
}

async function need<T>(value: Promise<T | null>, what: string): Promise<T> {
  const v = await value;
  if (v == null) throw new InputError(`no such ${what}`, [], 404);
  return v;
}

const int = (s: string | null, fallback: number) => (s && /^\d+$/.test(s) ? Number(s) : fallback);

// ---- home and setup ----

route("GET", "/social/overview", async ({ ctx: { store, now } }) => {
  const stats = await getStats(store, now);
  const counts = await store.inboxCounts();
  const upcoming = (await store.posts({ status: "scheduled", from: now.toISOString() }))
    .sort((a, b) => (a.scheduledAt ?? "").localeCompare(b.scheduledAt ?? ""))
    .slice(0, 10);
  return {
    accounts: await store.accounts(),
    stats,
    inbox: { new: counts.new, read: counts.read },
    upcoming,
    alerts: await store.alerts({ limit: 10 }),
    recentInbox: await store.inbox({ status: "open", limit: 10 }),
    topContent: stats.topContent,
    ideas: (await cachedIdeas(store)).ideas,
  };
});

route("GET", "/social/meta", async ({ ctx: { env, store } }) => ({
  platforms: platformInfo,
  redirectUris: Object.fromEntries(providers.map((p) => [p, redirectUri(env, p)])),
  webhookUrl: `${env.PUBLIC_URL}/webhooks/meta`,
  threadsWebhookUrl: `${env.PUBLIC_URL}/webhooks/threads`,
  verifyToken: await webhookVerifyToken(env.TOKEN_KEY),
  ai: await hasAi(store),
  aiProviders,
  hubVersion,
}));

route("GET", "/social/credentials", async ({ ctx }) => ctx.store.credentialStatus([...credentialProviders]));

const providerParam = (p: string) => z.enum(credentialProviders).parse(p);

route("PUT", "/social/credentials/:provider", async ({ ctx, params, body }) => {
  const provider = providerParam(params.provider);
  const input = await body(z.object({ publicId: z.string().trim().min(1).max(200).optional(), secret: z.string().trim().min(1).max(500) }));
  // AI keys need no id, except an OpenAI-compatible service: its address.
  const needsId = !isAi(provider) || provider === "compatible";
  if (needsId && !input.publicId) {
    throw new InputError(provider === "compatible" ? "compatible needs the service's API address as publicId" : `${provider} needs the app or client id as publicId`);
  }
  if (provider === "compatible") input.publicId = apiBase(input.publicId!);
  await ctx.store.putCredential(provider, needsId ? input.publicId! : null, input.secret);
  if (provider === "ebay") await ctx.env.KV.delete("social:ebay-token");
  return (await ctx.store.credentialStatus([provider]))[0];
});

/** Checks an app's ID and secret with the platform (the stored secret when none is sent), before or after saving. */
route("POST", "/social/credentials/:provider/check", async ({ ctx, params, body }) => {
  const provider = z.enum(["meta", "threads", "google", "linkedin", "ebay"] as const satisfies readonly CheckedProvider[]).parse(params.provider);
  const input = await body(z.object({ publicId: z.string().trim().min(1).max(200), secret: z.string().trim().min(1).max(500).optional() }));
  const secret = input.secret ?? (await ctx.store.credential(provider))?.secret;
  if (!secret) throw new InputError("enter the secret to check");
  const redirect = provider === "ebay" ? null : redirectUri(ctx.env, provider);
  return { detail: await checkCredential(provider, input.publicId, secret, redirect) };
});

/** An OpenAI-compatible API address the Worker can reach: https on the public internet. */
function apiBase(raw: string): string {
  let u: URL;
  try {
    u = new URL(raw);
  } catch {
    throw new InputError("the API address must be a web address, like https://api.example.com/v1");
  }
  const host = u.hostname;
  if (u.protocol !== "https:" || host === "localhost" || /^(127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|169\.254\.)/.test(host) || host.endsWith(".local") || host.endsWith(".ts.net")) {
    throw new InputError("the hub runs on the internet, so the API address must be public https (a model on your own computer works from Vani on that computer instead)");
  }
  return u.toString().replace(/\/+$/, "");
}

route("DELETE", "/social/credentials/:provider", async ({ ctx, params }) => {
  await ctx.store.deleteCredential(providerParam(params.provider));
  return { deleted: true };
});

// ---- profiles (hub-wide; every other route works in the x-vani-profile profile) ----

route("GET", "/social/profiles", async ({ ctx }) => ctx.store.profiles());

route("POST", "/social/profiles", async ({ ctx, body }) => addProfile(ctx, (await body(profileInput)).name));

route("PATCH", "/social/profiles/:id", async ({ ctx, params, body }) => renameProfile(ctx, params.id, (await body(profileInput)).name));

route("DELETE", "/social/profiles/:id", async ({ ctx, params }) => {
  await deleteProfile(ctx, params.id);
  return { ok: true };
});

// ---- accounts ----

route("GET", "/social/accounts", async ({ ctx }) => ctx.store.accounts());

route("POST", "/social/connect/mastodon", async ({ ctx, body }) =>
  startMastodon(ctx, (await body(z.object({ instance: z.string().trim().min(3).max(253) }))).instance),
);

route("POST", "/social/connect/:provider", async ({ ctx, params }) => startConnect(ctx, z.enum(providers).parse(params.provider)));

route("POST", "/social/accounts/bluesky", async ({ ctx, body }) => {
  const input = await body(
    z.object({ handle: z.string().trim().min(3).max(253), appPassword: z.string().trim().min(8).max(100), service: z.url({ protocol: /^https$/ }).optional() }),
  );
  const c = await connectBluesky(ctx, input.handle, input.appPassword, input.service);
  return ctx.store.saveAccount(c.account, c.secret);
});

route("POST", "/social/accounts/mastodon", async ({ ctx, body }) => {
  const input = await body(z.object({ instance: z.string().trim().min(3).max(253), accessToken: z.string().trim().min(10).max(500) }));
  const c = await connectMastodon(ctx, input.instance, input.accessToken);
  return ctx.store.saveAccount(c.account, c.secret);
});

route("POST", "/social/accounts/telegram", async ({ ctx, body }) => {
  const input = await body(
    z.object({ botToken: z.string().trim().regex(/^\d{5,20}:[\w-]{30,60}$/, "that doesn't look like a bot token"), chat: z.string().trim().min(2).max(100) }),
  );
  const c = await connectTelegram(ctx, input.botToken, input.chat);
  return ctx.store.saveAccount(c.account, c.secret);
});

route("POST", "/social/accounts/:id/check", async ({ ctx, params }) => {
  const account = await need(ctx.store.account(params.id), "account");
  const alerts: NewAlert[] = [];
  const checked = await checkAccount(ctx, account, alerts);
  if (alerts.length) await raise(ctx.env, ctx.store, alerts);
  return checked;
});

route("DELETE", "/social/accounts/:id", async ({ ctx, params }) => {
  await ctx.store.deleteAccount(params.id);
  return { deleted: true };
});

// ---- media ----

route("GET", "/social/media", async ({ ctx }) => Promise.all((await ctx.store.allMedia()).map((m) => withUrl(ctx.store, m))));

route("POST", "/social/media", async ({ ctx, body }) =>
  startUpload(ctx.store, await body(z.object({ filename: z.string().min(1).max(200), contentType: z.string().max(100), size: z.number().int().positive() }))),
);

route("PUT", "/social/media/:id/parts/:n", async ({ ctx, req, params }) =>
  uploadPart(ctx.store, params.id, Number(params.n), req.body, Number(req.headers.get("content-length") ?? -1)),
);

route("POST", "/social/media/:id/complete", async ({ ctx, params, body }) => {
  const input = await body(z.object({ parts: z.array(z.object({ n: z.number().int().min(1).max(10000), etag: z.string().min(1).max(200) })).min(1).max(10000) }));
  return completeUpload(ctx.store, params.id, input.parts);
});

route("PATCH", "/social/media/:id", async ({ ctx, params, body }) => {
  const { alt } = await body(z.object({ alt: z.string().max(1500) }));
  return setAlt(ctx.store, params.id, alt);
});

route("POST", "/social/media/:id/alt", async ({ ctx, params, body }) => {
  const { context } = await body(z.object({ context: z.string().max(4000).optional() }));
  const m = await need(ctx.store.media(params.id), "media");
  if (m.status !== "ready") throw new InputError("the file is still uploading", [], 409);
  if (!/^image\/(jpeg|png|webp|gif)$/.test(m.contentType)) throw new InputError("alt text can be drafted for JPEG, PNG, WebP and GIF images only", [], 422);
  return setAlt(ctx.store, m.id, await describeImage(ctx.store, await signedUrl(ctx.store, m.id, 1), context ?? ""));
});

route("DELETE", "/social/media/:id", async ({ ctx, params }) => {
  await deleteMedia(ctx.store, params.id);
  return { deleted: true };
});

// ---- posts ----

route("GET", "/social/posts", async ({ ctx, query }) =>
  ctx.store.posts({ from: query.get("from") ?? undefined, to: query.get("to") ?? undefined, status: query.get("status") ?? undefined }),
);

route("POST", "/social/posts", async ({ ctx, body }) => savePost(ctx.store, await body(postInput), null, ctx.now));

route("PUT", "/social/posts/:id", async ({ ctx, params, body }) => {
  const existing = await need(ctx.store.post(params.id), "post");
  return savePost(ctx.store, await body(postInput), existing, ctx.now);
});

route("DELETE", "/social/posts/:id", async ({ ctx, params }) => {
  const post = await need(ctx.store.post(params.id), "post");
  if (post.status === "publishing") throw new InputError("this post is publishing right now", [], 409);
  await ctx.store.deletePost(params.id);
  return { deleted: true };
});

route("POST", "/social/posts/:id/publish", async ({ ctx, params }) => {
  const post = await need(ctx.store.post(params.id), "post");
  if (post.status !== "draft" && post.status !== "scheduled") throw new InputError(`this post is ${post.status}`, [], 409);
  for (const t of post.targets) if (t.status === "draft") t.status = "scheduled";
  Object.assign(post, { status: overall(post.targets), scheduledAt: ctx.now.toISOString(), updatedAt: ctx.now.toISOString() });
  await ctx.store.savePost(post);
  await ctx.store.setLock(post.id, null);
  return (await publishPost(ctx, post.id)) ?? (await ctx.store.post(post.id));
});

route("POST", "/social/posts/:id/retry", async ({ ctx, params, body }) => {
  const post = await need(ctx.store.post(params.id), "post");
  const { force } = await body(z.object({ force: z.boolean().optional() }));
  await retryPost(ctx.store, post, force ?? false, ctx.now);
  return (await publishPost(ctx, post.id)) ?? (await ctx.store.post(post.id));
});

// ---- inbox ----

route("GET", "/social/inbox", async ({ ctx, query }) => ({
  items: await ctx.store.inbox({
    status: query.get("status") ?? undefined,
    platform: query.get("platform") ?? undefined,
    kind: query.get("kind") ?? undefined,
    accountId: query.get("accountId") ?? undefined,
    triage: query.get("triage") ?? undefined,
    before: query.get("before") ?? undefined,
    limit: int(query.get("limit"), 50),
  }),
  counts: await ctx.store.inboxCounts(),
}));

route("POST", "/social/inbox/refresh", async ({ ctx }) => pollAll(ctx));

route("POST", "/social/inbox/bulk", async ({ ctx, body }) => {
  const { ids, status } = await body(z.object({ ids: z.array(z.string().max(64)).max(1000), status: inboxStatus }));
  await ctx.store.setInboxStatus(ids, status);
  return { updated: ids.length };
});

route("PATCH", "/social/inbox/:id", async ({ ctx, params, body }) => {
  await need(ctx.store.inboxItem(params.id), "inbox item");
  const { status } = await body(z.object({ status: inboxStatus }));
  await ctx.store.setInboxStatus([params.id], status);
  return ctx.store.inboxItem(params.id);
});

route("POST", "/social/inbox/:id/reply", async ({ ctx, params, body }) => {
  const input = await body(z.object({ text: z.string().trim().min(1).max(10000), private: z.boolean().optional() }));
  return replyTo(ctx, params.id, input.text, input.private ?? false);
});

route("POST", "/social/inbox/:id/suggest", async ({ ctx, params }) => {
  const item = await need(ctx.store.inboxItem(params.id), "inbox item");
  const account = await need(ctx.store.account(item.accountId), "account");
  return { suggestions: await suggestReplies(ctx.store, item, account, (await getSettings(ctx.store)).savedReplies) };
});

route("POST", "/social/inbox/:id/moderate", async ({ ctx, params, body }) => {
  const { action } = await body(z.object({ action: z.enum(["hide", "unhide", "delete"]) }));
  return moderate(ctx, params.id, action);
});

route("POST", "/social/inbox/:id/translate", async ({ ctx, params }) => translateItem(ctx, params.id));

route("GET", "/social/content", async ({ ctx, query }) => ctx.store.content(query.get("accountId") ?? undefined, Math.min(int(query.get("limit"), 50), 500)));

// ---- rules, discovery, alerts ----

route("GET", "/social/rules", async ({ ctx }) => getRules(ctx.store));
route("PUT", "/social/rules", async ({ ctx, body }) => {
  const rules = await body(rulesInput);
  await ctx.store.putDoc("rules", rules);
  return rules;
});

route("GET", "/social/discovery", async ({ ctx }) => getWatches(ctx.store));
route("PUT", "/social/discovery", async ({ ctx, body }) => {
  const watches = await body(discoveryInput);
  const before = await getWatches(ctx.store);
  for (const old of before) if (!watches.some((w) => w.id === old.id)) await ctx.store.forgetWatch(old.id);
  await ctx.store.putDoc("discovery", watches);
  return watches;
});

route("POST", "/social/discovery/suggest", async ({ ctx, body }) => {
  const input = await body(z.object({ description: z.string().trim().min(3).max(1000), postcode: z.string().trim().max(12).optional() }));
  return suggestWatch(ctx.store, input.description, await ctx.store.accounts(), input.postcode || null);
});

route("POST", "/social/discovery/:id/run", async ({ ctx, params }) => {
  const watch = (await getWatches(ctx.store)).find((w) => w.id === params.id);
  if (!watch) throw new InputError("no such watch", [], 404);
  const state = await runState(ctx);
  try {
    return await runWatch(ctx, watch, state);
  } finally {
    await saveRunState(ctx, state);
  }
});

route("GET", "/social/alerts", async ({ ctx, query }) =>
  ctx.store.alerts({ since: query.get("since") ?? undefined, unread: query.get("unread") === "true" || query.get("unread") === "1" }),
);

route("POST", "/social/alerts/read", async ({ ctx, body }) => {
  const { ids } = await body(z.object({ ids: z.array(z.string().max(64)).max(1000).optional() }));
  await ctx.store.markAlertsRead(ids);
  return { read: true };
});

// ---- stats, settings, AI ----

route("GET", "/social/stats", async ({ ctx }) => getStats(ctx.store, ctx.now));

route("GET", "/social/settings", async ({ ctx }) => getSettings(ctx.store));
route("PUT", "/social/settings", async ({ ctx, body }) => {
  const settings = await body(settingsInput);
  await ctx.store.putDoc("settings", settings);
  return settings;
});

route("POST", "/social/ai/caption", async ({ ctx, body }) => {
  const input = await body(z.object({ brief: z.string().trim().min(3).max(4000), platforms: z.array(z.enum(platforms)).min(1).max(8), tone: z.string().max(100).optional() }));
  return caption(ctx.store, input.brief, input.platforms, input.tone);
});

route("POST", "/social/ai/translate", async ({ ctx, body }) => {
  const input = await body(z.object({ text: z.string().trim().min(1).max(5000), to: z.string().trim().min(2).max(40).regex(/^[\p{L} ()-]+$/u) }));
  return translate(ctx.store, input.text, input.to);
});

route("GET", "/social/ai/models", async ({ ctx, query }) => {
  const provider = z.enum(aiProviders as [AiProvider, ...AiProvider[]]).parse(query.get("provider"));
  const cred = await ctx.store.credential(provider);
  if (!cred) throw new InputError(`no ${provider} key yet`, [], 412);
  return { models: await listModels(provider, cred.secret, cred.publicId) };
});

route("POST", "/social/ai/weekly", async ({ ctx }) => weeklySummary(ctx));

route("GET", "/social/ai/ideas", async ({ ctx }) => {
  const cached = await cachedIdeas(ctx.store);
  const stale = !cached.generatedAt || ctx.now.getTime() - new Date(cached.generatedAt).getTime() > 86400_000;
  return stale && (await hasAi(ctx.store)) ? refreshIdeas(ctx.store, ctx.now) : cached;
});

// ---- dispatch ----

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", "cache-control": "no-store" } });

export async function handleSocial(ctx: Ctx, req: Request): Promise<Response> {
  const url = new URL(req.url);
  let pathMatched = false;
  for (const r of routes) {
    const m = url.pathname.match(r.pattern);
    if (!m) continue;
    pathMatched = true;
    if (r.method !== req.method) continue;
    const params = Object.fromEntries(r.keys.map((k, i) => [k, decodeURIComponent(m[i + 1])]));
    const body = async <T extends z.ZodType>(schema: T): Promise<z.infer<T>> => {
      const text = await req.text();
      let raw: unknown = {};
      try {
        if (text.trim()) raw = JSON.parse(text);
      } catch {
        throw new InputError("the body must be JSON");
      }
      return schema.parse(raw);
    };
    try {
      const inside = url.pathname.startsWith("/social/profiles") ? ctx : await requestProfile(ctx, req);
      if (req.headers.get("x-vani-ai") === "device") useDeviceAi(inside.store, deviceAnswers(req));
      return json(await r.handler({ ctx: inside, req, params, query: url.searchParams, body }));
    } catch (err) {
      return errorResponse(err);
    }
  }
  return json({ error: pathMatched ? "method not allowed" : "not found" }, pathMatched ? 405 : 404);
}

/** The device's answers so far: base64url JSON array in x-vani-ai-answers. */
function deviceAnswers(req: Request): unknown[] {
  const raw = req.headers.get("x-vani-ai-answers");
  if (!raw) return [];
  try {
    const bin = atob(raw.replace(/-/g, "+").replace(/_/g, "/"));
    const out = JSON.parse(new TextDecoder().decode(Uint8Array.from(bin, (c) => c.charCodeAt(0))));
    if (Array.isArray(out)) return out;
  } catch {
    // Unreadable: answered as invalid below.
  }
  throw new InputError("x-vani-ai-answers must be a base64url JSON array");
}

function errorResponse(err: unknown): Response {
  if (err instanceof NeedsDeviceAi) return json({ error: err.message, needsAi: err.request }, 409);
  if (err instanceof z.ZodError) {
    return json({ error: "invalid request", problems: err.issues.map((i) => `${i.path.join(".") || "body"}: ${i.message}`) }, 400);
  }
  if (err instanceof InputError) return json({ error: err.message, ...(err.problems.length ? { problems: err.problems } : {}) }, err.status);
  if (err instanceof PlatformError) return json({ error: err.message }, err.transient ? 503 : 502);
  console.log(`api error: ${err instanceof Error ? (err.stack ?? err.message) : err}`);
  return json({ error: "internal error" }, 500);
}
