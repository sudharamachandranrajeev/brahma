// YouTube Data API v3 with Google OAuth (offline access, PKCE). Uploads
// stream from R2 through a resumable session, so a retry asks YouTube how far
// the last attempt got instead of uploading twice.

import { call, form, OutOfBudget, PlatformError, spend } from "../http.ts";
import type { Account, Content, InboxItem } from "../types.ts";
import { clip, contentId, inboxItem, iso, itemId, type Adapter, type Ctx, type OAuthFlow } from "./adapter.ts";

const api = "https://www.googleapis.com/youtube/v3";

export interface YouTubeSecret {
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
  channelId: string;
}

const scopes = [
  "https://www.googleapis.com/auth/youtube.upload",
  "https://www.googleapis.com/auth/youtube.force-ssl",
  "https://www.googleapis.com/auth/youtube.readonly",
];

export const googleOAuth: OAuthFlow = {
  pkce: true,
  authorizeUrl: ({ clientId, redirectUri, state, challenge }) => {
    const u = new URL("https://accounts.google.com/o/oauth2/v2/auth");
    u.search = form({
      client_id: clientId,
      redirect_uri: redirectUri,
      state,
      response_type: "code",
      scope: scopes.join(" "),
      access_type: "offline",
      prompt: "consent",
      code_challenge: challenge,
      code_challenge_method: "S256",
    }).toString();
    return u.toString();
  },
  async exchange(ctx, { clientId, clientSecret, redirectUri, code, verifier }) {
    const tok = await call("https://oauth2.googleapis.com/token", {
      method: "POST",
      label: "Google",
      body: form({ code, client_id: clientId, client_secret: clientSecret, redirect_uri: redirectUri, grant_type: "authorization_code", code_verifier: verifier }),
    });
    if (!tok.refresh_token) throw new PlatformError("Google gave no refresh token; remove the app's access at myaccount.google.com/permissions and connect again", 400, false, false);
    const ch = await call(`${api}/channels?part=snippet&mine=true`, { label: "YouTube", headers: { authorization: `Bearer ${tok.access_token}` } });
    const expiresAt = new Date(ctx.now.getTime() + tok.expires_in * 1000).toISOString();
    const now = ctx.now.toISOString();
    if (!ch.items?.length) throw new PlatformError("This Google account has no YouTube channel", 400, false, false);
    return ch.items.map((c: any) => ({
      account: {
        platform: "youtube" as const,
        name: c.snippet.title,
        handle: c.snippet.customUrl ?? c.snippet.title,
        avatar: c.snippet.thumbnails?.default?.url ?? null,
        remoteId: c.id,
        status: "ok" as const,
        statusMessage: null,
        expiresAt: null,
        capabilities: ["publish", "comments", "live", "insights"] as Account["capabilities"],
        connectedAt: now,
        checkedAt: now,
      },
      secret: { accessToken: tok.access_token, refreshToken: tok.refresh_token, expiresAt, channelId: c.id } satisfies YouTubeSecret,
    }));
  },
};

/** A usable access token, refreshed (and saved) when it is about to expire. */
async function accessToken(ctx: Ctx, account: Account): Promise<string> {
  const s = await ctx.store.secretOf<YouTubeSecret>(account.id);
  if (new Date(s.expiresAt).getTime() - ctx.now.getTime() > 120_000) return s.accessToken;
  const cred = await ctx.store.credential("google");
  if (!cred?.publicId) throw new PlatformError("Google client credentials are missing", 400, false, true);
  let tok: any;
  try {
    tok = await call("https://oauth2.googleapis.com/token", {
      method: "POST",
      budget: ctx.budget,
      label: "Google",
      body: form({ client_id: cred.publicId, client_secret: cred.secret, refresh_token: s.refreshToken, grant_type: "refresh_token" }),
    });
  } catch (err) {
    // invalid_grant = revoked, or the OAuth app is still in "Testing" (7-day refresh tokens).
    if (err instanceof PlatformError && err.status === 400) throw new PlatformError(err.message, 401, false, true);
    throw err;
  }
  const next: YouTubeSecret = { ...s, accessToken: tok.access_token, expiresAt: new Date(ctx.now.getTime() + tok.expires_in * 1000).toISOString() };
  await ctx.store.updateAccount(account, next);
  return next.accessToken;
}

