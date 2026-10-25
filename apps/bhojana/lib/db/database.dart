import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [FoodLists, FoodItems, FoodPrices, Prefs, Outbox, SyncCursors, LocalSettings])
class AppDatabase extends _$AppDatabase with SyncedDatabase {
  AppDatabase(super.e);

  /// Opens Bhojana's encrypted database (see [openEncryptedDatabase]).
  AppDatabase.open(String key) : this(openEncryptedDatabase('bhojana', key));

  @override
  final syncedTables = const ['food_lists', 'food_items', 'food_prices', 'prefs'];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      for (final sql in _indexes) {
        await customStatement(sql);
      }
    },
  );

  static const _indexes = [
    'CREATE INDEX food_items_list ON food_items (list_id)',
    'CREATE INDEX food_prices_item ON food_prices (item_id)',
  ];
}
