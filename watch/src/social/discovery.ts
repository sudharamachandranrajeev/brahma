// Discovery watches: described searches over sources that allow it (official
// APIs, and pages robots.txt allows), with Claude checking each new find
// against the description. No logged-in scraping: Facebook Marketplace has
// no API and is not a source.

import { userAgent } from "../propertypal.ts";
import { hasAi, judgeFinds } from "./ai.ts";
import { raise, type NewAlert } from "./alerts.ts";
import { call, form, OutOfBudget, PlatformError, spend } from "./http.ts";
import type { Ctx } from "./platforms/adapter.ts";
import { bsky } from "./platforms/bluesky.ts";
import { g, type MetaSecret } from "./platforms/meta.ts";
import { yt } from "./platforms/youtube.ts";
import { getWatches } from "./settings.ts";
import type { Alert, DiscoverySource, DiscoveryWatch, Find } from "./types.ts";

/** YouTube search costs 100 of the 10,000 daily quota units, so a watch searches it at most hourly. */
const youtubeEveryMs = 60 * 60_000;
const alertsPerRun = 8;

type RunState = Record<string, { lastRun?: string; lastYoutube?: string; error?: string }>;

// ---- sources ----

async function ebayToken(ctx: Ctx): Promise<string> {
  const cached = await ctx.env.KV.get("social:ebay-token");
  if (cached) return cached;
  const cred = await ctx.store.credential("ebay");
  if (!cred?.publicId) throw new PlatformError("Add eBay client credentials under Credentials", 400, false, false);
  const tok = await call<{ access_token: string; expires_in: number }>("https://api.ebay.com/identity/v1/oauth2/token", {
    method: "POST",
    budget: ctx.budget,
    label: "eBay",
    headers: { authorization: `Basic ${btoa(`${cred.publicId}:${cred.secret}`)}`, "content-type": "application/x-www-form-urlencoded" },
    body: form({ grant_type: "client_credentials", scope: "https://api.ebay.com/oauth/api_scope" }),
  });
  await ctx.env.KV.put("social:ebay-token", tok.access_token, { expirationTtl: Math.max(60, tok.expires_in - 300) });
  return tok.access_token;
}

export function ebayFilter(s: Extract<DiscoverySource, { type: "ebay" }>): string {
  const parts: string[] = [];
  if (s.maxPrice != null) parts.push(`price:[..${s.maxPrice}]`, "priceCurrency:GBP");
  if (s.postcode) {
    parts.push(
      "deliveryOptions:{SELLER_ARRANGED_LOCAL_PICKUP}",
      "pickupCountry:GB",
      `pickupPostalCode:${s.postcode.replace(/\s+/g, "").toUpperCase()}`,
      `pickupRadius:${Math.round(s.radiusKm ?? 50)}`,
      "pickupRadiusUnit:km",
    );
  }
  return parts.join(",");
}

async function ebay(ctx: Ctx, s: Extract<DiscoverySource, { type: "ebay" }>): Promise<Find[]> {
  const token = await ebayToken(ctx);
  const url = new URL("https://api.ebay.com/buy/browse/v1/item_summary/search");
  url.searchParams.set("q", s.query);
  url.searchParams.set("sort", "newlyListed");
  url.searchParams.set("limit", "50");
  if (s.categoryId) url.searchParams.set("category_ids", s.categoryId);
  const filter = ebayFilter(s);
  if (filter) url.searchParams.set("filter", filter);
  const r = await call(url, {
    budget: ctx.budget,
    label: "eBay",
    headers: { authorization: `Bearer ${token}`, "x-ebay-c-marketplace-id": "EBAY_GB" },
  });
  return (r?.itemSummaries ?? []).map(
    (i: any): Find => ({
      id: `ebay:${i.itemId}`,
      source: "ebay",
      title: i.title ?? "",
      text: [i.condition, i.shortDescription].filter(Boolean).join(". "),
      url: i.itemWebUrl,
      image: i.image?.imageUrl ?? i.thumbnailImages?.[0]?.imageUrl ?? null,
      price: i.price?.value != null ? Number(i.price.value) : null,
      currency: i.price?.currency ?? null,
      location: [i.itemLocation?.city, i.itemLocation?.postalCode].filter(Boolean).join(" ") || null,
      at: i.itemCreationDate ?? null,
    }),
  );
}

