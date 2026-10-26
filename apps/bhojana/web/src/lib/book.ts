// Bhojana's write path and the reads the pages share, as the native app's
// lib/domain/book.dart. Rows are kept in their SQL shape (see schema.ts);
// these types are the readable view of them.
import type { Row } from "./schema.ts";
import { newId, type Store } from "./store.ts";
import { DEFAULT_SHOPS, SHOPS, shopById, type Shop } from "./shops.ts";

export interface ShopList {
  id: string;
  name: string;
  created: string;
}

export interface Item {
  id: string;
  listId: string;
  name: string;
  qty: number;
  note: string;
  done: boolean;
  ord: number;
  added: string;
}

export interface Price {
  id: string;
  itemId: string | null;
  query: string;
  shop: string;
  title: string;
  pence: number;
  unitPrice: string;
  offer: string;
  url: string;
  inStock: boolean;
  day: string;
  /// signed-in (read from the user's own shop session) | web | typed
  source: string;
}

/// A list costed at one shop from the latest price kept for each item.
export interface ShopCost {
  shop: string;
  pence: number;
  priced: number;
  items: number;
}

export const complete = (c: ShopCost) => c.priced === c.items;

/// Synced preference keys.
export const POSTCODE_PREF = "bhojana.postcode";
export const SHOPS_PREF = "bhojana.shops";

const live = (r: Row) => r.deleted !== 1;

export const toList = (r: Row): ShopList => ({ id: r.id as string, name: r.name as string, created: r.created as string });

export const toItem = (r: Row): Item => ({
  id: r.id as string,
  listId: r.list_id as string,
  name: r.name as string,
  qty: r.qty as number,
  note: (r.note as string) ?? "",
  done: r.done === 1,
  ord: r.ord as number,
  added: r.added as string,
});

export const toPrice = (r: Row): Price => ({
  id: r.id as string,
  itemId: (r.item_id as string | null) ?? null,
  query: r.query as string,
  shop: r.shop as string,
  title: r.title as string,
  pence: r.pence as number,
  unitPrice: (r.unit_price as string) ?? "",
  offer: (r.offer as string) ?? "",
  url: (r.url as string) ?? "",
  inStock: r.in_stock !== 0,
  day: r.day as string,
  source: (r.source as string) ?? "web",
});

