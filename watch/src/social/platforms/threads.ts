// Threads API (graph.threads.net). Its own sign-in, separate from Facebook
// Login; tokens last 60 days and are refreshed daily once they are a day old.

import { call, form, PlatformError, wait } from "../http.ts";
import type { Content, InboxItem } from "../types.ts";
import { clip, contentId, inboxItem, isVideo, iso, itemId, type Adapter, type Ctx, type OAuthFlow } from "./adapter.ts";

const api = "https://graph.threads.net/v1.0";

export interface ThreadsSecret {
  token: string;
  userId: string;
  expiresAt: string;
}

const t = <T = any>(ctx: Ctx, path: string, token: string, params: Record<string, string> = {}) => {
  const url = new URL(api + path);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
  url.searchParams.set("access_token", token);
  return call<T>(url, { budget: ctx.budget, label: "Threads" });
};

const tPost = <T = any>(ctx: Ctx, path: string, token: string, data: Record<string, string | boolean | undefined>) =>
  call<T>(api + path, { method: "POST", budget: ctx.budget, label: "Threads", body: form({ ...data, access_token: token }) });

export const threadsOAuth: OAuthFlow = {
  authorizeUrl: ({ clientId, redirectUri, state }) => {
    const u = new URL("https://threads.net/oauth/authorize");
    u.search = form({
      client_id: clientId,
      redirect_uri: redirectUri,
      state,
      response_type: "code",
      scope: "threads_basic,threads_content_publish,threads_manage_replies,threads_read_replies,threads_manage_insights",
    }).toString();
    return u.toString();
  },
  async exchange(ctx, { clientId, clientSecret, redirectUri, code }) {
    const short = await call("https://graph.threads.net/oauth/access_token", {
      method: "POST",
      label: "Threads",
      body: form({ client_id: clientId, client_secret: clientSecret, grant_type: "authorization_code", redirect_uri: redirectUri, code }),
    });
    const long = await call(
      `https://graph.threads.net/access_token?${form({ grant_type: "th_exchange_token", client_secret: clientSecret, access_token: short.access_token })}`,
      { label: "Threads" },
    );
    const me = await t(ctx, "/me", long.access_token, { fields: "id,username,name,threads_profile_picture_url" });
    const expiresAt = new Date(ctx.now.getTime() + (long.expires_in ?? 5184000) * 1000).toISOString();
    const now = ctx.now.toISOString();
    return [
      {
        account: {
          platform: "threads",
          name: me.name || me.username,
          handle: me.username,
          avatar: me.threads_profile_picture_url ?? null,
          remoteId: me.id,
          status: "ok",
          statusMessage: null,
          expiresAt,
          capabilities: ["publish", "comments", "insights"],
          connectedAt: now,
          checkedAt: now,
        },
        secret: { token: long.access_token, userId: me.id, expiresAt } satisfies ThreadsSecret,
      },
    ];
  },
};

async function ready(ctx: Ctx, id: string, token: string, maxSeconds = 40) {
  const started = Date.now();
  for (;;) {
    const r = await t(ctx, `/${id}`, token, { fields: "status,error_message" });
    if (r.status === "FINISHED" || r.status === "PUBLISHED") return;
    if (r.status === "ERROR" || r.status === "EXPIRED") throw new PlatformError(`Threads: ${r.error_message ?? r.status}`, 400, false, false);
    if (Date.now() - started > maxSeconds * 1000) throw new PlatformError("Threads is still processing the media", 503, true, false);
    await wait(3000);
  }
}

async function createAndPublish(ctx: Ctx, s: ThreadsSecret, body: Record<string, string | boolean | undefined>, existing: string | undefined, save: (id: string) => Promise<void>, commit: () => void) {
  let creation = existing;
  if (!creation) {
    creation = (await tPost(ctx, `/${s.userId}/threads`, s.token, body)).id as string;
    await save(creation);
  }
  await ready(ctx, creation, s.token);
  commit();
  return (await tPost(ctx, `/${s.userId}/threads_publish`, s.token, { creation_id: creation })).id as string;
}

