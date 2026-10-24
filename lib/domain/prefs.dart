import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

import '../db/database.dart';
import 'hub.dart';

/// Synced pref keys. Prefs are shared by every Brahma app, so Vani's start
/// with `vani.`.
abstract final class PrefKeys {
  static const hub = 'vani.hub';
  static const name = 'vani.name';
}

/// Vani's settings kept on the device's encrypted database and synced
/// (end-to-end encrypted) to the user's other devices.
class VaniPrefs {
  VaniPrefs(this.store);
  final Store store;

  AppDatabase get db => store.db as AppDatabase;

  Future<T> pref<T>(String key, T fallback) async {
    final row = await (db.select(db.prefs)..where((p) => p.id.equals(key))).getSingleOrNull();
    if (row == null || row.deleted) return fallback;
    final v = jsonDecode(row.value);
    return v is T ? v : fallback;
  }

  Future<void> setPref(String key, Object value) => store.save(
    db.prefs,
    PrefsCompanion.insert(id: key, value: jsonEncode(value), deleted: const Value(false)),
    key,
  );

  Future<HubLink> hub() async => HubLink.fromJson(await pref<Map<String, Object?>>(PrefKeys.hub, const {}));

  Future<void> saveHub(HubLink link) => setPref(PrefKeys.hub, link.toJson());

  Future<String> name() => pref<String>(PrefKeys.name, '');

  Future<void> saveName(String name) => setPref(PrefKeys.name, name.trim());
}
