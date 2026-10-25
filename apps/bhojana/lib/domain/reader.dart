import 'dart:convert';

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

/// "2 milk", "milk x2", "3x eggs" -> (2, "milk"). Anything else is one.
(int, String) splitQuantity(String text) {
  final t = text.trim();
  final lead = RegExp(r'^(\d{1,3})\s*[x×]?\s+(.+)$', caseSensitive: false).firstMatch(t);
  if (lead != null) return (int.parse(lead[1]!).clamp(1, 999), lead[2]!.trim());
  final trail = RegExp(r'^(.+?)\s+[x×]\s*(\d{1,3})$', caseSensitive: false).firstMatch(t);
  if (trail != null) return (int.parse(trail[2]!).clamp(1, 999), trail[1]!.trim());
  return (1, t);
}