/// Today as yyyy-MM-dd in local time, as brahma_core's today().
export function today(d = new Date()): string {
  const p = (n: number, w = 2) => String(n).padStart(w, "0");
  return `${p(d.getFullYear(), 4)}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/// "2026-10-05" as "5 Oct 2026", as the native niceDate.
export function niceDate(iso: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
  return m ? `${Number(m[3])} ${MONTHS[Number(m[2]) - 1]} ${m[1]}` : iso;
}

/// "2 milk", "milk x2", "3x eggs" -> [2, "milk"]. Anything else is one.
export function splitQuantity(text: string): [number, string] {
  const t = text.trim();
  const clamp = (n: number) => Math.min(999, Math.max(1, n));
  const lead = /^(\d{1,3})\s*[x×]?\s+(.+)$/i.exec(t);
  if (lead) return [clamp(parseInt(lead[1], 10)), lead[2].trim()];
  const trail = /^(.+?)\s+[x×]\s*(\d{1,3})$/i.exec(t);
  if (trail) return [clamp(parseInt(trail[2], 10)), trail[1].trim()];
  return [1, t];
}

/// Items in list order: still to buy first, then by position.
export const sortItems = (items: Item[]) =>
  [...items].sort((a, b) => Number(a.done) - Number(b.done) || a.ord - b.ord);

/// The latest price per (item, shop): the one a list is costed with.
export function latestPrices(prices: Price[]): Map<string, Price> {
  const out = new Map<string, Price>();
  for (const p of prices) {
    if (p.itemId === null) continue;
    const key = `${p.itemId}\u0000${p.shop}`;
    const had = out.get(key);
    // Newest day wins; on the same day the cheaper one.
    if (!had || p.day > had.day || (p.day === had.day && p.pence < had.pence)) out.set(key, p);
  }
  return out;
}

/// What [items] cost at each shop that has a price for any of them, cheapest
/// complete basket first.
export function costByShop(items: Item[], prices: Price[]): ShopCost[] {
  const latest = latestPrices(prices);
  const shopIds = new Set([...latest.values()].map((p) => p.shop));
  const out: ShopCost[] = [];
  for (const s of shopIds) {
    let pence = 0, priced = 0;
    for (const i of items) {
      const p = latest.get(`${i.id}\u0000${s}`);
      if (!p) continue;
      pence += p.pence * i.qty;
      priced++;
    }
    if (priced > 0) out.push({ shop: s, pence, priced, items: items.length });
  }
  // Dart's List.sort is not stable either, so ties may order differently;
  // breaking them by shop id keeps this page steady between renders.
  return out.sort((a, b) => b.priced - a.priced || a.pence - b.pence || (a.shop < b.shop ? -1 : 1));
}

/// The cheapest kept price for one item, at any shop.
export function bestPrice(itemId: string, prices: Price[]): Price | null {
  let best: Price | null = null;
  for (const p of latestPrices(prices).values()) {
    if (p.itemId === itemId && p.inStock && (!best || p.pence < best.pence)) best = p;
  }
  return best;
}

/// Pence as "£1.25" or "85p".
export const pounds = (pence: number) => (pence < 100 ? `${pence}p` : `£${(pence / 100).toFixed(2)}`);

/// "1.25", "£1.25" or "85p" as pence; null when it is not a price.
export function parsePounds(text: string): number | null {
  const t = text.trim().replace(/,/g, "");
  const pence = /^(\d{1,4})\s*p$/i.exec(t);
  if (pence) return Number(pence[1]) || null;
  const m = /^£?\s*(\d{0,5}(?:\.\d{1,2})?)$/.exec(t);
  if (!m || m[1] === "" || m[1] === ".") return null;
  const n = Math.round(Number(m[1]) * 100);
  return n > 0 ? n : null;
}

const POSTCODE = /^[A-Z]{1,2}\d[A-Z\d]? ?\d[A-Z]{2}$/;

/// A tidy UK postcode, "" for none, or null when it is not one.
export function tidyPostcode(text: string): string | null {
  const p = text.trim().toUpperCase().replace(/\s+/g, " ");
  return p === "" || POSTCODE.test(p) ? p : null;
}

/// The shops the user compares, in catalogue order.
export function myShops(raw: string | null): Shop[] {
  const ids = new Set(raw === null ? DEFAULT_SHOPS : raw.split(",").filter((s) => s !== ""));
  return SHOPS.filter((s) => ids.has(s.id));
}

export interface Snapshot {
  lists: ShopList[];
  items: Item[];
  prices: Price[];
  prefs: Map<string, string>;
}

export class ShoppingBook {
  readonly store: Store;
  constructor(store: Store) {
    this.store = store;
  }

  /// Everything the pages show, read in one go (a household's lists are small).
  async snapshot(): Promise<Snapshot> {
    const [lists, items, prices, prefs] = await Promise.all([
      this.store.all("food_lists"),
      this.store.all("food_items"),
      this.store.all("food_prices"),
      this.store.all("prefs"),
    ]);
    return {
      lists: lists.filter(live).map(toList).sort((a, b) => (a.created < b.created ? -1 : a.created > b.created ? 1 : a.name < b.name ? -1 : a.name > b.name ? 1 : 0)),
      items: items.filter(live).map(toItem),
      prices: prices
        .filter(live)
        .map(toPrice)
        .sort((a, b) => (a.day < b.day ? 1 : a.day > b.day ? -1 : a.pence - b.pence)),
      prefs: new Map(prefs.filter(live).map((r) => [r.id as string, r.value as string])),
    };
  }

  async items(listId: string): Promise<Item[]> {
    return sortItems((await this.store.all("food_items")).filter(live).map(toItem).filter((i) => i.listId === listId));
  }

  // ---- lists ----

  async addList(name: string, day = today()): Promise<string> {
    const id = newId();
    await this.store.save("food_lists", { id, name: name.trim(), created: day });
    return id;
  }

  renameList(id: string, name: string) {
    return this.store.save("food_lists", { id, name: name.trim() });
  }

  /// Deletes a list with its items; prices kept for them stay for history.
  async removeList(id: string) {
    const items = await this.items(id);
    await this.store.removeMany([...items.map((i): ["food_items", string] => ["food_items", i.id]), ["food_lists", id]]);
  }

  // ---- items ----

  /// Adds "2 milk" as two of milk at the end of the list.
  async addItem(listId: string, text: string, day = today()): Promise<string> {
    const [qty, name] = splitQuantity(text);
    const last = await this.items(listId);
    const ord = last.length === 0 ? 0 : Math.max(...last.map((i) => i.ord)) + 1;
    const id = newId();
    await this.store.save("food_items", { id, list_id: listId, name, qty, ord, added: day });
    return id;
  }

  saveItem(i: Item) {
    return this.store.save("food_items", {
      id: i.id,
      list_id: i.listId,
      name: i.name,
      qty: i.qty,
      note: i.note,
      done: i.done ? 1 : 0,
      ord: i.ord,
      added: i.added,
    });
  }

  tick(i: Item, done: boolean) {
    return this.saveItem({ ...i, done });
  }

  removeItem(id: string) {
    return this.store.remove("food_items", id);
  }

  /// Unticks every item, for the next shop.
  async resetList(listId: string) {
    const done = (await this.items(listId)).filter((i) => i.done);
    if (done.length) await this.store.saveMany(done.map((i) => ["food_items", { id: i.id, done: 0 }]));
  }

  /// Moves [itemId] one place up (-1) or down (+1) among the items still to
  /// buy, renumbering only the rows whose position changes.
  async move(listId: string, itemId: string, by: -1 | 1) {
    const all = await this.items(listId);
    const group = all.filter((i) => i.done === all.find((x) => x.id === itemId)?.done);
    const at = group.findIndex((i) => i.id === itemId);
    const to = at + by;
    if (at < 0 || to < 0 || to >= group.length) return;
    [group[at], group[to]] = [group[to], group[at]];
    // Renumber from the group's lowest position, so two devices that both
    // added at the same spot (equal ord) still end up in a definite order.
    const base = Math.min(...group.map((i) => i.ord));
    const changed = group.map((i, n) => ({ i, ord: base + n })).filter(({ i, ord }) => i.ord !== ord);
    if (changed.length) await this.store.saveMany(changed.map(({ i, ord }) => ["food_items", { id: i.id, ord }]));
  }

  // ---- prices ----

  /// Keeps a price the user read off a shelf, a leaflet or a site.
  async keepTypedPrice(o: { itemId: string | null; query: string; shop: string; title: string; pence: number }) {
    await this.store.save("food_prices", {
      id: newId(),
      item_id: o.itemId,
      query: o.query,
      shop: o.shop,
      title: o.title,
      pence: Math.round(o.pence),
      unit_price: "",
      offer: "",
      url: "",
      in_stock: 1,
      day: today(),
      source: "typed",
    });
  }

  /// Keeps a price the extension read off a shop's page (source 'web', as the
  /// native compare page does).
  async keepOffer(o: {
    itemId: string | null;
    query: string;
    shop: string;
    offer: { title: string; pence: number; unit: string; offer: string; url: string; inStock: boolean };
  }) {
    await this.store.save("food_prices", {
      id: newId(),
      item_id: o.itemId,
      query: o.query,
      shop: o.shop,
      title: o.offer.title,
      pence: Math.round(o.offer.pence),
      unit_price: o.offer.unit,
      offer: o.offer.offer,
      url: o.offer.url,
      in_stock: o.offer.inStock ? 1 : 0,
      day: today(),
      source: "web",
    });
  }

  removePrice(id: string) {
    return this.store.remove("food_prices", id);
  }

  // ---- prefs ----

  setPref(key: string, value: string) {
    return this.store.save("prefs", { id: key, value });
  }
}

export { shopById };
