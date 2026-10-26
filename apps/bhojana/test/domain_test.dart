import 'package:bhojana/domain/book.dart';
import 'package:bhojana/domain/reader.dart';
import 'package:bhojana/domain/shops.dart';
import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  test('quantities are read from the front or the back', () {
    expect(splitQuantity('2 milk'), (2, 'milk'));
    expect(splitQuantity('3x eggs'), (3, 'eggs'));
    expect(splitQuantity('bread x 4'), (4, 'bread'));
    expect(splitQuantity('7up'), (1, '7up'));
    expect(splitQuantity('washing-up liquid'), (1, 'washing-up liquid'));
  });

  test('reader output is parsed and junk dropped', () {
    final o = parseOffers(
      'tesco',
      '[{"title":"Milk 4 pints","pence":155,"unit":"39p/litre","offer":"Clubcard Price"},'
          '{"title":"","pence":100},{"title":"Free","pence":0},{"title":"Eggs","pence":"x"},'
          '{"title":"Cream","pence":120,"inStock":false}]',
    );
    expect(o.map((x) => x.title), ['Milk 4 pints', 'Cream']);
    expect(o.first.offer, 'Clubcard Price');
    expect(o.last.inStock, isFalse);
    expect(parseOffers('tesco', null), isEmpty);
  });

  test('ranking puts the best match first, then the cheapest', () {
    const a = Offer(shop: 's', title: 'Semi Skimmed Milk 2 Pints', pence: 120);
    const b = Offer(shop: 's', title: 'Organic Semi Skimmed Milk 4 Pints', pence: 210);
    const c = Offer(shop: 's', title: 'Semi Skimmed Milk 4 Pints', pence: 155);
    const d = Offer(shop: 's', title: 'Chocolate', pence: 50);
    expect(rank('semi skimmed milk 4 pints', [a, b, c, d]), [c, b, a]);
    const gone = Offer(shop: 's', title: 'Semi Skimmed Milk 4 Pints', pence: 99, inStock: false);
    expect(autoPick('semi skimmed milk 4 pints', [gone, a, b, c, d]), c);
    expect(autoPick('oat milk', [d]), isNull);
  });

  test('pack sizes are read and matched across shops', () {
    expect(sizeOf('Tesco Semi Skimmed Milk 2.272L, 4 Pints'), (amount: 2272.0, kind: 'ml'));
    expect(sameSize(sizeOf('Milk 4 Pints'), sizeOf('Milk 2.27L')), isTrue);
    expect(sizeOf('Coke 6 x 330ml'), (amount: 1980.0, kind: 'ml'));
    expect(sizeOf('Basmati Rice 1kg'), (amount: 1000.0, kind: 'g'));
    expect(sizeOf('Co-op 1 Pint Fresh Semi-skimmed Milk 568ml')?.amount, closeTo(568, 1));
    expect(sizeOf('Bananas Loose'), isNull);
    expect(sameSize(sizeOf('Milk 1L'), sizeOf('Milk 1kg')), isFalse);
  });

  test('every shop gets the same size where it sells it', () {
    const q = 'semi skimmed milk';
    final picks = pickAcross(q, {
      'tesco': const [
        Offer(shop: 'tesco', title: 'Semi Skimmed UHT Milk 1L', pence: 65),
        Offer(shop: 'tesco', title: 'Semi Skimmed Milk 4 Pints', pence: 155),
        Offer(shop: 'tesco', title: 'Semi Skimmed Milk 2 Pints', pence: 120),
      ],
      'aldi': const [
        Offer(shop: 'aldi', title: 'Cowbelle Semi Skimmed Milk 2.272L', pence: 145),
        Offer(shop: 'aldi', title: 'Semi Skimmed Milk 1 Pint', pence: 85),
        Offer(shop: 'aldi', title: 'Milk Chocolate', pence: 40),
      ],
      'coop': const [Offer(shop: 'coop', title: 'Semi Skimmed Milk 4 Pints', pence: 175)],
      'lidl': const [Offer(shop: 'lidl', title: 'Semi Skimmed Milk', pence: 99)],
      'asda': const [Offer(shop: 'asda', title: 'Chocolate', pence: 99)],
    });
    // 4 pints is the size three shops sell; Lidl has no size, so its match.
    expect(
      {for (final e in picks.entries) e.key: e.value.pence},
      {'tesco': 155, 'aldi': 145, 'coop': 175, 'lidl': 99},
    );
    // A shop without the brand is left out, not compared with another product.
    expect(
      pickAcross('heinz baked beans', {
        'tesco': const [Offer(shop: 'tesco', title: 'Heinz Baked Beans 415g', pence: 140)],
        'aldi': const [Offer(shop: 'aldi', title: 'Everyday Essentials Baked Beans 410g', pence: 27)],
      }).keys,
      ['tesco'],
    );
    // A size in the query wins.
    expect(
      pickAcross('semi skimmed milk 1 pint', {
        'aldi': const [
          Offer(shop: 'aldi', title: 'Semi Skimmed Milk 2.272L', pence: 145),
          Offer(shop: 'aldi', title: 'Semi Skimmed Milk 1 Pint', pence: 85),
        ],
      })['aldi']?.pence,
      85,
    );
  });

  test('every shop search address carries the query', () {
    for (final s in shops.where((s) => s.searchable)) {
      expect(s.searchUrl('baked beans'), contains('baked%20beans'), reason: s.name);
      expect(Uri.parse(s.searchUrl('x')).scheme, 'https', reason: s.name);
    }
    expect({for (final s in shops) s.id}.length, shops.length);
    for (final id in defaultShops) {
      expect(shopById(id), isNotNull);
    }
  });

  test('a list is costed per shop from the latest price of each item', () async {
    final store = await Store.open(memoryDatabase());
    final book = ShoppingBook(store);
    final list = await book.addList('Weekly', today: '2026-10-25');
    final milk = await book.addItem(list, '2 milk', today: '2026-10-25');
    final bread = await book.addItem(list, 'bread', today: '2026-10-25');
    await book.keepOffer(
      const Offer(shop: 'tesco', title: 'Milk', pence: 150),
      itemId: milk,
      query: 'milk',
      source: 'web',
    );
    await book.keepOffer(
      const Offer(shop: 'tesco', title: 'Bread', pence: 100),
      itemId: bread,
      query: 'bread',
      source: 'web',
    );
    await book.keepOffer(
      const Offer(shop: 'aldi', title: 'Milk', pence: 120),
      itemId: milk,
      query: 'milk',
      source: 'web',
    );
    final items = await book.items(list);
    expect(items.map((i) => (i.name, i.qty)), [('milk', 2), ('bread', 1)]);
    final costs = costByShop(items, await book.prices());
    expect(costs.map((c) => (c.shop, c.pence, c.priced)), [('tesco', 400, 2), ('aldi', 240, 1)]);
    expect(bestPrice(milk, await book.prices())?.shop, 'aldi');
    await book.removeList(list);
    expect(await book.items(list), isEmpty);
    expect(await book.prices(), hasLength(3));
    await book.setPref('bhojana.postcode', 'BT74 7AA');
    expect(await book.pref('bhojana.postcode'), 'BT74 7AA');
    await store.db.close();
  });

  test('a pick kept today replaces the one kept earlier today at the same shop', () async {
    final store = await Store.open(memoryDatabase());
    final book = ShoppingBook(store);
    final list = await book.addList('Weekly', today: '2026-10-25');
    final milk = await book.addItem(list, 'milk', today: '2026-10-25');
    await book.keepOffer(
      const Offer(shop: 'tesco', title: 'Milk 1L', pence: 90),
      itemId: milk,
      query: 'milk',
      source: 'auto',
    );
    await book.keepOffer(
      const Offer(shop: 'aldi', title: 'Milk 1L', pence: 85),
      itemId: milk,
      query: 'milk',
      source: 'auto',
    );
    await book.keepOffer(
      const Offer(shop: 'tesco', title: 'Milk 4 pints', pence: 155),
      itemId: milk,
      query: 'milk',
      source: 'web',
    );
    final kept = await book.prices();
    expect(kept.map((p) => (p.shop, p.pence)).toSet(), {('tesco', 155), ('aldi', 85)});
    await store.db.close();
  });

  test('the cheapest shop is named on the whole list, else like for like', () async {
    final store = await Store.open(memoryDatabase());
    final book = ShoppingBook(store);
    final list = await book.addList('Weekly', today: '2026-10-25');
    final milk = await book.addItem(list, '2 milk', today: '2026-10-25');
    final bread = await book.addItem(list, 'bread', today: '2026-10-25');
    Future<void> price(String shop, String item, int pence) => book.keepOffer(
      Offer(shop: shop, title: item, pence: pence),
      itemId: item,
      query: item,
      source: 'auto',
    );
    await price('tesco', milk, 150);
    await price('tesco', bread, 100);
    await price('aldi', milk, 120);
    final items = await book.items(list);
    var prices = await book.prices();
    // Only Tesco has both; on the one item they share, Aldi is cheaper.
    var v = cheapestShop(items, prices, costByShop(items, prices))!;
    expect((v.best, v.pence, v.items, v.runnerUp, v.saving), ('aldi', 240, 1, 'tesco', 60));

    await price('aldi', bread, 110);
    await price('lidl', milk, 100);
    await price('lidl', bread, 150);
    prices = await book.prices();
    v = cheapestShop(items, prices, costByShop(items, prices))!;
    // Whole list: Aldi and Lidl £3.50 each, Tesco £4.00.
    expect((v.items, v.pence), (2, 350));
    expect(v.saving, 0);
    expect(cheapestShop(items, const [], const []), isNull);
    await store.db.close();
  });

  test('pounds reads like a shelf label', () {
    expect(pounds(85), '85p');
    expect(pounds(100), '£1.00');
    expect(pounds(1250), '£12.50');
  });
}