/** DoneDeal search pages carry their results in __NEXT_DATA__ (robots.txt allows /cars and other sections). */
export function parseDoneDeal(html: string): Find[] {
  const m = html.match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);
  if (!m) throw new PlatformError("DoneDeal page has no __NEXT_DATA__ (blocked or layout changed)", 502, true, false);
  const ads = JSON.parse(m[1])?.props?.pageProps?.ads;
  if (!Array.isArray(ads)) throw new PlatformError("DoneDeal page has no ads list", 502, false, false);
  return ads.map((a: any): Find => {
    const label = String(a.priceInfo?.price ?? "");
    const digits = label.replace(/[^\d.]/g, "");
    return {
      id: `donedeal:${a.id}`,
      source: "donedeal",
      title: a.title ?? "",
      text: [...(a.metaInfo ?? []).map((x: string) => x.trim()), a.imageAlt].filter(Boolean).join(", "),
      url: a.friendlyUrl ?? `https://www.donedeal.ie${a.relativeUrl ?? ""}`,
      image: a.gallery?.coverImage?.small ?? null,
      price: a.priceInfo?.priceOnRequest || !digits ? null : Number(digits),
      currency: label.includes("£") ? "GBP" : label.includes("€") ? "EUR" : null,
      location: [a.countyTown, a.county].filter(Boolean).join(", ") || null,
      at: typeof a.publishDate === "number" ? new Date(a.publishDate).toISOString() : null,
    };
  });
}

async function donedeal(ctx: Ctx, s: Extract<DiscoverySource, { type: "donedeal" }>): Promise<Find[]> {
  spend(ctx.budget);
  const res = await fetch(`https://www.donedeal.ie${s.path}`, { headers: { "user-agent": userAgent, accept: "text/html" } });
  if (!res.ok) throw new PlatformError(`DoneDeal answered ${res.status}`, res.status, res.status === 429 || res.status >= 500, false);
  const finds = parseDoneDeal(await res.text());
  return s.maxPrice == null ? finds : finds.filter((f) => f.price == null || f.price <= s.maxPrice!);
}

const igFields = "id,caption,media_type,media_url,thumbnail_url,permalink,timestamp,like_count,comments_count";

const igFind = (m: any, who: string | null): Find => ({
  id: `instagram:${m.id}`,
  source: "instagram_hashtag",
  title: who ? `@${who}` : (m.caption ?? "").split("\n")[0].slice(0, 80) || "Instagram post",
  text: m.caption ?? "",
  url: m.permalink,
  image: m.media_type === "VIDEO" ? (m.thumbnail_url ?? null) : (m.media_url ?? null),
  price: null,
  currency: null,
  location: null,
  at: m.timestamp ?? null,
});

/** Hashtag ids are cached: Instagram allows 30 different hashtag lookups a week. */
async function hashtagId(ctx: Ctx, igUser: string, token: string, tag: string): Promise<string | null> {
  const key = `social:ig-hashtag:${tag.toLowerCase()}`;
  const cached = await ctx.env.KV.get(key);
  if (cached) return cached;
  const r = await g(ctx, "/ig_hashtag_search", token, { user_id: igUser, q: tag });
  const id = r?.data?.[0]?.id ?? null;
  if (id) await ctx.env.KV.put(key, id, { expirationTtl: 30 * 86400 });
  return id;
}

async function instagramAccount(ctx: Ctx, accountId: string) {
  const account = await ctx.store.account(accountId);
  if (!account || account.platform !== "instagram") throw new PlatformError("The Instagram account for this source is not connected", 400, false, false);
  const { pageToken } = await ctx.store.secretOf<MetaSecret>(account.id);
  return { igUser: account.remoteId, token: pageToken };
}

async function instagramHashtag(ctx: Ctx, s: Extract<DiscoverySource, { type: "instagram_hashtag" }>): Promise<Find[]> {
  const { igUser, token } = await instagramAccount(ctx, s.accountId);
  const out: Find[] = [];
  for (const tag of s.hashtags) {
    const id = await hashtagId(ctx, igUser, token, tag);
    if (!id) continue;
    const r = await g(ctx, `/${id}/recent_media`, token, { user_id: igUser, fields: igFields, limit: "50" });
    for (const m of r?.data ?? []) out.push(igFind(m, null));
  }
  return out;
}

async function instagramBusiness(ctx: Ctx, s: Extract<DiscoverySource, { type: "instagram_business" }>): Promise<Find[]> {
  const { igUser, token } = await instagramAccount(ctx, s.accountId);
  const out: Find[] = [];
  for (const username of s.usernames) {
    const r = await g(ctx, `/${igUser}`, token, {
      fields: `business_discovery.username(${username}){username,name,media.limit(12){${igFields}}}`,
    });
    const bd = r?.business_discovery;
    for (const m of bd?.media?.data ?? []) out.push({ ...igFind(m, bd.username), source: "instagram_business" });
  }
  return out;
}

