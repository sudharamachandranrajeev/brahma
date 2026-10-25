// Facebook Pages and Instagram professional accounts through the Graph API
// (Facebook Login). One Meta sign-in brings every Page the user manages and
// the Instagram account linked to each.

import { call, form, PlatformError, wait } from "../http.ts";
import type { Account, Content, ContextType, InboxItem } from "../types.ts";
import {
  clip,
  contentId,
  inboxItem,
  isVideo,
  iso,
  itemId,
  type Adapter,
  type Connected,
  type Ctx,
  type MediaFile,
  type OAuthFlow,
  type PollResult,
} from "./adapter.ts";

export const graphVersion = "v24.0";
const graph = `https://graph.facebook.com/${graphVersion}`;
const graphVideo = `https://graph-video.facebook.com/${graphVersion}`;

export interface MetaSecret {
  /** Page access token (from a long-lived user token, so it does not expire on a timer). */
  pageToken: string;
  pageId: string;
}

const scopes = [
  "pages_show_list",
  "pages_read_engagement",
  "pages_read_user_content",
  "pages_manage_posts",
  "pages_manage_engagement",
  "pages_messaging",
  "read_insights",
  "business_management",
  "instagram_basic",
  "instagram_content_publish",
  "instagram_manage_comments",
  "instagram_manage_insights",
  "instagram_manage_messages",
];

export const g = <T = any>(ctx: Ctx, path: string, token: string, params: Record<string, string> = {}) => {
  const url = new URL(path.startsWith("http") ? path : graph + path);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
  url.searchParams.set("access_token", token);
  return call<T>(url, { budget: ctx.budget, label: "Meta" });
};

const gPost = <T = any>(ctx: Ctx, path: string, token: string, data: Record<string, any>, base = graph) =>
  call<T>(base + path, {
    method: "POST",
    budget: ctx.budget,
    label: "Meta",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ ...data, access_token: token }),
  });

/** Data-access expiry (Meta asks people to re-approve apps every 90 days). */
async function dataAccessExpiry(ctx: Ctx, token: string): Promise<string | null> {
  const cred = await ctx.store.credential("meta");
  if (!cred?.publicId) return null;
  try {
    const r = await g(ctx, "/debug_token", `${cred.publicId}|${cred.secret}`, { input_token: token });
    const t = r?.data?.data_access_expires_at;
    return typeof t === "number" && t > 0 ? new Date(t * 1000).toISOString() : null;
  } catch {
    return null;
  }
}

export const metaOAuth: OAuthFlow = {
  authorizeUrl: ({ clientId, redirectUri, state }) => {
    const u = new URL(`https://www.facebook.com/${graphVersion}/dialog/oauth`);
    u.search = form({ client_id: clientId, redirect_uri: redirectUri, state, response_type: "code", scope: scopes.join(",") }).toString();
    return u.toString();
  },
  async exchange(ctx, { clientId, clientSecret, redirectUri, code }) {
    const short = await call(`${graph}/oauth/access_token?${form({ client_id: clientId, client_secret: clientSecret, redirect_uri: redirectUri, code })}`, { label: "Meta" });
    const long = await call(
      `${graph}/oauth/access_token?${form({ grant_type: "fb_exchange_token", client_id: clientId, client_secret: clientSecret, fb_exchange_token: short.access_token })}`,
      { label: "Meta" },
    );
    const pages = await g(ctx, "/me/accounts", long.access_token, {
      fields: "id,name,username,access_token,picture{url},instagram_business_account{id,username,name,profile_picture_url}",
      limit: "100",
    });
    const expiresAt = await dataAccessExpiry(ctx, long.access_token);
    const now = ctx.now.toISOString();
    const out: Connected[] = [];
    for (const p of pages.data ?? []) {
      const secret: MetaSecret = { pageToken: p.access_token, pageId: p.id };
      out.push({
        account: {
          platform: "facebook",
          name: p.name,
          handle: p.username ?? p.name,
          avatar: p.picture?.data?.url ?? null,
          remoteId: p.id,
          status: "ok",
          statusMessage: null,
          expiresAt,
          capabilities: ["publish", "comments", "messages", "insights", "private_reply"],
          connectedAt: now,
          checkedAt: now,
        },
        secret,
      });
      const ig = p.instagram_business_account;
      if (ig) {
        out.push({
          account: {
            platform: "instagram",
            name: ig.name ?? ig.username,
            handle: ig.username,
            avatar: ig.profile_picture_url ?? null,
            remoteId: ig.id,
            status: "ok",
            statusMessage: null,
            expiresAt,
            capabilities: ["publish", "comments", "messages", "mentions", "live", "insights", "private_reply"],
            connectedAt: now,
            checkedAt: now,
          },
          secret,
        });
      }
    }
    if (!out.length) {
      throw new PlatformError(
        "Meta: no Facebook Pages came back. Pick at least one Page in the sign-in dialog (Instagram must be a Business or Creator account linked to a Page).",
        400,
        false,
        false,
      );
    }
    return out;
  },
};

