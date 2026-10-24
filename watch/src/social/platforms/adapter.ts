import { hashId } from "../crypto.ts";
import type { Budget } from "../http.ts";
import type { SocialEnv, Store } from "../store.ts";
import type { Account, Content, InboxItem, Platform, PlatformInfo, Post, Provider, Target } from "../types.ts";

/** What every platform call gets: storage, secrets and this run's subrequest budget. */
export interface Ctx {
  env: SocialEnv;
  store: Store;
  budget: Budget;
  now: Date;
}

/** A media file ready for a platform: a signed URL it can fetch, or the R2 object to stream. */
export interface MediaFile {
  id: string;
  url: string;
  key: string;
  contentType: string;
  size: number;
  filename: string;
}

export const isVideo = (m: MediaFile) => m.contentType.startsWith("video/");

export interface PublishInput {
  post: Post;
  target: Target;
  text: string;
  media: MediaFile[];
}

/** Lets an adapter record progress, so a retry neither repeats nor double-posts. */
export interface PublishProgress {
  /** Keeps a platform container (Instagram, Threads) so a retry reuses it. */
  saveContainer(id: string): Promise<void>;
  /** Called right before the call that makes the post public. A failure after it may have posted. */
  commit(): void;
}

export interface PublishResult {
  remoteId: string;
  permalink: string | null;
}

export interface PollResult {
  items: InboxItem[];
  content: Content[];
  state: unknown;
  /** Parts skipped because the token lacks permission (e.g. "messages"). */
  skipped?: string[];
}

export interface Snapshot {
  followers: number | null;
  posts: number | null;
  views28d: number | null;
}

export interface Adapter {
  publish(ctx: Ctx, account: Account, input: PublishInput, progress: PublishProgress): Promise<PublishResult>;
  /** Adds a comment under a just-published post. */
  comment?(ctx: Ctx, account: Account, remoteId: string, text: string): Promise<void>;
  poll(ctx: Ctx, account: Account, state: any): Promise<PollResult>;
  /** Replies to an inbox item; returns the reply's remote id. */
  reply(ctx: Ctx, account: Account, item: InboxItem, text: string, privately: boolean): Promise<string>;
  snapshot(ctx: Ctx, account: Account): Promise<Snapshot>;
  /** Re-reads the profile and token health; returns the updated account (not yet saved). */
  check(ctx: Ctx, account: Account): Promise<Account>;
  /** Renews tokens that expire; called daily. */
  refresh?(ctx: Ctx, account: Account): Promise<void>;
}

/** A connected identity from an OAuth callback, ready to store. */
export interface Connected {
  account: Omit<Account, "id">;
  secret: unknown;
}

export interface OAuthFlow {
  /** Needs PKCE (the verifier is kept with the state). */
  pkce?: boolean;
  authorizeUrl(a: { clientId: string; redirectUri: string; state: string; challenge?: string }): string;
  exchange(
    ctx: Ctx,
    a: { clientId: string; clientSecret: string; redirectUri: string; code: string; verifier?: string },
  ): Promise<Connected[]>;
}

export const platformInfo: Record<Platform, PlatformInfo> = {
  instagram: { name: "Instagram", maxText: 2200, formats: ["post", "carousel", "reel", "story"], mediaRequired: ["post", "carousel", "reel", "story"], maxMedia: 10 },
  facebook: { name: "Facebook Page", maxText: 63206, formats: ["post", "video"], mediaRequired: ["video"], maxMedia: 10 },
  youtube: { name: "YouTube", maxText: 5000, formats: ["video", "short"], mediaRequired: ["video", "short"], maxMedia: 1 },
  linkedin: { name: "LinkedIn", maxText: 3000, formats: ["post", "video"], mediaRequired: ["video"], maxMedia: 9 },
  threads: { name: "Threads", maxText: 500, formats: ["post", "carousel"], mediaRequired: ["carousel"], maxMedia: 10 },
  bluesky: { name: "Bluesky", maxText: 300, formats: ["post"], mediaRequired: [], maxMedia: 4 },
  mastodon: { name: "Mastodon", maxText: 500, formats: ["post"], mediaRequired: [], maxMedia: 4 },
};

export const providerPlatforms: Record<Provider, Platform[]> = {
  meta: ["facebook", "instagram"],
  threads: ["threads"],
  google: ["youtube"],
  linkedin: ["linkedin"],
};

/** Inbox row id: stable per account and platform id, safe in URLs. */
export const itemId = (accountId: string, remoteId: string) => hashId(`${accountId}|${remoteId}`);
export const contentId = (accountId: string, remoteId: string) => hashId(`c|${accountId}|${remoteId}`);

export const iso = (t: string | number | undefined | null): string => {
  if (t == null) return new Date(0).toISOString();
  const d = typeof t === "number" ? new Date(t < 1e12 ? t * 1000 : t) : new Date(t);
  return Number.isNaN(d.getTime()) ? new Date(0).toISOString() : d.toISOString();
};

export const clip = (s: string | null | undefined, n = 120) => {
  const t = (s ?? "").replace(/\s+/g, " ").trim();
  return t.length > n ? `${t.slice(0, n - 1)}…` : t;
};

/** Base for a new inbox item. */
export function inboxItem(
  account: Account,
  fields: Omit<InboxItem, "accountId" | "platform" | "status" | "labels">,
): InboxItem {
  return { ...fields, accountId: account.id, platform: account.platform, status: "new", labels: [] };
}
