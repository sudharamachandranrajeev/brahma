import type { Listing } from "./propertypal.ts";

/**
 * A saved search. "propertypal" searches are fetched on a schedule.
 * "email" searches are filters over the portal alert emails the user
 * forwards to the Worker (Rightmove, Zoopla, OnTheMarket, OpenRent,
 * SpareRoom): nothing is fetched from those sites.
 */
export interface Watch {
  id: string;
  name: string;
  source: "propertypal" | "email";
  /** PropertyPal search path, e.g. /property-to-rent/enniskillen. Unused for email. */
  path: string;
  /** Email searches: homes to rent or to buy. */
  kind?: "rent" | "buy";
  maxPrice?: number;
  minBeds?: number;
  maxBeds?: number;
  centre?: { lat: number; lon: number; label: string };
  radiusKm?: number;
  /**
   * Words the advert must mention; a word starting with "-" must not appear
   * ("pets", "parking", "-tenanted", "-retirement").
   */
  keywords?: string[];
  /** Listings with a hidden price still alert (marked "price not shown"). */
  includeUnpriced?: boolean;
  paused?: boolean;
}

/** What the watcher remembers about a listing between runs. */
export interface Seen {
  price: number | null;
  status: string;
  matched: boolean;
  /** Email searches: when it was last in an email (ISO), to forget old ones. */
  at?: string;
  /** Email searches: a cross-portal key (see sameHomeKey). */
  home?: string;
}

export interface WatchEvent {
  at: string;
  watchId: string;
  kind: "new" | "price" | "status";
  listing: Listing;
  distanceKm: number | null;
  previousPrice?: number | null;
  previousStatus?: string;
}

export function distanceKm(a: { lat: number; lon: number }, b: { lat: number; lon: number }): number {
  const rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad;
  const dLon = (b.lon - a.lon) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.sqrt(h));
}

function distanceTo(w: Watch, l: Listing): number | null {
  if (!w.centre || l.lat == null || l.lon == null) return null;
  return distanceKm(w.centre, { lat: l.lat, lon: l.lon });
}

/** Every plain keyword appears in the advert's words; no "-" keyword does. */
export function keywordsMatch(keywords: string[] | undefined, l: Listing): boolean {
  if (!keywords?.length) return true;
  const hay = [l.address, l.style, l.furnished, l.text ?? ""].join(" ").toLowerCase();
  for (const raw of keywords) {
    const k = raw.trim().toLowerCase();
    if (k.startsWith("-")) {
      if (k.length > 1 && hay.includes(k.slice(1))) return false;
    } else if (k && !hay.includes(k)) {
      return false;
    }
  }
  return true;
}

export function matches(w: Watch, l: Listing): boolean {
  if (l.status !== "toLet" && l.status !== "forSale") return false;
  if (w.kind && (w.kind === "rent") !== (l.status === "toLet")) return false;
  if (l.price == null ? !w.includeUnpriced : w.maxPrice != null && l.price > w.maxPrice) return false;
  if (w.minBeds != null && l.beds != null && l.beds < w.minBeds) return false;
  if (w.maxBeds != null && l.beds != null && l.beds > w.maxBeds) return false;
  if (w.radiusKm != null && w.centre) {
    const d = distanceTo(w, l);
    if (d == null || d > w.radiusKm) return false;
  }
  return keywordsMatch(w.keywords, l);
}

/**
 * Compares this run's listings with what was seen before. Alerts when a
 * listing starts to match (new, or its price dropped into range) and when a
 * matching listing's price or status changes. A watch's first run only records
 * what is there, so adding a watch does not flood the phone.
 */
export function diff(
  w: Watch,
  listings: Listing[],
  before: Record<string, Seen> | null,
  now: string,
): { events: WatchEvent[]; seen: Record<string, Seen> } {
  // Only listings still in the search are kept, so the record stays small.
  const seen: Record<string, Seen> = {};
  const events: WatchEvent[] = [];
  for (const l of listings) {
    const prev = before?.[l.id];
    const matched = matches(w, l);
    seen[l.id] = { price: l.price, status: l.status, matched };
    if (!before) continue;
    const base = { at: now, watchId: w.id, listing: l, distanceKm: distanceTo(w, l) };
    if (matched && !prev?.matched) {
      events.push({ ...base, kind: prev ? "price" : "new", previousPrice: prev?.price });
    } else if (prev?.matched && prev.price !== l.price) {
      events.push({ ...base, kind: "price", previousPrice: prev.price });
    } else if (prev?.matched && prev.status !== l.status) {
      events.push({ ...base, kind: "status", previousStatus: prev.status });
    }
  }
  return { events, seen };
}

/** How long an email search remembers a home (for duplicates and price cuts). */
export const rememberDays = 60;

/**
 * The same home sent by two portals (or by two agents): same outward
 * postcode or street, same beds and a price within 3%. Null when too little
 * is known to say.
 */
export function sameHomeKey(l: Listing): string | null {
  if (l.price == null || l.beds == null) return null;
  const place = (l.address.match(/\b([A-Z]{1,2}\d[A-Z\d]?)(?:\s*\d[A-Z]{2})?\b/i)?.[1] ?? l.address.split(",")[0])
    .trim()
    .toLowerCase();
  if (!place) return null;
  return `${l.status}|${place}|${l.beds}|${l.price}`;
}

function nearSameHome(a: string, b: string): boolean {
  const [as, ap, ab, aprice] = a.split("|");
  const [bs, bp, bb, bprice] = b.split("|");
  if (as !== bs || ap !== bp || ab !== bb) return false;
  const x = Number(aprice), y = Number(bprice);
  return Math.abs(x - y) <= Math.max(x, y) * 0.03;
}

/**
 * Email searches. Every listing in an email is news, so there is no silent
 * first run. A home seen before alerts again only when its price changes
 * (portals email "reduced" homes). A home another portal already sent (see
 * sameHomeKey) is recorded without a second alert. Entries older than
 * rememberDays are forgotten.
 */
export function diffEmail(
  w: Watch,
  listings: Listing[],
  before: Record<string, Seen> | null,
  now: string,
): { events: WatchEvent[]; seen: Record<string, Seen> } {
  const cutoff = new Date(Date.parse(now) - rememberDays * 86400_000).toISOString();
  const seen: Record<string, Seen> = {};
  for (const [id, s] of Object.entries(before ?? {})) if ((s.at ?? "") >= cutoff) seen[id] = s;
  const events: WatchEvent[] = [];
  for (const l of listings) {
    const prev = seen[l.id];
    const matched = matches(w, l);
    const home = sameHomeKey(l) ?? undefined;
    const twin =
      !prev && home
        ? Object.entries(seen).find(([id, s]) => id !== l.id && s.matched && s.home && nearSameHome(s.home, home))
        : undefined;
    seen[l.id] = { price: l.price, status: l.status, matched, at: now, ...(home ? { home } : {}) };
    if (!matched || twin) continue;
    const base = { at: now, watchId: w.id, listing: l, distanceKm: distanceTo(w, l) };
    if (!prev?.matched) events.push({ ...base, kind: "new" });
    else if (prev.price !== l.price) events.push({ ...base, kind: "price", previousPrice: prev.price });
  }
  return { events, seen };
}
