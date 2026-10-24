// Bluesky (AT Protocol) with an app password (Settings > Privacy and
// security > App passwords). Sessions renew themselves from the password.

import { call, PlatformError } from "../http.ts";
import type { Account, Content, InboxItem } from "../types.ts";
import { contentId, inboxItem, iso, itemId, type Adapter, type Connected, type Ctx } from "./adapter.ts";

export interface BlueskySecret {
  service: string;
  identifier: string;
  appPassword: string;
  did: string;
  accessJwt: string;
  refreshJwt: string;
}

const xrpc = (service: string, method: string) => `${service.replace(/\/$/, "")}/xrpc/${method}`;

export async function connectBluesky(ctx: Ctx, handle: string, appPassword: string, service = "https://bsky.social"): Promise<Connected> {
  const s = await call(xrpc(service, "com.atproto.server.createSession"), {
    method: "POST",
    label: "Bluesky",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ identifier: handle.replace(/^@/, ""), password: appPassword }),
  });
  const profile = await call(`${xrpc(service, "app.bsky.actor.getProfile")}?actor=${encodeURIComponent(s.did)}`, {
    label: "Bluesky",
    headers: { authorization: `Bearer ${s.accessJwt}` },
  });
  const now = ctx.now.toISOString();
  return {
    account: {
      platform: "bluesky",
      name: profile.displayName || s.handle,
      handle: s.handle,
      avatar: profile.avatar ?? null,
      remoteId: s.did,
      status: "ok",
      statusMessage: null,
      expiresAt: null,
      capabilities: ["publish", "comments", "mentions"],
      connectedAt: now,
      checkedAt: now,
    },
    secret: { service, identifier: handle.replace(/^@/, ""), appPassword, did: s.did, accessJwt: s.accessJwt, refreshJwt: s.refreshJwt } satisfies BlueskySecret,
  };
}

/** Calls an XRPC method, renewing the session once if it has expired. */
export async function bsky<T = any>(ctx: Ctx, account: Account, method: string, init: { query?: Record<string, string>; body?: unknown; raw?: { data: ArrayBuffer; type: string } } = {}): Promise<T> {
  let s = await ctx.store.secretOf<BlueskySecret>(account.id);
  const send = (token: string) => {
    const url = new URL(xrpc(s.service, method));
    for (const [k, v] of Object.entries(init.query ?? {})) url.searchParams.set(k, v);
    const post = init.body !== undefined || init.raw;
    return call<T>(url, {
      method: post ? "POST" : "GET",
      budget: ctx.budget,
      label: "Bluesky",
      headers: { authorization: `Bearer ${token}`, ...(post ? { "content-type": init.raw?.type ?? "application/json" } : {}) },
      body: init.raw ? init.raw.data : init.body !== undefined ? JSON.stringify(init.body) : undefined,
    });
  };
  try {
    return await send(s.accessJwt);
  } catch (err) {
    if (!(err instanceof PlatformError) || (err.status !== 400 && err.status !== 401) || !/expired|token/i.test(err.message)) throw err;
  }
  // Renew from the app password (refresh tokens also expire; the password does not).
  const fresh = await call(xrpc(s.service, "com.atproto.server.createSession"), {
    method: "POST",
    budget: ctx.budget,
    label: "Bluesky",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ identifier: s.identifier, password: s.appPassword }),
  });
  s = { ...s, accessJwt: fresh.accessJwt, refreshJwt: fresh.refreshJwt };
  await ctx.store.updateAccount(account, s);
  return send(s.accessJwt);
}

const utf8 = new TextEncoder();

