import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

import '../db/database.dart';
import 'reader.dart';
import 'shops.dart';

/// A list costed at one shop from the latest price kept for each item.
class ShopCost {
  const ShopCost(this.shop, this.pence, this.priced, this.items);
  final String shop;
  final int pence;
  final int priced;
  final int items;

  bool get complete => priced == items;
}

/// Bhojana's write path and the reads screens share.
class ShoppingBook {
  ShoppingBook(this.store);
  final Store store;

  AppDatabase get db => store.db as AppDatabase;

  // ---- lists ----

  Future<String> addList(String name, {required String today}) async {
    final id = newId();
    await store.save(db.foodLists, FoodListsCompanion.insert(id: id, name: name.trim(), created: today), id);
    return id;
  }

  Future<void> renameList(ShopList l, String name) =>
      store.save(db.foodLists, l.copyWith(name: name.trim()), l.id);

  /// Deletes a list with its items; prices kept for them stay for history.
  Future<void> removeList(String id) async {
    for (final i in await items(id)) {
      await store.remove(db.foodItems, i.id);
    }
    await store.remove(db.foodLists, id);
  }

  // ---- items ----

  Future<List<Item>> items(String listId) =>
      (db.select(db.foodItems)
            ..where((t) => t.listId.equals(listId) & t.deleted.not())
            ..orderBy([(t) => OrderingTerm.asc(t.done), (t) => OrderingTerm.asc(t.ord)]))
          .get();

  /// Adds "2 milk" as two of milk at the end of the list.
  Future<String> addItem(String listId, String text, {required String today}) async {
    final (qty, name) = splitQuantity(text);
    final last = await items(listId);
    final ord = last.isEmpty ? 0 : last.map((i) => i.ord).reduce((a, b) => a > b ? a : b) + 1;
    final id = newId();
    await store.save(
      db.foodItems,
      FoodItemsCompanion.insert(
        id: id,
        listId: listId,
        name: name,
        qty: Value(qty),
        ord: Value(ord),
        added: today,
      ),
      id,
    );
    return id;
  }

  Future<void> saveItem(Item i) => store.save(db.foodItems, i, i.id);

  Future<void> tick(Item i, bool done) => saveItem(i.copyWith(done: done));

  Future<void> removeItem(String id) => store.remove(db.foodItems, id);

  /// Unticks every item, for the next shop.
  Future<void> resetList(String listId) async {
    for (final i in await items(listId)) {
      if (i.done) await tick(i, false);
    }
  }

  // ---- prices ----

  /// Keeps [o] as the price of [itemId] (or of a free search) seen today. It
  /// replaces a price already kept today for the same item at the same shop,
  /// so the user's own pick wins over an earlier automatic one.
  Future<void> keepOffer(Offer o, {String? itemId, required String query, required String source}) async {
    if (itemId != null) {
      final same =
          await (db.select(db.foodPrices)..where(
                (t) =>
                    t.itemId.equals(itemId) & t.shop.equals(o.shop) & t.day.equals(today()) & t.deleted.not(),
              ))
              .get();
      for (final p in same) {
        await store.remove(db.foodPrices, p.id);
      }
    }
    final id = newId();
    await store.save(
      db.foodPrices,
      FoodPricesCompanion.insert(
        id: id,
        itemId: Value(itemId),
        query: query,
        shop: o.shop,
        title: o.title,
        pence: o.pence,
        unitPrice: Value(o.unitPrice),
        offer: Value(o.offer),
        url: Value(o.url),
        inStock: Value(o.inStock),
        day: today(),
        source: Value(source),
      ),
      id,
    );
  }

  Future<void> removePrice(String id) => store.remove(db.foodPrices, id);

  /// Every kept price, newest first.
  Future<List<Price>> prices() =>
      (db.select(db.foodPrices)
            ..where((t) => t.deleted.not())
            ..orderBy([(t) => OrderingTerm.desc(t.day), (t) => OrderingTerm.asc(t.pence)]))
          .get();

  // ---- prefs ----

