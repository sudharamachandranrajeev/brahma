import 'dart:convert';
import 'dart:math';

import 'shops.dart';

/// A product a shop's search page listed.
class Offer {
  const Offer({
    required this.shop,
    required this.title,
    required this.pence,
    this.unitPrice = '',
    this.offer = '',
    this.url = '',
    this.inStock = true,
  });

  final String shop;
  final String title;
  final int pence;
  final String unitPrice;
  final String offer;
  final String url;
  final bool inStock;

  Shop? get shopInfo => shopById(shop);
}

/// Searches shops for a product. The app's searcher loads each shop's page
/// in a hidden web view, signed in with the user's own shop session.
abstract class PriceSearcher {
  /// Whether this device can read shop pages itself (it needs a web view).
  bool get available;

  Future<List<Offer>> search(Shop shop, String query);
}

/// Turns the reader script's JSON into offers, dropping anything unusable.
List<Offer> parseOffers(String shop, Object? json) {
  final raw = json is String ? jsonDecode(json) : json;
  if (raw is! List) return const [];
  final out = <Offer>[];
  for (final r in raw) {
    if (r is! Map) continue;
    final title = '${r['title'] ?? ''}'.trim();
    final pence = r['pence'];
    if (title.isEmpty || pence is! num || pence <= 0) continue;
    out.add(
      Offer(
        shop: shop,
        title: title,
        pence: pence.round(),
        unitPrice: '${r['unit'] ?? ''}',
        offer: '${r['offer'] ?? ''}',
        url: '${r['url'] ?? ''}',
        inStock: r['inStock'] != false,
      ),
    );
  }
  return out;
}

/// How well [title] matches [query]: the share of the query's words it holds.
double relevance(String query, String title) {
  final words = _words(query);
  if (words.isEmpty) return 0;
  final t = _words(title).toSet();
  return words.where(t.contains).length / words.length;
}

List<String> _words(String s) => s
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9]+'))
    .where((w) => w.length > 1 || RegExp(r'\d').hasMatch(w))
    .toList();

/// The offers worth showing for [query], best match first, then cheapest.
List<Offer> rank(String query, List<Offer> offers) {
  final scored = [
    for (final o in offers)
      if (relevance(query, o.title) >= 0.5) (o, relevance(query, o.title)),
  ];
  scored.sort((a, b) {
    final r = b.$2.compareTo(a.$2);
    return r != 0 ? r : a.$1.pence.compareTo(b.$1.pence);
  });
  return [for (final s in scored) s.$1];
}

/// The product Bhojana picks for [query] by itself: the best in-stock match,
/// cheapest among equals. Null when nothing on the page matches.
Offer? autoPick(String query, List<Offer> offers) => rank(query, offers).where((o) => o.inStock).firstOrNull;

/// A pack size: millilitres (kind 'ml') or grams (kind 'g').
typedef PackSize = ({double amount, String kind});

final _sizeRe = RegExp(
  r'(?:(\d{1,2})\s*[x×]\s*)?(\d+(?:\.\d+)?)\s*(ml|cl|l|ltr|litres?|liters?|g|kg|pints?|pt)\b',
  caseSensitive: false,
);

/// The pack size written in [title] ("2.272L, 4 Pints", "6 x 330ml", "1kg"),
/// or null when it has none.
PackSize? sizeOf(String title) {
  final m = _sizeRe.firstMatch(title);
  if (m == null) return null;
  final n = double.parse(m[2]!) * (m[1] == null ? 1 : int.parse(m[1]!));
  return switch (m[3]!.toLowerCase()) {
    'ml' => (amount: n, kind: 'ml'),
    'cl' => (amount: n * 10, kind: 'ml'),
    'g' => (amount: n, kind: 'g'),
    'kg' => (amount: n * 1000, kind: 'g'),
    'pint' || 'pints' || 'pt' => (amount: n * 568.26, kind: 'ml'),
    _ => (amount: n * 1000, kind: 'ml'),
  };
}

/// Whether two sizes are the same pack, give or take rounding (4 pints is
/// 2.272 litres; some shops call it 2.27L).
bool sameSize(PackSize? a, PackSize? b) =>
    a != null && b != null && a.kind == b.kind && (a.amount - b.amount).abs() <= 0.04 * a.amount;

