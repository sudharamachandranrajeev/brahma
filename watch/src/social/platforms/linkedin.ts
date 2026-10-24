// LinkedIn: "Sign In with LinkedIn using OpenID Connect" + "Share on LinkedIn"
// (self-serve) post to the member's profile. Reading comments needs
// r_member_social from the Community Management API, which LinkedIn grants
// per app; without it the inbox part is skipped, not failed.

import { call, form, PlatformError, spend } from "../http.ts";
import type { InboxItem } from "../types.ts";
import { clip, inboxItem, isVideo, iso, itemId, type Adapter, type Ctx, type MediaFile, type OAuthFlow } from "./adapter.ts";

/** LinkedIn's versioned REST API (YYYYMM); each version is served for at least a year. */
export const linkedinVersion = "202606";
const rest = "https://api.linkedin.com/rest";

export interface LinkedInSecret {
  token: string;
  expiresAt: string;
  urn: string;
}

export const linkedinOAuth: OAuthFlow = {
  authorizeUrl: ({ clientId, redirectUri, state }) => {
    const u = new URL("https://www.linkedin.com/oauth/v2/authorization");
    u.search = form({ response_type: "code", client_id: clientId, redirect_uri: redirectUri, state, scope: "openid profile email w_member_social" }).toString();
    return u.toString();
  },
  async exchange(ctx, { clientId, clientSecret, redirectUri, code }) {
    const tok = await call("https://www.linkedin.com/oauth/v2/accessToken", {
      method: "POST",
      label: "LinkedIn",
      body: form({ grant_type: "authorization_code", code, redirect_uri: redirectUri, client_id: clientId, client_secret: clientSecret }),
    });
    const me = await call("https://api.linkedin.com/v2/userinfo", { label: "LinkedIn", headers: { authorization: `Bearer ${tok.access_token}` } });
    const expiresAt = new Date(ctx.now.getTime() + tok.expires_in * 1000).toISOString();
    const now = ctx.now.toISOString();
    return [
      {
        account: {
          platform: "linkedin",
          name: me.name,
          handle: me.email ?? me.name,
          avatar: me.picture ?? null,
          remoteId: me.sub,
          status: "ok",
          statusMessage: null,
          expiresAt,
          capabilities: ["publish", "comments"],
          connectedAt: now,
          checkedAt: now,
        },
        secret: { token: tok.access_token, expiresAt, urn: `urn:li:person:${me.sub}` } satisfies LinkedInSecret,
      },
    ];
  },
};

const headers = (token: string) => ({
  authorization: `Bearer ${token}`,
  "linkedin-version": linkedinVersion,
  "x-restli-protocol-version": "2.0.0",
  "content-type": "application/json",
});

/**
 * Commentary uses LinkedIn's "little text" format: reserved characters need
 * a backslash or the text is cut short. #words become hashtags.
 */