export const threads: Adapter = {
  async publish(ctx, account, { target, text, media }, progress) {
    const s = await ctx.store.secretOf<ThreadsSecret>(account.id);
    let body: Record<string, string | boolean | undefined>;
    if (target.containerId) body = {};
    else if (media.length > 1) {
      const children: string[] = [];
      for (const m of media) {
        children.push(
          (await tPost(ctx, `/${s.userId}/threads`, s.token, isVideo(m)
            ? { media_type: "VIDEO", video_url: m.url, is_carousel_item: true }
            : { media_type: "IMAGE", image_url: m.url, is_carousel_item: true, alt_text: m.alt || undefined })).id,
        );
      }
      for (const id of children) await ready(ctx, id, s.token);
      body = { media_type: "CAROUSEL", children: children.join(","), text };
    } else if (media.length === 1) {
      body = isVideo(media[0])
        ? { media_type: "VIDEO", video_url: media[0].url, text }
        : { media_type: "IMAGE", image_url: media[0].url, text, alt_text: media[0].alt || undefined };
    } else {
      body = { media_type: "TEXT", text };
    }
    const id = await createAndPublish(ctx, s, body, target.containerId, progress.saveContainer, progress.commit);
    let permalink: string | null = null;
    try {
      permalink = (await t(ctx, `/${id}`, s.token, { fields: "permalink" })).permalink ?? null;
    } catch {
      // Up anyway.
    }
    return { remoteId: id, permalink };
  },

  async comment(ctx, account, remoteId, text) {
    const s = await ctx.store.secretOf<ThreadsSecret>(account.id);
    return createAndPublish(ctx, s, { media_type: "TEXT", text, reply_to_id: remoteId }, undefined, async () => {}, () => {});
  },

  async poll(ctx, account) {
    const s = await ctx.store.secretOf<ThreadsSecret>(account.id);
    const posts = await t(ctx, `/${s.userId}/threads`, s.token, {
      fields: "id,text,permalink,timestamp,media_url,thumbnail_url,media_type",
      limit: "10",
    });
    const items: InboxItem[] = [];
    const content: Content[] = [];
    // Replies cost one call per post: look at the newest few.
    for (const [i, p] of (posts.data ?? []).entries()) {
      content.push({
        id: await contentId(account.id, p.id),
        accountId: account.id,
        platform: "threads",
        remoteId: p.id,
        type: "thread",
        caption: p.text ?? "",
        url: p.permalink ?? null,
        thumbnail: p.thumbnail_url ?? p.media_url ?? null,
        at: iso(p.timestamp),
        likes: 0,
        comments: 0,
        views: null,
      });
      if (i >= 6) continue;
      const replies = await t(ctx, `/${p.id}/conversation`, s.token, {
        fields: "id,text,username,timestamp,permalink,is_reply_owned_by_me,replied_to",
        reverse: "false",
      });
      for (const r of replies.data ?? []) {
        if (r.is_reply_owned_by_me || r.username === account.handle) continue;
        items.push(
          inboxItem(account, {
            id: await itemId(account.id, r.id),
            kind: r.replied_to?.id && r.replied_to.id !== p.id ? "reply" : "comment",
            context: { type: "thread", id: p.id, title: clip(p.text, 80) || "Your thread", url: p.permalink ?? null, thumbnail: p.thumbnail_url ?? p.media_url ?? null },
            author: { id: "", name: r.username ?? "", handle: r.username ?? "", avatar: null },
            text: r.text ?? "",
            at: iso(r.timestamp),
            remoteId: r.id,
            parentRemoteId: r.replied_to?.id ?? p.id,
          }),
        );
      }
    }
    return { items, content, state: null };
  },

  async reply(ctx, account, item, text) {
    const s = await ctx.store.secretOf<ThreadsSecret>(account.id);
    return createAndPublish(ctx, s, { media_type: "TEXT", text, reply_to_id: item.remoteId }, undefined, async () => {}, () => {});
  },

  async snapshot(ctx, account) {
    const s = await ctx.store.secretOf<ThreadsSecret>(account.id);
    const until = Math.floor(ctx.now.getTime() / 1000);
    const r = await t(ctx, `/${s.userId}/threads_insights`, s.token, {
      metric: "followers_count,views",
      since: String(until - 28 * 86400),
      until: String(until),
    });
    const metric = (name: string) => r.data?.find((m: any) => m.name === name);
    const views = metric("views")?.values?.reduce((sum: number, v: any) => sum + (v.value ?? 0), 0) ?? null;
    return { followers: metric("followers_count")?.total_value?.value ?? null, posts: null, views28d: views };
  },

  async check(ctx, account) {
    const s = await ctx.store.secretOf<ThreadsSecret>(account.id);
    const me = await t(ctx, "/me", s.token, { fields: "id,username,name,threads_profile_picture_url" });
    return { ...account, name: me.name || me.username, handle: me.username, avatar: me.threads_profile_picture_url ?? account.avatar, expiresAt: s.expiresAt };
  },

  async refresh(ctx, account) {
    const s = await ctx.store.secretOf<ThreadsSecret>(account.id);
    // A token can be refreshed once it is at least a day old; renew when under 30 days remain.
    if (new Date(s.expiresAt).getTime() - ctx.now.getTime() > 30 * 86400_000) return;
    const r = await call(`https://graph.threads.net/refresh_access_token?${form({ grant_type: "th_refresh_token", access_token: s.token })}`, {
      budget: ctx.budget,
      label: "Threads",
    });
    const expiresAt = new Date(ctx.now.getTime() + (r.expires_in ?? 5184000) * 1000).toISOString();
    await ctx.store.updateAccount({ ...account, expiresAt }, { ...s, token: r.access_token, expiresAt } satisfies ThreadsSecret);
  },
};
