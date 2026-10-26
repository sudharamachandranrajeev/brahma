import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../db/database.dart';
import '../domain/book.dart';
import '../domain/car_sources.dart';
import '../ui/hints.dart';
import 'session.dart';

/// The open session; main() overrides this before the first frame.
final sessionProvider = Provider<AppSession>((ref) => throw StateError('No session'));

/// What main() and the tests override: the session, under both its Vahana
/// and its shared type, and the app's identity and hints.
List<Override> vahanaOverrides(AppSession session) => [
  sessionProvider.overrideWithValue(session),
  coreSessionProvider.overrideWithValue(session),
  appIdentityProvider.overrideWithValue(vahanaIdentity),
  hintTextsProvider.overrideWithValue({...coreHints, ...vahanaHints}),
  sentinelChecksProvider.overrideWithValue([...coreChecks, lockCheck]),
];

extension Mutate on WidgetRef {
  /// Runs a write, refreshes the screens and queues a sync.
  Future<T> mutate<T>(Future<T> Function(AppSession s) write) async {
    final result = await write(read(sessionProvider));
    changed();
    return result;
  }
}

/// The rows of [table] that are not deleted, re-read after every write.
FutureProvider<List<D>> _rows<T extends SyncedRow, D>(
  TableInfo<T, D> Function(AppDatabase db) table, {
  List<OrderingTerm Function(T t)> orderBy = const [],
}) => FutureProvider<List<D>>((ref) {
  ref.watch(revisionProvider);
  final db = ref.watch(sessionProvider).db;
  final q = db.select(table(db))
    ..where((t) => t.deleted.not())
    ..orderBy(orderBy);
  return q.get();
});

final vehiclesProvider = _rows<$VehiclesTable, Vehicle>(
  (db) => db.vehicles,
  orderBy: [
    (v) => OrderingTerm.desc(v.added),
    (v) => OrderingTerm(expression: v.title),
  ],
);

/// What the user is shopping for, kept across starts (and devices, with sync).
final carSearchProvider = FutureProvider<CarSearch>((ref) async {
  ref.watch(revisionProvider);
  final j = await ref.watch(sessionProvider).book.pref<Map<String, Object?>>(PrefKeys.carSearch, const {});
  return CarSearch.fromJson(j);
});

/// Sites the user added.
final customSourcesProvider = FutureProvider<List<CustomSource>>((ref) async {
  ref.watch(revisionProvider);
  final l = await ref.watch(sessionProvider).book.pref<List<dynamic>>(PrefKeys.carSources, const []);
  return [for (final e in l) CustomSource.fromJson((e as Map).cast())];
});

final carLogsProvider = _rows<$CarLogsTable, CarLog>(
  (db) => db.carLogs,
  orderBy: [(l) => OrderingTerm.desc(l.date)],
);