export function littleText(text: string): string {
  return text
    .split(/(#[\p{L}\p{N}_]+)/u)
    .map((part) =>
      /^#[\p{L}\p{N}_]+$/u.test(part)
        ? `{hashtag|\\#|${part.slice(1)}}`
        : part.replace(/[\\|{}@[\]()<>#*_~]/g, (c) => `\\${c}`),
    )
    .join("");
}

async function putBytes(ctx: Ctx, url: string, token: string, m: MediaFile, range?: { first: number; last: number }) {
  const obj = await ctx.env.MEDIA.get(m.key, range ? { range: { offset: range.first, length: range.last - range.first + 1 } } : undefined);
  if (!obj) throw new PlatformError("The media file is gone from storage", 400, false, false);
  spend(ctx.budget);
  const res = await fetch(url, { method: "PUT", headers: { authorization: `Bearer ${token}`, "content-type": "application/octet-stream" }, body: await obj.arrayBuffer() });
  if (!res.ok) throw new PlatformError(`LinkedIn upload: ${res.status} ${await res.text()}`, res.status, res.status >= 500, res.status === 401);
  return res.headers.get("etag") ?? "";
}

async function uploadImage(ctx: Ctx, s: LinkedInSecret, m: MediaFile): Promise<string> {
  const init = await call(`${rest}/images?action=initializeUpload`, {
    method: "POST",
    budget: ctx.budget,
    label: "LinkedIn",
    headers: headers(s.token),
    body: JSON.stringify({ initializeUploadRequest: { owner: s.urn } }),
  });
  await putBytes(ctx, init.value.uploadUrl, s.token, m);
  return init.value.image;
}

async function uploadVideo(ctx: Ctx, s: LinkedInSecret, m: MediaFile): Promise<string> {
  const init = await call(`${rest}/videos?action=initializeUpload`, {
    method: "POST",
    budget: ctx.budget,
    label: "LinkedIn",
    headers: headers(s.token),
    body: JSON.stringify({ initializeUploadRequest: { owner: s.urn, fileSizeBytes: m.size, uploadCaptions: false, uploadThumbnail: false } }),
  });
  const etags: string[] = [];
  for (const part of init.value.uploadInstructions) {
    etags.push(await putBytes(ctx, part.uploadUrl, s.token, m, { first: part.firstByte, last: part.lastByte }));
  }
  await call(`${rest}/videos?action=finalizeUpload`, {
    method: "POST",
    budget: ctx.budget,
    label: "LinkedIn",
    headers: headers(s.token),
    body: JSON.stringify({ finalizeUploadRequest: { video: init.value.video, uploadToken: init.value.uploadToken ?? "", uploadedPartIds: etags } }),
  });
  return init.value.video;
}

export const linkedin: Adapter = {
  async publish(ctx, account, { text, media }, progress) {
    const s = await ctx.store.secretOf<LinkedInSecret>(account.id);
    let content: object | undefined;
    const video = media.find(isVideo);
    if (video) content = { media: { id: await uploadVideo(ctx, s, video) } };
    else if (media.length === 1) content = { media: { id: await uploadImage(ctx, s, media[0]) } };
    else if (media.length > 1) {
      const images = [];
      for (const m of media) images.push({ id: await uploadImage(ctx, s, m) });
      content = { multiImage: { images } };
    }
    progress.commit();
    spend(ctx.budget);
    const res = await fetch(`${rest}/posts`, {
      method: "POST",
      headers: headers(s.token),
      body: JSON.stringify({
        author: s.urn,
        commentary: littleText(text),
        visibility: "PUBLIC",
        distribution: { feedDistribution: "MAIN_FEED", targetEntities: [], thirdPartyDistributionChannels: [] },
        lifecycleState: "PUBLISHED",
        isReshareDisabledByAuthor: false,
        ...(content ? { content } : {}),
      }),
    });
    if (!res.ok) {
      throw new PlatformError(`LinkedIn: ${(await res.text()).slice(0, 300)}`, res.status, res.status >= 500 || res.status === 429, res.status === 401, res.status === 403);
    }
    const urn = res.headers.get("x-restli-id") ?? "";
    return { remoteId: urn, permalink: urn ? `https://www.linkedin.com/feed/update/${urn}/` : null };
  },

  async comment(ctx, account, remoteId, text) {
    const s = await ctx.store.secretOf<LinkedInSecret>(account.id);
    await call(`${rest}/socialActions/${encodeURIComponent(remoteId)}/comments`, {
      method: "POST",
      budget: ctx.budget,
      label: "LinkedIn",
      headers: headers(s.token),
      body: JSON.stringify({ actor: s.urn, object: remoteId, message: { text } }),
    });
  },

  /** Comments on posts published from Vani in the last 30 days (LinkedIn has no "my posts" feed for self-serve apps). */
  async poll(ctx, account) {
    const s = await ctx.store.secretOf<LinkedInSecret>(account.id);
    const since = new Date(ctx.now.getTime() - 30 * 86400_000).toISOString();
    const mine = (await ctx.store.posts({ status: "published", from: since }))
      .flatMap((p) => p.targets.filter((t) => t.accountId === account.id && t.remoteId).map((t) => ({ post: p, urn: t.remoteId!, url: t.permalink ?? null })))
      .slice(0, 6);
    const items: InboxItem[] = [];
    for (const { post, urn, url } of mine) {
      let r: any;
      try {
        r = await call(`${rest}/socialActions/${encodeURIComponent(urn)}/comments?count=50`, { budget: ctx.budget, label: "LinkedIn", headers: headers(s.token) });
      } catch (err) {
        if (err instanceof PlatformError && err.permission) return { items, content: [], state: null, skipped: ["comments"] };
        throw err;
      }
      for (const c of r.elements ?? []) {
        if (c.actor === s.urn) continue;
        items.push(
          inboxItem(account, {
            id: await itemId(account.id, c.$URN ?? c.commentUrn ?? c.id),
            kind: c.parentComment ? "reply" : "comment",
            context: { type: "post", id: urn, title: clip(post.text, 80) || "Your post", url, thumbnail: null },
            author: { id: c.actor ?? "", name: c.actor ?? "LinkedIn member", handle: "", avatar: null },
            text: c.message?.text ?? "",
            at: iso(c.created?.time),
            remoteId: c.$URN ?? c.commentUrn ?? c.id,
            parentRemoteId: urn,
          }),
        );
      }
    }
    return { items, content: [], state: null };
  },

  async reply(ctx, account, item, text) {
    const s = await ctx.store.secretOf<LinkedInSecret>(account.id);
    const post = item.parentRemoteId ?? item.context.id;
    spend(ctx.budget);
    const res = await fetch(`${rest}/socialActions/${encodeURIComponent(post)}/comments`, {
      method: "POST",
      headers: headers(s.token),
      body: JSON.stringify({ actor: s.urn, object: post, message: { text }, parentComment: item.remoteId }),
    });
    if (!res.ok) throw new PlatformError(`LinkedIn: ${(await res.text()).slice(0, 300)}`, res.status, res.status >= 500, res.status === 401, res.status === 403);
    return res.headers.get("x-restli-id") ?? "";
  },

  async snapshot() {
    // Member follower counts need partner-only analytics scopes.
    return { followers: null, posts: null, views28d: null };
  },

  async check(ctx, account) {
    const s = await ctx.store.secretOf<LinkedInSecret>(account.id);
    const me = await call("https://api.linkedin.com/v2/userinfo", { budget: ctx.budget, label: "LinkedIn", headers: { authorization: `Bearer ${s.token}` } });
    return { ...account, name: me.name, avatar: me.picture ?? account.avatar, expiresAt: s.expiresAt };
  },
};
