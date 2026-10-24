import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Prefs, Outbox, SyncCursors, LocalSettings])
class AppDatabase extends _$AppDatabase with SyncedDatabase {
  AppDatabase(super.e);

  /// Opens Vani's encrypted database (see [openEncryptedDatabase]).
  AppDatabase.open(String key) : this(openEncryptedDatabase('vani', key));

  @override
  final syncedTables = const ['prefs'];

  @override
  int get schemaVersion => 1;
}