async function blueskySearch(ctx: Ctx, s: Extract<DiscoverySource, { type: "bluesky" }>): Promise<Find[]> {
  const query = { q: s.query, sort: "latest", limit: "50" };
  // A connected account's session avoids the public AppView's search limits.
  const account = (await ctx.store.accounts()).find((a) => a.platform === "bluesky" && a.status !== "broken");
  const r = account
    ? await bsky(ctx, account, "app.bsky.feed.searchPosts", { query })
    : await call(`https://public.api.bsky.app/xrpc/app.bsky.feed.searchPosts?${new URLSearchParams(query)}`, { budget: ctx.budget, label: "Bluesky" });
  return (r?.posts ?? []).map((p: any): Find => {
    const rkey = String(p.uri).split("/").pop();
    return {
      id: `bluesky:${p.uri}`,
      source: "bluesky",
      title: `${p.author?.displayName || p.author?.handle} (@${p.author?.handle})`,
      text: p.record?.text ?? "",
      url: `https://bsky.app/profile/${p.author?.handle}/post/${rkey}`,
      image: p.embed?.images?.[0]?.thumb ?? p.author?.avatar ?? null,
      price: null,
      currency: null,
      location: null,
      at: p.record?.createdAt ?? p.indexedAt ?? null,
    };
  });
}

async function youtubeSearch(ctx: Ctx, s: Extract<DiscoverySource, { type: "youtube" }>, since: Date): Promise<Find[]> {
  const account = await ctx.store.account(s.accountId);
  if (!account || account.platform !== "youtube") throw new PlatformError("The YouTube account for this source is not connected", 400, false, false);
  const q = new URLSearchParams({ part: "snippet", q: s.query, type: "video", order: "date", maxResults: "25", publishedAfter: since.toISOString() });
  const r = await yt(ctx, account, `/search?${q}`);
  return (r?.items ?? []).map(
    (v: any): Find => ({
      id: `youtube:${v.id?.videoId}`,
      source: "youtube",
      title: v.snippet?.title ?? "",
      text: `${v.snippet?.channelTitle ?? ""}: ${v.snippet?.description ?? ""}`,
      url: `https://www.youtube.com/watch?v=${v.id?.videoId}`,
      image: v.snippet?.thumbnails?.medium?.url ?? null,
      price: null,
      currency: null,
      location: null,
      at: v.snippet?.publishedAt ?? null,
    }),
  );
}

// ---- running ----

/** Every keyword must appear (case-insensitive) in the title or text. */
export const keywordsMatch = (f: Find, keywords: string[]) => {
  const hay = `${f.title} ${f.text}`.toLowerCase();
  return keywords.every((k) => hay.includes(k.toLowerCase()));
};

export interface RunResult {
  finds: Find[];
  alerts: Alert[];
  errors: string[];
}

/**
 * Runs one watch: fetch every source, keep keyword matches, drop what it has
 * seen, let Claude judge the rest (when on), alert on matches. The very first
 * run only records what is there, so a new watch doesn't alert on old listings.
 */