/// Picks one product for [query] at each shop so the shops can be compared
/// fairly: where the shops sell it in different sizes, the size the most
/// shops have (or the one the query names) is taken everywhere it is sold,
/// cheapest first. A shop without that size gets its best match; a shop
/// whose best match is weaker than the others' gets nothing.
Map<String, Offer> pickAcross(String query, Map<String, List<Offer>> byShop) {
  final cands = <String, List<Offer>>{};
  for (final MapEntry(key: shop, value: offers) in byShop.entries) {
    final ranked = rank(query, offers).where((o) => o.inStock).toList();
    if (ranked.isEmpty) continue;
    // Only the best-matching products: "milk" should not become milkshake.
    final top = relevance(query, ranked.first.title);
    cands[shop] = [
      for (final o in ranked)
        if (relevance(query, o.title) == top) o,
    ];
  }
  // A shop whose best is a weaker match than other shops' (no Heinz at Aldi)
  // sells something else: leave it out rather than compare unlike products.
  final best = cands.values.map((c) => relevance(query, c.first.title)).fold(0.0, max);
  cands.removeWhere((_, c) => relevance(query, c.first.title) < best);
  var target = sizeOf(query);
  if (target == null) {
    // The size the most shops sell; among equals, the smallest.
    final sizes = [
      for (final c in cands.values)
        for (final o in c) ?sizeOf(o.title),
    ]..sort((a, b) => a.amount.compareTo(b.amount));
    var most = 0;
    for (final s in sizes) {
      final shops = cands.values.where((c) => c.any((o) => sameSize(sizeOf(o.title), s))).length;
      if (shops > most) (most, target) = (shops, s);
    }
  }
  return {
    for (final MapEntry(key: shop, value: c) in cands.entries)
      shop:
          ([
            ...c.where((o) => sameSize(sizeOf(o.title), target)),
          ]..sort((a, b) => a.pence.compareTo(b.pence))).firstOrNull ??
          c.first,
  };
}

/// Reads the products on a shop's search page, whatever shop it is. It
/// trusts schema.org Product data when the page has it, and otherwise looks
/// for product links whose tile shows a £ price. It returns JSON text.
const readerScript = r'''
(() => {
  const out = [], seen = new Set();
  const unitRe = /(£\s?\d+(?:\.\d+)?|\d+(?:\.\d+)?p)\s*(?:\/|per)\s*(?:\d+\s?)?[a-z]+/gi;
  const priceRe = /£\s?(\d{1,4}(?:\.\d{1,2})?)|(?:^|\s)(\d{1,3})p\b/g;
  const offerRe = /(clubcard price|nectar price|rollback|asda price|more card price|lidl plus|\b\d+ for £\s?\d+(?:\.\d\d)?|any \d+ for|half price|buy \d+ get \d+|save £\s?\d+(?:\.\d\d)?|\d+% off|was £\s?\d+(?:\.\d\d)?)/i;
  const noStockRe = /out of stock|sold out|currently unavailable|not available/i;
  const add = (title, pence, url, unit, offer, inStock) => {
    title = (title || '').replace(/\s+/g, ' ').trim();
    if (title.length < 3 || !(pence > 0)) return;
    const key = title.toLowerCase() + '|' + pence;
    if (seen.has(key)) return;
    seen.add(key);
    out.push({title, pence, url: url || '', unit: unit || '', offer: offer || '', inStock});
  };
  const walk = (n) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) return n.forEach(walk);
    const types = [].concat(n['@type'] || []);
    if (types.includes('Product') && n.name) {
      const o = [].concat(n.offers || [])[0] || {};
      const p = parseFloat(o.price ?? o.lowPrice);
      const stock = o.availability ? !/OutOfStock|SoldOut/i.test(o.availability) : true;
      add(n.name, Math.round(p * 100), n.url || o.url, '', '', stock);
    }
    for (const k in n) walk(n[k]);
  };
  for (const s of document.querySelectorAll('script[type="application/ld+json"]')) {
    try { walk(JSON.parse(s.textContent)); } catch (e) {}
  }
  const tiles = new Set();
  for (const a of document.querySelectorAll('a[href]')) {
    let el = a;
    for (let i = 0; i < 7 && el && el !== document.body; i++, el = el.parentElement) {
      const text = el.innerText || '';
      if (text.length > 700) break;
      const units = text.match(unitRe) || [];
      let rest = text;
      for (const u of units) rest = rest.replace(u, ' ');
      const prices = [...rest.matchAll(priceRe)].map((m) => m[1] ? Math.round(parseFloat(m[1]) * 100) : parseInt(m[2]));
      if (!prices.length) continue;
      // A tile already read, or the list around it: not a product of its own.
      if ([...tiles].some((t) => el.contains(t))) break;
      tiles.add(el);
      const lines = text.split('\n').map((l) => l.trim()).filter((l) => l && !/£|\dp\b/.test(l) && !offerRe.test(l));
      const label = a.getAttribute('aria-label') || a.getAttribute('title') || '';
      let title = (a.innerText || '').trim().length > 5 ? a.innerText : (label || lines.sort((x, y) => y.length - x.length)[0]);
      const offer = (text.match(offerRe) || [''])[0];
      title = (title || '').replace(/\(?[^()]*\bper\b[^()]*\)|\([^()]*\/[^()]*\)|(for )?(£|GBP) ?\d+(\.\d+)?/g, ' ');
      add(title, Math.min(...prices), a.href, units[0] || '', offer, !noStockRe.test(text));
      break;
    }
  }
  return JSON.stringify(out.slice(0, 40));
})()
''';

