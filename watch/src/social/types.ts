// The social hub's data model. These shapes are the HTTP API's JSON too
// (Vani reads and writes them), so change them with the app in mind.

export type Platform = "instagram" | "facebook" | "youtube" | "linkedin" | "threads" | "bluesky" | "mastodon" | "telegram";

/** Where an OAuth sign-in starts; one provider can bring several accounts (a Meta login brings Pages and their Instagram accounts). */
export type Provider = "meta" | "threads" | "google" | "linkedin";

/** What a post becomes on a platform. */
export type Format = "post" | "carousel" | "reel" | "story" | "video" | "short";

export type Capability = "publish" | "comments" | "messages" | "mentions" | "live" | "insights" | "private_reply";

export interface Account {
  id: string;
  platform: Platform;
  name: string;
  handle: string;
  avatar: string | null;
  /** The platform's own id (Instagram user id, Page id, channel id, DID...). */
  remoteId: string;
  /** "expiring" when the token runs out within 7 days, "broken" when calls fail with auth errors. */
  status: "ok" | "expiring" | "broken";
  statusMessage: string | null;
  expiresAt: string | null;
  capabilities: Capability[];
  connectedAt: string;
  checkedAt: string | null;
}

export interface Media {
  id: string;
  filename: string;
  contentType: string;
  size: number;
  status: "uploading" | "ready";
  createdAt: string;
  /** Description for people using screen readers; sent as alt text where the platform takes it. */
  alt?: string;
  /** Signed, time-limited public URL (platforms fetch media from it). */
  url: string;
}

export type TargetStatus = "draft" | "scheduled" | "publishing" | "published" | "failed";

/** One account a post goes to, with its own wording and outcome. */
export interface Target {
  accountId: string;
  format: Format;
  /** Replaces the post's text on this account. */
  text?: string;
  /** YouTube title (required there). */
  title?: string;
  /** Posted as the first comment right after publishing (hashtags, links). */
  firstComment?: string;
  /** More posts after the first, each a reply to the one before (Threads, Bluesky, Mastodon). */
  thread?: string[];
  status: TargetStatus;
  remoteId?: string;
  permalink?: string;
  error?: string;
  /**
   * True when a failure happened after the platform may already have
   * accepted the post, so a blind retry could post it twice.
   */
  maybePosted?: boolean;
  attempts: number;
  /** Instagram/Threads container made in an earlier attempt, reused on retry. */
  containerId?: string;
  /** Remote ids of the thread's later posts that are up, so a retry carries on after them. */
  threadIds?: string[];
  publishedAt?: string;
}

export interface Post {
  id: string;
  text: string;
  /** Media ids, in order. */
  media: string[];
  targets: Target[];
  /** ISO time to publish; null for a draft or a post published by hand. */
  scheduledAt: string | null;
  status: TargetStatus;
  /** Re-queued this many days after it is published (evergreen content). */
  recycleDays?: number;
  /** Goes out again on a fixed schedule: the next copy is made once this one is done. */
  repeat?: Repeat;
  /** The next copy in the series, once made. */
  repeatedAs?: string;
  /** Media id of an image used as the cover of video formats (reels, YouTube, Facebook and LinkedIn videos). */
  cover?: string;
  tags: string[];
  createdAt: string;
  updatedAt: string;
}

/** Every [every] days, weeks or months, at the same local time (Settings.timezone), until [until]. */
export interface Repeat {
  unit: "day" | "week" | "month";
  every: number;
  until?: string;
}

export type InboxKind = "comment" | "reply" | "message" | "mention" | "live_chat";
export type ContextType = "post" | "reel" | "story" | "live" | "video" | "short" | "dm" | "thread";

export interface InboxItem {
  id: string;
  accountId: string;
  platform: Platform;
  kind: InboxKind;
  context: {
    type: ContextType;
    id: string;
    title: string;
    url: string | null;
    thumbnail: string | null;
  };
  author: { id: string; name: string; handle: string; avatar: string | null };
  text: string;
  at: string;
  /** The platform's id for this comment or message; replies go to it. */
  remoteId: string;
  parentRemoteId: string | null;
  status: "new" | "read" | "done";
  myReply?: { text: string; at: string; private: boolean };
  /** Names of the rules that matched it. */
  labels: string[];
  likes?: number;
  /** Claude's read of a new item (when AI is on). */
  triage?: Triage;
  /** The text in `to` (the owner's language when it was asked); `lang` is the original's ISO 639-1 code. */
  translation?: { lang: string; to: string; text: string };
  /** What the owner did to it on the platform. */
  moderation?: "hidden" | "deleted";
}

export type Mood = "positive" | "neutral" | "question" | "complaint" | "spam";

