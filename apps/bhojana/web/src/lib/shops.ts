// The shop catalogue, ported from the native app's lib/domain/shops.dart.
// Ids are what synced prices and the `bhojana.shops` pref hold, so they must
// match the native list exactly; a shop that changes its site needs its entry
// changed in both places.

/// What a shop sells online.
export type Selling = "delivery" | "online" | "browse";

export const SELLING_LABEL: Record<Selling, string> = {
  delivery: "Delivery",
  online: "Online orders",
  browse: "In store only",
};

export interface Shop {
  id: string;
  name: string;
  /// Grocery | Discount | Home | Fashion | Health & beauty | Sport
  kind: string;
  home: string;
  /// The search page, with `{q}` where the words go; absent when the site has
  /// no product search.
  search?: string;
  /// The delivery slot page, for grocers that book slots.
  slots?: string;
  selling: Selling;
  /// The loyalty scheme whose prices show only when signed in.
  loyalty?: string;
}

export const SHOP_KINDS = ["Grocery", "Discount", "Home", "Fashion", "Health & beauty", "Sport"];

export const SHOPS: Shop[] = [
  {
    id: "tesco",
    name: "Tesco",
    kind: "Grocery",
    home: "https://www.tesco.com/groceries/en-GB",
    search: "https://www.tesco.com/groceries/en-GB/search?query={q}",
    slots: "https://www.tesco.com/groceries/en-GB/slots/delivery",
    selling: "delivery",
    loyalty: "Clubcard",
  },
  {
    id: "sainsburys",
    name: "Sainsbury's",
    kind: "Grocery",
    home: "https://www.sainsburys.co.uk/gol-ui/groceries",
    search: "https://www.sainsburys.co.uk/gol-ui/SearchResults/{q}",
    slots: "https://www.sainsburys.co.uk/gol-ui/slot/book",
    selling: "delivery",
    loyalty: "Nectar",
  },
  {
    id: "asda",
    name: "Asda",
    kind: "Grocery",
    home: "https://www.asda.com/groceries",
    search: "https://www.asda.com/groceries/search/{q}",
    slots: "https://www.asda.com/groceries/book-slot",
    selling: "delivery",
    loyalty: "Asda Rewards",
  },
  {
    id: "morrisons",
    name: "Morrisons",
    kind: "Grocery",
    home: "https://groceries.morrisons.com",
    search: "https://groceries.morrisons.com/search?q={q}",
    slots: "https://groceries.morrisons.com/slots",
    selling: "delivery",
    loyalty: "More Card",
  },
  {
    id: "ocado",
    name: "Ocado",
    kind: "Grocery",
    home: "https://www.ocado.com",
    search: "https://www.ocado.com/search?q={q}",
    slots: "https://www.ocado.com/slots",
    selling: "delivery",
  },
  {
    id: "waitrose",
    name: "Waitrose",
    kind: "Grocery",
    home: "https://www.waitrose.com",
    search: "https://www.waitrose.com/ecom/shop/search?searchTerm={q}",
    slots: "https://www.waitrose.com/ecom/bookslot",
    selling: "delivery",
    loyalty: "myWaitrose",
  },
  {
    id: "iceland",
    name: "Iceland",
    kind: "Grocery",
    home: "https://www.iceland.co.uk",
    search: "https://www.iceland.co.uk/search?q={q}",
    slots: "https://www.iceland.co.uk/book-delivery",
    selling: "delivery",
    loyalty: "Bonus Card",
  },
  {
    id: "coop",
    name: "Co-op",
    kind: "Grocery",
    home: "https://www.coop.co.uk",
    search: "https://www.coop.co.uk/products/search?query={q}",
    selling: "online",
    loyalty: "Co-op Membership",
  },
  {
    id: "aldi",
    name: "Aldi",
    kind: "Grocery",
    home: "https://www.aldi.co.uk",
    search: "https://www.aldi.co.uk/results?q={q}",
    selling: "browse",
  },
  {
    id: "lidl",
    name: "Lidl",
    kind: "Grocery",
    home: "https://www.lidl.co.uk",
    search: "https://www.lidl.co.uk/q/search?q={q}",
    selling: "browse",
    loyalty: "Lidl Plus",
  },
  {
    id: "poundland",
    name: "Poundland",
    kind: "Discount",
    home: "https://www.poundland.co.uk",
    search: "https://www.poundland.co.uk/search?q={q}",
    selling: "browse",
  },
  {
    id: "poundstretcher",
    name: "Poundstretcher",
    kind: "Discount",
    home: "https://www.poundstretcher.co.uk",
    search: "https://www.poundstretcher.co.uk/search?q={q}",
    selling: "online",
  },
  {
    id: "homebargains",
    name: "Home Bargains",
    kind: "Discount",
    home: "https://www.homebargains.co.uk",
    search: "https://www.homebargains.co.uk/search?q={q}",
    selling: "online",
  },
  {
    id: "bm",
    name: "B&M",
    kind: "Discount",
    home: "https://www.bmstores.co.uk",
    search: "https://www.bmstores.co.uk/search?q={q}",
    selling: "browse",
  },
  {
    id: "homesense",
    name: "HomeSense",
    kind: "Home",
    home: "https://www.homesense.com",
    selling: "browse",
  },
  {
    id: "tkmaxx",
    name: "TK Maxx",
    kind: "Home",
    home: "https://www.tkmaxx.com/uk/en",
    search: "https://www.tkmaxx.com/uk/en/search?text={q}",
    selling: "online",
  },
  {
    id: "matalan",
    name: "Matalan",
    kind: "Fashion",
    home: "https://www.matalan.co.uk",
    search: "https://www.matalan.co.uk/search?q={q}",
    selling: "online",
  },
  {
    id: "primark",
    name: "Primark",
    kind: "Fashion",
    home: "https://www.primark.com/en-gb",
    search: "https://www.primark.com/en-gb/search?q={q}",
    selling: "browse",
  },
  {
    id: "boots",
    name: "Boots",
    kind: "Health & beauty",
    home: "https://www.boots.com",
    search: "https://www.boots.com/sitesearch?searchTerm={q}",
    selling: "online",
    loyalty: "Advantage Card",
  },
  {
    id: "superdrug",
    name: "Superdrug",
    kind: "Health & beauty",
    home: "https://www.superdrug.com",
    search: "https://www.superdrug.com/search?text={q}",
    selling: "online",
  },
  {
    id: "bodyshop",
    name: "The Body Shop",
    kind: "Health & beauty",
    home: "https://www.thebodyshop.com/en-gb",
    search: "https://www.thebodyshop.com/search?q={q}",
    selling: "online",
  },
  {
    id: "sportsdirect",
    name: "Sports Direct",
    kind: "Sport",
    home: "https://www.sportsdirect.com",
    search: "https://www.sportsdirect.com/searchresults?descriptionfilter={q}",
    selling: "online",
  },
];

const byId = new Map(SHOPS.map((s) => [s.id, s]));

export const shopById = (id: string) => byId.get(id);

/// Shop names for display, unknown ids as they are.
export const shopName = (id: string) => byId.get(id)?.name ?? id;

export const searchable = (s: Shop) => s.search !== undefined;

/// Dart's Uri.encodeComponent leaves the same characters alone as
/// encodeURIComponent does except `!'()*`, which it escapes too.
const encodeComponent = (s: string) =>
  encodeURIComponent(s).replace(/[!'()*]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`);

export const searchUrl = (s: Shop, query: string) => (s.search ?? s.home).replaceAll("{q}", encodeComponent(query.trim()));

/// The shops a first-time user compares: the big grocers.
export const DEFAULT_SHOPS = ["tesco", "sainsburys", "asda", "morrisons", "aldi", "lidl"];