/** Rich-text facets for links and #hashtags (byte offsets, as the protocol counts them). */
export function facets(text: string) {
  const out: object[] = [];
  const add = (re: RegExp, feature: (m: RegExpExecArray) => object) => {
    for (let m: RegExpExecArray | null; (m = re.exec(text)); ) {
      const start = utf8.encode(text.slice(0, m.index)).byteLength;
      out.push({ index: { byteStart: start, byteEnd: start + utf8.encode(m[0]).byteLength }, features: [feature(m)] });
    }
  };
  add(/https?:\/\/[^\s)]+/g, (m) => ({ $type: "app.bsky.richtext.facet#link", uri: m[0] }));
  add(/(?<![\w#])#([\p{L}\p{N}_]{1,64})/gu, (m) => ({ $type: "app.bsky.richtext.facet#tag", tag: m[1] }));
  return out;
}

const rkey = (uri: string) => uri.split("/").pop() ?? "";

async function postRef(ctx: Ctx, account: Account, uri: string) {
  const r = await bsky(ctx, account, "app.bsky.feed.getPosts", { query: { uris: uri } });
  const p = r.posts?.[0];
  if (!p) throw new PlatformError("Bluesky: that post is gone", 404, false, false);
  return { uri: p.uri as string, cid: p.cid as string, root: (p.record?.reply?.root as { uri: string; cid: string } | undefined) ?? { uri: p.uri, cid: p.cid } };
}

async function createPost(ctx: Ctx, account: Account, record: object) {
  const s = await ctx.store.secretOf<BlueskySecret>(account.id);
  return bsky<{ uri: string; cid: string }>(ctx, account, "com.atproto.repo.createRecord", {
    body: { repo: s.did, collection: "app.bsky.feed.post", record: { $type: "app.bsky.feed.post", createdAt: ctx.now.toISOString(), ...record } },
  });
}

async function replyTo(ctx: Ctx, account: Account, uri: string, text: string) {
  const parent = await postRef(ctx, account, uri);
  const r = await createPost(ctx, account, { text, facets: facets(text), reply: { root: parent.root, parent: { uri: parent.uri, cid: parent.cid } } });
  return r.uri;
}

export const bluesky: Adapter = {
  async publish(ctx, account, { text, media }, progress) {
    const images = [];
    for (const m of media) {
      if (!m.contentType.startsWith("image/")) throw new PlatformError("Bluesky posts here take images only", 400, false, false);
      const obj = await ctx.env.MEDIA.get(m.key);
      if (!obj) throw new PlatformError("The media file is gone from storage", 400, false, false);
      const r = await bsky(ctx, account, "com.atproto.repo.uploadBlob", { raw: { data: await obj.arrayBuffer(), type: m.contentType } });
      images.push({ alt: "", image: r.blob });
    }
    progress.commit();
    const r = await createPost(ctx, account, {
      text,
      facets: facets(text),
      ...(images.length ? { embed: { $type: "app.bsky.embed.images", images } } : {}),
    });
    return { remoteId: r.uri, permalink: `https://bsky.app/profile/${account.handle}/post/${rkey(r.uri)}` };
  },

  async comment(ctx, account, remoteId, text) {
    await replyTo(ctx, account, remoteId, text);
  },

  async poll(ctx, account) {
    const s = await ctx.store.secretOf<BlueskySecret>(account.id);
    const n = await bsky(ctx, account, "app.bsky.notification.listNotifications", { query: { limit: "50" } });
    const items: InboxItem[] = [];
    for (const x of n.notifications ?? []) {
      if (!["reply", "mention", "quote"].includes(x.reason) || x.author?.did === s.did) continue;
      const url = `https://bsky.app/profile/${x.author.handle}/post/${rkey(x.uri)}`;
      items.push(
        inboxItem(account, {
          id: await itemId(account.id, x.uri),
          kind: x.reason === "reply" ? "reply" : "mention",
          context: {
            type: "post",
            id: x.record?.reply?.parent?.uri ?? x.uri,
            title: x.reason === "reply" ? "Reply to your post" : x.reason === "quote" ? "Quoted your post" : "Mentioned you",
            url,
            thumbnail: null,
          },
          author: { id: x.author.did, name: x.author.displayName || x.author.handle, handle: x.author.handle, avatar: x.author.avatar ?? null },
          text: x.record?.text ?? "",
          at: iso(x.record?.createdAt ?? x.indexedAt),
          remoteId: x.uri,
          parentRemoteId: x.record?.reply?.parent?.uri ?? null,
        }),
      );
    }
    const feed = await bsky(ctx, account, "app.bsky.feed.getAuthorFeed", { query: { actor: s.did, filter: "posts_no_replies", limit: "20" } });
    const content: Content[] = [];
    for (const { post: p } of feed.feed ?? []) {
      if (p.author?.did !== s.did) continue;
      content.push({
        id: await contentId(account.id, p.uri),
        accountId: account.id,
        platform: "bluesky",
        remoteId: p.uri,
        type: "post",
        caption: p.record?.text ?? "",
        url: `https://bsky.app/profile/${account.handle}/post/${rkey(p.uri)}`,
        thumbnail: p.embed?.images?.[0]?.thumb ?? null,
        at: iso(p.record?.createdAt ?? p.indexedAt),
        likes: p.likeCount ?? 0,
        comments: p.replyCount ?? 0,
        views: null,
      });
    }
    return { items, content, state: null };
  },

  reply: (ctx, account, item, text) => replyTo(ctx, account, item.remoteId, text),

  async snapshot(ctx, account) {
    const p = await bsky(ctx, account, "app.bsky.actor.getProfile", { query: { actor: account.remoteId } });
    return { followers: p.followersCount ?? null, posts: p.postsCount ?? null, views28d: null };
  },

  async check(ctx, account) {
    const p = await bsky(ctx, account, "app.bsky.actor.getProfile", { query: { actor: account.remoteId } });
    return { ...account, name: p.displayName || p.handle, handle: p.handle, avatar: p.avatar ?? account.avatar };
  },
};