// ---- publishing ----

/** Waits for an Instagram container to finish processing; throws a retryable error if it is still going. */
async function waitForContainer(ctx: Ctx, id: string, token: string, maxSeconds = 40) {
  const started = Date.now();
  for (;;) {
    const r = await g(ctx, `/${id}`, token, { fields: "status_code,status" });
    if (r.status_code === "FINISHED" || r.status_code === "PUBLISHED") return;
    if (r.status_code === "ERROR" || r.status_code === "EXPIRED") {
      throw new PlatformError(`Instagram could not process the media: ${r.status ?? r.status_code}`, 400, false, false);
    }
    if (Date.now() - started > maxSeconds * 1000) {
      throw new PlatformError("Instagram is still processing the video; will try again", 503, true, false);
    }
    await wait(4000);
  }
}

const alt = (m: MediaFile) => (m.alt ? { alt_text: m.alt } : {});
const fbAlt = (m: MediaFile) => (m.alt ? { alt_text_custom: m.alt } : {});

const igPublish: Adapter["publish"] = async (ctx, account, { target, text, media }, progress) => {
  const { pageToken: token } = await ctx.store.secretOf<MetaSecret>(account.id);
  const ig = account.remoteId;
  let creation = target.containerId;
  if (!creation) {
    const one = media[0];
    if (!one) throw new PlatformError("Instagram needs at least one photo or video", 400, false, false);
    let body: Record<string, any>;
    if (target.format === "carousel" && media.length > 1) {
      const children: string[] = [];
      for (const m of media) {
        const child = await gPost(ctx, `/${ig}/media`, token, isVideo(m)
          ? { media_type: "VIDEO", video_url: m.url, is_carousel_item: true }
          : { image_url: m.url, is_carousel_item: true, ...alt(m) });
        children.push(child.id);
      }
      for (const [i, m] of media.entries()) if (isVideo(m)) await waitForContainer(ctx, children[i], token);
      body = { media_type: "CAROUSEL", children: children.join(","), caption: text };
    } else if (target.format === "story") {
      body = isVideo(one) ? { media_type: "STORIES", video_url: one.url } : { media_type: "STORIES", image_url: one.url };
    } else if (target.format === "reel" || isVideo(one)) {
      body = { media_type: "REELS", video_url: one.url, caption: text, share_to_feed: true };
    } else {
      body = { image_url: one.url, caption: text, ...alt(one) };
    }
    creation = (await gPost(ctx, `/${ig}/media`, token, body)).id as string;
    await progress.saveContainer(creation);
  }
  await waitForContainer(ctx, creation, token);
  progress.commit();
  const published = await gPost(ctx, `/${ig}/media_publish`, token, { creation_id: creation });
  let permalink: string | null = null;
  try {
    permalink = (await g(ctx, `/${published.id}`, token, { fields: "permalink" })).permalink ?? null;
  } catch {
    // The post is up; the link is a nicety.
  }
  return { remoteId: published.id, permalink };
};

const fbPublish: Adapter["publish"] = async (ctx, account, { target, text, media }, progress) => {
  const { pageToken: token } = await ctx.store.secretOf<MetaSecret>(account.id);
  const page = account.remoteId;
  let id: string;
  const video = media.find(isVideo);
  if (target.format === "video" || video) {
    if (!video) throw new PlatformError("A Facebook video post needs a video", 400, false, false);
    progress.commit();
    id = (await gPost(ctx, `/${page}/videos`, token, { file_url: video.url, description: text, title: target.title }, graphVideo)).id;
  } else if (media.length === 1) {
    progress.commit();
    const r = await gPost(ctx, `/${page}/photos`, token, { url: media[0].url, caption: text, ...fbAlt(media[0]) });
    id = r.post_id ?? r.id;
  } else if (media.length > 1) {
    const ids: string[] = [];
    for (const m of media) ids.push((await gPost(ctx, `/${page}/photos`, token, { url: m.url, published: false, ...fbAlt(m) })).id);
    progress.commit();
    id = (await gPost(ctx, `/${page}/feed`, token, { message: text, attached_media: ids.map((media_fbid) => ({ media_fbid })) })).id;
  } else {
    progress.commit();
    id = (await gPost(ctx, `/${page}/feed`, token, { message: text })).id;
  }
  let permalink: string | null = null;
  try {
    permalink = (await g(ctx, `/${id}`, token, { fields: "permalink_url" })).permalink_url ?? null;
  } catch {
    // Video ids have no permalink_url until processed.
  }
  return { remoteId: id, permalink };
};

