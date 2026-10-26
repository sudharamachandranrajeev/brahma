// Sentinel's threat watch for synced devices: the server fetches CISA's
// catalogue of known exploited vulnerabilities (KEV) at most twice a day and
// hands its devices the recent part. Devices that keep their data on the
// device only fetch the catalogue themselves (core's sentinel/threats.dart,
// which trims it the same way and decides what concerns each device).

export const KEV_URL = "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json";

/// Days of the catalogue kept.
export const THREAT_DAYS = 180;

const FRESH_MS = 12 * 3600_000;

export interface Threat {
  cve: string;
  vendor: string;
  product: string;
  name: string;
  /// YYYY-MM-DD, when CISA added it.
  added: string;
  ransomware: boolean;
}

export interface ThreatList {
  fetched: string;
  threats: Threat[];
}

const str = (v: unknown, max: number) => (typeof v === "string" ? v.trim().slice(0, max) : "");

/// The catalogue's entries added in the last [THREAT_DAYS] days, newest
/// first, in the short form devices keep.
export function trimKev(kev: unknown, now: Date): Threat[] {
  const list = (kev as { vulnerabilities?: unknown })?.vulnerabilities;
  if (!Array.isArray(list)) throw new Error("Not the KEV catalogue");
  const since = new Date(now.getTime() - THREAT_DAYS * 86400_000).toISOString().slice(0, 10);
  const out: Threat[] = [];
  for (const v of list as Record<string, unknown>[]) {
    const added = str(v?.dateAdded, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(added) || added < since) continue;
    out.push({
      cve: str(v.cveID, 40),
      vendor: str(v.vendorProject, 80),
      product: str(v.product, 120),
      name: str(v.vulnerabilityName, 200),
      added,
      ransomware: v.knownRansomwareCampaignUse === "Known",
    });
  }
  return out.sort((a, b) => b.added.localeCompare(a.added));
}

let cache: ThreatList | null = null;

/// The recent threats, from memory while fresh. A failed fetch keeps
/// serving the last list; with none, it throws.
export async function threats(now = new Date(), get: typeof fetch = fetch): Promise<ThreatList> {
  if (cache && now.getTime() - Date.parse(cache.fetched) < FRESH_MS) return cache;
  try {
    const res = await get(KEV_URL, { headers: { accept: "application/json" } });
    if (!res.ok) throw new Error(`CISA answered ${res.status}`);
    cache = { fetched: now.toISOString(), threats: trimKev(await res.json(), now) };
  } catch (e) {
    if (!cache) throw e;
    console.error("Threat list not refreshed:", e);
  }
  return cache;
}

/// For tests.
export const forgetThreats = () => {
  cache = null;
};
