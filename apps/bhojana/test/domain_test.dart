import 'package:bhojana/db/database.dart';
import 'package:bhojana/domain/aisles.dart';
import 'package:bhojana/domain/book.dart';
import 'package:bhojana/domain/reader.dart';
import 'package:bhojana/domain/shops.dart';
import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'seed.dart';
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

  test('multi-buys are read at the shops whose deals are checked, and only when cheaper', () {
    expect(multiBuyAt('tesco', 'Any 2 for £2 Clubcard Price', 140)?.pence, 200);
    expect(multiBuyAt('tesco', 'Any 2 for £2 Clubcard Price', 140)?.each, 100);
    expect(multiBuyAt('iceland', 'Buy 2 Get 1 FREE', 250)?.count, 3);
    expect(multiBuyAt('iceland', 'Buy 2 Get 1 FREE', 250)?.pence, 500);
    expect(multiBuyAt('asda', '3 for 2', 100)?.pence, 200);
    expect(multiBuyAt('asda', '2 for 50p', 30)?.pence, 50);
    // Not a saving, not a deal, or a shop whose deals are not checked yet.
    expect(multiBuyAt('asda', 'Any 2 for £8', 400), isNull);
    expect(multiBuyAt('tesco', 'Clubcard Price', 140), isNull);
    expect(multiBuyAt('aldi', 'Any 2 for £2', 140), isNull);
    final d = multiBuyAt('iceland', '10 for £10.00', 140)!;
    expect((d.units(3), d.cost(3)), (10, 1000));
    expect((d.units(12), d.cost(12)), (20, 2000));
  });

  test('a taken multi-buy costs the list as whole deals; one not taken costs singly', () async {
    final store = await Store.open(memoryDatabase());
    final book = ShoppingBook(store);
    final list = await book.addList('Weekly', today: '2026-10-26');
    final beans = await book.addItem(list, 'heinz beans', today: '2026-10-26');
    await book.keepOffer(
      const Offer(shop: 'tesco', title: 'Heinz Beans 415g', pence: 140, deal: 'Any 2 for £2 Clubcard Price'),
      itemId: beans,
      query: 'heinz beans',
      source: 'auto',
    );
    await book.keepOffer(
      const Offer(shop: 'asda', title: 'Heinz Beans 415g', pence: 120),
      itemId: beans,
      query: 'heinz beans',
      source: 'auto',
    );
    final items = await book.items(list);
    final prices = await book.prices();
    final offers = dealOffers(items, prices, await book.dealChoices(), {'tesco', 'asda'});
    expect(offers.map((o) => (o.price.shop, o.deal.text, o.taken)), [
      ('tesco', 'Any 2 for £2 Clubcard Price', null),
    ]);
    expect(offers.single.price.offer, 'Any 2 for £2 Clubcard Price');
    // Until the user takes it, Tesco is costed at the single price.
    expect({for (final c in costByShop(items, prices)) c.shop: c.pence}, {'tesco': 140, 'asda': 120});

    await book.chooseDeal(dealKey(offers.single.price, offers.single.deal), true);
    final deals = await book.dealChoices();
    expect(
      {for (final c in costByShop(items, prices, deals: deals)) c.shop: c.pence},
      {'tesco': 200, 'asda': 120},
    );
    expect(offers.single.price.units(1, deals), 2);
    expect(dealOffers(items, prices, deals, {'tesco'}).single.taken, isTrue);
    await book.chooseDeal(dealKey(offers.single.price, offers.single.deal), false);
    expect(offers.single.price.cost(1, await book.dealChoices()), 140);
    await store.db.close();
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

  test('a watched item whose best price fell since the last day priced is a price drop', () async {
    final store = await Store.open(memoryDatabase());
    final book = ShoppingBook(store);
    await seedBook(book);
    final list = await book.items((await book.db.select(book.db.foodLists).get()).single.id);
    Item named(String n) => list.firstWhere((i) => i.name == n);
    final milk = named('semi-skimmed milk'), bread = named('wholemeal bread');
    expect(priceDrops(list, await book.prices(), await book.watched()), isEmpty);

    await book.watch(milk.id, true);
    await book.watch(bread.id, true);
    final drops = priceDrops(list, await book.prices(), await book.watched());
    // Milk was £1.49 at Aldi on the latest earlier day; bread has no earlier day.
    expect(drops.map((d) => (d.item.id, d.now.pence, d.was.pence, d.was.day)), [
      (milk.id, 139, 149, '2026-10-18'),
    ]);

    await book.watch(milk.id, false);
    expect(await book.watched(), {bread.id});
    await store.db.close();
  });

  test('the shop is walked through every aisle once', () {
    expect({...walkOrder}, {...Aisle.values});
    expect(walkOrder, hasLength(Aisle.values.length));
  });

  test('items bought before come back once, newest first, unless already on the list', () async {
    final store = await Store.open(memoryDatabase());
    final book = ShoppingBook(store);
    final old = await book.addList('Old', today: '2026-10-01');
    await book.addItem(old, 'eggs', today: '2026-10-01');
    await book.addItem(old, 'tea', today: '2026-10-02');
    final now = await book.addList('Now', today: '2026-10-20');
    await book.addItem(now, 'Eggs', today: '2026-10-20');
    await book.addItem(now, 'rice', today: '2026-10-21');
    await book.removeItem((await book.items(now)).firstWhere((i) => i.name == 'rice').id);
    expect(await book.usualItems({'Eggs'}), ['rice', 'tea']);
    expect(await book.usualItems({'Eggs'}, limit: 1), ['rice']);
    await store.db.close();
  });

  test('the running total counts the basket and the list at best prices, and a budget is kept', () async {
    final store = await Store.open(memoryDatabase());
    final book = ShoppingBook(store);
    await seedBook(book);
    final listId = (await book.db.select(book.db.foodLists).get()).single.id;
    final items = await book.items(listId);
    // 2 milk at Aldi's £1.39 and bread at £1.40; bananas and the ticked
    // washing-up liquid have no price.
    expect(spend(items, await book.prices()), (basket: 0, list: 418, unpriced: 2));
    final bread = items.firstWhere((i) => i.name == 'wholemeal bread');
    await book.tick(bread, true);
    expect(spend(await book.items(listId), await book.prices()).basket, 140);

    expect(await book.budget(listId), isNull);
    await book.setBudget(listId, 6000);
    expect(await book.budget(listId), 6000);
    await book.setBudget(listId, null);
    expect(await book.budget(listId), isNull);
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

  test('items are placed in their aisle, with tricky names caught first', () {
    expect(aisleOf('2 semi-skimmed milk'), Aisle.dairy);
    expect(aisleOf('wholemeal bread'), Aisle.bakery);
    expect(aisleOf('bananas'), Aisle.fruitVeg);
    expect(aisleOf('washing-up liquid'), Aisle.household);
    expect(aisleOf('peanut butter'), Aisle.cupboard);
    expect(aisleOf('ice cream'), Aisle.frozen);
    expect(aisleOf('frozen peas'), Aisle.frozen);
    expect(aisleOf('watermelon'), Aisle.fruitVeg);
    expect(aisleOf('dog food'), Aisle.pets);
    expect(aisleOf('teacakes'), Aisle.bakery);
    expect(aisleOf('a gift'), Aisle.other);
  });
}