export async function runWatch(ctx: Ctx, watch: DiscoveryWatch, state: RunState = {}): Promise<RunResult> {
  const errors: string[] = [];
  const mine = (state[watch.id] ??= {});
  const lastYoutube = mine.lastYoutube ? new Date(mine.lastYoutube) : null;
  const youtubeDue = !lastYoutube || ctx.now.getTime() - lastYoutube.getTime() >= youtubeEveryMs;
  let finds: Find[] = [];
  for (const s of watch.sources) {
    try {
      if (s.type === "ebay") finds.push(...(await ebay(ctx, s)));
      else if (s.type === "donedeal") finds.push(...(await donedeal(ctx, s)));
      else if (s.type === "instagram_hashtag") finds.push(...(await instagramHashtag(ctx, s)));
      else if (s.type === "instagram_business") finds.push(...(await instagramBusiness(ctx, s)));
      else if (s.type === "bluesky") finds.push(...(await blueskySearch(ctx, s)));
      else if (s.type === "youtube" && youtubeDue) {
        finds.push(...(await youtubeSearch(ctx, s, lastYoutube ?? new Date(ctx.now.getTime() - 7 * 86400_000))));
        mine.lastYoutube = ctx.now.toISOString();
      }
    } catch (err) {
      if (err instanceof OutOfBudget) throw err;
      errors.push(`${s.type}: ${err instanceof Error ? err.message : String(err)}`);
    }
  }
  const unique = new Map(finds.map((f) => [f.id, f]));
  finds = [...unique.values()].filter((f) => keywordsMatch(f, watch.keywords));
  mine.lastRun = ctx.now.toISOString();

  const { store } = ctx;
  const baseline = !(await store.hasSeen(watch.id));
  const unseen = await store.unseen(watch.id, finds.map((f) => f.id));
  const fresh = finds.filter((f) => unseen.has(f.id));
  let matches: { find: Find; score?: number; reason?: string }[] = [];
  if (!baseline && fresh.length) {
    if (watch.ai && (await hasAi(store))) {
      for (let i = 0; i < fresh.length; i += 25) spend(ctx.budget);
      try {
        const verdicts = await judgeFinds(store, watch.description, fresh);
        matches = fresh
          .map((find) => ({ find, ...verdicts.get(find.id) }))
          .filter((m) => m.match && (m.score ?? 0) >= 0.5)
          .sort((a, b) => (b.score ?? 0) - (a.score ?? 0));
      } catch (err) {
        // Not marked seen: these finds are judged again on the next run.
        errors.push(`Claude: ${err instanceof Error ? err.message : String(err)}`);
        return finish(ctx, watch, mine, { finds, alerts: [], errors });
      }
    } else {
      matches = fresh.map((find) => ({ find }));
    }
  }
  await store.markSeen(watch.id, [...(baseline ? ["_baseline"] : []), ...fresh.map((f) => f.id)], ctx.now.toISOString());

  const alerts: NewAlert[] = matches.slice(0, alertsPerRun).map(({ find, score, reason }) => ({
    kind: "discovery",
    title: `${watch.name}: ${find.title}`.slice(0, 200),
    body: [find.price != null ? money(find.price, find.currency) : null, find.location, reason].filter(Boolean).join(" · "),
    url: find.url,
    image: find.image,
    ref: watch.id,
    ...(score != null ? { score } : {}),
    ...(reason ? { reason } : {}),
  }));
  if (matches.length > alertsPerRun) {
    alerts.push({ kind: "discovery", title: `${watch.name}: ${matches.length - alertsPerRun} more matches`, body: "Open Vani to see them all.", url: null, image: null, ref: watch.id });
  }
  return finish(ctx, watch, mine, { finds, alerts: alerts.length ? await raise(ctx.env, store, alerts) : [], errors });
}

function money(n: number, currency: string | null) {
  try {
    return new Intl.NumberFormat("en-GB", { style: "currency", currency: currency ?? "GBP", maximumFractionDigits: 0 }).format(n);
  } catch {
    return String(n);
  }
}

/** Records the run's error, alerting when it is a new one (so a broken source is noticed once, not every 10 minutes). */
async function finish(ctx: Ctx, watch: DiscoveryWatch, mine: RunState[string], result: RunResult): Promise<RunResult> {
  const error = result.errors.join("; ") || undefined;
  if (error && error !== mine.error) {
    result.alerts.push(
      ...(await raise(ctx.env, ctx.store, [{ kind: "system", title: `Watch "${watch.name}" has a problem`, body: error.slice(0, 500), url: null, image: null, ref: watch.id }])),
    );
  }
  mine.error = error;
  return result;
}

export const runState = (ctx: Ctx) => ctx.store.doc<RunState>("discovery_state", {});
export const saveRunState = (ctx: Ctx, state: RunState) => ctx.store.putDoc("discovery_state", state);

/** The cron's discovery pass: watches whose interval has passed, while the budget lasts. */
export async function runDue(ctx: Ctx): Promise<number> {
  const watches = await getWatches(ctx.store);
  const state = await runState(ctx);
  // Forget state of deleted watches.
  for (const id of Object.keys(state)) if (!watches.some((w) => w.id === id)) delete state[id];
  let ran = 0;
  const byAge = watches
    .filter((w) => !w.paused)
    .sort((a, b) => (state[a.id]?.lastRun ?? "").localeCompare(state[b.id]?.lastRun ?? ""));
  for (const w of byAge) {
    const last = state[w.id]?.lastRun;
    // A minute of slack so a 10-minute watch runs on every 10-minute tick.
    if (last && ctx.now.getTime() - new Date(last).getTime() < (w.everyMinutes - 1) * 60_000) continue;
    if (ctx.budget.left < w.sources.length * 2 + 3) break;
    try {
      await runWatch(ctx, w, state);
      ran++;
    } catch (err) {
      if (err instanceof OutOfBudget) break;
      throw err;
    } finally {
      await saveRunState(ctx, state);
    }
  }
  return ran;
}
