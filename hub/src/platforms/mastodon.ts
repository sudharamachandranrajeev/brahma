// Mastodon (any server). One click: the hub registers its own app on the
// user's server (Mastodon lets anyone), then signs in with OAuth. An access
// token from Preferences > Development > New application (scopes: read
// write) works too. Statuses carry an Idempotency-Key, so a retried publish
// never posts twice.

import { open, pkce, randomToken, seal } from "../crypto.ts";
import { call, form, InputError, PlatformError, wait } from "../http.ts";
import type { Account, Content, InboxItem } from "../types.ts";
import { clip, contentId, inboxItem, iso, itemId, type Adapter, type Connected, type Ctx } from "./adapter.ts";

export interface MastodonSecret {
  instance: string;
  token: string;
}

export function normaliseInstance(instance: string): string {
  let u: URL;
  try {
    u = new URL(/^https?:\/\//.test(instance) ? instance : `https://${instance}`);
  } catch {
    throw new InputError("Enter the Mastodon server, like mastodon.social");
  }
  if (u.protocol !== "https:") throw new InputError("The Mastodon server must use https");
  return u.origin;
}

/** Mastodon statuses are HTML; inbox shows plain text. */
export function htmlToText(html: string): string {
  return html
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/p>\s*<p>/gi, "\n\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .trim();
}

const m = async <T = any>(ctx: Ctx, account: Account, path: string, init: RequestInit = {}) => {
  const s = await ctx.store.secretOf<MastodonSecret>(account.id);
  return call<T>(s.instance + path, {
    ...init,
    budget: ctx.budget,
    label: "Mastodon",
    headers: { authorization: `Bearer ${s.token}`, ...(init.headers ?? {}) },
  });
};

const toAccount = (me: any, instance: string, now: string): Connected["account"] => ({
  platform: "mastodon",
  name: me.display_name || me.username,
  handle: `@${me.username}@${new URL(instance).host}`,
  avatar: me.avatar ?? null,
  remoteId: `${new URL(instance).host}:${me.id}`,
  status: "ok",
  statusMessage: null,
  expiresAt: null,
  capabilities: ["publish", "comments", "mentions"],
  connectedAt: now,
  checkedAt: now,
});

export async function connectMastodon(ctx: Ctx, instance: string, token: string): Promise<Connected> {
  const origin = normaliseInstance(instance);
  const me = await call(`${origin}/api/v1/accounts/verify_credentials`, { label: "Mastodon", headers: { authorization: `Bearer ${token}` } });
  return { account: toAccount(me, origin, ctx.now.toISOString()), secret: { instance: origin, token } satisfies MastodonSecret };
}

const scope = "read write";
export const mastodonRedirect = (publicUrl: string) => `${publicUrl}/oauth/mastodon/callback`;
const appKey = (origin: string) => `social:mastodon-app:${new URL(origin).host}`;

interface MastodonApp {
  clientId: string;
  clientSecret: string;
}

/** The hub's app on [origin], registered on first use and kept sealed in KV. */
async function mastodonApp(ctx: Ctx, origin: string): Promise<MastodonApp> {
  const saved = await ctx.env.KV.get(appKey(origin));
  if (saved) return open<MastodonApp>(ctx.env.TOKEN_KEY, saved);
  const app = await call(`${origin}/api/v1/apps`, {
    method: "POST",
    label: "Mastodon",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ client_name: "Vani", redirect_uris: mastodonRedirect(ctx.env.PUBLIC_URL), scopes: scope, website: "https://github.com/sudharamachandranrajeev/vani" }),
  });
  if (!app?.client_id || !app?.client_secret) throw new InputError("That server did not register Vani; is it a Mastodon server?", [], 502);
  const out = { clientId: String(app.client_id), clientSecret: String(app.client_secret) };
  await ctx.env.KV.put(appKey(origin), await seal(ctx.env.TOKEN_KEY, out));
  return out;
}

/** Starts a one-click sign-in on [instance]: returns the server's sign-in page. */
export async function startMastodon(ctx: Ctx, instance: string): Promise<{ url: string }> {
  const origin = normaliseInstance(instance);
  const app = await mastodonApp(ctx, origin);
  const state = randomToken();
  const p = await pkce();
  await ctx.env.KV.put(
    `social:oauth:${state}`,
    JSON.stringify({ provider: "mastodon", instance: origin, verifier: p.verifier, profile: ctx.store.profile }),
    { expirationTtl: 600 },
  );
  const u = new URL(`${origin}/oauth/authorize`);
  u.search = form({
    response_type: "code",
    client_id: app.clientId,
    redirect_uri: mastodonRedirect(ctx.env.PUBLIC_URL),
    scope,
    state,
    // Servers before 4.3 ignore PKCE; newer ones check it.
    code_challenge: p.challenge,
    code_challenge_method: "S256",
  }).toString();
  return { url: u.toString() };
}

