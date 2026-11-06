// Reads the property alert emails that Rightmove, Zoopla, OnTheMarket,
// OpenRent and SpareRoom send to the user, after the user's own mailbox
// forwards them here. Nothing is fetched from those sites: the links are
// kept for the user to open.
//
// The layouts are not documented and change without notice, so this reads
// them loosely: it finds advert links by their URL pattern and reads the
// price, bedrooms, type and address from the text near each link. When an
// email from a portal yields nothing, the caller keeps a copy so the parser
// can be fixed from a real example.

import type { Listing } from "./propertypal.ts";

export interface Portal {
  source: string;
  label: string;
  /** Sender domains (the From header). */
  senders: string[];
  /** Hosts the advert links live on. */
  host: string;
  /** The advert id in a link, or null when it is not an advert link. */
  advertId(u: URL): string | null;
  /** Lets only (OpenRent, SpareRoom). */
  rentOnly?: boolean;
}

const digits = /^\d{4,}$/;
const segs = (u: URL) => u.pathname.split("/").filter(Boolean);

export const portals: Portal[] = [
  {
    source: "rightmove",
    label: "Rightmove",
    senders: ["rightmove.co.uk", "rightmove.com"],
    host: "rightmove.co.uk",
    // /properties/123456789 and /property-to-rent/property-123456789.html
    advertId: (u) => {
      const s = segs(u);
      if (s[0] === "properties" && digits.test(s[1] ?? "")) return s[1];
      return /property-(\d{5,})\.html$/.exec(u.pathname)?.[1] ?? null;
    },
  },
  {
    source: "zoopla",
    label: "Zoopla",
    senders: ["zoopla.co.uk", "zoopla.com"],
    host: "zoopla.co.uk",
    // /to-rent/details/12345678/ and /for-sale/details/12345678/
    advertId: (u) => {
      const s = segs(u);
      const i = s.indexOf("details");
      return i >= 0 && digits.test(s[i + 1] ?? "") ? s[i + 1] : null;
    },
  },
  {
    source: "onTheMarket",
    label: "OnTheMarket",
    senders: ["onthemarket.com"],
    host: "onthemarket.com",
    // /details/12345678/
    advertId: (u) => {
      const s = segs(u);
      const i = s.indexOf("details");
      return i >= 0 && digits.test(s[i + 1] ?? "") ? s[i + 1] : null;
    },
  },
  {
    source: "openRent",
    label: "OpenRent",
    senders: ["openrent.co.uk", "openrent.com"],
    host: "openrent.co.uk",
    rentOnly: true,
    // /property-to-rent/leeds/2-bed-flat-high-street/2345678 and /2345678
    advertId: (u) => {
      const s = segs(u);
      const last = s[s.length - 1] ?? "";
      return (s[0] === "property-to-rent" || s.length === 1) && digits.test(last) ? last : null;
    },
  },
  {
    source: "spareRoom",
    label: "SpareRoom",
    senders: ["spareroom.co.uk", "spareroom.com"],
    host: "spareroom.co.uk",
    rentOnly: true,
    // /flatshare/flatshare_detail.pl?flatshare_id=123 and /flatshare/leeds/hyde-park/1234567
    advertId: (u) => {
      const q = u.searchParams.get("flatshare_id");
      if (q && /^\d+$/.test(q)) return q;
      const s = segs(u);
      return s[0] === "flatshare" && digits.test(s[s.length - 1] ?? "") ? s[s.length - 1] : null;
    },
  },
];

/** The address part of a From header, lower case. */
export function senderAddress(from: string): string {
  const m = /<([^>]+)>/.exec(from);
  return (m ? m[1] : from).trim().toLowerCase();
}

function domainOf(address: string): string {
  return address.slice(address.lastIndexOf("@") + 1);
}

/** The portal that sent an email, by its From header. */
export function portalForSender(from: string): Portal | null {
  const d = domainOf(senderAddress(from));
  return portals.find((p) => p.senders.some((s) => d === s || d.endsWith(`.${s}`))) ?? null;
}

const entities: Record<string, string> = {
  amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ", pound: "£", ndash: "–", mdash: "—",
};

export function decodeEntities(s: string): string {
  return s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (all, e: string) => {
    if (e[0] === "#") {
      const n = e[1] === "x" || e[1] === "X" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
      return Number.isFinite(n) && n > 0 && n < 0x110000 ? String.fromCodePoint(n) : all;
    }
    return entities[e.toLowerCase()] ?? all;
  });
}

/**
 * The advert a link points at. Tracking links that carry the real address
 * in a query parameter or encoded in the path are unwrapped (without being
 * followed).
 */
