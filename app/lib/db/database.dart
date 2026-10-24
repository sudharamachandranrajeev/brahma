import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

part 'database.g.dart';

// Only the tables core needs: the suite app's own data is its local
// settings. Each hosted app keeps its own database (see lib/app/session.dart).

@DataClassName('Pref')
class Prefs extends Table with SyncedRow, PrefColumns {}

@DataClassName('OutboxItem')
class Outbox extends Table with OutboxColumns {}

@DataClassName('SyncCursor')
class SyncCursors extends Table with SyncCursorColumns {}

@DataClassName('LocalSetting')
class LocalSettings extends Table with LocalSettingColumns {}

@DriftDatabase(tables: [Prefs, Outbox, SyncCursors, LocalSettings])
class HubDatabase extends _$HubDatabase with SyncedDatabase {
  HubDatabase(super.e);

  /// Opens the suite app's encrypted database (see [openEncryptedDatabase]).
  HubDatabase.open(String key) : this(openEncryptedDatabase('brahma', key));

  @override
  final syncedTables = const ['prefs'];

  @override
  int get schemaVersion => 1;
}