export interface Triage {
  mood: Mood;
  /** high: needs an answer soon (a complaint, a buyer, a problem); low: nothing to do. */
  priority: "high" | "normal" | "low";
  /** ISO 639-1 code of the item's language. */
  lang: string;
}

export type ModerateAction = "hide" | "unhide" | "delete";

/** A post, reel or video on a connected account, with its latest numbers. */
export interface Content {
  id: string;
  accountId: string;
  platform: Platform;
  remoteId: string;
  type: ContextType;
  caption: string;
  url: string | null;
  thumbnail: string | null;
  at: string;
  likes: number;
  comments: number;
  views: number | null;
}

/** Acts on new inbox items. */
export interface InboxRule {
  id: string;
  name: string;
  enabled: boolean;
  /** null = every account. */
  accountIds: string[] | null;
  /** Any of these words or phrases (case-insensitive). */
  keywords: string[];
  /** Plain-English condition judged by Claude, e.g. "asks about price or availability". */
  description?: string;
  /** Reply in public with this text; {name} becomes the author's name. */
  reply?: string;
  /** Private reply (Instagram/Facebook comment-to-DM). */
  privateReply?: string;
  alert: boolean;
}

export type DiscoverySource =
  | { type: "ebay"; query: string; categoryId?: string; postcode?: string; radiusKm?: number; maxPrice?: number }
  | { type: "donedeal"; path: string; maxPrice?: number }
  | { type: "instagram_hashtag"; accountId: string; hashtags: string[] }
  | { type: "instagram_business"; accountId: string; usernames: string[] }
  | { type: "bluesky"; query: string }
  | { type: "youtube"; accountId: string; query: string };

/** A described search the cloud runs on a schedule, alerting on new matches. */
export interface DiscoveryWatch {
  id: string;
  name: string;
  /** What you are looking for, in plain English. Claude checks each new find against it when `ai` is on. */
  description: string;
  sources: DiscoverySource[];
  keywords: string[];
  ai: boolean;
  /** Minutes between runs (at least 10). */
  everyMinutes: number;
  paused: boolean;
}

/** One thing a discovery source found. */
export interface Find {
  id: string;
  source: DiscoverySource["type"];
  title: string;
  text: string;
  url: string;
  image: string | null;
  price: number | null;
  currency: string | null;
  location: string | null;
  at: string | null;
}

/** A separate workspace on the hub: its own accounts, posts, inbox, rules and settings. */
export interface Profile {
  id: string;
  name: string;
  createdAt: string;
}

export type AlertKind = "discovery" | "inbox" | "publish" | "account" | "system" | "summary";

export interface Alert {
  id: string;
  at: string;
  kind: AlertKind;
  title: string;
  body: string;
  url: string | null;
  image: string | null;
  /** The watch, rule, post or account it is about. */
  ref: string | null;
  /** Claude's match score (0-1) and why, for discovery alerts. */
  score?: number;
  reason?: string;
  read: boolean;
}

export interface StatPoint {
  day: string;
  followers: number;
}

export interface AccountStats {
  accountId: string;
  followers: number | null;
  /** Change over the last 7 days of snapshots. */
  followersDelta7d: number | null;
  posts: number | null;
  /** Platform-reported reach or views over the last 28 days, when it offers one. */
  views28d: number | null;
  series: StatPoint[];
}

export interface Stats {
  accounts: AccountStats[];
  /** Engagement of your own posts by weekday (0 = Monday) and hour (UTC), 0-1. */
  bestTimes: { day: number; hour: number; score: number; posts: number }[];
  topContent: Content[];
}

/** Posting slots for the queue: weekday (0 = Monday) and local time "HH:MM". */
export interface QueueSlot {
  day: number;
  time: string;
}

export interface Settings {
  /** IANA zone for queue slots, e.g. "Europe/London". */
  timezone: string;
  queue: QueueSlot[];
  savedReplies: { id: string; title: string; text: string }[];
  /** Model for drafting and matching. */
  model: string;
  /** Language inbox items are translated into, in English ("English", "Malayalam"). */
  language: string;
}

/** Per-platform limits and formats; the app's composer reads them from GET /social/meta. */
export interface PlatformInfo {
  name: string;
  maxText: number;
  formats: Format[];
  /** Formats that need at least one media file. */
  mediaRequired: Format[];
  maxMedia: number;
  /** What the owner can do to other people's comments there ("unhide" comes with "hide"). */
  moderation: ("hide" | "delete")[];
  /** Takes a thread: several posts, each replying to the one before. */
  threads: boolean;
  /** Takes a cover image on these video formats. */
  cover: Format[];
}

/** Which provider credentials are stored (never the secrets themselves). */
export interface CredentialStatus {
  provider: CredentialProvider;
  set: boolean;
  /** The id part, safe to show (client id / app id). */
  publicId: string | null;
  updatedAt: string | null;
}

export type CredentialProvider = Provider | "ebay" | "anthropic";