// ---- inbox ----

const igType = (m: any): ContextType =>
  m.media_product_type === "REELS" ? "reel" : m.media_product_type === "STORY" ? "story" : m.media_product_type === "LIVE" ? "live" : "post";

/** Runs an optional part of a poll; a missing permission skips it instead of failing the account. */
async function optional<T>(skipped: string[], name: string, fn: () => Promise<T>): Promise<T | null> {
  try {
    return await fn();
  } catch (err) {
    if (err instanceof PlatformError && err.permission) {
      skipped.push(name);
      return null;
    }
    throw err;
  }
}

async function messages(ctx: Ctx, account: Account, token: string, pageId: string, platform: "instagram" | "facebook", selfId: string) {
  const r = await g(ctx, `/${pageId}/conversations`, token, {
    ...(platform === "instagram" ? { platform: "instagram" } : {}),
    fields: "id,updated_time,messages.limit(10){id,message,from,created_time,story}",
    limit: "15",
  });
  const items: InboxItem[] = [];
  for (const conv of r.data ?? []) {
    for (const m of conv.messages?.data ?? []) {
      if (!m.message && !m.story) continue;
      if (m.from?.id === selfId || m.from?.id === pageId) continue;
      const storyReply = !!m.story?.reply_to;
      items.push(
        inboxItem(account, {
          id: await itemId(account.id, m.id),
          kind: "message",
          context: {
            type: storyReply ? "story" : "dm",
            id: conv.id,
            title: storyReply ? "Reply to your story" : m.story?.mention ? "Mentioned you in their story" : "Direct message",
            url: m.story?.reply_to?.link ?? m.story?.mention?.link ?? null,
            thumbnail: null,
          },
          author: { id: m.from?.id ?? "", name: m.from?.name ?? m.from?.username ?? "", handle: m.from?.username ?? m.from?.name ?? "", avatar: null },
          text: m.message ?? (m.story?.mention ? "(story mention)" : ""),
          at: iso(m.created_time),
          remoteId: m.id,
          parentRemoteId: m.from?.id ?? null,
        }),
      );
    }
  }
  return items;
}

