import type { Listing } from "./propertypal.ts";

/** A saved search the cloud checks on a schedule. */
export interface Watch {
  id: string;
  name: string;
  /** Only "propertypal" today. */
  source: "propertypal";
  /** Search path, e.g. /property-to-rent/enniskillen */
  path: string;
  maxPrice?: number;
  minBeds?: number;
  maxBeds?: number;
  centre?: { lat: number; lon: number; label: string };
  radiusKm?: number;
  /** Listings with a hidden price still alert (marked "price not shown"). */
  includeUnpriced?: boolean;
  paused?: boolean;
}

/** What the watcher remembers about a listing between runs. */
export interface Seen {
  price: number | null;
  status: string;
  matched: boolean;
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

export function matches(w: Watch, l: Listing): boolean {
  if (l.status !== "toLet" && l.status !== "forSale") return false;
  if (l.price == null ? !w.includeUnpriced : w.maxPrice != null && l.price > w.maxPrice) return false;
  if (w.minBeds != null && l.beds != null && l.beds < w.minBeds) return false;
  if (w.maxBeds != null && l.beds != null && l.beds > w.maxBeds) return false;
  if (w.radiusKm != null && w.centre) {
    const d = distanceTo(w, l);
    if (d == null || d > w.radiusKm) return false;
  }
  return true;
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