export const yt = async <T = any>(ctx: Ctx, account: Account, path: string, init: RequestInit = {}) =>
  call<T>(api + path, {
    ...init,
    budget: ctx.budget,
    label: "YouTube",
    headers: { authorization: `Bearer ${await accessToken(ctx, account)}`, "content-type": "application/json", ...(init.headers ?? {}) },
  });

/** Sends the file (from [offset]) to a resumable upload session. */
async function sendFrom(ctx: Ctx, uploadUrl: string, token: string, key: string, size: number, type: string, offset: number) {
  const obj = await ctx.env.MEDIA.get(key, offset ? { range: { offset } } : undefined);
  if (!obj) throw new PlatformError("The video file is gone from storage", 400, false, false);
  const { readable, writable } = new FixedLengthStream(size - offset);
  obj.body.pipeTo(writable).catch(() => {});
  spend(ctx.budget);
  return fetch(uploadUrl, {
    method: "PUT",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": type,
      ...(offset ? { "content-range": `bytes ${offset}-${size - 1}/${size}` } : {}),
    },
    body: readable,
  });
}

/** Asks an upload session how much it has: done (the video), or the offset to resume from. */
async function sessionStatus(ctx: Ctx, uploadUrl: string, token: string, size: number): Promise<{ video?: any; offset?: number }> {
  spend(ctx.budget);
  const res = await fetch(uploadUrl, { method: "PUT", headers: { authorization: `Bearer ${token}`, "content-range": `bytes */${size}` } });
  if (res.status === 200 || res.status === 201) return { video: await res.json() };
  if (res.status === 308) {
    const range = res.headers.get("range");
    return { offset: range ? Number(range.split("-")[1]) + 1 : 0 };
  }
  // 404/410: the session expired; start again.
  return {};
}