const igPoll: Adapter["poll"] = async (ctx, account) => {
  const { pageToken: token, pageId } = await ctx.store.secretOf<MetaSecret>(account.id);
  const ig = account.remoteId;
  const skipped: string[] = [];
  const commentFields = "id,text,username,from,timestamp,like_count,replies{id,text,username,from,timestamp}";
  const media = await g(ctx, `/${ig}/media`, token, {
    fields: `id,caption,media_type,media_product_type,permalink,thumbnail_url,media_url,timestamp,like_count,comments_count,comments.limit(50){${commentFields}}`,
    limit: "20",
  });
  const items: InboxItem[] = [];
  const content: Content[] = [];
  const addComments = async (m: any, type: ContextType) => {
    const ctxInfo = { type, id: m.id, title: clip(m.caption, 80) || (type === "live" ? "Live video" : "Your post"), url: m.permalink ?? null, thumbnail: m.thumbnail_url ?? m.media_url ?? null };
    for (const c of m.comments?.data ?? []) {
      const all = [{ c, parent: null as string | null }, ...(c.replies?.data ?? []).map((r: any) => ({ c: r, parent: c.id }))];
      for (const { c: x, parent } of all) {
        if (x.username === account.handle) continue;
        items.push(
          inboxItem(account, {
            id: await itemId(account.id, x.id),
            kind: type === "live" ? "live_chat" : parent ? "reply" : "comment",
            context: ctxInfo,
            author: { id: x.from?.id ?? "", name: x.username ?? "", handle: x.username ?? "", avatar: null },
            text: x.text ?? "",
            at: iso(x.timestamp),
            remoteId: x.id,
            parentRemoteId: parent,
            likes: x.like_count,
          }),
        );
      }
    }
  };
  for (const m of media.data ?? []) {
    const type = igType(m);
    await addComments(m, type);
    content.push({
      id: await contentId(account.id, m.id),
      accountId: account.id,
      platform: "instagram",
      remoteId: m.id,
      type,
      caption: m.caption ?? "",
      url: m.permalink ?? null,
      thumbnail: m.thumbnail_url ?? m.media_url ?? null,
      at: iso(m.timestamp),
      likes: m.like_count ?? 0,
      comments: m.comments_count ?? 0,
      views: null,
    });
  }
  // Comments on a live broadcast exist only while it is live.
  const live = await optional(skipped, "live", () =>
    g(ctx, `/${ig}/live_media`, token, { fields: `id,media_product_type,timestamp,comments{${commentFields}}` }),
  );
  for (const m of live?.data ?? []) await addComments(m, "live");
  const tags = await optional(skipped, "mentions", () =>
    g(ctx, `/${ig}/tags`, token, { fields: "id,caption,username,permalink,timestamp,media_url,thumbnail_url", limit: "15" }),
  );
  for (const t of tags?.data ?? []) {
    items.push(
      inboxItem(account, {
        id: await itemId(account.id, `tag:${t.id}`),
        kind: "mention",
        context: { type: "post", id: t.id, title: "Tagged you in a post", url: t.permalink ?? null, thumbnail: t.thumbnail_url ?? t.media_url ?? null },
        author: { id: "", name: t.username ?? "", handle: t.username ?? "", avatar: null },
        text: t.caption ?? "",
        at: iso(t.timestamp),
        remoteId: t.id,
        parentRemoteId: null,
      }),
    );
  }
  const dms = await optional(skipped, "messages", () => messages(ctx, account, token, pageId, "instagram", ig));
  if (dms) items.push(...dms);
  return { items, content, state: null, skipped } satisfies PollResult;
};

const fbPoll: Adapter["poll"] = async (ctx, account) => {
  const { pageToken: token } = await ctx.store.secretOf<MetaSecret>(account.id);
  const page = account.remoteId;
  const skipped: string[] = [];
  const posts = await g(ctx, `/${page}/published_posts`, token, {
    fields:
      "id,message,permalink_url,created_time,full_picture,reactions.summary(total_count).limit(0)," +
      "comments.summary(true).limit(50).order(reverse_chronological){id,message,from,created_time,like_count,comments{id,message,from,created_time}}",
    limit: "20",
  });
  const items: InboxItem[] = [];
  const content: Content[] = [];
  for (const p of posts.data ?? []) {
    const context = { type: "post" as const, id: p.id, title: clip(p.message, 80) || "Your post", url: p.permalink_url ?? null, thumbnail: p.full_picture ?? null };
    for (const c of p.comments?.data ?? []) {
      for (const { c: x, parent } of [{ c, parent: null as string | null }, ...(c.comments?.data ?? []).map((r: any) => ({ c: r, parent: c.id }))]) {
        if (x.from?.id === page) continue;
        items.push(
          inboxItem(account, {
            id: await itemId(account.id, x.id),
            kind: parent ? "reply" : "comment",
            context,
            author: { id: x.from?.id ?? "", name: x.from?.name ?? "Someone", handle: x.from?.name ?? "", avatar: null },
            text: x.message ?? "",
            at: iso(x.created_time),
            remoteId: x.id,
            parentRemoteId: parent,
            likes: x.like_count,
          }),
        );
      }
    }
    content.push({
      id: await contentId(account.id, p.id),
      accountId: account.id,
      platform: "facebook",
      remoteId: p.id,
      type: "post",
      caption: p.message ?? "",
      url: p.permalink_url ?? null,
      thumbnail: p.full_picture ?? null,
      at: iso(p.created_time),
      likes: p.reactions?.summary?.total_count ?? 0,
      comments: p.comments?.summary?.total_count ?? 0,
      views: null,
    });
  }
  const dms = await optional(skipped, "messages", () => messages(ctx, account, token, page, "facebook", page));
  if (dms) items.push(...dms);
  return { items, content, state: null, skipped };
};

