import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';

/// Columns every synced row has. `hlc` is the hybrid-logical-clock stamp of
/// the last write (see sync/hlc.dart); `deleted` is a tombstone so a
/// deletion syncs like any other change.
mixin SyncedRow on Table {
  TextColumn get id => text()();
  TextColumn get hlc => text().withDefault(const Constant(''))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// The tables sync needs. drift reads table classes only from the package it
// builds, so core gives their columns as mixins and each app declares them,
// with exactly these class names (the SQL names `prefs`, `outbox`,
// `sync_cursors` and `local_settings` come from them):
//
//   @DataClassName('Pref')
//   class Prefs extends Table with SyncedRow, PrefColumns {}
//   @DataClassName('OutboxItem')
//   class Outbox extends Table with OutboxColumns {}
//   @DataClassName('SyncCursor')
//   class SyncCursors extends Table with SyncCursorColumns {}
//   @DataClassName('LocalSetting')
//   class LocalSettings extends Table with LocalSettingColumns {}

/// Synced preferences. Shared by every Brahma app on the account, so apps
/// prefix their own keys (`anveshana.…`); unprefixed keys are suite-wide.
mixin PrefColumns on Table {
  TextColumn get value => text()();
}

// ---- local only (never synced) ----

/// Rows changed locally and not yet pushed. `seq` is assigned when a push
/// starts; a local write resets it to null so the newer version goes out too.
mixin OutboxColumns on Table {
  TextColumn get entity => text()();
  TextColumn get rowId => text()();
  IntColumn get seq => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {entity, rowId};
}

/// Highest change sequence pulled from each other device.
mixin SyncCursorColumns on Table {
  TextColumn get deviceId => text()();
  IntColumn get seq => integer()();

  @override
  Set<Column<Object>> get primaryKey => {deviceId};
}

/// Device-local settings (device id, server URL, push counter).
mixin LocalSettingColumns on Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Rows that live under a parent row and always sync with it, so a parent
/// never arrives half-done (a journal entry and its postings).
class ChildRows {
  const ChildRows({required this.table, required this.parentColumn, required this.orderBy});
  final String table;
  final String parentColumn;
  final String orderBy;
}

/// What sync needs from an app's database. Each app's drift database
/// declares the four tables above and mixes this in.
///
/// Every app on an account reads the same change log and applies only the
/// tables it lists here, so table names must be unique across the suite
/// (only `prefs` is shared on purpose).
mixin SyncedDatabase on GeneratedDatabase {
  /// Tables whose rows sync between devices, by SQL name.
  List<String> get syncedTables;

  /// Child tables that travel with their parent, keyed by parent table.
  Map<String, ChildRows> get childRows => const {};

  TableInfo<Table, dynamic>? tableNamed(String name) {
    for (final t in allTables) {
      if (t.actualTableName == name) return t;
    }
    return null;
  }

  Future<String?> localSetting(String key) async => (await customSelect(
    'SELECT value FROM local_settings WHERE key = ?',
    variables: [Variable(key)],
  ).getSingleOrNull())?.read<String>('value');

  Future<void> setLocalSetting(String key, String value) => customStatement(
    'INSERT INTO local_settings (key, value) VALUES (?, ?) '
    'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
    [key, value],
  );
}

/// Where an app's on-device database lives.
Future<File> databaseFile(String name) async =>
    File(p.join((await getApplicationSupportDirectory()).path, '$name.sqlite'));

/// Opens an app's on-device database, encrypted with SQLite3MultipleCiphers.
///
/// [key] is a random hex secret kept in the platform keystore (KeyVault).
/// Opening fails loudly if the bundled SQLite lacks encryption support or the
/// key is wrong, rather than ever writing personal data in plain text.
QueryExecutor openEncryptedDatabase(String name, String key) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(key)) {
    throw ArgumentError('database key must be 64 hex characters');
  }
  return driftDatabase(
    name: name,
    native: DriftNativeOptions(
      databasePath: () async => (await databaseFile(name)).path,
      setup: (db) => applyEncryptionKey(db, key),
    ),
  );
}

/// Runs inside the connection's isolate before drift touches the file.
void applyEncryptionKey(CommonDatabase db, String key) {
  db.execute("PRAGMA key = '$key'");
  // Fails with "no such function" on a plain SQLite build (where PRAGMA key is
  // silently ignored) and with "file is not a database" on a wrong key, so an
  // unencrypted or mis-keyed database is never used.
  db.select('SELECT sqlite3mc_version()');
}
