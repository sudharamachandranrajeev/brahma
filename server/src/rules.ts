// Relays Sentinel's signed rules file (sentinel/rules.json in the brahma
// repository) to synced devices, fetched from GitHub at most twice a day.
// The server does not check the signature and cannot forge one: each device
// verifies the file against the maintainers' public key (core's
// sentinel/rules.dart).

export const RULES_URL = "https://raw.githubusercontent.com/sudharamachandranrajeev/brahma/main/sentinel/rules.json";

const FRESH_MS = 12 * 3600_000;

export interface SignedRules {
  rules: string;
  sig: string;
  fetched: string;
}

let cache: SignedRules | null = null;

/// The file and its signature, from memory while fresh. A failed fetch keeps
/// serving the last copy; with none, it throws.
export async function rules(now = new Date(), get: typeof fetch = fetch): Promise<SignedRules> {
  if (cache && now.getTime() - Date.parse(cache.fetched) < FRESH_MS) return cache;
  try {
    const text = async (url: string) => {
      const res = await get(url);
      if (!res.ok) throw new Error(`GitHub answered ${res.status}`);
      return res.text();
    };
    const [r, s] = await Promise.all([text(RULES_URL), text(`${RULES_URL}.sig`)]);
    cache = { rules: r, sig: s, fetched: now.toISOString() };
  } catch (e) {
    if (!cache) throw e;
    console.error("Rules not refreshed:", e);
  }
  return cache;
}

/// For tests.
export const forgetRules = () => {
  cache = null;
};