export const youtube: Adapter = {
  async publish(ctx, account, { target, text, media, post }, progress) {
    const video = media.find((m) => m.contentType.startsWith("video/"));
    if (!video) throw new PlatformError("YouTube needs a video", 400, false, false);
    const token = await accessToken(ctx, account);
    let uploadUrl = target.containerId;
    let offset = 0;
    if (uploadUrl) {
      const st = await sessionStatus(ctx, uploadUrl, token, video.size);
      if (st.video) return { remoteId: st.video.id, permalink: `https://www.youtube.com/watch?v=${st.video.id}` };
      if (st.offset === undefined) uploadUrl = undefined;
      else offset = st.offset;
    }
    if (!uploadUrl) {
      let title = (target.title ?? clip(text, 100)) || video.filename;
      let description = text;
      if (target.format === "short" && !/#shorts/i.test(title + description)) description = `${description}\n\n#Shorts`.trim();
      title = title.slice(0, 100);
      spend(ctx.budget);
      const res = await fetch(`https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status`, {
        method: "POST",
        headers: {
          authorization: `Bearer ${token}`,
          "content-type": "application/json; charset=UTF-8",
          "x-upload-content-length": String(video.size),
          "x-upload-content-type": video.contentType,
        },
        body: JSON.stringify({
          snippet: { title, description, categoryId: "22", tags: post.tags.slice(0, 30) },
          status: { privacyStatus: "public", selfDeclaredMadeForKids: false },
        }),
      });
      const location = res.headers.get("location");
      if (!res.ok || !location) {
        const body = await res.text();
        throw new PlatformError(`YouTube: ${body.slice(0, 300) || res.status}`, res.status, res.status >= 500 || res.status === 429, res.status === 401, res.status === 403);
      }
      uploadUrl = location;
      await progress.saveContainer(uploadUrl);
    }
    let res: Response;
    try {
      res = await sendFrom(ctx, uploadUrl, token, video.key, video.size, video.contentType, offset);
    } catch (err) {
      if (err instanceof PlatformError || err instanceof OutOfBudget) throw err;
      throw new PlatformError(`YouTube upload interrupted: ${err instanceof Error ? err.message : err}`, 0, true, false);
    }
    if (!res.ok) {
      const body = await res.text();
      throw new PlatformError(`YouTube upload: ${body.slice(0, 300) || res.status}`, res.status, res.status >= 500 || res.status === 308 || res.status === 429, res.status === 401, res.status === 403);
    }
    const v = (await res.json()) as any;
    return { remoteId: v.id, permalink: `https://www.youtube.com/watch?v=${v.id}` };
  },

  async comment(ctx, account, remoteId, text) {
    await yt(ctx, account, "/commentThreads?part=snippet", {
      method: "POST",
      body: JSON.stringify({ snippet: { videoId: remoteId, topLevelComment: { snippet: { textOriginal: text } } } }),
    });
  },

  async poll(ctx, account) {
    const s = await ctx.store.secretOf<YouTubeSecret>(account.id);
    const ch = await yt(ctx, account, "/channels?part=contentDetails&mine=true");
    const uploads = ch.items?.[0]?.contentDetails?.relatedPlaylists?.uploads;
    const content: Content[] = [];
    const titles = new Map<string, { title: string; thumb: string | null; short: boolean }>();
    if (uploads) {
      const pl = await yt(ctx, account, `/playlistItems?part=contentDetails&maxResults=20&playlistId=${uploads}`);
      const ids = (pl.items ?? []).map((i: any) => i.contentDetails.videoId).join(",");
      if (ids) {
        const vids = await yt(ctx, account, `/videos?part=snippet,statistics,contentDetails&id=${ids}`);
        for (const v of vids.items ?? []) {
          const short = /#shorts/i.test(`${v.snippet.title} ${v.snippet.description}`) || /^PT(\d{1,2}S|[0-2]M(\d{1,2}S)?|3M)$/.test(v.contentDetails?.duration ?? "");
          const thumb = v.snippet.thumbnails?.high?.url ?? v.snippet.thumbnails?.default?.url ?? null;
          titles.set(v.id, { title: v.snippet.title, thumb, short });
          content.push({
            id: await contentId(account.id, v.id),
            accountId: account.id,
            platform: "youtube",
            remoteId: v.id,
            type: short ? "short" : "video",
            caption: v.snippet.title,
            url: short ? `https://www.youtube.com/shorts/${v.id}` : `https://www.youtube.com/watch?v=${v.id}`,
            thumbnail: thumb,
            at: iso(v.snippet.publishedAt),
            likes: Number(v.statistics?.likeCount ?? 0),
            comments: Number(v.statistics?.commentCount ?? 0),
            views: Number(v.statistics?.viewCount ?? 0),
          });
        }
      }
    }
    const items: InboxItem[] = [];
    const threads = await yt(ctx, account, `/commentThreads?part=snippet,replies&allThreadsRelatedToChannelId=${s.channelId}&maxResults=50&order=time`);
    for (const th of threads.items ?? []) {
      const top = th.snippet.topLevelComment;
      const videoId = th.snippet.videoId ?? top.snippet.videoId;
      const info = titles.get(videoId);
      const context = {
        type: info?.short ? ("short" as const) : ("video" as const),
        id: videoId,
        title: info?.title ?? "Your video",
        url: `https://www.youtube.com/watch?v=${videoId}`,
        thumbnail: info?.thumb ?? null,
      };
      const all = [{ c: top, parent: null as string | null }, ...(th.replies?.comments ?? []).map((r: any) => ({ c: r, parent: top.id }))];
      for (const { c, parent } of all) {
        if (c.snippet.authorChannelId?.value === s.channelId) continue;
        items.push(
          inboxItem(account, {
            id: await itemId(account.id, c.id),
            kind: parent ? "reply" : "comment",
            context,
            author: { id: c.snippet.authorChannelId?.value ?? "", name: c.snippet.authorDisplayName, handle: c.snippet.authorDisplayName, avatar: c.snippet.authorProfileImageUrl ?? null },
            text: c.snippet.textOriginal ?? c.snippet.textDisplay ?? "",
            at: iso(c.snippet.publishedAt),
            remoteId: c.id,
            parentRemoteId: parent,
            likes: c.snippet.likeCount,
          }),
        );
      }
    }
    // Live chat of a broadcast that is on air now.
    const live = await yt(ctx, account, "/liveBroadcasts?part=snippet&broadcastStatus=active&broadcastType=all&maxResults=5");
    for (const b of live.items ?? []) {
      const chatId = b.snippet.liveChatId;
      if (!chatId) continue;
      const chat = await yt(ctx, account, `/liveChat/messages?part=snippet,authorDetails&maxResults=200&liveChatId=${encodeURIComponent(chatId)}`);
      for (const m of chat.items ?? []) {
        if (m.authorDetails?.channelId === s.channelId || m.snippet.type !== "textMessageEvent") continue;
        items.push(
          inboxItem(account, {
            id: await itemId(account.id, m.id),
            kind: "live_chat",
            context: { type: "live", id: chatId, title: b.snippet.title, url: `https://www.youtube.com/watch?v=${b.id}`, thumbnail: b.snippet.thumbnails?.high?.url ?? null },
            author: { id: m.authorDetails.channelId, name: m.authorDetails.displayName, handle: m.authorDetails.displayName, avatar: m.authorDetails.profileImageUrl ?? null },
            text: m.snippet.displayMessage ?? "",
            at: iso(m.snippet.publishedAt),
            remoteId: m.id,
            parentRemoteId: null,
          }),
        );
      }
    }
    return { items, content, state: null };
  },

  async reply(ctx, account, item, text) {
    if (item.kind === "live_chat") {
      const r = await yt(ctx, account, "/liveChat/messages?part=snippet", {
        method: "POST",
        body: JSON.stringify({ snippet: { liveChatId: item.context.id, type: "textMessageEvent", textMessageDetails: { messageText: text } } }),
      });
      return r.id;
    }
    const r = await yt(ctx, account, "/comments?part=snippet", {
      method: "POST",
      body: JSON.stringify({ snippet: { parentId: item.parentRemoteId ?? item.remoteId, textOriginal: text } }),
    });
    return r.id;
  },

  // Held for review = hidden from the public until approved; YouTube only lets you delete your own comments.
  async moderate(ctx, account, item, action) {
    const status = action === "hide" ? "heldForReview" : "published";
    await yt(ctx, account, `/comments/setModerationStatus?id=${encodeURIComponent(item.remoteId)}&moderationStatus=${status}`, { method: "POST" });
  },

  async snapshot(ctx, account) {
    const r = await yt(ctx, account, "/channels?part=statistics&mine=true");
    const st = r.items?.[0]?.statistics;
    return {
      followers: st?.hiddenSubscriberCount ? null : Number(st?.subscriberCount ?? 0),
      posts: st ? Number(st.videoCount) : null,
      views28d: null,
    };
  },

  async check(ctx, account) {
    const r = await yt(ctx, account, "/channels?part=snippet&mine=true");
    const c = r.items?.[0];
    if (!c) throw new PlatformError("YouTube channel not found", 404, false, true);
    return { ...account, name: c.snippet.title, handle: c.snippet.customUrl ?? c.snippet.title, avatar: c.snippet.thumbnails?.default?.url ?? account.avatar };
  },
};