export function advertIn(href: string, portal?: Portal): { portal: Portal; id: string } | null {
  const candidates = [href];
  try {
    const decoded = decodeURIComponent(href);
    if (decoded !== href) candidates.push(decoded);
  } catch {
    // Not percent-encoded text.
  }
  // A URL carried inside another: each later "http" starts a candidate.
  for (const c of [...candidates]) {
    for (const m of c.matchAll(/https?:\/\//g)) {
      if (m.index! > 0) candidates.push(c.slice(m.index!).split(/[\s"'<>&]/)[0]);
    }
  }
  for (const c of candidates) {
    let u: URL;
    try {
      u = new URL(c);
    } catch {
      continue;
    }
    for (const p of portal ? [portal] : portals) {
      if (u.hostname !== p.host && !u.hostname.endsWith(`.${p.host}`)) continue;
      const id = p.advertId(u);
      if (id) return { portal: p, id };
    }
  }
  return null;
}

/** An advert's public address, without tracking parameters. */
export function advertUrl(p: Portal, id: string): string {
  switch (p.source) {
    case "rightmove":
      return `https://www.rightmove.co.uk/properties/${id}`;
    case "zoopla":
      return `https://www.zoopla.co.uk/property/details/${id}/`;
    case "onTheMarket":
      return `https://www.onthemarket.com/details/${id}/`;
    case "openRent":
      return `https://www.openrent.co.uk/${id}`;
    default:
      return `https://www.spareroom.co.uk/flatshare/flatshare_detail.pl?flatshare_id=${id}`;
  }
}

const types = [
  ["semi-detached", /\bsemi[- ]detached\b/i],
  ["detached", /\bdetached\b/i],
  ["end of terrace", /\bend[- ]of[- ]terrace\b/i],
  ["terraced", /\bterrace[d]?\b/i],
  ["bungalow", /\bbungalow\b/i],
  ["maisonette", /\bmaisonette\b/i],
  ["studio", /\bstudio\b/i],
  ["apartment", /\bapartment\b/i],
  ["flat", /\bflat\b/i],
  ["room", /\b(?:double|single|en-?suite)? ?room\b/i],
  ["house", /\bhouse\b/i],
] as const;

const postcodeRe = /\b([A-Z]{1,2}\d[A-Z\d]?)(?:\s*(\d[A-Z]{2}))?\b/;

/** Price in pounds a month for lets (weekly prices converted), as asked for sales. */
export function readPrice(text: string): { price: number | null; suffix: string; weekly: boolean } {
  const m = /£\s?(\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?\s*(pcm|p\.c\.m\.?|per calendar month|per month|a month|pw|p\.w\.?|per week|a week)?/i.exec(
    text,
  );
  if (!m) return { price: null, suffix: "", weekly: false };
  const n = Number(m[1].replace(/,/g, ""));
  const unit = (m[2] ?? "").toLowerCase();
  const weekly = /w/.test(unit) && !/month/.test(unit);
  return {
    price: weekly ? Math.round((n * 52) / 12) : n,
    suffix: weekly ? "pcm (from weekly)" : /m/.test(unit) ? "pcm" : "",
    weekly,
  };
}

/** Lines that are an address: holding a postcode, or "Street, Town" without a price. */
function readAddress(lines: string[]): string {
  const clean = lines.map((l) => l.trim()).filter((l) => l.length >= 6 && l.length <= 140 && !/£/.test(l));
  return (
    clean.find((l) => postcodeRe.test(l) && /[a-z]/i.test(l.replace(postcodeRe, ""))) ??
    clean.find((l) => /,/.test(l) && !/\b(bed|bedroom|bath|added|reduced|unsubscribe|view)\b/i.test(l)) ??
    ""
  );
}

export interface ParsedEmail {
  portal: Portal | null;
  listings: Listing[];
  /** Links that looked like adverts. */
  adverts: number;
}

/** Text with block tags turned into line breaks, and link and image markers. */
function flatten(html: string): { text: string; links: string[]; images: string[] } {
  const links: string[] = [];
  const images: string[] = [];
  const body = html
    .replace(/<(script|style|head)[\s\S]*?<\/\1>/gi, " ")
    .replace(/<a\b[^>]*?\bhref\s*=\s*(["'])(.*?)\1[^>]*>/gi, (_a, _q, href: string) => {
      links.push(decodeEntities(href));
      return `\u0001L${links.length - 1}\u0001`;
    })
    .replace(/<img\b[^>]*?\bsrc\s*=\s*(["'])(.*?)\1[^>]*>/gi, (_a, _q, src: string) => {
      images.push(decodeEntities(src));
      return `\u0001I${images.length - 1}\u0001`;
    })
    .replace(/<\/(p|div|td|tr|li|h\d|table)>|<br\s*\/?>/gi, "\n")
    .replace(/<[^>]+>/g, " ");
  return { text: decodeEntities(body).replace(/[ \t ]+/g, " "), links, images };
}

const footer = /unsubscribe|manage (your )?alerts|view all|see all|privacy|registered in england|you are receiving/i;

/**
 * The adverts in an alert email. [kind] is the alert's side when the email
 * does not say (lets: "toLet"; sales: "forSale").
 */
export function parseAlertEmail(
  email: { from: string; subject: string; html?: string; text?: string },
  options: { kind?: "toLet" | "forSale" } = {},
): ParsedEmail {
  const sender = portalForSender(email.from);
  const html =
    email.html ??
    (email.text ?? "").replace(/&/g, "&amp;").replace(/<|>/g, " ").replace(/https?:\/\/\S+/g, (u) => `<a href="${u}">`);
  const { text, links, images } = flatten(html);
  // Each advert's first marker; the next advert's first marker ends its block.
  const order: { key: string; portal: Portal; id: string; at: number }[] = [];
  const firstAt = new Map<string, number>();
  for (const m of text.matchAll(/\u0001L(\d+)\u0001/g)) {
    const a = advertIn(links[Number(m[1])], sender ?? undefined);
    if (!a) continue;
    const key = `${a.portal.source}:${a.id}`;
    if (firstAt.has(key)) continue;
    firstAt.set(key, m.index!);
    order.push({ key, portal: a.portal, id: a.id, at: m.index! });
  }
  const subjectSays = /\bto rent\b|\brent(al)?s?\b|\blet(s|ting)?\b/i.test(email.subject)
    ? "toLet"
    : /\bfor sale\b|\bto buy\b|\bsale\b/i.test(email.subject)
      ? "forSale"
      : undefined;
  const listings: Listing[] = [];
  for (let i = 0; i < order.length; i++) {
    const o = order[i];
    let block = text.slice(o.at, i + 1 < order.length ? order[i + 1].at : undefined);
    // The last advert runs into the footer; stop there.
    const f = footer.exec(block);
    if (f) block = block.slice(0, f.index);
    const imgs = [...block.matchAll(/\u0001I(\d+)\u0001/g)]
      .map((m) => images[Number(m[1])])
      .filter((src) => /^https:/.test(src) && !/logo|icon|spacer|pixel|track|\.gif(\?|$)/i.test(src));
    const plain = block.replace(/\u0001[LI]\d+\u0001/g, " ");
    const lines = plain.split("\n").map((l) => l.replace(/\s+/g, " ").trim()).filter(Boolean);
    const flat = lines.join(" · ");
    const money = readPrice(flat);
    const beds = /\bstudio\b/i.test(flat) ? 0 : Number(/(\d+)\s*(?:-\s*)?bed(?:room)?s?\b/i.exec(flat)?.[1] ?? NaN);
    const style = types.find(([, re]) => re.test(flat))?.[0] ?? "";
    const rent =
      o.portal.rentOnly ||
      money.weekly ||
      /pcm|per (calendar )?month|a month/i.test(money.suffix + flat) ||
      (options.kind ?? subjectSays) === "toLet";
    listings.push({
      id: o.key,
      source: o.portal.source,
      sourceId: o.id,
      url: advertUrl(o.portal, o.id),
      address: readAddress(lines),
      price: money.price,
      priceSuffix: money.suffix,
      beds: Number.isFinite(beds) ? beds : null,
      baths: null,
      style,
      furnished: /\bunfurnished\b/i.test(flat) ? "Unfurnished" : /\bfurnished\b/i.test(flat) ? "Furnished" : "",
      heating: "",
      availableFrom: null,
      lat: null,
      lon: null,
      agent: "",
      agentPhone: "",
      image: imgs[0] ?? null,
      images: [...new Set(imgs)],
      status: rent ? "toLet" : "forSale",
      text: flat.slice(0, 600),
    });
  }
  return { portal: sender ?? order[0]?.portal ?? null, listings, adverts: order.length };
}

/** A full postcode, an outward code, or a town name to look up, in that order. */
export function placeToFind(address: string): { postcode?: string; outcode?: string; town?: string } {
  const m = postcodeRe.exec(address.toUpperCase());
  if (m?.[2]) return { postcode: `${m[1]} ${m[2]}` };
  if (m) return { outcode: m[1] };
  const parts = address.split(",").map((s) => s.trim()).filter(Boolean);
  const town = parts.length > 1 ? parts[parts.length - 1] : undefined;
  return town && /^[a-z' -]{3,40}$/i.test(town) ? { town } : {};
}