/** Finishes the sign-in: trades the code for a token and reads the account. */
export async function finishMastodon(ctx: Ctx, origin: string, code: string, verifier?: string): Promise<Connected> {
  const app = await mastodonApp(ctx, origin);
  let tok: any;
  try {
    tok = await call(`${origin}/oauth/token`, {
      method: "POST",
      label: "Mastodon",
      body: form({
        grant_type: "authorization_code",
        code,
        client_id: app.clientId,
        client_secret: app.clientSecret,
        redirect_uri: mastodonRedirect(ctx.env.PUBLIC_URL),
        scope,
        code_verifier: verifier,
      }),
    });
  } catch (err) {
    // The server may have dropped the app; the next try registers a new one.
    if (err instanceof PlatformError && err.status === 401) await ctx.env.KV.delete(appKey(origin));
    throw err;
  }
  return connectMastodon(ctx, origin, String(tok.access_token));
}

async function status(ctx: Ctx, account: Account, body: object, key: string) {
  return m(ctx, account, "/api/v1/statuses", {
    method: "POST",
    headers: { "content-type": "application/json", "idempotency-key": key },
    body: JSON.stringify(body),
  });
}

export const mastodon: Adapter = {
  async publish(ctx, account, { post, text, media }) {
    const ids: string[] = [];
    for (const f of media) {
      const obj = await ctx.env.MEDIA.get(f.key);
      if (!obj) throw new PlatformError("The media file is gone from storage", 400, false, false);
      const fd = new FormData();
      fd.set("file", new File([await obj.arrayBuffer()], f.filename, { type: f.contentType }));
      if (f.alt) fd.set("description", f.alt);
      let att = await m(ctx, account, "/api/v2/media", { method: "POST", body: fd });
      // Video is processed in the background: wait until it has a URL.
      for (let i = 0; !att.url && i < 10; i++) {
        await wait(3000);
        att = await m(ctx, account, `/api/v1/media/${att.id}`);
      }
      if (!att.url) throw new PlatformError("Mastodon is still processing the media", 503, true, false);
      ids.push(att.id);
    }
    const r = await status(ctx, account, { status: text, media_ids: ids, visibility: "public" }, `vani-${post.id}-${account.id}`);
    return { remoteId: r.id, permalink: r.url ?? null };
  },

  async comment(ctx, account, remoteId, text) {
    await status(ctx, account, { status: text, in_reply_to_id: remoteId, visibility: "public" }, `vani-comment-${remoteId}`);
  },

  async poll(ctx, account) {
    const n = await m(ctx, account, "/api/v1/notifications?types[]=mention&limit=40");
    const items: InboxItem[] = [];
    for (const x of n ?? []) {
      if (!x.status) continue;
      items.push(
        inboxItem(account, {
          id: await itemId(account.id, x.status.id),
          kind: x.status.in_reply_to_id ? "reply" : "mention",
          context: { type: "post", id: x.status.in_reply_to_id ?? x.status.id, title: x.status.in_reply_to_id ? "Reply to your post" : "Mentioned you", url: x.status.url ?? null, thumbnail: null },
          author: { id: x.account.id, name: x.account.display_name || x.account.username, handle: `@${x.account.acct}`, avatar: x.account.avatar ?? null },
          text: htmlToText(x.status.content ?? ""),
          at: iso(x.status.created_at),
          remoteId: x.status.id,
          parentRemoteId: x.status.in_reply_to_id ?? null,
        }),
      );
    }
    const selfId = account.remoteId.split(":").pop();
    const statuses = await m(ctx, account, `/api/v1/accounts/${selfId}/statuses?limit=20&exclude_replies=true&exclude_reblogs=true`);
    const content: Content[] = [];
    for (const s of statuses ?? []) {
      content.push({
        id: await contentId(account.id, s.id),
        accountId: account.id,
        platform: "mastodon",
        remoteId: s.id,
        type: "post",
        caption: clip(htmlToText(s.content ?? ""), 500),
        url: s.url ?? null,
        thumbnail: s.media_attachments?.[0]?.preview_url ?? null,
        at: iso(s.created_at),
        likes: s.favourites_count ?? 0,
        comments: s.replies_count ?? 0,
        views: null,
      });
    }
    return { items, content, state: null };
  },

  async reply(ctx, account, item, text) {
    const mention = item.author.handle && !text.includes(item.author.handle) ? `${item.author.handle} ` : "";
    const r = await status(ctx, account, { status: mention + text, in_reply_to_id: item.remoteId, visibility: "public" }, `vani-reply-${item.id}-${text.length}`);
    return r.id;
  },

  async snapshot(ctx, account) {
    const me = await m(ctx, account, "/api/v1/accounts/verify_credentials");
    return { followers: me.followers_count ?? null, posts: me.statuses_count ?? null, views28d: null };
  },

  async check(ctx, account) {
    const s = await ctx.store.secretOf<MastodonSecret>(account.id);
    const me = await m(ctx, account, "/api/v1/accounts/verify_credentials");
    const fresh = toAccount(me, s.instance, account.connectedAt);
    return { ...account, name: fresh.name, handle: fresh.handle, avatar: fresh.avatar };
  },
};