  Future<String?> pref(String key) async => (await (db.select(
    db.prefs,
  )..where((t) => t.id.equals(key) & t.deleted.not())).getSingleOrNull())?.value;

  Future<void> setPref(String key, String value) =>
      store.save(db.prefs, PrefsCompanion.insert(id: key, value: value), key);
}

/// The latest price per (item, shop): the one a list is costed with.
Map<(String, String), Price> latestPrices(List<Price> prices) {
  final out = <(String, String), Price>{};
  for (final p in prices) {
    if (p.itemId == null) continue;
    final key = (p.itemId!, p.shop);
    final had = out[key];
    // Newest day wins; on the same day the cheaper one.
    if (had == null || p.day.compareTo(had.day) > 0 || (p.day == had.day && p.pence < had.pence)) {
      out[key] = p;
    }
  }
  return out;
}

/// What [items] cost at each shop that has a price for any of them,
/// cheapest complete basket first.
List<ShopCost> costByShop(List<Item> items, List<Price> prices) {
  final latest = latestPrices(prices);
  final shopIds = {for (final k in latest.keys) k.$2};
  final out = <ShopCost>[];
  for (final s in shopIds) {
    var pence = 0, priced = 0;
    for (final i in items) {
      final p = latest[(i.id, s)];
      if (p == null) continue;
      pence += p.pence * i.qty;
      priced++;
    }
    if (priced > 0) out.add(ShopCost(s, pence, priced, items.length));
  }
  out.sort((a, b) {
    final c = b.priced.compareTo(a.priced);
    return c != 0 ? c : a.pence.compareTo(b.pence);
  });
  return out;
}

/// Which shop is cheapest for a list, and by how much.
class Verdict {
  const Verdict(this.best, this.pence, this.items, {this.runnerUp, this.runnerUpPence = 0});

  /// The cheapest shop and what [items] of the list cost there.
  final String best;
  final int pence;

  /// How many items the comparison covers: the whole list when the shops
  /// price every item, otherwise the ones every compared shop has.
  final int items;

  /// The next cheapest shop over the same items, if any.
  final String? runnerUp;
  final int runnerUpPence;

  int get saving => runnerUp == null ? 0 : runnerUpPence - pence;
}

/// The cheapest shop for [items] among [costs]. When two or more shops price
/// the whole list they are compared on it; otherwise every shop is compared
/// like for like on the items they all price. Null when there is nothing to
/// compare.
Verdict? cheapestShop(List<Item> items, List<Price> prices, List<ShopCost> costs) {
  if (costs.isEmpty) return null;
  final complete = [
    for (final c in costs)
      if (c.complete) c,
  ];
  if (complete.length > 1) {
    complete.sort((a, b) => a.pence.compareTo(b.pence));
    return Verdict(
      complete.first.shop,
      complete.first.pence,
      items.length,
      runnerUp: complete[1].shop,
      runnerUpPence: complete[1].pence,
    );
  }
  final latest = latestPrices(prices);
  final shops = [for (final c in costs) c.shop];
  final common = [
    for (final i in items)
      if (shops.every((s) => latest.containsKey((i.id, s)))) i,
  ];
  if (common.isEmpty) return null;
  final totals = [
    for (final s in shops) (s, common.fold(0, (sum, i) => sum + latest[(i.id, s)]!.pence * i.qty)),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  final next = totals.length > 1 ? totals[1] : null;
  return Verdict(
    totals.first.$1,
    totals.first.$2,
    common.length,
    runnerUp: next?.$1,
    runnerUpPence: next?.$2 ?? 0,
  );
}

/// The cheapest kept price for one item, at any shop.
Price? bestPrice(String itemId, List<Price> prices) {
  Price? best;
  for (final p in latestPrices(prices).values) {
    if (p.itemId == itemId && p.inStock && (best == null || p.pence < best.pence)) best = p;
  }
  return best;
}

/// Pence as "£1.25" or "85p".
String pounds(int pence) => pence < 100 ? '${pence}p' : '£${(pence / 100).toStringAsFixed(2)}';

/// Shop names for display, unknown ids as they are.
String shopName(String id) => shopById(id)?.name ?? id;
