// PropertyPal (and PropertyNews, same platform) search pages are Next.js
// pages: the results sit in the __NEXT_DATA__ JSON, so no HTML scraping and
// no private API. robots.txt allows these paths.

export interface Listing {
  id: string;
  url: string;
  address: string;
  /** Monthly rent or asking price in pounds; null when the agent hides it. */
  price: number | null;
  priceSuffix: string;
  beds: number | null;
  baths: number | null;
  style: string;
  furnished: string;
  heating: string;
  availableFrom: string | null;
  lat: number | null;
  lon: number | null;
  agent: string;
  agentPhone: string;
  image: string | null;
  /** toLet, letAgreed, forSale, saleAgreed... */
  status: string;
}

const origin = "https://www.propertypal.com";
export const userAgent = "Mozilla/5.0 (compatible; BrahmaWatch/0.1; personal saved-search alerts)";

/** Reads one results page. Throws when the page has no results data. */
export function parseSearchPage(html: string): { listings: Listing[]; totalPages: number } {
  const m = html.match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);
  if (!m) throw new Error("PropertyPal page has no __NEXT_DATA__ (blocked or layout changed)");
  const data = JSON.parse(m[1])?.props?.pageProps?.initialState?.properties?.data;
  if (!data || !Array.isArray(data.results)) throw new Error("PropertyPal page has no results data");
  return { listings: data.results.map(toListing), totalPages: Number(data.totalPages) || 1 };
}

function toListing(r: any): Listing {
  const price = r.price && !r.price.priceHidden && !r.price.priceOnApplication ? r.price.price : null;
  const phone = r.account?.officePhone;
  return {
    id: String(r.pathId ?? r.id),
    url: origin + r.path,
    address: String(r.displayAddress ?? ""),
    price: typeof price === "number" ? price : null,
    priceSuffix: r.price?.priceSuffix ?? "",
    beds: r.numBedrooms ?? null,
    baths: r.numBathrooms ?? null,
    style: r.style?.text ?? "",
    furnished: r.furnishedType?.text ?? "",
    heating: r.heatingType?.text ?? "",
    availableFrom: r.dateAvailableFrom ?? null,
    lat: r.coordinate?.latitude ?? null,
    lon: r.coordinate?.longitude ?? null,
    agent: r.account?.organisation ?? "",
    agentPhone: phone?.international ?? "",
    image: r.images?.[0]?.url ?? null,
    status: r.status?.key ?? "",
  };
}

/**
 * Fetches every page of a search, newest first. [path] is a PropertyPal search
 * path such as `/property-to-rent/enniskillen`.
 */
export async function fetchSearch(path: string, maxPages = 5): Promise<Listing[]> {
  const all: Listing[] = [];
  for (let page = 1; page <= maxPages; page++) {
    const url = new URL(path + (page > 1 ? `/page-${page}` : ""), origin);
    url.searchParams.set("sort", "dateHigh");
    const res = await fetch(url, { headers: { "user-agent": userAgent, accept: "text/html" } });
    if (!res.ok) throw new Error(`PropertyPal ${url.pathname} answered ${res.status}`);
    const { listings, totalPages } = parseSearchPage(await res.text());
    all.push(...listings);
    if (page >= totalPages) break;
  }
  return all;
}
