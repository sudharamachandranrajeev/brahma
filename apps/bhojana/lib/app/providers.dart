import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../db/database.dart';
import '../domain/reader.dart';
import '../domain/shops.dart';
import '../domain/web_searcher.dart';
import '../ui/hints.dart';
import 'session.dart';

/// The open session; main() overrides this before the first frame.
final sessionProvider = Provider<AppSession>((ref) => throw StateError('No session'));

/// What main() and the tests override: the session, under both its Bhojana
/// and its shared type, and the app's identity and hints.
List<Override> bhojanaOverrides(AppSession session) => [
  sessionProvider.overrideWithValue(session),
  coreSessionProvider.overrideWithValue(session),
  appIdentityProvider.overrideWithValue(bhojanaIdentity),
  hintTextsProvider.overrideWithValue({...coreHints, ...bhojanaHints}),
  sentinelChecksProvider.overrideWithValue([...coreChecks, lockCheck]),
];

/// Reads shop pages; tests swap in a fake.
final searcherProvider = Provider<PriceSearcher>((_) => const WebSearcher());

extension Mutate on WidgetRef {
  /// Runs a write, refreshes the screens and queues a sync.
  Future<T> mutate<T>(Future<T> Function(AppSession s) write) async {
    final result = await write(read(sessionProvider));
    changed();
    return result;
  }
}

final listsProvider = FutureProvider<List<ShopList>>((ref) {
  ref.watch(revisionProvider);
  final db = ref.watch(sessionProvider).db;
  return (db.select(db.foodLists)
        ..where((t) => t.deleted.not())
        ..orderBy([(t) => OrderingTerm.asc(t.created), (t) => OrderingTerm.asc(t.name)]))
      .get();
});

/// The list on screen, by id; null shows the first list.
class CurrentList extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

final currentListIdProvider = NotifierProvider<CurrentList, String?>(CurrentList.new);

final currentListProvider = FutureProvider<ShopList?>((ref) async {
  final lists = await ref.watch(listsProvider.future);
  final id = ref.watch(currentListIdProvider);
  return lists.where((l) => l.id == id).firstOrNull ?? lists.firstOrNull;
});

final itemsProvider = FutureProvider<List<Item>>((ref) async {
  ref.watch(revisionProvider);
  final list = await ref.watch(currentListProvider.future);
  return list == null ? const [] : ref.watch(sessionProvider).book.items(list.id);
});

final pricesProvider = FutureProvider<List<Price>>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(sessionProvider).book.prices();
});

/// Synced preference keys.
const postcodePref = 'bhojana.postcode';
const shopsPref = 'bhojana.shops';

final postcodeProvider = FutureProvider<String>((ref) async {
  ref.watch(revisionProvider);
  return await ref.watch(sessionProvider).book.pref(postcodePref) ?? '';
});

/// The shops the user compares, in catalogue order.
final myShopsProvider = FutureProvider<List<Shop>>((ref) async {
  ref.watch(revisionProvider);
  final raw = await ref.watch(sessionProvider).book.pref(shopsPref);
  final ids = raw == null ? defaultShops.toSet() : raw.split(',').where((s) => s.isNotEmpty).toSet();
  return [
    for (final s in shops)
      if (ids.contains(s.id)) s,
  ];
});
