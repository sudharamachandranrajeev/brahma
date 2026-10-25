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

  test('pounds reads like a shelf label', () {
    expect(pounds(85), '85p');
    expect(pounds(100), '£1.00');
    expect(pounds(1250), '£12.50');
  });
}