/// Presses the first "Add" or "Add to basket/trolley" button on the page,
/// the way the user would. Returns 'added', or 'none' when no such button.
const addFirstScript = r'''
(() => {
  const re = /^\s*(add|add to (basket|trolley|bag|cart))\b/i;
  for (const b of document.querySelectorAll('button, [role="button"], input[type="submit"]')) {
    const label = (b.getAttribute('aria-label') || b.innerText || b.value || '').trim();
    if (!re.test(label) || b.disabled || b.offsetParent === null) continue;
    b.scrollIntoView({block: 'center'});
    b.click();
    return 'added';
  }
  return 'none';
})()
''';

/// Presses Add on the tile of one product: the one at [url], or else the one
/// titled [title]. It marks that tile so [moreScript] can raise the
/// quantity. Returns 'added', 'no-button' (the product is there but has no
/// Add button, often because the shop wants a sign-in) or 'not-found'.
String addScript({required String url, required String title}) =>
    '(() => {\n  const want = ${jsonEncode({'url': url, 'title': title})};\n$_addBody';

const _addBody = r'''
  const addRe = /^\s*\+?\s*(add|add to (basket|trolley|bag|cart))\b/i;
  const notRe = /favourite|wish|list|compare|review|note/i;
  const label = (b) => (b.getAttribute('aria-label') || b.innerText || b.value || '').trim();
  const usable = (b) => !b.disabled && b.offsetParent !== null && addRe.test(label(b)) && !notRe.test(label(b));
  const norm = (s) => (s || '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
  const path = (u) => { try { return new URL(u, location.href).pathname.replace(/\/$/, ''); } catch (e) { return ''; } };
  const links = [...document.querySelectorAll('a[href]')];
  const p = want.url ? path(want.url) : '';
  let found = p.length > 1 ? links.filter((a) => path(a.href) === p) : [];
  if (!found.length) {
    const t = norm(want.title);
    found = links.filter((a) => {
      const n = norm(a.innerText || a.getAttribute('aria-label') || a.getAttribute('title'));
      return n.length > 2 && (n === t || n.includes(t) || (n.length > 8 && t.includes(n)));
    });
  }
  for (const old of document.querySelectorAll('[data-bhojana-tile]')) old.removeAttribute('data-bhojana-tile');
  for (const a of found) {
    let el = a;
    for (let i = 0; i < 8 && el && el !== document.body; i++, el = el.parentElement) {
      const buttons = [...el.querySelectorAll('button, [role="button"], input[type="submit"]')].filter(usable);
      // Several Add buttons: this is the list around many tiles.
      if (buttons.length > 1) break;
      if (buttons.length === 1) {
        el.setAttribute('data-bhojana-tile', '1');
        buttons[0].scrollIntoView({block: 'center'});
        buttons[0].click();
        return 'added';
      }
    }
  }
  return found.length ? 'no-button' : 'not-found';
})()
''';

/// Adds one more of the product [addScript] last added, with the tile's own
/// plus (or Add) button. Returns 'more', or 'none' when the tile has none.
const moreScript = r'''
(() => {
  const tile = document.querySelector('[data-bhojana-tile]');
  if (!tile) return 'none';
  const re = /^\s*\+\s*$|increase|increment|add (one )?more|add another|plus one|^\s*\+?\s*add\b/i;
  const notRe = /favourite|wish|list|compare|decrease|remove|minus/i;
  for (const b of tile.querySelectorAll('button, [role="button"]')) {
    const label = (b.getAttribute('aria-label') || b.innerText || '').trim();
    if (b.disabled || b.offsetParent === null || !re.test(label) || notRe.test(label)) continue;
    b.click();
    return 'more';
  }
  return 'none';
})()
''';

/// "2 milk", "milk x2", "3x eggs" -> (2, "milk"). Anything else is one.
(int, String) splitQuantity(String text) {
  final t = text.trim();
  final lead = RegExp(r'^(\d{1,3})\s*[x×]?\s+(.+)$', caseSensitive: false).firstMatch(t);
  if (lead != null) return (int.parse(lead[1]!).clamp(1, 999), lead[2]!.trim());
  final trail = RegExp(r'^(.+?)\s+[x×]\s*(\d{1,3})$', caseSensitive: false).firstMatch(t);
  if (trail != null) return (int.parse(trail[2]!).clamp(1, 999), trail[1]!.trim());
  return (1, t);
}
