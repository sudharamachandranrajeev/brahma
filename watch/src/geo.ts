// Places for alert-email adverts, which carry an address but no map point.
// postcodes.io is free, open (OGL) and needs no key.

import type { Listing } from "./propertypal.ts";
import { placeToFind } from "./email.ts";

type Fetch = (url: string) => Promise<Response>;
type Point = { lat: number; lon: number } | null;

async function lookup(fetcher: Fetch, url: string, pick: (j: any) => Point): Promise<Point> {
  try {
    const res = await fetcher(url);
    if (!res.ok) return null;
    return pick(await res.json());
  } catch {
    return null;
  }
}

const point = (r: any): Point =>
  r && typeof r.latitude === "number" && typeof r.longitude === "number" ? { lat: r.latitude, lon: r.longitude } : null;

/**
 * Fills in lat/lon for listings that lack them: from the full postcode, else
 * the middle of the outward code (LS6), else the named town. One lookup per
 * distinct place. A listing whose place cannot be found keeps no point, so a
 * search with a radius skips it.
 */
export async function locate(listings: Listing[], fetcher: Fetch = (u) => fetch(u)): Promise<void> {
  const base = "https://api.postcodes.io";
  const cache = new Map<string, Promise<Point>>();
  const once = (key: string, url: string, pick: (j: any) => Point) => {
    if (!cache.has(key)) cache.set(key, lookup(fetcher, url, pick));
    return cache.get(key)!;
  };
  for (const l of listings) {
    if (l.lat != null && l.lon != null) continue;
    const p = placeToFind(l.address);
    const found = p.postcode
      ? await once(`p:${p.postcode}`, `${base}/postcodes/${encodeURIComponent(p.postcode)}`, (j) => point(j?.result))
      : p.outcode
        ? await once(`o:${p.outcode}`, `${base}/outcodes/${encodeURIComponent(p.outcode)}`, (j) => point(j?.result))
        : p.town
          ? await once(`t:${p.town.toLowerCase()}`, `${base}/places?q=${encodeURIComponent(p.town)}&limit=1`, (j) =>
              point(j?.result?.[0]),
            )
          : null;
    if (found) {
      l.lat = found.lat;
      l.lon = found.lon;
    }
  }
}