/** Replies in public, or privately (Messenger / Instagram DM) to a comment or message. */
async function metaReply(ctx: Ctx, account: Account, item: InboxItem, text: string, privately: boolean): Promise<string> {
  const { pageToken: token, pageId } = await ctx.store.secretOf<MetaSecret>(account.id);
  if (item.kind === "message") {
    const r = await gPost(ctx, `/${pageId}/messages`, token, {
      recipient: { id: item.author.id },
      messaging_type: "RESPONSE",
      message: { text },
    });
    return r.message_id;
  }
  if (privately) {
    const r = await gPost(ctx, `/${pageId}/messages`, token, { recipient: { comment_id: item.remoteId }, message: { text } });
    return r.message_id;
  }
  if (item.kind === "mention") throw new PlatformError("Mentions can't be replied to from here; open the post", 400, false, false);
  // Instagram replies attach to the top-level comment; Facebook allows replying to replies.
  if (account.platform === "instagram") {
    return (await gPost(ctx, `/${item.parentRemoteId ?? item.remoteId}/replies`, token, { message: text })).id;
  }
  return (await gPost(ctx, `/${item.remoteId}/comments`, token, { message: text })).id;
}

/** Instagram comments hide with `hide`, Facebook ones with `is_hidden`; both delete with DELETE. */
const metaModerate: Adapter["moderate"] = async (ctx, account, item, action) => {
  const { pageToken: token } = await ctx.store.secretOf<MetaSecret>(account.id);
  if (action === "delete") {
    await call(`${graph}/${item.remoteId}?${form({ access_token: token })}`, { method: "DELETE", budget: ctx.budget, label: "Meta" });
    return;
  }
  await gPost(ctx, `/${item.remoteId}`, token, account.platform === "instagram" ? { hide: action === "hide" } : { is_hidden: action === "hide" });
};

async function metaCheck(ctx: Ctx, account: Account): Promise<Account> {
  const { pageToken: token } = await ctx.store.secretOf<MetaSecret>(account.id);
  const fields = account.platform === "instagram" ? "username,name,profile_picture_url" : "name,username,picture{url}";
  const me = await g(ctx, `/${account.remoteId}`, token, { fields });
  const expiresAt = (await dataAccessExpiry(ctx, token)) ?? account.expiresAt;
  return {
    ...account,
    name: me.name ?? me.username ?? account.name,
    handle: me.username ?? account.handle,
    avatar: me.profile_picture_url ?? me.picture?.data?.url ?? account.avatar,
    expiresAt,
  };
}

export const instagram: Adapter = {
  publish: igPublish,
  async comment(ctx, account, remoteId, text) {
    const { pageToken } = await ctx.store.secretOf<MetaSecret>(account.id);
    await gPost(ctx, `/${remoteId}/comments`, pageToken, { message: text });
  },
  poll: igPoll,
  reply: metaReply,
  moderate: metaModerate,
  async snapshot(ctx, account) {
    const { pageToken: token } = await ctx.store.secretOf<MetaSecret>(account.id);
    const me = await g(ctx, `/${account.remoteId}`, token, { fields: "followers_count,media_count" });
    let views28d: number | null = null;
    try {
      const until = Math.floor(ctx.now.getTime() / 1000);
      const r = await g(ctx, `/${account.remoteId}/insights`, token, {
        metric: "views",
        metric_type: "total_value",
        period: "day",
        since: String(until - 28 * 86400),
        until: String(until),
      });
      views28d = r.data?.[0]?.total_value?.value ?? null;
    } catch {
      // Insights need instagram_manage_insights and enough followers; numbers above still count.
    }
    return { followers: me.followers_count ?? null, posts: me.media_count ?? null, views28d };
  },
  check: metaCheck,
};

export const facebook: Adapter = {
  publish: fbPublish,
  async comment(ctx, account, remoteId, text) {
    const { pageToken } = await ctx.store.secretOf<MetaSecret>(account.id);
    await gPost(ctx, `/${remoteId}/comments`, pageToken, { message: text });
  },
  poll: fbPoll,
  reply: metaReply,
  moderate: metaModerate,
  async snapshot(ctx, account) {
    const { pageToken: token } = await ctx.store.secretOf<MetaSecret>(account.id);
    const me = await g(ctx, `/${account.remoteId}`, token, { fields: "followers_count,fan_count" });
    return { followers: me.followers_count ?? me.fan_count ?? null, posts: null, views28d: null };
  },
  check: metaCheck,
};

